<#
    .SYNOPSIS
    Check a device's presence and risk status in Entra ID and Microsoft Defender for Endpoint

    .DESCRIPTION
    This runbook compares a device between Entra ID and Microsoft Defender for Endpoint based on its Entra device ID. It reports whether the device exists in each service, returns key properties like onboarding and health state, and evaluates the Defender risk score to flag elevated risk.

    .PARAMETER DeviceId
    The Entra device ID of the target device.

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }

param(
    [Parameter(Mandatory = $true)]
    [string] $DeviceId,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region     RJ Log Part
#
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "DeviceId: $DeviceId" -Verbose

#endregion RJ Log Part

############################################################
#region     Result object
#
############################################################

$result = [ordered]@{
    EntraDeviceId    = $DeviceId
    ExistsInEntra    = $false
    ExistsInDefender = $false
    EntraDisplayName = $null
    EntraEnabled     = $null
    EntraTrustType   = $null
    EntraOS          = $null
    EntraLastSignIn  = $null
    MdeDeviceName    = $null
    MdeOnboarding    = $null
    MdeHealthStatus  = $null
    MdeLastSeen      = $null
    RiskScore        = $null
    Status           = $null
    Verdict          = $null
    Recommendation   = $null
    Alert            = $false
}

#endregion Result object

############################################################
#region     Connect Part
#
############################################################

Connect-RjRbGraph
Connect-RjRbDefenderATP

#endregion Connect Part

############################################################
#region     Main Part
#
############################################################

    #region Check Entra ID
    ##############################

    Write-Output ""
    Write-Output "Checking Entra ID"
    Write-Output "---------------------"

    try {
        $entraDevice = Invoke-RjRbRestMethodGraph -Resource "/devices" -OdFilter "deviceId eq '$DeviceId'" -ErrorAction Stop | Select-Object -First 1
    }
    catch {
        $result.Status = "ERROR: Entra query failed - $($_.Exception.Message)"
        [pscustomobject]$result | Format-List
        throw "Entra query failed: $($_.Exception.Message)"
    }

    if ($entraDevice) {
        $result.ExistsInEntra = $true
        $result.EntraDisplayName = $entraDevice.displayName
        $result.EntraEnabled = $entraDevice.accountEnabled
        $result.EntraTrustType = $entraDevice.trustType
        $result.EntraOS = "$($entraDevice.operatingSystem) $($entraDevice.operatingSystemVersion)"
        $result.EntraLastSignIn = $entraDevice.approximateLastSignInDateTime
        Write-Output "Device found in Entra ID: $($entraDevice.displayName)"
    }
    else {
        Write-Output "Device not found in Entra ID."
    }

    #endregion Check Entra ID

    #region Check Defender for Endpoint
    ##############################

    Write-Output ""
    Write-Output "Checking Microsoft Defender for Endpoint"
    Write-Output "---------------------"

    try {
        # From experience the first result seems to be the "freshest" candidate.
        $machine = Invoke-RjRbRestMethodDefenderATP -Resource "/machines" -OdFilter "aadDeviceId eq $DeviceId" -ErrorAction Stop |
            Sort-Object { [datetime]$_.lastSeen } -Descending |
            Select-Object -First 1
    }
    catch {
        $result.Status = "ERROR: Defender query failed - $($_.Exception.Message)"
        [pscustomobject]$result | Format-List
        throw "Defender query failed: $($_.Exception.Message)"
    }

    if ($machine) {
        $result.ExistsInDefender = $true
        $result.MdeDeviceName = $machine.computerDnsName
        $result.MdeOnboarding = $machine.onboardingStatus
        $result.MdeHealthStatus = $machine.healthStatus
        $result.MdeLastSeen = $machine.lastSeen
        $result.RiskScore = $machine.riskScore
        Write-Output "Device found in Defender: $($machine.computerDnsName)"
    }
    else {
        Write-Output "Device not found in Defender for Endpoint."
    }

    #endregion Check Defender for Endpoint

    #region Summarize status
    ##############################

    if (-not $result.ExistsInEntra -and -not $result.ExistsInDefender) {
        $result.Status = "NOT_FOUND: Device exists neither in Entra nor in Defender."
        $result.Verdict = "NOT FOUND"
        $result.Recommendation = "The device ID could not be found in Entra ID or Defender. Verify that the correct device ID was provided."
    }
    elseif ($result.ExistsInEntra -and -not $result.ExistsInDefender) {
        $result.Status = "ENTRA_ONLY: Present in Entra, but not onboarded in Defender (no risk score available)."
        $result.Verdict = "NOT ONBOARDED"
        $result.Recommendation = "The device exists in Entra ID but is not onboarded to Microsoft Defender for Endpoint. Check the Defender onboarding configuration for this device."
    }
    elseif (-not $result.ExistsInEntra -and $result.ExistsInDefender) {
        $result.Status = "DEFENDER_ONLY: Present in Defender, but no Entra device found (possibly stale entry)."
        $result.Verdict = "STALE ENTRY"
        $result.Recommendation = "The device exists in Defender but has no matching Entra ID object. This is often a stale Defender entry - consider removing it if the device is decommissioned."
    }
    else {
        if ($result.RiskScore -in @('Medium', 'High')) {
            $result.Status = "RISK_$($result.RiskScore.ToUpper()): Elevated risk detected."
            $result.Verdict = "AT RISK ($($result.RiskScore.ToUpper()))"
            $result.Recommendation = "Defender reports an elevated risk score ($($result.RiskScore)). Review the device in the Microsoft Defender portal and take remediation action (e.g. investigate alerts, isolate the device)."
            $result.Alert = $true
        }
        elseif ([string]::IsNullOrEmpty($result.RiskScore) -or $result.RiskScore -eq 'None') {
            $result.Status = "OK: No risk (RiskScore = None/empty)."
            $result.Verdict = "OK"
            $result.Recommendation = "No action required. The device is onboarded and reports no elevated risk."
        }
        else {
            $result.Status = "OK: RiskScore = $($result.RiskScore)."
            $result.Verdict = "OK"
            $result.Recommendation = "No action required. The device is onboarded and reports a low risk score ($($result.RiskScore))."
        }
    }

    #endregion Summarize status

#endregion Main Part

############################################################
#region     Output
#
############################################################

$output = [pscustomobject]$result

    #region Summary
    ##############################

    # Friendly display values for the summary block
    $deviceNameDisplay = if ($result.EntraDisplayName) { $result.EntraDisplayName } elseif ($result.MdeDeviceName) { $result.MdeDeviceName } else { "Unknown" }
    $entraStateDisplay = if ($result.ExistsInEntra) { "Yes" } else { "No" }
    if ($result.ExistsInDefender) {
        $defenderStateDisplay = "Yes (Onboarding: $($result.MdeOnboarding), Health: $($result.MdeHealthStatus))"
    }
    else {
        $defenderStateDisplay = "No"
    }
    $riskDisplay = if ([string]::IsNullOrEmpty($result.RiskScore)) { "None" } else { $result.RiskScore }

    Write-Output ""
    Write-Output "========================================================"
    Write-Output " DEVICE SECURITY CHECK - SUMMARY"
    Write-Output "========================================================"
    Write-Output ("  Device          : {0}" -f $deviceNameDisplay)
    Write-Output ("  Entra Device ID : {0}" -f $result.EntraDeviceId)
    Write-Output ("  Verdict         : {0}" -f $result.Verdict)
    Write-Output ("  In Entra ID     : {0}" -f $entraStateDisplay)
    Write-Output ("  In Defender     : {0}" -f $defenderStateDisplay)
    Write-Output ("  Risk Score      : {0}" -f $riskDisplay)
    Write-Output "--------------------------------------------------------"
    Write-Output "  Recommendation:"
    Write-Output ("  {0}" -f $result.Recommendation)
    Write-Output "========================================================"

    #endregion Summary

    #region Details
    ##############################

    Write-Output ""
    Write-Output "Details"
    Write-Output "---------------------"
    Write-Output ""
    Write-Output "Entra ID"
    Write-Output "  Exists           : $($result.ExistsInEntra)"
    Write-Output "  Display Name     : $($result.EntraDisplayName)"
    Write-Output "  Account Enabled  : $($result.EntraEnabled)"
    Write-Output "  Trust Type       : $($result.EntraTrustType)"
    Write-Output "  Operating System : $($result.EntraOS)"
    Write-Output "  Last Sign-In     : $($result.EntraLastSignIn)"
    Write-Output ""
    Write-Output "Microsoft Defender for Endpoint"
    Write-Output "  Exists           : $($result.ExistsInDefender)"
    Write-Output "  Device Name      : $($result.MdeDeviceName)"
    Write-Output "  Onboarding       : $($result.MdeOnboarding)"
    Write-Output "  Health Status    : $($result.MdeHealthStatus)"
    Write-Output "  Last Seen        : $($result.MdeLastSeen)"
    Write-Output "  Risk Score       : $riskDisplay"
    Write-Output ""
    Write-Output "  Status (raw)     : $($result.Status)"

    #endregion Details

if ($output.Alert) {
    Write-Output ""
    Write-Warning "ALERT: $($output.MdeDeviceName) ($DeviceId) -> $($output.Status)"
}

Write-Output ""
Write-Output "Done!"

#endregion Output
