# This will import a windows device into windows autopilot
#
# Permissions: MS Graph
# - DeviceManagementServiceConfig.ReadWrite.All

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

param(
    [Parameter(Mandatory = $true)]
    [string] $SerialNumber,
    [Parameter(Mandatory = $true)]
    [string] $HardwareIdentifier,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [string] $AssignedUser = "",
    [bool] $Wait = $true

)

Connect-RjRbGraph

$body = @{
    serialNumber       = $SerialNumber 
    hardwareIdentifier = $HardwareIdentifier
    # groupTag = ""
}

# Find assigned user's name
if ($AssignedUser) {
    $username = (Invoke-RjRbRestMethodGraph -Resource "/users/$AssignedUser").UserPrincipalName
    $body += @{ assignedUserPrincipalName = $username }
}

# Start the import
$result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedWindowsAutopilotDeviceIdentities" -Method "POST" -Body $body

"Import of device $SerialNumber started."

# Track the import's progress
if ($Wait) {
    while (($result.state.deviceImportStatus -ne "complete") -and ($result.state.deviceImportStatus -ne "error")) {
        "."
        Start-Sleep -Seconds 20
        $result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedWindowsAutopilotDeviceIdentities/$($result.id)" -Method Get
    }
    if ($result.state.deviceImportStatus -eq "complete") {
        "Import of device $SerialNumber is successfull."
    }
    else {
        write-error ($result.state)
        throw "Import of device $SerialNumber failed."
    }
}

