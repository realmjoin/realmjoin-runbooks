<#
    .SYNOPSIS
    Set or remove a user's mobile phone MFA method

    .DESCRIPTION
    Adds, updates, or removes the user's mobile phone authentication method. This runbook manages phone numbers as regular MFA factors (call/text verification). Important: The Microsoft Graph phoneMethods API does not offer a way to add a phone number as "MFA only" without triggering an automatic SMS Sign-In registration attempt. If the user is enabled by the tenant's Authentication Methods Policy for SMS Sign-In, Graph will automatically try to register the number for SMS Sign-In after creating or updating the phone method. If the number is already used by another user for SMS Sign-In, Graph returns a 409 Conflict with error code "phoneNumberNotUnique". However, the phone method itself (for regular MFA) is typically created or updated successfully despite this error. The smsSignInState property is read-only and cannot be controlled via the create/update request. SMS Sign-In can only be explicitly managed via the separate enableSmsSignIn and disableSmsSignIn endpoints. This runbook verifies the actual state after such errors and reports success if the MFA method was assigned, with a warning about the SMS Sign-In conflict. If the assignment truly failed, it searches for the user holding the number.

    .PARAMETER UserId
    Object ID of the target user.

    .PARAMETER phoneNumber
    Mobile phone number in international E.164 format (e.g., +491701234567).

    .PARAMETER Remove
    "Set/Update Mobile Phone MFA Method" (final value: $false) or "Remove Mobile Phone MFA Method" (final value: $true) can be selected as action to perform. If set to true, the runbook will remove the mobile phone MFA method for the user. If set to false, it will add or update the mobile phone MFA method with the provided phone number.

    .PARAMETER CallerName
    Caller name is tracked purely for auditing purposes.

    .PARAMETER NotifyUser
    When enabled, sends a notification email to the target user informing them that their mobile phone MFA method was added or removed by an administrator. Default is disabled.

    .PARAMETER EmailFrom
    Sender email address for the optional notification mail. Sourced from the RealmJoin tenant setting RJReport.EmailSender.

    .PARAMETER ServiceDeskDisplayName
    Service Desk display name for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_DisplayName.

    .PARAMETER ServiceDeskEmail
    Service Desk email address for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_EMail.

    .PARAMETER ServiceDeskPhone
    Service Desk phone number for user contact information (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_Phone.

    .PARAMETER ServiceDeskPortalUrl
    Service Desk portal URL for user contact information, rendered as a clickable link (optional). Sourced from the RealmJoin tenant setting RJReport.ServiceDesk_PortalUrl.

    .PARAMETER ServiceDeskTicketUrl
    Direct link to the Service Desk ticket related to this request, rendered as a clickable link (optional). Empty by default, so no ticket link is added.

    .PARAMETER LanguageOverride
    Overrides the language used for the notification email. Accepted values are 'DE' (German) or 'EN' (English). If left empty, the language is determined automatically based on the target user's usage location.

    .NOTES
    Permissions (managed identity, application):
    - UserAuthenticationMethod.ReadWrite.All - manage phone authentication methods
    - User.Read.All                           - resolve target user
    - Organization.Read.All                  - read tenant display name for the email body
    - Mail.Send                              - only required when NotifyUser is enabled

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
            "NotifyUser": {
                "DisplayName": "Notify user via email",
                "Hide": true
            },
            "EmailFrom": {
                "Hide": true
            },
            "ServiceDeskDisplayName": {
                "Hide": true
            },
            "ServiceDeskEmail": {
                "Hide": true
            },
            "ServiceDeskPhone": {
                "Hide": true
            },
            "ServiceDeskPortalUrl": {
                "Hide": true
            },
            "ServiceDeskTicketUrl": {
                "Hide": true
            },
            "LanguageOverride": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.7" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.38.0" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Current User" } )]
    [String]$UserId,
    [Parameter(Mandatory = $true)]
    [String]$phoneNumber,
    [bool] $Remove = $false,

    [bool]$NotifyUser = $false,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.EmailSender" -Value $_ } )]
    [string]$EmailFrom,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_DisplayName" } )]
    [string]$ServiceDeskDisplayName,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_EMail" } )]
    [string]$ServiceDeskEmail,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_Phone" } )]
    [string]$ServiceDeskPhone,

    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "RJReport.ServiceDesk_PortalUrl" } )]
    [string]$ServiceDeskPortalUrl,

    [string]$ServiceDeskTicketUrl = "",

    # LanguageOverride allows forcing a specific notification email language ('DE' or 'EN'); empty = auto-detect from usage location
    [ValidateSet('', 'DE', 'EN')]
    [string]$LanguageOverride = "",

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

$Version = "2.1.3"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "UserId: $UserId" -Verbose
Write-RjRbLog -Message "phoneNumber: $phoneNumber" -Verbose
Write-RjRbLog -Message "Remove: $Remove" -Verbose
Write-RjRbLog -Message "NotifyUser: $NotifyUser" -Verbose
Write-RjRbLog -Message "LanguageOverride: $LanguageOverride" -Verbose

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
            termination since these numbers must be unique. Sets $script:phoneNumberOwnerFound
            to $true if found, $false otherwise.

            .PARAMETER PhoneNumber
            The phone number to search for in E.164 format.
        #>
        param(
            [string]$PhoneNumber
        )

        $script:phoneNumberOwnerFound = $false

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
                            if ($cleanNumber -eq $PhoneNumber) {
                                Write-Output ""
                                Write-Output "Phone number '$($PhoneNumber)' is assigned to:"
                                Write-Output "  Display Name:       $($user.userDisplayName)"
                                Write-Output "  UPN:                $($user.userPrincipalName)"
                                Write-Output "  Phone Type:         $($method.phoneType)"
                                Write-Output "  SMS Sign-In State:  $($method.smsSignInState)"
                                Write-Output "  Entra Portal Link:  https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($user.id)"
                                $script:phoneNumberOwnerFound = $true
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
            if ($processedCount % $progressInterval -eq 0) {
                Write-Output "Searched $processedCount of $($phoneRegisteredUsers.Count) users..."
            }
        }

        Write-Output "Could not identify the user holding this phone number for SMS Sign-In."
        Write-Output "The number may be held by a deleted or soft-deleted user account."
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

if ($NotifyUser) {
    try {
        Connect-RjRbGraph | Out-Null
    }
    catch {
        Write-Error "Failed to initialize the RealmJoin Graph context required for sending the notification email via Send-RjReportEmail. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "RealmJoin Graph connection failed."
    }
}

#endregion Connect Part

############################################################
#region     StatusQuo & Preflight-Check Part
#
############################################################

# Resolve user details for display and to validate the user exists
try {
    $targetUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)?`$select=id,userPrincipalName,displayName,userType,mail,usageLocation" -Method Get
}
catch {
    Write-Error "Failed to resolve user '$($UserId)': $($_.Exception.Message)" -ErrorAction Continue
    throw
}
$userPrincipalName = $targetUser.userPrincipalName
$userDisplayName = $targetUser.displayName
Write-Output "User: '$($userDisplayName)' ($($userPrincipalName))"
if ($targetUser.userType -eq 'Guest') {
    Write-Output "Note: User '$($userDisplayName)' ($($userPrincipalName)) is a guest user."
}
$CurrentMail = $targetUser.mail
$CurrentUsageLocation = $targetUser.usageLocation

if ($NotifyUser) {
    if ([string]::IsNullOrWhiteSpace($CurrentMail)) {
        Write-RjRbLog -Message "WARNING: NotifyUser is enabled but the target user has no primary email address. The notification email will be skipped."
    }
    if ([string]::IsNullOrWhiteSpace($EmailFrom)) {
        Write-Error "NotifyUser is enabled but the 'RJReport.EmailSender' tenant setting is empty. Configure a valid sender email address in RealmJoin settings or disable NotifyUser." -ErrorAction Continue
        throw "Sender email address not configured."
    }
}

Write-Output ""
if ($Remove) {
    Write-Output "Trying to remove phone MFA number '$($phoneNumber)'."
}
else {
    Write-Output "Trying to add phone MFA number '$($phoneNumber)'."
}
Write-Output "---------------------"

# Find existing mobile phone auth methods for user
Write-Output "Getting current phone authentication methods..."
try {
    $phoneMethodsResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods?`$filter=phoneType eq 'mobile'" -Method Get
    $phoneAM = $phoneMethodsResponse.value | Select-Object -First 1  # At most one mobile phone method per user
}
catch {
    Write-Error "Failed to retrieve phone authentication methods: $($_.Exception.Message)"
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
        Write-Output "Phone number '$($phoneNumber)' is already assigned to '$($userDisplayName)'. No changes needed."
        Write-Output ""
        Write-Output "Done!"
        exit
    }
}
else {
    Write-Output "No mobile phone MFA method is currently configured."
}

#endregion StatusQuo & Preflight-Check Part

############################################################
#region     Main Part
#
############################################################

# --- API Behavior Note ---
# The Graph phoneMethods API (POST/PATCH) creates or updates the phone number as a regular MFA factor.
# However, if the user is enabled for SMS Sign-In by the tenant's Authentication Methods Policy,
# Graph automatically attempts to register the number for SMS Sign-In after the MFA assignment.
# This auto-registration can fail with a 409 Conflict / "phoneNumberNotUnique" error if the number
# is already registered for SMS Sign-In by another user. Crucially, the MFA phone method itself is
# typically created/updated successfully despite this error — only the SMS Sign-In enablement fails.
# The smsSignInState property is read-only and cannot be set via POST/PATCH.
# SMS Sign-In must be managed via the separate enableSmsSignIn / disableSmsSignIn endpoints.
# Therefore, on a 409 error we wait briefly and verify the actual state before deciding outcome.
# Reference: https://learn.microsoft.com/en-us/graph/api/authentication-post-phonemethods
# Reference: https://learn.microsoft.com/en-us/graph/api/phoneauthenticationmethod-update

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
            Write-Output "Successfully removed mobile phone authentication number '$($phoneNumber)' from '$($userDisplayName)'."
        }
        catch {
            Write-Error "Failed to remove phone MFA method: $($_.Exception.Message)" -ErrorAction Continue
            throw
        }
    }
    else {
        $conflictError = $null
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods/$($phoneAM.id)" -Method Patch -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-Output "Successfully updated mobile phone authentication number '$($phoneNumber)' for '$($userDisplayName)'."
        }
        catch {
            $fullErrorMessage = "$($_.ErrorDetails.Message) $($_.Exception.Message)"
            Write-RjRbLog -Message "Graph API error during update: $($fullErrorMessage)" -Verbose

            if ($fullErrorMessage -match 'phoneNumberNotUnique|409|Conflict') {
                # Extract the error message from the JSON portion of the error response
                if ($_.ErrorDetails.Message -match '(\{"error":.+)') {
                    try {
                        $errorBody = $Matches[1] | ConvertFrom-Json
                        $conflictError = $errorBody.error.message
                    }
                    catch {
                        $conflictError = "Phone number uniqueness conflict (could not parse error details)."
                    }
                }
                else {
                    $conflictError = "Phone number uniqueness conflict (could not parse error details)."
                }
            }
            else {
                Write-Error "Failed to update phone MFA method: $($_.Exception.Message)" -ErrorAction Continue
                throw
            }
        }

        # Handle 409 Conflict: verify actual state after a short delay
        if ($conflictError) {
            Write-RjRbLog -Message "Received SMS Sign-In uniqueness conflict. Waiting 5 seconds before verifying MFA assignment..." -Verbose
            Start-Sleep -Seconds 5

            $verifyResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods?`$filter=phoneType eq 'mobile'" -Method Get
            $verifyAM = $verifyResponse.value | Select-Object -First 1
            $verifyNumber = if ($verifyAM) { $verifyAM.phoneNumber -replace '\s', '' } else { $null }

            if ($verifyNumber -eq $phoneNumber) {
                Write-Output "Successfully updated mobile phone authentication number '$($phoneNumber)' for '$($userDisplayName)'."
                Write-Output "Note: SMS Sign-In is not available for this number because it is already registered for SMS Sign-In by another user in this tenant."
                Write-Output "Reason: $($conflictError)"
            }
            else {
                Write-Error "Phone number '$($phoneNumber)' could not be updated. The number must be unique for SMS Sign-In and cannot be used as MFA for this user." -ErrorAction Continue
                Find-PhoneNumberOwner -PhoneNumber $phoneNumber
                throw "Phone number '$($phoneNumber)' could not be assigned. See above for details."
            }
        }
    }
}
else {
    if ($Remove) {
        Write-Output "Number '$($phoneNumber)' not found as mobile phone MFA factor for '$($userDisplayName)'."
    }
    else {
        $conflictError = $null
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-Output "Successfully added mobile phone authentication number '$($phoneNumber)' to '$($userDisplayName)'."
        }
        catch {
            $fullErrorMessage = "$($_.ErrorDetails.Message) $($_.Exception.Message)"
            Write-RjRbLog -Message "Graph API error during creation: $($fullErrorMessage)" -Verbose

            if ($fullErrorMessage -match 'phoneNumberNotUnique|409|Conflict') {
                # Extract the error message from the JSON portion of the error response
                if ($_.ErrorDetails.Message -match '(\{"error":.+)') {
                    try {
                        $errorBody = $Matches[1] | ConvertFrom-Json
                        $conflictError = $errorBody.error.message
                    }
                    catch {
                        $conflictError = "Phone number uniqueness conflict (could not parse error details)."
                    }
                }
                else {
                    $conflictError = "Phone number uniqueness conflict (could not parse error details)."
                }
            }
            else {
                Write-Error "Failed to add phone MFA method: $($_.Exception.Message)" -ErrorAction Continue
                throw
            }
        }

        # Handle 409 Conflict: verify actual state after a short delay
        if ($conflictError) {
            Write-RjRbLog -Message "Received SMS Sign-In uniqueness conflict. Waiting 5 seconds before verifying MFA assignment..." -Verbose
            Start-Sleep -Seconds 5

            $verifyResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($UserId)/authentication/phoneMethods?`$filter=phoneType eq 'mobile'" -Method Get
            $verifyAM = $verifyResponse.value | Select-Object -First 1
            $verifyNumber = if ($verifyAM) { $verifyAM.phoneNumber -replace '\s', '' } else { $null }

            if ($verifyNumber -eq $phoneNumber) {
                Write-Output "Successfully added mobile phone authentication number '$($phoneNumber)' to '$($userDisplayName)'."
                Write-Output "Note: SMS Sign-In is not available for this number because it is already registered for SMS Sign-In by another user in this tenant."
                Write-Output "Reason: $($conflictError)"
            }
            else {
                Write-Error "Phone number '$($phoneNumber)' could not be added. The number must be unique for SMS Sign-In and cannot be used as MFA for this user." -ErrorAction Continue
                Find-PhoneNumberOwner -PhoneNumber $phoneNumber
                throw "Phone number '$($phoneNumber)' could not be assigned. See above for details."
            }
        }
    }
}

#endregion Main Part

########################################################
#region     Notify User
########################################################

Write-Output ""
Write-Output "Notify User"
Write-Output "---------------------"

if (-not $NotifyUser) {
    Write-Output "NotifyUser is disabled - no notification email sent."
}
elseif ([string]::IsNullOrWhiteSpace($CurrentMail)) {
    Write-Output "Skipped: target user has no primary email address."
}
else {
    $tenantDisplayName = "your organization"
    try {
        $tenantInfo = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
        if ($tenantInfo -and $tenantInfo.value -and $tenantInfo.value.Count -gt 0 -and $tenantInfo.value[0].displayName) {
            $tenantDisplayName = $tenantInfo.value[0].displayName
        }
    }
    catch {
        Write-RjRbLog -Message "WARNING: Could not retrieve tenant display name. Falling back to a generic value. Error: $($_.Exception.Message)"
    }

    $useGerman = if (-not [string]::IsNullOrWhiteSpace($LanguageOverride)) { $LanguageOverride -eq 'DE' } else { $CurrentUsageLocation -eq 'DE' }

    $serviceDeskSection = ""
    if ($ServiceDeskDisplayName -or $ServiceDeskEmail -or $ServiceDeskPhone -or $ServiceDeskPortalUrl -or $ServiceDeskTicketUrl) {
        if ($useGerman) {
            $serviceDeskSection = "`n`n### Service Desk Kontaktinformationen`n"
        }
        else {
            $serviceDeskSection = "`n`n### Service Desk Contact Information`n"
        }
        if ($ServiceDeskDisplayName) {
            $serviceDeskSection += "`n $($ServiceDeskDisplayName)"
        }
        if ($ServiceDeskEmail) {
            $serviceDeskSection += "`n **Email:** [$($ServiceDeskEmail)](mailto:$($ServiceDeskEmail))"
        }
        if ($ServiceDeskPhone) {
            if ($useGerman) {
                $serviceDeskSection += "`n **Telefon:** [$($ServiceDeskPhone)](tel:$($ServiceDeskPhone))"
            }
            else {
                $serviceDeskSection += "`n **Phone:** [$($ServiceDeskPhone)](tel:$($ServiceDeskPhone))"
            }
        }
        if ($ServiceDeskPortalUrl) {
            $serviceDeskSection += "`n **Portal:** [$($ServiceDeskPortalUrl)]($($ServiceDeskPortalUrl))"
        }
        if ($ServiceDeskTicketUrl) {
            $serviceDeskSection += "`n **Ticket:** [$($ServiceDeskTicketUrl)]($($ServiceDeskTicketUrl))"
        }
    }

    if ($Remove) {
        if ($useGerman) {
            $subject = "Ihre mobile Telefon-MFA-Methode wurde von einem Administrator entfernt"
            $markdownContent = @"
Hallo $userDisplayName,

Dies ist eine automatische Benachrichtigung von $tenantDisplayName.

Ein Administrator hat Ihre mobile Telefon-MFA-Methode ($phoneNumber) über das RealmJoin-Portal von Ihrem Konto entfernt.

Falls Sie diesen Vorgang nicht erwartet haben, wenden Sie sich bitte an Ihre IT-Administration.$serviceDeskSection

Durchgeführt von: $CallerName
Datum (UTC):      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Mit freundlichen Grüßen,
IT-Administration

---

*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*
"@
        }
        else {
            $subject = "Your mobile phone MFA method has been removed by an administrator"
            $markdownContent = @"
Hello $userDisplayName,

This is an automated notification from $tenantDisplayName.

An administrator has removed your mobile phone MFA method ($phoneNumber) from your account through the RealmJoin portal.

If you did not expect this action, please contact your IT administrator.$serviceDeskSection

Action performed by: $CallerName
Date (UTC):          $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Regards,
IT Administration

---

*This email was automatically generated. Please do not reply to this email.*
"@
        }
    }
    else {
        if ($useGerman) {
            $subject = "Eine Mobiltelefonnummer wurde Ihrem Konto als MFA-Methode hinzugefügt"
            $markdownContent = @"
Hallo $userDisplayName,

Dies ist eine automatische Benachrichtigung von $tenantDisplayName.

Ein Administrator hat die Mobiltelefonnummer $phoneNumber über das RealmJoin-Portal als mobile Telefon-MFA-Methode zu Ihrem Konto hinzugefügt.

Falls Sie diesen Vorgang nicht erwartet haben, wenden Sie sich bitte an Ihre IT-Administration.$serviceDeskSection

Durchgeführt von: $CallerName
Datum (UTC):      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Mit freundlichen Grüßen,
IT-Administration

---

*Diese E-Mail wurde automatisch generiert. Bitte antworten Sie nicht auf diese E-Mail.*
"@
        }
        else {
            $subject = "A mobile phone MFA method was added to your account by an administrator"
            $markdownContent = @"
Hello $userDisplayName,

This is an automated notification from $tenantDisplayName.

An administrator has added the mobile phone number $phoneNumber as a mobile phone MFA method to your account through the RealmJoin portal.

If you did not expect this action, please contact your IT administrator.$serviceDeskSection

Action performed by: $CallerName
Date (UTC):          $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Regards,
IT Administration

---

*This email was automatically generated. Please do not reply to this email.*
"@
        }
    }

    try {
        Send-RjReportEmail -EmailFrom $EmailFrom -EmailTo $CurrentMail -Subject $subject -MarkdownContent $markdownContent -TenantDisplayName $tenantDisplayName -ReportVersion $Version
        Write-Output "Notification email sent to $CurrentMail."
    }
    catch {
        Write-Error "Failed to send notification email to '$CurrentMail'. Verify the managed identity has the 'Mail.Send' application permission and that the sender '$EmailFrom' is a valid mailbox in this tenant. Error: $($_.Exception.Message)" -ErrorAction Continue
        throw "Notification email send failed."
    }
}

#endregion

Write-Output ""
Write-Output "Done!"
