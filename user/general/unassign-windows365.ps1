<#
  .SYNOPSIS
  Remove/Deprovision a Windows 365 instance

  .DESCRIPTION
  Remove/Deprovision a Windows 365 instance

  .NOTES
  Permissions:
  MS Graph (API):
  - User.Read.All
  - GroupMember.ReadWrite.All 
  - Group.ReadWrite.All
  - CloudPC.ReadWrite.All (Beta)

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "cfgProvisioningGroupPrefix": {
                "Hide": true
            },
            "cfgUserSettingsGroupPrefix": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules "RealmJoin.RunbookHelper"

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [string] $licWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [string] $cfgProvisioningGroupPrefix = "cfg - Windows 365 - Provisioning - ",
    [string] $cfgUserSettingsGroupPrefix = "cfg - Windows 365 - User Settings - ",
    [string] $licWin365GroupPrefix = "lic - Windows 365 Enterprise - ",
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Verify Windows 365 license group
$licWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$licWin365GroupName'"
if (-not $licWin365GroupObj) {
    "## Could not find Windows 365 license group '$licWin365GroupName'."
    throw "licWin365 not found"
}

# Find the user object
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'"

# Make sure the Win365 license is unassigned.
$result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"
if ($result -and ($result.userPrincipalName -contains $UserName)) {
    Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
    "## Unassgined '$licWin365GroupName' from '$UserName'."
    # POST https://graph.microsoft.com/beta/deviceManagement/virtualEndpoint/cloudPCs/{cloudPCId}/endGracePeriod
} else {
    "## '$UserName' does not have '$licWin365GroupName'." 
    "## Can not deprovision."
}

# Are any other Cloud PCs assigned to this user?
$licWin365GroupIsAssigned = $false
$allLicWin365Groups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$licWin365GroupPrefix')"
foreach ($group in $allLicWin365Groups) {
    $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
    if ($result -and ($result.userPrincipalName -contains $UserName)) {
        $licWin365GroupIsAssigned = $true
    }
}
if (-not $licWin365GroupIsAssigned) {
    "## No other Cloud PCs exist for '$UserName'."
    "## Removing Provisinging Policy and User Settings."

    [array]$groups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgProvisioningGroupPrefix')"
    $groups += Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgUserSettingsGroupPrefix')"
    foreach ($group in $groups) {
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            "## Removing '$($group.displayName)' from '$UserName'."
            Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/$($targetUser.id)/`$ref" -Method Delete | Out-Null
        }
    }
}

