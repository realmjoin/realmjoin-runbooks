<#
    .SYNOPSIS
    Add or remove a group member

    .DESCRIPTION
    This runbook adds a user to a group or removes a user from a group.
    It supports Microsoft Entra ID groups and Exchange Online distribution or mail-enabled security groups.
    Use the Remove switch to remove the user instead of adding the user.

    .PARAMETER GroupID
    Object ID of the target group.

    .PARAMETER UserId
    Object ID of the user to add or remove.

    .PARAMETER Remove
    "Add User to Group" (final value: $false) or "Remove User from Group" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the user from the group. If set to false, it will add the user to the group.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Remove": {
                "DisplayName": "Add or Remove User",
                "SelectSimple": {
                    "Add User as member": false,
                    "Remove User as member": true
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

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

$Version = "1.0.0"
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

        # Get User mailbox
        $targetMailbox = get-mailbox -Identity $targetUser.id

        if ($Remove) {
            # Remove user from EXO group
            if ($groupObj.Members -contains $targetMailbox.name) {
                Remove-DistributionGroupMember -Identity $GroupID -Member $targetMailbox.Name -BypassSecurityGroupManagerCheck -Confirm:$false
                "## '$($targetUser.UserPrincipalName)' is removed from '$($targetGroup.DisplayName)'."
            }
            else {
                "## User '$($targetUser.UserPrincipalName)' is not a member of '$($targetGroup.DisplayName)'. No action taken."
            }
        }
        else {
            # Add user to EXO group
            if ($groupObj.RecipientType -in @("MailUniversalDistributionGroup", "MailUniversalSecurityGroup")) {
                if ($groupObj.Members -contains $targetMailbox.name) {
                    "## User '$($targetUser.UserPrincipalName)' is already a member of '$($targetGroup.DisplayName)'. No action taken."
                }
                else {
                    Add-DistributionGroupMember -Identity $GroupID -member $targetMailbox.Name -BypassSecurityGroupManagerCheck -Confirm:$false
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
