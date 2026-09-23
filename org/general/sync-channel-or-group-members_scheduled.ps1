<#
    .SYNOPSIS
    Mirror members between a Teams shared channel and a group

    .DESCRIPTION
    Copies the members of a source into a target on every run. The source and target can be a shared channel and a security group, two groups, or a group and a shared channel. Missing members are always added; members that exist only in the target are removed only when asked. A dry run shows the changes without applying them, and the report can be sent by email or provided as a download link. Details on the options are in the runbook documentation (docs.realmjoin.com).

    .PARAMETER Direction
    What is copied where: shared channel members into the target group, source group members into the target group, or source group members into the shared channel.

    .PARAMETER TeamId
    Team that hosts the shared channel. Needed for the shared channel directions only.

    .PARAMETER ChannelName
    Exact name of the shared channel in that team. Needed for the shared channel directions only.

    .PARAMETER SourceGroupId
    Group whose members are copied. Needed when the source is a group.

    .PARAMETER TargetGroupId
    Security group that receives the members. Needed when the target is a group.

    .PARAMETER RemoveExtraMembers
    Also removes members that exist only in the target, so it mirrors the source exactly. Otherwise members are only added.

    .PARAMETER IncludeGuests
    Also adds and removes guest users. Otherwise guests are left untouched on both sides.

    .PARAMETER RemoveFromTeam
    When a member is removed from the shared channel, also removes them from the host team. Only applies when a group is copied into a shared channel.

    .PARAMETER WhatIfMode
    Only logs what would change without writing anything.

    .PARAMETER SendEmailReport
    Send the report to the recipient email address.

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

    .PARAMETER ReportFileFormat
    Deliver the report as CSV, as an Excel workbook, or both.

    .PARAMETER CreateDownloadLink
    Also upload the report and return a download link that expires after a few days.

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
            "Direction": {
                "DisplayName": "Direction",
                "Default": "SharedChannelToGroup",
                "Select": {
                    "Options": [
                        {
                            "Display": "Shared channel members to security group",
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
                            "Display": "Group members to group",
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
                            "Display": "Group members to shared channel",
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
                "DisplayName": "Shared channel name",
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
                "DisplayName": "Remove members missing in the source?"
            },
            "IncludeGuests": {
                "DisplayName": "Include guest users?"
            },
            "RemoveFromTeam": {
                "DisplayName": "Also remove from the host team?",
                "Hide": true
            },
            "WhatIfMode": {
                "DisplayName": "Dry run?"
            },
            "SendEmailReport": {
                "DisplayName": "Send email report?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - send the report via email",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": [
                                    "EmailTo",
                                    "ReportFileFormat"
                                ]
                            }
                        },
                        {
                            "Display": "No - do not send an email",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "EmailTo",
                                    "ReportFileFormat"
                                ]
                            }
                        }
                    ]
                }
            },
            "EmailTo": {
                "DisplayName": "Recipient email address(es)",
                "Hide": true
            },
            "EmailFrom": {
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
            "CreateDownloadLink": {
                "DisplayName": "Create a download link?",
                "Select": {
                    "Options": [
                        {
                            "Display": "Yes - upload report and return a download link",
                            "ParameterValue": true,
                            "Customization": {
                                "Show": [
                                    "ReportFileFormat"
                                ]
                            }
                        },
                        {
                            "Display": "No - do not create a download link",
                            "ParameterValue": false,
                            "Customization": {
                                "Hide": [
                                    "ReportFileFormat"
                                ]
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

    # Enables uploading the report file(s) to a storage account and returning a download link.
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

$Version = "1.3.0"
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
Write-RjRbLog -Message "ReportFileFormat: $ReportFileFormat" -Verbose
Write-RjRbLog -Message "CreateDownloadLink: $CreateDownloadLink" -Verbose
if ($CreateDownloadLink) {
    Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
    Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
    Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
    Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose
}
Write-RjRbLog -Message "BrandingHeaderImageUrl: $BrandingHeaderImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterImageUrl: $BrandingFooterImageUrl" -Verbose
Write-RjRbLog -Message "BrandingFooterLink: $BrandingFooterLink" -Verbose
Write-RjRbLog -Message "BrandingAccentColor: $BrandingAccentColor" -Verbose
Write-RjRbLog -Message "BrandingTextColor: $BrandingTextColor" -Verbose

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

$brandingMailParams = @{}
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

    # Sort once so the CSV and XLSX exports use identical data
    $actionRows = @($actionRows | Sort-Object Action, UserUpn)

    $reportFiles = @()
    $xlsxPath = $null

    if ($ReportFileFormat -ne 'XLSX only') {
        # CSV: per-change detail
        $actionsCsvPath = Join-Path -Path $basePath -ChildPath "${timestamp}_MemberSync_Changes.csv"
        if ($actionRows.Count -gt 0) {
            $actionRows | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
        }
        else {
            # Always produce a (header-only) file so the attachment/upload is present
            "" | Select-Object @{N = "Direction"; E = { $_ } } | Where-Object { $false } | Export-Csv -Path $actionsCsvPath -NoTypeInformation -Encoding UTF8
        }
        $reportFiles += $actionsCsvPath
    }

    if ($ReportFileFormat -ne 'CSV only') {
        # XLSX: the same data as a formatted Excel workbook (writes a "No data available" sheet when empty)
        $xlsxPath = Join-Path -Path $basePath -ChildPath "${timestamp}_MemberSync_Changes.xlsx"
        $actionRows | Export-RjRbXlsx -Path $xlsxPath -WorksheetName "Actions"
        $reportFiles += $xlsxPath
    }

    # Upload + download link (optional)
    $downloadLinks = @()
    if ($CreateDownloadLink -and $reportFiles.Count -gt 0) {
        Write-Output "## Uploading report to storage account..."
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
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

$(if ($ReportFileFormat -ne 'XLSX only') { "- **$([IO.Path]::GetFileName($actionsCsvPath))** - one row per individual change (target, user, action)." })
$(if ($ReportFileFormat -ne 'CSV only') { "- **$([IO.Path]::GetFileName($xlsxPath))** - the same data as a formatted Excel workbook." })

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $markdownFallback = @"
# Member Sync

$modeNote

## Summary

| Metric | Value |
|---|---|
| Mode | $mode |
| Direction | $Direction |
| Members added | $totalAdded |
| Members removed | $totalRemoved |

## Attachments

- **$([IO.Path]::GetFileName($xlsxPath))** - one row per individual change (target, user, action) as a formatted Excel workbook.

> **Note:** The CSV file was not attached because it exceeds the email attachment size limit. The Excel workbook contains the complete data. Enable the download link option (CreateDownloadLink) to obtain the raw CSV file.

---

*This email was automatically generated. Please do not reply to this email.*
"@

        $emailSubject = "Member Sync - $Direction - added $totalAdded, removed $totalRemoved$(if ($WhatIfMode) { ' [WhatIf]' }) - $tenantDisplayName".Trim()

        # Send email (attachment size guarded; "CSV & XLSX" falls back to the workbook alone when the CSV is too large)
        Write-Output "Sending report to '$EmailTo'..."

        # Resolve optional tenant email branding once per run (never fails the send)
        $brandingMailParams = Get-RjRbBrandingMailParams -HeaderImageUrl $BrandingHeaderImageUrl -FooterImageUrl $BrandingFooterImageUrl -FooterLink $BrandingFooterLink -AccentColor $BrandingAccentColor -TextColor $BrandingTextColor

        try {
            $guardParams = @{
                EmailFrom         = $EmailFrom
                EmailTo           = $EmailTo
                Subject           = $emailSubject
                MarkdownContent   = $markdownContent
                TenantDisplayName = $tenantDisplayName
                ReportVersion     = $Version
            }
            $guardParams.UseNativeGraphRequest = $true
            if ($ReportFileFormat -eq 'CSV & XLSX' -and $xlsxPath) {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles -FallbackAttachments @($xlsxPath) -FallbackMarkdownContent $markdownFallback
            }
            else {
                Send-RjReportEmail @guardParams @brandingMailParams -Attachments $reportFiles
            }
            Write-RjRbLog -Message "Email report sent to: $EmailTo" -Verbose
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
