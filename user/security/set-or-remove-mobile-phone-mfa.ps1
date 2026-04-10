<#
    .SYNOPSIS
    Set or remove a user's mobile phone MFA method

    .DESCRIPTION
    Adds, updates, or removes the user's mobile phone authentication method. If you need to change a number, remove the existing method first and then add the new number. When adding or updating a number that is reserved for SMS Sign-In by another user, the runbook catches the "phoneNumberNotUnique" error and automatically identifies the user who holds that number. Note that phone numbers used as regular MFA methods (not SMS Sign-In) do not need to be unique and will not cause this error.

    .PARAMETER UserId
    Object ID of the target user.

    .PARAMETER phoneNumber
    Mobile phone number in international E.164 format (e.g., +491701234567).

    .PARAMETER Remove
    "Set/Update Mobile Phone MFA Method" (final value: $false) or "Remove Mobile Phone MFA Method" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the mobile phone MFA method for the user. If set to false, it will add or update the mobile phone MFA method with the provided phone number.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserId": {
                "Hide": true
            },
            "Remove": {
                "DisplayName": "Add or Remove Mobile Phone MFA Method",
                "SelectSimple": {
                    "Add this number as Mobile Phone MFA factor": false,
                    "Remove this number / mobile phone MFA factor": true
                }
            },
            "phoneNumber": {
                "DisplayName": "Mobile Phone Number"
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.35.1" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String]$UserId,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber,
    [bool] $Remove = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

############################################################
#region     RJ Log Part
#
############################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "2.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserId: $UserId" -Verbose
Write-RjRbLog -Message "phoneNumber: $phoneNumber" -Verbose
Write-RjRbLog -Message "Remove: $Remove" -Verbose

#endregion RJ Log Part

############################################################
#region     Parameter Validation
#
############################################################

if ($phoneNumber -notmatch "^\+\d{8,15}$") {
    Write-Error -Message "Error: Phone number needs to be in E.164 format ( '+' followed by country code and number, e.g. +491701234567 ). Submitted value: '$($phoneNumber)'" -ErrorAction Continue
    throw "Phone number needs to be in E.164 format ( '+' followed by country code and number, e.g. +491701234567 )."
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

    function Find-PhoneNumberOwner {
        <#
            .SYNOPSIS
            Finds the user who has SMS Sign-In enabled with a specific phone number.

            .DESCRIPTION
            Searches users with SMS Sign-In enabled via batch API to find the owner of a
            specific phone number. Only SMS Sign-In numbers are unique per tenant. Uses early
            termination since these numbers must be unique.

            .PARAMETER PhoneNumber
            The phone number to search for in E.164 format.
        #>
        param(
            [string]$PhoneNumber
        )

        Write-Output ""
        Write-Output "Searching for the user who has SMS Sign-In enabled with number '$($PhoneNumber)'..."
        Write-Output "---------------------"

        try {
            $registrationDetailsURI = "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?`$filter=methodsRegistered/any(t: t eq 'mobilePhone')&`$select=id,userPrincipalName,userDisplayName"
            $phoneRegisteredUsers = Get-GraphPagedResult -Uri $registrationDetailsURI
            Write-Output "Found $($phoneRegisteredUsers.Count) user(s) with phone authentication methods registered."
        }
        catch {
            Write-Warning "Could not retrieve authentication method registration details: $($_.Exception.Message)"
            return
        }

        if ($phoneRegisteredUsers.Count -eq 0) {
            Write-Output "No users in this tenant have phone authentication methods registered."
            return
        }

        $batchSize = 20
        $processedCount = 0

        for ($i = 0; $i -lt $phoneRegisteredUsers.Count; $i += $batchSize) {
            $batch = $phoneRegisteredUsers[$i..([Math]::Min($i + $batchSize - 1, $phoneRegisteredUsers.Count - 1))]

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

            try {
                $batchBody = @{ requests = $batchRequests }
                $batchResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/`$batch" -Method POST -Body ($batchBody | ConvertTo-Json -Depth 10) -ContentType "application/json"

                foreach ($response in $batchResponse.responses) {
                    $responseIndex = [int]$response.id - 1
                    $user = $batch[$responseIndex]

                    if ($response.status -eq 200 -and $response.body.value) {
                        foreach ($method in $response.body.value) {
                            $cleanNumber = $method.phoneNumber -replace '\s', ''
                            if ($cleanNumber -eq $PhoneNumber -and $method.smsSignInState -eq 'ready') {
                                Write-Output ""
                                Write-Output "Phone number '$($PhoneNumber)' is reserved for SMS Sign-In by:"
                                Write-Output "  Display Name:       $($user.userDisplayName)"
                                Write-Output "  UPN:                $($user.userPrincipalName)"
                                Write-Output "  Phone Type:         $($method.phoneType)"
                                Write-Output "  SMS Sign-In State:  $($method.smsSignInState)"
                                Write-Output "  Entra Portal Link:  https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($user.id)"
                                return
                            }
                        }
                    }
                }
            }
            catch {
                Write-Verbose "Batch request failed: $($_.Exception.Message)"
            }

            $processedCount += $batch.Count
            if ($processedCount % 100 -eq 0) {
                Write-Output "Searched $processedCount of $($phoneRegisteredUsers.Count) users..."
            }
        }

        Write-Output "Could not identify the user holding this phone number for SMS Sign-In."
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
#region     StatusQuo & Preflight-Check Part
#
############################################################

# Resolve user details for display and to validate the user exists
Write-Output "Resolving user details for '$($UserId)'..."
try {
    $targetUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)?`$select=id,userPrincipalName,displayName,userType" -Method Get
}
catch {
    Write-Error "Failed to resolve user '$($UserId)': $($_.Exception.Message)" -ErrorAction Continue
    throw
}
$userPrincipalName = $targetUser.userPrincipalName
$userDisplayName = $targetUser.displayName
if ($targetUser.userType -eq 'Guest') {
    Write-Output "Note: User '$($userDisplayName)' ($($userPrincipalName)) is a guest user."
}

Write-Output ""
if ($Remove) {
    Write-Output "Trying to remove phone MFA number '$($phoneNumber)' from user '$($userPrincipalName)'."
}
else {
    Write-Output "Trying to add phone MFA number '$($phoneNumber)' to user '$($userPrincipalName)'."
}
Write-Output "---------------------"

# Find existing mobile phone auth methods for user
Write-Output "Getting current phone authentication methods for user '$($userPrincipalName)'..."
try {
    $phoneMethodsResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods?`$filter=phoneType eq 'mobile'" -Method Get
    $phoneAM = $phoneMethodsResponse.value | Select-Object -First 1  # At most one mobile phone method per user
}
catch {
    Write-Error "Failed to retrieve phone authentication methods for user '$($userPrincipalName)': $($_.Exception.Message)"
    throw
}

# Check if the number is already assigned to this user (strip whitespace for comparison)
if ($phoneAM) {
    Write-Output "Current mobile phone MFA method:"
    Write-Output "  Phone Number:       $($phoneAM.phoneNumber)"
    Write-Output "  SMS Sign-In State:  $($phoneAM.smsSignInState)"
    Write-Output ""
    $existingNumber = $phoneAM.phoneNumber -replace '\s', ''
    if ($existingNumber -eq $phoneNumber -and -not $Remove) {
        Write-Output "Phone number '$($phoneNumber)' is already assigned to user '$($userPrincipalName)'. No changes needed."
        Write-Output ""
        Write-Output "Done!"
        exit
    }
}

#endregion StatusQuo & Preflight-Check Part

############################################################
#region     Main Part
#
############################################################

Write-Output ""
Write-Output "Start set process"
Write-Output "---------------------"

$body = @{
    phoneNumber = $phoneNumber
    phoneType   = "mobile"
}

if ($phoneAM) {
    if ($Remove) {
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods/$($phoneAM.id)" -Method Delete | Out-Null
            Write-Output "Successfully removed mobile phone authentication number '$($phoneNumber)' from user '$($userPrincipalName)'."
        }
        catch {
            Write-Error "Failed to remove phone MFA method: $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
    }
    else {
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods/$($phoneAM.id)" -Method Patch -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-Output "Successfully updated mobile phone authentication number '$($phoneNumber)' for user '$($userPrincipalName)'."
        }
        catch {
            $fullErrorMessage = "$($_.ErrorDetails.Message) $($_.Exception.Message)"
            if ($fullErrorMessage -match 'phoneNumberNotUnique') {
                Write-Error "Phone number '$($phoneNumber)' cannot be used because it is reserved for SMS Sign-In by another user in this tenant." -ErrorAction Continue
                Find-PhoneNumberOwner -PhoneNumber $phoneNumber
                throw "Phone number '$($phoneNumber)' is reserved for SMS Sign-In by another user. See above for details."
            }
            else {
                Write-Error "Failed to update phone MFA method: $($_.Exception.Message)" -ErrorAction Continue
                throw
            }
        }
    }
}
else {
    if ($Remove) {
        Write-Output "Number '$($phoneNumber)' not found as mobile phone MFA factor for '$($userPrincipalName)'."
    }
    else {
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-Output "Successfully added mobile phone authentication number '$($phoneNumber)' to user '$($userPrincipalName)'."
        }
        catch {
            $fullErrorMessage = "$($_.ErrorDetails.Message) $($_.Exception.Message)"
            if ($fullErrorMessage -match 'phoneNumberNotUnique') {
                Write-Error "Phone number '$($phoneNumber)' cannot be used because it is reserved for SMS Sign-In by another user in this tenant." -ErrorAction Continue
                Find-PhoneNumberOwner -PhoneNumber $phoneNumber
                throw "Phone number '$($phoneNumber)' is reserved for SMS Sign-In by another user. See above for details."
            }
            else {
                Write-Error "Failed to add phone MFA method: $($_.Exception.Message)" -ErrorAction Continue
                throw
            }
        }
    }
}

#endregion Main Part

Write-Output ""
Write-Output "Done!"
