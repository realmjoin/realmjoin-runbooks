<#

.SYNOPSIS
    Update an application registration in Azure AD

.DESCRIPTION
    This script modifies an existing application registration in Azure Active Directory (Entra ID) with comprehensive configuration updates.

    The script intelligently determines what changes need to be applied by comparing current settings
    with requested parameters, ensuring only necessary updates are performed. It maintains backward
    compatibility while supporting modern authentication patterns and security requirements.

.INPUTS
    RunbookCustomization: {
    "Parameters": {
        "signInAudience": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        },
        "RedirectURI": {
            "DisplayName": "Redirect URI (Optional)",
            "Default": "None",
            "Select": {
                "Options": [
                        {
                        "Display": "None",
                        "ParameterValue": "None",
                        "Customization": {
                            "Default": {
                                        "EnableSAML": false
                            },
                            "Hide": [
                                "webRedirectURI",
                                "publicClientRedirectURI",
                                "spaRedirectURI",
                                "EnableSAML",
                                "SAMLReplyURL",
                                "SAMLSignOnURL",
                                "SAMLLogoutURL",
                                "SAMLIdentifier",
                                "SAMLRelayState",
                                "SAMLExpiryNotificationEmail"
                            ]
                        }
                        },
                        {
                            "Display": "Web",
                            "ParameterValue": "Web",
                            "Customization": {
                                "Default": {
                                        "EnableSAML": false
                                },
                                "Hide": [
                                    "publicClientRedirectURI",
                                    "spaRedirectURI",
                                    "EnableSAML",
                                    "SAMLReplyURL",
                                    "SAMLSignOnURL",
                                    "SAMLLogoutURL",
                                    "SAMLIdentifier",
                                    "SAMLRelayState",
                                    "SAMLExpiryNotificationEmail"
                                ]
                            }
                        },
                        {
                            "Display": "SAML",
                            "ParameterValue": "SAML",
                            "Customization": {
                                "Default": {
                                        "EnableSAML": true
                                },
                                "Hide": [
                                    "webRedirectURI",
                                    "publicClientRedirectURI",
                                    "spaRedirectURI"
                                ]
                            }
                        },
                        {
                            "Display": "Public client/native (mobile & desktop)",
                            "ParameterValue": "PublicClient",
                            "Customization": {
                                "Default": {
                                        "EnableSAML": false
                                },
                                "Hide": [
                                    "webRedirectURI",
                                    "spaRedirectURI",
                                    "EnableSAML",
                                    "SAMLReplyURL",
                                    "SAMLSignOnURL",
                                    "SAMLLogoutURL",
                                    "SAMLIdentifier",
                                    "SAMLRelayState",
                                    "SAMLExpiryNotificationEmail"
                                ]
                            }
                        },
                        {
                            "Display": "Single-page application (SPA)",
                            "ParameterValue": "SPA",
                            "Customization": {
                                "Hide": [
                                    "webRedirectURI",
                                    "publicClientRedirectURI",
                                    "EnableSAML",
                                    "SAMLReplyURL",
                                    "SAMLSignOnURL",
                                    "SAMLLogoutURL",
                                    "SAMLIdentifier",
                                    "SAMLRelayState",
                                    "SAMLExpiryNotificationEmail"
                                ]
                            }
                        }
                ],
                "ShowValue": false
            }
        },
        "webRedirectURI": {
            "DisplayName": "Web Redirect URI e.g. https://myapp.com/auth (semicolon-separated for multiple)",
            "Hide": false
        },
        "publicClientRedirectURI": {
            "DisplayName": "Public client/native Redirect URI e.g. myapp://auth (semicolon-separated for multiple)",
            "Hide": false
        },
        "spaRedirectURI": {
            "DisplayName": "Single-page application (SPA) Redirect URI e.g. https://myapp.com (semicolon-separated for multiple)",
            "Hide": false
        },
        "EnableSAML":{
            "Hide": false
        },
        "SAMLReplyURL":{
            "Hide": false
        },
        "SAMLSignOnURL":{
            "Hide": false
        },
        "SAMLLogoutURL":{
            "Hide": false
        },
        "SAMLIdentifier":{
            "Hide": false
        },
        "SAMLRelayState":{
            "Hide": false
        },
        "SAMLExpiryNotificationEmail":{
            "Hide": false
        },
        "isApplicationVisible":{
            "DisplayName": "Application visible in My Apps portal",
            "Hide": false
        },
        "UserAssignmentRequired":{
            "DisplayName": "User assignment required",
            "Hide": false
        },
        "groupAssignmentPrefix":{
            "DisplayName": "Group assignment prefix (Only necessary when User assignment required)",
            "Hide": false
        },
        "implicitGrantAccessTokens":{
            "DisplayName": "Enable implicit grant for access tokens",
            "Hide": false
        },
        "implicitGrantIDTokens":{
            "DisplayName": "Enable implicit grant for ID tokens",
            "Hide": false
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $ClientId,
    [string] $RedirectURI, # Only for UI used
    [string] $webRedirectURI = "",
    [string] $publicClientRedirectURI = "",
    [string] $spaRedirectURI = "",
    [bool] $EnableSAML = $false,
    [String] $SAMLReplyURL = "",
    [String] $SAMLSignOnURL = "",
    [String] $SAMLLogoutURL = "",
    [String] $SAMLIdentifier = "",
    [String] $SAMLRelayState = "",
    [String] $SAMLExpiryNotificationEmail = "",
    [bool] $isApplicationVisible = $true,
    [bool] $UserAssignmentRequired = $false,
    [String] $groupAssignmentPrefix = "col - Entra - users - ",
    [bool] $implicitGrantAccessTokens = $false,
    [bool] $implicitGrantIDTokens = $false,
    [bool] $disableImplicitGrant = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Check if the application exists
$existingApp = Invoke-RjRbRestMethodGraph -Method GET -Resource "/applications" -OdFilter "appId eq '$ClientId'" -ErrorAction SilentlyContinue

if (-not $existingApp) {
    "## Application with '$ClientId' does not exists."
    throw "Application with '$ClientId' does not exists. Stopping."
}

# Check if the service principal exists
$existingSvcPrincipal = Invoke-RjRbRestMethodGraph -Method GET -Resource "/servicePrincipals" -OdFilter "appId eq '$ClientId'" -ErrorAction SilentlyContinue

if (-not $existingSvcPrincipal) {
    "## Service Principal for ClientId '$ClientId' does not exists."
    throw "Service Principal for ClientId '$ClientId' does not exists. Stopping."
}

$webRedirectURIs = @()
if ($webRedirectURI) {
    $webRedirectURIs += $webRedirectURI.Split(";").Trim()
}
$spaRedirectURIs = @()
if ($spaRedirectURI) {
    $spaRedirectURIs += $spaRedirectURI.Split(";").Trim()
}
$publicClientRedirectURIs = @()
if ($publicClientRedirectURI) {
    $publicClientRedirectURIs += $publicClientRedirectURI.Split(";").Trim()
}

if (($webRedirectURIs.count -gt 0) -or ($EnableSAML -and ($SAMLReplyURL.count -gt 0))) {
    if ($SAMLReplyURL) {
        $webRedirectURIs = @($SAMLReplyURL)
    }
    else {
        "## Web redirect URI / SAML Reply URL must be specified for SAML applications."
        "## Stopping"
        throw ("Web redirect URI must be specified for SAML applications")
    }
}

if ($EnableSAML -and (-not $SAMLReplyURL)) {
    if ($publicClientRedirectURIs.Count -gt 0) {
        $SAMLReplyURL = $publicClientRedirectURI[0]
    }
    elseif ($webRedirectURIs.Count -gt 0) {
        $SAMLReplyURL = $webRedirectURI[0]
    }
    elseif ($spaRedirectURIs.Count -gt 0) {
        $SAMLReplyURL = $spaRedirectURI[0]
    }
}

if ($EnableSAML -and (-not $SAMLReplyURL)) {
    "## SAML Reply URL must be specified for SAML applications."
    "## Stopping"
    throw ("SAML Reply URL must be specified for SAML applications")
}

if ($SAMLIdentifier) {
    $SAMLIdentifier = $SAMLIdentifier.trim().trimend('/')
}

# Make sure early that SAML is enabled on the service principal, if required.
if ($EnableSAML) {
    if ($existingSvcPrincipal.preferredSingleSignOnMode -ne "saml") {
        $body = @{}

        "## Updating preferredSingleSignOnMode to 'saml'"
        $body["preferredSingleSignOnMode"] = "saml"

        Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($existingSvcPrincipal.id)" -Method PATCH -Body $body | Out-Null
        "## Waiting 20 seconds for changes to propagate to the application"
    }
}

$body = @{}
$web = @{}

# Set the redirect URIs if Web redirect URIs are specified
$redirects = @()
if ($webRedirectURIs.count -gt 0) {
    $redirects = @($webRedirectURIs)
    if ($EnableSAML -and $SAMLReplyURL -and ($redirects -notcontains $SAMLReplyURL)) {
        $redirects += $SAMLReplyURL
    }
    $web["redirectUris"] = $redirects
}

if ($disableImplicitGrant) {
    $web["implicitGrantSettings"] = @{
        "enableAccessTokenIssuance" = $false
        "enableIdTokenIssuance"     = $false
    }
}
else {
    $web["implicitGrantSettings"] = @{
        "enableAccessTokenIssuance" = $existingApp.web.implicitGrantSettings.enableAccessTokenIssuance -or $implicitGrantAccessTokens
        "enableIdTokenIssuance"     = $existingApp.web.implicitGrantSettings.enableIdTokenIssuance -or $implicitGrantIDTokens
    }
}

if ($spaRedirectURI) {
    "## Updating spa redirect URIs"
    $body["spa"] = @{
        "redirectUris" = $spaRedirectURis
    }
}

if ($publicClientRedirectURI) {
    "## Updating Public Client redirect URIs"
    $body["publicClient"] = @{
        "redirectUris" = $publicClientRedirectURIs
    }
}

$body["tags"] = [array]($existingApp.tags)

if ($EnableSAML) {
    if ($existingApp.signInAudience -ne "AzureADMyOrg") {
        "## Updating signInAudience to 'AzureADMyOrg'"
        $body["signInAudience"] = "AzureADMyOrg"
    }
    if ($body["tags"] -notcontains "WindowsAzureActiveDirectoryCustomSingleSignOnApplication") {
        "## Updating tags to include 'WindowsAzureActiveDirectoryCustomSingleSignOnApplication'"
        $body["tags"] = [array]($body["tags"] + "WindowsAzureActiveDirectoryCustomSingleSignOnApplication")
    }
    if ($SAMLLogoutURL) {
        $web["logoutUrl"] = $SAMLLogoutURL
    }
    if ($SAMLIdentifier) {
        "## Updating identifierUris to '$SAMLIdentifier'"
        $body["identifierUris"] = @($SAMLIdentifier)
    }
}

# Check if the application is visible
if ($isApplicationVisible -and ($body["tags"] -contains "HideApp")) {
    "## Making the application visible"
    $body["tags"] = [array]($body["tags"] -ne "HideApp")
}
if (-not $isApplicationVisible -and ($body["tags"] -notcontains "HideApp")) {
    "## Hiding the application"
    $body["tags"] = [array]($body["tags"] + @("HideApp"))
}

if ($web.count -gt 0) {
    $body["web"] = $web
}

if ($body.count -gt 0) {

    Invoke-RjRbRestMethodGraph -Resource "/applications/$($existingApp.id)" -Method PATCH -Body $body | Out-Null
    "## Application updated."
    "## Waiting 20 seconds for changes to propagate to the service principal"
    Start-Sleep -Seconds 20
}

$body = @{}

# Check if SAML Settings are correct for the service principal
if ($EnableSAML) {
    $resultSvcPrincipal = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($existingSvcPrincipal.id)" -Method GET
    if ($SAMLReplyURL) {
        if ($resultSvcPrincipal.replyUrls -notcontains $SAMLReplyURL) {
            "## Updating SAML Reply URL to '$SAMLReplyURL'"
            $body["replyUrls"] = @($SAMLReplyURL)
        }
    }
    if ($SAMLRelayState -and ($resultSvcPrincipal.samlSingleSignOnSettings.relayState -ne $SAMLRelayState)) {
        "## Updating SAML Relay State to '$SAMLRelayState'"
        $body["samlSingleSignOnSettings"] = @{
            "relayState" = $SAMLRelayState
        }
    }
    if ($SAMLSignOnURL -and ($resultSvcPrincipal.loginUrl -ne $SAMLSignOnURL)) {
        "## Updating SAML Sign On URL to '$SAMLSignOnURL'"
        $body["loginUrl"] = $SAMLSignOnURL
    }
    if ($SAMLIdentifier -and ($resultSvcPrincipal.servicePrincipalNames -notcontains $SAMLIdentifier)) {
        "## Updating ServicePrincipalNames to include SAML Identifier '$SAMLIdentifier'"
        $body["servicePrincipalNames"] = @(
            $SAMLIdentifier,
            $ClientId
        )
    }
    if ($SAMLExpiryNotificationEmail -and ($resultSvcPrincipal.notificationEmailAddresses -notcontains $SAMLExpiryNotificationEmail)) {
        "## Updating Notification Email to '$SAMLExpiryNotificationEmail'"
        $body["notificationEmailAddresses"] = @($SAMLExpiryNotificationEmail)
    }

    Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)" -Method PATCH -Body $body | Out-Null
    "## Service Principal updated."
    "## Waiting 20 seconds for changes to propagate."
    Start-Sleep -Seconds 20
}

if ($PSBoundParameters.Keys -contains "UserAssignmentRequired") {
    if ($UserAssignmentRequired) {
        # Check if the user assignment is required
        $resultSvcPrincipal = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($existingSvcPrincipal.id)" -Method GET
        if ($resultSvcPrincipal.appRoleAssignmentRequired -ne $true) {
            "## Updating appRoleAssignmentRequired to '$true'"
            $body = @{
                "appRoleAssignmentRequired" = $true
            }

            Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)" -Method PATCH -Body $body | Out-Null

            $appRoleAssignments = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)/appRoleAssignedTo" -Method GET -ErrorAction SilentlyContinue
            if (-not $appRoleAssignments) {
                $ApplicationName = $existingApp.displayName
                $ApplicationFullName = $ApplicationName

                [string]$shortAppName = $ApplicationFullName -replace " \| ", "-" -replace "\|", "-" # -replace " ", "-" -replace "[()]", ""

                [string]$mailnickname = $ApplicationName -replace " \| ", "-" -replace "\|", "-" -replace " ", "-" -replace "[()]", ""
                if ($mailnickname.Length -gt 25) {
                    $mailnickname = $mailnickname.Substring(0, 24)
                }

                # Create a valid mailNickname by removing invalid characters (spaces, special chars)
                $groupMailNickname = ($groupAssignmentPrefix + $mailnickname) -replace "[^a-zA-Z0-9\-]", "" -replace "^-+", "" -replace "-+$", ""
                # Ensure mailNickname doesn't exceed 64 characters and doesn't start/end with dash
                if ($groupMailNickname.Length -gt 64) {
                    $groupMailNickname = $groupMailNickname.Substring(0, 63)
                }
                # Remove trailing dashes if any
                $groupMailNickname = $groupMailNickname -replace "-+$", ""

                $groupBody = @{
                    "displayName"     = "$groupAssignmentPrefix$shortAppName"
                    "description"     = "Users of $ApplicationFullName"
                    "mailEnabled"     = $false
                    "mailNickname"    = $groupMailNickname
                    "securityEnabled" = $true
                }
                $resultGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -Method POST -Body $groupBody
                "## Group '$($resultGroup.displayName)' created, id: $($resultGroup.id)"

                # Add the group to the application
                $groupAppRoleBody = @{
                    "appRoleId"   = "00000000-0000-0000-0000-000000000000"
                    "principalId" = $resultGroup.id
                    "resourceId"  = $resultSvcPrincipal.id
                }
                $resultGroupAppRole = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)/appRoleAssignedTo" -Method POST -Body $groupAppRoleBody
                "## Group '$($resultGroup.displayName)' added to application '$ApplicationFullName'"
            }
        }
    }
    else {
        # If $UserAssignmentRequired=false
        $resultSvcPrincipal = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($existingSvcPrincipal.id)" -Method GET
        if ($resultSvcPrincipal.appRoleAssignmentRequired -ne $false) {
            "## Updating appRoleAssignmentRequired to '$false'"
            $body = @{
                "appRoleAssignmentRequired" = $false
            }

            Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)" -Method PATCH -Body $body | Out-Null
            "## Waiting 20 seconds for changes to propagate."
            Start-Sleep -Seconds 20
        }
    }
}

# refresh the service principal
$existingSvcPrincipal = Invoke-RjRbRestMethodGraph -Method GET -Resource "/servicePrincipals" -OdFilter "appId eq '$ClientId'" -ErrorAction Stop

# Check if the application is visible
$body = @{}
if ($isApplicationVisible -and ($existingSvcPrincipal.tags -contains "HideApp")) {
    "## Making the application visible"
    $body["tags"] = [array]($existingSvcPrincipal.tags -ne "HideApp")
}
if (-not $isApplicationVisible -and ($existingSvcPrincipal.tags -notcontains "HideApp")) {
    "## Hiding the application"
    $body["tags"] = [array]($existingSvcPrincipal.tags + @("HideApp"))
}
if ($body.count -gt 0) {

    Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($existingSvcPrincipal.id)" -Method PATCH -Body $body | Out-Null
    "## Service Principal updated."
    "## Waiting 20 seconds for changes to propagate."
    Start-Sleep -Seconds 20
}

