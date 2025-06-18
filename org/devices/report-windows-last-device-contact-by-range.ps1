<#
.SYNOPSIS
    Reports Windows devices with last device contact within a specified date range.

.DESCRIPTION
    This Runbook retrieves a list of Windows devices from Azure AD / Intune, filtered by their
    last device contact time (lastSyncDateTime). As a dropdown for the date range, you can select from 0-30 days, 30-90 days, 90-180 days, 180-365 days, or 365+ days.
    The output includes the device name, last sync date, user ID, user display name, and user principal name.

.PARAMETER DateRange
    Date range for filtering devices based on their last contact time.

.INPUTS
RunbookCustomization: {
    "Parameters": {
        "DateRange": {
            "Name": "DateRange",
            "Label": "Select Last Device Contact Range (days)",
            "Description": "Filter devices based on their last contact time.",
            "Required": true,
            "SelectSimple": {
                "0-30 days": "0-30",
                "30-90 days": "30-90",
                "90-180 days": "90-180",
                "180-365 days": "180-365",
                "365 days and more": "365+"
            }
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.28.0" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("0-30", "30-90", "90-180", "180-365", "365+")]
    [string]$DateRange,
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
Write-RjRbLog -Message "DateRange: $DateRange" -Verbose

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
#region Retrieve Windows Devices by Last Device Contact Date Range
####################################################################

#region Prepare parameters and filters
$now = Get-Date
$startDate = $null
$endDate = $null

switch ($DateRange) {
    "0-30" {
        $startDate = $now.AddDays(-30)
        $endDate = $now
    }
    "30-90" {
        $startDate = $now.AddDays(-90)
        $endDate = $now.AddDays(-30)
    }
    "90-180" {
        $startDate = $now.AddDays(-180)
        $endDate = $now.AddDays(-90)
    }
    "180-365" {
        $startDate = $now.AddDays(-365)
        $endDate = $now.AddDays(-180)
    }
    "365+" {
        # For "365+", $startDate remains $null, meaning no lower bound on age.
        # We will filter for devices with contact date *older than or equal to* 365 days ago.
        $endDate = $now.AddDays(-365)
    }
}

$baseFilter = "operatingSystem eq 'Windows'"
$dateFilter = ""

if ($DateRange -eq "365+") {
    $endDateISO = $endDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $dateFilter = "lastSyncDateTime le $($endDateISO)"
    Write-Verbose "Filtering for devices with last contact on or before $($endDateISO)."
}
else {
    $startDateISO = $startDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endDateISO = $endDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $dateFilter = "lastSyncDateTime ge $($startDateISO) and lastSyncDateTime le $($endDateISO)"
    Write-Verbose "Filtering for devices with last contact between $($startDateISO) and $($endDateISO)."
}

$baseURI = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter='
$filterQuery = "$($baseFilter) and $($dateFilter)"
$selectQuery = "&$select="
$selectProperties = "id,azureADDeviceId,lastSyncDateTime,deviceName,userId,userDisplayName,userPrincipalName"
$selectProperties_Array = $selectProperties -split ',' | ForEach-Object { $_.Trim() }

$fullURI = $baseURI + $filterQuery + $selectQuery + $selectProperties

#endregion

#region Fetch Devices

$allDevices = @()
$currentURI = $fullURI

try {
    Write-Verbose "Retrieving devices from Microsoft Graph with initial filter: $($filterQuery)"
    Write-Verbose "Initial URI: $currentURI"
    do {
        Write-Verbose "Fetching data from URI: $currentURI"
        $response = Invoke-MgGraphRequest -Uri $currentURI -Method Get -ErrorAction Stop
        if ($response -and $response.value) {
            $allDevices += $response.value | Select-Object -Property $selectProperties_Array
            Write-Verbose "Retrieved $($response.value.Count) devices in this batch. Total devices so far: $(($allDevices | Measure-Object).Count)."
        }
        else {
            Write-Verbose "No devices found in this batch or response format unexpected."
        }
        $currentURI = $response.'@odata.nextLink'
    } while ($null -ne $currentURI)

    Write-Verbose "Successfully retrieved all devices. Total count: $(($allDevices | Measure-Object).Count)."
}
catch {
    Write-Error "Failed to retrieve devices: $($_.Exception.Message)"
    # If an error occurs, $devices might be partially populated or null.
    # Depending on requirements, you might want to clear $devices or handle it.
    # For now, we'll let it be as is and throw the exception.
    throw
}

#endregion
#endregion

######################################################################
#region Output Devices
######################################################################

#Prettify the property names for better readability
$outputDevices = $allDevices | ForEach-Object {
    [PSCustomObject]@{
        DeviceName          = $_.deviceName
        LastSyncDateTime    = $_.lastSyncDateTime
        IntuneDeviceId      = $_.id
        EntraIdDeviceId     = $_.azureADDeviceId
        UserDisplayName     = $_.userDisplayName
        UserPrincipalName   = $_.userPrincipalName
        UserId              = $_.userId
    }
}


Write-Verbose "Resulting devices: $(($outputDevices | Measure-Object).Count)"
if ($(($outputDevices | Measure-Object).Count) -eq 0) {
    Write-Output "No devices found matching the specified date range."
}
else {
    # Reduced properties in the output to optimize readability
    $outputDevices | Select-Object DeviceName, LastSyncDateTime, IntuneDeviceId, UserPrincipalName | Format-Table
}
