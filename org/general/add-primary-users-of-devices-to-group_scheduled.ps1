<#
    .SYNOPSIS
    Sync primary users of Intune managed devices by platform into an Entra ID group

    .DESCRIPTION
    This runbook collects the primary users of all Intune managed devices matching the selected platform(s) and synchronizes them into a target Entra ID group. Users no longer assigned as primary user on any matching device are removed from the group. An optional include group restricts which users are eligible, and an optional exclude group prevents specific users from being added or keeps them removed.

    .PARAMETER TargetGroupId
    The Entra ID group to synchronize primary users into. Members of this group will be managed exclusively by this runbook.

    .PARAMETER Windows
    Include primary users of Windows devices. (OData Filter used "operatingSystem eq 'Windows'")

    .PARAMETER MacOS
    Include primary users of macOS devices. (OData Filter used "operatingSystem eq 'macOS'")

    .PARAMETER iOS
    Include primary users of iOS and iPadOS devices. (OData Filter used "operatingSystem eq 'iOS'")

    .PARAMETER Android
    Include primary users of Android devices. (OData Filter used "operatingSystem eq 'Android'")

    .PARAMETER AdvancedFilter
    Optional. Custom OData filter to apply when retrieving devices. Overrides the platform-based filters if provided. Example: startsWith(deviceName,'FWP-') and operatingSystem eq 'Windows' .

    .PARAMETER IncludeGroupId
    Optional. Only users who are members of this group are eligible to be added to the target group. Leave empty to consider all primary users.

    .PARAMETER ExcludeGroupId
    Optional. Users who are members of this group will not be added and will be removed from the target group if already present.

    .PARAMETER RemoveUsersWhenNoDeviceMatch
    When enabled (default), users who no longer have a primary device matching the selected platform(s) are removed from the target group. Disable to add-only mode — existing members are never removed.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "TargetGroupId": {
                "DisplayName": "Target Group (sync primary users into)",
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
            "AdvancedFilter": {
                "DisplayName": "Custom filter (overrides OS selection)",
            },
            "RemoveUsersWhenNoDeviceMatch": {
                "DisplayName": "Remove users who no longer have a matching device",
            },
            "IncludeGroupId": {
                "DisplayName": "Include users from group (optional)",
                "Hide": true
            },
            "ExcludeGroupId": {
                "DisplayName": "Exclude users from group (optional)",
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "(Optional) Filter eligible users by group membership.",
                "DisplayAfter": "RemoveUsersWhenNoDeviceMatch",
                "Default": false,
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - filter by group membership",
                            "Customization": {
                                "Hide": [],
                                "Show": ["IncludeGroupId", "ExcludeGroupId"]
                            }
                        },
                        {
                            "Display": "No - consider all primary users",
                            "Customization": {
                                "Hide": ["IncludeGroupId", "ExcludeGroupId"]
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

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Target Group" } )]
    [string]$TargetGroupId,

    [bool]$Windows = $false,
    [bool]$MacOS = $false,
    [bool]$iOS = $false,
    [bool]$Android = $false,

    [string]$AdvancedFilter = "",

    [bool]$RemoveUsersWhenNoDeviceMatch = $true,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Include users from group (optional)" } )]
    [string]$IncludeGroupId = "",

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Exclude users from group (optional)" } )]
    [string]$ExcludeGroupId = "",

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "TargetGroupId: $TargetGroupId" -Verbose
Write-RjRbLog -Message "Windows: $Windows" -Verbose
Write-RjRbLog -Message "MacOS: $MacOS" -Verbose
Write-RjRbLog -Message "iOS: $iOS" -Verbose
Write-RjRbLog -Message "Android: $Android" -Verbose
Write-RjRbLog -Message "AdvancedFilter: $AdvancedFilter" -Verbose
Write-RjRbLog -Message "IncludeGroupId: $IncludeGroupId" -Verbose
Write-RjRbLog -Message "ExcludeGroupId: $ExcludeGroupId" -Verbose
Write-RjRbLog -Message "RemoveUsersWhenNoDeviceMatch: $RemoveUsersWhenNoDeviceMatch" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

if (-not $Windows -and -not $MacOS -and -not $iOS -and -not $Android -and [string]::IsNullOrWhiteSpace($AdvancedFilter)) {
    Write-Error "At least one platform must be selected (Windows, MacOS, iOS, or Android), or provide a custom filter." -ErrorAction Continue
    throw "No platform selected."
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
        The initial Microsoft Graph API endpoint URI to query.
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

function Invoke-GraphBatch {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Requests
    )

    # Graph batch API: max 20 requests per call
    $batchSize = 20
    $responses = [System.Collections.Generic.List[object]]::new()

    for ($i = 0; $i -lt $Requests.Count; $i += $batchSize) {
        $chunk = $Requests[$i..([Math]::Min($i + $batchSize - 1, $Requests.Count - 1))]
        $batchBody = @{ requests = @($chunk) }
        $batchResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/`$batch" -Method POST -Body $batchBody
        $responses.AddRange([object[]]@($batchResult.responses))
    }

    return $responses
}

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

# Validate target group exists
try {
    $targetGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
    Write-RjRbLog -Message "Target Group:    $($targetGroup.displayName)" -Verbose
}
catch {
    Write-Error "Target group with ID '$TargetGroupId' was not found in Entra ID. Please verify the group exists." -ErrorAction Continue
    throw "Target group '$TargetGroupId' not found."
}

# Validate include group if specified
if ($IncludeGroupId) {
    try {
        $includeGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$IncludeGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
        Write-RjRbLog -Message "Include Group:   $($includeGroup.displayName)" -Verbose
    }
    catch {
        Write-Error "Include group with ID '$IncludeGroupId' was not found in Entra ID." -ErrorAction Continue
        throw "Include group '$IncludeGroupId' not found."
    }
}

# Validate exclude group if specified
if ($ExcludeGroupId) {
    try {
        $excludeGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId`?`$select=id,displayName" -Method GET -ErrorAction Stop
        Write-RjRbLog -Message "Exclude Group:   $($excludeGroup.displayName)" -Verbose
    }
    catch {
        Write-Error "Exclude group with ID '$ExcludeGroupId' was not found in Entra ID." -ErrorAction Continue
        throw "Exclude group '$ExcludeGroupId' not found."
    }
}

# Show selected platforms
$selectedPlatforms = @()
if ($Windows) { $selectedPlatforms += "Windows" }
if ($MacOS) { $selectedPlatforms += "macOS" }
if ($iOS) { $selectedPlatforms += "iOS" }
if ($Android) { $selectedPlatforms += "Android" }
Write-RjRbLog -Message "Platforms:       $($selectedPlatforms -join ', ')" -Verbose

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Collecting primary users from Intune devices..."
Write-Output "---------------------"
Write-Output "Note: This may take a while depending on the number of devices in your tenant."

# Build OData filter for selected operating systems
$osFilters = @()
if ($Windows) { $osFilters += "operatingSystem eq 'Windows'" }
if ($MacOS) { $osFilters += "operatingSystem eq 'macOS'" }
if ($iOS) { $osFilters += "operatingSystem eq 'iOS'" }
if ($Android) { $osFilters += "operatingSystem eq 'Android'" }
$osFilter = [System.Uri]::EscapeDataString("(" + ($osFilters -join " or ") + ")")

# Build Graph URI — apply OS filter; if an advanced filter is provided it replaces the OS filter entirely
$graphFilter = if (-not [string]::IsNullOrWhiteSpace($AdvancedFilter)) {
    [System.Uri]::EscapeDataString($AdvancedFilter)
} else {
    $osFilter
}

# Retrieve all managed devices
$allDevices = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=$graphFilter&`$select=id,deviceName,operatingSystem,userId")

Write-Output "Devices found:   $($allDevices.Count) (across selected platform(s))"

# Extract unique primary user IDs — skip devices without an assigned user
$desiredUserIds = @($allDevices |
    Where-Object { -not [string]::IsNullOrEmpty($_.userId) } |
    Select-Object -ExpandProperty userId |
    Sort-Object -Unique)
Write-Output "Unique primary users: $($desiredUserIds.Count)"

# Apply include scope filter — use HashSet for O(1) lookups
if ($IncludeGroupId) {
    Write-Output ""
    Write-Output "Applying include scope from '$($includeGroup.displayName)'..."
    $includeMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$IncludeGroupId/members?`$select=id")
    $includeSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($includeMembers | Where-Object { $_.id } | Select-Object -ExpandProperty id),
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $desiredUserIds = @($desiredUserIds | Where-Object { $includeSet.Contains($_) })
    Write-Output "Eligible users after include filter: $($desiredUserIds.Count)"
}

# Apply exclude scope filter — use HashSet for O(1) lookups
if ($ExcludeGroupId) {
    Write-Output ""
    Write-Output "Applying exclude scope from '$($excludeGroup.displayName)'..."
    $excludeMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$ExcludeGroupId/members?`$select=id")
    $excludeSet = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($excludeMembers | Where-Object { $_.id } | Select-Object -ExpandProperty id),
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $desiredUserIds = @($desiredUserIds | Where-Object { -not $excludeSet.Contains($_) })
    Write-Output "Eligible users after exclude filter: $($desiredUserIds.Count)"
}

# Get current members of target group (users only)
Write-Output ""
Write-Output "Getting current members of '$($targetGroup.displayName)'..."
$currentMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId/members?`$select=id,userPrincipalName")

# Filter to user objects only (groups can contain non-user members)
$currentUserMembers = @($currentMembers | Where-Object { $_.userPrincipalName })
$currentMemberIds = @($currentUserMembers | Select-Object -ExpandProperty id)
Write-Output "Current user members: $($currentMemberIds.Count)"

# Calculate diff using HashSets — O(n) instead of O(n²)
$desiredSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$desiredUserIds, [System.StringComparer]::OrdinalIgnoreCase)
$currentSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$currentMemberIds, [System.StringComparer]::OrdinalIgnoreCase)

$toAdd = @($desiredUserIds  | Where-Object { -not $currentSet.Contains($_) })
$toRemove = @($currentMemberIds | Where-Object { -not $desiredSet.Contains($_) })

Write-Output ""
Write-Output "Changes required:"
Write-Output "  Users to add:    $($toAdd.Count)"
Write-Output "  Users to remove: $($toRemove.Count)"

# Initialize counters for summary output
$addedCount = 0
$addFailedCount = 0
$removedCount = 0
$removeFailedCount = 0

# Add new members via Graph batch API (20 per batch call)
if ($toAdd.Count -gt 0) {
    Write-RjRbLog -Message "Adding $($toAdd.Count) user(s) via batch API..." -Verbose

    $addRequests = @($toAdd | ForEach-Object -Begin { $idx = 1 } -Process {
            @{
                id      = "$idx"
                method  = "POST"
                url     = "/groups/$TargetGroupId/members/`$ref"
                headers = @{ "Content-Type" = "application/json" }
                body    = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$_" }
            }
            $idx++
        })

    $addResponses = Invoke-GraphBatch -Requests $addRequests
    $addedCount = ($addResponses | Where-Object { $_.status -in 200, 201, 204 }).Count
    $alreadyExisted = ($addResponses | Where-Object { $_.status -eq 400 -and $_.body.error.message -like "*already exist*" }).Count
    $addFailedCount = $addResponses.Count - $addedCount - $alreadyExisted

    $addedCount += $alreadyExisted  # already-member is not an error

    Write-RjRbLog -Message "Added: $($addedCount) user(s)$(if ($addFailedCount -gt 0) { ", failed: $($addFailedCount)" })" -Verbose
    if ($addFailedCount -gt 0) {
        $addResponses | Where-Object { $_.status -notin 200, 201, 204 -and -not ($_.status -eq 400 -and $_.body.error.message -like "*already exist*") } | ForEach-Object {
            Write-RjRbLog -Message "Add failed (status $($_.status), id $($_.id)): $($_.body.error.message)" -Verbose
        }
    }
}

# Remove stale members via Graph batch API (20 per batch call)
if (-not $RemoveUsersWhenNoDeviceMatch) {
    Write-RjRbLog -Message "Removal is disabled. $($toRemove.Count) user(s) would have been removed but are kept in the group." -Verbose
    $toRemove = @()
}

if ($toRemove.Count -gt 0) {
    Write-RjRbLog -Message "Removing $($toRemove.Count) user(s) via batch API..." -Verbose

    # Build UPN lookup for verbose logging
    $upnLookup = @{}
    $currentUserMembers | ForEach-Object { $upnLookup[$_.id] = $_.userPrincipalName }

    $removeRequests = @($toRemove | ForEach-Object -Begin { $idx = 1 } -Process {
            @{
                id     = "$idx"
                method = "DELETE"
                url    = "/groups/$TargetGroupId/members/$_/`$ref"
            }
            $idx++
        })

    $removeResponses = Invoke-GraphBatch -Requests $removeRequests
    $removedCount = ($removeResponses | Where-Object { $_.status -in 200, 204 }).Count
    $alreadyGone = ($removeResponses | Where-Object { $_.status -eq 404 }).Count
    $removeFailedCount = $removeResponses.Count - $removedCount - $alreadyGone

    $removedCount += $alreadyGone  # already-removed is not an error

    Write-RjRbLog -Message "Removed: $($removedCount) user(s)$(if ($removeFailedCount -gt 0) { ", failed: $($removeFailedCount)" })" -Verbose
    if ($removeFailedCount -gt 0) {
        $removeResponses | Where-Object { $_.status -notin 200, 204, 404 } | ForEach-Object {
            $reqIdx = [int]$_.id - 1
            $uid = if ($reqIdx -ge 0 -and $reqIdx -lt $toRemove.Count) { $toRemove[$reqIdx] } else { "unknown" }
            $upn = if ($upnLookup.ContainsKey($uid)) { $upnLookup[$uid] } else { $uid }
            Write-RjRbLog -Message "Remove failed (status $($_.status)): $upn — $($_.body.error.message)" -Verbose
        }
    }
}

if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
    Write-Output ""
    Write-Output "Group is already up to date. No changes needed."
}

#endregion

########################################################
#region     Cleanup
########################################################

Write-Output ""
Write-Output "Summary"
Write-Output "---------------------"
Write-Output "Target Group:         $($targetGroup.displayName)"
Write-Output "Platforms:            $($selectedPlatforms -join ', ')"
if ($IncludeGroupId) { Write-Output "Include Scope:        $($includeGroup.displayName)" }
if ($ExcludeGroupId) { Write-Output "Exclude Scope:        $($excludeGroup.displayName)" }
Write-Output "Devices evaluated:    $($allDevices.Count)"
Write-Output "Desired members:      $($desiredUserIds.Count)"
Write-Output "Previous members:     $($currentMemberIds.Count)"
Write-Output "Added:                $($toAdd.Count)"
Write-Output "Removed:              $($toRemove.Count)"
Write-Output "Removal enabled:      $($RemoveUsersWhenNoDeviceMatch)"

Disconnect-MgGraph | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion
