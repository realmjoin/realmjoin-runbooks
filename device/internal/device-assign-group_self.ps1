<#
  .SYNOPSIS
  Add a device to a group.

  .DESCRIPTION
  Add a device to a group.

  .NOTES
  Permissions: 
  MS Graph (API)
  - Group.ReadWrite.All
  - Directory.ReadWrite.All
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    # RJ will pass the "DeviceID" != AAD "ObjectID". Be aware :)
    [Parameter(Mandatory = $true)]
    [String] $DeviceId,
    [String] $GroupID = "9d7b59ac-89dd-4b6b-a37a-22a94f886904",
    # Track 
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# "Find the device object " 
$targetDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'"
if (-not $targetDevice) {
    throw ("Device ID '$DeviceId' not found.")
}

$targetGroup = Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID" -ErrorAction SilentlyContinue
if (-not $targetGroup) {
    throw ("Group ID '$GroupID' not found.")
}

# Work on AzureAD based groups
if (($targetGroup.GroupTypes -contains "Unified") -or (-not $targetGroup.MailEnabled)) {
    "## Group type: AzureAD"
    # Prepare Request
    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetDevice.id)"
    }
    
    # "Is device member of the the group?" 
    if (Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/$($targetDevice.id)" -ErrorAction SilentlyContinue) {
        "## Device '$($targetDevice.DisplayName)' is already a member of '$($targetGroup.DisplayName)'. No action taken."
    }
    else {
        Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupID/members/`$ref" -Method Post -Body $body | Out-Null
        "## '$($targetDevice.DisplayName)' is added to '$($targetGroup.DisplayName)'."  
    }
} 
else {
    "## Group '$($targetGroup.DisplayName)' is not an AzureAD group. Exiting."
}
