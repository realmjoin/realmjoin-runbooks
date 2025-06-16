<#
.SYNOPSIS
    Reports all managed devices in Intune that do not have a primary user assigned.
.DESCRIPTION
    This script retrieves all managed devices from Intune, and filters out those without a primary user (userId).
    The output is a formatted table showing Object ID, Device ID, Display Name, and Last Sync Date/Time for each device without a primary user.
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
#region Get all devices without registered users
####################################################################

# Define the base URI for the Microsoft Graph API to retrieve managed devices and the properties to select.
$baseURI = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'

$selectQuery = "?&$select="
$selectProperties = "id,azureADDeviceId,lastSyncDateTime,deviceName,userId"

$raw = @()
$uri = $baseURI + $selectQuery + $selectProperties

do {
    $response = Invoke-MgGraphRequest -Uri $uri -Method Get -ErrorAction Stop
    $raw += $response.value | Where-Object {
        # Filter devices where userId is null or empty
        -not $_.userId -or [string]::IsNullOrEmpty($_.userId)
    }
    $uri = $response.'@odata.nextLink'
} while ($null -ne $uri)

#endregion

####################################################################
#region Output Devices Without Primary User
####################################################################

# Create a PSCustomObject with all devices without registered users, and prettify the output
$devicesWithoutPrimaryUser = $raw | ForEach-Object {
    [PSCustomObject]@{
        ObjectId           = $_.id
        DeviceId           = $_.azureADDeviceId
        DisplayName        = $_.deviceName
        LastSyncDateTime   = $_.lastSyncDateTime
    }
}

$devicesWithoutPrimaryUser | Sort-Object DisplayName | Format-Table -AutoSize

#endregion