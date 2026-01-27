<#
.SYNOPSIS
    Reports users with more than five registered devices in Entra ID.

.DESCRIPTION
    This script queries all devices and their registered users, and reports users who have more than five devices registered.
    The output includes the user's Object ID, UPN, display name, and the number of devices.

    Optionally, the report can be sent via email with a CSV attachment containing detailed device information for each user.

.PARAMETER EmailTo
    If specified, an email with the report will be sent to the provided address(es).
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

.PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization.

.PARAMETER CallerName
    Internal parameter for tracking purposes

.INPUTS
    RunbookCustomization: {
        "Parameters": {
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.34.0" }

param (
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

$Version = "1.1.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
if ($EmailTo) {
    Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
    Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
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

#endregion

####################################################################
#region Function Definitions
####################################################################
function Get-AllGraphPage {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Get-AllGraphPage takes an initial Microsoft Graph API URI and retrieves all items across
        multiple pages by following the @odata.nextLink property in the response. It aggregates
        all items into a single array and returns it.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-AllGraphPage -Uri "https://graph.microsoft.com/v1.0/applications"
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
        elseif ($response.'@odata.context') {
            # Single item response
            $allResults += $response
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $nextLink = $response.'@odata.nextLink'
        }
        else {
            $nextLink = $null
        }
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
$property = 'id,registeredUsers'

$AllDevices_BasedOnUsers = @()
$uri = "https://graph.microsoft.com/v1.0/devices?`$select=$property&`$expand=registeredUsers"

$AllDevices_BasedOnUsers = Get-AllGraphPage -Uri $uri

Write-Output "  Retrieved $($AllDevices_BasedOnUsers.Count) devices from the tenant."

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

    # Check if any users were found
    $totalUsers = ($Output | Measure-Object).Count
    $csvFiles = @()

    if ($totalUsers -eq 0) {
        # No users found - send email without attachments
        Write-RjRbLog -Message "No users found with more than 5 devices - sending notification email" -Verbose

        $markdownContent = @"
# Users with More Than 5 Devices Report

## Summary

✅ **Good News!** No users were found with more than 5 devices registered in Entra ID.

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

"@

        $emailSubject = "Users with More Than 5 Devices Report - No Issues Found - $($tenantDisplayName) - $(Get-Date -Format 'yyyy-MM-dd')"

    }
    else {
        # Users found - create CSV files and send detailed report
        Write-RjRbLog -Message "Found $totalUsers users with more than 5 devices - preparing detailed report" -Verbose

        # Create temporary directory for CSV files
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "UsersWithMultipleDevicesReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-RjRbLog -Message "Created temp directory: $tempDir" -Verbose

        # Export summary to CSV
        $fileName_Summary = "UsersWithMoreThan5Devices_Summary.csv"
        $csvFile = Join-Path $tempDir $fileName_Summary
        $Output | Sort-Object DeviceCount -Descending | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Verbose "Exported summary data to: $csvFile"
        $csvFiles += $csvFile

        # Create detailed device list for each user
        $fileName_Details = "UsersWithMoreThan5Devices_Details.csv"
        $detailedCsvFile = Join-Path $tempDir $fileName_Details
        $detailedOutput = @()

        foreach ($group in $raw) {
            $objectId = $group.Name
            $upn = ($group.Group | Select-Object -First 1).RegisteredUsers.UserPrincipalName
            $displayName = ($group.Group | Select-Object -First 1).RegisteredUsers.DisplayName

            foreach ($device in $group.Group) {
                $detailedOutput += [PSCustomObject]@{
                    UserObjectId    = $objectId
                    UserDisplayName = $displayName
                    UserUPN         = $upn
                    DeviceId        = $device.Id
                    DeviceName      = if ($device.DisplayName) { $device.DisplayName } else { "N/A" }
                }
            }
        }

        $detailedOutput | Export-Csv -Path $detailedCsvFile -NoTypeInformation -Encoding UTF8
        Write-Verbose "Exported detailed device data to: $detailedCsvFile"
        $csvFiles += $detailedCsvFile

        # Calculate statistics
        $totalDevices = ($detailedOutput | Measure-Object).Count
        $avgDevicesPerUser = if ($totalUsers -gt 0) { [math]::Round($totalDevices / $totalUsers, 2) } else { 0 }
        $maxDevices = ($Output | Measure-Object -Property DeviceCount -Maximum).Maximum
        $minDevices = ($Output | Measure-Object -Property DeviceCount -Minimum).Minimum

        # Create markdown content for email with detailed findings
        $markdownContent = @"
# Users with More Than 5 Devices Report

This report identifies users who have more than 5 devices registered in Entra ID.

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
- **Details:** Complete device list for each user including Device IDs and Names
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