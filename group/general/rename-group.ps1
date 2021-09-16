<#
  .SYNOPSIS
  Rename a group.

  .DESCRIPTION
  Rename a group MailNickname, DisplayName and Description. Wil NOT change eMail addresses!

  .NOTES
  Permissions: MS Graph (API):
   - Group.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "GroupId": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [string] $GroupId,
    [ValidateScript( { Use-RJInterface -DisplayName "New MailNickname" } )]
    [string] $MailNickname,
    [ValidateScript( { Use-RJInterface -DisplayName "New DisplayName" } )]
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -DisplayName "New Description" } )]
    [string] $Description
)

Connect-RjRbGraph

$body = @{}
if ($MailNickname) {
    $body.Add("mailNickname", $MailNickname)
}
if ($DisplayName) {
    $body.Add("displayName", $DisplayName)
}
if ($Description) {
    $body.Add("description",$Description)
}


if ($body.Count -gt 0) {
    Invoke-RjRbRestMethodGraph -resource "/groups/$GroupId" -Method Patch -Body $body | Out-Null
    "## Successfully updated group object."
} else {
    "## Nothing to do."
}

