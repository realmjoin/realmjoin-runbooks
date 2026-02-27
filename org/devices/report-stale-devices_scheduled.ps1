<#
    .SYNOPSIS
    Scheduled report of stale devices based on last activity date and platform.

    .DESCRIPTION
    Identifies and lists devices that haven't been active for a specified number of days.
    Automatically sends a report via email.

    .NOTES
    This runbook generates a comprehensive report of stale devices and delivers it via email.
    The report includes device details, platform breakdowns, and exports a CSV file for further analysis.

    Prerequisites:
    - EmailFrom parameter must be configured in runbook customization (RJReport.EmailSender setting)

    Common Use Cases:
    - Regular device inventory audits and compliance reporting
    - Identifying devices for retirement or decommissioning
    - Security reviews to find potentially lost devices
    - Monitoring device health across the organization
    - Using MaxDays parameter for staged reporting (e.g., 30-60 days, 60-90 days)
    - User scope filtering to focus on specific departments or exclude service accounts

    The runbook supports optional user scope filtering to include or exclude devices based on primary user group membership.

    .PARAMETER Days
    Number of days without activity to be considered stale.

    .PARAMETER MaxDays
    Optional maximum number of days without activity. If set, only devices inactive between Days and MaxDays will be included.

    .PARAMETER Windows
    Include Windows devices in the results.

    .PARAMETER MacOS
    Include macOS devices in the results.

    .PARAMETER iOS
    Include iOS devices in the results.

    .PARAMETER Android
    Include Android devices in the results.

    .PARAMETER EmailTo
    Can be a single address or multiple comma-separated addresses (string).
    The function sends individual emails to each recipient for privacy reasons.

    .PARAMETER EmailFrom
    The sender email address. This needs to be configured in the runbook customization

    .PARAMETER UseUserScope
    Enable user scope filtering to include or exclude devices based on primary user group membership.

    .PARAMETER IncludeUserGroup
    Only include devices whose primary users are members of this group. Requires UseUserScope to be enabled.

    .PARAMETER ExcludeUserGroup
    Exclude devices whose primary users are members of this group. Requires UseUserScope to be enabled.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Days": {
                "DisplayName": "Minimum Days Without Activity"
            },
            "MaxDays": {
                "DisplayName": "(Optional) Maximum Days Without Activity"
            },
            "Windows": {
                "DisplayName": "Include Windows Devices"
            },
            "MacOS": {
                "DisplayName": "Include macOS Devices"
            },
            "iOS": {
                "DisplayName": "Include iOS Devices"
            },
            "Android": {
                "DisplayName": "Include Android Devices"
            },
            "CallerName": {
                "Hide": true
            },
            "EmailTo": {
                "DisplayName": "Recipient Email Address(es)"
            },
            "EmailFrom": {
                "Hide": true
            },
            "UseUserScope": {
                "DisplayName": "Use User Scope Filtering",
                "Hide": true
            },
            "IncludeUserGroup": {
                "DisplayName": "Users to include (Group)",
                "Hide": true
            },
            "ExcludeUserGroup": {
                "DisplayName": "Users to exclude (Group)",
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "(Optional) Enable user scope filtering to include or exclude devices based on primary user group membership.",
                "DisplayAfter": "EmailFrom",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - filter by group membership",
                            "Customization": {
                                "Hide": [],
                                "Show": ["IncludeUserGroup", "ExcludeUserGroup"],
                                "Default": {
                                    "UseUserScope": true
                                }
                            }
                        },
                        {
                            "Display": "No - include all devices",
                            "Customization": {
                                "Hide": ["IncludeUserGroup", "ExcludeUserGroup"],
                                "Default": {
                                    "UseUserScope": false
                                }
                            },
                            "ParameterValue": false
                        }
                    ]
                }
            }
        ]
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [int] $Days = 30,
    [int] $MaxDays = $null,
    [bool] $Windows = $true,
    [bool] $MacOS = $true,
    [bool] $iOS = $true,
    [bool] $Android = $true,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string]$EmailFrom,
    [bool] $UseUserScope = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Include Users from Group" } )]
    [string]$IncludeUserGroup,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude Users from Group" } )]
    [string]$ExcludeUserGroup,
    [Parameter(Mandatory = $true)]
    [string] $EmailTo,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Email To: $EmailTo" -Verbose
Write-RjRbLog -Message "Email From: $EmailFrom" -Verbose
Write-RjRbLog -Message "Days: $Days" -Verbose
Write-RjRbLog -Message "MaxDays: $MaxDays" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "UseUserScope: $UseUserScope" -Verbose
Write-RjRbLog -Message "IncludeUserGroup: $IncludeUserGroup" -Verbose
Write-RjRbLog -Message "ExcludeUserGroup: $ExcludeUserGroup" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

# Validate Email Addresses
if (-not $EmailFrom) {
    Write-Warning -Message "The sender email address is required. This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md" -Verbose
    throw "This needs to be configured in the runbook customization. Documentation: https://github.com/realmjoin/realmjoin-runbooks/tree/master/docs/general/setup-email-reporting.md"
    exit
}

if (-not $EmailTo) {
    Write-RjRbLog -Message "The recipient email address is required. It could be a single address or multiple comma-separated addresses." -Verbose
    throw "The recipient email address is required."
}

#endregion

########################################################
#region     Email Function Definitions
########################################################

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

# Connect to Microsoft Graph
Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

# Get tenant information
Write-Output "## Retrieving tenant information..."
$tenantDisplayName = "Unknown Tenant"
try {
    $organizationUri = "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
    $organizationResponse = Invoke-MgGraphRequest -Uri $organizationUri -Method GET -ErrorAction Stop

    if ($organizationResponse.value -and $organizationResponse.value.Count -gt 0) {
        $tenantDisplayName = $organizationResponse.value[0].displayName
        Write-Output "## Tenant: $($tenantDisplayName)"
    }
    elseif ($organizationResponse.displayName) {
        $tenantDisplayName = $organizationResponse.displayName
        Write-Output "## Tenant: $($tenantDisplayName)"
    }
}
catch {
    Write-RjRbLog -Message "Failed to retrieve tenant information: $($_.Exception.Message)" -Verbose
}

# Connect RJ RunbookHelper for email reporting
Write-Output "Graph connection for RJ RunbookHelper..."
Connect-RjRbGraph

Write-Output ""

# Calculate the date threshold for stale devices
$beforeDate = (Get-Date).AddDays(-$Days) | Get-Date -Format "yyyy-MM-dd"

# Prepare filter for the Graph API query
if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    # Filter for devices inactive between Days and MaxDays
    $afterDate = (Get-Date).AddDays(-$MaxDays) | Get-Date -Format "yyyy-MM-dd"
    $filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z and lastSyncDateTime ge $($afterDate)T00:00:00Z"
    Write-RjRbLog -Message "Filtering devices inactive between $Days and $MaxDays days" -Verbose
}
else {
    # Filter for devices inactive for at least Days
    $filter = "lastSyncDateTime le $($beforeDate)T00:00:00Z"
    Write-RjRbLog -Message "Filtering devices inactive for at least $Days days" -Verbose
}

# Define the properties to select
$selectProperties = @(
    'deviceName'
    'lastSyncDateTime'
    'enrolledDateTime'
    'userPrincipalName'
    'id'
    'serialNumber'
    'manufacturer'
    'model'
    'operatingSystem'
    'osVersion'
    'complianceState'
)
$selectString = ($selectProperties -join ',')

# Get all stale devices
if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    Write-Output "## Listing devices inactive between $($Days) and $($MaxDays) days"
}
else {
    Write-Output "## Listing devices not active for at least $($Days) days"
}
Write-Output ""

$encodedFilter = [System.Uri]::EscapeDataString($filter)
$devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$selectString&`$filter=$encodedFilter"
$devices = Get-AllGraphPage -Uri $devicesUri

########################################################
#region     User Scope Filtering
########################################################

# Get group membership for filtering if UseUserScope is enabled
$includeUserIds = @()
$excludeUserIds = @()

if ($UseUserScope) {
    Write-Output ""
    Write-Output "## Processing user scope filtering..."

    # Get users from include group
    if ($IncludeUserGroup) {
        Write-Output "Getting members from include group..."
        try {
            $includeGroupUri = "https://graph.microsoft.com/v1.0/groups/$IncludeUserGroup/members?`$select=id,userPrincipalName"
            $includeMembers = Get-AllGraphPage -Uri $includeGroupUri
            $includeUserIds = $includeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' } | ForEach-Object { $_.id }
            Write-Output "Include group contains $($includeUserIds.Count) users"
        }
        catch {
            Write-Warning "Failed to retrieve include group members: $_"
        }
    }

    # Get users from exclude group
    if ($ExcludeUserGroup) {
        Write-Output "Getting members from exclude group..."
        try {
            $excludeGroupUri = "https://graph.microsoft.com/v1.0/groups/$ExcludeUserGroup/members?`$select=id,userPrincipalName"
            $excludeMembers = Get-AllGraphPage -Uri $excludeGroupUri
            $excludeUserIds = $excludeMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' } | ForEach-Object { $_.id }
            Write-Output "Exclude group contains $($excludeUserIds.Count) users"
        }
        catch {
            Write-Warning "Failed to retrieve exclude group members: $_"
        }
    }
    Write-Output ""
}

#endregion

# Filter devices by platform based on user selection
$filteredDevices = @()

foreach ($device in $devices) {
    $include = $false

    # Check if the device's platform matches any of the selected platforms
    if ($Windows -and $device.operatingSystem -eq "Windows") {
        $include = $true
    }
    elseif ($MacOS -and $device.operatingSystem -eq "macOS") {
        $include = $true
    }
    elseif ($iOS -and $device.operatingSystem -eq "iOS") {
        $include = $true
    }
    elseif ($Android -and $device.operatingSystem -eq "Android") {
        $include = $true
    }

    if ($include) {
        # Try to get additional user information
        if ($device.userPrincipalName) {
            try {
                $encodedUserPrincipalName = [System.Uri]::EscapeDataString($device.userPrincipalName)
                $userUri = "https://graph.microsoft.com/v1.0/users/{0}?`$select=id,displayName,city,usageLocation" -f $encodedUserPrincipalName
                $userInfo = Invoke-MgGraphRequest -Uri $userUri -Method GET -ErrorAction SilentlyContinue

                if ($userInfo) {
                    $device | Add-Member -Name "userDisplayName" -Value $userInfo.displayName -MemberType "NoteProperty" -Force
                    $device | Add-Member -Name "userLocation" -Value "$($userInfo.city), $($userInfo.usageLocation)" -MemberType "NoteProperty" -Force

                    # Apply user scope filtering if enabled
                    if ($UseUserScope) {
                        $userId = $userInfo.id

                        # Apply include filter
                        if ($IncludeUserGroup -and ($includeUserIds.Count -gt 0) -and ($userId -notin $includeUserIds)) {
                            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' not in include group" -Verbose
                            continue
                        }

                        # Apply exclude filter
                        if ($ExcludeUserGroup -and ($excludeUserIds.Count -gt 0) -and ($userId -in $excludeUserIds)) {
                            Write-RjRbLog -Message "Skipping device '$($device.deviceName)' - primary user '$($device.userPrincipalName)' in exclude group" -Verbose
                            continue
                        }
                    }
                }
            }
            catch {
                Write-RjRbLog -Message "Could not retrieve user info for $($device.userPrincipalName): $($_.Exception.Message)" -Verbose
            }
        }

        $filteredDevices += $device
    }
}

# Display summary counts
Write-Output "## Summary of stale devices for $($tenantDisplayName):"
Write-Output "Total devices: $($filteredDevices.Count)"

if ($Windows) {
    $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" } | Measure-Object).Count
    Write-Output "Windows devices: $($windowsCount)"
}

if ($MacOS) {
    $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" } | Measure-Object).Count
    Write-Output "macOS devices: $($macOSCount)"
}

if ($iOS) {
    $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" } | Measure-Object).Count
    Write-Output "iOS devices: $($iOSCount)"
}

if ($Android) {
    $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" } | Measure-Object).Count
    Write-Output "Android devices: $($androidCount)"
}

Write-Output ""
Write-Output "## Detailed list of stale devices:"
Write-Output ""

# Convert to PSCustomObject array for consistent formatting
$displayDevices = @()
foreach ($device in $filteredDevices) {
    $displayDevices += [PSCustomObject]@{
        LastSync      = if ($device.lastSyncDateTime) { Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd } else { "N/A" }
        DeviceName    = if ($device.deviceName -and $device.deviceName.Length -gt 15) { $device.deviceName.Substring(0, 14) + ".." } elseif ($device.deviceName) { $device.deviceName } else { "N/A" }
        DeviceID      = if ($device.id -and $device.id.Length -gt 15) { $device.id.Substring(0, 14) + ".." } elseif ($device.id) { $device.id } else { "N/A" }
        SerialNumber  = if ($device.serialNumber -and $device.serialNumber.Length -gt 15) { $device.serialNumber.Substring(0, 14) + ".." } elseif ($device.serialNumber) { $device.serialNumber } else { "N/A" }
        PrimaryUser   = if ($device.userPrincipalName -and $device.userPrincipalName.Length -gt 20) { $device.userPrincipalName.Substring(0, 19) + ".." } elseif ($device.userPrincipalName) { $device.userPrincipalName } else { "N/A" }
    }
}

# Display the filtered devices
$displayDevices | Sort-Object -Property LastSync | Format-Table -AutoSize

# Create Markdown content for email
Write-Output ""
Write-Output "## Preparing email report to send to $($EmailTo)"

# Prepare additional metadata for the report body
$selectedPlatforms = @()
if ($Windows) { $selectedPlatforms += 'Windows' }
if ($MacOS) { $selectedPlatforms += 'macOS' }
if ($iOS) { $selectedPlatforms += 'iOS' }
if ($Android) { $selectedPlatforms += 'Android' }
$platformSummary = if ($selectedPlatforms.Count -gt 0) { $selectedPlatforms -join ', ' } else { 'No specific platforms selected' }
$totalDevicesEvaluated = ($devices | Measure-Object).Count

if ($filteredDevices.Count -gt 10) {
    $filteredDevices_moreThan10 = $true
}
# Build Markdown content
$inactivityPeriodText = if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    "between **$Days and $MaxDays days**"
} else {
    "at least **$Days days**"
}

$markdownContent = if ($filteredDevices.Count -eq 0) {
    @"
# Stale Devices Report

Great news — no managed devices matched the stale device criteria (inactive for $($inactivityPeriodText)) for the selected platforms.

## What We Checked

- Inactivity threshold: $($inactivityPeriodText)
- Platforms evaluated: $($platformSummary)
- Devices evaluated: $($totalDevicesEvaluated)
$(if ($UseUserScope) {
    $filterInfo = @()
    if ($IncludeUserGroup) { $filterInfo += "Include group: $($includeUserIds.Count) users" }
    if ($ExcludeUserGroup) { $filterInfo += "Exclude group: $($excludeUserIds.Count) users" }
    "- User scope filtering: $($filterInfo -join ', ')"
})

## Recommendations

- Continue to monitor this report regularly to spot newly idle devices early
- Keep lifecycle policies and retirement procedures current
- Ensure device owners stay informed about required check-ins
"@
}
else {
    @"
# Stale Devices Report

This report shows devices that have been inactive for $($inactivityPeriodText).
$(if ($UseUserScope) {
    $filterInfo = @()
    if ($IncludeUserGroup) { $filterInfo += "Include group with $($includeUserIds.Count) users" }
    if ($ExcludeUserGroup) { $filterInfo += "Exclude group with $($excludeUserIds.Count) users" }
    "`n**User Scope Filtering Applied:** $($filterInfo -join ', ')"
})

## Summary Statistics

| Metric | Count |
|--------|-------|
| **Total Stale Devices** | $($filteredDevices.Count) |
$(
    $summaryLines = @()
    if ($Windows) {
        $windowsCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Windows" } | Measure-Object).Count
        $summaryLines += "| **Windows Devices** | $windowsCount |"
    }
    if ($MacOS) {
        $macOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "macOS" } | Measure-Object).Count
        $summaryLines += "| **macOS Devices** | $macOSCount |"
    }
    if ($iOS) {
        $iOSCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "iOS" } | Measure-Object).Count
        $summaryLines += "| **iOS Devices** | $iOSCount |"
    }
    if ($Android) {
        $androidCount = ($filteredDevices | Where-Object { $_.operatingSystem -eq "Android" } | Measure-Object).Count
        $summaryLines += "| **Android Devices** | $androidCount |"
    }
    $summaryLines -join "`n"
)

$(if ($filteredDevices_moreThan10) {
    "## Top 10 Stale Devices (by Last Sync Date)"
    ""
    "This table lists the top 10 devices that have been inactive the longest, based on the current defined threshold ($($inactivityPeriodText))."
    ""
} else {
    "## Stale Devices"
    ""
    "This table lists all devices matching the inactivity criteria ($($inactivityPeriodText))."
    ""
})


$(if ($filteredDevices.Count -gt 0) {
    $sortedDevices = $filteredDevices | Sort-Object -Property lastSyncDateTime

    # If more than 10 devices, only show top 10 in email (oldest first)
    $devicesToShow = if ($filteredDevices.Count -gt 10) {
        $sortedDevices | Select-Object -First 10
    } else {
        $sortedDevices
    }

    # Create markdown table
    $table = @"
| Last Sync | Device Name | Operating System | Serial Number | Primary User |
|-----------|-------------|------------------|---------------|--------------|
"@

    foreach ($device in $devicesToShow) {
        $lastSync = Get-Date $device.lastSyncDateTime -Format yyyy-MM-dd
        $deviceName = $device.deviceName
        $os = $device.operatingSystem
        $serialNumber = $device.serialNumber
        $user = $device.userPrincipalName

        $table += "`n| $($lastSync) | $($deviceName) | $($os) | $($serialNumber) | $($user) |"
    }

    $table
} else {
    "No stale devices found matching the selected criteria."
})

## Recommendations

### Review and Action

Please review the listed devices and take appropriate action:
- Contact device owners to verify device status
- Consider retiring devices that are no longer in use
- Update device records if devices have been decommissioned
- Ensure compliance with your organization's device lifecycle policy

### Device Lifecycle Management

Regularly reviewing stale devices helps:
- Maintain accurate device inventory
- Reduce security risks from unmanaged devices
- Optimize license utilization
- Ensure compliance with organizational policies

## Attachments

The .csv-file attached to this email contains the full list of stale devices for further analysis.

"@
}

# Create CSV file in current location
$csvFileNameSuffix = if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    "$($Days)-$($MaxDays)Days"
} else {
    "$($Days)Days"
}
$csvFilePath = Join-Path -Path $((Get-Location).Path) -ChildPath "StaleDevicesReport_$($tenantDisplayName)_$($csvFileNameSuffix).csv"
$filteredDevices | Export-Csv -Path $csvFilePath -NoTypeInformation
$attachments = @($csvFilePath)
Write-RjRbLog -Message "Exported stale devices to CSV: $($csvFilePath)" -Verbose

# Send email report
$emailSubjectSuffix = if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
    "$($Days)-$($MaxDays) days"
} else {
    "$($Days)+ days"
}
$emailSubject = "Stale Devices Report - $($tenantDisplayName) - $($emailSubjectSuffix)"

Write-Output "Sending report to '$($EmailTo)'..."
try {
    Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $attachments

    Write-RjRbLog -Message "Email report sent successfully to: $($EmailTo)" -Verbose
    Write-Output "Stale devices report generated and sent successfully"
    Write-Output "Recipient: $($EmailTo)"
    Write-Output "Total Stale Devices: $($filteredDevices.Count)"
    if ($null -ne $MaxDays -and $MaxDays -gt $Days) {
        Write-Output "Inactivity range: $Days to $MaxDays days"
    }
    else {
        Write-Output "Days threshold: $Days days (minimum)"
    }

    if ($UseUserScope) {
        Write-Output ""
        Write-Output "User Scope Filtering:"
        if ($IncludeUserGroup) {
            Write-Output "  - Include group: $($includeUserIds.Count) users"
        }
        if ($ExcludeUserGroup) {
            Write-Output "  - Exclude group: $($excludeUserIds.Count) users"
        }
    }
}
catch {
    Write-Output "Error sending email: $_"
    Write-RjRbLog -Message "Error sending email: $_" -Verbose
    throw "Failed to send email report: $($_.Exception.Message)"
}