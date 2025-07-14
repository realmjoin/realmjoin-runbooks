<#
.SYNOPSIS
    Reports users with more than five registered devices in Entra ID.

.DESCRIPTION
    This script queries all devices and their registered users, and reports users who have more than five devices registered.
    The output includes the users ObjectId, UPN, and the number of devices.
.INPUTS
RunbookCustomization: {
    "Parameters": {
        "CallerName": {
            "Hide": true
        }
    }
}
#>
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.28.0" }

param (
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
##
########################################################

# Add Caller and Version in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

#endregion

####################################################################
#region Connect to Microsoft Graph
####################################################################

try {
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    Write-Verbose "Successfully connected to Microsoft Graph."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

#endregion

####################################################################
#region Get all devices based on registered users
####################################################################

Write-Output "Querying devices..."
Write-Output "  Note: Depending on the number of devices in the tenant, this process can take several minutes!"
$property = 'id,registeredUsers'

$AllDevices_BasedOnUsers = @()
$uri = "https://graph.microsoft.com/v1.0/devices?`$select=$property&`$expand=registeredUsers"
do {
    $response = Invoke-MgGraphRequest -Method Get -Uri $uri
    $AllDevices_BasedOnUsers += $response.value
    $uri = $response.'@odata.nextLink'
} while ($uri)


$raw = $AllDevices_BasedOnUsers | Where-Object { $_.RegisteredUsers.Count -gt 0 } | Group-Object { $_.RegisteredUsers.Id } | Where-Object Count -gt 5

#endregion

####################################################################
#region Prepare output
####################################################################

# Prepare output. Should contain the user ID, the UPN, and the number of devices
$Output = @()

foreach ($group in $raw) {
    $objectId = $group.Name
    $upn = ($group.Group | Select-Object -First 1).RegisteredUsers.UserPrincipalName
    $deviceCount = $group.Count

    $Output += [PSCustomObject]@{
        ObjectId    = $objectId
        UPN         = $upn
        DeviceCount = $deviceCount
    }
}

Write-Output ""
if ($($Output | Measure-Object).Count -eq 0) {
    Write-Output "No users found with more than five devices."
}else {
    Write-Output "Found $($($Output | Measure-Object).Count) users with more than five devices:"
    $Output | Sort-Object DeviceCount -Descending | Format-Table
}


#endregion