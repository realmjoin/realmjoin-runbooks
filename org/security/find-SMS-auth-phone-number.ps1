<#
    .SYNOPSIS
    Find the user associated with a specific SMS-based authentication phone number

    .DESCRIPTION
    This runbook searches for which user has a specific phone number registered with SMS Sign-In enabled in Microsoft Entra ID. Unlike regular phone MFA methods, SMS Sign-In numbers must be unique across the tenant. If a number is reserved for SMS Sign-In by one user, assigning it to another user will fail with a "phoneNumberNotUnique" error. Regular phone MFA methods do not enforce uniqueness. This runbook helps administrators identify which user holds a specific SMS Sign-In number for troubleshooting and remediation.

    .PARAMETER PhoneNumber
    Phone number to search for in E.164 format (e.g., +492349876543). The number must start with a "+" followed by the country code and subscriber number.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "PhoneNumber": {
                "DisplayName": "Phone Number (E.164 format)"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param (
    [Parameter(Mandatory = $true)]
    [string]$PhoneNumber,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

############################################################
#region     RJ Log Part
#
############################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.2.1"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "PhoneNumber: $PhoneNumber" -Verbose

#endregion RJ Log Part

############################################################
#region     Parameter Validation
#
############################################################

if ($PhoneNumber -notmatch "^\+\d{8,15}$") {
    Write-Error -Message "Error: Phone number needs to be in E.164 format ( '+' followed by country code and number, e.g. +492349876543 ). Submitted value: '$PhoneNumber'" -ErrorAction Continue
    throw "Phone number needs to be in E.164 format ( '+' followed by country code and number, e.g. +492349876543 )."
}

#endregion Parameter Validation

############################################################
#region     Function Definitions
#
############################################################

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

#endregion Function Definitions

############################################################
#region     Connect Part
#
############################################################

Write-Output "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    throw
}

#endregion Connect Part

############################################################
#region     Main Part
#
############################################################

Write-Output ""
Write-Output "Searching for phone number '$PhoneNumber'..."
Write-Output "---------------------"

#region Pre-filter users with phone methods registered
##############################

Write-Output "Step 1: Retrieving users with phone authentication methods registered..."
Write-Output "Note: Pre-filters to users with phone methods, then checks SMS Sign-In state on each."

try {
    $registrationDetailsURI = "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?`$filter=methodsRegistered/any(t: t eq 'mobilePhone')&`$select=id,userPrincipalName,userDisplayName"
    $phoneRegisteredUsers = Get-GraphPagedResult -Uri $registrationDetailsURI

    Write-Output "Found $($phoneRegisteredUsers.Count) user(s) with phone authentication methods registered."
}
catch {
    Write-Error "Failed to retrieve authentication method registration details: $($_.Exception.Message)"
    throw
}

if ($phoneRegisteredUsers.Count -eq 0) {
    Write-Output ""
    Write-Output "Search Results"
    Write-Output "---------------------"
    Write-Output "No users in this tenant have phone authentication methods registered."
    Write-Output "The number '$PhoneNumber' is not reserved for SMS Sign-In."
    Write-Output ""
    Write-Output "Done!"
    exit
}

#endregion Pre-filter users with phone methods registered

#region Query phone methods via batch API
##############################

Write-Output ""
Write-Output "Step 2: Checking phone numbers and SMS Sign-In state for $($phoneRegisteredUsers.Count) user(s) via batch API..."

$smsSignInMatch = $null
$mfaOnlyMatches = @()
$batchSize = 20
$processedCount = 0

# Determine progress interval based on total user count
$totalUsers = $phoneRegisteredUsers.Count
if ($totalUsers -le 500) {
    $progressInterval = 100
}
elseif ($totalUsers -le 1000) {
    $progressInterval = 250
}
elseif ($totalUsers -le 2500) {
    $progressInterval = 500
}
else {
    $progressInterval = 1000
}

for ($i = 0; $i -lt $phoneRegisteredUsers.Count; $i += $batchSize) {
    $batch = $phoneRegisteredUsers[$i..([Math]::Min($i + $batchSize - 1, $phoneRegisteredUsers.Count - 1))]

    # Build batch requests
    $batchRequests = @()
    $batchIndex = 1
    foreach ($user in $batch) {
        $batchRequests += @{
            id     = "$batchIndex"
            method = "GET"
            url    = "/users/$($user.id)/authentication/phoneMethods"
        }
        $batchIndex++
    }

    # Execute batch request
    try {
        $batchBody = @{ requests = $batchRequests }
        $batchResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/`$batch" -Method POST -Body ($batchBody | ConvertTo-Json -Depth 10) -ContentType "application/json"
        $responses = $batchResponse.responses

        # Process batch responses
        foreach ($response in $responses) {
            $responseIndex = [int]$response.id - 1
            $user = $batch[$responseIndex]

            if ($response.status -eq 200 -and $response.body.value) {
                foreach ($method in $response.body.value) {
                    $CleanPhoneNumber = $method.phoneNumber -replace '\s', ''
                    if ($CleanPhoneNumber -eq $PhoneNumber) {
                        if ($method.smsSignInState -eq 'ready') {
                            # SMS Sign-In match found - retrieve account status
                            $accountEnabled = $null
                            try {
                                $userDetails = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)?`$select=accountEnabled" -Method Get
                                $accountEnabled = $userDetails.accountEnabled
                            }
                            catch {
                                Write-Verbose "Could not retrieve account status for user $($user.userPrincipalName): $($_.Exception.Message)"
                            }

                            $smsSignInMatch = [PSCustomObject]@{
                                DisplayName       = $user.userDisplayName
                                UserPrincipalName = $user.userPrincipalName
                                AccountEnabled    = $accountEnabled
                                PhoneType         = $method.phoneType
                                SmsSignInState    = $method.smsSignInState
                                PhoneNumber       = $CleanPhoneNumber
                                UserId            = $user.id
                            }
                        }
                        else {
                            # Phone number matches but SMS Sign-In is not enabled - MFA only
                            $mfaOnlyMatches += [PSCustomObject]@{
                                DisplayName       = $user.userDisplayName
                                UserPrincipalName = $user.userPrincipalName
                                PhoneType         = $method.phoneType
                                SmsSignInState    = $method.smsSignInState
                                PhoneNumber       = $CleanPhoneNumber
                                UserId            = $user.id
                            }
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Batch request failed for users $($i + 1) to $([Math]::Min($i + $batchSize, $phoneRegisteredUsers.Count)): $($_.Exception.Message)"
    }

    $processedCount += $batch.Count
    if ($processedCount % $progressInterval -eq 0) {
        Write-Output "Processed $processedCount of $($phoneRegisteredUsers.Count) users..."
    }
}

#endregion Query phone methods via batch API

#endregion Main Part

############################################################
#region     Output
#
############################################################

Write-Output ""
Write-Output "Search Results"
Write-Output "---------------------"

if ($smsSignInMatch) {
    Write-Output "Found the user with phone number '$PhoneNumber' registered for SMS Sign-In:"
    Write-Output ""
    Write-Output "  Display Name:       $($smsSignInMatch.DisplayName)"
    Write-Output "  UPN:                $($smsSignInMatch.UserPrincipalName)"
    Write-Output "  Account Enabled:    $($smsSignInMatch.AccountEnabled)"
    Write-Output "  Phone Type:         $($smsSignInMatch.PhoneType)"
    Write-Output "  SMS Sign-In State:  $($smsSignInMatch.SmsSignInState)"
    Write-Output "  Phone Number:       $($smsSignInMatch.PhoneNumber)"
    Write-Output "  Entra Portal Link:  https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($smsSignInMatch.UserId)"
    Write-Output ""
}
else {
    Write-Output "No active user found with phone number '$PhoneNumber' registered for SMS Sign-In."
    Write-Output "Note: The number may still be reserved by a soft-deleted (recently deleted) user account."
    Write-Output "Soft-deleted users are not included in this search. Check Entra ID > Deleted users if a 'phoneNumberNotUnique' error persists."
    Write-Output ""
}

if ($mfaOnlyMatches.Count -gt 0) {
    Write-Output ""
    Write-Output "MFA-Only Matches (not SMS Sign-In)"
    Write-Output "---------------------"
    Write-Output "The following $($mfaOnlyMatches.Count) user(s) have '$PhoneNumber' registered as a phone MFA method (without SMS Sign-In):"
    Write-Output ""
    foreach ($mfaUser in $mfaOnlyMatches) {
        Write-Output "  Display Name:       $($mfaUser.DisplayName)"
        Write-Output "  UPN:                $($mfaUser.UserPrincipalName)"
        Write-Output "  Phone Type:         $($mfaUser.PhoneType)"
        Write-Output "  SMS Sign-In State:  $($mfaUser.SmsSignInState)"
        Write-Output "  Phone Number:       $($mfaUser.PhoneNumber)"
        Write-Output "  Entra Portal Link:  https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($mfaUser.UserId)"
        Write-Output ""
    }
}

Write-Output ""
Write-Output "Done!"

#endregion Output
