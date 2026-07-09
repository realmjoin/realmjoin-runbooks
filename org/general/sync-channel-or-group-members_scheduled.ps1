<#
    .SYNOPSIS
    Sync members between a Teams Shared Channel or a group and an Entra security group

    .DESCRIPTION
    This scheduled runbook mirrors the membership of a source object into a target object in one
    direction per run. It supports syncing Teams Shared Channel members into a security group, syncing
    the members of one group into another group (for example a Microsoft 365 group into a security group
    or vice versa) and syncing group members into a Teams Shared Channel. Adding missing members is always
    performed, while removing members that only exist in the target is optional and controlled by a
    parameter. Guest handling and whether channel removals also remove the host team membership are
    configurable, and the runbook can optionally send an email report and upload the results as a
    time-limited download link.

    .PARAMETER Direction
    Selects what is synced into what. SharedChannelToGroup copies shared channel members into the target
    group, GroupToGroup copies the source group members into the target group, and GroupToSharedChannel
    copies the source group members into the shared channel.

    .PARAMETER TeamId
    Object id of the team that hosts the shared channel. Only used for the shared channel directions.

    .PARAMETER ChannelName
    Exact display name of the shared channel inside the selected team. Only used for the shared channel
    directions.

    .PARAMETER SourceGroupId
    Object id of the source group whose members are copied. Used for the group source directions.

    .PARAMETER TargetGroupId
    Object id of the target security group that receives the members. Used for the group target directions.

    .PARAMETER RemoveExtraMembers
    When enabled, members that exist only in the target and not in the source are removed so the target
    mirrors the source. When disabled (default), the runbook only adds missing members.

    .PARAMETER IncludeGuests
    When enabled, guest users are included in the sync and may be added or removed. When disabled (default),
    guests are skipped and are never added or removed.

    .PARAMETER RemoveFromTeam
    Only relevant for GroupToSharedChannel. When enabled, removing a member from the shared channel also
    removes that user from the host team membership. When disabled (default), only the channel membership
    is removed.

    .PARAMETER WhatIfMode
    When enabled, the runbook only logs the changes it would make without writing anything.

    .PARAMETER SendEmailReport
    When enabled, a RealmJoin-branded email report is sent via Send-RjReportEmail after the run.

    .PARAMETER EmailTo
    Recipient email address(es) for the report (comma-separated). Only used when SendEmailReport is enabled.

    .PARAMETER EmailFrom
    Sender mailbox for the report. Bound to the org Setting RJReport.EmailSender.

    .PARAMETER CreateDownloadLink
    When enabled, the CSV report is uploaded to a storage account and a time-limited download link is
    returned (and included in the email report if that is also enabled).

    .PARAMETER ContainerName
    Storage container used for the upload. Configured per runbook.

    .PARAMETER ResourceGroupName
    Resource group that contains the storage account. Bound to RJReport.StorageAccount.ResourceGroup.

    .PARAMETER StorageAccountName
    Storage account used for the upload. Bound to RJReport.StorageAccount.StorageAccountName.

    .PARAMETER LinkExpiryDays
    Days until the generated download link expires. Bound to RJReport.StorageAccount.LinkExpiryDays.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Direction": {
                "DisplayName": "What should be synced",
                "Default": "SharedChannelToGroup",
                "Select": {
                    "Options": [
                        {
                            "Display": "Shared Channel members -> security group",
                            "ParameterValue": "SharedChannelToGroup",
                            "Customization": {
                                "Show": [
                                    "TeamId",
                                    "ChannelName",
                                    "TargetGroupId"
                                ],
                                "Hide": [
                                    "SourceGroupId",
                                    "RemoveFromTeam"
                                ],
                                "Mandatory": [
                                    "TeamId",
                                    "ChannelName",
                                    "TargetGroupId"
                                ]
                            }
                        },
                        {
                            "Display": "Group members -> group",
                            "ParameterValue": "GroupToGroup",
                            "Customization": {
                                "Show": [
                                    "SourceGroupId",
                                    "TargetGroupId"
                                ],
                                "Hide": [
                                    "TeamId",
                                    "ChannelName",
                                    "RemoveFromTeam"
                                ],
                                "Mandatory": [
                                    "SourceGroupId",
                                    "TargetGroupId"
                                ]
                            }
                        },
                        {
                            "Display": "Group members -> Shared Channel",
                            "ParameterValue": "GroupToSharedChannel",
                            "Customization": {
                                "Show": [
                                    "SourceGroupId",
                                    "TeamId",
                                    "ChannelName",
                                    "RemoveFromTeam"
                                ],
                                "Hide": [
                                    "TargetGroupId"
                                ],
                                "Mandatory": [
                                    "SourceGroupId",
                                    "TeamId",
                                    "ChannelName"
                                ]
                            }
                        }
                    ]
                }
            },
            "TeamId": {
                "DisplayName": "Team hosting the shared channel",
                "Hide": false
            },
            "ChannelName": {
                "DisplayName": "Shared channel display name",
                "Hide": false
            },
            "SourceGroupId": {
                "DisplayName": "Source group",
                "Hide": true
            },
            "TargetGroupId": {
                "DisplayName": "Target security group",
                "Hide": false
            },
            "RemoveExtraMembers": {
                "DisplayName": "Remove members that only exist in the target (mirror source)"
            },
            "IncludeGuests": {
                "DisplayName": "Include guest users"
            },
            "RemoveFromTeam": {
                "DisplayName": "On channel removal, also remove the user from the host team",
                "Hide": true
            },
            "WhatIfMode": {
                "DisplayName": "Dry run (log only, no changes)"
            },
            "SendEmailReport": {
                "DisplayName": "Send email report",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": [
                                    "EmailTo"
                                ]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "EmailTo"
                                ]
                            }
                        }
                    ]
                }
            },
            "EmailTo": {
                "DisplayName": "Send report to (email address(es))",
                "Hide": true
            },
            "EmailFrom": {
                "Hide": true
            },
            "CreateDownloadLink": {
                "DisplayName": "Create a report download link (upload report to storage)",
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
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("SharedChannelToGroup", "GroupToGroup", "GroupToSharedChannel")]
    [string] $Direction,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Team hosting the shared channel" -Filter "resourceProvisioningOptions/any(c:c eq 'Team')" } )]
    [string] $TeamId,

    [string] $ChannelName,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Source group" } )]
    [string] $SourceGroupId,

    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group -DisplayName "Target security group" } )]
    [string] $TargetGroupId,

    # Add-only by default; when on, members present only in the target are removed.
    [bool] $RemoveExtraMembers = $false,

    # When off, guests are skipped entirely (never added or removed).
    [bool] $IncludeGuests = $false,

    # Only used for GroupToSharedChannel removals.
    [bool] $RemoveFromTeam = $false,

    [bool] $WhatIfMode = $false,

    # Enables the email report; when on, EmailTo becomes visible in the portal.
    [bool] $SendEmailReport = $false,

    [string] $EmailTo,

    # Sender mailbox, sourced from the org Setting "RJReport.EmailSender".
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" } )]
    [string] $EmailFrom,

    # Enables uploading the CSV report to a storage account and returning a download link.
    [bool] $CreateDownloadLink = $false,

    [string] $ContainerName = "channel-group-member-sync",

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $StorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     Function declaration
##
########################################################

function Get-GraphPagedResult {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    $results = @()
    $nextLink = $Uri
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
        if ($response.value) {
            $results += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    return $results
}

function Get-GroupMemberUser {
    # Returns the user members of a group as normalized objects @{ Id; Upn; IsGuest }.
    # Transitive expands nested groups (used for the source); direct returns only direct members
    # (used for the target, because add/remove operates on direct membership).
    param(
        [Parameter(Mandatory = $true)]
        [string] $GroupId,
        [switch] $Transitive
    )

    $segment = if ($Transitive) { "transitiveMembers" } else { "members" }
    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/$segment/microsoft.graph.user`?`$select=id,userPrincipalName,userType"
    $users = Get-GraphPagedResult -Uri $uri

    return $users | ForEach-Object {
        [PSCustomObject]@{
            Id      = $_.id
            Upn     = $_.userPrincipalName
            IsGuest = ($_.userType -eq "Guest")
        }
    }
}

function Get-ChannelMemberUser {
    # Returns the user members of a channel as normalized objects, including the membership id and
    # roles so members can later be promoted, removed or identified as guests.
    param(
        [Parameter(Mandatory = $true)]
        [string] $TeamId,
        [Parameter(Mandatory = $true)]
        [string] $ChannelId
    )

    $members = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$ChannelId/members"

    return $members | Where-Object { $_.userId } | ForEach-Object {
        [PSCustomObject]@{
            Id           = $_.userId
            Upn          = if ($_.email) { $_.email } else { $_.displayName }
            MembershipId = $_.id
            IsGuest      = (@($_.roles) -contains "guest")
        }
    }
}

#endregion

########################################################
#region     RJ Log Part
##
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Direction: $Direction" -Verbose
Write-RjRbLog -Message "TeamId: $TeamId" -Verbose
Write-RjRbLog -Message "ChannelName: $ChannelName" -Verbose
Write-RjRbLog -Message "SourceGroupId: $SourceGroupId" -Verbose
Write-RjRbLog -Message "TargetGroupId: $TargetGroupId" -Verbose
Write-RjRbLog -Message "RemoveExtraMembers: $RemoveExtraMembers" -Verbose
Write-RjRbLog -Message "IncludeGuests: $IncludeGuests" -Verbose
Write-RjRbLog -Message "RemoveFromTeam: $RemoveFromTeam" -Verbose
Write-RjRbLog -Message "WhatIfMode: $WhatIfMode" -Verbose
Write-RjRbLog -Message "SendEmailReport: $SendEmailReport" -Verbose
Write-RjRbLog -Message "EmailTo: $EmailTo" -Verbose
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
##
########################################################

$sourceIsChannel = ($Direction -eq "SharedChannelToGroup")
$targetIsChannel = ($Direction -eq "GroupToSharedChannel")

# Validate the identifiers required for the selected direction
if ($sourceIsChannel -or $targetIsChannel) {
    if (-not $TeamId) {
        "## Direction '$Direction' requires a Team (TeamId)."
        throw ("TeamId missing")
    }
    if (-not $ChannelName) {
        "## Direction '$Direction' requires a shared channel display name (ChannelName)."
        throw ("ChannelName missing")
    }
}

if (-not $sourceIsChannel -and -not $SourceGroupId) {
    "## Direction '$Direction' requires a source group (SourceGroupId)."
    throw ("SourceGroupId missing")
}

if (-not $targetIsChannel -and -not $TargetGroupId) {
    "## Direction '$Direction' requires a target group (TargetGroupId)."
    throw ("TargetGroupId missing")
}

# Validate report configuration early (fail fast before doing the work)
if ($SendEmailReport) {
    if (-not $EmailTo) {
        "## SendEmailReport is enabled but no EmailTo was provided."
        throw ("EmailTo missing")
    }
    if (-not $EmailFrom) {
        "## SendEmailReport is enabled but no sender is configured (org Setting 'RJReport.EmailSender')."
        throw ("EmailFrom missing")
    }
}

if ($CreateDownloadLink -and ((-not $ResourceGroupName) -or (-not $StorageAccountName))) {
    "## CreateDownloadLink is enabled but no target storage account is configured."
    "## Configure the RJReport.StorageAccount.* settings or pass ResourceGroupName and StorageAccountName."
    throw ("Storage account configuration missing")
}

#endregion

########################################################
#region     Connect Part
##
########################################################

Write-Output "Initiate MGGraph Session..."
try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    throw ("Graph connection failed")
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
##
########################################################

$mode = if ($WhatIfMode) { "WhatIf" } else { "Live" }

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

# Resolve the shared channel (needed as source or target) once
$channelId = $null
$channelDisplayName = $ChannelName
if ($sourceIsChannel -or $targetIsChannel) {
    Write-Output "Resolving team '$TeamId'..."
    try {
        $team = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$TeamId`?`$select=id,displayName,resourceProvisioningOptions"
    }
    catch {
        Write-Error "The specified team could not be found. Please check the TeamId: $TeamId" -ErrorAction Continue
        throw ("Team not found")
    }
    if (-not (@($team.resourceProvisioningOptions) -contains "Team")) {
        Write-Error "The specified group is not provisioned as a Team. Please check the TeamId: $TeamId" -ErrorAction Continue
        throw ("Group is not a team")
    }

    Write-Output "Resolving shared channel '$ChannelName'..."
    $channels = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/teams/$TeamId/channels`?`$select=id,displayName,membershipType"
    $channel = $channels | Where-Object { $_.displayName -eq $ChannelName } | Select-Object -First 1
    if (-not $channel) {
        Write-Error "The shared channel '$ChannelName' could not be found in team '$($team.displayName)'." -ErrorAction Continue
        throw ("Channel not found")
    }
    $channelId = $channel.id
    $channelDisplayName = $channel.displayName

    # 'shared' is an evolvable-enum value, so Graph returns 'unknownFutureValue' for membershipType
    # unless the 'include-unknown-enum-members' preference is requested. Fetch the channel directly
    # (authoritative) with that header.
    $membershipType = $null
    try {
        $channelDetail = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$channelId`?`$select=id,displayName,membershipType" -Headers @{ "Prefer" = "include-unknown-enum-members" }
        $membershipType = $channelDetail.membershipType
    }
    catch {
        Write-RjRbLog -Message "Could not read membershipType for channel '$ChannelName': $_" -Verbose
        $membershipType = $channel.membershipType
    }
    Write-RjRbLog -Message "Channel '$ChannelName' membershipType: '$membershipType'" -Verbose
    if ("$membershipType" -ne "shared") {
        Write-Error "The channel '$ChannelName' in team '$($team.displayName)' is not a shared channel (its membership type is '$membershipType'). This runbook only operates on shared channels. Please provide the name of a shared channel." -ErrorAction Continue
        throw ("Channel is not a shared channel")
    }
}

# Resolve and validate the involved groups
if (-not $sourceIsChannel) {
    try {
        $sourceGroup = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$SourceGroupId`?`$select=id,displayName"
    }
    catch {
        Write-Error "The source group could not be found. Please check the SourceGroupId: $SourceGroupId" -ErrorAction Continue
        throw ("Source group not found")
    }
}
if (-not $targetIsChannel) {
    try {
        $targetGroup = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId`?`$select=id,displayName"
    }
    catch {
        Write-Error "The target group could not be found. Please check the TargetGroupId: $TargetGroupId" -ErrorAction Continue
        throw ("Target group not found")
    }
}

# Resolve source members (normalized @{ Id; Upn; IsGuest })
if ($sourceIsChannel) {
    $sourceLabel = "Shared channel '$channelDisplayName'"
    $sourceMembers = @(Get-ChannelMemberUser -TeamId $TeamId -ChannelId $channelId)
}
else {
    $sourceLabel = "Group '$($sourceGroup.displayName)'"
    # Transitive expansion of the source group (per configuration)
    $sourceMembers = @(Get-GroupMemberUser -GroupId $SourceGroupId -Transitive)
}

# Resolve current target members (direct membership - that is what we can add to / remove from)
if ($targetIsChannel) {
    $targetLabel = "Shared channel '$channelDisplayName'"
    $targetMembers = @(Get-ChannelMemberUser -TeamId $TeamId -ChannelId $channelId)
}
else {
    $targetLabel = "Group '$($targetGroup.displayName)'"
    $targetMembers = @(Get-GroupMemberUser -GroupId $TargetGroupId)
}

# Filter guests unless explicitly included (never touch guests when off)
if (-not $IncludeGuests) {
    $sourceMembers = @($sourceMembers | Where-Object { -not $_.IsGuest })
    $targetMembers = @($targetMembers | Where-Object { -not $_.IsGuest })
}

# De-duplicate by object id
$sourceMembers = @($sourceMembers | Sort-Object Id -Unique)
$targetMembers = @($targetMembers | Sort-Object Id -Unique)

$sourceIds = @($sourceMembers | ForEach-Object { $_.Id })
$targetIds = @($targetMembers | ForEach-Object { $_.Id })

Write-Output "Source: $sourceLabel -> $($sourceMembers.Count) member(s)"
Write-Output "Target: $targetLabel -> $($targetMembers.Count) member(s)"

# Compute the delta
$toAdd = @($sourceMembers | Where-Object { $targetIds -notcontains $_.Id })
$toRemove = @()
if ($RemoveExtraMembers) {
    $toRemove = @($targetMembers | Where-Object { $sourceIds -notcontains $_.Id })
}

Write-Output "Members to add: $($toAdd.Count)"
Write-Output "Members to remove: $($toRemove.Count)$(if (-not $RemoveExtraMembers) { ' (removal disabled)' })"

#endregion

########################################################
#region     Main Part
##
########################################################

Write-Output ""
Write-Output "Start sync process"
Write-Output "---------------------"
if ($WhatIfMode) {
    "## WhatIf mode is ON - no changes will be written."
}

$totalAdded = 0
$totalRemoved = 0
$actionRows = @()

# For channel target additions, team membership is the prerequisite - preload direct team members
$teamMemberIds = @()
if ($targetIsChannel) {
    $teamMemberIds = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$TeamId/members`?`$select=id" | ForEach-Object { $_.id })
}

# --- Additions ---
foreach ($member in $toAdd) {
    if ($targetIsChannel) {
        # Ensure the user is a member of the host team first (prerequisite for channel membership)
        if ($teamMemberIds -notcontains $member.Id) {
            if ($WhatIfMode) {
                "## [WhatIf] Would add '$($member.Upn)' to team membership"
            }
            else {
                try {
                    $refBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($member.Id)" }
                    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$TeamId/members/`$ref" -Body $refBody -ContentType "application/json" | Out-Null
                    $teamMemberIds += $member.Id
                }
                catch {
                    Write-RjRbLog -Message "Could not add '$($member.Upn)' to team membership: $_" -Verbose
                }
            }
        }

        if ($WhatIfMode) {
            "## [WhatIf] Would add '$($member.Upn)' to channel '$channelDisplayName'"
            $totalAdded++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Add"; Mode = $mode }
            continue
        }
        try {
            $addBody = @{
                "@odata.type"     = "#microsoft.graph.aadUserConversationMember"
                roles             = @()
                "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$($member.Id)')"
            }
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$channelId/members" -Body $addBody -ContentType "application/json" | Out-Null
            $totalAdded++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Add"; Mode = $mode }
            "## + Added '$($member.Upn)' to channel '$channelDisplayName'"
        }
        catch {
            "## ! Failed to add '$($member.Upn)' to channel: $($_.Exception.Message)"
            Write-RjRbLog -Message "Failed to add '$($member.Upn)' to channel '$channelId': $_" -Verbose
        }
    }
    else {
        # Target is a group - add as a direct member
        if ($WhatIfMode) {
            "## [WhatIf] Would add '$($member.Upn)' to $targetLabel"
            $totalAdded++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Add"; Mode = $mode }
            continue
        }
        try {
            $refBody = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($member.Id)" }
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId/members/`$ref" -Body $refBody -ContentType "application/json" | Out-Null
            $totalAdded++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Add"; Mode = $mode }
            "## + Added '$($member.Upn)' to $targetLabel"
        }
        catch {
            "## ! Failed to add '$($member.Upn)' to target group: $($_.Exception.Message)"
            Write-RjRbLog -Message "Failed to add '$($member.Upn)' to group '$TargetGroupId': $_" -Verbose
        }
    }
}

# --- Removals (only when enabled) ---
foreach ($member in $toRemove) {
    if ($targetIsChannel) {
        if ($WhatIfMode) {
            "## [WhatIf] Would remove '$($member.Upn)' from channel '$channelDisplayName'$(if ($RemoveFromTeam) { ' and from the host team' })"
            $totalRemoved++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Remove"; Mode = $mode }
            continue
        }
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/teams/$TeamId/channels/$channelId/members/$([uri]::EscapeDataString($member.MembershipId))" | Out-Null
            $totalRemoved++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Remove"; Mode = $mode }
            "## - Removed '$($member.Upn)' from channel '$channelDisplayName'"

            if ($RemoveFromTeam) {
                try {
                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$TeamId/members/$($member.Id)/`$ref" | Out-Null
                    "## - Removed '$($member.Upn)' from host team membership"
                }
                catch {
                    Write-RjRbLog -Message "Could not remove '$($member.Upn)' from team membership: $_" -Verbose
                }
            }
        }
        catch {
            "## ! Failed to remove '$($member.Upn)' from channel: $($_.Exception.Message)"
            Write-RjRbLog -Message "Failed to remove '$($member.Upn)' from channel '$channelId': $_" -Verbose
        }
    }
    else {
        if ($WhatIfMode) {
            "## [WhatIf] Would remove '$($member.Upn)' from $targetLabel"
            $totalRemoved++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Remove"; Mode = $mode }
            continue
        }
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/groups/$TargetGroupId/members/$($member.Id)/`$ref" | Out-Null
            $totalRemoved++
            $actionRows += [PSCustomObject]@{ Direction = $Direction; Target = $targetLabel; UserUpn = $member.Upn; UserId = $member.Id; Action = "Remove"; Mode = $mode }
            "## - Removed '$($member.Upn)' from $targetLabel"
        }
        catch {
            "## ! Failed to remove '$($member.Upn)' from target group: $($_.Exception.Message)"
            Write-RjRbLog -Message "Failed to remove '$($member.Upn)' from group '$TargetGroupId': $_" -Verbose
        }
    }
}

Write-Output ""
Write-Output "## Done. Direction: $Direction | Added: $totalAdded | Removed: $totalRemoved"
if ($WhatIfMode) {
    "## (WhatIf mode - counts reflect what WOULD have been changed.)"
}

#endregion

########################################################
#region     Report (email and/or download link)
##
########################################################

if ($SendEmailReport -or $CreateDownloadLink) {
    Write-Output ""
    Write-Output "## Preparing report..."

    # Tenant display name for the report footer/subject
    $tenantDisplayName = ""
    try {
        $org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName"
        $tenantDisplayName = @($org.value).displayName | Select-Object -First 1
    }
    catch {
        Write-RjRbLog -Message "Could not resolve tenant display name: $_" -Verbose
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $basePath = (Get-Location).Path

    # CSV: per-change detail
    $actionsCsvPath = Join-Path -Path $basePath -ChildPath "${timestamp}_MemberSync_Changes.csv"
    if ($actionRows.Count -gt 0) {
        $actionRows | Sort-Object Action, UserUpn | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
    }
    else {
        # Always produce a (header-only) file so the attachment/upload is present
        "" | Select-Object @{N = "Direction"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
    }

    $csvFiles = @($actionsCsvPath)

    # Upload + download link (optional)
    $downloadLinks = @()
    if ($CreateDownloadLink) {
        Write-Output "## Uploading report to storage account..."
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $csvFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $true

        foreach ($uploadResult in $uploadResults) {
            $downloadLinks += [PSCustomObject]@{
                FileName = $uploadResult.BlobName
                SASLink  = $uploadResult.SASLink
                Expiry   = $uploadResult.EndTime
            }
            Write-Output "## Download link ($($uploadResult.BlobName)) - expires $($uploadResult.EndTime):"
            $uploadResult.SASLink | Out-String | Write-Output
        }
    }

    # Email report (optional)
    if ($SendEmailReport) {
        Write-Output "## Preparing email report for '$EmailTo'..."

        $modeNote = if ($WhatIfMode) { "**WhatIf / dry run** - the figures below reflect changes that *would* have been made; nothing was written." } else { "Live run - the figures below reflect changes that were applied." }

        # Optional download-link section (when CreateDownloadLink produced links)
        $downloadSection = ""
        if ($downloadLinks.Count -gt 0) {
            $linkLines = foreach ($dl in $downloadLinks) {
                "- [$($dl.FileName)]($($dl.SASLink)) (expires $($dl.Expiry))"
            }
            $downloadSection = @"

## Download links

$($linkLines -join "`n")
"@
        }

        $markdownContent = @"
# Member Sync

$modeNote

## Summary

| Metric | Value |
|---|---|
| Mode | $mode |
| Direction | $Direction |
| Source | $sourceLabel |
| Target | $targetLabel |
| Source members | $($sourceMembers.Count) |
| Target members (before) | $($targetMembers.Count) |
| Members added | $totalAdded |
| Members removed | $totalRemoved |
| Remove extra members | $RemoveExtraMembers |
| Include guests | $IncludeGuests |
$downloadSection
## Attachments

- **$([IO.Path]::GetFileName($actionsCsvPath))** - one row per individual change (target, user, action).

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Member Sync - $Direction - added $totalAdded, removed $totalRemoved$(if ($WhatIfMode) { ' [WhatIf]' }) - $tenantDisplayName".Trim()

        Write-Output "Sending report to '$EmailTo'..."
        try {
            Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $EmailTo -Subject $emailSubject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version -Attachments $csvFiles -UseNativeGraphRequest
            Write-RjRbLog -Message "Email report sent to: $EmailTo" -Verbose
            Write-Output "Email report sent to '$EmailTo'."
        }
        catch {
            Write-Error "Failed to send email report: $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
    }
}

#endregion

Write-Output ""
Write-Output "Done!"
