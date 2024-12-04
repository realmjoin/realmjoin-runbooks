<#
  .SYNOPSIS
  Add/remove users to/from a group.

  .DESCRIPTION
  Add/remove users to/from an AzureAD or Exchange Online group.

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.ReadWrite.All
  - Directory.ReadWrite.All

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
            },
            "Remove": {
                "DisplayName": "Remove this user"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

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
