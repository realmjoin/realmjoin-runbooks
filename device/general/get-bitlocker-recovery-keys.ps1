<#
  .SYNOPSIS
  Get BitLocker recovery keys for a device

  .DESCRIPTION
  This runbook retrieves BitLocker recovery keys for a specified device.
  It first gets all BitLocker recovery key IDs associated with the device,
  then retrieves the actual recovery keys.

  .NOTES
  Permissions (Graph):
  - Device.Read.All
  - BitlockerKey.Read.All

  .PARAMETER DeviceId
  The Azure AD device ID of the device.

  .PARAMETER CallerName
  Caller name for auditing purposes.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Function to get BitLocker keys for a device
function Get-BitLockerKeys {
    param (
        [string]$azureADDeviceId
    )
    
    $recoveryKeys = @()
    
    try {
        # Get all BitLocker recovery key IDs for the device
        $keyResponse = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys" -OdFilter "deviceId eq '$azureADDeviceId'" -Method GET -Beta
        
        if ($keyResponse -and $keyResponse.Count -gt 0) {
            # Sort keys by creation date (newest first)
            $sortedKeys = $keyResponse | Sort-Object -Property createdDateTime -Descending
            
            foreach ($keyInfo in $sortedKeys) {
                try {
                    # Get the actual recovery key
                    $recoveryKeyDetail = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys/$($keyInfo.id)" -OdSelect "key" -Method GET -Beta
                    
                    if ($recoveryKeyDetail) {
                        $recoveryKeys += [PSCustomObject]@{
                            KeyId           = $keyInfo.id
                            CreatedDateTime = $keyInfo.createdDateTime
                            RecoveryKey     = $recoveryKeyDetail.key
                        }
                    }
                }
                catch {
                    Write-RjRbLog -Message "Error retrieving key details for $($keyInfo.id): $_" -Verbose
                }
            }
        }
        
        return $recoveryKeys
    }
    catch {
        Write-RjRbLog -Message "Error retrieving BitLocker keys: $_" -Verbose
        return $recoveryKeys
    }
}

# Connect to Microsoft Graph
Connect-RjRbGraph -Force

try {
    # Get device details from Intune
    $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
    
    if (-not $intuneDevice) {
        Write-Output "## Device not found in Intune. Checking Azure AD..."
        $azureADDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'"
        
        if (-not $azureADDevice) {
            Write-Output "## Device not found in Azure AD."
            exit
        }
        
        $deviceName = $azureADDevice.displayName
        $serialNumber = "Not available"
        $lastSyncDateTime = "Not available"
    }
    else {
        $deviceName = $intuneDevice.deviceName
        $serialNumber = $intuneDevice.serialNumber
        $lastSyncDateTime = $intuneDevice.lastSyncDateTime
    }
    
    # Get BitLocker keys
    $bitlockerKeys = Get-BitLockerKeys -azureADDeviceId $DeviceId
    
    # Create result object
    $result = [PSCustomObject]@{
        DeviceName                  = $deviceName
        SerialNumber                = $serialNumber
        "BitLocker Keys in EntraID" = if ($bitlockerKeys.Count -gt 0) { "Yes ($($bitlockerKeys.Count))" } else { "No" }
        "Last Sync With Intune"     = if ($lastSyncDateTime -ne "Not available") {
            (Get-Date $lastSyncDateTime).ToString("yyyy-MM-dd")
        }
        else {
            $lastSyncDateTime
        }
    }
    
    # Display device information
    Write-Output "## Device Details:"
    Write-Output "- Device Name: $($result.DeviceName)"
    Write-Output "- Serial Number: $($result.SerialNumber)"
    Write-Output "- BitLocker Keys in EntraID: $($result.'BitLocker Keys in EntraID')"
    Write-Output "- Last Sync With Intune: $($result.'Last Sync With Intune')"
    
    # Display BitLocker keys if available
    if ($bitlockerKeys.Count -gt 0) {
        Write-Output ""
        Write-Output "## BitLocker Recovery Keys:"
        
        foreach ($key in $bitlockerKeys) {
            Write-Output ""
            Write-Output "- Key ID: $($key.KeyId)"
            Write-Output "  Created: $($key.CreatedDateTime)"
            Write-Output "  Recovery Key: $($key.RecoveryKey)"
        }
    }
    else {
        Write-Output ""
        Write-Output "## No BitLocker recovery keys found for this device."
    }
}
catch {
    $errorResponse = $_
    Write-Output "## Error processing device:"
    Write-Output $errorResponse
    Write-RjRbLog -Message "Error: $errorResponse" -Verbose
}

Write-Output ""
Write-Output "## Note: This script uses the beta endpoint for BitLocker API calls."