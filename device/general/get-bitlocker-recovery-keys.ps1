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

# Connect to Microsoft Graph
Connect-RjRbGraph -Force

# Diagnostic: Check permissions by testing access to different endpoints
Write-Output "## Checking permissions..."
try {
    # Test Device.Read.All permission
    $deviceTest = Invoke-RjRbRestMethodGraph -Resource "/devices?`$top=1" -ErrorAction Stop
    Write-Output "- Device.Read.All permission: Available"
}
catch {
    Write-Output "- Device.Read.All permission: NOT available"
    Write-Output "  Error: $_"
}

try {
    # Test if we can access BitLocker API (v1.0 endpoint)
    $bitlockerTest = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys?`$top=1" -ErrorAction Stop
    Write-Output "- BitlockerKey.Read.All permission: Available"
}
catch {
    Write-Output "- BitlockerKey.Read.All permission: NOT available (v1.0 endpoint)"
    Write-Output "  Error: $_"
    
    # Try beta endpoint as fallback
    try {
        $bitlockerTestBeta = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys?`$top=1" -Beta -ErrorAction Stop
        Write-Output "- BitlockerKey.Read.All permission: Available (beta endpoint)"
    }
    catch {
        Write-Output "- BitlockerKey.Read.All permission: NOT available (beta endpoint)"
        Write-Output "  Error: $_"
    }
}

Write-Output ""

# Get device details first
try {
    $deviceDetailsResponse = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'"
    if ($deviceDetailsResponse) {
        Write-Output "## Device Details:"
        Write-Output "- Device Name: $($deviceDetailsResponse.displayName)"
        
        # Get Intune device to get serial number
        $intuneDevice = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/managedDevices" -OdFilter "azureADDeviceId eq '$DeviceId'" -ErrorAction SilentlyContinue
        if ($intuneDevice) {
            Write-Output "- Serial Number: $($intuneDevice.serialNumber)"
        }
        else {
            Write-Output "- Serial Number: Not available"
        }
    }
}
catch {
    Write-Output "## Error retrieving device details: $_"
}

# Get BitLocker recovery keys for the device
Write-Output ""
Write-Output "## Getting BitLocker recovery keys for device ID: $DeviceId"

try {
    # First, get all BitLocker recovery key IDs for the device
    $recoveryKeysResponse = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys" -OdFilter "deviceId eq '$DeviceId'" -Method GET
    
    if (-not $recoveryKeysResponse -or $recoveryKeysResponse.Count -eq 0) {
        Write-Output "## No BitLocker recovery keys found for this device."
        exit
    }
    
    Write-Output "## Found $($recoveryKeysResponse.Count) BitLocker recovery key(s)"
    Write-Output "## Keys are sorted by creation date (newest first)"
    
    # Sort recovery keys by creation date (newest first)
    $sortedRecoveryKeys = $recoveryKeysResponse | Sort-Object -Property createdDateTime -Descending
    
    # Display information about each recovery key
    foreach ($recoveryKeyInfo in $sortedRecoveryKeys) {
        $recoveryKeyId = $recoveryKeyInfo.id
        Write-Output ""
        Write-Output "## Recovery Key ID: $recoveryKeyId"
        Write-Output "- Created: $($recoveryKeyInfo.createdDateTime)"
        
        # Get the actual recovery key
        try {
            $recoveryKeyResponse = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys/$recoveryKeyId" -OdSelect "key" -Method GET
            
            if ($recoveryKeyResponse) {
                Write-Output "- Recovery Key: $($recoveryKeyResponse.key)"
            }
            else {
                Write-Output "- Unable to retrieve the recovery key value."
            }
        }
        catch {
            $errorResponse = $_
            Write-Output "- Error retrieving recovery key: $errorResponse"
        }
    }
}
catch {
    $errorResponse = $_
    if ($errorResponse -match '404') {
        Write-Output "## No recovery keys found."
        Write-RjRbLog -Message "## Error: $($errorResponse)" -Verbose
    }
    elseif ($errorResponse -match '403' -or $errorResponse -match 'authorization_error') {
        Write-Output "## Forbidden. Check Graph permissions of automation account."
        Write-Output "## Required permission: BitlockerKey.Read.All"
        Write-Output "## Note: This permission must be granted with admin consent."
        Write-Output "## Verify in Azure Portal: Azure Active Directory > App registrations > Your App > API permissions"
        Write-RjRbLog -Message "## Error: $($errorResponse)" -Verbose
        
        # Try beta endpoint as fallback
        Write-Output ""
        Write-Output "## Attempting to use beta endpoint as fallback..."
        try {
            $recoveryKeysResponseBeta = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys" -OdFilter "deviceId eq '$DeviceId'" -Method GET -Beta
            
            if (-not $recoveryKeysResponseBeta -or $recoveryKeysResponseBeta.Count -eq 0) {
                Write-Output "## No BitLocker recovery keys found for this device (beta endpoint)."
                exit
            }
            
            Write-Output "## Found $($recoveryKeysResponseBeta.Count) BitLocker recovery key(s) using beta endpoint"
            Write-Output "## Keys are sorted by creation date (newest first)"
            
            # Sort recovery keys by creation date (newest first)
            $sortedRecoveryKeysBeta = $recoveryKeysResponseBeta | Sort-Object -Property createdDateTime -Descending
            
            # Display information about each recovery key
            foreach ($recoveryKeyInfo in $sortedRecoveryKeysBeta) {
                $recoveryKeyId = $recoveryKeyInfo.id
                Write-Output ""
                Write-Output "## Recovery Key ID: $recoveryKeyId"
                Write-Output "- Created: $($recoveryKeyInfo.createdDateTime)"
                
                # Get the actual recovery key
                try {
                    $recoveryKeyResponse = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/bitlocker/recoveryKeys/$recoveryKeyId" -OdSelect "key" -Method GET -Beta
                    
                    if ($recoveryKeyResponse) {
                        Write-Output "- Recovery Key: $($recoveryKeyResponse.key)"
                    }
                    else {
                        Write-Output "- Unable to retrieve the recovery key value."
                    }
                }
                catch {
                    $errorResponse = $_
                    Write-Output "- Error retrieving recovery key: $errorResponse"
                }
            }
        }
        catch {
            Write-Output "## Beta endpoint also failed. Error: $_"
        }
    }
    else {
        Write-Output "## Error retrieving BitLocker recovery keys."
        Write-Output "## Error: $($errorResponse)"
    }
}

Write-Output ""
Write-Output "## Troubleshooting Notes:"
Write-Output "1. Ensure the enterprise app has BitlockerKey.Read.All permission"
Write-Output "2. Ensure admin consent has been granted for the permission"
Write-Output "3. The BitLocker API might require using the beta endpoint in some cases"
Write-Output "4. If using a service principal, ensure it has the correct application permissions"