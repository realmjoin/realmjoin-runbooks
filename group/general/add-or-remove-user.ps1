<#
    .SYNOPSIS
    Add a user to this group or remove one

    .DESCRIPTION
    Adds a user as a member of this group or removes an existing member. Works for Microsoft Entra ID groups as well as Exchange Online distribution and mail-enabled security groups.

    .PARAMETER GroupID
    Object ID of the group the runbook acts on. Set by the portal from the selected group.

    .PARAMETER UserId
    User who is added to or removed from the group.

    .PARAMETER Remove
    Add makes the user a member. Remove takes the membership away.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Remove": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Add user as member": false,
                    "Remove user as member": true
                }
            },
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserId,
    [bool] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.3"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Find the user object "
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserId" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User '$UserId' not found.")
}

$targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID" -ErrorAction SilentlyContinue
if (-not $targetGroup) {
    throw ("Group '$GroupID' not found.")
}

# Work on AzureAD based groups
if (($targetGroup.GroupTypes -contains "Unified") -or (-not $targetGroup.MailEnabled)) {
    "## Group type: AzureAD"
    # Prepare Request
    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
    }

    # "Is user member of the the group?"
    if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$UserID" -ErrorAction SilentlyContinue) {
        if ($Remove) {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$UserId/`$ref" -Method Delete -Body $body | Out-Null
            "## '$($targetUser.UserPrincipalName)' is removed from '$($targetGroup.DisplayName)'."
        }
        else {
            "## User '$($targetUser.UserPrincipalName)' is already a member of '$($targetGroup.DisplayName)'. No action taken."
        }
    }
    else {
        if ($Remove) {
            "## User '$($targetUser.UserPrincipalName)' is not a member of '$($targetGroup.DisplayName)'. No action taken."
        }
        else {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/`$ref" -Method Post -Body $body | Out-Null
            "## '$($targetUser.UserPrincipalName)' is added to '$($targetGroup.DisplayName)'."
        }
    }
}
else {
    "## Group type: Exchange Online"
    try {
        Connect-RjRbExchangeOnline
        $groupObj = Get-Group -Identity $groupID

        # Resolve the user as an Exchange Online recipient. A distribution group member does not need a
        # cloud mailbox - a mail user (for example a hybrid user whose mailbox is hosted on-premises) is a
        # valid member as well. The membership changes below address the member by its directory object
        # id - the recipient Name is not unique in Exchange Online and can fail as an ambiguous identity.
        $targetRecipient = Get-Recipient -Identity $targetUser.id -ErrorAction SilentlyContinue
        if (-not $targetRecipient) {
            throw "User '$($targetUser.UserPrincipalName)' is not an Exchange Online recipient (neither a mailbox nor a mail user). Only mail-enabled users can be members of a distribution or mail-enabled security group."
        }

        # Exchange Online returns the group members as directory object ids; module versions that
        # return recipient names instead are covered as well, so the membership check holds in both
        # cases. Comparing only the name misses every recipient whose name is not its object id.
        $isMember = ($groupObj.Members -contains $targetUser.id) -or ($groupObj.Members -contains $targetRecipient.Name)

        if ($Remove) {
            # Remove user from EXO group
            if ($isMember) {
                Remove-DistributionGroupMember -Identity $GroupID -Member $targetUser.id -BypassSecurityGroupManagerCheck -Confirm:$false
                "## '$($targetUser.UserPrincipalName)' is removed from '$($targetGroup.DisplayName)'."
            }
            else {
                "## User '$($targetUser.UserPrincipalName)' is not a member of '$($targetGroup.DisplayName)'. No action taken."
            }
        }
        else {
            # Add user to EXO group
            if ($groupObj.RecipientType -in @("MailUniversalDistributionGroup", "MailUniversalSecurityGroup")) {
                if ($isMember) {
                    "## User '$($targetUser.UserPrincipalName)' is already a member of '$($targetGroup.DisplayName)'. No action taken."
                }
                else {
                    Add-DistributionGroupMember -Identity $GroupID -member $targetUser.id -BypassSecurityGroupManagerCheck -Confirm:$false
                    "## '$($targetUser.UserPrincipalName)' is added to '$($targetGroup.DisplayName)'."
                }
            }
            else {
                "## Unknown EXO group type: '$($groupObj.RecipientType)'"
                throw ("EXO groups not supported")
            }
        }
    }
    finally {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }
}
