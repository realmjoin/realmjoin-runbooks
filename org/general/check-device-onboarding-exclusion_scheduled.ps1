<#
  .SYNOPSIS
  Add unenrolled Autopilot devices to an exclusion group

  .DESCRIPTION
  This runbook identifies Windows Autopilot devices that are not yet enrolled in Intune and ensures they are members of a configured exclusion group.
  It also removes devices from the group once they are no longer in scope.

  .PARAMETER exclusionGroupName
  Display name of the exclusion group to manage.

  .PARAMETER maxAgeInDays
  Maximum age in days for recently enrolled devices to be considered in grace scope.

  .PARAMETER CallerName
  Caller name for auditing purposes.

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
      "CallerName": {
        "Hide": true
      },
      "exclusionGroupName": {
        "DisplayName": "Exclusion group name"
      },
      "maxAgeInDays": {
        "DisplayName": "Max age in days"
      }
    }
  }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }

param(
  # EntraID exclusion group for Defender Compliance.
  [string]$exclusionGroupName = "cfg - Intune - Windows - Compliance for unenrolled Autopilot devices (devices)",
  [int] $maxAgeInDays = 1,
  # CallerName is tracked purely for auditing purposes
  [Parameter(Mandatory = $true)]
  [string]$CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
  <#
    .SYNOPSIS
    Retrieves all items from a paginated Microsoft Graph API endpoint.

    .DESCRIPTION
    Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
    by following the @odata.nextLink property in the response.

    .PARAMETER Uri
    The initial Microsoft Graph API endpoint URI to query.
  #>
  param(
    [string]$Uri
  )

  $allResults = @()
  $nextLink = $Uri

  do {
    $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET
    if ($response.value) {
      $allResults += $response.value
    }
    $nextLink = $response.'@odata.nextLink'
  } while ($nextLink)

  return $allResults
}

function Invoke-GraphBatch {
  <#
    .SYNOPSIS
    Executes Microsoft Graph requests via the JSON batch endpoint (max 20 per call).
  #>
  param(
    [Parameter(Mandatory = $true)]
    [object[]]$Requests
  )

  # Graph batch API: max 20 requests per call
  $batchSize = 20
  $responses = [System.Collections.Generic.List[object]]::new()

  for ($i = 0; $i -lt $Requests.Count; $i += $batchSize) {
    $chunk = $Requests[$i..([Math]::Min($i + $batchSize - 1, $Requests.Count - 1))]
    $batchBody = @{ requests = @($chunk) }
    $batchResult = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/`$batch" -Method POST -Body $batchBody
    $responses.AddRange([object[]]@($batchResult.responses))
  }

  return $responses
}

function Resolve-EntraDevices {
  <#
    .SYNOPSIS
    Resolves a list of Entra device IDs (azureADDeviceId / azureActiveDirectoryDeviceId)
    to their Entra device objects via the Graph batch API.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyCollection()]
    [string[]]$DeviceIds
  )

  $results = [System.Collections.Generic.List[object]]::new()
  if ($DeviceIds.Count -eq 0) {
    return $results
  }

  $requests = @($DeviceIds | ForEach-Object -Begin { $idx = 1 } -Process {
      $deviceFilter = [System.Uri]::EscapeDataString("deviceId eq '$_'")
      @{
        id     = "$idx"
        method = "GET"
        url    = "/devices?`$filter=$deviceFilter&`$select=id,displayName,deviceId"
      }
      $idx++
    })

  $responses = Invoke-GraphBatch -Requests $requests
  foreach ($r in $responses) {
    if ($r.status -eq 200 -and $r.body.value) {
      $results.AddRange([object[]]@($r.body.value))
    }
  }

  return $results
}

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Microsoft Graph..."
try {
  Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
  Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
  throw
}

#endregion

########################################################
#region     Ensure exclusion group exists
########################################################

$groupFilter = [System.Uri]::EscapeDataString("displayName eq '$exclusionGroupName'")
$exclusionGroupId = ((Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=$groupFilter&`$select=id" -Method GET).value | Select-Object -First 1).id
if (-not $exclusionGroupId) {
  "## Create the exclusion group"
  $mailNickname = $exclusionGroupName.Replace(" ", "").Replace("-", "").Replace("(", "").Replace(")", "")
  if ($mailNickname.Length -gt 50) {
    $mailNickname = $mailNickname.Substring(0, 50)
  }
  $body = @{
    displayName     = $exclusionGroupName
    mailEnabled     = $false
    mailNickname    = $mailNickname
    securityEnabled = $true
  }
  $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups" -Method Post -Body $body
  $exclusionGroupId = $group.id
  "## Sleep for 10 seconds to allow the group to be created"
  Start-Sleep -Seconds 10
}

#endregion

########################################################
#region     Collect devices in grace scope
########################################################

$InGraceDevices = @()

## Get all Autopilot Devices
$APDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities"

"## Search for the Autopilot Devices not yet present in Intune"
# Collect the Entra device IDs of all not-yet-enrolled Autopilot devices, then resolve them in batches.
$apDeviceIds = @($APDevices |
  Where-Object { ($_.enrollmentState -ne "enrolled") -and $_.azureActiveDirectoryDeviceId } |
  Select-Object -ExpandProperty azureActiveDirectoryDeviceId -Unique)
$apResolved = Resolve-EntraDevices -DeviceIds $apDeviceIds
$InGraceDevices += $apResolved
"## $($apResolved.Count) devices found."
""

"## Search for Intune devices younger than maxAgeInDays"
# Filter server-side on operatingSystem and enrolledDateTime so we never pull the full managed device
# inventory into memory (a tenant with ~100k devices would otherwise cause an OutOfMemoryException).
# managedDevice: operatingSystem supports 'eq', enrolledDateTime supports 'gt'.
$dateThreshold = (Get-Date).ToUniversalTime().AddDays(-$maxAgeInDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
$intuneFilter = [System.Uri]::EscapeDataString("operatingSystem eq 'Windows' and enrolledDateTime gt $dateThreshold")
$recentIntuneDevices = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$intuneFilter&`$select=id,azureADDeviceId,enrolledDateTime,operatingSystem"

$intuneDeviceIds = @($recentIntuneDevices |
  Where-Object { $_.azureADDeviceId } |
  Select-Object -ExpandProperty azureADDeviceId -Unique)
$intuneResolved = Resolve-EntraDevices -DeviceIds $intuneDeviceIds
$InGraceDevices += $intuneResolved
"## $($intuneResolved.Count) devices found."
""

#endregion

########################################################
#region     Reconcile exclusion group membership
########################################################

## Get current members of the exclusion group
$exclusionGroupMembers = @(Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/groups/$exclusionGroupId/members?`$select=id")

# Build HashSets for O(1) diffing
$inGraceIds = [System.Collections.Generic.HashSet[string]]::new(
  [string[]]@($InGraceDevices | Where-Object { $_.id } | Select-Object -ExpandProperty id),
  [System.StringComparer]::OrdinalIgnoreCase
)
$currentMemberIds = @($exclusionGroupMembers | Where-Object { $_.id } | Select-Object -ExpandProperty id)
$currentMemberSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$currentMemberIds, [System.StringComparer]::OrdinalIgnoreCase)

$toRemove = @($currentMemberIds | Where-Object { -not $inGraceIds.Contains($_) })
# Select-Object -Unique dedupes devices returned by both the Autopilot and Intune queries
$toAdd = @($InGraceDevices | Where-Object { $_.id -and -not $currentMemberSet.Contains($_.id) } | Select-Object -ExpandProperty id -Unique)

"## Remove members from the group that are not in the InGraceDevices list"
if ($toRemove.Count -gt 0) {
  $removeRequests = @($toRemove | ForEach-Object -Begin { $idx = 1 } -Process {
      @{
        id     = "$idx"
        method = "DELETE"
        url    = "/groups/$exclusionGroupId/members/$_/`$ref"
      }
      $idx++
    })
  $removeResponses = Invoke-GraphBatch -Requests $removeRequests
  $removeFailed = @($removeResponses | Where-Object { $_.status -notin 200, 204, 404 })
  foreach ($r in $removeFailed) {
    Write-RjRbLog -Message "Remove failed (status $($r.status), id $($r.id)): $($r.body.error.message)" -Verbose
  }
}
"## $($toRemove.Count) devices removed."
""

"## Add members to the group that are in the InGraceDevices list and not yet members of the group"
if ($toAdd.Count -gt 0) {
  $addRequests = @($toAdd | ForEach-Object -Begin { $idx = 1 } -Process {
      @{
        id      = "$idx"
        method  = "POST"
        url     = "/groups/$exclusionGroupId/members/`$ref"
        headers = @{ "Content-Type" = "application/json" }
        body    = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$_" }
      }
      $idx++
    })
  $addResponses = Invoke-GraphBatch -Requests $addRequests
  $addFailed = @($addResponses | Where-Object { $_.status -notin 200, 201, 204 -and -not ($_.status -eq 400 -and $_.body.error.message -like "*already exist*") })
  foreach ($r in $addFailed) {
    Write-RjRbLog -Message "Add failed (status $($r.status), id $($r.id)): $($r.body.error.message)" -Verbose
  }
}
"## $($toAdd.Count) devices added."

#endregion
