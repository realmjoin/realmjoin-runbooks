<#
    .SYNOPSIS
    Remove the primary user from this device

    .DESCRIPTION
    Clears the primary user of this device in Intune. The device then has no assigned user, which is useful for shared devices or before handing the device to someone else. The user account itself is not changed.

    .PARAMETER DeviceId
    Entra ID device ID of the device the runbook acts on. Set by the portal from the selected device.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "DeviceId": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param (
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
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

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "Device Id: $DeviceId" -Verbose

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
#region Remove Primary User from Device
####################################################################
# Define the base URI for the Microsoft Graph API to remove the primary user from a managed device.
$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($DeviceId)')/users/`$ref"

try {
    Write-Verbose "Attempting to remove primary user from device with ID: $($DeviceId)"
    $tmp = Invoke-MgGraphRequest -Method DELETE -Uri $uri -ErrorAction Stop
    Write-Verbose "Successfully sent request to remove primary user."
    if ($null -ne $tmp) {
        Clear-Variable -Name tmp -ErrorAction Ignore | Out-Null
    }
}
catch {
    Write-Error "Failed to remove primary user from device with ID: $DeviceId. Error: $($_.Exception.Message)"
    throw
}

Write-Output "Successfully removed primary user from device with ID: $($DeviceId)."
#endregion
