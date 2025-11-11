<#
  .SYNOPSIS
  Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. Fully automated through Teams Phone Inventory.

  .DESCRIPTION
  Assigns a Microsoft Teams user a phone number and corresponding voice policies for his location, based on AzureAD attributes, in a fully automated way.
  The input of parameters is not necessary resp. not possible with this runbook.
  The runbook is part of the TeamsPhoneInventory.

  .NOTES
  Version Changelog:
  1.1.1 - 2025-04-16 - Add additional check, if number is assigned
  1.1.0 - 2025-03-25 - New Get-TPIList function
                       - For better handling of SharePoint Lists
                       - Removed conversion of returned list object (no longer needed, cause of the new function)
                     - Simplified Invoke-TPIRestMethod function
                     - Update PowerShell modules to the latest version (RealmJoin.RunbookHelper, MicrosoftTeams, Microsoft.Graph.Authentication)
                     - Add regions to the script for better readability
  1.0.0 - 2024-12-20 - Initial Version (=first version in which versioning is defined)

 .INPUTS
  RunbookCustomization: {
      "Parameters": {
          "SharepointSite": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointTPIList": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointLocationDefaultsList": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointUserMappingList": {
              "Hide": true,
              "Mandatory": true
          },
          "CallerName": {
              "Hide": true
          }
      }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.4.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.32.0"}

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,

    # TPI parameters - needs to be configured in RealmJoin Runbook Customization!
    # See Section "Runbook Customization" in Documentation for further Details
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointSite" } )]
    [string] $SharepointSite,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointTPIList" } )]
    [string] $SharepointTPIList,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLocationDefaultsList" } )]
    [String] $SharepointLocationDefaultsList,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointUserMappingList" } )]
    [String] $SharepointUserMappingList,
    # CallerName is tracked purely for auditing purposes
    [string] $CallerName

)

########################################################
#region function declaration
##
########################################################
function Get-TPIList {
    param (
        [parameter(Mandatory = $true)]
        [String]$ListBaseURL,
        [parameter(Mandatory = $false)]
        [String]$ListName, # Only for easier logging
        [parameter(Mandatory = $false)]
        [String[]]$Properties,
        # Example call with multiple properties
        # $ListBaseURL = "A valid URL"
        # $Properties = @("Title", "ID", "PhoneNumber", "Extension")
        # $ListItems = Get-TPIList -ListBaseURL $ListBaseURL -Properties $Properties

        # In default, the first column is Title, but if the Value should be replaced, it can be done with this parameter
        [parameter(Mandatory = $false)]
        [String]$TitelNameReplacement,
        [parameter(Mandatory = $false)]
        [bool]$VerboseGraphAPILogging = $false
    )

    $GraphAPIUrl_StatusQuoSharepointList = $ListBaseURL + '/items?expand=fields'
    $AllItems = @()

    try {
        do {
            $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8' -Verbose:$VerboseGraphAPILogging
            $AllItems += $AllItemsResponse.value.fields
            $GraphAPIUrl_StatusQuoSharepointList = $AllItemsResponse."@odata.nextLink"
        } while ($null -ne $GraphAPIUrl_StatusQuoSharepointList)
    }
    catch {
        Write-Warning "First try to get TPI list failed - reconnect MgGraph and test again"

        try {
            Connect-MgGraph -Identity
            do {
                $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8' -Verbose:$VerboseGraphAPILogging
                $AllItems += $AllItemsResponse.value.fields
                $GraphAPIUrl_StatusQuoSharepointList = $AllItemsResponse."@odata.nextLink"
            } while ($null -ne $GraphAPIUrl_StatusQuoSharepointList)
        }
        catch {
            Write-Error "Getting TPI list failed - stopping script" -ErrorAction Continue
            Exit
        }
    }

    if (($AllItems | Measure-Object).Count -gt 0) {
        $CustomObjects = @()
        foreach ($item in $AllItems) {
            $objProps = @{}
            if ($Properties) {
                foreach ($property in $Properties) {
                    if ($item.ContainsKey($property)) {
                        if ($property -eq "Title" -and $TitelNameReplacement) {
                            $objProps[$TitelNameReplacement] = $item[$property]
                        }
                        else {
                            $objProps[$property] = $item[$property]
                        }
                    }
                    else {
                        $objProps[$property] = ""
                    }
                }
            }
            else {
                foreach ($key in $item.Keys) {
                    if ($key -eq "Title" -and $TitelNameReplacement) {
                        $objProps[$TitelNameReplacement] = $item[$key]
                    }
                    else {
                        $objProps[$key] = $item[$key]
                    }
                }
            }
            $CustomObjects += [PSCustomObject]$objProps
        }
        return $CustomObjects
    }
    else {
        return @()
    }
}

function Invoke-TPIRestMethod {
    param (
        [parameter(Mandatory = $true)]
        [String] $Uri,
        [parameter(Mandatory = $true)]
        [String] $Method,
        [parameter(Mandatory = $false)]
        $Body,
        [parameter(Mandatory = $true)]
        [String] $ProcessPart,
        [parameter(Mandatory = $false)]
        [bool] $VerboseGraphAPILogging = $false
    )

    $ExitError = $false
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")

    try {
        if ($Method -in @("Post", "Patch")) {
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body (($Body) | ConvertTo-Json -Depth 6) -ContentType 'application/json; charset=utf-8' -Verbose:$VerboseGraphAPILogging
        } else {
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Verbose:$VerboseGraphAPILogging
        }
    } catch {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart"
        $StatusCode = $_.Exception.Response.StatusCode.value__
        $StatusDescription = $_.Exception.Response.ReasonPhrase
        Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
        Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"

        try {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - GraphAPI - One Retry after 5 seconds"
            Start-Sleep -Seconds 5

            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - GraphAPI - GraphAPI Session refresh"
            Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop

            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - GraphAPI - 2nd Run for Process part: $ProcessPart"
            if ($Method -in @("Post", "Patch")) {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body (($Body) | ConvertTo-Json -Depth 6) -ContentType 'application/json; charset=utf-8' -Verbose:$VerboseGraphAPILogging
            } else {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Verbose:$VerboseGraphAPILogging
            }
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
        } catch {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present!"
            $StatusCode = $_.Exception.Response.StatusCode.value__
            $StatusDescription = $_.Exception.Response.ReasonPhrase
            Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
            Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
            $ExitError = $true
        }
    }

    if ($ExitError) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        throw "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present! StatusCode: $StatusCode StatusDescription: $StatusDescription"
    }

    return $TPIRestMethod
}


#endregion

########################################################
#region     Properties declaration
##
########################################################
# Description for this block:
# ===========================
#
# Properties:
# ------------------
# To be able to get all collumns from the SharePoint Lists for each TPI List, the Get-TPIList had a parameter calles "Properties"
# This parameter is used to define the columns that should be returned from the SharePoint List.
# So all Properties (=Collumns) only need to defined once.
#
# Title Replacement:
# ------------------
# By default, the first column from a SharePoint List is called "Title".
# This could be changed for the DisplayName, but this does not change the internal name of the column.
# To change the internal name of the column, the parameter "TitelNameReplacement" is used.
# It allows an easier handling of the returned objects.

# TeamsPhoneInventory List
$ListProperties_TeamsPhoneInventory = @(
    "Title",
    "MainLineUri",
    "DID",
    "TeamsEXT",
    "NumberRangeName",
    "ExtensionRangeName",
    "CivicAddressMappingName",
    "UPN",
    "Display_Name",
    "OnlineVoiceRoutingPolicy",
    "TeamsCallingPolicy",
    "DialPlan",
    "TenantDialPlan",
    "TeamsPrivateLine",
    "VoiceType",
    "UserType",
    "NumberCapability",
    "NumberRangeIndex",
    "ExtensionRangeIndex",
    "CivicAddressMappingIndex",
    "Country",
    "City",
    "Company",
    "EmergencyAddressName",
    "Status",
    "id"
)
$TitelNameReplacement_TeamsPhoneInventory = "FullLineUri"

# NumberRange List
$ListProperties_NumberRange = @(
    "Title",
    "NumberRangeName",
    "MainNumber",
    "BeginNumberRange",
    "EndNumberRange",
    "Country",
    "City",
    "UNLOCODE",
    "Company"
)
$TitelNameReplacement_NumberRange = "NumberRangeIndex"

# ExtensionRange List
$ListProperties_ExtensionRange = @(
    "Title",
    "ExtensionRangeName",
    "BeginExtensionRange",
    "EndExtensionRange",
    "NumberRangeIndex",
    "ExtensionRangeCompany"
)
$TitelNameReplacement_ExtensionRange = "ExtensionRangeIndex"

# CivicAddressMapping List
$ListProperties_CivicAddressMapping = @(
    "Title",
    "CivicAddressMappingName",
    "CivicAddressID",
    "Country",
    "City",
    "UNLOCODE",
    "Company"
)
$TitelNameReplacement_CivicAddressMapping = "CivicAddressMappingIndex"

# Legacy List
$ListProperties_Legacy = @(
    "Title",
    "LegacyName",
    "LegacyType"
)
$TitelNameReplacement_Legacy = "LineUri"

# BlockExtension List
$ListProperties_BlockExtension = @(
    "Title",
    "BlockUntil",
    "BlockReason"
)
$TitelNameReplacement_BlockExtension = "LineUri"

#LocationDefaults List
$ListProperties_LocationDefaults = @(
    "Title",
    "LocationName",
    "ExtensionRangeIndex",
    "CivicAddressMappingIndex",
    "OnlineVoiceRoutingPolicy",
    "TeamsCallingPolicy",
    "TenantDialPlan",
    "TeamsIPPhonePolicy",
    "OnlineVoicemailPolicy"
)
$TitelNameReplacement_LocationDefaults = "LocationIdentifier"

#LocationMapping List
$ListProperties_LocationMapping = @(
    "Title",
    "City",
    "Street",
    "Company"
)
$TitelNameReplacement_LocationMapping = "LocationIdentifier"

# UserMapping List
$ListProperties_UserMapping = @(
    "Title",
    "LocationIdentifier"
)
$TitelNameReplacement_UserMapping = "UPN"

#endregion


########################################################
#region Block 0 - Connect Part
##
########################################################
# Add Caller in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

# Add Version in Verbose output
$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "SharepointSite: '$SharepointSite'" -Verbose
Write-RjRbLog -Message "SharepointTPIList: '$SharepointTPIList'" -Verbose
Write-RjRbLog -Message "SharepointLocationDefaultsList: '$SharepointLocationDefaultsList'" -Verbose
Write-RjRbLog -Message "SharepointUserMappingList: '$SharepointUserMappingList'" -Verbose

# Needs a Microsoft Teams Connection First!
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Connect to Microsoft Teams (PowerShell as RealmJoin managed identity)"

$VerbosePreference = "SilentlyContinue"
Connect-MicrosoftTeams -Identity -ErrorAction Stop
$VerbosePreference = "Continue"

# Check if Teams connection is active
try {
    $Test = Get-CsTenant -ErrorAction Stop | Out-Null
}
catch {
    try {
        Start-Sleep -Seconds 5
        $Test = Get-CsTenant -ErrorAction Stop | Out-Null
    }
    catch {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Teams PowerShell session could not be established. Stopping script!"
        Exit
    }
}

# Initiate Graph Session
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Initiate MGGraph Session"
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    Exit
}

#endregion
########################################################
#region Block 1 - License check
##
########################################################
Write-Output ""
Write-Output "Block 1 - License check"
# If no license has been assigned to the user, respectively if the license is not yet replicated
# in the teams backend or if the appropriate applications are not available within the license,
# the script will be stopped!

Write-Output "Getting StatusQuo for user with ID: $UserName"
$StatusQuo = Get-CsOnlineUser $UserName

if ($StatusQuo.UsageLocation -eq $null -or $StatusQuo.UsageLocation -eq "") {
    Write-Error "Error: The user's Usage Location is not set. Please set the Usage Location for the user and try again."
    throw "The user's Usage Location is not set. Please set the Usage Location for the user and try again."
    Exit
}

$AssignedPlan = $StatusQuo.AssignedPlan

if ($AssignedPlan.Capability -like "MCOSTANDARD" -or $AssignedPlan.Capability -like "MCOEV" -or $AssignedPlan.Capability -like "MCOEV-*") {
    Write-Output "License check - Microsoft O365 Phone Standard is generally assigned to this user"

    #Validation whether license is already assigned long enough
    $Now = get-date

    $LicenseTimeStamp = ($AssignedPlan | Where-Object Capability -Like "MCOSTANDARD").AssignedTimestamp

    if ($LicenseTimeStamp -like "") {
        $LicenseTimeStamp = ($AssignedPlan | Where-Object Capability -Like "MCOEV*").AssignedTimestamp
    }
    if ($LicenseTimeStamp -notlike "") {
        try {
            if ($LicenseTimeStamp.AddHours(1) -lt $Now ) {
                Write-Output "The license has already been assigned to the user for more than one hour. Date/time of license assignment: $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss"))"
                if (($LicenseTimeStamp.AddHours(24) -gt $Now)) {
                    Write-Output "Note: In some cases, this may not yet be sufficient. It can take up to 24h until the license replication in the backend is completed!"
                }

            }else {
                Write-Output ""
                Write-Error "Error: The user license should have been assigned for at least one hour, otherwise proper provisioning cannot be ensured. The license was assigned at $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss")) (UTC). Please try again at $($LicenseTimeStamp.AddHours(1).ToString("yyyy-MM-dd HH:mm:ss")) (MCOEV - Microsoft O365 Phone Standard)"
                throw "The user license should have been assigned for at least one hour, otherwise proper provisioning cannot be ensured. The license was assigned at $($LicenseTimeStamp.ToString("yyyy-MM-dd HH:mm:ss")) (UTC). Please try again at $($LicenseTimeStamp.AddHours(1).ToString("yyyy-MM-dd HH:mm:ss")) (MCOEV - Microsoft O365 Phone Standard)"
                Exit
            }
        }
        catch {
            Write-Warning "Warning: The time of license assignment could not be verified!"
        }
    }else {
        Write-Warning "Warning: The time of license assignment could not be verified!"
    }

}else {
    Write-Output ""
    Write-Error "Error: The user does not have a license assigned respectively it is not yet replicated in the teams backend or the corresponding applications within the license are not available (MCOEV - Microsoft O365 Phone Standard)"
    throw "The user does not have a license assigned respectively it is not yet replicated in the teams backend or the corresponding applications within the license are not available (MCOEV - Microsoft O365 Phone Standard)"
    Exit
}


#endregion
########################################################
#region Block 2 - Setup base URL
##
########################################################
Write-Output ""
Write-Output "Block 2 - Check basic connection to TPI List and build base URL"

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Check basic connection to TPI List"

$SharepointURL = (Invoke-TPIRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/root" -Method GET -ProcessPart "Get SharePoint WebURL" ).webUrl
if ($SharepointURL -like "https://*") {
  $SharepointURL = $SharepointURL.Replace("https://","")
}elseif ($SharepointURL -like "http://*") {
  $SharepointURL = $SharepointURL.Replace("http://","")
}

# Setup Base URL - not only for NumberRange etc.
$BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/teams/' + $SharepointSite + ':/lists/'
$TPIListURL = $BaseURL + $SharepointTPIList
try {
    Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" -ErrorAction Stop | Out-Null
}
catch {
    $BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/sites/' + $SharepointSite + ':/lists/'
    $TPIListURL = $BaseURL + $SharepointTPIList
    try {
        Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List"  -ErrorAction Stop | Out-Null
    }
    catch {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Connection - Could not connect to SharePoint TPI List!"
        throw "$TimeStamp - Could not connect to SharePoint TPI List!"
        Exit
    }
}

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - SharePoint TPI List URL: $TPIListURL"



#endregion
########################################################
#region Block 3 - Get Status Quo of the User Mapping SharePoint List
##
########################################################
Write-Output "Block 3 - Get StatusQuo of the User Mapping SharePoint List"

$TPIUserMappingListURL = $BaseURL + $SharepointUserMappingList

$TPI_UserMapping_AllItems = Get-TPIList -ListBaseURL $TPIUserMappingListURL -ListName $SharepointUserMappingList -Properties $ListProperties_UserMapping -TitelNameReplacement $TitelNameReplacement_UserMapping

Write-Output "Items in $SharepointUserMappingList SharePoint List: $($TPI_UserMapping_AllItems.Count)"

#endregion
########################################################
#region Block 4 - Check if current user fits to a defined location
##
########################################################
Write-Output ""
Write-Output "Block 4 - Check if current user fits to a defined location"
$CurrentUserMapping = $TPI_UserMapping_AllItems | Where-Object UPN -Like $UserName #Get all entries from TPI-UserMapping List which Title (UPN) is like the given UserName

Write-Output "EntraID Attributes for the current user:"
Write-Output "$($StatusQuo.DisplayName) - $($StatusQuo.UserPrincipalName)"
Write-Output "- Company: $($StatusQuo.Company)"
Write-Output "- City: $($StatusQuo.City)"
Write-Output "- Street: $($StatusQuo.Street) `n"

if (($CurrentUserMapping | Measure-Object).Count -eq 1) {
    if ($CurrentUserMapping.LocationIdentifier -notlike "") { #If there is exactly one match - go on
        $CurrentLocationIdentifier = $CurrentUserMapping.LocationIdentifier
        Write-Output "The LocationIdentifier of the user is $CurrentLocationIdentifier"
    }else {
        Write-Output ""
        Write-Output "Error:"
        Write-Output "There is an entry for the user in the user mapping list, but the LocationIdentifier is empty. The script will therefore be terminated!"
        Write-Output ""
        throw "There is an entry for the user in the user mapping list, but the LocationIdentifier is empty. The script will therefore be terminated!"
        Exit
    }
}elseif (($CurrentUserMapping | Measure-Object).Count -gt 1) { #If there are duplicates - stop it!
    Write-Output ""
    Write-Output "Error:"
    Write-Output "More than one entry is present in the user mapping table. Script will be cancelled because no unique mapping is possible!"
    Write-Output ""
    throw "More than one entry is present in the user mapping table. Script will be cancelled because no unique mapping is possible!"
    Exit
}elseif (($CurrentUserMapping | Measure-Object).Count -eq 0) { #If there is no match - stop it!
    Write-Output ""
    Write-Output "Error:"
    Write-Output "User is not available in User Mapping List. Either no suitable location could be found for the user based on his Azure AD attributes or the user has been created for less than a day, so the user has not been mapped yet. The script will therefore be terminated!"
    Write-Output ""
    throw "User is not available in User Mapping List. Either no suitable location could be found for the user based on his Azure AD attributes or the user has been created for less than a day, so the user has not been mapped yet. The script will therefore be terminated!"
    Exit
}


#endregion
########################################################
#region Block 5 - Get Status Quo of the Location Defaults SharePoint List
##
########################################################
Write-Output ""
Write-Output "Block 5 - Get StatusQuo of the Location Defaults SharePoint List"

$TPILocationDefaultsListURL = $BaseURL + $SharepointLocationDefaultsList

$TPI_LocationDefaults_AllItems = Get-TPIList -ListBaseURL $TPILocationDefaultsListURL -ListName $SharepointLocationDefaultsList -Properties $ListProperties_LocationDefaults -TitelNameReplacement $TitelNameReplacement_LocationDefaults
Write-Output "Items in $SharepointLocationDefaultsList SharePoint List: $($TPI_LocationDefaults_AllItems.Count)"

$RecievedLocationDefaults = $TPI_LocationDefaults_AllItems | Where-Object LocationIdentifier -Like $CurrentLocationIdentifier

Write-Verbose "Current Location Identifier: $CurrentLocationIdentifier"

if (($RecievedLocationDefaults | Measure-Object).Count -eq 1) {
    if ($RecievedLocationDefaults.ExtensionRangeIndex -notlike "" -or $RecievedLocationDefaults.CivicAddressMappingIndex -notlike "") {
        Write-Output ""

        $CivicAddressMappingIndex = $RecievedLocationDefaults.CivicAddressMappingIndex
        if (($RecievedLocationDefaults.ExtensionRangeIndex -notlike "" -and $RecievedLocationDefaults.CivicAddressMappingIndex -notlike "")) {
            Write-Warning "For the current Location Identifier: $CurrentLocationIdentifier both values (ExtensionRange and CivicAdressMapping(CallingPlan)) is filled!"
            Write-Warning "Prefer ExtensionRange and clearing CivicAdressMapping now!"
            $CivicAddressMappingIndex = ""
        }
        Write-Output "Recieved values:"
        $ExtensionRangeIndex = $RecievedLocationDefaults.ExtensionRangeIndex
        if ($ExtensionRangeIndex -notlike "") {
            Write-Output "The ExtensionRangeIndex of the user is $ExtensionRangeIndex"
        }elseif ($CivicAddressMappingIndex -notlike "") {
            Write-Output "The CivicAddressMappingIndex of the user is $CivicAddressMappingIndex"
        }

        $OnlineVoiceRoutingPolicy = $RecievedLocationDefaults.OnlineVoiceRoutingPolicy
        if ($OnlineVoiceRoutingPolicy -like "") {
            $OnlineVoiceRoutingPolicy = "Global (Org Wide Default)"
        }
        Write-Output "The OnlineVoiceRoutingPolicy of the user is $OnlineVoiceRoutingPolicy"
        $TenantDialPlan = $RecievedLocationDefaults.TenantDialPlan
        if ($TenantDialPlan -like "") {
            $TenantDialPlan = "Global (Org Wide Default)"
        }
        Write-Output "The TenantDialPlan of the user is $TenantDialPlan"
        $CallingPolicy = $RecievedLocationDefaults.CallingPolicy
        if ($CallingPolicy -like "") {
            $CallingPolicy = "Global (Org Wide Default)"
        }
        Write-Output "The CallingPolicy of the user is $CallingPolicy"
    }else {
        Write-Output ""
        Write-Error "Error: There is an entry for the current location identifier, but no phone number ranges or civic address mappings are defined for it. The script will therefore be terminated!"
        Write-Output ""
        throw "There is an entry for the current location identifier, but no phone number ranges or civic address mappings are defined for it. The script will therefore be terminated!"
        Exit
    }
}elseif (($RecievedLocationDefaults | Measure-Object).Count -eq 0) {
    Write-Output ""
    Write-Error "Error: No location defaults could be found for the received location identifier. The script will therefore be terminated!"
    Write-Output ""
    throw "No location defaults could be found for the received location identifier. The script will therefore be terminated!"
    Exit
}

#endregion
########################################################
#region Block 6 - Get Status Quo of the main TPI SharePoint List and find next free number
##
########################################################

Write-Output ""
Write-Output "Block 6 - Get StatusQuo of the SharePoint List"

$TPI_AllItems = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList -Properties $ListProperties_TeamsPhoneInventory -TitelNameReplacement $TitelNameReplacement_TeamsPhoneInventory
Write-Output "Items in $SharepointTPIList SharePoint List: $($TPI_AllItems.Count)"

if ($ExtensionRangeIndex -notlike "") {
    Write-Output "Check for next free number using ExtensionRangeIndex: $ExtensionRangeIndex"
    $NextFreeNumber = ($TPI_AllItems | Where-Object {($_.ExtensionRangeIndex -Like $ExtensionRangeIndex) -and ($_.Display_Name -Like "") -and ($_.UPN -Like "") -and ($_.Type -NotLike "LegacyPhoneNumber") -and ($_.Status -notmatch '.*BlockNumber_Until([0]?[1-9]|[1|2][0-9]|[3][0|1]).([0]?[1-9]|[1][0-2]).([0-9]{4}|[0-9]{2}).*') -and ($_.Status -notmatch '.*BlockNumber_Permanent.*') -and ($_.Status -notmatch '.*BlockNumber_permanent.*')} | Sort-Object FullLineUri | Select-Object FullLineUri,ID -First 1)
}elseif ($CivicAddressMappingIndex -notlike "") {
    Write-Output "Check for next free number using CivicAddressMappingIndex: $CivicAddressMappingIndex"
    $NextFreeNumber = ($TPI_AllItems | Where-Object {($_.CivicAddressMappingIndex -Like $CivicAddressMappingIndex) -and ($_.Display_Name -Like "") -and ($_.UPN -Like "") -and ($_.Type -NotLike "LegacyPhoneNumber") -and ($_.Status -notmatch '.*BlockNumber_Until([0]?[1-9]|[1|2][0-9]|[3][0|1]).([0]?[1-9]|[1][0-2]).([0-9]{4}|[0-9]{2}).*') -and ($_.Status -notmatch '.*BlockNumber_Permanent.*') -and ($_.Status -notmatch '.*BlockNumber_permanent.*')} | Sort-Object FullLineUri | Select-Object FullLineUri,ID -First 1)
}else {
    Write-Error "Error: Both entries ExtensionRangeIndex and CivicAddressMappingIndex are empty, therefore it is not possible to search for a free number!"
}

if (($NextFreeNumber| Measure-Object).Count -eq 0) {
    Write-Error "Error: No free number for the choosen location available"
    throw "No free number for the choosen location available"
    Exit
}

$PhoneNumber = $NextFreeNumber.FullLineUri
Write-Output "The next free number for location $CurrentLocationIdentifier would be $PhoneNumber"

#endregion
########################################################
#region Block 7 - Teams User StatusQuo
##
########################################################
Write-Output ""
Write-Output "Block 7 - List StatusQuo for user with ID:  $UserName"

$UPN = $StatusQuo.UserPrincipalName
Write-Output "UPN from user: $UPN"

$CurrentLineUri = $StatusQuo.LineURI -replace("tel:","")

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

if ($CurrentLineUri -like "+") { # Change Current LineUri to "none" if it is blank
    $CurrentLineUri = "none"
}

if ($StatusQuo.OnlineVoiceRoutingPolicy -like "") {
    $CurrentOnlineVoiceRoutingPolicy = "Global"
}else {
    $CurrentOnlineVoiceRoutingPolicy = $StatusQuo.OnlineVoiceRoutingPolicy
}

if ($StatusQuo.CallingPolicy -like "") {
    $CurrentCallingPolicy = "Global"
}else {
    $CurrentCallingPolicy = $StatusQuo.CallingPolicy
}

if ($StatusQuo.DialPlan -like "") {
    $CurrentDialPlan = "Global"
}else {
    $CurrentDialPlan = $StatusQuo.DialPlan
}

if ($StatusQuo.TenantDialPlan -like "") {
    $CurrentTenantDialPlan = "Global"
}else {
    $CurrentTenantDialPlan = $StatusQuo.TenantDialPlan
}

if ($StatusQuo.TeamsIPPhonePolicy -like "") {
    $CurrentTeamsIPPhonePolicy = "Global"
}else {
    $CurrentTeamsIPPhonePolicy = $StatusQuo.TeamsIPPhonePolicy
}

Write-Output "Current LineUri: $CurrentLineUri"
Write-Output "Current OnlineVoiceRoutingPolicy: $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Current CallingPolicy: $CurrentCallingPolicy"
Write-Output "Current DialPlan: $CurrentDialPlan"
Write-Output "Current TenantDialPlan: $CurrentTenantDialPlan"
Write-Output "Current TeamsIPPhonePolicy: $CurrentTeamsIPPhonePolicy"


#endregion
########################################################
#region Block 8 - Pre flight check
##
########################################################
Write-Output ""
Write-Output "Block 8 - Pre flight check"

# Check if number is already assigned
$PhoneNumberAssignment = Get-CsPhoneNumberAssignment -TelephoneNumber "$PhoneNumber"
$PstnAssignmentStatus = $PhoneNumberAssignment.PstnAssignmentStatus
$AssignedPstnTargetId = $PhoneNumberAssignment.AssignedPstnTargetId

$NumberAlreadyAssigned = 0

if ($PstnAssignmentStatus -like "Unassigned") {
    Write-Output "Phone number is not yet assigned to a Microsoft Teams user"
}elseif ($PstnAssignmentStatus -like "") {
    Write-Output "PstnAssignmentStatus is empty, performing additional check with Get-CsOnlineUser"
    $ExistingUser = Get-CsOnlineUser -Filter "LineURI -eq 'tel:$PhoneNumber'" -ErrorAction SilentlyContinue
    if ($ExistingUser) {
        if ($ExistingUser.UserPrincipalName -eq $UPN) {
            $NumberAlreadyAssigned = 1
            Write-Output "Phone number is already assigned to the user!"
        } else {
            Write-Error "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned to $($ExistingUser.UserPrincipalName) according to direct user check"
            throw "The assignment could not be performed. PhoneNumber is already assigned!"
        }
    } else {
        Write-Output "No user found with this phone number in direct check, proceeding with assignment"
    }
}else {
    if ($($StatusQuo.Identity) -like $AssignedPstnTargetId) { #Check if number is already assigned to the target user
        $NumberAlreadyAssigned = 1
        Write-Output "Phone number is already assigned to the user!"
    }elseif ($PhoneNumberAssignment.AssignmentCategory -like "Private") {
        try {
            $CurrentPrivateLineUser = (Get-CsOnlineUser $PhoneNumberAssignment.AssignedPstnTargetId).UserPrincipalName
            if ([string]::IsNullOrEmpty($CurrentPrivateLineUser)) {
            Write-Error "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned as a private line but user details could not be retrieved."
            throw "The assignment could not be performed. PhoneNumber is already assigned as a private line!"
            } else {
            Write-Error "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned as a private line to $CurrentPrivateLineUser"
            throw "The assignment could not be performed. PhoneNumber is already assigned as a private line!"
            }
        }
        catch {
            Write-Error "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned as a private line. Failed to retrieve user details: $_"
            throw "The assignment could not be performed. PhoneNumber is already assigned as a private line!"
        }

    }else{
        try {
            $CurrentAssignedUser = (Get-CsOnlineUser $AssignedPstnTargetId).UserPrincipalName
            if ([string]::IsNullOrEmpty($CurrentAssignedUser)) {
                Write-Error "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned but user details could not be retrieved."
                throw "The assignment could not be performed. PhoneNumber is already assigned!"
            } else {
                Write-Error "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned to $CurrentAssignedUser"
                throw "The assignment could not be performed. PhoneNumber is already assigned!"
            }
        }
        catch {
            Write-Error "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned. Failed to retrieve user details: $_"
            throw "The assignment could not be performed. PhoneNumber is already assigned!"
        }
    }
}

#Check if number is a calling plan or operator connect number
Write-Output "Check if LineUri is a Calling Plan, Operator Connect or Direct Routing number"

if($PhoneNumberAssignment.NumberType -eq "DirectRouting") {
    $CallingPlanCheck = $false
    $OperatorConnectCheck = $false
    Write-Output "Phone number is a Direct Routing number"
}elseif($PhoneNumberAssignment.NumberType -eq "CallingPlan") {
    $CallingPlanCheck = $true
    $OperatorConnectCheck = $false
    Write-Output "Phone number is a Calling Plan number"
}elseif($PhoneNumberAssignment.NumberType -eq "OperatorConnect") {
    $CallingPlanCheck = $false
    $OperatorConnectCheck = $true
    Write-Output "Phone number is a Operator Connect number"
}else{
    $CallingPlanCheck = $false
    $OperatorConnectCheck = $false
    Write-Output "Phone number could not be identified. Falling back to Direct Routing"
}

# Check if specified Online Voice Routing Policy exists
try {
    if ($OnlineVoiceRoutingPolicy -like "Global (Org Wide Default)") {
        Write-Output "The specified Online Voice Routing Policy exists - (Global (Org Wide Default))"
    }else{
        $TMP = Get-CsOnlineVoiceRoutingPolicy $OnlineVoiceRoutingPolicy -ErrorAction Stop
        Write-Output "The specified Online Voice Routing Policy exists"
    }
}
catch {
    Write-Error  "Teams - Error: The specified Online Voice Routing Policy could not be found in the tenant. Please check the specified policy! Submitted policy name: $OnlineVoiceRoutingPolicy"
    throw "The specified Online Voice Routing Policy could not be found in the tenant!"
}
if ($TMP -notlike "") {
    Clear-Variable TMP
}


# Check if specified Tenant Dial Plan exists, if submitted
if ($TenantDialPlan -notlike "") {
    try {
        if ($TenantDialPlan -like "Global (Org Wide Default)") {
            Write-Output "The specified Tenant Dial Plan exists - (Global (Org Wide Default))"
        }else{
            $TMP = Get-CsTenantDialPlan $TenantDialPlan -ErrorAction Stop
            Write-Output "The specified Tenant Dial Plan exists"
        }
    }
    catch {
        Write-Error  "Teams - Error: The specified Tenant Dial Plan could not be found in the tenant. Please check the specified policy! Submitted policy name: $TenantDialPlan"
        throw "The specified Tenant Dial Plan could not be found in the tenant!"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}


# Check if specified Teams Calling Policy exists, if submitted
if ($TeamsCallingPolicy -notlike "") {
    try {
        if ($TeamsCallingPolicy -like "Global (Org Wide Default)") {
            Write-Output "The specified Teams Calling Policy exists - (Global (Org Wide Default))"
        }else{
            $TMP = Get-CsTeamsCallingPolicy $TeamsCallingPolicy -ErrorAction Stop
            Write-Output "The specified Teams Calling Policy exists"
        }
    }
    catch {
        Write-Error  "Teams - Error: The specified Teams Calling Policy could not be found in the tenant. Please check the specified policy! Submitted policy name: $TeamsCallingPolicy"
        throw "The specified Teams Calling Policy could not be found in the tenant!"
    }
    if ($TMP -notlike "") {
        Clear-Variable TMP
    }
}


#endregion
########################################################
#region Block 9 - Main Part
##
########################################################
Write-Output ""
Write-Output "Block 9 - Main Part"

if ($NumberAlreadyAssigned -like 1) {
    Write-Output "Teams - Number $PhoneNumber is already set to $UPN - skip phone number assignment"
}else {
    Write-Output "Set $PhoneNumber to $UPN"
    try {
        if ($CallingPlanCheck) {
            Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType CallingPlan -ErrorAction Stop
        }elseif ($OperatorConnectCheck) {
            Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType OperatorConnect -ErrorAction Stop
        } else {
            Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType DirectRouting -ErrorAction Stop
        }
    }catch {
        $message = $_
        Write-Error "Teams - Error: The assignment for $UPN could not be performed! - Error Message: $message"
        throw "Teams - Error: The assignment for $UPN could not be performed! Further details in ""All Logs"""
    }
}


if (($OnlineVoiceRoutingPolicy -notlike "") -or ($TenantDialPlan -notlike "") -or ($TeamsCallingPolicy -notlike "")) {
    Write-Output ""
    Write-Output "Grant Policies policies to $UPN :"

    # Grant OnlineVoiceRoutingPolicy if defined
    if ($OnlineVoiceRoutingPolicy -notlike "") {
        Write-Output "Online Voice Routing Policy: $OnlineVoiceRoutingPolicy"
        try {
            if ($OnlineVoiceRoutingPolicy -like "Global (Org Wide Default)") {
                Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
            }else {
                Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $OnlineVoiceRoutingPolicy -ErrorAction Stop
            }
        }
        catch {
            $message = $_
            Write-Error "Teams - Error: The assignment of OnlineVoiceRoutingPolicy for $UPN could not be completed! - Error Message: $message"
            throw "Teams - Error: The assignment of OnlineVoiceRoutingPolicy for $UPN could not be completed!"
        }
    }

    # Grant TenantDialPlan if defined
    if ($TenantDialPlan -notlike "") {
        Write-Output "Tenant Dial Plan: $TenantDialPlan"
        try {
            if ($TenantDialPlan -like "Global (Org Wide Default)") {
                Grant-CsTenantDialPlan -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
            }else {
                Grant-CsTenantDialPlan -Identity $UPN -PolicyName $TenantDialPlan -ErrorAction Stop
            }
        }
        catch {
            $message = $_
            Write-Error "Teams - Error: The assignment of TenantDialPlan for $UPN could not be completed! - Error Message: $message"
            throw "Teams - Error: The assignment of TenantDialPlan for $UPN could not be completed!"
        }
    }

    # Grant TeamsCallingPolicy if defined
    if ($TeamsCallingPolicy -notlike "") {
        Write-Output "Calling Policy: $TeamsCallingPolicy"
        try {
            if ($TeamsCallingPolicy -like "Global (Org Wide Default)") {
                Grant-CsTeamsCallingPolicy -Identity $UPN -PolicyName $null -ErrorAction Stop #reset to default
            }else {
                Grant-CsTeamsCallingPolicy -Identity $UPN -PolicyName $TeamsCallingPolicy -ErrorAction Stop
            }
        }
        catch {
            $message = $_
            Write-Error "Teams - Error: The assignment of TeamsCallingPolicy for $UPN could not be completed! - Error Message: $message"
            throw "Teams - Error: The assignment of TeamsCallingPolicy for $UPN could not be completed!"
        }
    }
}

#endregion
########################################################
#region Block 10 - Write Output to TPI
##
########################################################
Write-Output ""
Write-Output "Block 10 - Write Output to TPI"

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
$ID = $NextFreeNumber.ID
$GraphAPIUrl_UpdateElement = $TPIListURL + '/items/'+ $ID
$HTTPBody_UpdateElement = @{
    "fields" = @{
        "Title"= $PhoneNumber
        "UPN"= $UPN
        "OnlineVoiceRoutingPolicy"= $OnlineVoiceRoutingPolicy
        "TeamsCallingPolicy"= $TeamsCallingPolicy
        "TenantDialPlan"= $TenantDialPlan
        "Status"= "Filled by Set Teams Phone User Runbook - $TimeStamp"
    }
}
Write-Output "Update entry: $PhoneNumber"
$TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_UpdateElement -Method Patch -Body $HTTPBody_UpdateElement -ProcessPart "TPI List - Update item: $CurrentLineUri"
$HTTPBody_UpdateElement = $null

Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null