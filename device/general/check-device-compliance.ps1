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

Write-Output ""
Write-Output "## Compliance Check: '$($managedDevice.deviceName)'"
Write-Output "-------------------------------------------------------------"
Write-Output "Device Name:       $($managedDevice.deviceName)"
Write-Output "Operating System:  $($managedDevice.operatingSystem) $($managedDevice.osVersion)"
Write-Output "Compliance State:  $($managedDevice.complianceState)"
Write-Output "Managed By:        $($managedDevice.managementAgent)"
Write-Output "Last Sync:         $($managedDevice.lastSyncDateTime)"
Write-Output ""

# Retrieve compliance policy states for this device
$policyStatesResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$intuneDeviceId/deviceCompliancePolicyStates" -Method GET

$complianceDetails = @()

# Fetch per-setting details only when detailed output mode is active
$fetchSettingDetails = $DetailedOutput

if ($policyStatesResponse.value -and ($policyStatesResponse.value | Measure-Object).Count -gt 0) {
    foreach ($policy in $policyStatesResponse.value) {
        Write-RjRbLog -Message "Policy: '$($policy.displayName)' - State: $($policy.state)" -Verbose

        $nonCompliantSettings = @()
        if ($fetchSettingDetails) {
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
            Write-Output "Policy: '$($policy.displayName)'"
            Write-Output "  State: $($policy.state)"

            if ($DetailedOutput) {
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
            }
            Write-Output ""
        }
    }
}
else {
    Write-Output "No compliance policies are assigned to this device."
}

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
    $nonCompliantPolicies = @($complianceDetails | Where-Object { $_.State -ne "compliant" })
    $compliantPolicies = @($complianceDetails | Where-Object { $_.State -eq "compliant" })
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
| **Compliance State** | $($managedDevice.complianceState) |
| **Managed By** | $($managedDevice.managementAgent) |
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
