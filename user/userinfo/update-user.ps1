<#
  .SYNOPSIS
  Update the metadata of an existing user object.

  .DESCRIPTION
  Update the metadata of an existing user object.

  .PARAMETER PreferredLanguage
  Examples: 'en-US' or 'de-DE'

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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, AzureAD

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

Connect-RjRbAzureAD

Write-RjRbLog "Searching for user '$UserName'"
$targetUser = Get-AzureADUser -ObjectId $UserName

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
addToUserArgs 'officeLocation' 'PhysicalDeliveryOfficeName'
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
    $userArgs['companyName'] = (Get-RjRbAzureADTenantDetail).DisplayName
}

Write-RjRbLog "Updating user object with the following properties" $userArgs
Set-AzureADUser -ObjectId $targetUser.ObjectId @userArgs | Out-Null


"## User '$UserName' successfully updated."