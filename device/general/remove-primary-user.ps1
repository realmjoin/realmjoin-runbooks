<#
.SYNOPSIS
    Removes the primary user from a device.
.DESCRIPTION
    This script removes the assigned primary user from a specified Azure AD device.
    It requires the DeviceId of the target device and the name of the caller for auditing purposes.
.PARAMETER DeviceId
    The unique identifier of the device from which the primary user will be removed.
    It will be prefilled from the RealmJoin Portal and is hidden in the UI.
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.34.0" }

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

$Version = "1.0.0"
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
