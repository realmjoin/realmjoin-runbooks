<#
    .SYNOPSIS
    Reports all Windows Entra devices that have no associated Windows Autopilot object.

    .DESCRIPTION
    This runbook lists every Windows device object in Entra ID (Microsoft Entra) and matches it against
    the Windows Autopilot device identities in Intune. Entra devices whose device ID is not referenced by
    any Autopilot object (via the Autopilot object's azureActiveDirectoryDeviceId) are reported as orphans.

    Such orphaned Entra device objects are typical leftovers ("Objektleichen") from devices that were
    reset, re-imaged, or replaced without being cleaned up. The report supports clean-up efforts by making
    these candidates visible so they can be reviewed and - if appropriate - deleted.

    Optionally, the report CSV can be uploaded to an Azure Storage Account (returning a time-limited
    download link) and/or sent via email with the CSV attached.

    .PARAMETER SendMail
    If enabled, the report is sent via email. Toggling this on reveals the recipient address field.

    .PARAMETER CreateDownloadLink
    If enabled, the report CSV is uploaded to an Azure Storage Account and a time-limited download link is returned.

    .PARAMETER EmailTo
    Recipient address(es) for the email report. Only used / shown when SendMail is enabled.
    Can be a single address or multiple comma-separated addresses (string).

    .PARAMETER EmailFrom
    The sender email address. Sourced from the RJReport tenant settings (RJReport.EmailSender).

    .PARAMETER ContainerName
    Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Sourced from the RJReport tenant settings.

    .PARAMETER StorageAccountName
    Storage account name used for the upload. Sourced from the RJReport tenant settings.

    .PARAMETER LinkExpiryDays
    Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "SendMail": {
                "DisplayName": "Send the report via email?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["EmailTo"]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["EmailTo"]
                            }
                        }
                    ]
                }
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a file download link (upload report to storage)?",
                "SelectSimple": {
                    "Yes - upload report and return a download link": true,
                    "No - do not create a download link": false
                }
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)",
                "Hide": true
            },
            "EmailFrom": {
                "Hide": true
            },
            "ContainerName": {
                "Hide": true
            },
            "ResourceGroupName": {
                "Hide": true
            },
            "StorageAccountName": {
                "Hide": true
            },
            "LinkExpiryDays": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param(
    [bool] $SendMail = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string] $EmailFrom,

    [bool] $CreateDownloadLink = $true,

    [string] $ContainerName = "windows-devices-without-autopilot",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SendMail: $SendMail" -Verbose
if ($SendMail) {
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
}
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}

#endregion

########################################################
#region     Parameter Validation
########################################################

# A recipient and a configured sender are required to send an email report
if ($SendMail) {
    if (-not $EmailTo) {
        throw "A recipient email address (EmailTo) is required when 'Send the report via email' is enabled."
    }
    if (-not $EmailFrom) {
        Write-Warning -Message "The sender email address is required to send an email report. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
        throw "The sender email address (EmailFrom) needs to be configured in the runbook customization."
    }
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/devices".
    #>
    param(
        [string]$Uri
    )

    $allResults = @()
    $nextLink = $Uri

    do {
        $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        if ($response.value) {
            $allResults += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $allResults
}

#endregion

########################################################
#region     Connect to Microsoft Graph
########################################################

Write-Output "## Connecting to Microsoft Graph..."
Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

# Get tenant information for the report
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationUri = "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
    $organizationResponse = Invoke-MgGraphRequest -Uri $organizationUri -Method GET -ErrorAction Stop
    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
    }
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}
Write-Output "## Tenant: $($tenantDisplayName)"

#endregion

########################################################
#region     Main Part
########################################################

try {

    #region Data Collection
    ##############################

    Write-Output ""
    Write-Output "## Retrieving all Windows devices from Entra ID..."
    $deviceFilter = [System.Uri]::EscapeDataString("operatingSystem eq 'Windows'")
    $deviceSelect = "deviceId,displayName,accountEnabled,trustType,approximateLastSignInDateTime,operatingSystem,operatingSystemVersion"
    $devicesUri = "https://graph.microsoft.com/v1.0/devices?`$filter=$deviceFilter&`$select=$deviceSelect"
    $windowsDevices = Get-GraphPagedResult -Uri $devicesUri
    Write-Output "## Found $(($windowsDevices | Measure-Object).Count) Windows device(s) in Entra ID."

    Write-Output "## Retrieving all Windows Autopilot device identities from Intune..."
    $autopilotUri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities"
    $autopilotDevices = Get-GraphPagedResult -Uri $autopilotUri
    Write-Output "## Found $(($autopilotDevices | Measure-Object).Count) Autopilot device(s)."

    # Build a lookup of all Entra device IDs that are referenced by an Autopilot object
    $autopilotDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($apDevice in $autopilotDevices) {
        if (-not [string]::IsNullOrEmpty($apDevice.azureActiveDirectoryDeviceId)) {
            [void]$autopilotDeviceIds.Add($apDevice.azureActiveDirectoryDeviceId)
        }
    }

    #endregion

    #region Filter orphaned devices
    ##############################

    Write-Output ""
    Write-Output "## Determining Windows Entra devices without an associated Autopilot object..."

    $orphanedDevices = foreach ($device in $windowsDevices) {
        if (-not $autopilotDeviceIds.Contains($device.deviceId)) {
            [PSCustomObject]@{
                DisplayName               = $device.displayName
                DeviceId                  = $device.deviceId
                AccountEnabled            = $device.accountEnabled
                TrustType                 = $device.trustType
                OperatingSystemVersion    = $device.operatingSystemVersion
                ApproximateLastSignInDate = $device.approximateLastSignInDateTime
            }
        }
    }
    # Normalize to an array (foreach returns a scalar for a single match, $null for none)
    $orphanedDevices = @($orphanedDevices)

    $totalDevices = $orphanedDevices.Count

    Write-Output ""
    Write-Output "## Windows Entra devices without an associated Autopilot object for '$($tenantDisplayName)': $($totalDevices)"
    Write-Output ""
    if ($totalDevices -gt 0) {
        $orphanedDevices | Sort-Object DisplayName | Format-Table -AutoSize | Out-String | Write-Output
    }
    else {
        Write-Output "No orphaned Windows devices were found. Every Windows Entra device has an associated Autopilot object."
    }

    #endregion

    #region CSV Export
    ##############################

    # The CSV is only needed when it will be uploaded and/or attached to an email
    $csvFileName = "windows-devices-without-autopilot.csv"
    $csvFilePath = $null
    if ($CreateDownloadLink -or $SendMail) {
        $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $csvFileName
        $orphanedDevices | Sort-Object DisplayName | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        Write-RjRbLog -Message "Exported orphaned devices to CSV: $($csvFilePath)" -Verbose
    }

    #endregion

    #region Upload / Download Link (optional)
    ##############################

    if ($CreateDownloadLink) {
        Write-Output ""
        Write-Output "## Uploading report to storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths @($csvFilePath) `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        $uploadResult = $uploadResults[0]
        Write-Output "## Report uploaded to storage account."
        Write-Output "## Expiry of Link: $($uploadResult.EndTime)"
        $uploadResult.SASLink | Out-String | Write-Output
    }

    #endregion

    #region Send Email Report (optional)
    ##############################

    if ($SendMail) {
        Write-Output ""
        Write-Output "## Preparing email report to send to '$($EmailTo)'..."

        if ($totalDevices -eq 0) {
            $markdownContent = @"
# Windows Devices Without Autopilot Object

## Summary

**No orphaned Windows devices were found** for tenant **$($tenantDisplayName)**.

Every Windows device object in Entra ID is associated with a Windows Autopilot object. No clean-up action is required at this time.

---

*This email was automatically generated. Please do not reply to this email.*
"@
            $emailSubject = "Windows Devices Without Autopilot - $($tenantDisplayName) - No Issues Found"
        }
        else {
            # Show the first 10 devices inline; the full list is in the attached CSV
            $devicesToShow = $orphanedDevices | Sort-Object DisplayName | Select-Object -First 10
            $table = @"
| Display Name | Device ID | Enabled | Trust Type | Last Sign-In |
|--------------|-----------|---------|------------|--------------|
"@
            foreach ($device in $devicesToShow) {
                $lastSignIn = if ($device.ApproximateLastSignInDate) { Get-Date $device.ApproximateLastSignInDate -Format "yyyy-MM-dd" } else { "N/A" }
                $table += "`n| $($device.DisplayName) | $($device.DeviceId) | $($device.AccountEnabled) | $($device.TrustType) | $($lastSignIn) |"
            }

            $tableHeading = if ($totalDevices -gt 10) {
                "## First 10 Devices (full list in attached CSV)"
            }
            else {
                "## Devices"
            }

            $markdownContent = @"
# Windows Devices Without Autopilot Object

## Executive Summary

This report identifies **$($totalDevices) Windows device object(s)** in Entra ID for tenant **$($tenantDisplayName)** that have **no associated Windows Autopilot object**.

These objects are typical leftovers ("Objektleichen") of devices that were reset, re-imaged, or replaced without being cleaned up. They are good candidates for review and possible deletion.

## How the association is determined

Each Windows Autopilot object references the Entra device it is enrolled as via its ``azureActiveDirectoryDeviceId`` property. A Windows Entra device whose device ID is not referenced by any Autopilot object is reported here.

$($tableHeading)

$($table)

## Recommended Actions

1. **Review** the attached list and confirm the devices are genuinely no longer in use.
2. **Verify** there is no pending re-enrollment or Autopilot import in progress for these devices.
3. **Delete** the confirmed orphaned device objects from Entra ID to keep the inventory clean.

## Data Files

The following file is attached to this email:

- **$($csvFileName)**: Complete list of all Windows Entra devices without an associated Autopilot object.

---

*This email was automatically generated. Please do not reply to this email.*
"@
            $emailSubject = "Windows Devices Without Autopilot - $($tenantDisplayName) - $($totalDevices) Device(s) Found"
        }

        try {
            # -UseNativeGraphRequest reuses the native Connect-MgGraph context established above
            Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -Attachments @($csvFilePath) -TenantDisplayName $tenantDisplayName -ReportVersion $Version -UseNativeGraphRequest
            Write-Output "## Email report sent successfully to: $($EmailTo)"
        }
        catch {
            Write-Error "Failed to send email report: $($_.Exception.Message)"
            throw
        }
    }

    #endregion

    Write-Output ""
    Write-Output "Done!"

}
catch {
    throw $_
}
finally {
    #region Cleanup
    ##############################

    if ($CreateDownloadLink) {
        Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
    }

    #endregion
}

#endregion
