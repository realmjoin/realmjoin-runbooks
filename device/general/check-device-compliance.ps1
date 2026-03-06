<#
    .SYNOPSIS
    Check the compliance status of a device

    .DESCRIPTION
    This runbook retrieves the compliance status of a managed device from Microsoft Intune.
    In simple mode it shows the overall compliance state and lists any non-compliant policies. In detailed mode it additionally shows which specific settings are failing and the reason for each failure.
    Optionally, a report with the full compliance details can be sent via email.

    .PARAMETER DeviceId
    The Entra ID device ID of the target device. Passed automatically by the RealmJoin platform.

    .PARAMETER DetailedOutput
    Select "Simple" (final value: $false) to show only the overall compliance state and non-compliant policy names.
    Select "Detailed" (final value: $true) to additionally show which specific settings are failing and the reason for each failure.

    .PARAMETER EmailTo
    Optional - if specified, a compliance report will be sent to the provided email address(es).
    Can be a single address or multiple comma-separated addresses.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "DetailedOutput": {
                "DisplayName": "Output Mode",
                "Select": {
                    "Options": [
                        {
                            "Display": "Simple - show overall compliance state and non-compliant policies",
                            "Value": false
                        },
                        {
                            "Display": "Detailed - show failing settings and reasons per policy",
                            "Value": true
                        }
                    ]
                }
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es) (optional)"
            },
            "EmailFrom": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,

    [bool] $DetailedOutput = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose
Write-RjRbLog -Message "Detailed Output: $DetailedOutput" -Verbose

if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
}

#endregion RJ Log Part

########################################################
#region     Parameter Validation
########################################################

if ($EmailTo -and -not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "This needs to be configured in the runbook customization."
}

#endregion Parameter Validation

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-MgGraph -Identity -NoWelcome

Write-Output "Connecting to RJ RunbookHelper Graph..."
Connect-RjRbGraph

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output "Retrieving device information from Intune..."

# Look up the managed device in Intune by Azure AD device ID
$managedDeviceResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$DeviceId'" -Method GET

if (-not $managedDeviceResponse.value -or ($managedDeviceResponse.value | Measure-Object).Count -eq 0) {
    Write-Error "No managed device found in Intune for DeviceId '$DeviceId'." -ErrorAction Continue
    throw "Device '$DeviceId' not found in Intune. Ensure the device is enrolled and the ID is correct."
}

$managedDevice = $managedDeviceResponse.value[0]
$intuneDeviceId = $managedDevice.id

Write-RjRbLog -Message "Device found: '$($managedDevice.deviceName)' (Intune ID: $intuneDeviceId)" -Verbose
Write-RjRbLog -Message "OS: $($managedDevice.operatingSystem) $($managedDevice.osVersion)" -Verbose
Write-RjRbLog -Message "Compliance State: $($managedDevice.complianceState)" -Verbose

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

# Format raw API values for display
$complianceStateDisplay = switch ($managedDevice.complianceState) {
    "compliant"    { "Compliant" }
    "noncompliant" { "Non-Compliant" }
    "unknown"      { "Unknown" }
    "error"        { "Error" }
    "inGracePeriod" { "In Grace Period" }
    "configManager" { "Config Manager" }
    default        { $managedDevice.complianceState }
}
$managementAgentDisplay = ($managedDevice.managementAgent).ToUpper()

Write-Output ""
Write-Output "## Compliance Check: '$($managedDevice.deviceName)'"
Write-Output "-------------------------------------------------------------"
Write-Output "Device Name:       $($managedDevice.deviceName)"
Write-Output "Operating System:  $($managedDevice.operatingSystem) $($managedDevice.osVersion)"
Write-Output "Compliance State:  $complianceStateDisplay"
Write-Output "Managed By:        $managementAgentDisplay"
Write-Output "Last Sync:         $($managedDevice.lastSyncDateTime)"
Write-Output ""

# In simple mode, print a heading for the non-compliant policy list
if (-not $DetailedOutput -and $managedDevice.complianceState -ne "compliant") {
    Write-Output "Non-compliant policies:"
}

# Retrieve compliance policy states for this device
$policyStatesResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$intuneDeviceId/deviceCompliancePolicyStates" -Method GET

$complianceDetails = @()

# Setting name to human-readable description mapping
$settingDescriptions = @{
    'osMinimumVersion'                            = 'OS version below minimum requirement'
    'osMaximumVersion'                            = 'OS version above maximum requirement'
    'mobileOsMinimumVersion'                      = 'Mobile OS version below minimum requirement'
    'validOperatingSystemBuildRanges'             = 'OS build not in allowed range'
    'bitLockerEnabled'                            = 'BitLocker not enabled'
    'storageRequireDeviceEncryption'              = 'Device encryption not enabled'
    'passwordRequired'                            = 'Password policy not met'
    'passwordMinimumLength'                       = 'Password too short'
    'passwordRequiredType'                        = 'Password type requirement not met'
    'passwordExpirationDays'                      = 'Password expiration not compliant'
    'defenderEnabled'                             = 'Microsoft Defender not enabled'
    'antivirusRequired'                           = 'Antivirus not compliant'
    'antiSpywareRequired'                         = 'Anti-spyware not compliant'
    'firewallEnabled'                             = 'Firewall not enabled'
    'activeFirewallRequired'                      = 'Firewall not enabled'
    'secureBootEnabled'                           = 'Secure Boot not enabled'
    'codeIntegrityEnabled'                        = 'Code Integrity not enabled'
    'tpmRequired'                                 = 'TPM not present or not compliant'
    'deviceThreatProtectionEnabled'              = 'Device threat protection not enabled'
    'deviceThreatProtectionRequiredSecurityLevel' = 'Device threat protection level not met'
    'rtpEnabled'                                  = 'Real-time protection not enabled'
    'signatureOutOfDate'                          = 'Antivirus signatures out of date'
    'configurationManagerComplianceRequired'      = 'Configuration Manager compliance not met'
    'requireRemainContact'                        = 'Device has not checked in with Intune within the required timeframe'
}

# Map device OS to the Intune compliance policy platformType values it can match
$devicePlatformTypes = switch ($managedDevice.operatingSystem) {
    "Windows" { @("windows10AndLater", "windows81AndLater", "windowsPhone81", "all") }
    "macOS"   { @("macOS", "all") }
    "iOS"     { @("iOS", "all") }
    "Android" { @("android", "androidForWork", "androidWorkProfile", "androidAOSP", "all") }
    default   { @() }  # empty = no platform filtering for unknown OS
}
Write-RjRbLog -Message "Device platform types: $($devicePlatformTypes -join ', ')" -Verbose

if ($policyStatesResponse.value -and ($policyStatesResponse.value | Measure-Object).Count -gt 0) {
    foreach ($policy in $policyStatesResponse.value) {
        # Skip policies that do not apply to this device (e.g. macOS policies on a Windows device)
        if ($policy.state -in @('notApplicable', 'notAssigned')) {
            Write-RjRbLog -Message "Skipping policy '$($policy.displayName)' - State: $($policy.state) (not applicable to this device)" -Verbose
            continue
        }

        # Skip policies targeting a different OS platform
        if ($devicePlatformTypes.Count -gt 0 -and $policy.platformType -and $policy.platformType -notin $devicePlatformTypes) {
            Write-RjRbLog -Message "Skipping policy '$($policy.displayName)' - Platform: '$($policy.platformType)' does not match device OS: '$($managedDevice.operatingSystem)'" -Verbose
            continue
        }

        Write-RjRbLog -Message "Policy: '$($policy.displayName)' - State: $($policy.state)" -Verbose

        $nonCompliantSettings = @()
        # Always fetch setting states for non-compliant policies to derive readable reasons in both modes
        if ($policy.state -ne "compliant") {
            # Retrieve per-setting states for this policy
            $settingStatesResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$intuneDeviceId/deviceCompliancePolicyStates/$($policy.id)/settingStates" -Method GET

            if ($settingStatesResponse.value) {
                $nonCompliantSettings = @($settingStatesResponse.value | Where-Object {
                    $_.state -ne "compliant" -and $_.state -ne "notApplicable" -and $_.state -ne "notAssigned"
                })
            }
        }

        $policyResult = [PSCustomObject]@{
            PolicyName           = $policy.displayName
            PolicyId             = $policy.id
            State                = $policy.state
            NonCompliantSettings = $nonCompliantSettings
        }
        $complianceDetails += $policyResult

        if ($policy.state -ne "compliant") {
            if ($DetailedOutput) {
                Write-Output "Policy: '$($policy.displayName)'"
                Write-Output "  State: $($policy.state)"

                if ($nonCompliantSettings.Count -gt 0) {
                    Write-Output "  Non-compliant settings:"
                    foreach ($setting in $nonCompliantSettings) {
                        Write-Output "    - $($setting.setting): $($setting.state)"
                        if ($setting.errorDescription) {
                            Write-Output "      Reason: $($setting.errorDescription)"
                        }
                        if ($setting.userEmail) {
                            Write-Output "      User:   $($setting.userEmail)"
                        }
                    }
                }
                else {
                    Write-Output "  No detailed setting information available."
                }
                Write-Output ""
            }
            else {
                # Simple mode: show policy name and readable setting reasons
                Write-Output "  - '$($policy.displayName)'"
                if ($nonCompliantSettings.Count -gt 0) {
                    $readableReasons = $nonCompliantSettings | ForEach-Object {
                        $shortName = ($_.setting -split '\.')[-1]
                        if ($settingDescriptions.ContainsKey($shortName)) { $settingDescriptions[$shortName] } else { $shortName }
                    }
                    Write-Output "    Reason: $(($readableReasons | Select-Object -Unique) -join '; ')"
                }
                else {
                    $fallbackReason = switch ($policy.state) {
                        "unknown"  { "Policy could not be evaluated - device may not have synced recently" }
                        "error"    { "Policy evaluation error" }
                        "conflict" { "Policy conflict with another policy" }
                        default    { "Policy state: $($policy.state)" }
                    }
                    Write-Output "    Reason: $fallbackReason"
                }
                Write-Output ""
            }
        }
    }
}
else {
    Write-Output "No compliance policies are assigned to this device."
}

# Shared variables used by console output and email report
$nonCompliantPolicies = @($complianceDetails | Where-Object { $_.State -ne "compliant" })
$compliantPolicies = @($complianceDetails | Where-Object { $_.State -eq "compliant" })

Write-Output ""
if ($managedDevice.complianceState -eq "compliant") {
    Write-Output "Result: Device '$($managedDevice.deviceName)' is COMPLIANT."
}
else {
    Write-Output "Result: Device '$($managedDevice.deviceName)' is NOT COMPLIANT (State: $($managedDevice.complianceState))."
}

#endregion Main Part

########################################################
#region     Email Report
########################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "Preparing compliance report email..."

    # Retrieve tenant display name for the email report
    $tenantResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
    $tenantDisplayName = if ($tenantResponse.value -and ($tenantResponse.value | Measure-Object).Count -gt 0) {
        $tenantResponse.value[0].displayName
    }
    else {
        "Unknown Tenant"
    }

    $dateStr = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $totalPolicies = ($complianceDetails | Measure-Object).Count
    $complianceEmoji = if ($managedDevice.complianceState -eq "compliant") { "OK" } else { "NOT COMPLIANT" }

    $markdownContent = @"
# Device Compliance Report

**Date:** $dateStr
**Tenant:** $tenantDisplayName

## Overall Status: $complianceEmoji

## Device Information

| Property | Value |
|----------|-------|
| **Device Name** | $($managedDevice.deviceName) |
| **Operating System** | $($managedDevice.operatingSystem) $($managedDevice.osVersion) |
| **Compliance State** | $complianceStateDisplay |
| **Managed By** | $managementAgentDisplay |
| **Last Sync** | $($managedDevice.lastSyncDateTime) |
| **Azure AD Device ID** | $DeviceId |
| **Intune Device ID** | $intuneDeviceId |

## Compliance Policy Summary

| Total Policies | Compliant | Non-Compliant |
|----------------|-----------|---------------|
| $totalPolicies | $($compliantPolicies.Count) | $($nonCompliantPolicies.Count) |

$(if ($nonCompliantPolicies.Count -gt 0) {
    $sb = "## Non-Compliant Policies`n`n"

    foreach ($policy in $nonCompliantPolicies) {
        $sb += "### $($policy.PolicyName)`n`n"
        $sb += "**State:** $($policy.State)`n`n"
        if ($DetailedOutput) {
            if ($policy.NonCompliantSettings -and $policy.NonCompliantSettings.Count -gt 0) {
                $sb += "| Setting | State | Reason |`n"
                $sb += "|---------|-------|--------|`n"
                foreach ($s in $policy.NonCompliantSettings) {
                    $reason = if ($s.errorDescription) { $s.errorDescription } else { "-" }
                    $sb += "| $($s.setting) | $($s.state) | $reason |`n"
                }
                $sb += "`n"
            }
            else {
                $sb += "No detailed setting information available for this policy.`n`n"
            }
        }
        else {
            if ($policy.NonCompliantSettings -and $policy.NonCompliantSettings.Count -gt 0) {
                $readableReasons = $policy.NonCompliantSettings | ForEach-Object {
                    $shortName = ($_.setting -split '\.')[-1]
                    if ($settingDescriptions.ContainsKey($shortName)) { $settingDescriptions[$shortName] } else { $shortName }
                }
                $uniqueReasons = ($readableReasons | Select-Object -Unique) -join '; '
                $sb += "**Reason:** $uniqueReasons`n`n"
            }
            else {
                $fallbackReason = switch ($policy.State) {
                    "unknown"  { "Policy could not be evaluated - device may not have synced recently" }
                    "error"    { "Policy evaluation error" }
                    "conflict" { "Policy conflict with another policy" }
                    default    { "Policy state: $($policy.State)" }
                }
                $sb += "**Reason:** $fallbackReason`n`n"
            }
        }
    }
    $sb
} else {
    "## All Policies Compliant`n`nAll assigned compliance policies are in a compliant state.`n"
})
---
*Generated by the RealmJoin Device Compliance Check runbook (v$Version).*
"@

    $emailSubject = "Device Compliance [$($managedDevice.complianceState.ToUpper())] - $($managedDevice.deviceName) - $dateStr"

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version
        Write-RjRbLog -Message "Compliance report email sent successfully to: $EmailTo" -Verbose
        Write-Output "Compliance report sent to: $EmailTo"
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
}

#endregion Email Report

########################################################
#region     Cleanup
########################################################

Write-RjRbLog -Message "Device compliance check completed for '$($managedDevice.deviceName)'" -Verbose

#endregion Cleanup
