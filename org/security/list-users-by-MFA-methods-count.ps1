<#
.SYNOPSIS
    Reports users by the count of their registered MFA methods.

.DESCRIPTION
    This Runbook retrieves a list of users from Azure AD and counts their registered MFA authentication methods.
    As a dropdown for the MFA methods count range, you can select from "0 methods (no MFA)", "1-3 methods", "4-5 methods", or "6+ methods".
    The output includes the user display name, user principal name, and the count of registered MFA methods.

.PARAMETER mfaMethodsRange
    Range for filtering users based on the count of their registered MFA methods.

.INPUTS
RunbookCustomization: {
    "Parameters": {
        "mfaMethodsRange": {
            "DisplayName": "Select MFA Methods Count Range",
            "Description": "Filter users based on the count of their registered MFA methods.",
            "Required": true,
            "SelectSimple": {
                "Users with 0 methods (no MFA)": "0",
                "Users with 1-3 methods": "1-3",
                "Users with 4-5 methods": "4-5",
                "Users with 6+ methods": "6+"
            }
        },
        "CallerName": {
            "Hide": true
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.34.0" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("0", "1-3", "4-5", "6+")]
    [string]$mfaMethodsRange,
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
Write-RjRbLog -Message "MFA Methods Range: $mfaMethodsRange" -Verbose

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
#region Retrieve Users and their MFA Methods
####################################################################

#region Fetch all users
$allUsers = @()
$usersBaseURI = 'https://graph.microsoft.com/v1.0/users?$select=id,displayName,userPrincipalName,accountEnabled&$filter=accountEnabled eq true'

try {
    Write-Verbose "Retrieving users from Microsoft Graph..."
    $currentURI = $usersBaseURI

    do {
        Write-Verbose "Fetching data from URI: $($currentURI)"
        $response = Invoke-MgGraphRequest -Uri $currentURI -Method Get -ErrorAction Stop
        if ($response -and $response.value) {
            $allUsers += $response.value
            Write-Verbose "Retrieved $($response.value.Count) users in this batch. Total users so far: $(($allUsers | Measure-Object).Count)."
        }
        else {
            Write-Verbose "No users found in this batch or response format unexpected."
        }
        $currentURI = $response.'@odata.nextLink'
    } while ($null -ne $currentURI)

    Write-Output "Retrieved total users: $(($allUsers | Measure-Object).Count)"
}
catch {
    Write-Error "Failed to retrieve users: $($_.Exception.Message)"
    throw
}
#endregion

#region Get MFA methods for each user and filter by range
$filteredUsers = @()

foreach ($user in $allUsers) {
    try {
        $mfaMethodsURI = "https://graph.microsoft.com/v1.0/users/$($user.id)/authentication/methods"
        Write-Verbose "Fetching MFA methods for user: $($user.userPrincipalName)"

        $mfaResponse = Invoke-MgGraphRequest -Uri $mfaMethodsURI -Method Get -ErrorAction Stop
        $mfaMethodsCount = ($mfaResponse.value | Measure-Object).Count

        # Filter based on the selected range
        $includeUser = $false
        switch ($mfaMethodsRange) {
            "0" {
                $includeUser = ($mfaMethodsCount -eq 0)
            }
            "1-3" {
                $includeUser = ($mfaMethodsCount -ge 1 -and $mfaMethodsCount -le 3)
            }
            "4-5" {
                $includeUser = ($mfaMethodsCount -ge 4 -and $mfaMethodsCount -le 5)
            }
            "6+" {
                $includeUser = ($mfaMethodsCount -ge 6)
            }
        }

        if ($includeUser) {
            $filteredUsers += [PSCustomObject]@{
                DisplayName       = $user.displayName
                UserPrincipalName = $user.userPrincipalName
                MFAMethodsCount   = $mfaMethodsCount
                UserId            = $user.id
            }
        }
    }
    catch {
        Write-Warning "Failed to retrieve MFA methods for user $($user.userPrincipalName): $($_.Exception.Message)"
    }
}

#endregion
#endregion

######################################################################
#region Output Users
######################################################################

Write-Verbose "Resulting users with MFA methods in range '$mfaMethodsRange': $(($filteredUsers | Measure-Object).Count)"

if ($(($filteredUsers | Measure-Object).Count) -eq 0) {
    Write-Output "No users found with MFA methods count in the specified range: $mfaMethodsRange"
}
else {
    Write-Output "Users with MFA methods count in range '$mfaMethodsRange': $(($filteredUsers | Measure-Object).Count)"

    # Sort by MFA methods count (descending) and then by display name
    $sortedUsers = $filteredUsers | Sort-Object MFAMethodsCount, DisplayName -Descending

    # Output in a formatted table
    $sortedUsers | Select-Object MFAMethodsCount, DisplayName, UserPrincipalName | Format-Table -AutoSize
}