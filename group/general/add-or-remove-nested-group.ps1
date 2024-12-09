<#
  .SYNOPSIS
  Add/remove a nested group to/from a group.

  .DESCRIPTION
  Add/remove a nested group to/from an AzureAD or Exchange Online group. 

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.ReadWrite.All
  - Directory.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "Remove": {
                "DisplayName": "Remove this group"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [String] $GroupID,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity Group -DisplayName "Nested Group" } )]
    [String] $NestedGroupID,
    [bool] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

# "Find the nested group " 
$nestedGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$NestedGroupID" -ErrorAction SilentlyContinue
if (-not $nestedGroup) {
    throw ("(Nested) Group '$NestedGroupId' not found.")
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
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$NestedGroupID"
    }
    
    # "Is nestedGroup member of the the group?" 
    if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$NestedGroupID" -ErrorAction SilentlyContinue) {
        if ($Remove) {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$NestedGroupID/`$ref" -Method Delete -Body $body | Out-Null
            "## '$($nestedGroup.displayName)' is removed from '$($targetGroup.displayName)'."
        }
        else {    
            "## Group '$($nestedGroup.displayName)' is already a member of '$($targetGroup.DisplayName)'. No action taken."
        }
    }
    else {
        if ($Remove) {
            "## User '$($nestedGroup.displayName)' is not a member of '$($targetGroup.DisplayName)'. No action taken."
        }
        else {
            Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/`$ref" -Method Post -Body $body | Out-Null
            "## '$($nestedGroup.displayName)' is added to '$($targetGroup.DisplayName)'."  
        }
    }
} 
else {
    "## Group type: Exchange Online"
    try {
        Connect-RjRbExchangeOnline
        $groupObj = Get-Group -Identity $groupID

        # Get nested group
        $nestedGroupObj = Get-Group -Identity $NestedGroupID

        if ($Remove) {
            # Remove user from EXO group
            if ($groupObj.Members -contains $nestedGroupObj.name) {
                Remove-DistributionGroupMember -Identity $GroupID -Member $nestedGroupObj.Name -BypassSecurityGroupManagerCheck -Confirm:$false
                "## '$($nestedGroupObj.DisplayName)' is removed from '$($groupObj.DisplayName)'."
            }
            else {
                "## Group '$($nestedGroupObj.DisplayName)' is not a member of '$($groupObj.DisplayName)'. No action taken."
            }
        }
        else {
            # Add user to EXO group
            if ($groupObj.RecipientType -in @("MailUniversalDistributionGroup", "MailUniversalSecurityGroup")) {
                if ($groupObj.Members -contains $nestedGroupObj.name) {
                    "## User '$($nestedGroupObj.DisplayName)' is already a member of '$($groupObj.DisplayName)'. No action taken."
                }
                else {
                    Add-DistributionGroupMember -Identity $GroupID -member $nestedGroupObj.Name -BypassSecurityGroupManagerCheck -Confirm:$false
                    "## '$($nestedGroupObj.DisplayName)' is added to '$($groupObj.DisplayName)'."
                }
            }
            else {
                "## Unknown EXO group type: '$($groupObj.RecipientType)'"
                throw ("EXO groups not supported")
            }
        }
    }
    catch {
        "## Working on Exchange groups failed. Did you try to nest an EntraID group in an Exchange group?"
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        throw $_
    }
    finally {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }
}
