<#
    .SYNOPSIS
    Create an application registration in Entra ID

    .DESCRIPTION
    Creates a new application registration in Entra ID. Optionally it also configures redirect URIs for web, SPA or public clients, SAML sign-in, visibility in My Apps, user assignment with an access group, and implicit grant. Duplicate names are refused and the inputs are checked before anything is created.

    .PARAMETER ApplicationName
    Display name of the new application registration.

    .PARAMETER RedirectURI
    Type of sign-in to set up: none, a web redirect URI, SAML, a public client (mobile and desktop) or a single-page application. The matching fields appear once you choose.

    .PARAMETER signInAudience
    Who may sign in to the application. Preset to accounts in this tenant only (AzureADMyOrg).

    .PARAMETER webRedirectURI
    Redirect URI of a web application, for example https://myapp.com/auth. Separate several with semicolons.

    .PARAMETER spaRedirectURI
    Redirect URI of a single-page application, for example https://myapp.com. Separate several with semicolons.

    .PARAMETER publicClientRedirectURI
    Redirect URI of a mobile or desktop client, for example myapp://auth. Separate several with semicolons.

    .PARAMETER EnableSAML
    Whether SAML sign-in is configured. Set by the "Redirect URI" choice.

    .PARAMETER SAMLReplyURL
    Where the SAML response is sent (assertion consumer service URL).

    .PARAMETER SAMLSignOnURL
    URL where users start the sign-in to the application.

    .PARAMETER SAMLLogoutURL
    URL the application uses to sign users out.

    .PARAMETER SAMLIdentifier
    Identifier of the application in SAML (entity ID). Leave empty to use urn:app: followed by the client ID.

    .PARAMETER SAMLRelayState
    Value the application receives back after sign-in, for example to return to a page.

    .PARAMETER SAMLExpiryNotificationEmail
    Email address that is notified before the SAML signing certificate expires.

    .PARAMETER SAMLCertificateLifeYears
    How many years the SAML signing certificate stays valid.

    .PARAMETER isApplicationVisible
    Lists the application in the users' My Apps portal.

    .PARAMETER UserAssignmentRequired
    Only assigned users can use the application. An access group is created for the assignment.

    .PARAMETER groupAssignmentPrefix
    Text put in front of the access group name. Only used when user assignment is required.

    .PARAMETER implicitGrantAccessTokens
    Lets the application receive access tokens through the implicit flow. Needed only for older single-page apps.

    .PARAMETER implicitGrantIDTokens
    Lets the application receive ID tokens through the implicit flow.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
    "Parameters": {
        "SAMLReplyURL": {
            "DisplayName": "SAML reply URL"
        },
        "SAMLSignOnURL": {
            "DisplayName": "SAML sign-on URL"
        },
        "SAMLLogoutURL": {
            "DisplayName": "SAML logout URL"
        },
        "SAMLIdentifier": {
            "DisplayName": "SAML identifier (entity ID)"
        },
        "SAMLRelayState": {
            "DisplayName": "SAML relay state"
        },
        "SAMLExpiryNotificationEmail": {
            "DisplayName": "Certificate expiry notification email"
        },
        "SAMLCertificateLifeYears": {
            "DisplayName": "Certificate lifetime (years)"
        },
        "signInAudience": {
            "Hide": true
        },
        "CallerName": {
            "Hide": true
        },
        "ApplicationName": {
            "DisplayName": "Application name",
            "Hide": false
        },
        "RedirectURI": {
            "DisplayName": "Sign-in type",
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
            "DisplayName": "Web redirect URI",
            "Hide": false
        },
        "publicClientRedirectURI": {
            "DisplayName": "Public client redirect URI",
            "Hide": false
        },
        "spaRedirectURI": {
            "DisplayName": "SPA redirect URI",
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
            "DisplayName": "Show in My Apps?",
            "Hide": false
        },
        "UserAssignmentRequired":{
            "DisplayName": "Require user assignment?",
            "Hide": false
        },
        "groupAssignmentPrefix":{
            "DisplayName": "Access group prefix",
            "Hide": false
        },
        "implicitGrantAccessTokens":{
            "DisplayName": "Implicit grant for access tokens?",
            "Hide": false
        },
        "implicitGrantIDTokens":{
            "DisplayName": "Implicit grant for ID tokens?",
            "Hide": false
        }
    }
}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

# Suppress false positive from PSScriptAnalyzer - $resultGroupAppRole captures API result for side effect only
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "resultGroupAppRole")]
# Suppress false positive from PSScriptAnalyzer - $parsedUri is used for URI validation only, the constructor throws on invalid input
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "parsedUri")]
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

############################################################
#region RJ Log Part
#
############################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "ApplicationName: $ApplicationName" -Verbose
Write-RjRbLog -Message "RedirectURI: $RedirectURI" -Verbose
Write-RjRbLog -Message "signInAudience: $signInAudience" -Verbose
Write-RjRbLog -Message "webRedirectURI: $webRedirectURI" -Verbose
Write-RjRbLog -Message "spaRedirectURI: $spaRedirectURI" -Verbose
Write-RjRbLog -Message "publicClientRedirectURI: $publicClientRedirectURI" -Verbose
Write-RjRbLog -Message "EnableSAML: $EnableSAML" -Verbose
Write-RjRbLog -Message "SAMLReplyURL: $SAMLReplyURL" -Verbose
Write-RjRbLog -Message "SAMLSignOnURL: $SAMLSignOnURL" -Verbose
Write-RjRbLog -Message "SAMLLogoutURL: $SAMLLogoutURL" -Verbose
Write-RjRbLog -Message "SAMLIdentifier: $SAMLIdentifier" -Verbose
Write-RjRbLog -Message "SAMLRelayState: $SAMLRelayState" -Verbose
Write-RjRbLog -Message "SAMLExpiryNotificationEmail: $SAMLExpiryNotificationEmail" -Verbose
Write-RjRbLog -Message "SAMLCertificateLifeYears: $SAMLCertificateLifeYears" -Verbose
Write-RjRbLog -Message "isApplicationVisible: $isApplicationVisible" -Verbose
Write-RjRbLog -Message "UserAssignmentRequired: $UserAssignmentRequired" -Verbose
Write-RjRbLog -Message "groupAssignmentPrefix: $groupAssignmentPrefix" -Verbose
Write-RjRbLog -Message "implicitGrantAccessTokens: $implicitGrantAccessTokens" -Verbose
Write-RjRbLog -Message "implicitGrantIDTokens: $implicitGrantIDTokens" -Verbose

#endregion RJ Log Part

############################################################
#region Connect Part
#
############################################################

Write-Output "Connecting to Microsoft Graph..."
Connect-RjRbGraph

#endregion Connect Part

############################################################
#region StatusQuo & Preflight-Check Part
#
############################################################

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# If webRedirectURI is provided, verify if it is a valid (Must start with "HTTPS" or "http://localhost". Must be a valid URL)
$parsedUri = $null
if ($webRedirectURI) {
    $webRedirectURIs = $webRedirectURI.Split(";").Trim()
    foreach ($uri in $webRedirectURIs) {
        if (-not ($uri -match "^(https:\/\/|http:\/\/localhost)")) {
            "## Web Redirect URI '$($uri)' is invalid. It must start with 'https://' or 'http://localhost'."
            "## Stopping"
            throw ("Invalid Web Redirect URI")
        }
        try {
            # Validate URI syntax - parsing will fail for malformed URIs
            $parsedUri = [System.Uri]::new($uri)
        }
        catch {
            "## Web Redirect URI '$($uri)' is not a valid URL."
            "## Stopping"
            throw ("Invalid Web Redirect URI")
        }
    }
}

# If spaRedirectURI is provided, verify if it is a valid (Must start with "HTTPS" or "http://localhost". Must be a valid URL)
$parsedUri = $null
if ($spaRedirectURI) {
    $spaRedirectURIs = $spaRedirectURI.Split(";").Trim()
    foreach ($uri in $spaRedirectURIs) {
        if (-not ($uri -match "^(https:\/\/|http:\/\/localhost)")) {
            "## SPA Redirect URI '$($uri)' is invalid. It must start with 'https://' or 'http://localhost'."
            "## Stopping"
            throw ("Invalid SPA Redirect URI")
        }
        try {
            # Validate URI syntax - parsing will fail for malformed URIs
            $parsedUri = [System.Uri]::new($uri)
        }
        catch {
            "## SPA Redirect URI '$($uri)' is not a valid URL."
            "## Stopping"
            throw ("Invalid SPA Redirect URI")
        }
    }
}

# If publicClientRedirectURI is provided, verify if it is a valid (Must start with "HTTPS", "http://" or a custom scheme. Must be a valid URI)
$parsedUri = $null
if ($publicClientRedirectURI) {
    $publicClientRedirectURIs = $publicClientRedirectURI.Split(";").Trim()
    foreach ($uri in $publicClientRedirectURIs) {
        if (-not ($uri -match "^(https:\/\/|http:\/\/|[\w\-]+:\/\/)")) {
            "## Public Client Redirect URI '$($uri)' is invalid. It must start with 'https://', 'http://', or a custom scheme (e.g., 'myapp://')."
            "## Stopping"
            throw ("Invalid Public Client Redirect URI")
        }
        try {
            # Validate URI syntax - parsing will fail for malformed URIs
            $parsedUri = [System.Uri]::new($uri)
        }
        catch {
            "## Public Client Redirect URI '$($uri)' is not a valid URI."
            "## Stopping"
            throw ("Invalid Public Client Redirect URI")
        }
    }
}

$ApplicationFullName = $ApplicationName

# Check if an application with the same name already exists
try {
    Write-Output "Checking if application '$ApplicationFullName' already exists..."
    $existingApp = Invoke-RjRbRestMethodGraph -Method GET -Resource "/applications" -OdFilter "displayName eq '$ApplicationFullName'" -ErrorAction Stop

    if ($existingApp) {
        "## Application '$ApplicationFullName' already exists, id: $($existingApp.id)"
        "## Stopping"
        throw ("Application already exists")
    }
    Write-Output "No existing application found with this name."
}
catch {
    if ($_.Exception.Message -like "*Application already exists*") {
        throw
    }
    Write-Error "Failed to check for existing applications: $_"
    throw
}

#endregion StatusQuo & Preflight-Check Part

############################################################
#region Main Part
#
############################################################

    #region Prepare Application Registration
    ##############################

Write-Output ""
Write-Output "Preparing application registration..."
Write-Output "---------------------"

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

    #endregion Prepare Application Registration

    #region Configure Redirect URIs
    ##############################

Write-Output "Configuring redirect URIs..."

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

# Validate SAML configuration if SAML is enabled
if ($EnableSAML) {
    if ($SAMLReplyURL) {
        $webRedirectURIs = @($SAMLReplyURL)
    }
    elseif ($webRedirectURIs.count -eq 0) {
        "## Web redirect URI / SAML Reply URL must be specified for SAML applications."
        "## Stopping"
        throw ("Web redirect URI must be specified for SAML applications")
    }
}

$body["web"] = @{}

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

    #endregion Configure Redirect URIs

    #region Add Default Permissions
    ##############################

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

try {
    $tenantId = (Invoke-RjRbRestMethodGraph -Resource "/organization").id
}
catch {
    $tenantId = "Could not be determined"
}

    #endregion Add Default Permissions

    #region Create Application
    ##############################

Write-Output ""
Write-Output "Creating application registration..."
Write-Output "---------------------"

try {
    $resultApp = Invoke-RjRbRestMethodGraph -Resource "/applications" -Method POST -Body $body
    ""
    "## Application '$($ApplicationFullName)' created, AppId: $($resultApp.appId), TenantId: $($tenantId)"
}
catch {
    Write-Error "Failed to create application '$($ApplicationFullName)': $_"
    throw
}

"## Wait for the application to be ready"
Start-Sleep -Seconds 20

    #endregion Create Application

    #region Create Service Principal
    ##############################

Write-Output ""
Write-Output "Creating service principal..."
Write-Output "---------------------"

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


try {
    $resultSvcPrincipal = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals" -Method POST -Body $body
    "## Service Principal for '$($ApplicationFullName)' created, id: $($resultSvcPrincipal.id)"
}
catch {
    Write-Error "Failed to create Service Principal for '$($ApplicationFullName)': $_"
    throw
}

"## Wait for the Service Principal to be ready"
Start-Sleep -Seconds 20

    #endregion Create Service Principal

    #region Configure SAML Settings
    ##############################

if ($EnableSAML) {
    Write-Output ""
    Write-Output "Configuring SAML settings..."
    Write-Output "---------------------"

    if (-not $SAMLIdentifier) {
        $SAMLIdentifier = "urn:app:$($resultApp.appId)"
    }
    else {
        $SAMLIdentifier = $SAMLIdentifier.trim().trimend('/')
    }

    "## Update the application object with the SAML2 settings"
    try {
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
        Invoke-RjRbRestMethodGraph -Resource "/applications/$($resultApp.id)" -Method PATCH -Body $body -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to update application object with SAML2 settings: $_"
        throw
    }

    "## Wait for the application to be ready"
    Start-Sleep -Seconds 20

    "## Update the service principal object with the SAML2 settings"
    try {
        $body = @{}
        $body["servicePrincipalNames"] = @(
            $SAMLIdentifier,
            $resultApp.appId
        )

        Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)" -Method PATCH -Body $body -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to update service principal object with SAML2 settings: $_"
        throw
    }

    # Create a token signing certificate
    try {
        $certname = "CN=Microsoft Azure Federated SSO Certificate"
        $endDate = (Get-Date).AddYears($SAMLCertificateLifeYears).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $certBody = @{
            "displayName" = $certname
            "endDateTime" = $endDate
        }
        $certResult = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)/addTokenSigningCertificate" -Method POST -Body $certBody -ErrorAction Stop
        "## Token signing certificate created."
        ""
        "## DEBUG - Print the certificate (public key))"
        $certResult | Format-List | Out-String
        ""
    }
    catch {
        Write-Error "Failed to create token signing certificate: $_"
        throw
    }

    if ($SAMLExpiryNotificationEmail) {
        try {
            "## Update the certificate expiry notification email to '$SAMLExpiryNotificationEmail'"
            $body = @{
                "notificationEmailAddresses" = @(
                    $SAMLExpiryNotificationEmail
                )
            }
            Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)" -Method PATCH -Body $body -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Failed to update certificate expiry notification email: $_"
            throw
        }
    }
}

    #endregion Configure SAML Settings

    #region Create User Assignment Group
    ##############################

if ($UserAssignmentRequired) {
    Write-Output ""
    Write-Output "Creating user assignment group..."
    Write-Output "---------------------"

    [string]$shortAppName = $ApplicationFullName -replace " \| ", "-" -replace "\|", "-" # -replace " ", "-" -replace "[()]", ""

    [string]$mailnickname = $ApplicationName -replace " \| ", "-" -replace "\|", "-" -replace " ", "-" -replace "[()]", ""
    if ($mailnickname.Length -gt 25) {
        $mailnickname = $mailnickname.Substring(0, 24)
    }
    # Create an EntraID group for the application
    try {
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
        $resultGroup = Invoke-RjRbRestMethodGraph -Resource "/groups" -Method POST -Body $groupBody -ErrorAction Stop
        "## Group '$($resultGroup.displayName)' created, id: $($resultGroup.id)"
    }
    catch {
        Write-Error "Failed to create EntraID group for application: $_"
        throw
    }

    # Add the group to the application
    try {
        $groupAppRoleBody = @{
            "appRoleId"   = "00000000-0000-0000-0000-000000000000"
            "principalId" = $resultGroup.id
            "resourceId"  = $resultSvcPrincipal.id
        }
        $resultGroupAppRole = Invoke-RjRbRestMethodGraph -Resource "/servicePrincipals/$($resultSvcPrincipal.id)/appRoleAssignedTo" -Method POST -Body $groupAppRoleBody -ErrorAction Stop | Out-Null
        "## Group '$($resultGroup.displayName)' added to application '$ApplicationFullName'"
    }
    catch {
        Write-Error "Failed to assign group '$($resultGroup.displayName)' to application: $_"
        throw
    }
}

    #endregion Create User Assignment Group

#endregion Main Part

Write-Output ""
Write-Output "## Application registration successfully created."
Write-Output ""
Write-Output "Done!"
