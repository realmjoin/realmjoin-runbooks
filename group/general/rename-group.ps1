<#
  .SYNOPSIS
  Rename a group.

  .DESCRIPTION
  Rename a group MailNickname, DisplayName and Description. Will NOT change eMail addresses!

  .NOTES
  Permissions: MS Graph (API):
   - Group.ReadWrite.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "GroupId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.1" }

param(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity Group } )]
    [string] $GroupId,
    [ValidateScript( { Use-RJInterface -DisplayName "New DisplayName / Team Name" } )]
    [string] $DisplayName,
    [ValidateScript( { Use-RJInterface -DisplayName "New MailNickname" } )]
    [string] $MailNickname,
    [ValidateScript( { Use-RJInterface -DisplayName "New Description" } )]
    [string] $Description,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Check if group exists already
$group = Invoke-RjRbRestMethodGraph -resource "/groups/$GroupId" -erroraction SilentlyContinue
if (-not $group) {
    throw "GroupId '$GroupId' does not exist."
}

"## Trying to rename/update group $($group.displayName) to:"

$body = @{}
if ($MailNickname) {
    "New MailNickname: $MailNickname"
    $body.Add("mailNickname", $MailNickname)
}
if ($DisplayName) {
    "New DisplayName: $DisplayName"
    $body.Add("displayName", $DisplayName)
}
if ($Description) {
    "New Descriptio: $Description"
    $body.Add("description",$Description)
}

if ($body.Count -gt 0) {
    Invoke-RjRbRestMethodGraph -resource "/groups/$GroupId" -Method Patch -Body $body | Out-Null
    "## Successfully updated group object."
} else {
    "## Nothing to do."
}

