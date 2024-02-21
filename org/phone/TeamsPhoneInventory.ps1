#region Customization depending on the implemented version
########################################################################################################################################################################
##             Start Region - Customization depending on the implemented version
##             Current Version: RJ Runbook
##
########################################################

<#
  .SYNOPSIS
  Teams Phone Inventory - Main Part (Updater)

  .DESCRIPTION
  This runbook fills the defined SharePoint list with all available phone numbers, which can be assigned as extension. 
  This list of phone numbers is then merged with a current state of the assigned phone numbers in Microsoft Teams, 
  as well as the stored legacy numbers and thus results in a current overview of assigned and free phone numbers.
  The runbook is part of the TeamsPhoneInventory.

  .PARAMETER SharepointURL
  URL of the SharePoint where the list is stored. 
  Example: c4a8.sharepoint.com

  .PARAMETER SharepointSite
  The name of the SharePoint site in which the list is stored 
  Example: TeamsPhoneInventory

  .PARAMETER SharepointTPIList
  The name of the SharePoint list, which is used as a data for the TeamsPhoneInventory. 
  Example: TeamsPhoneInventory

  .PARAMETER SharepointNumberRangeList
  The name of the SharePoint list, which inlucde the number ranges. 
  Example: TPI-NumberRange

  .PARAMETER SharepointExtensionRangeList
  The name of the SharePoint list, which inlucde the number ranges.
  Example: TPI-ExtensionRange

  .PARAMETER SharepointLegacyList
  The name of the SharePoint list, which inlucde the number ranges.
  Example: TPI-Legacy

  .PARAMETER SharepointBlockExtensionList
  The name of the SharePoint list, which inlucde the number ranges.
  Example: TPI-BlockExtension

  .PARAMETER BlockExtensionDays
  How long should a number been blocked after offboarding (in days) 
  Example: 30

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "SharepointURL": {
                "Hide": true
            },
            "SharepointSite": {
                "Hide": true
            },
            "SharepointTPIList": {
                "Hide": true
            },
            "SharepointNumberRangeList": {
                "Hide": true
            },
            "SharepointExtensionRangeList": {
                "Hide": true
            },
            "SharepointLegacyList": {
                "Hide": true
            },
            "SharepointBlockExtensionList": {
                "Hide": true
            },
            "SharepointLocationDefaultsList": {
                "Hide": true
            },
            "SharepointLocationMappingList": {
                "Hide": true
            },
            "SharepointUserMappingList": {
                "Hide": true
            },
            "BlockExtensionDays": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, @{ModuleName = "MicrosoftTeams"; ModuleVersion = "5.9.0" }

########################################################
##             Variable/Parameter declaration
##          
########################################################

Param(
        # App Registration for Update regulary TeamsPhoneInventory List - not for initializing (scoped site permission)
        # Define Sharepoint Parameters
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointURL" } )]
        [string] $SharepointURL,
        
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointSite" } )]
        [string] $SharepointSite,
        
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointTPIList" } )]
        [string] $SharepointTPIList,

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointNumberRangeList" } )]
        [String] $SharepointNumberRangeList,

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointExtensionRangeList" } )]
        [String] $SharepointExtensionRangeList,

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLegacyList" } )]
        [String] $SharepointLegacyList,
        
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointBlockExtensionList" } )]
        [String] $SharepointBlockExtensionList,

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLocationDefaultsList" } )]
        [String] $SharepointLocationDefaultsList,

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLocationMappingList" } )]
        [String] $SharepointLocationMappingList,

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointUserMappingList" } )]
        [String] $SharepointUserMappingList,

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.BlockExtensionDays" } )]
        [int] $BlockExtensionDays,

        # CallerName is tracked purely for auditing purposes
        [string] $CallerName
)

########################################################
##             Variable/Parameter declaration
##          
########################################################

# Define RunMode
# Possible Values - "AppBased", "Runbook" or "RealmJoinRunbook"
# Functions has to be replaced to the regarding RunMode variants
$RunMode = "RealmJoinRunbook"

########################################################
##             function declaration
##          
########################################################
function Get-TPIList {
    param (
        [parameter(Mandatory = $true)]
        [String]
        $ListBaseURL,
        [parameter(Mandatory = $false)]
        [String]
        $ListName # Only for easier logging
    )
    
    #Get fresh status quo of the SharePoint List after updating
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - GraphAPI - Get fresh StatusQuo of the SharePoint List $ListName"

    #Setup URL variables
    $GraphAPIUrl_StatusQuoSharepointList = $ListBaseURL + '/items'

    $AllItemsResponse = Invoke-RjRbRestMethodGraph -Resource $GraphAPIUrl_StatusQuoSharepointList -Method Get -UriQueryRaw 'expand=columns,items(expand=fields)' -FollowPaging
    $AllItems = $AllItemsResponse.fields

    return $AllItems

}

function Invoke-TPIRestMethod {
    param (
        [parameter(Mandatory = $true)]
        [String]
        $Uri,
        [parameter(Mandatory = $true)]
        [String]
        $Method,
        [parameter(Mandatory = $false)]
        [hashtable]
        $Body,
        [parameter(Mandatory = $true)]
        [String]
        $ProcessPart,
        [parameter(Mandatory = $false)]
        [String]
        $SkipThrow = $false
        
    )

    #ToFetchErrors (Throw)
    $ExitError = 0

    if (($Method -like "Post") -or ($Method -like "Patch")) {
        try {
            $TPIRestMethod = Invoke-RjRbRestMethodGraph -Resource $Uri -Method $Method -Body $Body
        }
        catch {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output ""
            Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart"
            $StatusCode = $_.Exception.Response.StatusCode.value__ 
            $StatusDescription = $_.Exception.Response.ReasonPhrase
            Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
            Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
            Write-Output ""

            Write-Output "$TimeStamp - GraphAPI - One Retry after 5 seconds"
            Connect-RjRbGraph -Force
            Start-Sleep -Seconds 5
            try {
                $TPIRestMethod = Invoke-RjRbRestMethodGraph -Resource $Uri -Method $Method -Body $Body
                Write-Output "$TimeStamp - GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
            } catch {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                # $2ndLastError = $_.Exception
                $ExitError = 1
                $StatusCode = $_.Exception.Response.StatusCode.value__ 
                $StatusDescription = $_.Exception.Response.ReasonPhrase
                Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present!"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
                Write-Output ""
                $ExitError = 1
            } 
        }
    }else{
        try {
            #$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            #Write-Output "$TimeStamp - Uri $Uri -Method $Method : $ProcessPart"
            $TPIRestMethod = Invoke-RjRbRestMethodGraph -Resource $Uri -Method $Method
        }
        catch {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output ""
            Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart"
            $StatusCode = $_.Exception.Response.StatusCode.value__ 
            $StatusDescription = $_.Exception.Response.ReasonPhrase
            Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
            Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
            Write-Output ""
            Write-Output "$TimeStamp - GraphAPI - One Retry after 5 seconds"
            Connect-RjRbGraph -Force
            Start-Sleep -Seconds 5
            try {
                $TPIRestMethod = Invoke-RjRbRestMethodGraph -Resource $Uri -Method $Method
                Write-Output "$TimeStamp - GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
            } catch {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                # $2ndLastError = $_.Exception
                $ExitError = 1
                $StatusCode = $_.Exception.Response.StatusCode.value__ 
                $StatusDescription = $_.Exception.Response.ReasonPhrase
                Write-Output "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present!"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusCode: $StatusCode"
                Write-Output "$TimeStamp - GraphAPI - Error! StatusDescription: $StatusDescription"
                Write-Output ""
            } 
        }
    }

    if ($ExitError -eq 1) {
        throw "$TimeStamp - GraphAPI - Error! Process part: $ProcessPart error is still present! StatusCode: $StatusCode StatusDescription: $StatusDescription"
        $StatusCode = $null
        $StatusDescription = $null
    }

    return $TPIRestMethod
    
}

########################################################
##             Logo Part
##          
########################################################

Write-Output ''
Write-Output ' _____                                      ____    _                                ___                                  _                          '
Write-Output '|_   _|   ___    __ _   _ __ ___    ___    |  _ \  | |__     ___    _ __     ___    |_ _|  _ __   __   __   ___   _ __   | |_    ___    _ __   _   _ '
Write-Output '  | |    / _ \  / _` | |  _ ` _ \  / __|   | |_) | |  _ \   / _ \  |  _ \   / _ \    | |  |  _ \  \ \ / /  / _ \ |  _ \  | __|  / _ \  |  __| | | | |'
Write-Output '  | |   |  __/ | (_| | | | | | | | \__ \   |  __/  | | | | | (_) | | | | | |  __/    | |  | | | |  \ V /  |  __/ | | | | | |_  | (_) | | |    | |_| |'
Write-Output '  |_|    \___|  \__,_| |_| |_| |_| |___/   |_|     |_| |_|  \___/  |_| |_|  \___|   |___| |_| |_|   \_/    \___| |_| |_|  \__|  \___/  |_|     \__, |'
Write-Output '                                                                                                                                               |___/ '
Write-Output ''


########################################################
##             Connect Part
##          
########################################################
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

# Initiate RealmJoin Graph Session
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Initiate RealmJoin Graph Session"
Connect-RjRbGraph

# Add Caller in Verbose output
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SharepointURL: '$SharepointURL'" -Verbose
Write-RjRbLog -Message "SharepointSite: '$SharepointSite'" -Verbose
Write-RjRbLog -Message "SharepointTPIList: '$SharepointTPIList'" -Verbose
Write-RjRbLog -Message "SharepointNumberRangeList: '$SharepointNumberRangeList'" -Verbose
Write-RjRbLog -Message "SharepointExtensionRangeList: '$SharepointExtensionRangeList'" -Verbose
Write-RjRbLog -Message "SharepointLegacyList: '$SharepointLegacyList'" -Verbose
Write-RjRbLog -Message "SharepointBlockExtensionList: '$SharepointBlockExtensionList'" -Verbose
Write-RjRbLog -Message "SharepointLocationDefaultsList: '$SharepointLocationDefaultsList'" -Verbose
Write-RjRbLog -Message "SharepointLocationMappingList: '$SharepointLocationMappingList'" -Verbose
Write-RjRbLog -Message "SharepointUserMappingList: '$SharepointUserMappingList'" -Verbose
Write-RjRbLog -Message "BlockExtensionDays: '$BlockExtensionDays'" -Verbose


########################################################
##             End Region - Customization depending on the implemented version
##             Current Version: RJ Runbook
##
########################################################################################################################################################################
#endregion

#region RampUp Connection Details
########################################################
##             Block 0 - RampUp Connection Details
##          
########################################################


if ($RunMode -like "AppBased") {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Connection - Check if GraphAPI token and Teams PowerShell session belong to the same tenant" 
    #Check if GraphAPI token and Teams PowerShell session belong to the same tenant
    $TeamsTenantDomains = (Get-CsTenant).Domains
    if ($TeamsTenantDomains -notcontains $global:TenantDomainName) {
        if ($TeamsTenantDomains -like "") {
            $TeamsTenantDomains = (Get-CsTenant).VerifiedDomains.Name
            if ($TeamsTenantDomains -notcontains $global:TenantDomainName) {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                Write-Error "$TimeStamp - The tenant to which the Teams Powershell session was built does not contain the tenant domain used for GraphAPI - also even not as a verified Domain! Stopping script now!"
                Exit   
            }
        }else {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Warning "$TimeStamp - The tenant to which the Teams Powershell session was built does not contain the tenant domain used for GraphAPI."   
        }
    }
}

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Check basic connection to TPI List"

# Setup Base URL - not only for NumberRange etc.
if (($RunMode -like "AppBased") -or ($RunMode -like "Runbook")) {
    $BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/teams/' + $SharepointSite + ':/lists/'
}else{
    $BaseURL = '/sites/' + $SharepointURL + ':/teams/' + $SharepointSite + ':/lists/' 
}
$TPIListURL = $BaseURL + $SharepointTPIList
try {
    Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" -ErrorAction Stop | Out-Null
}
catch {
    if (($RunMode -like "AppBased") -or ($RunMode -like "Runbook")) {
        $BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/sites/' + $SharepointSite + ':/lists/'
    }else{
        $BaseURL = '/sites/' + $SharepointURL + ':/sites/' + $SharepointSite + ':/lists/' 
    }
    $TPIListURL = $BaseURL + $SharepointTPIList
    try {
        Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" | Out-Null
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

#region Number + Extensionrange
########################################################
##             Block 1 - Number + Extensionrange
##          
########################################################

# # Block 1
#  - Arrays aufbauen
#  - ExtensionRange Array
#  - NumberRange Array

#Setup URL for NumberRange, ExtensionRange& Legacy List
$NumberRangeListURL = $BaseURL + $SharepointNumberRangeList
$ExtensionRangeListURL = $BaseURL + $SharepointExtensionRangeList


$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 1 - RampUp: Get content from NumberRange, ExtensionRange & Legacy List"

#Get List for NumberRange, ExtensionRange & Legacy List 
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Get StatusQuo of NumberRange SharePoint List - ListName: $SharepointNumberRangeList"
$NumberRangeList = Get-TPIList -ListBaseURL $NumberRangeListURL -ListName $SharepointNumberRangeList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Get StatusQuo of ExtensionRange SharePoint List - ListName: $SharepointExtensionRangeList"
$ExtensionRangeList = Get-TPIList -ListBaseURL $ExtensionRangeListURL -ListName $SharepointExtensionRangeList

#region Transfer Response into an Arrays (easier handling)
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Transfer NumberRange Response into an Array"

[System.Collections.ArrayList]$NumberRanges = @()

foreach ($NumberRangeItem in $NumberRangeList) {
    $TMPNumberRangeIndex = $NumberRangeItem.Title -replace $null,""
    $TMPNumberRangeName = $NumberRangeItem.NumberRangeName -replace $null,""
    $TMPMainNumber = $NumberRangeItem.MainNumber -replace $null,""
    $TMPBeginNumberRange = $NumberRangeItem.BeginNumberRange -replace $null,""
    $TMPEndNumberRange = $NumberRangeItem.EndNumberRange -replace $null,""
    $TMPCountry = $NumberRangeItem.Country -replace $null,""
    $TMPCity = $NumberRangeItem.City -replace $null,""
    $TMPCompany = $NumberRangeItem.Company -replace $null,""
    
    # Check for empty elements
    if (($TMPNumberRangeIndex -notlike "") -and ($TMPNumberRangeName -notlike "") -and ($TMPMainNumber -notlike "") -and ($TMPBeginNumberRange -notlike "") -and ($TMPEndNumberRange -notlike "")) {
        $NewRow += [pscustomobject]@{'NumberRangeIndex'=$TMPNumberRangeIndex;'NumberRangeName'=$TMPNumberRangeName;'MainNumber'=$TMPMainNumber;'BeginNumberRange'=$TMPBeginNumberRange;'EndNumberRange'=$TMPEndNumberRange;'Country'=$TMPCountry;'City'=$TMPCity;'Company'=$TMPCompany}
        $NumberRanges += $NewRow
    }
    
    $NewRow = $null    
    $TMPNumberRangeIndex = $null
    $TMPNumberRangeName = $null
    $TMPMainNumber = $null
    $TMPBeginNumberRange = $null
    $TMPEndNumberRange = $null
    $TMPCountry = $null
    $TMPCity = $null
    $TMPCompany = $null
}

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Transfer ExtensionRange Response into an Array"
#Transfer Response into an Array (easier handling)
[System.Collections.ArrayList]$ExtensionRanges = @()

foreach ($ExtensionRangeItem in $ExtensionRangeList ) {
    $TMPExtensionRangeIndex = $ExtensionRangeItem.Title -replace $null,""
    $TMPExtensionRangeName = $ExtensionRangeItem.ExtensionRangeName -replace $null,""
    $TMPBeginExtensionRange = $ExtensionRangeItem.BeginExtensionRange -replace $null,""
    $TMPEndExtensionRange = $ExtensionRangeItem.EndExtensionRange -replace $null,""
    $TMPNumberRangeIndex = $ExtensionRangeItem.NumberRangeIndex -replace $null,""

    # Check for empty elements
    if (($TMPExtensionRangeIndex -notlike "") -and ($TMPExtensionRangeName -notlike "") -and ($TMPBeginExtensionRange -notlike "")-and ($TMPEndExtensionRange -notlike "")-and ($TMPNumberRangeIndex -notlike "")) {
        $NewRow += [pscustomobject]@{'ExtensionRangeIndex'=$TMPExtensionRangeIndex;'ExtensionRangeName'=$TMPExtensionRangeName;'BeginExtensionRange'=$TMPBeginExtensionRange;'EndExtensionRange'=$TMPEndExtensionRange;'NumberRangeIndex'=$TMPNumberRangeIndex;}
        $ExtensionRanges += $NewRow
    }
 
    $NewRow = $null    
    $TMPExtensionRangeIndex = $null
    $TMPExtensionRangeName = $null
    $TMPBeginExtensionRange = $null
    $TMPEndExtensionRange = $null
    $TMPNumberRangeIndex = $null
}
#endregion

#region Check Extension Ranges
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Check if there are errors in the number or extension ranges (e.g. extension 90 to 10 (values swapped))"

foreach ($NumberRange in $NumberRanges) {
    if($NumberRange.BeginUserRange -gt $NumberRange.EndUserRange){
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the NumberRange: "@($NumberRange.NumberRangeName)
        Write-Error "$TimeStamp - Block 1 - The start extension is greater than the end extension. This will terminate the script."
        Start-Sleep -Seconds 5
        Exit
    }
    if ($NumberRange.EndUserRange.Length -lt $NumberRange.BeginUserRange.Length) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the NumberRange: "@($NumberRange.NumberRangeName)
        Write-Error "$TimeStamp - Block 1 - The Start NumberRange is longer than the End NumberRange! This will terminate the script."
        Start-Sleep -Seconds 5
        Exit
    }
}

foreach ($ExtensionRange in $ExtensionRanges) {
    [int]$StartNumber = $ExtensionRange.BeginExtensionRange
    [int]$EndNumber = $ExtensionRange.EndExtensionRange
    $Name = $ExtensionRange.ExtensionRangeName
    if($StartNumber -gt $EndNumber){
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the ExtensionRange: $Name"
        Write-Error "$TimeStamp - Block 1 - The start extension is greater than the end extension! This will terminate the script."
        Start-Sleep -Seconds 5
        Exit
    }
    if ($EndNumber.Length -lt $StartNumber.Length) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the ExtensionRange: $Name"
        Write-Error "$TimeStamp - Block 1 - The Start ExtensionRange is longer than the End ExtensionRange! This will terminate the script."
        Start-Sleep -Seconds 5
        Exit
    }

}
#endregion

#region Fill Up MainArray (ExtensionRange)
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - List all numbers in defined Extension Ranges and fill MainArray"
[System.Collections.ArrayList]$MainArray = @()

$CounterExtensionRange = $ExtensionRanges.Count
$Counter = 0

foreach ($ExtensionRange in $ExtensionRanges) {
    if ($RunMode -like "AppBased") {
        $Counter++
        $ProgressPercent = [math]::Round((($Counter/$CounterExtensionRange)*100))
        Write-Progress -Activity "List all Numbers in defined Extension Ranges (Update per Range):" -Status "$ProgressPercent% Done" -PercentComplete $ProgressPercent
    }
    $StartNumber = $ExtensionRange.BeginExtensionRange
    $EndNumber = $ExtensionRange.EndExtensionRange
    $ExtensionRangeName = $ExtensionRange.ExtensionRangeName
    $CurrentNumberRangeIndex = $ExtensionRange.NumberRangeIndex
    $CurrentExtensionRangeIndex = $ExtensionRange.ExtensionRangeIndex
    foreach ($NumberRange in $NumberRanges) {
        if ($NumberRange.NumberRangeIndex -like $CurrentNumberRangeIndex) {
            $Country = $NumberRange.Country
            $City = $NumberRange.City
            $Company = $NumberRange.Company
            $NumberRangeName = $NumberRange.NumberRangeName
            $CurrentMainNumber =  $NumberRange.MainNumber
            
            $StartNumber..$EndNumber |ForEach-Object {
                $CurrentExtension = $_.toString().PadLeft(($EndNumber.toString().Length),'0')
                $CurrentLineUri = $CurrentMainNumber + $CurrentExtension
                if ($MainArray.LineUri -notcontains $CurrentLineUri) {
                    $NewRow += [pscustomobject]@{'FullLineUri'=$CurrentLineUri;'MainLineUri'=$CurrentLineUri;'DID'=$CurrentExtension;'TeamsEXT'='';'NumberRangeName'=$NumberRangeName;'ExtensionRangeName'=$ExtensionRangeName;'UPN'='';'Display_Name'='';'OnlineVoiceRoutingPolicy'='';'TeamsCallingPolicy'='';'DialPlan'='';'TenantDialPlan'='';'VoiceType'='';'UserType'='';'NumberRangeIndex'=$CurrentNumberRangeIndex;'ExtensionRangeIndex'=$CurrentExtensionRangeIndex;'Country'=$Country;'City'=$City;'Company'=$Company;'Status'=''}
                    $MainArray += $NewRow
                    $NewRow = $null  
                }else {
                    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                    Write-Error "$TimeStamp - Error - $CurrentLineUri from Current Extension Range $ExtensionRangeName is already in MainArray - Extension Range duplicate or overlap!"
                }  
            }
        }
    }        
}
if ($RunMode -like "AppBased") {
    Write-Progress -Completed -Activity "List all numbers completed"
}
#endregion

#region Fill the NumberRangeArray with every single extension of the entire number ranges
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Fill the NumberRangeArray with every single extension of the entire number ranges"
[System.Collections.ArrayList]$NumberRangeArray = @()

$CounterNumberRange = $NumberRanges.Count
$NRCounter = 0
$Counter = 0

foreach ($NumberRange in $NumberRanges) {
    if ($RunMode -like "AppBased") {
        $NRCounter++
        $ProgressPercent = [math]::Round((($NRCounter/$CounterNumberRange)*100))
        Write-Progress -Activity "Fill the number range array with every single extension of the entire number ranges:" -Status "$ProgressPercent% Done" -PercentComplete $ProgressPercent -ErrorAction Stop
    }

    if ($NumberRange.MainNumber -contains $MultipleMainNumber) {
        Write-Output "ja"
        $NumberRange.MainNumber
    }
    
    $CurrentNumberRangeIndex = $NumberRange.NumberRangeIndex
    $CurrentName = $NumberRange.NumberRangeName
    $CurrentMainNumber =  $NumberRange.MainNumber
    $CurrentStartNumber = $NumberRange.BeginNumberRange
    $CurrentEndNumber = $NumberRange.EndNumberRange
    $CurrentCountry = $NumberRange.Country
    $CurrentCity = $NumberRange.City
    $CurrentCompany = $NumberRange.Company

    $EndNumberDigits = $CurrentEndNumber.ToString().Length 

    if ($CurrentStartNumber -le $CurrentEndNumber ) {
        if ( $CurrentStartNumber -ne $CurrentEndNumber ) {
            $Counter = 0
            do { 
                $Counter = $Counter + 1
                $Digits = '0' * $Counter
                $CounterMin = '0' * $Counter
                $CounterMax = '9' * $Counter
                if ([int]$CounterMax -gt $CurrentEndNumber) {
                    $CounterMax = $CurrentEndNumber
                }
                if ([int]$CounterMin -lt $CurrentStartNumber) {
                    $CounterMin = $CurrentStartNumber
                }

                
                #$CounterMin..$CounterMax

                $CounterMin..$CounterMax |ForEach-Object {
                    $CurrentExtension = $_.ToString($Digits)
                    $CurrentLineUri = $CurrentMainNumber + $CurrentExtension
                    $NewRow += [pscustomobject]@{'NumberRangeIndex'=$CurrentNumberRangeIndex;'NumberRangeName'=$CurrentName;'LineUri'=$CurrentLineUri;'DID'=$CurrentExtension;'Country'=$CurrentCountry;'City'=$CurrentCity;'Company'=$CurrentCompany}
                    $NumberRangeArray += $NewRow
                    $NewRow = $null                    
                }

            } while ($Counter -lt $EndNumberDigits)
  
        }else {
            #Start and End number is the same, so there is only one extension
            $CurrentExtension = $CurrentStartNumber
            $CurrentLineUri = $CurrentMainNumber + $CurrentExtension
            $NewRow += [pscustomobject]@{'NumberRangeIndex'=$CurrentNumberRangeIndex;'NumberRangeName'=$CurrentName;'LineUri'=$CurrentLineUri;'DID'=$CurrentExtension;'Country'=$CurrentCountry;'City'=$CurrentCity;'Company'=$CurrentCompany}
            $NumberRangeArray += $NewRow
            $NewRow = $null   
        }
        
    }
    else {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output ""
        Write-Output "$TimeStamp - Block 1  - Error: Start Number is greater than End Number" 
        Write-Output "$TimeStamp - Block 1  - Current Number Range: $CurrentName"
    }    
}

if ($RunMode -like "AppBased") {
    Write-Progress -Completed -Activity "Finished Helper Array (Whole Number Range)"
}

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Finished Helper Array (Whole Number Range)"
#endregion

#endregion

#region Teams
########################################################
##             Block 2 - Teams
##          
########################################################

# # Block 2 Teams
# - User abrufen
# - Foreach -> Merge in Main Array
#     - not in Main Array -> Add Entry

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 2 - Retrieve all Microsoft Teams Users, which have an LineUri"
$AllTeamsUser = Get-CsOnlineUser | Where-Object LineUri -NotLike "" | Select-Object DisplayName,UserPrincipalName,LineUri,TeamsCallingPolicy,OnlineVoiceRoutingPolicy,InterpretedUserType,EnterpriseVoiceEnabled,HostingProvider,DialPlan,TenantDialPlan,AssignedPlan

$CounterAllTeamsUser = ($AllTeamsUser | Measure-Object).Count
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Received Microsoft Teams Users, which have an LineUri: $CounterAllTeamsUser"

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Retrieve all Microsoft Teams IP-Phone Policies"
$TeamsIPPhonePolicies = Get-CsTeamsIPPhonePolicy

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Merge all collected Microsoft Teams User in the main array"

$Counter = 0

if ($CounterAllTeamsUser -gt 0) {
    # Merge Teams Users into the main array
    foreach ($TeamsUser in $AllTeamsUser) {
        if ($RunMode -like "AppBased") {
            $Counter++
            $ProgressPercent = [math]::Round((($Counter/$CounterAllTeamsUser)*100))
            Write-Progress -Activity "Merge all collected Microsoft Teams User in the main array:" -Status "$ProgressPercent% Done" -PercentComplete $ProgressPercent
        }

        # Cut off tel: prefix
        if ($TeamsUser.LineUri.StartsWith('tel:')) {
            $Teams_LineUri = $TeamsUser.LineUri.Substring(4,($TeamsUser.LineUri.Length -4))
            if (!($Teams_LineUri.StartsWith('+'))) {
                $Teams_LineUri = '+' + $($Teams_LineUri -replace $null,"")
            }
        }else{
            #Check if number start with '+' - if not - add it
            if (!($TeamsUser.LineUri.StartsWith('+'))) {
                $Teams_LineUri = '+' + $($TeamsUser.LineUri -replace $null,"")
            }
        }

        # Check if LineUri contains an extension
        if($Teams_LineUri -like '*;ext=*') {
            $Teams_LineUri_Extension = $Teams_LineUri.Substring(($Teams_LineUri.IndexOf(';')+1),($Teams_LineUri.Length-($Teams_LineUri.IndexOf(';')+1))).Replace("ext=","")
            $Teams_MainLineUri = $Teams_LineUri.Substring(0,$Teams_LineUri.IndexOf(';')) #Cut off Extensions - +49432156789;ext=789 -> finallly +49432156789
            $Teams_FullLineUri = $Teams_LineUri
        }else {
            $Teams_FullLineUri = $Teams_LineUri
            $Teams_MainLineUri = $Teams_LineUri
            $Teams_LineUri_Extension = ""
        }

        $Teams_UPN = $TeamsUser.UserPrincipalName -replace $null,""
        $Teams_DisplayName = $TeamsUser.DisplayName -replace $null,""
        
        # During tests it was noticed in some tenants that the return value differs from tenant to tenant
        # For some tenants the name of the policy could be retrieved directly, for some it has to be differentiated again by .name
        if($TeamsUser.OnlineVoiceRoutingPolicy.PSObject.Properties.Name -contains "Authority"){
            $Teams_OnlineVoiceRoutingPolicy = $TeamsUser.OnlineVoiceRoutingPolicy.Name -replace $null,""
        }else {
            $Teams_OnlineVoiceRoutingPolicy = $TeamsUser.OnlineVoiceRoutingPolicy -replace $null,""
        }

        if($TeamsUser.TeamsCallingPolicy.PSObject.Properties.Name -contains "Authority"){
            $Teams_TeamsCallingPolicy = $TeamsUser.TeamsCallingPolicy.Name -replace $null,""
        }else {
            $Teams_TeamsCallingPolicy = $TeamsUser.TeamsCallingPolicy -replace $null,""
        }

        if($TeamsUser.DialPlan.PSObject.Properties.Name -contains "Authority"){
            $Teams_DialPlan = $TeamsUser.DialPlan.Name -replace $null,""
        }else {
            $Teams_DialPlan = $TeamsUser.DialPlan -replace $null,""
        }

        if($TeamsUser.TenantDialPlan.PSObject.Properties.Name -contains "Authority"){
            $Teams_TenantDialPlan = $TeamsUser.TenantDialPlan.Name -replace $null,""
        }else {
            $Teams_TenantDialPlan = $TeamsUser.TenantDialPlan -replace $null,""
        }

        # Define Entry Voice Type
        if ($TeamsUser.InterpretedUserType -like "*ApplicationInstance*") {
            $Teams_VoiceType = "ResourceAccount"
        }elseif ($TeamsUser.LineURI -notlike "") {
            if ($TeamsUser.InterpretedUserType -like "HybridOnPremSfBUserWithTeamsLicense") {
                $Teams_VoiceType = "SkypeForBusiness"
                #Alternative via Hostingprovider SRV: instead of sipfed.online.lync.com
            }else{
                if ($TeamsUser.EnterpriseVoiceEnabled -eq $true) {
                    #Reply of this is different from Tenant to Tenant
                    foreach ($XMLEntry in $TeamsUser.AssignedPlan) {
                        try {
                            if ((([xml]$XMLEntry).XmlValueAssignedPlan.Plan.Capability.Capability.Plan) -like "MCOPSTN*") {
                                $Teams_VoiceType = "CallingPlan"
                            }
                        }catch {                           
                        }
                    }
                    #Reply of this is different from Tenant to Tenant
                    if($TeamsUser.AssignedPlan.Capability -contains "MCOPSTN"){
                        $Teams_VoiceType = "CallingPlan"
                    }
                    
                    if ($Teams_VoiceType -notlike "CallingPlan") {
                        $Teams_VoiceType = "DirectRouting"
                    }
                }else {
                    $Teams_VoiceType = "ActiveDirectory-Legacy"
                }   
            }
        }else {
            $Teams_VoiceType = "CallingPlan"
        }

        # Define Entry User Type
        if ($TeamsUser.TeamsIPPhonePolicy.Name -like "") {
            $TMPUserTeamsIPPhonePolicy = "Global"
        }else {
            $TMPUserTeamsIPPhonePolicy = "Tag:"+ $TeamsUser.TeamsIPPhonePolicy.Name
        }
        
        if (($TeamsUser.AssignedPlan.Capability -contains "MCOCAP") -or ($($TeamsIPPhonePolicies | Where-Object Identity -Like  $TMPUserTeamsIPPhonePolicy).SignInMode -like "CommonAreaPhoneSignIn")) {
            $Teams_UserType = "CommonAreaPhone"
        }elseif (($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Standard") -or ($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Basic") -or ($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Pro") -or ($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Premium")) {
            $Teams_UserType = "MeetingRoom"
        }else {
            $Teams_UserType = "DefaultUser"
        }

        #Check if FullLineUri Already in MainArray
        if ($MainArray.FullLineUri -contains $Teams_FullLineUri) {
            $ArrayIndex = [array]::indexof($MainArray.FullLineUri,$Teams_FullLineUri)
            $MainArray[$ArrayIndex].Display_Name = $Teams_DisplayName
            $MainArray[$ArrayIndex].OnlineVoiceRoutingPolicy = $Teams_OnlineVoiceRoutingPolicy
            $MainArray[$ArrayIndex].TeamsCallingPolicy = $Teams_TeamsCallingPolicy
            $MainArray[$ArrayIndex].DialPlan = $Teams_DialPlan
            $MainArray[$ArrayIndex].TenantDialPlan = $Teams_TenantDialPlan
            $MainArray[$ArrayIndex].VoiceType = $Teams_VoiceType
            $MainArray[$ArrayIndex].UserType = $Teams_UserType
            $MainArray[$ArrayIndex].UPN = $Teams_UPN
            
        }elseif($MainArray.MainLineUri -contains $Teams_MainLineUri) { #If not, check if Main LineUri - so without Teams Ext - is in Main Array included
            $ArrayIndex = [array]::indexof($MainArray.MainLineUri,$Teams_MainLineUri) | Select-Object -First 1
            
            $CurrentDID = $MainArray[$ArrayIndex].DID -replace $null,""
            $CurrentNumberRangeName = $MainArray[$ArrayIndex].NumberRangeName -replace $null,""
            $CurrentExtensionRangeName = $MainArray[$ArrayIndex].ExtensionRangeName -replace $null,""
            $CurrentNumberRangeIndex = $MainArray[$ArrayIndex].NumberRangeIndex -replace $null,""
            $CurrentExtensionRangeIndex = $MainArray[$ArrayIndex].ExtensionRangeIndex -replace $null,""
            $CurrentCountry = $MainArray[$ArrayIndex].Country -replace $null,""
            $CurrentCity = $MainArray[$ArrayIndex].City -replace $null,""
            $CurrentCompany = $MainArray[$ArrayIndex].Company -replace $null,""

            $NewRow += [pscustomobject]@{'FullLineUri'=$Teams_FullLineUri;'MainLineUri'=$Teams_MainLineUri;'DID'=$CurrentDID;'TeamsEXT'=$Teams_LineUri_Extension;'NumberRangeName'=$CurrentNumberRangeName;'ExtensionRangeName'=$CurrentExtensionRangeName;'UPN'=$Teams_UPN;'Display_Name'=$Teams_DisplayName;'OnlineVoiceRoutingPolicy'=$Teams_OnlineVoiceRoutingPolicy;'TeamsCallingPolicy'=$Teams_TeamsCallingPolicy;'DialPlan'=$Teams_DialPlan;'TenantDialPlan'=$Teams_TenantDialPlan;'VoiceType'=$Teams_VoiceType;'UserType'=$Teams_UserType;'NumberRangeIndex'=$CurrentNumberRangeIndex;'ExtensionRangeIndex'=$CurrentExtensionRangeIndex;'Country'=$CurrentCountry;'City'=$CurrentCity;'Company'=$CurrentCompany;'Status'=''}
            $MainArray += $NewRow
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentExtensionRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow")
            
        }elseif($NumberRangeArray.LineUri -contains $Teams_MainLineUri) { #If not, check if LineUri is in NumberRangeArray included
            $ArrayIndex = [array]::indexof($NumberRangeArray.LineUri,$Teams_MainLineUri)
            
            $CurrentDID = $NumberRangeArray[$ArrayIndex].DID -replace $null,""
            $CurrentNumberRangeName = $NumberRangeArray[$ArrayIndex].NumberRangeName -replace $null,""
            $CurrentNumberRangeIndex = $NumberRangeArray[$ArrayIndex].NumberRangeIndex -replace $null,""
            $CurrentCountry = $NumberRangeArray[$ArrayIndex].Country -replace $null,""
            $CurrentCity = $NumberRangeArray[$ArrayIndex].City -replace $null,""
            $CurrentCompany = $NumberRangeArray[$ArrayIndex].Company -replace $null,""

            $NewRow += [pscustomobject]@{'FullLineUri'=$Teams_FullLineUri;'MainLineUri'=$Teams_MainLineUri;'DID'=$CurrentDID;'TeamsEXT'=$Teams_LineUri_Extension;'NumberRangeName'=$CurrentNumberRangeName;'ExtensionRangeName'='NoneDefined';'UPN'=$Teams_UPN;'Display_Name'=$Teams_DisplayName;'OnlineVoiceRoutingPolicy'=$Teams_OnlineVoiceRoutingPolicy;'TeamsCallingPolicy'=$Teams_TeamsCallingPolicy;'DialPlan'=$Teams_DialPlan;'TenantDialPlan'=$Teams_TenantDialPlan;'VoiceType'=$Teams_VoiceType;'UserType'=$Teams_UserType;'NumberRangeIndex'=$CurrentNumberRangeIndex;'ExtensionRangeIndex'='NoneDefined';'Country'=$CurrentCountry;'City'=$CurrentCity;'Company'=$CurrentCompany;'Status'=''}
            $MainArray += $NewRow
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow")
            
        }else { #If not add Entry as a new MainArray entry
            $NewRow += [pscustomobject]@{'FullLineUri'=$Teams_FullLineUri;'MainLineUri'=$Teams_MainLineUri;'DID'='NoneDefined';'TeamsEXT'=$Teams_LineUri_Extension;'NumberRangeName'='NoneDefined';'ExtensionRangeName'='NoneDefined';'UPN'=$Teams_UPN;'Display_Name'=$Teams_DisplayName;'OnlineVoiceRoutingPolicy'=$Teams_OnlineVoiceRoutingPolicy;'TeamsCallingPolicy'=$Teams_TeamsCallingPolicy;'DialPlan'=$Teams_DialPlan;'TenantDialPlan'=$Teams_TenantDialPlan;'VoiceType'=$Teams_VoiceType;'UserType'=$Teams_UserType;'NumberRangeIndex'='NoneDefined';'ExtensionRangeIndex'='NoneDefined';'Country'='NoneDefined';'City'='NoneDefined';'Company'='NoneDefined';'Status'=''}
            $MainArray += $NewRow
            $NewRow = $null
        }
        Clear-Variable -Name ("Teams_UPN","Teams_FullLineUri","Teams_MainLineUri","Teams_LineUri_Extension","Teams_VoiceType","Teams_UserType")
    }
    if ($RunMode -like "AppBased") {
        Write-Progress -Completed -Activity "Merge of Microsoft Teams User in the main array completed"
    }

}else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Error "$TimeStamp - Error: No Teams user, which has a LineUri, was found. The script will be terminated now!"
    Start-Sleep -Seconds 5
    Exit
}

$AllTeamsUser = $null

#endregion

#region Legacy
########################################################
##             Block 3 - Legacy & Duplicates
##          
########################################################

# # Block 3 Legacy
# - Read List
# - Merge in Main Array
#     - Duplicate?
#         - Add LineUri + UPN to Status
#     - not in Main Array -> Add Entry

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 3 - Merge all defined legacy phone numbers in the main array"


$LegacyListURL = $BaseURL + $SharepointLegacyList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 3 - Get StatusQuo of Legacy SharePoint List - ListName: $SharepointLegacyList"
$LegacyList = Get-TPIList -ListBaseURL $LegacyListURL -ListName $SharepointLegacyList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 3 - Transfer Legacy Response into an Array"
#Transfer Response into an Array (easier handling)
[System.Collections.ArrayList]$LegacyPhoneNumbers = @()

foreach ($LegacyItem in $LegacyList ) {
    $TMPLineUri = $LegacyItem.Title -replace $null,""
    $TMPLegacyName = $LegacyItem.LegacyName -replace $null,""
    
    # Check for empty elements
    if (($TMPLineUri -notlike "") -and ($TMPLegacyName -notlike "")) {
        $NewRow += [pscustomobject]@{'LineUri'=$TMPLineUri;'LegacyName'=$TMPLegacyName}
        $LegacyPhoneNumbers += $NewRow
    }

    
    $NewRow = $null    
    $TMPLineUri = $null
    $TMPLegacyName = $null
}
$LegacyList = $null

$CounterLegacyPhoneNumber = $LegacyPhoneNumbers.Count

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 3 - Received legacy phone numbers: $CounterLegacyPhoneNumber"

if ($CounterLegacyPhoneNumber -gt 0) {
    $Counter = 0

    #Create array for duplicates
    [System.Collections.ArrayList]$Duplicate = @()

    foreach ($LegacyPhoneNumber in $LegacyPhoneNumbers) {
        
        if ($RunMode -like "AppBased") {
            $Counter++
            $ProgressPercent = [math]::Round((($Counter/$CounterLegacyPhoneNumber)*100))
            Write-Progress -Activity "Merge all legacy phone numbers in the main array:" -Status "$ProgressPercent% Done" -PercentComplete $ProgressPercent
        }
        $Legacy_LineUri = $LegacyPhoneNumber.LineUri.Trim()
        $Legacy_DisplayName = $LegacyPhoneNumber.LegacyName
        $Legacy_Type = "LegacyPhoneNumber"

        if ($MainArray.FullLineUri -contains $Legacy_LineUri) {
            $ArrayIndex = [array]::indexof($MainArray.FullLineUri,$Legacy_LineUri)
            
            # Add LineUri and UPN to duplicate error, if LineUri is already assigned to a Teams User
            if ($MainArray[$ArrayIndex].UPN -notlike "") {
                $DuplicateUPN = $MainArray[$ArrayIndex].UPN
                $NewRow += [pscustomobject]@{'LineUri'=$Legacy_LineUri;'UPN'=$DuplicateUPN}
                $Duplicate += $NewRow
                $NewRow = $null
                $MainArray[$ArrayIndex].Status = 'DuplicateUPN_' + $DuplicateUPN + ';'
            }

            $MainArray[$ArrayIndex].Display_Name = $Legacy_DisplayName -replace $null,"" 
            $MainArray[$ArrayIndex].VoiceType = $Legacy_Type -replace $null,""
            $MainArray[$ArrayIndex].UPN = ""
            $MainArray[$ArrayIndex].OnlineVoiceRoutingPolicy = ""
            $MainArray[$ArrayIndex].TeamsCallingPolicy = ""
            $MainArray[$ArrayIndex].DialPlan = ""
            $MainArray[$ArrayIndex].TenantDialPlan = ""
            
        }elseif ($NumberRangeArray.LineUri -contains $Legacy_LineUri) {
            $ArrayIndex = [array]::indexof($NumberRangeArray.LineUri, $Legacy_LineUri)
            
            $CurrentDID = $NumberRangeArray[$ArrayIndex].DID -replace $null,""
            $CurrentNumberRangeName = $NumberRangeArray[$ArrayIndex].NumberRangeName -replace $null,""
            $CurrentNumberRangeIndex = $NumberRangeArray[$ArrayIndex].NumberRangeIndex -replace $null,""
            $CurrentCountry = $NumberRangeArray[$ArrayIndex].Country -replace $null,""
            $CurrentCity = $NumberRangeArray[$ArrayIndex].City -replace $null,""
            $CurrentCompany = $NumberRangeArray[$ArrayIndex].Company -replace $null,""

            $NewRow += [pscustomobject]@{'FullLineUri'=$Legacy_LineUri;'MainLineUri'=$Legacy_LineUri;'DID'=$CurrentDID;'TeamsEXT'='NoneDefined';'NumberRangeName'=$CurrentNumberRangeName;'ExtensionRangeName'='NoneDefined';'UPN'='NoneDefined';'Display_Name'=$Legacy_DisplayName;'OnlineVoiceRoutingPolicy'='NoneDefined';'TeamsCallingPolicy'='NoneDefined';'DialPlan'='NoneDefined';'TenantDialPlan'='NoneDefined';'VoiceType'=$Legacy_Type;'UserType'='NoneDefined';'NumberRangeIndex'=$CurrentNumberRangeIndex;'ExtensionRangeIndex'='NoneDefined';'Country'=$CurrentCountry;'City'=$CurrentCity;'Company'=$CurrentCompany;'Status'=''}
            $MainArray += $NewRow
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow")
            
        }else {
            $NewRow += [pscustomobject]@{'FullLineUri'=$Legacy_LineUri;'MainLineUri'=$Legacy_LineUri;'DID'='';'TeamsEXT'='';'NumberRangeName'='NoneDefined';'ExtensionRangeName'='NoneDefined';'UPN'='NoneDefined';'Display_Name'=$Legacy_DisplayName;'OnlineVoiceRoutingPolicy'='NoneDefined';'TeamsCallingPolicy'='NoneDefined';'DialPlan'='NoneDefined';'TenantDialPlan'='NoneDefined';'VoiceType'=$Legacy_Type;'UserType'='NoneDefined';'NumberRangeIndex'='NoneDefined';'ExtensionRangeIndex'='NoneDefined';'Country'='NoneDefined';'City'='NoneDefined';'Company'='NoneDefined';'Status'=''}
            $MainArray += $NewRow
            $NewRow = $null
        }

        $Legacy_LineUri = $null
        $Legacy_DisplayName = $null

    }

    if ($RunMode -like "AppBased") {
        Write-Progress -Completed -Activity "Merge of legacy phone numbers in the main array completed"
    }
}

$LegacyPhoneNumbers = $null
#endregion

#region BlockExtension - Check for outdated items
########################################################
##             Block 4 - BlockExtension - Check for outdated items
##          
########################################################

# # Block 4 BlockExtension - Check for outdated items
# - Read List BlockExtension
# - If outdated -> remove

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 4 - Check BlockExtension Table for outdated items"

#Setup List URL for GraphAPI call
$BlockExtensionListURL = $BaseURL + $SharepointBlockExtensionList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 4 - Get StatusQuo of NumberRange BlockExtension List - ListName: $SharepointBlockExtensionList"
$BlockExtensionList = Get-TPIList -ListBaseURL $BlockExtensionListURL -ListName $SharepointBlockExtensionList

#Define Date String for today
$NowString = (Get-Date).ToString('dd.MM.yyyy')
$NowDate = [datetime]::ParseExact($NowString, 'dd.MM.yyyy', $null)

foreach ($BlockListItem in $BlockExtensionList) {
    if ($($BlockListItem.Title) -notlike "") {
        $BlockItemDate = $BlockListItem.BlockUntil
        $NeedBlockItemUpdate = 0
        $DateValdidationError = 0
        $BlockItemLineUri = $BlockListItem.Title.Trim()
        $BlockItemReason = $BlockListItem.BlockReason
        if ($BlockItemDate -match '^[0-3][0-9][/.][0-3][0-9][/.](?:[0-9][0-9])?[0-9][0-9]$') { # Check if Date is correct (with leading zero - 01.02.2022)
            try {
                $ExpirationDate = ([datetime]::ParseExact($BlockItemDate, 'dd.MM.yyyy', $null))
            }
            catch {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                Write-Output ""
                Write-Output "$TimeStamp - Block 4 - Error: Date validation fail - Skip Entry $BlockItemLineUri - $BlockItemDate - $BlockItemReason"
                Write-Output ""
                $DateValdidationError = 1
            }
        
            if (($NowDate -gt $ExpirationDate) -and ($DateValdidationError -eq 0)) {
                $NeedBlockItemUpdate = 1
            }
        }elseif ($BlockItemDate -match '^[0-3]?[0-9][/.][0-3]?[0-9][/.](?:[0-9]{2})?[0-9]{2}$'){ # Check if Date is correct (without leading zero - 1.2.2022)
            $ConvertDate = $BlockItemDate.Split('.')
            $Day = $ConvertDate[0].PadLeft(2,'0')
            $Month = $ConvertDate[1].PadLeft(2,'0')
            $Year = $ConvertDate[2]
            if ($Year.Length -eq 2) {
                if ([int]$Year -gt 70) {
                    $Year = "19" + $Year
                }else{
                    $Year = "20" + $Year
                }
            }
            $BlockItemDate = $Day + '.' + $Month + '.' + $Year
            try {
                $ExpirationDate = ([datetime]::ParseExact($BlockItemDate, 'dd.MM.yyyy', $null))
            }
            catch {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                Write-Output ""
                Write-Output "$TimeStamp - Block 4 - Error: Date validation fail - Skip Entry $BlockItemLineUri - $BlockItemDate - $BlockItemReason"
                Write-Output ""
            }
            
        
            if (($ExpirationDate -gt $NowDate) -and ($DateValdidationError -eq 0)) {
                $NeedBlockItemUpdate = 1
            }
        
        }
        if ($NeedBlockItemUpdate -eq 1) {
            # Block item could be deleted
            $GraphAPIUrl_DeleteElement = $BlockExtensionListURL + '/items/'+ $BlockListItem.ID
            Write-Verbose "Delete Block Item $BlockItemLineUri Date: $BlockItemDate Reason: $BlockItemReason"
            $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_DeleteElement -Method Delete -ProcessPart "BlockExtension List: Delete item: $BlockItemLineUri"
            $GraphAPIUrl_DeleteElement = $null

        }
    }
}

$BlockExtensionList = $null

#endregion

#region BlockExtension
########################################################
##             Block 5 - BlockExtension
##          
########################################################

# # Block 5 BlockExtension
# - Read List BlockExtension
# - Merge in Main Array (Fill/Add Status)

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 5 - Blocked Extension Handling"

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 5 - Get fresh StatusQuo of NumberRange BlockExtension List - ListName: $SharepointBlockExtensionList"
$BlockExtensionList = Get-TPIList -ListBaseURL $BlockExtensionListURL -ListName $SharepointBlockExtensionList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 5 - Transfer blocked extensions into an Array"
#Transfer Response into an Array (easier handling)
[System.Collections.ArrayList]$BlockExtension = @()

foreach ($item in $BlockExtensionList ) {
    if ($item.Title -notlike "") {
        $TMPLineUri = $item.Title -replace $null,""
        $TMPLineUri = $TMPLineUri.Trim()
        $TMPBlockUntil = $item.BlockUntil -replace $null,""
        $TMPBlockReason = $item.BlockReason -replace $null,""
        $TMPStatus = 'BlockNumber_Until' + $TMPBlockUntil + '_Reason'+$TMPBlockReason+';'
        
        if ($TMPLineUri -notlike "") {
            $NewRow += [pscustomobject]@{'LineUri'=$TMPLineUri;'Status'=$TMPStatus;}
            $BlockExtension += $NewRow    
        } 
    
        $NewRow = $null    
        $TMPLineUri = $null
        $TMPBlockUntil = $null
        $TMPBlockReason = $null
    }
}

foreach ($BlockExtensionItem in $BlockExtension) {
    $BlockExtensionLineUri = $BlockExtensionItem.LineUri.Trim()
    $ArrayIndex = [array]::indexof($MainArray.FullLineUri,$BlockExtensionLineUri)
    $CurrentStatus = $MainArray[$ArrayIndex].Status
    $MainArray[$ArrayIndex].Status = $CurrentStatus + $BlockExtensionItem.Status
}

$BlockExtensionList = $null

#endregion

#region Compare + Update TPI List
########################################################
##             Block 6 - Compare + Update TPI List
##          
########################################################

# # Block 6 Compare 
# - Get TPI List
# - Transfer to Array
# - Compare-Object
#     - Add
#     - Update
#     - Delete

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - CleanUp - Clear Variable + free unused memory"
#Clear $NumberRangeArray for less memory usage before starting TPI read (huge amount of memory needed)
$NumberRangeArray = $null

# Try to clear unused memory
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
write-host "$TimeStamp - CleanUp - Memory used before collection: $([System.GC]::GetTotalMemory($false))"
[System.GC]::Collect()

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
write-host "$TimeStamp - CleanUp - Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
Start-Sleep -Seconds 15

#region Compare the MainArray with the SharePoint List to check if items in the list need to be updated
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 6 - Compare the MainArray with the SharePoint List"
Write-Output "$TimeStamp - Block 6 - Get StatusQuo of TPI SharePoint List - ListName: $SharepointTPIList"
$TPIList = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList | Select-Object Title,MainLineUri,DID,TeamsEXT,NumberRangeName,ExtensionRangeName,UPN,Display_Name,OnlineVoiceRoutingPolicy,TeamsCallingPolicy,DialPlan,TenantDialPlan,VoiceType,UserType,NumberRangeIndex,ExtensionRangeIndex,Country,City,Company,Status,id

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Transfer Response into an Array"
#Transfer Response into an Array (easier handling)
[System.Collections.ArrayList]$AllItemsArray = @()

foreach ($item in $TPIList) {
    $TMPNumberRangeName = $item.NumberRangeName -replace $null,""
    $TMPExtensionRangeName = $item.ExtensionRangeName -replace $null,""
    $TMPTitle = $item.Title -replace $null,""
    $TMPMainLineUri = $item.MainLineUri -replace $null,""
    $TMPDID = $item.DID -replace $null,""
    $TMPTeamsEXT = $item.TeamsEXT -replace $null,""
    $TMPUPN = $item.UPN -replace $null,""
    $TMPDisplay_Name = $item.Display_Name -replace $null,""
    $TMPOnlineVoiceRoutingPolicy = $item.OnlineVoiceRoutingPolicy -replace $null,""
    $TMPTeamsCallingPolicy = $item.TeamsCallingPolicy -replace $null,""
    $TMPDialPlan = $item.DialPlan -replace $null,""
    $TMPTenantDialPlan = $item.TenantDialPlan -replace $null,""
    $TMPVoiceType = $item.VoiceType -replace $null,""
    $TMPUserType = $item.UserType -replace $null,""
    $TMPNumberRangeIndex = $item.NumberRangeIndex -replace $null,""
    $TMPExtensionRangeIndex = $item.ExtensionRangeIndex -replace $null,""
    $TMPCountry = $item.Country -replace $null,""
    $TMPCity = $item.City -replace $null,""
    $TMPCompany = $item.Company -replace $null,""
    $TMPStatus = $item.Status -replace $null,""
    $TMPid = $item.id
    
    #Check for empty entries
    if ($TMPTitle -notlike "") {
        $NewRow += [pscustomobject]@{'FullLineUri'=$TMPTitle;'MainLineUri'=$TMPMainLineUri;'DID'=$TMPDID;'TeamsEXT'=$TMPTeamsEXT;'NumberRangeName'=$TMPNumberRangeName;'ExtensionRangeName'=$TMPExtensionRangeName;'UPN'=$TMPUPN;'Display_Name'=$TMPDisplay_Name;'OnlineVoiceRoutingPolicy'=$TMPOnlineVoiceRoutingPolicy;'TeamsCallingPolicy'=$TMPTeamsCallingPolicy;'DialPlan'=$TMPDialPlan;'TenantDialPlan'=$TMPTenantDialPlan;'VoiceType'=$TMPVoiceType;'UserType'=$TMPUserType;'NumberRangeIndex'=$TMPNumberRangeIndex;'ExtensionRangeIndex'=$TMPExtensionRangeIndex;'Country'=$TMPCountry;'City'=$TMPCity;'Company'=$TMPCompany;'Status'=$TMPStatus; 'id'=$TMPid}
        $AllItemsArray += $NewRow
    }
    
    Clear-Variable -Name ("NewRow","TMPMainLineUri","TMPTeamsEXT","TMPNumberRangeName","TMPExtensionRangeName","TMPid","TMPTitle","TMPDID","TMPUPN","TMPDisplay_Name","TMPOnlineVoiceRoutingPolicy","TMPTeamsCallingPolicy","TMPDialPlan","TMPTenantDialPlan","TMPVoiceType","TMPUserType","TMPNumberRangeIndex","TMPExtensionRangeIndex","TMPCountry","TMPCity","TMPCompany")
}

$TPIList = $null


$MainArrayCounter = $MainArray.Count
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Items in SharePoint List: $($AllItemsArray.Count)"

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Compare the MainArray with the SharePoint List to check if items in the list need to be updated"
$DifferentEntries = Compare-Object -ReferenceObject $MainArray -DifferenceObject $AllItemsArray -Property FullLineUri,MainLineUri,DID,TeamsEXT,NumberRangeName,ExtensionRangeName,UPN,Display_Name,OnlineVoiceRoutingPolicy,TeamsCallingPolicy,DialPlan,TenantDialPlan,VoiceType,UserType,NumberRangeIndex,ExtensionRangeIndex,Country,City,Company,Status | Where-Object SideIndicator -Like "<="
$NoUpdate = 0
$Counter = 0

if ($DifferentEntries.Count -gt 0) {
    $DifferentCounter = $DifferentEntries.Count
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Items in SharePoint List which need an update: $DifferentCounter"
    foreach ($Entry in $DifferentEntries) {
        if ($RunMode -like "AppBased") {
            $Counter = $Counter + 1
            $ProgressPercent = [math]::Round((($Counter/$DifferentCounter)*100))
            Write-Progress -Activity "Update of the SharePoint List via GraphAPI:" -Status "$ProgressPercent% Done" -PercentComplete $ProgressPercent
        }
        if ($AllItemsArray.FullLineUri -notcontains $Entry.FullLineUri) {
            #Add new element to the list
            $GraphAPIUrl = $TPIListURL + '/items'
            $CurrentLineUri = $Entry.FullLineUri
            $HTTPBody_NewElement = @{
                "fields" = @{
                    "Title"= $Entry.FullLineUri
                    "MainLineUri" = $Entry.MainLineUri
                    "DID"= $Entry.DID.ToString()
                    "TeamsEXT" = $Entry.TeamsEXT
                    "NumberRangeName" = $Entry.NumberRangeName
                    "ExtensionRangeName" = $Entry.ExtensionRangeName
                    "UPN"= $Entry.UPN
                    "Display_Name"= $Entry.Display_Name
                    "OnlineVoiceRoutingPolicy"= $Entry.OnlineVoiceRoutingPolicy
                    "TeamsCallingPolicy"= $Entry.TeamsCallingPolicy
                    "DialPlan"= $Entry.DialPlan
                    "TenantDialPlan"= $Entry.TenantDialPlan
                    "VoiceType"= $Entry.VoiceType
                    "UserType"= $Entry.UserType
                    "NumberRangeIndex"= $Entry.NumberRangeIndex
                    "ExtensionRangeIndex"= $Entry.ExtensionRangeIndex
                    "Country"= $Entry.Country
                    "City"= $Entry.City
                    "Company"= $Entry.Company
                    "Status"= $Entry.Status
                }
            }
            Write-Verbose "Add $($Entry.FullLineUri) Name: $($Entry.Display_Name) Type: $($Entry.VoiceType)"
            $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl -Method Post -Body $HTTPBody_NewElement -ProcessPart "TPI List - Add item: $CurrentLineUri"
            $HTTPBody_NewElement = $null
            
        }else {
            #Update Element in the list (based on MainArray)
            
            $ID = ($AllItemsArray | Where-Object FullLineUri -like $Entry.FullLineUri).ID
            $GraphAPIUrl_UpdateElement = $TPIListURL + '/items/'+ $ID
            $HTTPBody_UpdateElement = @{
                "fields" = @{
                    "Title"= $Entry.FullLineUri
                    "MainLineUri" = $Entry.MainLineUri
                    "DID"= $Entry.DID.ToString()
                    "TeamsEXT" = $Entry.TeamsEXT
                    "NumberRangeName" = $Entry.NumberRangeName
                    "ExtensionRangeName" = $Entry.ExtensionRangeName
                    "UPN"= $Entry.UPN
                    "Display_Name"= $Entry.Display_Name
                    "OnlineVoiceRoutingPolicy"= $Entry.OnlineVoiceRoutingPolicy
                    "TeamsCallingPolicy"= $Entry.TeamsCallingPolicy
                    "DialPlan"= $Entry.DialPlan
                    "TenantDialPlan"= $Entry.TenantDialPlan
                    "VoiceType"= $Entry.VoiceType
                    "UserType"= $Entry.UserType
                    "NumberRangeIndex"= $Entry.NumberRangeIndex
                    "ExtensionRangeIndex"= $Entry.ExtensionRangeIndex
                    "Country"= $Entry.Country
                    "City"= $Entry.City
                    "Company"= $Entry.Company
                    "Status"= $Entry.Status
                }
            }
            Write-Verbose "Update $($Entry.FullLineUri) Name: $($Entry.Display_Name) Type: $($Entry.VoiceType)"
            $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_UpdateElement -Method Patch -Body $HTTPBody_UpdateElement -ProcessPart "TPI List - Update item: $CurrentLineUri"
            $HTTPBody_UpdateElement = $null
        }
        
    }
    if ($RunMode -like "AppBased") {
        Write-Progress -Completed -Activity "Update of the list completed"
    }
    
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Update of the list completed"

    $NoUpdate = 0
}else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - SharePoint List is up to date - no need for an update"
    $NoUpdate = 1
}
#endregion

#region Get Status Quo of the Sharepoint List if needed
if ($NoUpdate -ne 1) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Get fresh StatusQuo of TPI SharePoint List - ListName: $SharepointTPIList"
    $TPIList = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList | Select-Object Title,MainLineUri,DID,TeamsEXT,NumberRangeName,ExtensionRangeName,UPN,Display_Name,OnlineVoiceRoutingPolicy,TeamsCallingPolicy,DialPlan,TenantDialPlan,VoiceType,UserType,NumberRangeIndex,ExtensionRangeIndex,Country,City,Company,Status,id

    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Transfer Response into an Array"
    #Transfer Response into an Array (easier handling)
    [System.Collections.ArrayList]$AllItemsArray = @()

    foreach ($item in $TPIList) {
        $TMPNumberRangeName = $item.NumberRangeName -replace $null,""
        $TMPExtensionRangeName = $item.ExtensionRangeName -replace $null,""
        $TMPTitle = $item.Title -replace $null,""
        $TMPMainLineUri = $item.MainLineUri -replace $null,""
        $TMPDID = $item.DID -replace $null,""
        $TMPTeamsEXT = $item.TeamsEXT -replace $null,""
        $TMPUPN = $item.UPN -replace $null,""
        $TMPDisplay_Name = $item.Display_Name -replace $null,""
        $TMPOnlineVoiceRoutingPolicy = $item.OnlineVoiceRoutingPolicy -replace $null,""
        $TMPTeamsCallingPolicy = $item.TeamsCallingPolicy -replace $null,""
        $TMPDialPlan = $item.DialPlan -replace $null,""
        $TMPTenantDialPlan = $item.TenantDialPlan -replace $null,""
        $TMPVoiceType = $item.VoiceType -replace $null,""
        $TMPUserType = $item.UserType -replace $null,""
        $TMPNumberRangeIndex = $item.NumberRangeIndex -replace $null,""
        $TMPExtensionRangeIndex = $item.ExtensionRangeIndex -replace $null,""
        $TMPCountry = $item.Country -replace $null,""
        $TMPCity = $item.City -replace $null,""
        $TMPCompany = $item.Company -replace $null,""
        $TMPStatus = $item.Status -replace $null,""
        $TMPid = $item.id
        
        #Check for empty entries
        if ($TMPTitle -notlike "") {
            $NewRow += [pscustomobject]@{'FullLineUri'=$TMPTitle;'MainLineUri'=$TMPMainLineUri;'DID'=$TMPDID;'TeamsEXT'=$TMPTeamsEXT;'NumberRangeName'=$TMPNumberRangeName;'ExtensionRangeName'=$TMPExtensionRangeName;'UPN'=$TMPUPN;'Display_Name'=$TMPDisplay_Name;'OnlineVoiceRoutingPolicy'=$TMPOnlineVoiceRoutingPolicy;'TeamsCallingPolicy'=$TMPTeamsCallingPolicy;'DialPlan'=$TMPDialPlan;'TenantDialPlan'=$TMPTenantDialPlan;'VoiceType'=$TMPVoiceType;'UserType'=$TMPUserType;'NumberRangeIndex'=$TMPNumberRangeIndex;'ExtensionRangeIndex'=$TMPExtensionRangeIndex;'Country'=$TMPCountry;'City'=$TMPCity;'Company'=$TMPCompany;'Status'=$TMPStatus; 'id'=$TMPid}
            $AllItemsArray += $NewRow
        }
        
        Clear-Variable -Name ("NewRow","TMPNumberRangeName","TMPMainLineUri","TMPTeamsEXT","TMPExtensionRangeName","TMPid","TMPTitle","TMPDID","TMPUPN","TMPDisplay_Name","TMPOnlineVoiceRoutingPolicy","TMPTeamsCallingPolicy","TMPDialPlan","TMPTenantDialPlan","TMPVoiceType","TMPUserType","TMPNumberRangeIndex","TMPExtensionRangeIndex","TMPCountry","TMPCity","TMPCompany")
    }

    $TPIList = $null

    $MainArrayCounter = $MainArray.Count
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Items in SharePoint List: $($AllItemsArray.Count)"
    Write-Output "$TimeStamp - Block 6 - Items in MainArray: $MainArrayCounter"
}

#endregion

#region Compare the MainArray with the SharePoint List to check if items in the list need to be deleted
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Compare the MainArray with the SharePoint List to check if items in the list need to be deleted"
$EntrysToDelete = Compare-Object -ReferenceObject $MainArray -DifferenceObject $AllItemsArray -Property FullLineUri,MainLineUri,DID,TeamsEXT,NumberRangeName,ExtensionRangeName,UPN,Display_Name,OnlineVoiceRoutingPolicy,TeamsCallingPolicy,DialPlan,TenantDialPlan,VoiceType,UserType,NumberRangeIndex,ExtensionRangeIndex,Country,City,Company,Status | Where-Object SideIndicator -Like "=>"

$EntrysToDeleteCount = $EntrysToDelete.Count 

if ($EntrysToDeleteCount -gt 0) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Number of items in the SharePoint List that need to be removed: $EntrysToDeleteCount"
    
    foreach ($DeleteItem in $EntrysToDelete) {
        $ID = ($AllItemsArray | Where-Object FullLineUri -like $DeleteItem.FullLineUri).ID
        $GraphAPIUrl_DeleteElement = $TPIListURL + '/items/'+ $ID
        Write-Verbose "Delete $($DeleteItem.FullLineUri) Name: $($DeleteItem.Display_Name) Type: $($DeleteItem.VoiceType)"
        $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_DeleteElement -Method Delete -ProcessPart "TPI List: Delete item: $($DeleteItem.FullLineUri)"
        $GraphAPIUrl_DeleteElement = $null
    }
}else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - There are no items that need to be removed from the SharePoint List."
}

#endregion

#endregion   