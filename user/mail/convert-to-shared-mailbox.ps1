<#
  .SYNOPSIS
  Turn this users mailbox into a shared mailbox.

  .DESCRIPTION
  Turn this users mailbox into a shared mailbox.

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Action",
                "DisplayBefore": "AutoMapping",
                "Select": {
                    "Options": [
                        {
                            "Display": "Turn mailbox into shared mailbox",
                            "Customization": {
                                "Default": {
                                    "Remove": false
                                },
                                "Hide": [
                                    "RegularLicenseGroup"
                                ]
                            }
                        }, {
                            "Display": "Turn shared mailbox back into regular mailbox",
                            "Customization": {
                                "Default": {
                                    "Remove": true,
                                    "RemoveGroups": false
                                },
                                "Hide": [
                                    "AutoMapping",
                                    "delegateTo",
                                    "RemoveGroups",
                                    "ArchivalLicenseGroup"
                                ]
                            }
                        }
                    ]
                },
                "Default": "Turn mailbox into shared mailbox"
            },
            {
                "Name": "CallerName",
                "Hide": true
            }
        ]
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $delegateTo,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Turn mailbox back to regular mailbox" } )]
    [bool] $Remove = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Remove existing group memberships (incl. license groups)?" } )]
    [bool] $RemoveGroups = $true,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Assign this group (DisplayName) if an Ex. Online Plan 2 is required" } )]
    [string] $ArchivalLicenseGroup = "",
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Assign this group (DisplayName) when converting to regular mailbox" } )]
    [string] $RegularLicenseGroup = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$outputString = "## Trying to convert mailbox '$UserName' "
if ($Remove) {
    $outputString += "to a regular mailbox."
}
else {
    $outputString += "to a shared mailbox."
}
$outputString

if ($delegateTo) {
    $delegateObj = Invoke-RjRbRestMethodGraph -Resource "/users/$delegateTo"
    "## Give access to mailbox '$UserName' to '$($delegateObj.userPrincipalName)'."
}
if ($AutoMapping) {
    "## Mailbox will automatically appear in Outlook."
}

try {
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    # No need to check trustee for a mailbox with "FullAccess"
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User '$UserName' has no mailbox."
    }

    [bool] $archivalLicNeeded = $false
    "## Check Mailbox Size"
    $stats = Get-EXOMailboxStatistics -Identity $UserName
    if ($stats.TotalItemSize.Value -gt 50GB) {
        " -> Mailbox is larger than 50GB -> license required"
        $archivalLicNeeded = $true
    }

    "## Check for litigation hold"
    $result = Get-Mailbox -Identity $UserName
    if ($result.LitigationHoldEnabled) {
        " -> Mailbox is on litigation hold -> license required"
        $archivalLicNeeded = $true
    }

    "## Check for Mailbox Archive"
    # Not using "ArchiveState", see https://docs.microsoft.com/en-us/office365/troubleshoot/archive-mailboxes/archivestatus-set-none
    if (($result.ArchiveGuid -and ($result.ArchiveGuid.GUID -ne "00000000-0000-0000-0000-000000000000")) -or ($result.ArchiveDatabase)) {
        " -> Mailbox has an archive -> license required"
        $archivalLicNeeded = $true
    }

    if ($Remove) {
        "## Removing access for other users..."
        $PermittedUsers = Get-MailboxPermission -Identity $UserName | Where-Object { $_.User -ne "NT AUTHORITY\SELF" }
        foreach ($PermittedUser in $PermittedUsers) {
            "## Reverting Mailbox Access Permission for '$($PermittedUser.User)' from mailbox '$UserName'"
            Remove-MailboxPermission -Identity $UserName -User $PermittedUser.User -AccessRights $PermittedUser.AccessRights -InheritanceType All -confirm:$false | Out-Null
        }
        $PermittedRecipients = Get-RecipientPermission -Identity $UserName | Where-Object { $_.Trustee -ne "NT AUTHORITY\SELF" }
        foreach ($PermittedRecipient in $PermittedRecipients) {
            "## Reverting SendAs/SendOnBehalf Permission for '$($PermittedRecipient.Trustee)' from mailbox '$UserName'"
            Remove-RecipientPermission -Identity $UserName -Trustee $PermittedRecipient.Trustee -AccessRights $PermittedRecipient.AccessRights -confirm:$false | Out-Null
        }

        if ($RegularLicenseGroup) {
            # Assign lic. group
            $groupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$RegularLicenseGroup'"
            if ($groupObj) {
                $members = Invoke-RjRbRestMethodGraph -Resource "/groups/$($groupObj.id)/members"
                if ($members.id -notcontains $user.ExternalDirectoryObjectId) {
                    "## Assigning license group '$RegularLicenseGroup' to mailbox '$UserName'"
                    $body = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.ExternalDirectoryObjectId)"
                    }
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($groupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
                }
                else {
                    "## License group '$RegularLicenseGroup' already assigned to mailbox '$UserName'"
                }
            }
        }

        "## Enabling user object '$UserName'"
        $userObj = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
        $body = @{
            accountEnabled = $true
        }
        Invoke-RjRbRestMethodGraph -Resource "/users/$($userObj.id)" -Method Patch -Body $body | Out-Null

        "## Turning mailbox '$UserName' into regular user mailbox"
        Set-Mailbox $UserName -Type regular -GrantSendOnBehalfTo $null | Out-Null

        ""
        "## Success: Mailbox '$UserName' is now a regular mailbox."
    }
    else {
        "## Disabling user object '$UserName' (no login for shared mailboxes)"
        $userObj = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName"
        $body = @{
            accountEnabled = $false
        }
        Invoke-RjRbRestMethodGraph -Resource "/users/$($userObj.id)" -Method Patch -Body $body | Out-Null

        "## Turning mailbox '$UserName' into shared mailbox"
        Set-Mailbox $UserName -Type shared | Out-Null
        # Add access
        if ($delegateTo) {
            $delegateObj = Invoke-RjRbRestMethodGraph -Resource "/users/$delegateTo"
            "## Adding FullAccess Permission for '$($delegateObj.userPrincipalName)' to mailbox '$UserName'"
            Add-MailboxPermission $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        }

        if ($RemoveGroups) {
            # Remove all group memberships
            $memberships = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/memberOf" -FollowPaging
            $memberships | ForEach-Object {
                if ($_.GroupTypes -contains "DynamicMembership") {
                    "## Skipping dynamic group '$($_.displayName)'"
                }
                elseif ($_.onPremisesSyncEnabled) {
                    "## Skipping on-premises group '$($_.displayName)'"
                    "## - please remove manually"
                }
                elseif ($_.isAssignableToRoles) {
                    # this would require RoleManagement.ReadWrite.Directory permission and "Privileged Role Administrator" Role for RJ
                    "## Skipping role group '$($_.displayName)'"
                    "## - Role assignable groups can not be managed via RJ - Privileged Role Management permission required"
                }
                else {
                    "## Removing group membership '$($_.displayName)' from mailbox '$UserName'"
                    if (($_.GroupTypes -contains "Unified") -or (-not $_.MailEnabled)) {
                        "## .. using Graph API"
                        Invoke-RjRbRestMethodGraph -Resource "/groups/$($_.id)/members/$($user.ExternalDirectoryObjectId)/`$ref" -Method Delete | Out-Null
                    }
                    else {
                        "## .. using Exchange Online PowerShell"
                        Remove-DistributionGroupMember -Identity $_.id -Member $UserName -BypassSecurityGroupManagerCheck -Confirm:$false | Out-Null
                    }
                }
            }
        }

        if ($ArchivalLicenseGroup -and $archivalLicNeeded) {
            # Assign lic. group to preserve online arhive etc.
            $groupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$ArchivalLicenseGroup'"
            if ($groupObj) {
                $members = Invoke-RjRbRestMethodGraph -Resource "/groups/$($groupObj.id)/members"
                if ($members.id -notcontains $user.ExternalDirectoryObjectId) {
                    "## Assigning license group '$ArchivalLicenseGroup' to mailbox '$UserName'"
                    $body = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.ExternalDirectoryObjectId)"
                    }
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($groupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
                }
                else {
                    "## License group '$ArchivalLicenseGroup' already assigned to mailbox '$UserName'"
                }
            }
        }

        ""
        "## Success: Mailbox '$UserName' is now a shared mailbox."
    }

    ""
    "## Current Permission Delegations"
    Get-MailboxPermission -Identity $UserName | Select-Object -expandproperty User

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue | Out-Null
}
