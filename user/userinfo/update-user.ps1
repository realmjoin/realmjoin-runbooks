<#
  .SYNOPSIS
  Update the metadata of an existing user object.

  .DESCRIPTION
  Update the metadata of an existing user object.

  .PARAMETER PreferredLanguage
  Examples: 'en-US' or 'de-DE'

  .PARAMETER UsageLocation
  Examples: "DE" or "US"

  .NOTES
  Permissions
  AzureAD Roles
  - User administrator

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
             "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [string]$UserName,
    [string]$GivenName,
    [string]$Surname,
    [ValidateScript( { Use-RJInterface -DisplayName "DisplayName" } )]
    [string]$DisplayName,
    [string]$CompanyName,
    [string]$City,
    [string]$Country,
    [string]$JobTitle,
    # think "physicalDeliveryOfficeName" if you are coming from on-prem
    [string]$OfficeLocation,
    [ValidateScript( { Use-RJInterface -Type Number } )]
    [string]$PostalCode,
    [string]$PreferredLanguage,
    [string]$State,
    [string]$StreetAddress,
    [string]$UsageLocation,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

"## Updating metadate of user '$UserName'."

Connect-RjRbGraph

Write-RjRbLog "Searching for user '$UserName'"
$targetUser = Invoke-RjRbRestMethodGraph -resource "/users/$UserName"

$userArgs = @{}
function addToUserArgs($variableName, $paramName = $variableName) {
    $paramValue = Get-Variable $variableName -ValueOnly -EA 0
    if ($paramValue) {
        $userArgs[$paramName] = $paramValue
    }
}
addToUserArgs 'givenName'
addToUserArgs 'surname'
addToUserArgs 'displayName'
addToUserArgs 'companyName'
addToUserArgs 'city'
addToUserArgs 'country'
addToUserArgs 'jobTitle'
addToUserArgs 'officeLocation'
addToUserArgs 'postalCode'
addToUserArgs 'preferredLanguage'
addToUserArgs 'state'
addToUserArgs 'streetAddress'
addToUserArgs 'usageLocation'

if (-not $targetUser.DisplayName -and -not $DisplayName) {
    $resultingGivenName = ($GivenName, $targetUser.GivenName -ne "" -ne $null)[0]
    $resultingSurname = ($Surname, $targetUser.Surname  -ne "" -ne $null)[0]
    if ($resultingGivenName -and $resultingSurname) {
        $userArgs['displayName'] = "$resultingGivenName $resultingSurname"
    }
    else {
        $userArgs['displayName'] = $targetUser.MailNickName
    }
}
if (-not $targetUser.CompanyName -and -not $CompanyName) {
    $tenantDetail = Invoke-RjRbRestMethodGraph -Resource "/organization"
    $userArgs['companyName'] = $tenantDetail.displayName
}

Write-RjRbLog "Updating user object with the following properties" $userArgs
Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Patch -Body $userArgs

"## User '$UserName' successfully updated."