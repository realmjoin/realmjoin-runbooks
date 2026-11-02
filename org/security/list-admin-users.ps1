<#
	.SYNOPSIS
	List all Entra ID admins and check their MFA methods

	.DESCRIPTION
	Lists every user and service principal that holds a built-in Entra ID role, including PIM eligible assignments, as an admin-to-role report. Optionally the registered authentication methods of each admin are checked to show who is protected by MFA, with a choice of which methods count. The report can be uploaded as CSV to an Azure Storage account. Nothing is changed.

	.PARAMETER ExportToFile
	Uploads the report as CSV to the storage account configured in the tenant settings.

	.PARAMETER PimEligibleUntilInCSV
	Adds the end dates of PIM eligible and active assignments to the CSV report.

	.PARAMETER ContainerName
	Storage container the report files are uploaded to. Taken from the tenant setting ListAdminsReport.Container, otherwise set per runbook.

	.PARAMETER ResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting ListAdminsReport.ResourceGroup; when it is not set, RJReport.StorageAccount.ResourceGroup is used.

	.PARAMETER StorageAccountName
	Storage account for report uploads. Taken from the tenant setting ListAdminsReport.StorageAccount.Name; when it is not set, RJReport.StorageAccount.StorageAccountName is used.

	.PARAMETER SubscriptionId
	Subscription ID of the storage account given in ResourceGroupName and StorageAccountName. Not taken from a tenant setting; the subscription the managed identity signs in to is used when empty.

	.PARAMETER StorageAccountLocation
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER StorageAccountSku
	No longer used, because the storage account is not created any more. Kept so existing schedules and API calls keep starting; a passed value only adds a deprecation warning to the run.

	.PARAMETER QueryMfaState
	With the check, each admin gets a column showing whether a method that counts as MFA is registered; without it, the report lists only the role assignments.

	.PARAMETER TrustEmailMfa
	Counts email as a valid MFA method.

	.PARAMETER TrustPhoneMfa
	Counts phone calls and SMS as a valid MFA method.

	.PARAMETER TrustSoftwareOathMfa
	Counts software OATH tokens as a valid MFA method.

	.PARAMETER TrustWinHelloMFA
	Counts Windows Hello for Business as a valid MFA method.

	.PARAMETER RJReportResourceGroupName
	Resource group of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.ResourceGroup and used when ListAdminsReport.ResourceGroup is not set.

	.PARAMETER RJReportStorageAccountName
	Storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.StorageAccountName and used when ListAdminsReport.StorageAccount.Name is not set.

	.PARAMETER RJReportSubscriptionId
	Subscription ID of the storage account for report uploads. Taken from the tenant setting RJReport.StorageAccount.SubscriptionId and used when the storage account comes from RJReport.StorageAccount.

	.PARAMETER LinkExpiryDays
	Number of days a download link stays valid. Taken from the tenant setting RJReport.StorageAccount.LinkExpiryDays.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"CallerName": {
				"Hide": true
			},
			"ContainerName": {
				"Hide": true
			},
			"ResourceGroupName": {
				"Hide": true
			},
			"StorageAccountName": {
				"Hide": true
			},
			"SubscriptionId": {
				"Hide": true
			},
			"StorageAccountLocation": {
				"Hide": true
			},
			"StorageAccountSku": {
				"Hide": true
			},
			"RJReportResourceGroupName": {
				"Hide": true
			},
			"RJReportStorageAccountName": {
				"Hide": true
			},
			"RJReportSubscriptionId": {
				"Hide": true
			},
			"LinkExpiryDays": {
				"Hide": true
			},
			"QueryMfaState": {
				"Select": {
					"Options": [
						{
							"Display": "Check and report the MFA state of every admin",
							"Value": true
						},
						{
							"Display": "Do not check MFA states",
							"Value": false,
							"Customization": {
								"Hide": [
									"TrustEmailMfa",
									"TrustPhoneMfa",
									"TrustSoftwareOathMfa",
									"TrustWinHelloMFA"
								]
							}
						}
					]
				}
			}
		}
	}

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }
#Requires -Modules @{ModuleName = "Az.Accounts"; ModuleVersion = "5.5.2" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Upload the report as CSV?" } )]
    [bool] $ExportToFile = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Include PIM end dates in the CSV?" } )]
    [bool] $PimEligibleUntilInCSV = $false,
    # Legacy report settings: ListAdminsReport.* - rebind to RJReport.StorageAccount.* (ContainerName: unbind) when it is switched off
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "ListAdminsReport.Container" } )]
    [string] $ContainerName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "ListAdminsReport.ResourceGroup" } )]
    [string] $ResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "ListAdminsReport.StorageAccount.Name" } )]
    [string] $StorageAccountName,
    # Legacy report settings: set only explicitly for now - bind to RJReport.StorageAccount.SubscriptionId when it is switched off
    [string] $SubscriptionId,
    # Legacy report settings: deprecated and ignored, kept so existing schedules and API calls keep starting
    [string] $StorageAccountLocation,
    [string] $StorageAccountSku,
    [ValidateScript( { Use-RJInterface -DisplayName "Check MFA state?" } )]
    [bool]$QueryMfaState = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Count email as MFA?" } )]
    [bool]$TrustEmailMfa = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Count phone/SMS as MFA?" } )]
    [bool]$TrustPhoneMfa = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Count software OATH tokens as MFA?" } )]
    [bool]$TrustSoftwareOathMfa = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Count Windows Hello for Business as MFA?" } )]
    [bool]$TrustWinHelloMFA = $false,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.ResourceGroup" } )]
    [string] $RJReportResourceGroupName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.StorageAccountName" } )]
    [string] $RJReportStorageAccountName,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.SubscriptionId" } )]
    [string] $RJReportSubscriptionId,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.StorageAccount.LinkExpiryDays" } )]
    [ValidateRange(1, 3650)]
    [int] $LinkExpiryDays = 6,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region     RJ Log Part
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.3.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "ExportToFile: $ExportToFile" -Verbose
Write-RjRbLog -Message "PimEligibleUntilInCSV: $PimEligibleUntilInCSV" -Verbose
Write-RjRbLog -Message "ContainerName: $ContainerName" -Verbose
Write-RjRbLog -Message "ResourceGroupName: $ResourceGroupName" -Verbose
Write-RjRbLog -Message "StorageAccountName: $StorageAccountName" -Verbose
Write-RjRbLog -Message "SubscriptionId: $SubscriptionId" -Verbose
Write-RjRbLog -Message "StorageAccountLocation: $StorageAccountLocation" -Verbose
Write-RjRbLog -Message "StorageAccountSku: $StorageAccountSku" -Verbose
Write-RjRbLog -Message "QueryMfaState: $QueryMfaState" -Verbose
Write-RjRbLog -Message "TrustEmailMfa: $TrustEmailMfa" -Verbose
Write-RjRbLog -Message "TrustPhoneMfa: $TrustPhoneMfa" -Verbose
Write-RjRbLog -Message "TrustSoftwareOathMfa: $TrustSoftwareOathMfa" -Verbose
Write-RjRbLog -Message "TrustWinHelloMFA: $TrustWinHelloMFA" -Verbose
Write-RjRbLog -Message "RJReportResourceGroupName: $RJReportResourceGroupName" -Verbose
Write-RjRbLog -Message "RJReportStorageAccountName: $RJReportStorageAccountName" -Verbose
Write-RjRbLog -Message "RJReportSubscriptionId: $RJReportSubscriptionId" -Verbose
Write-RjRbLog -Message "LinkExpiryDays: $LinkExpiryDays" -Verbose

#endregion RJ Log Part

############################################################
#region     Parameter Validation
############################################################

# Legacy report settings: ListAdminsReport.* stays bound to the original parameters, so explicit values, existing schedules
# and API calls behave as before and the legacy settings win. RJReport.StorageAccount.* fills in when they are not set.
if (-not ($ResourceGroupName -and $StorageAccountName) -and $RJReportResourceGroupName -and $RJReportStorageAccountName) {
    Write-RjRbLog -Message "Using RJReport.StorageAccount.* - ListAdminsReport.* is not configured" -Verbose
    $ResourceGroupName = $RJReportResourceGroupName
    $StorageAccountName = $RJReportStorageAccountName
    $SubscriptionId = $RJReportSubscriptionId
}

# Legacy report settings: remove with StorageAccountLocation / StorageAccountSku in the switch-off release
if ($PSBoundParameters.ContainsKey('StorageAccountLocation') -or $PSBoundParameters.ContainsKey('StorageAccountSku')) {
    $deprecationMessage = "StorageAccountLocation and StorageAccountSku are deprecated and ignored - the storage account is no longer created automatically. Re-create this schedule or drop both parameters from the API call; a later version removes them."
    Write-RjRbLog -Message "WARNING: $deprecationMessage"
    Write-Warning $deprecationMessage
}

#endregion Parameter Validation

############################################################
#region     Functions
############################################################

#region Helper Functions
##############################

function Format-RemainingTime {
    <#
        .SYNOPSIS
        Formats remaining time until a given end date.

        .DESCRIPTION
        Format-RemainingTime converts a future DateTime into a compact human-readable string
        like "in 5 days" or "in 3 hours". If the end date is in the past, it returns "expired".

        .PARAMETER EndDateTime
        The end date/time to calculate the remaining time for.

        .PARAMETER Now
        Reference time. Defaults to current date/time.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$EndDateTime,
        [Parameter(Mandatory = $false)]
        [datetime]$Now = (Get-Date)
    )

    $delta = $EndDateTime - $Now
    if ($delta.TotalSeconds -le 0) {
        return 'expired'
    }

    if ($delta.TotalDays -ge 2) {
        $days = [int][math]::Ceiling($delta.TotalDays)
        if ($days -eq 1) {
            return 'in 1 day'
        }
        return "in $days days"
    }

    if ($delta.TotalHours -ge 2) {
        $hours = [int][math]::Ceiling($delta.TotalHours)
        if ($hours -eq 1) {
            return 'in 1 hour'
        }
        return "in $hours hours"
    }

    $minutes = [int][math]::Ceiling([math]::Max($delta.TotalMinutes, 1))
    if ($minutes -eq 1) {
        return 'in 1 minute'
    }
    return "in $minutes minutes"
}

function Get-UntilDisplayText {
    <#
        .SYNOPSIS
        Builds a combined "until" + "remaining" display text.

        .DESCRIPTION
        Get-UntilDisplayText returns a string like "2026-02-24 18:30 (in 3 hours)".
        For permanent assignments it returns "Permanent".

        .PARAMETER EndDateTime
        The end date/time if the assignment expires.

        .PARAMETER DateOnly
        If true, the EndDateTime is formatted as date only (yyyy-MM-dd).
    #>
    param(
        [Parameter(Mandatory = $false)]
        [datetime]$EndDateTime,
        [Parameter(Mandatory = $false)]
        [bool]$DateOnly = $true
    )

    if ($null -eq $EndDateTime) {
        return 'Permanent'
    }

    $now = Get-Date
    $remaining = Format-RemainingTime -EndDateTime $EndDateTime -Now $now
    $untilText = if ($DateOnly) {
        (Get-Date $EndDateTime -Format 'yyyy-MM-dd')
    }
    else {
        (Get-Date $EndDateTime -Format 'yyyy-MM-dd HH:mm')
    }

    if ($remaining -eq 'expired') {
        return "$untilText (expired)"
    }

    return "$untilText ($remaining)"
}

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/applications".

        .EXAMPLE
        PS C:\> $allApps = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/applications"
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

#endregion Helper Functions

#endregion Functions

############################################################
#region     Connect Part
############################################################

Write-Output "Connecting to Microsoft Graph..."

try {
    $mgContext = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $mgContext) {
        Connect-MgGraph -Identity -ContextScope Process -NoWelcome -ErrorAction Stop | Out-Null
    }
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Ensure the runbook identity has the required Graph permissions and Microsoft.Graph.Authentication is available." -ErrorAction Continue
    throw
}

#endregion Connect Part

############################################################
#region     Data Collection
############################################################

## Get builtin AzureAD Roles
$roles = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=isBuiltIn eq true"

if ([array]$roles.count -eq 0) {
    "## Error - No AzureAD roles found. Missing permissions?"
    throw("no roles found")
}

## Performance issue - Get all role assignments at once
try {
    $allRoleHolders = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments"
}
catch {
    $allRoleHolders = @()
}

try {
    $allPimHolders = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/roleManagement/directory/roleEligibilitySchedules"
}
catch {
    $allPimHolders = @()
}

try {
    # Includes permanent assignments and time-bound PIM activations.
    $allPimActiveInstances = Get-GraphPagedResult -Uri "https://graph.microsoft.com/beta/roleManagement/directory/roleAssignmentScheduleInstances?`$select=principalId,roleDefinitionId,startDateTime,endDateTime"
}
catch {
    $allPimActiveInstances = @()
}

$getPimEligibilityInfo = {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Schedules
    )

    if (-not $Schedules -or $Schedules.Count -eq 0) {
        return $null
    }

    $expirationTypes = $Schedules | ForEach-Object { $_.scheduleInfo.expiration.type }
    if ($expirationTypes -contains 'noExpiration') {
        return [PSCustomObject]@{
            UntilText     = 'Permanent'
            RemainingText = ''
            DisplayText   = 'Permanent'
        }
    }

    $endDates = @()
    $maxDays = $null

    foreach ($schedule in $Schedules) {
        $expiration = $schedule.scheduleInfo.expiration
        $expirationType = $expiration.type

        if (($expirationType -eq 'afterDateTime') -and $expiration.endDateTime) {
            # -as returns $null if parsing fails instead of throwing — only add if parseable
            $parsed = $expiration.endDateTime -as [datetime]
            if ($parsed) { $endDates += $parsed }
            continue
        }

        if ($schedule.endDateTime) {
            # -as returns $null if parsing fails instead of throwing — only add if parseable
            $parsed = $schedule.endDateTime -as [datetime]
            if ($parsed) { $endDates += $parsed }
            continue
        }

        if ($expirationType -eq 'afterDuration' -and $expiration.duration) {
            $durationText = [string]$expiration.duration
            $startText = $schedule.scheduleInfo.startDateTime
            if (-not $startText) {
                $startText = $schedule.startDateTime
            }

            if ($startText) {
                try {
                    $timeSpan = [System.Xml.XmlConvert]::ToTimeSpan($durationText)
                    $endDates += ([datetime]$startText).Add($timeSpan)
                    continue
                }
                catch {
                    # Suppress PSAvoidUsingEmptyCatchBlock — invalid XML duration, fall through to regex fallback
                    $null = $_
                }

                if ($durationText -match '^P(?<days>\d+)D$') {
                    $endDates += ([datetime]$startText).AddDays([int]$Matches.days)
                    continue
                }
            }

            if ($durationText -match '^P(?<days>\d+)D$') {
                $days = [int]$Matches.days
                if ($null -eq $maxDays -or $days -gt $maxDays) {
                    $maxDays = $days
                }
                continue
            }
        }
    }

    if ($endDates.Count -gt 0) {
        $latest = $endDates | Sort-Object | Select-Object -Last 1
        $untilText = (Get-Date $latest -Format 'yyyy-MM-dd')
        $remainingText = Format-RemainingTime -EndDateTime $latest
        $displayText = if ($remainingText -eq 'expired') {
            "$untilText (expired)"
        }
        else {
            "$untilText ($remainingText)"
        }
        return [PSCustomObject]@{
            UntilText     = $untilText
            RemainingText = $remainingText
            DisplayText   = $displayText
        }
    }

    if ($null -ne $maxDays) {
        # Best-effort: we only know a duration, not an absolute end date.
        $remainingText = if ($maxDays -eq 1) {
            'in 1 day'
        }
        else {
            "in $maxDays days"
        }

        return [PSCustomObject]@{
            UntilText     = ''
            RemainingText = $remainingText
            DisplayText   = $remainingText
        }
    }

    return [PSCustomObject]@{
        UntilText     = ''
        RemainingText = 'Unknown'
        DisplayText   = 'Unknown'
    }
}

$pimEligibleInfoByPrincipalRole = @{}

if ($allPimHolders -and ([array]$allPimHolders).Count -gt 0) {
    $allPimHolders | Group-Object -Property { "$($_.principalId)|$($_.roleDefinitionId)" } | ForEach-Object {
        $key = $_.Name
        $value = & $getPimEligibilityInfo $_.Group
        if ($null -ne $value) {
            $pimEligibleInfoByPrincipalRole[$key] = $value
        }
    }
}

$pimActiveInfoByPrincipalRole = @{}

if ($allPimActiveInstances -and ([array]$allPimActiveInstances).Count -gt 0) {
    $allPimActiveInstances | Group-Object -Property { "$($_.principalId)|$($_.roleDefinitionId)" } | ForEach-Object {
        $key = $_.Name

        # Determine the latest endDateTime across all active instances.
        $endDates = @()
        $hasPermanentInstance = $false
        foreach ($instance in $_.Group) {
            if (-not $instance.endDateTime) {
                $hasPermanentInstance = $true
                continue
            }
            if ($instance.endDateTime) {
                # -as returns $null if parsing fails instead of throwing — only add if parseable
                $parsed = $instance.endDateTime -as [datetime]
                if ($parsed) { $endDates += $parsed }
            }
        }

        if ($hasPermanentInstance) {
            $pimActiveInfoByPrincipalRole[$key] = [PSCustomObject]@{
                UntilText     = 'Permanent'
                RemainingText = ''
                DisplayText   = 'Permanent'
            }
            return
        }

        if ($endDates.Count -gt 0) {
            $latest = $endDates | Sort-Object | Select-Object -Last 1
            $untilText = (Get-Date $latest -Format 'yyyy-MM-dd HH:mm')
            $remainingText = Format-RemainingTime -EndDateTime $latest
            $displayText = if ($remainingText -eq 'expired') {
                "$untilText (expired)"
            }
            else {
                "$untilText ($remainingText)"
            }
            $pimActiveInfoByPrincipalRole[$key] = [PSCustomObject]@{
                UntilText     = $untilText
                RemainingText = $remainingText
                DisplayText   = $displayText
            }
        }
        else {
            # No endDateTime usually means permanent assignment.
            $pimActiveInfoByPrincipalRole[$key] = [PSCustomObject]@{
                UntilText     = 'Permanent'
                RemainingText = ''
                DisplayText   = 'Permanent'
            }
        }
    }
}

$AdminUsers = @{}

$roles | ForEach-Object {
    $roleDefinitionId = $_.id
    $pimHolders = $allPimHolders | Where-Object { $_.roleDefinitionId -eq $roleDefinitionId }
    $roleHolders = $allRoleHolders | Where-Object { $_.roleDefinitionId -eq $roleDefinitionId }

    if ((([array]$roleHolders).count -gt 0) -or (([array]$pimHolders).count -gt 0)) {
        "## Role: $($_.displayName)"
        "## - Active Assignments"

        $roleHolders | ForEach-Object {
            $activeUntilSuffix = ''
            $activeKey = "$($_.principalId)|$roleDefinitionId"
            if ($pimActiveInfoByPrincipalRole.ContainsKey($activeKey)) {
                $activeUntilSuffix = " (Active until: $($pimActiveInfoByPrincipalRole[$activeKey].DisplayText))"
            }

            try {
                $principal = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/directoryObjects/$($_.principalId)" -Method GET -OutputType PSObject -ErrorAction Stop
            }
            catch {
                $principal = $null
            }
            if (-not $principal) {
                "  $($_.principalId) (Unknown principal)$activeUntilSuffix"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)$activeUntilSuffix"
                    if (-not $AdminUsers.ContainsKey($principal.id)) {
                        $AdminUsers[$principal.id] = $principal.userPrincipalName
                    }
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "  $($principal.displayName) (ServicePrincipal)$activeUntilSuffix"
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.group") {
                    "  $($principal.displayName) (Group)$activeUntilSuffix"
                }
                else {
                    "  $($principal.displayName) $($principal."@odata.type")$activeUntilSuffix"
                }
            }
        }

        "## - PIM eligible"

        $pimHolders | Group-Object -Property principalId | ForEach-Object {
            $principalId = $_.Name
            $eligibleInfo = & $getPimEligibilityInfo $_.Group
            $eligibleText = if ($null -ne $eligibleInfo) { $eligibleInfo.DisplayText } else { 'Unknown' }
            $eligibleSuffix = " (Eligible until: $eligibleText)"

            try {
                $principal = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/directoryObjects/$principalId" -Method GET -OutputType PSObject -ErrorAction Stop
            }
            catch {
                $principal = $null
            }

            if (-not $principal) {
                "  $principalId (Unknown principal)$eligibleSuffix"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)$eligibleSuffix"
                    if (-not $AdminUsers.ContainsKey($principal.id)) {
                        $AdminUsers[$principal.id] = $principal.userPrincipalName
                    }
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "  $($principal.displayName) (ServicePrincipal)$eligibleSuffix"
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.group") {
                    "  $($principal.displayName) (Group)$eligibleSuffix"
                }
                else {
                    "  $($principal.displayName) $($principal."@odata.type")$eligibleSuffix"
                }
            }
        }


        ""
    }

}

#endregion Data Collection

############################################################
#region     Report File Export
############################################################

# The storage check stays here, after the role listing, so the run output keeps the order of earlier versions
if ($exportToFile) {
    if ((-not $StorageAccountName) -or (-not $ResourceGroupName)) {
        $exportToFile = $false
        "## AZ Storage configuration incomplete, will not export to AZ Storage."
        "## Configure the following attributes (see https://docs.realmjoin.com/automation/runbooks/runbook-report-settings):"
        "## - RJReport.StorageAccount.ResourceGroup"
        "## - RJReport.StorageAccount.StorageAccountName"
        "## The runbook-specific ListAdminsReport.ResourceGroup and ListAdminsReport.StorageAccount.Name are still read and take precedence."
    }
}

$reportFiles = @()
if ($exportToFile) {
    # The local file name becomes the blob name, so uploads keep the blob names of earlier versions
    $filename = Join-Path ([System.IO.Path]::GetTempPath()) "AdminRoleOverview.csv"
    [string]$output = "UPN;"
    $roles | ForEach-Object {
        $output += $_.displayName + ";"
        if ($pimEligibleUntilInCSV) {
            $output += ($_.displayName + "_PIMEligibleUntil;")
            $output += ($_.displayName + "_PIMEligibleRemaining;")
            $output += ($_.displayName + "_ActiveUntil;")
            $output += ($_.displayName + "_ActiveRemaining;")
        }
    }
    $output > $filename

    $AdminUsers.GetEnumerator() | Sort-Object -Property Value | ForEach-Object {
        $AdminId = $_.Key
        $AdminUPN = $_.Value
        [string]$output = $AdminUPN + ";"
        $roles | ForEach-Object {
            $roleDefinitionId = $_.id
            if ($allRoleHolders | Where-Object { ($_.roleDefinitionId -eq $roleDefinitionId) -and ($_.principalId -eq $AdminId) }) {
                $output += "x;"
            }
            elseif ($pimEligibleInfoByPrincipalRole.ContainsKey("$AdminId|$roleDefinitionId")) {
                $output += "p;"
            }
            else {
                $output += ";"
            }

            if ($pimEligibleUntilInCSV) {
                $key = "$AdminId|$roleDefinitionId"
                if ($pimEligibleInfoByPrincipalRole.ContainsKey($key)) {
                    $eligibleInfo = $pimEligibleInfoByPrincipalRole[$key]
                    $output += ([string]$eligibleInfo.UntilText + ";")
                    $output += ([string]$eligibleInfo.RemainingText + ";")
                }
                else {
                    $output += ";;"
                }

                if ($pimActiveInfoByPrincipalRole.ContainsKey($key)) {
                    $activeInfo = $pimActiveInfoByPrincipalRole[$key]
                    $output += ([string]$activeInfo.UntilText + ";")
                    $output += ([string]$activeInfo.RemainingText + ";")
                }
                elseif ($allRoleHolders | Where-Object { ($_.roleDefinitionId -eq $roleDefinitionId) -and ($_.principalId -eq $AdminId) }) {
                    # Fallback if schedule instances are not accessible.
                    $output += ('Permanent;')
                    $output += (';')
                }
                else {
                    $output += ";;"
                }
            }
        }
        $output >> $filename
    }
    $content = Get-Content $filename
    Set-Content -Path $filename -Value $content -Encoding utf8
    $reportFiles += $filename
}

#endregion Report File Export

############################################################
#region     Upload / Download Link
############################################################

if ($exportToFile) {
    Connect-RjRbAzAccount

    if (-not $ContainerName) {
        $ContainerName = "adminoverview-" + (Get-Date -Format "yyyy-MM-dd")
    }

    try {
        Write-RjRbLog -Message "Upload" -Verbose
        $uploadResults = Publish-RjRbFilesToStorageContainer `
            -FilePaths $reportFiles `
            -ContainerName $ContainerName `
            -ResourceGroupName $ResourceGroupName `
            -StorageAccountName $StorageAccountName `
            -SubscriptionId $SubscriptionId `
            -LinkExpiryDays $LinkExpiryDays `
            -AddBlobNamePrefix $false

        foreach ($uploadResult in $uploadResults) {
            "## $($uploadResult.BlobName)"
            " $($uploadResult.SASLink)"
            ""
        }
        "## upload of CSVs successful."
        "## Expiry of Links: $(@($uploadResults)[0].EndTime)"
    }
    catch {
        # The MFA state below is still reported when the upload fails
        Write-RjRbLog -Message "Upload to storage account '$StorageAccountName' failed: $($_.Exception.Message). The managed identity needs the 'Reader and Data Access' role on the storage account." -Verbose
        "## Upload of report failed. Please see log."
        ""
        $_
    }
}

#endregion Upload / Download Link

############################################################
#region     Main Part
############################################################

if ($QueryMfaState) {
    ""
    "## MFA State of each Admin:"
    $NoMFAAdmins = @()
    $AdminUsers.GetEnumerator() | Sort-Object -Property Value | ForEach-Object {
        $AdminId = $_.Key
        $AdminUPN = $_.Value
        $AuthenticationMethods = @()
        [array]$MFAData = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/users/$AdminId/authentication/methods"
        foreach ($MFA in $MFAData) {
            switch ($MFA."@odata.type") {
                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                    $AuthenticationMethods += "- MS Authenticator App"
                }
                "#microsoft.graph.phoneAuthenticationMethod" {
                    if ($TrustPhoneMfa) {
                        $AuthenticationMethods += "- Phone authentication"
                    }
                }
                "#microsoft.graph.fido2AuthenticationMethod" {
                    $AuthenticationMethods += "- FIDO2 key"
                }
                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    if ($TrustWinHelloMFA) {
                        $AuthenticationMethods += "- Windows Hello"
                    }
                }
                "#microsoft.graph.emailAuthenticationMethod" {
                    if ($TrustEmailMfa) {
                        $AuthenticationMethods += "- Email Authentication"
                    }
                }
                "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" {
                    $AuthenticationMethods += "- MS Authenticator App (passwordless)"
                }
                "#microsoft.graph.softwareOathAuthenticationMethod" {
                    if ($TrustSoftwareOathMfa) {
                        $AuthenticationMethods += "- SoftwareOath"
                    }
                }
            }
        }
        if ($AuthenticationMethods.count -eq 0) {
            $NoMFAAdmins += $AdminUPN
        }
        else {
            "'$AdminUPN':"
            $AuthenticationMethods | Sort-Object -Unique
            ""
        }
    }

    if ($NoMFAAdmins.count -ne 0) {
        ""
        "## Admins without valid MFA:"
        $NoMFAAdmins | Sort-Object -Unique
    }
}

#endregion Main Part

############################################################
#region     Cleanup
############################################################

foreach ($reportFile in $reportFiles) {
    Remove-Item -LiteralPath $reportFile -Force -ErrorAction SilentlyContinue
}

#endregion Cleanup