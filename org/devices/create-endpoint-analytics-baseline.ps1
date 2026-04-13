<#
.SYNOPSIS
Creates Endpoint Analytics baselines in Microsoft Intune with a specified naming schema.

.DESCRIPTION
This runbook creates new Endpoint Analytics baselines in Intune using a customizable naming schema. Endpoint Analytics baselines allow organizations to measure and track device performance metrics over time. The naming schema can include placeholders that will be replaced with contextual values during baseline creation.

.PARAMETER BaselineNamingSchema
The naming schema to use for the Endpoint Analytics baseline. Can include placeholders like {Date}, {DateTime}, {Month}, {Year}, or other tokens that will be replaced during creation. Example: "EA-Baseline-{Year}-{Month}" or "Analytics-{Date}".

.PARAMETER RemoveOldestBaseline
When enabled (default), automatically removes the oldest baseline if the maximum limit of 20 baselines is reached. Set to false to prevent automatic deletion and fail the runbook when the limit is reached.

.PARAMETER CallerName
The name of the user or service principal initiating the baseline creation. This parameter is automatically populated by the RealmJoin platform and is used for audit logging purposes.

.INPUTS
RunbookCustomization: {
    "Parameters": {
        "BaselineNamingSchema": {
            "DisplayName": "Baseline Naming Schema",
            "DisplayBefore": "RemoveOldestBaseline"
        },
        "RemoveOldestBaseline": {
            "DisplayName": "Remove Oldest Baseline When Limit Reached",
            "DisplayBefore": "CallerName"
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5"}
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1"}

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
$Version = "1.0.0"
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
try {
    Disconnect-MgGraph | Out-Null
}
catch {
    # Silently ignore if already disconnected
}

Write-Output ""
Write-Output "Done!"
#endregion
