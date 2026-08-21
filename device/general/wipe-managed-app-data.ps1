<#
    .SYNOPSIS
    App selective wipe - remove company app data from this MAM device

    .DESCRIPTION
    Performs an "App selective wipe" (Mobile Application Management) for this device, mirroring the
    Intune portal flow "Apps > App selective wipe > Create wipe request". It removes company data
    from apps protected by app protection policies without wiping the whole device - typically
    used for lost or stolen devices that are MAM-managed (not MDM-enrolled).

    The runbook resolves the users registered on the device, collects their MAM app registrations
    that belong to this device and creates a wipe request for each affected user/device tag. The
    wipe is executed the next time each protected app checks in. Wipe requests can be monitored
    and cancelled in the Intune portal under "Apps > App selective wipe".

    .PARAMETER DeviceId
    The device ID of the target device.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0" }

param (
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

############################################################
#region     RJ Log Part
#
############################################################

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose

#endregion RJ Log Part

############################################################
#region     Functions
#
############################################################

function Get-AllGraphPages {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )
    $results = @()
    $nextLink = $Uri
    while ($nextLink) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
        if ($response.value) {
            $results += $response.value
        }
        $nextLink = $response.'@odata.nextLink'
    }
    return $results
}

#endregion Functions

############################################################
#region     Connect Part
#
############################################################

try {
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    throw ("Graph connection failed")
}

#endregion Connect Part

############################################################
#region     StatusQuo & Preflight-Check Part
#
############################################################

# Resolve the target device
$deviceResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=deviceId eq '$DeviceId'&`$select=id,deviceId,displayName"
$targetDevice = $deviceResponse.value | Select-Object -First 1
if (-not $targetDevice) {
    throw "DeviceId '$DeviceId' not found in EntraID."
}

"## Processing device '$($targetDevice.displayName)' (DeviceId '$DeviceId')"

# MAM app registrations belong to users, not to the device object,
# so resolve the users registered on this device first.
$deviceUsers = Get-AllGraphPages -Uri "https://graph.microsoft.com/v1.0/devices/$($targetDevice.id)/registeredUsers"
if (-not $deviceUsers -or $deviceUsers.Count -eq 0) {
    $deviceUsers = Get-AllGraphPages -Uri "https://graph.microsoft.com/v1.0/devices/$($targetDevice.id)/registeredOwners"
}
if (-not $deviceUsers -or $deviceUsers.Count -eq 0) {
    "## No registered users/owners found on this device."
    "## MAM app registrations are tied to a user, so the wipe cannot be mapped without one."
    "## Execution stopped."
    throw "No registered user found for device '$($targetDevice.displayName)' (DeviceId '$DeviceId')."
}
$deviceUsers | ForEach-Object {
    "## Registered user: '$($_.userPrincipalName)'"
}
""

# Collect the MAM app registrations of each registered user that belong to this device.
# Beta is required to get the azureADDeviceId of a registration. It can be empty even for
# EntraID-registered devices, so registrations are matched by the device's display name as fallback.
$matchedRegistrations = @()
$fallbackUsed = $false
foreach ($user in $deviceUsers) {
    try {
        $registrations = Get-AllGraphPages -Uri "https://graph.microsoft.com/beta/users/$($user.id)/managedAppRegistrations"
    }
    catch {
        "## Error Message: $($_.Exception.Message)"
        "## Please see 'All logs' for more details."
        "## Execution stopped."
        throw "Could not read MAM app registrations for user '$($user.userPrincipalName)'."
    }
    if (-not $registrations) {
        continue
    }

    $byDeviceId = @($registrations | Where-Object { $_.azureADDeviceId -eq $DeviceId })
    if ($byDeviceId.Count -gt 0) {
        $userMatches = $byDeviceId
    }
    else {
        $userMatches = @($registrations | Where-Object { (-not $_.azureADDeviceId) -and ($_.deviceName -eq $targetDevice.displayName) })
        if ($userMatches.Count -gt 0) {
            $fallbackUsed = $true
        }
    }

    foreach ($registration in $userMatches) {
        # The app identifier property differs per platform (iOS/Android/Windows).
        $appId = $registration.appIdentifier.bundleId
        if (-not $appId) { $appId = $registration.appIdentifier.packageId }
        if (-not $appId) { $appId = $registration.appIdentifier.windowsAppId }
        $matchedRegistrations += [PSCustomObject]@{
            UserId            = $user.id
            UserPrincipalName = $user.userPrincipalName
            DeviceTag         = $registration.deviceTag
            DeviceName        = $registration.deviceName
            DeviceType        = $registration.deviceType
            AppId             = $appId
            LastSync          = $registration.lastSyncDateTime
        }
    }
}

if ($matchedRegistrations.Count -eq 0) {
    "## No MAM app registrations found for this device. Nothing to wipe."
    exit
}

if ($fallbackUsed) {
    "## Note: Some registrations do not carry an EntraID device id and were matched by device name '$($targetDevice.displayName)' instead."
    ""
}

# One wipe request per user and device tag covers all registered apps of that user on the device.
$wipeTargets = $matchedRegistrations | Group-Object -Property { "$($_.UserId)|$($_.DeviceTag)" } | ForEach-Object {
    $first = $_.Group | Select-Object -First 1
    [PSCustomObject]@{
        UserId            = $first.UserId
        UserPrincipalName = $first.UserPrincipalName
        DeviceTag         = $first.DeviceTag
        DeviceName        = $first.DeviceName
        DeviceType        = $first.DeviceType
        Apps              = @($_.Group | ForEach-Object { $_.AppId } | Where-Object { $_ } | Sort-Object -Unique)
        LastSync          = ($_.Group | ForEach-Object { $_.LastSync } | Sort-Object -Descending | Select-Object -First 1)
    }
}

"## MAM app registrations found for this device:"
foreach ($wipeTarget in $wipeTargets) {
    ""
    "## Device '$($wipeTarget.DeviceName)' (Type: '$($wipeTarget.DeviceType)') - user '$($wipeTarget.UserPrincipalName)'"
    "##   Protected apps: $($wipeTarget.Apps.Count), last app sync: $($wipeTarget.LastSync)"
    $wipeTarget.Apps | ForEach-Object {
        "##   - $_"
    }
}
""

#endregion StatusQuo & Preflight-Check Part

############################################################
#region     Main Part
#
############################################################

$failedWipes = 0
foreach ($wipeTarget in $wipeTargets) {
    "## Creating wipe request for device '$($wipeTarget.DeviceName)', user '$($wipeTarget.UserPrincipalName)'..."
    $body = @{
        deviceTag = $wipeTarget.DeviceTag
    }
    try {
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($wipeTarget.UserId)/wipeManagedAppRegistrationsByDeviceTag" -Body $body -ContentType "application/json" | Out-Null
        "## Wipe request created."
    }
    catch {
        $failedWipes++
        "## Error Message: $($_.Exception.Message)"
        "## Please see 'All logs' for more details."
        "## Creating the wipe request for user '$($wipeTarget.UserPrincipalName)' failed!"
    }
    ""
}

if ($failedWipes -gt 0) {
    throw "$failedWipes of $($wipeTargets.Count) wipe request(s) could not be created. Please see the output above."
}

#endregion Main Part

############################################################
#region     Cleanup
#
############################################################

"## Result:"
"## $($wipeTargets.Count) wipe request(s) successfully created for device '$($targetDevice.displayName)'."
"## Company app data will be removed the next time each protected app checks in on the device."
"## Pending wipe requests can be monitored and cancelled in the Intune portal under 'Apps > App selective wipe'."
""
"## Important - device objects are NOT removed by this runbook:"
"## This runbook only removes company data from MAM-protected apps (app selective wipe)."
"## The device object itself still exists in EntraID (and in Intune/Autopilot, if it is additionally MDM-enrolled)."
"## To disable or remove the device from EntraID, Intune and Autopilot as well, run the 'Outphase Device' runbook (Device \ General) on this device afterwards."

#endregion Cleanup
