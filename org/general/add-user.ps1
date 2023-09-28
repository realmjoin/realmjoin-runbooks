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
            },
            "CallerName": {
                "Hide": true
            },
            "DefaultLicense": {
                "DisplayName": "License group to assign"
            },
            "EnableEXOArchive": {
                "DisplayName": "Create Exchange Online Archive Mailbox"
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, ExchangeOnlineManagement

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
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Manager" -Filter "userType eq 'Member'" } )]
    [string]$ManagerId = "",
    [string]$MobilePhone = "",
    [string]$LocationName = "",
    [string]$StreetAddress,
    [string]$PostalCode,
    [string]$City,
    [string]$State,
    [string]$Country,
    [string]$UsageLocation,
    [string]$DefaultLicense = "",
    [string]$DefaultGroups = "",
    [String]$InitialPassword = "",
    [bool]$EnableEXOArchive = $false,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph
Connect-RjRbExchangeOnline

# AzureAD Module is broken in regards to ErrorAction, so...
$ErrorActionPreference = "SilentlyContinue"

#"Generating random initial PW."
if ($InitialPassword -eq "") {
    $InitialPassword = ("Start" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
}

# Collect information about this tenant, like verified domains
$tenantDetail = Invoke-RjRbRestMethodGraph -Resource "/organization"

#"Choosing UPN, if not given"
if ($UserPrincipalName -eq "") {
    $UPNSuffix = ($tenantDetail.verifiedDomains | Where-Object { $_.isDefault }).name
    if ($MailNickname -ne "") {
        # Try to base it on mailnickname...
        $UserPrincipalName = ($MailNickname + "@" + $UPNSuffix).ToLower()
    }
    elseif (($GivenName -ne "") -and ($Surname -ne "")) {
        # Try to create it from the real name...
        $prefix = ($GivenName + "." + $Surname).ToLower()
        # Filter/Replace illeagal characters. List is not complete.
        $prefix = $prefix.Replace(" ", "")
        $prefix = $prefix.Replace("´", "'")
        $prefix = $prefix.Replace("``", "'")
        $prefix = $prefix.Replace("ä", "ae")
        $prefix = $prefix.Replace("ö", "oe")
        $prefix = $prefix.Replace("ü", "ue")
        $prefix = $prefix.Replace("ß", "ss")

        $UserPrincipalName = ($prefix + "@" + $UPNSuffix).ToLower()
    }
    else {
        throw "Please provide a userPrincipalName"
    }
    #"Setting userPrincipalName to `"$UserPrincipalName`"."
}

#"Check if the username $UserPrincipalName is available" 
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users/$UserPrincipalName" -ErrorAction SilentlyContinue
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
    $CompanyName = $tenantDetail.displayName
    #"Setting companyName to `"$CompanyName`"."
}



$newUserArgs = [ordered]@{
    userPrincipalName = $UserPrincipalName
    mailNickName      = $MailNickname
    displayName       = $DisplayName
    accountEnabled    = $true
    passwordProfile   = @{
        forceChangePasswordNextSignIn = $true
        password                      = $initialPassword
    }
}

if ($givenName) {
    $newUserArgs += @{ givenName = $givenName }
}

if ($surname) {
    $newUserArgs += @{ surname = $surname }
}

if ($CompanyName) {
    $newUserArgs += @{ companyName = $CompanyName }
}

if ($Department) {
    $newUserArgs += @{ department = $Department }
}

if ($LocationName) {
    $newUserArgs += @{ officeLocation = $LocationName }
}

if ($Country) {
    $newUserArgs += @{ country = $Country }
}

if ($State) {
    $newUserArgs += @{ state = $State }
}

if ($postalCode) {
    $newUserArgs += @{ postalCode = $postalCode }
}

if ($city) {
    $newUserArgs += @{ city = $city }
}

if ($streetAddress) {
    $newUserArgs += @{ streetAddress = $streetAddress }
}

if ($JobTitle) {
    $newUserArgs += @{ jobTitle = $JobTitle }
}

if ($MobilePhone) {
    $newUserArgs += @{ mobilePhone = $MobilePhone }
}

if ($UsageLocation) {
    $newUserArgs += @{ usageLocation = $UsageLocation }
}

# $newUserArgs | Format-Table | Out-String

"## Creating user object '$UserPrincipalName'"
$userObject = Invoke-RjRbRestMethodGraph -Resource "/users" -Method Post -Body $newUserArgs


# Assign a manager 
if ($ManagerId) {
    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($ManagerId)"
    }
    Invoke-RjRbRestMethodGraph -Resource "/users/$($userObject.id)/manager/`$ref" -Method Put -Body $body | Out-Null
}

# Assign the default license. Continue even if this fails.
if ($DefaultLicense -ne "") {
    #"Searching license group $DefaultLicense."
    $group = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$DefaultLicense'" -OdSelect "displayName, assignedLicenses, id" -ErrorAction SilentlyContinue

    if (-not $group) {
        "## License group '$DefaultLicense' not found!"
        Write-Error "License group '$DefaultLicense' not found!"
    }
    else {
        $licenses = $group.assignedLicenses
        $enoughlicenses = $true
        foreach ($license in $licenses) {
            $sku = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" | Where-Object { $_.skuID -eq $license.skuId }
            $SkuRemaining = $sku.prepaidUnits.enabled - $sku.consumedUnits
            if ($SkuRemaining -le 0) {
                $enoughlicenses = $false
            }
        }
        if ($enoughlicenses) {
            "## Adding to license group '$($group.displayName)'"
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($userObject.id)" 
            }
            try {
                Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/`$ref" -Method Post -Body $body | Out-Null
                #"## '$($group.displayName)' is assigned to '$UserPrincipalName'"
            }
            catch {
                "## ... failed. Skipping '$($group.displayName)'. See Errorlog."
                Write-RjRbLog $_
            }
        }
        else {
            "## WARNING - Licensegroup '$DefaultLicense' lacks sufficient licenses! Not provisioning license / group membership."

        }
        
        
    }
}

# Assign the given groups. Continue even if this fails.
$groupsArray = $DefaultGroups.split(',').Trim()
foreach ($groupname in $groupsArray) {
    if ($groupname -ne "") {
        #"Searching default group $groupname."
        $group = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$groupname'" -ErrorAction SilentlyContinue
        if (-not $group) {
            "## Group '$groupname' not found!" 
            Write-Error "Group '$groupname' not found!"
        }
        else {
            if (($group.GroupTypes -contains "Unified") -or (-not $group.MailEnabled)) {
                "## Adding to group '$($group.displayName)'"
                $body = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($userObject.id)"
                }
                try {
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/`$ref" -Method Post -Body $body | Out-Null
                    #"## '$($group.displayName)' is assigned to '$UserPrincipalName'"
                }
                catch {
                    "## ... failed. Skipping '$($group.displayName)'. See Errorlog."
                    Write-RjRbLog $_
                }
            }
            else {
                try {
                    "## Adding to exchange group/list '$($group.displayName)'"
                    # Mailbox needs to be provisioned first. EXO takes multiple minutes to privision a fresh mailbox. 
                    $mbox = get-exomailbox -Identity $UserPrincipalName -ErrorAction SilentlyContinue
                    if (-not $mbox) {
                        $MaxRuns = 30
                        "## - Waiting for Mailbox creation. Max Wait Time ca. $($MaxRuns/2) minutes."
                        $mbox = $null; 
                        $counter = 0
                        while ((-not $mbox) -and ($counter -le $MaxRuns)) {
                            $counter++;
                            Start-Sleep 30; 
                            $mbox = get-exomailbox -Identity $UserPrincipalName -ErrorAction SilentlyContinue; 
                        }; 
                    }
                    Add-DistributionGroupMember -Identity $group.id -Member $UserPrincipalName -BypassSecurityGroupManagerCheck:$true -Confirm:$false
                }
                catch {
                    "## ... failed. Skipping '$($group.displayName)'. See Errorlog."
                    Write-RjRbLog $_
                }
            }
        }
    }
}

# Enable Exchange Online Archive
if ($EnableEXOArchive) {
    try {
        "## Enabling EXO Archive Mailbox"
        # Mailbox needs to be provisioned first. EXO takes multiple minutes to privision a fresh mailbox. 
        $mbox = get-exomailbox -Identity $UserPrincipalName -ErrorAction SilentlyContinue
        if (-not $mbox) {
            $MaxRuns = 30
            "## - Waiting for Mailbox creation. Max Wait Time ca. $($MaxRuns/2) minutes."
            $mbox = $null; 
            $counter = 0
            while ((-not $mbox) -and ($counter -le $MaxRuns)) {
                $counter++;
                Start-Sleep 30; 
                $mbox = get-exomailbox -Identity $UserPrincipalName -ErrorAction SilentlyContinue; 
            }; 
        }
        Enable-Mailbox -Archive -Identity $UserPrincipalName | Out-Null
    }
    catch {
        Write-Error "Enabling Mail Archive for '$UserPrincipalName' failed"
        Write-Error $_
    }
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

"## User '$UserPrincipalName' successfully created. Initial PW:" 
"$InitialPassword"

