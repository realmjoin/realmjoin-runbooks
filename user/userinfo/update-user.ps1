# This runbook will update fields of an existing user object.

#Requires -Module RealmJoin.RunbookHelper, AzureAD

param (
    [Parameter(Mandatory = $true)]
    [string]$UserName,
    [string]$givenName,
    [string]$surname,
    [string]$displayName,
    [string]$companyName,
    [string]$city,
    [string]$country,
    [string]$jobTitle,
    # think "physicalDeliveryOfficeName" if you are coming from on-prem
    [string]$officeLocation,
    [ValidateScript( { Use-RJInterface -Type Number } )]
    [string]$postalCode,
    [string]$preferredLanguage,
    [string]$state,
    [string]$streetAddress,
    [string]$usageLocation

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

if (-not $targetUser.DisplayName -and -not $displayName) {
    $resultingGivenName = ($givenName, $targetUser.GivenName -ne "" -ne $null)[0]
    $resultingSurname = ($surname, $targetUser.Surname  -ne "" -ne $null)[0]
    if ($resultingGivenName -and $resultingSurname) {
        $userArgs['displayName'] = "$resultingGivenName $resultingSurname"
    }
    else {
        $userArgs['displayName'] = $targetUser.MailNickName
    }
}
if (-not $targetUser.CompanyName -and -not $companyName) {
    $userArgs['companyName'] = (Get-RjRbAzureADTenantDetail).DisplayName
}

Write-RjRbLog "Updating user object with the following properties" $userArgs
Set-AzureADUser -ObjectId $targetUser.ObjectId @userArgs


Write-Output "User '$UserName' successfully updated."
