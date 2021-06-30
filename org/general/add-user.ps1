# This runbook will create a new user account
#
# It will try to guess values if needed.

#Requires -Module AzureAD, RealmJoin.RunbookHelper

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
param (
    # Option - Use at least "givenName" and "surname" to create the user.
    [string]$givenName,
    [string]$surname,
    # Option - Use at least "userPrincipalName" to create the user.
    [string]$userPrincipalName,
    [string]$displayName,
    [string]$companyName,
    [string]$StreetAddress,
    [string]$PostalCode,
    [string]$City,
    # Option - Use at least the "mailNickName" to create the user.
    [string]$mailNickName,
    [string]$defaultLicense = "LIC_M365_E5",
    # Comma separated list of groups to add the user to
    [string]$defaultGroups,
    # Optional: Give an initial password. Otherwise, a random PW will be generated.
    [String]$initialPassword
)

$ErrorActionPreference = "Stop"

$aadTenantDetail = Connect-RjRbAzureAD -GetTenantDetail:((-not $userPrincipalName) -or (-not $companyName))
# -GetTenantDetail: eigene function

if (-not $userPrincipalName) {
    if ($mailNickName) {
        $userPrincipalName = "$mailNickName@$($aadTenantDetail.UpnSuffix)"
    }
    elseif ($givenName -and $surname) {
        $userPrincipalName = "$givenName.$surname@$($aadTenantDetail.UpnSuffix)"
    }
    else {
        throw "Please provide userPrincipalName, mailNickName or givenName and surname"
    }
}

"Check if the UPN $userPrincipalName is still available"
& {
    # HACK as Get-AzureADUser seems to ignore -ErrorAction (as of 2021-05)
    $ErrorActionPreference = "SilentlyContinue"
    if (Get-AzureADUser -ObjectId $userPrincipalName) {
        # HACK throw not working if EA is SilentlyContinue (as of 2021-05)
        $ErrorActionPreference = "Stop"
        throw "Username $userPrincipalName has already been taken"
    }
}

if (-not $mailNickName) {
    $mailNickName = $userPrincipalName.Split('@')[0]
}

if (-not $displayName) {
    if ($givenName -and $surname) {
        $displayName = "$givenName $surname"
    }
    else {
        $displayName = $mailNickName
    }
}

if (-not $companyName) {
    $companyName = $aadTenantDetail.DisplayName
}

if (-not $initialPassword) {
    $initialPassword = New-RjRbPassword
}

$newUserArgs = [ordered]@{
    UserPrincipalName = $userPrincipalName
    MailNickName      = $mailNickName
    DisplayName       = $displayName
    CompanyName       = $companyName
    AccountEnabled    = $true
    PasswordProfile   = [Microsoft.Open.AzureAD.Model.PasswordProfile]::new($initialPassword, $true <# ForceChangePasswordNextLogin #>)
}
if ($givenName) {
    $newUserArgs += @{ GivenName = $givenName }
}
if ($surname) {
    $newUserArgs += @{ Surname = $surname }
}

"Creating user object with the following properties"
$newUserArgs + @{InitialPassword = $initialPassword } | Out-String
$userObject = New-AzureADUser @newUserArgs

Add-RjRbAadGroupMember -UserObject $userObject -GroupName $defaultLicense -IgnoreNotFound

Add-RjRbAadGroupMember -UserObject $userObject -GroupName $defaultGroups.split(',') #-IgnoreNotFound

"User $userPrincipalName successfully created. Initial PW: $initialPassword"
