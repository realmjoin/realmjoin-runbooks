<#
    .SYNOPSIS
    Add an owner to this group or remove one

    .DESCRIPTION
    Makes a user an owner of this group or removes an existing owner. For Microsoft 365 groups a new owner is also made a member.

    .PARAMETER GroupID
    Object ID of the group the runbook acts on. Set by the portal from the selected group.

    .PARAMETER UserId
    User who gets or loses the ownership.

    .PARAMETER Remove
    Add makes the user an owner. Remove takes the user off the owner list.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "Remove": {
                "DisplayName": "Action",
                "SelectSimple": {
                    "Add user as owner": false,
                    "Remove user as owner": true
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
    #[ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Group" } )]
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

$Version = "1.0.1"
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
    # Prepare Request
    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
    }

    # "Is user owner of the the group?"
    if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners/$UserID" -ErrorAction SilentlyContinue) {
        if ($Remove) {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners/$UserId/`$ref" -Method Delete -Body $body | Out-Null
            "## '$($targetUser.UserPrincipalName)' is removed from '$($targetGroup.DisplayName)' owners"
        }
        else {
            "## User '$($targetUser.UserPrincipalName)' is already an owner of '$($targetGroup.DisplayName)'. No action taken."
        }
    }
    else {
        if ($Remove) {
            "## User '$($targetUser.UserPrincipalName)' is not an owner of '$($targetGroup.DisplayName)'. No action taken."
        }
        else {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/owners/`$ref" -Method Post -Body $body | Out-Null
            "## '$($targetUser.UserPrincipalName)' is added to '$($targetGroup.DisplayName)' owners."

            # Check members - owners also have to be members
            if (-not (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$UserID" -ErrorAction SilentlyContinue)) {
                Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/`$ref" -Method Post -Body $body | Out-Null
                "## '$($targetUser.UserPrincipalName)' is added to '$($targetGroup.DisplayName)' members."
            }
        }
    }
}
# Work on Exchange groups
else {
    try {
        $ProgressPreference = "SilentlyContinue"

        Connect-RjRbExchangeOnline

        $exgroup = Get-DistributionGroup -Identity $GroupID
        # Checking if group is of type "distribution"
        if (-not $exgroup) {
            throw "'$GroupId' is not a distribution- or mail-enabled sec. group. Can not proceed."
        }

        $exuser = Get-EXORecipient -Identity $UserId
        if (-not $exuser) {
            throw "Recipient '$UserId' not found in ExchangeOnline. Can not proceed."
        }

        if ($Remove) {
            if ($exgroup.ManagedBy -contains $exuser.Name) {
                $managedBy = $exgroup.ManagedBy | Where-Object { $_ -ne $exuser.Name }
                Set-DistributionGroup -Identity $GroupID -ManagedBy $managedBy -BypassSecurityGroupManagerCheck:$true
                "## Removed '$($targetUser.UserPrincipalName)' from the list of owners for '$($targetGroup.DisplayName)'."
            }
            else {
                "## '$($targetUser.UserPrincipalName)' is not owner of '$($targetGroup.DisplayName)'. No action taken."
            }
        }
        else {
            if ($exgroup.ManagedBy -contains $exuser.Name) {
                "## '$($targetUser.UserPrincipalName)' is already owner of '$($targetGroup.DisplayName)'. No action taken."
            }
            else {
                $managedBy = $exgroup.ManagedBy + $UserId
                Set-DistributionGroup -Identity $GroupID -ManagedBy $managedBy -BypassSecurityGroupManagerCheck:$true
                "## Added '$($targetUser.UserPrincipalName)' to the list of owners for '$($targetGroup.DisplayName)'."
            }
        }
    }
    finally {
        Disconnect-ExchangeOnline -Confirm:$false | Out-Null
    }
}
