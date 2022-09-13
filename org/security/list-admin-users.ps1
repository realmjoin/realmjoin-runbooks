<#
  .SYNOPSIS
  List AzureAD role holders and their MFA state.

  .DESCRIPTION
  Will list users and service principals that hold a builtin AzureAD role. 
  Admins will be queried for valid MFA methods.

  .NOTES
  Permissions: MS Graph
  - User.Read.All
  - Directory.Read.All
  - RoleManagement.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Regard eMail as a valid MFA Method" } )]
    [bool]$TrustEmailMfa = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Regard Phone/SMS as a valid MFA Method" } )]
    [bool]$TrustPhoneMfa = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Regard Software OATH Token as a valid MFA Method" } )]
    [bool]$TrustSoftwareOathMfa = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Regard Win. Hello f.B. as a valid MFA Method" } )]
    [bool]$TrustWinHelloMFA = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Connect-RjRbGraph

## Get builtin AzureAD Roles
$roles = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleDefinitions" -OdFilter "isBuiltIn eq true"

if ([array]$roles.count -eq 0) {
    "## Error - No AzureAD roles found. Missing permissions?"
    throw("no roles found")
}

## Performance issue - Get all PIM role assignments at once
$allPimHolders = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleEligibilitySchedules" -Beta -ErrorAction SilentlyContinue

$AdminUsers = @()

$roles | ForEach-Object {
    $roleDefinitionId = $_.id
    $pimHolders = $allPimHolders | Where-Object { $_.roleDefinitionId -eq $roleDefinitionId }
    $roleHolders = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleAssignments" -OdFilter "roleDefinitionId eq '$roleDefinitionId'" -ErrorAction SilentlyContinue

    if ((([array]$roleHolders).count -gt 0) -or (([array]$pimHolders).count -gt 0)) {
        "## Role: $($_.displayName)"
        "## - Active Assignments"

        $roleHolders | ForEach-Object {
            $principal = Invoke-RjRbRestMethodGraph -Resource "/directoryObjects/$($_.principalId)" -ErrorAction SilentlyContinue
            if (-not $principal) {
                "  $($_.principalId) (Unknown principal)"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)"
                    if (-not $AdminUsers.Contains($principal.userPrincipalName)) {
                        $AdminUsers += $principal.userPrincipalName
                    }
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "  $($principal.displayName) (ServicePrincipal)"
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.group") {
                    "  $($principal.displayName) (Group)"
                }
                else {
                    "  $($principal.displayName) $($principal."@odata.type")"
                }
            }
        }

        "## - PIM eligbile"

        $pimHolders | ForEach-Object {
            $principal = Invoke-RjRbRestMethodGraph -Resource "/directoryObjects/$($_.principalId)" -ErrorAction SilentlyContinue
            if (-not $principal) {
                "  $($_.principalId) (Unknown principal)"
            }
            else {
                if ($principal."@odata.type" -eq "#microsoft.graph.user") {
                    "  $($principal.userPrincipalName)"
                    if (-not $AdminUsers.Contains($principal.userPrincipalName)) {
                        $AdminUsers += $principal.userPrincipalName
                    }
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.servicePrincipal") {
                    "  $($principal.displayName) (ServicePrincipal)"
                }
                elseif ($principal."@odata.type" -eq "#microsoft.graph.group") {
                    "  $($principal.displayName) (Group)"
                }
                else {
                    "  $($principal.displayName) $($principal."@odata.type")"
                }
            }
        }


        ""
    }

}

""
"## MFA State of each Admin:"
$NoMFAAdmins = @()
$AdminUsers | Sort-Object -Unique | ForEach-Object {
    $AdminUPN = $_
    $AuthenticationMethods = @()
    [array]$MFAData = Invoke-RjRbRestMethodGraph -Resource "/users/$AdminUPN/authentication/methods"
    foreach ($MFA in $MFAData) { 
        Switch ($MFA."@odata.type") { 
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
  

