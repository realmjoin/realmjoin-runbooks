<#

.SYNOPSIS
    Add an application registration to Azure AD

.DESCRIPTION
    This script creates a new application registration in Azure Active Directory (Entra ID) with comprehensive configuration options.
    
    The script validates input parameters, prevents duplicate application creation, and provides comprehensive logging
    throughout the process. For SAML applications, it automatically configures reply URLs, sign-on URLs, logout URLs,
    and certificate expiry notifications.

.INPUTS
    RunbookCustomization: {
    "Parameters": {
        "signInAudience": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        },
        "ApplicationName": {
            "DisplayName": "Application Name",
            "Hide": false
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
                                "SAMLExpiryNotificationEmail",
                                "SAMLCertificateLifeYears"
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
                                    "SAMLExpiryNotificationEmail",
                                    "SAMLCertificateLifeYears"
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
                                    "SAMLExpiryNotificationEmail",
                                    "SAMLCertificateLifeYears"
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
                                    "SAMLExpiryNotificationEmail",
                                    "SAMLCertificateLifeYears"
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
        "SAMLCertificateLifeYears":{
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }

param(
    [Parameter(Mandatory = $true)]
    [string] $ApplicationName,
    [string] $RedirectURI, # Only for UI used
    [string] $signInAudience = "AzureADMyOrg",
    [string] $webRedirectURI = "",
    [string] $spaRedirectURI = "",
    [string] $publicClientRedirectURI = "",
    [bool] $EnableSAML = $false,
    [String] $SAMLReplyURL = "",
    [String] $SAMLSignOnURL = "",
    [String] $SAMLLogoutURL = "",
    [String] $SAMLIdentifier = "",
    [String] $SAMLRelayState = "",
    [String] $SAMLExpiryNotificationEmail = "",
    [int] $SAMLCertificateLifeYears = 3,
    [bool] $isApplicationVisible = $true,
    [bool] $UserAssignmentRequired = $false,
    [String] $groupAssignmentPrefix = "col - Entra - users - ",
    [bool] $implicitGrantAccessTokens = $false,
    [bool] $implicitGrantIDTokens = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

$ApplicationFullName = $ApplicationName

# Check if an application with the same name already exists
$existingApp = Invoke-RjRbRestMethodGraph -Method GET -Resource "/applications" -OdFilter "displayName eq '$ApplicationFullName'" -errorAction SilentlyContinue

if ($existingApp) {
    "## Application '$ApplicationFullName' already exists, id: $($existingApp.id)"
    "## Stopping"
    throw ("Application already exists")
}

$body = @{
    "displayName"    = $ApplicationFullName
    "signInAudience" = $signInAudience
    "tags"           = @(
        "WindowsAzureActiveDirectoryIntegratedApp"
    )
}

if ($isApplicationVisible -eq $false) {
    $body["tags"] += "HideApp"
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

$body[“web"] = @{}

# Set the redirect URIs if Web redirect URIs are specified
$redirects = @()
if ($webRedirectURIs.count -gt 0) {
    $redirects = @($webRedirectURIs)
    if ($EnableSAML -and $SAMLReplyURL -and ($redirects -notcontains $SAMLReplyURL)) {
        $redirects += $SAMLReplyURL
    }
    $body["web"]["redirectUris"] = $redirects
}

$body["web"]["implicitGrantSettings"] = @{
    "enableAccessTokenIssuance" = $implicitGrantAccessTokens
    "enableIdTokenIssuance"     = $implicitGrantIDTokens
}

if ($spaRedirectURIs.Count -gt 0) {
    $body["spa"] = @{
        redirectUris = $spaRedirectURIs
    }
}

if ($publicClientRedirectURIs.Count -gt 0) {
    $body["publicClient"] = @{
        redirectUris = $publicClientRedirectURIs
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

# Add default permissions
$body["requiredResourceAccess"] = @(
    @{
        "resourceAppId"  = "00000003-0000-0000-c000-000000000000"
        "resourceAccess" = @(
            @{
                "id"   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
                "type" = "Scope"
            }
            @{
                "id"   = "37f7f235-527c-4136-accd-4a02d197296e"
                "type" = "Scope"
            }
            @{
                "id"   = "14dad69e-099b-42c9-810b-d002981feec1"
                "type" = "Scope"
            }
            @{
                "id"   = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"
                "type" = "Scope"
            }
        )
    }
)

$tenantId = (invoke-RjRbRestMethodGraph -Resource "/organization").id

$resultApp = Invoke-RjRbRestMethodGraph -Resource "/applications" -Method POST -Body $body
""
"## Application '$ApplicationFullName' created, AppId: $($resultApp.appId), TenantId: $tenantId"

"## Wait for the application to be ready"
Start-Sleep -Seconds 20

$body = @{
    "appId" = $resultApp.appId
}

if ($EnableSAML) {
    $body["preferredSingleSignOnMode"] = "saml"
    
    $body["samlSingleSignOnSettings"] = @{
        "relayState" = $SAMLRelayState
    }

    #$body["replyUrls"] = @(
    #    $SAMLReplyURL
    #)
    if ($SAMLSignOnURL) { 
        $body["loginUrl"] = $SAMLSignOnURL 
    }
}

if ($UserAssignmentRequired) {
    $body["appRoleAssignmentRequired"] = $true
}


$resultSvcPrincipal = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -Method POST -Body $body
"## Service Principal for '$ApplicationFullName' created, id: $($resultSvcPrincipal.id)"

"## Wait for the Service Principal to be ready"
Start-Sleep -Seconds 20

if ($EnableSAML) {
    if (-not $SAMLIdentifier) {
        $SAMLIdentifier = "urn:app:$($resultApp.appId)"
    }
    else {
        $SAMLIdentifier = $SAMLIdentifier.trim().trimend('/')
    }

    "## Update the application object with the SAML2 settings"
    $body = @{
        "tags" = $resultApp.tags
    }
    $body["tags"] += "WindowsAzureActiveDirectoryCustomSingleSignOnApplication"
    $body["identifierUris"] = @(
        $SAMLIdentifier
    )
    if ($SAMLLogoutURL) {
        $body["web"] = @{
            "logoutUrl" = $SAMLLogoutURL
        } 
    }
    Invoke-RjRbRestMethodGraph -Resource "/applications/$($resultApp.id)" -Method PATCH -Body $body | Out-Null

    "## Wait for the application to be ready"
    Start-Sleep -Seconds 20

    "## Update the service principal object with the SAML2 settings"
    $body = @{}
    $body["servicePrincipalNames"] = @(
        $SAMLIdentifier,
        $resultApp.appId
    )

    Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)" -Method PATCH -Body $body | Out-Null

    # Create a token signing certificate
    $certname = "CN=Microsoft Azure Federated SSO Certificate"
    $endDate = (Get-Date).AddYears($SAMLCertificateLifeYears).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $certBody = @{
        "displayName" = $certname
        "endDateTime" = $endDate
    }
    $certResult = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)/addTokenSigningCertificate" -Method POST -Body $certBody
    "## Token signing certificate created."
    ""
    "## DEBUG - Print the certificate (public key))"
    $certResult | Format-List | Out-String
    ""

    if ($SAMLExpiryNotificationEmail) {
        "## Update the certificate expiry notification email to '$SAMLExpiryNotificationEmail'"
        $body = @{
            "notificationEmailAddresses" = @(
                $SAMLExpiryNotificationEmail
            )
        }
        Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)" -Method PATCH -Body $body | Out-Null
    }
}

[string]$shortAppName = $ApplicationFullName -replace " \| ", "-" -replace "\|", "-" # -replace " ", "-" -replace "[()]", ""

[string]$mailnickname = $ApplicationName -replace " \| ", "-" -replace "\|", "-" -replace " ", "-" -replace "[()]", ""
if ($mailnickname.Length -gt 25) {
    $mailnickname = $mailnickname.Substring(0, 24)
}

if ($UserAssignmentRequired) {
    # Create an EntraID group for the application
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


"## Application registration successfully created."
