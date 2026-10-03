<#
    .SYNOPSIS
    Create an Endpoint Analytics baseline with a naming schema

    .DESCRIPTION
    Creates a new Endpoint Analytics baseline in Intune, named after a schema with placeholders such as the current date, so baselines can be created regularly and compared over time. Intune allows at most 20 baselines; the oldest can be removed automatically when the limit is reached.

    .PARAMETER BaselineNamingSchema
    Name pattern with placeholders such as {Year}, {Month}, {Date} or {DateTime}, for example EA-Baseline-{Year}-{Month}.

    .PARAMETER RemoveOldestBaseline
    Deletes the oldest baseline when 20 already exist. Turn off to stop with an error instead.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

.INPUTS
RunbookCustomization: {
    "Parameters": {
        "BaselineNamingSchema": {
            "DisplayName": "Baseline naming schema",
            "DisplayBefore": "RemoveOldestBaseline"
        },
        "RemoveOldestBaseline": {
            "DisplayName": "Remove the oldest baseline at the limit?",
            "DisplayBefore": "CallerName"
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9"}
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.39.0"}

param(
    [Parameter(Mandatory = $true)]
    [string]$BaselineNamingSchema,

    [Parameter(Mandatory = $false)]
    [bool]$RemoveOldestBaseline = $true,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
$Version = "1.0.3"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "BaselineNamingSchema: $BaselineNamingSchema" -Verbose
Write-RjRbLog -Message "RemoveOldestBaseline: $RemoveOldestBaseline" -Verbose
#endregion

########################################################
#region     Connect Part
########################################################
Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    throw
}
#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################
Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

try {
    # Retrieve existing Endpoint Analytics baselines
    $StatusQuo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsBaselines" -Method GET

    $existingBaselines = $StatusQuo.value
    $baselineCount = ($existingBaselines | Measure-Object).Count

    Write-Output "Current Endpoint Analytics baselines: $baselineCount"
    if ($baselineCount -gt 0) {
        Write-Output "Existing baselines:"
        $existingBaselines | ForEach-Object {
            Write-Output "  - $($_.displayName)"
        }
    } else {
        Write-Output "No existing baselines found."
    }
}
catch {
    Write-Error "Failed to retrieve current Endpoint Analytics baselines: $_" -ErrorAction Continue
    throw
}

Write-Output ""
Write-Output "Preflight Checks"
Write-Output "---------------------"

try {
    # Process naming schema - replace placeholders with actual values
    $resolvedBaselineName = $BaselineNamingSchema

    # Replace {Date} placeholder with current date in ISO format (yyyy-MM-dd)
    if ($resolvedBaselineName -match '\{Date\}') {
        $currentDate = Get-Date -Format 'yyyy-MM-dd'
        $resolvedBaselineName = $resolvedBaselineName -replace '\{Date\}', $currentDate
        Write-Output "Resolved {Date} placeholder to: $currentDate"
    }

    # Replace {DateTime} placeholder with current date and time
    if ($resolvedBaselineName -match '\{DateTime\}') {
        $currentDateTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $resolvedBaselineName = $resolvedBaselineName -replace '\{DateTime\}', $currentDateTime
        Write-Output "Resolved {DateTime} placeholder to: $currentDateTime"
    }

    # Replace {Year} placeholder with current year
    if ($resolvedBaselineName -match '\{Year\}') {
        $currentYear = Get-Date -Format 'yyyy'
        $resolvedBaselineName = $resolvedBaselineName -replace '\{Year\}', $currentYear
        Write-Output "Resolved {Year} placeholder to: $currentYear"
    }

    # Replace {Month} placeholder with current month
    if ($resolvedBaselineName -match '\{Month\}') {
        $currentMonth = Get-Date -Format 'MM'
        $resolvedBaselineName = $resolvedBaselineName -replace '\{Month\}', $currentMonth
        Write-Output "Resolved {Month} placeholder to: $currentMonth"
    }

    Write-Output "Final baseline name: $resolvedBaselineName"

    # Validate that the naming schema produced a valid name
    if ([string]::IsNullOrWhiteSpace($resolvedBaselineName)) {
        Write-Error "The naming schema resulted in an empty baseline name." -ErrorAction Continue
        throw "Invalid naming schema: resolved name is empty"
    }

    # Check if a baseline with the resolved name already exists
    $existingBaseline = $existingBaselines | Where-Object { $_.displayName -eq $resolvedBaselineName }
    if ($existingBaseline) {
        Write-Error "A baseline with the name '$resolvedBaselineName' already exists." -ErrorAction Continue
        throw "Duplicate baseline name detected. Please use a different naming schema or delete the existing baseline."
    }

    # Check baseline count and handle limit
    if ($baselineCount -ge 20) {
        Write-Output ""
        Write-Output "Baseline limit reached: $baselineCount/20 baselines exist."

        if ($RemoveOldestBaseline) {
            Write-Output "RemoveOldestBaseline is enabled. Identifying oldest baseline for removal..."

            # Sort baselines by creation date to find the oldest
            $oldestBaseline = $existingBaselines | Sort-Object createdDateTime | Select-Object -First 1

            if ($oldestBaseline) {
                Write-Output "Oldest baseline identified: '$($oldestBaseline.displayName)' (Created: $($oldestBaseline.createdDateTime))"
                Write-Output "Deleting oldest baseline to make room for new baseline..."

                try {
                    Invoke-MgGraphRequest `
                        -Uri "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsBaselines/$($oldestBaseline.id)" `
                        -Method DELETE

                    Write-Output "Successfully deleted baseline: $($oldestBaseline.displayName)"
                }
                catch {
                    Write-Error "Failed to delete oldest baseline: $_" -ErrorAction Continue
                    throw
                }
            }
            else {
                Write-Error "Could not identify oldest baseline for removal." -ErrorAction Continue
                throw "Unable to determine oldest baseline"
            }
        }
        else {
            Write-Error "Baseline limit of 20 has been reached and RemoveOldestBaseline is disabled." -ErrorAction Continue
            throw "Maximum baseline limit (20) reached. Cannot create new baseline without removing an existing one."
        }
    }

    Write-Output "Preflight checks passed. Ready to create baseline: $resolvedBaselineName"
}
catch {
    Write-Error "Preflight check failed: $_" -ErrorAction Continue
    throw
}
#endregion

########################################################
#region     Main Part
########################################################
Write-Output ""
Write-Output "Creating Endpoint Analytics Baseline"
Write-Output "---------------------"

try {
    # Prepare the request body for creating the baseline
    $baselineBody = @{
        displayName = $resolvedBaselineName
        isBuiltIn   = $false
    }

    # Create the baseline using Microsoft Graph API
    Write-Output "Creating baseline: $resolvedBaselineName"
    $newBaseline = Invoke-MgGraphRequest `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsBaselines" `
        -Method POST `
        -Body $baselineBody

    Write-Output ""
    Write-Output "Baseline created successfully!"
    Write-Output "  - Display Name: $($newBaseline.displayName)"
    Write-Output "  - Baseline ID: $($newBaseline.id)"
    Write-Output "  - Created Date: $($newBaseline.createdDateTime)"
    Write-Output "  - Is Built-In: $($newBaseline.isBuiltIn)"
}
catch {
    Write-Error "Failed to create Endpoint Analytics baseline: $_" -ErrorAction Continue
    throw
}
#endregion

########################################################
#region     Cleanup
########################################################

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

Write-Output ""
Write-Output "Done!"
#endregion
