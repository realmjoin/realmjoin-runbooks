<#
    .SYNOPSIS
    Report users with more than five registered devices

    .DESCRIPTION
    This runbook queries Entra ID devices and their registered users to identify users with more than five devices.
    It outputs a summary table and can optionally send an email with CSV attachments.
    The detailed CSV export lists each device with its object ID, Entra ID device ID and display name, and indicates whether the device is also present in Intune as a managed device.
    The report CSV files can also be uploaded to an Azure Storage Account, returning time-limited download links.

.PARAMETER IntuneOnlyDevices
    If enabled, only devices that are present in Intune (managed devices) are considered for the report.
    The "InIntune" column is omitted from the detailed CSV export in this case, as all reported devices are Intune-managed.
    Disabled by default.

.PARAMETER CreateDownloadLink
    If enabled, the report CSV files are uploaded to an Azure Storage Account and time-limited download links are returned. Disabled by default.

.PARAMETER ContainerName
    Storage container name used for the upload. Configured per runbook (not a global RJReport setting).

.PARAMETER ResourceGroupName
    Resource group that contains the storage account. Sourced from the RJReport tenant settings.

.PARAMETER StorageAccountName
    Storage account name used for the upload. Sourced from the RJReport tenant settings.

.PARAMETER LinkExpiryDays
    Number of days until the generated download link expires. Sourced from the RJReport tenant settings.

.PARAMETER EmailTo
    If specified, an email with the report will be sent to the provided address(es).
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

.PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

.PARAMETER CallerName
    Caller name for auditing purposes.

.INPUTS
    RunbookCustomization: {
        "Parameters": {
            "IntuneOnlyDevices": {
                "DisplayName": "Only include devices present in Intune"
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a file download link (upload report to storage)?",
                "SelectSimple": {
                    "Yes - upload report and return a download link": true,
                    "No - do not create a download link": false
                }
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
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.3.4" }

param (
    [bool]$IntuneOnlyDevices = $false,

    [bool]$CreateDownloadLink = $false,

    [string]$ContainerName = "users-with-more-than-5-devices",

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" -Value $_ })]
    [string]$ResourceGroupName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" -Value $_ })]
    [string]$StorageAccountName,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" -Value $_ })]
    [ValidateRange(1, 3650)]
    [int]$LinkExpiryDays = 6,

    [ValidateScript({ Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ })]
    [string]$EmailFrom,

    [Parameter(Mandatory = $false)]
    [string]$EmailTo,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "IntuneOnlyDevices: $IntuneOnlyDevices" -Verbose

# Add Parameter in Verbose output
if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
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

# Validate Email Addresses (only if email is requested)
if ($EmailTo) {
    if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    exit
    }
}

# A target storage account is required to create a download link
if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    Write-Warning -Message "A target storage account is required to create a download link. Configure the RJReport.StorageAccount.* settings in the runbook customization ( https://portal.realmjoin.com/settings/runbooks-customizations ) or pass ResourceGroupName and StorageAccountName when starting the runbook." -Verbose
    throw "Missing Storage Account Configuration (RJReport.StorageAccount.ResourceGroup / RJReport.StorageAccount.StorageAccountName)."
}

#endregion

####################################################################
#region Function Definitions
####################################################################
function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
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

####################################################################
#region Connect to Microsoft Graph
####################################################################

try {
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

#endregion

####################################################################
#region Get all devices based on registered users
####################################################################

Write-Output "Querying devices..."
Write-Output "  Note: Depending on the number of devices in the tenant, this process can take several minutes!"
$property = 'id,deviceId,displayName,registeredUsers'

$AllDevices_BasedOnUsers = @()
$uri = "https://graph.microsoft.com/v1.0/devices?`$select=$property&`$expand=registeredUsers"

$AllDevices_BasedOnUsers = Get-GraphPagedResult -Uri $uri

Write-Output "  Retrieved $($AllDevices_BasedOnUsers.Count) devices from the tenant."

# Retrieve all Intune managed devices to determine Intune presence per device (and to filter, if requested)
Write-Output "Querying Intune managed devices..."
$intuneManagedDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=azureADDeviceId"
$intuneDeviceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($managedDevice in $intuneManagedDevices) {
    if ($managedDevice.azureADDeviceId) {
        [void]$intuneDeviceIds.Add([string]$managedDevice.azureADDeviceId)
    }
}
Write-Output "  Retrieved $($($intuneManagedDevices | Measure-Object).Count) managed devices from Intune."

if ($IntuneOnlyDevices) {
    $AllDevices_BasedOnUsers = $AllDevices_BasedOnUsers | Where-Object { $_.deviceId -and $intuneDeviceIds.Contains([string]$_.deviceId) }
    Write-Output "  Only devices present in Intune are considered: $($($AllDevices_BasedOnUsers | Measure-Object).Count) devices remain."
}

$raw = $AllDevices_BasedOnUsers | Where-Object { $_.RegisteredUsers.Count -gt 0 } | Group-Object { $_.RegisteredUsers.Id } | Where-Object Count -GT 5

#endregion

####################################################################
#region Prepare output
####################################################################

# Prepare output. Should contain the user ID, the UPN, and the number of devices
$Output = @()

foreach ($group in $raw) {
    $objectId = $group.Name
    $upn = ($group.Group | Select-Object -First 1).RegisteredUsers.UserPrincipalName
    $displayName = ($group.Group | Select-Object -First 1).RegisteredUsers.DisplayName
    $deviceCount = $group.Count

    $Output += [PSCustomObject]@{
        ObjectId    = $objectId
        DisplayName = $displayName
        UPN         = $upn
        DeviceCount = $deviceCount
    }
}

Write-Output ""
if ($($Output | Measure-Object).Count -eq 0) {
    Write-Output "No users found with more than five devices."
}
else {
    Write-Output "Found $($($Output | Measure-Object).Count) users with more than five devices:"
    $Output | Sort-Object DeviceCount -Descending | Format-Table
}

#endregion

######################################################################
#region CSV Export (if needed for download link or email)
######################################################################

$totalUsers = ($Output | Measure-Object).Count
$csvFiles = @()
$tempDir = $null
$detailedOutput = @()
$fileName_Summary = "UsersWithMoreThan5Devices_Summary.csv"
$fileName_Details = "UsersWithMoreThan5Devices_Details.csv"

if (($CreateDownloadLink -or $EmailTo) -and $totalUsers -gt 0) {
    Write-RjRbLog -Message "Found $totalUsers users with more than 5 devices - preparing CSV export" -Verbose

    # Create temporary directory for CSV files
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "UsersWithMultipleDevicesReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

    # Export summary to CSV
    $csvFile = Join-Path $tempDir $fileName_Summary
    $Output | Sort-Object DeviceCount -Descending | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
    Write-Verbose "Exported summary data to: $csvFile"
    $csvFiles += $csvFile

    # Create detailed device list for each user
    $detailedCsvFile = Join-Path $tempDir $fileName_Details

    foreach ($group in $raw) {
        $objectId = $group.Name
        $upn = ($group.Group | Select-Object -First 1).RegisteredUsers.UserPrincipalName
        $displayName = ($group.Group | Select-Object -First 1).RegisteredUsers.DisplayName

        foreach ($device in $group.Group) {
            $deviceEntry = [ordered]@{
                UserObjectId    = $objectId
                UserDisplayName = $displayName
                UserUPN         = $upn
                DeviceObjectId  = $device.Id
                EntraIDDeviceID = $device.deviceId
                DeviceName      = if ($device.DisplayName) { $device.DisplayName } else { "N/A" }
            }
            if (-not $IntuneOnlyDevices) {
                $deviceEntry.InIntune = if ($device.deviceId -and $intuneDeviceIds.Contains([string]$device.deviceId)) { "yes" } else { "no" }
            }
            $detailedOutput += [PSCustomObject]$deviceEntry
        }
    }

    $detailedOutput | Export-Csv -Path $detailedCsvFile -NoTypeInformation -Encoding UTF8
    Write-Verbose "Exported detailed device data to: $detailedCsvFile"
    $csvFiles += $detailedCsvFile
}

#endregion

######################################################################
#region Upload / Download Link (if CreateDownloadLink is enabled)
######################################################################

if ($CreateDownloadLink) {
    Write-Output ""
    if ($totalUsers -gt 0) {
        Write-Output "Uploading report files to storage account..."

        # Publish-RjRbFilesToStorageContainer authenticates against Azure (Az.Accounts) and
        # transparently connects the managed identity if no Az context is active.
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $csvFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        foreach ($uploadResult in $uploadResults) {
            Write-Output "Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }
    else {
        Write-Output "No users with more than five devices were found - skipping report upload."
    }
}

#endregion

######################################################################
#region Send Email Report (if requested)
######################################################################

if ($EmailTo) {
    Write-Output ""
    Write-Output "Preparing email report..."

    # Get tenant information
    try {
        $tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
        if ($tenant.value -and (($(($tenant.value) | Measure-Object).Count) -gt 0)) {
            $tenant = $tenant.value[0]
        }
        $tenantDisplayName = $tenant.displayName
        $tenantId = $tenant.id
        Write-RjRbLog -Message "Tenant: $tenantDisplayName ($tenantId)" -Verbose
    }
    catch {
        Write-Warning "Warning: Could not retrieve tenant information: $($_.Exception.Message) - proceeding without tenant name."
        $tenantDisplayName = ""
    }

    if ($totalUsers -eq 0) {
        # No users found - send email without attachments
        Write-RjRbLog -Message "No users found with more than 5 devices - sending notification email" -Verbose

        $markdownContent = @"
# Users with More Than 5 Devices Report

## Summary

✅ **Good News!** No users were found with more than 5 devices registered in Entra ID.
$(if ($IntuneOnlyDevices) { "`n**Scope:** Only devices present in Intune were considered for this report.`n" })

This indicates:
- Users are following device management policies
- No excessive device registrations detected
- Healthy device distribution across the organization

## Report Details

| Metric | Value |
|--------|-------|
| **Users with >5 Devices** | 0 |
| **Report Date** | $(Get-Date -Format 'yyyy-MM-dd HH:mm') |
| **Tenant** | $($tenantDisplayName) |

---

*This email was automatically generated. Please do not reply to this email.*

"@

        $emailSubject = "Users with More Than 5 Devices Report - No Issues Found - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"

    }
    else {
        # Users found - send detailed report (CSV files were already exported above)
        Write-RjRbLog -Message "Found $totalUsers users with more than 5 devices - preparing detailed report" -Verbose

        # Calculate statistics
        $totalDevices = ($detailedOutput | Measure-Object).Count
        $avgDevicesPerUser = if ($totalUsers -gt 0) { [math]::Round($totalDevices / $totalUsers, 2) } else { 0 }
        $maxDevices = ($Output | Measure-Object -Property DeviceCount -Maximum).Maximum
        $minDevices = ($Output | Measure-Object -Property DeviceCount -Minimum).Minimum

        # Create markdown content for email with detailed findings
        $markdownContent = @"
# Users with More Than 5 Devices Report

This report identifies users who have more than 5 devices registered in Entra ID.
$(if ($IntuneOnlyDevices) { "`n**Scope:** Only devices present in Intune were considered for this report.`n" })

## Summary Statistics

Based on the filtered data (users with >5 devices), the following statistics were calculated.
Note that these statistics only consider users who meet the >5 devices criteria.

| Metric | Value |
|--------|-------|
| **Total Users with >5 Devices** | $totalUsers |
| **Total Devices** | $totalDevices |
| **Average Devices per User** | $avgDevicesPerUser |
| **Maximum Devices (Single User)** | $maxDevices |
| **Minimum Devices** | $minDevices |

## Top 20 Users by Device Count

| User Display Name | User Principal Name | Device Count |
|-------------------|---------------------|--------------|
$(
    $Output | Sort-Object DeviceCount -Descending | Select-Object -First 20 | ForEach-Object {
        "| $($_.DisplayName) | $($_.UPN) | $($_.DeviceCount) |"
    }
)

## Report Details

### Summary File
- **File:** $($fileName_Summary)
- **Count:** $($totalUsers) users
- Contains user information and device counts

### Detailed File
- **File:** $($fileName_Details)
- **Count:** $($totalDevices) device entries
- Contains detailed device information for each user

## Recommendations

### Device Management Best Practices

🔍 **Review Device Assignments:**
- Users with many devices may have old/inactive devices registered
- Consider implementing a device cleanup policy
- Review if all devices are actively used

🛡️ **Security Considerations:**
- Multiple devices increase the attack surface
- Ensure all devices comply with security policies
- Verify that unused devices are properly decommissioned

📋 **Compliance & Licensing:**
- Check if device counts align with licensing agreements
- Ensure proper MDM/MAM coverage across all devices
- Consider user education on device management

### Suggested Actions

1. **Contact High-Device-Count Users:**
   - Verify all registered devices are legitimate
   - Request removal of unused/old devices
   - Provide guidance on device management

2. **Implement Device Limits:**
   - Consider setting maximum device limits per user
   - Create automated workflows for device approval
   - Establish regular device audits

3. **Monitor Trends:**
   - Track device registration patterns
   - Identify users who frequently exceed limits
   - Adjust policies based on organizational needs

## Data Export Information

The attached CSV files contain:
- **Summary:** User Object ID, Display Name, UPN, and Device Count
- **Details:** Complete device list for each user including the device object ID, the Entra ID device ID and the device name$(if (-not $IntuneOnlyDevices) { ", plus an ""InIntune"" column indicating whether the device is present in Intune" })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Users with More Than 5 Devices Report - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"
    }

    # Send email (with or without attachments depending on findings)
    try {
        if ($totalUsers -gt 0) {
            Write-RjRbLog -Message "Sending email with $($csvFiles.Count) attachment(s)" -Verbose
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -Attachments $csvFiles `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version
        }
        else {
            Write-RjRbLog -Message "Sending email without attachments" -Verbose
            Send-RjReportEmail `
                -EmailFrom $EmailFrom `
                -EmailTo $EmailTo `
                -Subject $emailSubject `
                -MarkdownContent $markdownContent `
                -TenantDisplayName $tenantDisplayName `
                -ReportVersion $Version
        }


        Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
        Write-Output "✅ Report generated and sent successfully"
        Write-Output "📧 Recipient: $($EmailTo)"
        if ($totalUsers -gt 0) {
            Write-Output "👥 Users reported: $totalUsers"
            Write-Output "📱 Total devices: $($detailedOutput.Count)"
        }
        else {
            Write-Output "✅ No users with more than 5 devices found"
        }
    }
    catch {
        Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to send email report: $($_.Exception.Message)"
    }
    finally {
        # Clean up temporary files (only if they were created)
        if ($totalUsers -gt 0) {
            try {
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force
                    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
                }
            }
            catch {
                Write-RjRbLog -Message "Warning: Could not clean up temporary directory: $($_.Exception.Message)" -Verbose
            }
        }
    }
}

#endregion

######################################################################
#region Cleanup
######################################################################

# Cleanup temporary files (covers the download-link-only case; the email path cleans up in its finally block)
if ($tempDir -and (Test-Path $tempDir)) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-RjRbLog -Message "Cleaned up temporary directory: $($tempDir)" -Verbose
}

#endregion