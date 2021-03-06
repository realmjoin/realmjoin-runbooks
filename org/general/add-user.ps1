<#
  .SYNOPSIS
  Create a new user account.

  .DESCRIPTION
  Create a new user account. 

  .PARAMETER DefaultGroups
  Comma separated list of groups to assign. e.g. "DL Sales,LIC Internal Product"

  .PARAMETER InitialPassword
  Password will be autogenerated if left empty

  .NOTES
  Permissions
  AzureAD Roles
  - User administrator

  .EXAMPLE
  Full Runbook Customizations Example
    {
        "Templates": {
            "Options": [
                {
                    "$id": "LocationOptions",
                    "$values": [
                        {
                            "Display": "DE-OF",
                            "Customization": {
                                "Default": {
                                    "StreetAddress": "Kaiserstraße 39",
                                    "PostalCode": "63065",
                                    "City": "Offenbach",
                                    "Country": "Germany"
                                }
                            }
                        },
                        {
                            "Display": "DE-DEG",
                            "Customization": {
                                "Default": {
                                    "StreetAddress": "Lateinschulgassse 24-26",
                                    "PostalCode": "94469",
                                    "City": "Deggendorf",
                                    "Country": "Germany"
                                }
                            }
                        },
                        {
                            "Display": "DE-HH",
                            "Customization": {
                                "Default": {
                                    "StreetAddress": "Hans-Henny-Jahnn-Weg 53",
                                    "PostalCode": "22085",
                                    "City": "Hamburg",
                                    "Country": "Germany"
                                }
                            }
                        },
                        {
                            "Display": "FI-HS",
                            "Customization": {
                                "Default": {
                                    "StreetAddress": "Somewhere 42",
                                    "PostalCode": "12345",
                                    "City": "Helsinki",
                                    "Country": "Finland"
                                }
                            }
                        }
                    ]
                },
                {
                    "$id": "CompanyOptions",
                    "$values": [
                        {
                            "Id": "gkg",
                            "Display": "glueckkanja-gab",
                            "Value": "glueckkanja-gab AG"
                        },
                        {
                            "Id": "pp",
                            "Display": "PrimePulse",
                            "Value": "PrimePulse AG"
                        }
                    ]
                }
            ]
        },
        "Runbooks": {
            "rjgit-org_general_add-user": {
                "ParameterList": [
                    {
                        "DisplayName": "Office Location",
                        "DisplayAfter": "CompanyName",
                        "Select": {
                            "Options": {
                                "$ref": "LocationOptions"
                            }
                        }
                    },
                    {
                        "Name": "CompanyName",
                        "Select": {
                            "Options": {
                                "$ref": "CompanyOptions"
                            },
                            "AllowEdit": false
                        }
                    }
                ],
                "ReadOnly": [
                    "StreetAddress",
                    "PostalCode",
                    "City",
                    "Country"
                ]
            }
        }
    }

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserPrincipalName": {
                 "Hide": true
            },
            "MailNickname": {
                 "Hide": true
            },
            "DisplayName": {
                 "Hide": true
            }
        }
    }

#>

#Requires -Modules AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.2" }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
param (
    [Parameter(Mandatory = $true)]
    [string]$GivenName = "",
    [Parameter(Mandatory = $true)]
    [string]$Surname = "",
    [string]$UserPrincipalName,
    [string]$MailNickname = "",
    [string]$DisplayName = "",
    [string]$CompanyName = "",
    [string]$JobTitle = "",
    [string]$Department = "",
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Manager" } )]
    [string]$ManagerId = "",
    [string]$MobilePhone = "",
    [string]$LocationName = "",
    [string]$StreetAddress,
    [string]$PostalCode,
    [string]$City,
    [string]$State,
    [string]$Country,
    [string]$UsageLocation,
    [string]$DefaultLicense = "LIC_M365_E5",
    [string]$DefaultGroups = "",
    [String]$InitialPassword = ""
)

Connect-RjRbAzureAD

# AzureAD Module is broken in regards to ErrorAction, so...
$ErrorActionPreference = "SilentlyContinue"

#"Generating random initial PW."
if ($InitialPassword -eq "") {
    $InitialPassword = ("Start" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
}

#"Choosing UPN, if not given"
if ($UserPrincipalName -eq "") {
    $tenantDetail = Get-AzureADTenantDetail
    $UPNSuffix = ($tenantDetail.VerifiedDomains | Where-Object { $_._Default }).Name
    if ($MailNickname -ne "") {
        # Try to base it on mailnickname...
        $UserPrincipalName = ($MailNickname + "@" + $UPNSuffix).ToLower()
    }
    elseif (($GivenName -ne "") -and ($Surname -ne "")) {
        # Try to create it from the real name...
        $UserPrincipalName = ($GivenName + "." + $Surname + "@" + $UPNSuffix).ToLower()
    }
    else {
        throw "Please provide a userPrincipalName"
    }
    #"Setting userPrincipalName to `"$UserPrincipalName`"."
}

#"Check if the username $UserPrincipalName is available" 
$targetUser = Get-AzureADUser -ObjectId $UserPrincipalName 
if ($null -ne $targetUser) {
    throw ("Username $UserPrincipalName is already taken.")
}

# Prefereably contruct the displayName from the real names...
if (($DisplayName -eq "") -and ($GivenName -ne "") -and ($Surname -ne "")) {
    $DisplayName = "$GivenName $Surname"    
    #"Setting displayName to `"$DisplayName`"."
}

if ($MailNickname -eq "") {
    $MailNickname = $UserPrincipalName.Split('@')[0]
    #"Setting mailNickName `"$MailNickname`"."
}

# Ok, at least have some displayName...
if ($DisplayName -eq "") {
    $DisplayName = $MailNickname    
    #"Setting displayName to `"$MailNickname`"."
}

if ($CompanyName -eq "") {
    $CompanyName = (Get-AzureADTenantDetail).DisplayName
    #"Setting companyName to `"$CompanyName`"."
}


$newUserArgs = [ordered]@{
    UserPrincipalName = $UserPrincipalName
    MailNickName      = $MailNickname
    DisplayName       = $DisplayName
    AccountEnabled    = $true
    PasswordProfile   = [Microsoft.Open.AzureAD.Model.PasswordProfile]::new($initialPassword, $true <# ForceChangePasswordNextLogin #>)
}

if ($givenName) {
    $newUserArgs += @{ GivenName = $givenName }
}

if ($surname) {
    $newUserArgs += @{ Surname = $surname }
}

if ($CompanyName) {
    $newUserArgs += @{ CompanyName = $CompanyName }
}

if ($Department) {
    $newUserArgs += @{ Department = $Department }
}

if ($LocationName) {
    $newUserArgs += @{ PhysicalDeliveryOfficeName = $LocationName }
}

if ($Country) {
    $newUserArgs += @{ Country = $Country }
}

if ($State) {
    $newUserArgs += @{ State = $State }
}

if ($postalCode) {
    $newUserArgs += @{ PostalCode = $postalCode }
}

if ($city) {
    $newUserArgs += @{ City = $city }
}

if ($streetAddress) {
    $newUserArgs += @{ StreetAddress = $streetAddress }
}

if ($JobTitle) {
    $newUserArgs += @{ JobTitle = $JobTitle }
}

if ($MobilePhone) {
    $newUserArgs += @{ Mobile = $MobilePhone }
}

if ($UsageLocation) {
    $newUserArgs += @{ UsageLocation = $UsageLocation }
}

# $newUserArgs | Format-Table | Out-String

#"Creating user object for $UserPrincipalName"
$ErrorActionPreference = "Stop"
$userObject = New-AzureADUser @newUserArgs -ErrorAction Stop 
$ErrorActionPreference = "SilentlyContinue"


# Assign the default license. Continue even if this fails.
if ($DefaultLicense -ne "") {
    #"Searching license group $DefaultLicense."
    $group = Get-AzureADGroup -Filter "displayName eq `'$DefaultLicense`'" -ErrorAction SilentlyContinue
    if (-not $group) {
        "License group $DefaultLicense not found!"
        Write-Error "License group $DefaultLicense not found!"
    }
    else {
        #"Adding $UserPrincipalName to $($group.displayName)"
        Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $userObject.ObjectId | Out-Null
    }
}

# Assign the given groups. Continue even if this fails.
$groupsArray = $DefaultGroups.split(',').Trim()
foreach ($groupname in $groupsArray) {
    if ($groupname -ne "") {
        #"Searching default group $groupname."
        $group = Get-AzureADGroup -Filter "displayName eq `'$groupname`'" -ErrorAction SilentlyContinue
        if (-not $group) {
            "Group $groupname not found!" 
            Write-Error "Group $groupname not found!"
        }
        else {
            #"Adding $UserPrincipalName to $($group.displayName)"
            Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $userObject.ObjectId | Out-Null
        }
    }
}

# Assign Manager
if ($ManagerId) {
    $ErrorActionPreference = "Stop"
    Set-AzureADUserManager -ObjectId $userObject.ObjectId -RefObjectId $ManagerId | Out-Null
    $ErrorActionPreference = "SilentlyContinue"
}

Write-Output "User $UserPrincipalName successfully created. Initial PW: $InitialPassword"
# "Disconnecting from AzureAD."
Disconnect-AzureAD -confirm:$false | Out-Null

