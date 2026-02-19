<#
    .SYNOPSIS
    Import a Windows device into Windows Autopilot

    .DESCRIPTION
    This runbook imports a Windows device into Windows Autopilot using the device serial number and hardware hash.
    It can optionally wait for the import job to finish and supports tagging during import.

    .PARAMETER SerialNumber
    Device serial number as returned by Get-WindowsAutopilotInfo.

    .PARAMETER HardwareIdentifier
    Device hardware hash as returned by Get-WindowsAutopilotInfo.

    .PARAMETER AssignedUser
    Optional user to assign to the Autopilot device.

    .PARAMETER Wait
    If set to true, the runbook waits until the import job completes.

    .PARAMETER GroupTag
    Optional group tag to apply to the imported device.

    .PARAMETER CallerName
    Caller name for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "SerialNumber": {
                "DisplayName": "'Device Serial Number' from Get-WindowsAutopilotInfo"
            },
            "HardwareIdentifier": {
                "DisplayName": "'Hardware Hash' from Get-WindowsAutopilotInfo"
            },
            "AssignedUser": {
                "DisplayName": "Assign device to this user (optional)",
                "Hide": true // MS removed the ability to assign users directly via Autopilot
            },
            "Wait": {
                "DisplayName": "Wait for job to finish"
            },
            "GroupTag": {
                "DisplayName": "Group tag (optional)"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $SerialNumber,
    [Parameter(Mandatory = $true)]
    [string] $HardwareIdentifier,
    ## MS removed the ability to assign users directly via Autopilot
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Assign device to this user (optional)"  -Filter "userType eq 'Member'" } )]
    [string] $AssignedUser = "",
    [bool] $Wait = $true,
    [string] $GroupTag = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$body = @{
    serialNumber       = $SerialNumber
    hardwareIdentifier = $HardwareIdentifier
    # groupTag = ""
}

## MS removed the ability to assign users directly via Autopilot
if ($AssignedUser) {
    ## Find assigned user's name
    $username = (Invoke-RjRbRestMethodGraph -Resource "/users/$AssignedUser").UserPrincipalName
    $body += @{ assignedUserPrincipalName = $username }
}

if ($groupTag) {
    $body += @{ groupTag = $GroupTag }
}

# Start the import
$result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedWindowsAutopilotDeviceIdentities" -Method "POST" -Body $body

"## Import of device $SerialNumber started."

# Track the import's progress
if ($Wait) {
    while (($result.state.deviceImportStatus -ne "complete") -and ($result.state.deviceImportStatus -ne "error")) {
        "## ."
        Start-Sleep -Seconds 20
        $result = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/importedWindowsAutopilotDeviceIdentities/$($result.id)" -Method Get
    }
    if ($result.state.deviceImportStatus -eq "complete") {
        "## Import of device $SerialNumber is successfull."
    }
    else {
        write-error ($result.state)
        throw "Import of device $SerialNumber failed."
    }
}
