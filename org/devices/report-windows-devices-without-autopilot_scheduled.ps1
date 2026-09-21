<#
    .SYNOPSIS
    Report Windows devices in Entra ID without an Autopilot record

    .DESCRIPTION
    Lists Windows device objects in Entra ID that no Windows Autopilot registration refers to. Such orphaned objects are usually left over from devices that were reset, re-imaged or replaced without cleanup, so the list shows what can be reviewed and deleted. Nothing is changed. The report can be sent by email or provided as a download link.

    .PARAMETER SendMail
    Send the report to the recipient email address.

    .PARAMETER ReportFileFormat
    Deliver the report as CSV, as an Excel workbook, or both.

    .PARAMETER CreateDownloadLink
    Also upload the report and return a download link that expires after a few days.

    .PARAMETER EmailTo
    Send the report to these addresses. Separate several with commas; each recipient gets a separate email.

    .PARAMETER EmailFrom
    Sender address of the report email. Taken from the tenant setting RJReport.EmailSender.

    .PARAMETER BrandingHeaderImageUrl
    Header image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.HeaderImageUrl; the default RealmJoin header is used when empty.

    .PARAMETER BrandingFooterImageUrl
    Footer image of the report email (HTTPS URL, PNG/JPEG/GIF, max 200 KB). Taken from the tenant setting RJReport.Branding.FooterImageUrl; the default RealmJoin footer is used when empty.

    .PARAMETER BrandingFooterLink
    Link behind the footer image of the report email. Taken from the tenant setting RJReport.Branding.FooterLink; realmjoin.com is used when empty.

    .PARAMETER BrandingAccentColor
    Accent color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.AccentColor; the RealmJoin default is used when empty or invalid.

    .PARAMETER BrandingTextColor
    Text color of the report email as a 6-digit hex value. Taken from the tenant setting RJReport.Branding.TextColor; the RealmJoin default is used when empty or invalid.

    .PARAMETER ContainerName
    Storage container the report files are uploaded to. Set per runbook.

    .PARAMETER ResourceGroupName
    Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup.

    .PARAMETER StorageAccountName
    Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName.

    .PARAMETER LinkExpiryDays
    Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "SendMail": {
                "DisplayName": "Send the report by email?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["EmailTo", "ReportFileFormat"]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["EmailTo", "ReportFileFormat"]
                            }
                        }
                    ]
                }
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a download link?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - upload report and return a download link",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": ["ReportFileFormat"]
                            }
                        },
                        {
                            "Display": "No - do not create a download link",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": ["ReportFileFormat"]
                            }
                        }
                    ]
                }
            },
            "ReportFileFormat": {
                "DisplayName": "Report file format",
                "Hide": true,
                "Select": {
                    "Options": [
                        {
                            "Display": "CSV & XLSX",
                            "ParameterValue": "CSV & XLSX"
                        },
                        {
                            "Display": "CSV only",
                            "ParameterValue": "CSV only"
                        },
                        {
                            "Display": "XLSX only",
                            "ParameterValue": "XLSX only"
                        }
                    ],
                    "ShowValue": false
                }
            },
            "EmailTo": {
                "DisplayName": "Recipient email address(es)",
                "Hide": true
            },
            "BrandingHeaderImageUrl": {
                "Hide": true
            },
            "BrandingFooterImageUrl": {
                "Hide": true
            },
            "BrandingFooterLink": {
                "Hide": true
            },
            "BrandingAccentColor": {
                "Hide": true
            },
            "BrandingTextColor": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [bool] $SendMail = $false,

    [Parameter(Mandatory = $false)]
    [string] $EmailTo,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string] $EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.HeaderImageUrl" -Value $_ } )]
    [string] $BrandingHeaderImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterImageUrl" -Value $_ } )]
    [string] $BrandingFooterImageUrl,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.FooterLink" -Value $_ } )]
    [string] $BrandingFooterLink,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.AccentColor" -Value $_ } )]
    [string] $BrandingAccentColor,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.Branding.TextColor" -Value $_ } )]
    [string] $BrandingTextColor,

    [ValidateSet('CSV only', 'CSV & XLSX', 'XLSX only')]
    [string] $ReportFileFormat = 'CSV & XLSX',

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

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SendMail: $SendMail" -Verbose
if ($SendMail) {
    Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
    Write-RjRbLog -Message "EmailFrom: $EmailFrom" -Verbose
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose
}
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
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
        Write-Warning -Message "The sender email address is required to send an email report. This needs to be configured in the runbook customization. Documentation: https://docs.realmjoin.com/automation/runbooks/runbook-report-settings" -Verbose
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

    #region Report File Export
    ##############################

    # The report files are only needed when they will be uploaded and/or attached to an email
    $csvFileName = "windows-devices-without-autopilot.csv"
    $xlsxFileName = "windows-devices-without-autopilot.xlsx"
    $csvFilePath = $null
    $xlsxFilePath = $null
    $reportFiles = @()
    if (($CreateDownloadLink -or $SendMail) -and $totalDevices -gt 0) {
        $sortedDevices = $orphanedDevices | Sort-Object DisplayName

        if ($ReportFileFormat -ne 'XLSX only') {
            $csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $csvFileName
            $sortedDevices | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
            $reportFiles += $csvFilePath
            Write-RjRbLog -Message "Exported orphaned devices to CSV: $($csvFilePath)" -Verbose
        }

        if ($ReportFileFormat -ne 'CSV only') {
            $xlsxFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath $xlsxFileName
            $sortedDevices | Export-RjRbXlsx -Path $xlsxFilePath -WorksheetName "Devices"
            $reportFiles += $xlsxFilePath
            Write-RjRbLog -Message "Exported orphaned devices to XLSX: $($xlsxFilePath)" -Verbose
        }
    }

    #endregion

    #region Upload / Download Link (optional)
    ##############################

    if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
        Write-Output ""
        Write-Output "## Uploading report to storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        Write-Output "## Report uploaded to storage account."
        foreach ($uploadResult in $uploadResults) {
            Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    elseif ($CreateDownloadLink) {
        Write-Output ""
        Write-Output "## No orphaned devices were found - skipping report upload."
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
            # Show the first 10 devices inline; the full list is in the attached report file(s)
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
                "## First 10 Devices (full list in the attached report file(s))"
            }
            else {
                "## Devices"
            }

            $markdownContent = @"
# Windows Devices Without Autopilot Object

## Executive Summary

This report identifies **$($totalDevices) Windows device object(s)** in Entra ID for tenant **$($tenantDisplayName)** that have **no associated Windows Autopilot object**.

These objects are typical leftovers of devices that were reset, re-imaged, or replaced without being cleaned up. They are good candidates for review and possible deletion.

## How the association is determined

Each Windows Autopilot object references the Entra device it is enrolled as via its ``azureActiveDirectoryDeviceId`` property. A Windows Entra device whose device ID is not referenced by any Autopilot object is reported here.

$($tableHeading)

$($table)

## Recommended Actions

1. **Review** the attached list and confirm the devices are genuinely no longer in use.
2. **Verify** there is no pending re-enrollment or Autopilot import in progress for these devices.
3. **Delete** the confirmed orphaned device objects from Entra ID to keep the inventory clean.

## Data Files

The following file(s) are attached to this email:

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$($csvFileName)**: Complete list of all Windows Entra devices without an associated Autopilot object (CSV)" })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$($xlsxFileName)**: The same list as a formatted Excel workbook" })

---

*This email was automatically generated. Please do not reply to this email.*
"@
            $emailSubject = "Windows Devices Without Autopilot - $($tenantDisplayName) - $($totalDevices) Device(s) Found"

            $markdownFallback = @"
# Windows Devices Without Autopilot Object

## Executive Summary

This report identifies **$($totalDevices) Windows device object(s)** in Entra ID for tenant **$($tenantDisplayName)** that have **no associated Windows Autopilot object**.

## Data Files

- **$($xlsxFileName)**: Formatted Excel workbook with the complete device list

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@
        }

        # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
        # Resolve optional tenant email branding once per run (never fails the send)
        $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

        try {
            if ($reportFiles.Count -gt 0) {
                # -UseNativeGraphRequest reuses the native Connect-MgGraph context established above
                $guardParams = @{
                    EmailFrom         = $EmailFrom
                    EmailTo           = $EmailTo
                    Subject           = $emailSubject
                    MarkdownContent   = $markdownContent
                    TenantDisplayName = $tenantDisplayName
                    ReportVersion     = $Version
                }
                $guardParams.UseNativeGraphRequest = $true
                if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxFilePath) {
                    Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxFilePath) -FallbackMarkdownContent $markdownFallback
                }
                else {
                    Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
                }
            }
            else {
                # -UseNativeGraphRequest reuses the native Connect-MgGraph context established above
                Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -UseNativeGraphRequest @brandingMailParams
                Write-Output "## Email report sent successfully to: $($EmailTo)"
            }
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
    # Remove the downloaded branding images, if any were used.
    foreach ($brandingKey in @('HeaderImage', 'FooterImage')) {
        if ($brandingMailParams -and $brandingMailParams.ContainsKey($brandingKey) -and (Test-Path -LiteralPath $brandingMailParams[$brandingKey])) {
            Remove-Item -LiteralPath $brandingMailParams[$brandingKey] -Force -ErrorAction SilentlyContinue
        }
    }

    if ($CreateDownloadLink) {
        Disconnect-AzAccount -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
    }

    #endregion
}

#endregion
