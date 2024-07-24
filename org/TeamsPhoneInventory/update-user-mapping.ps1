#region Customization depending on the implemented version
########################################################################################################################################################################
##             Start Region - Customization depending on the implemented version
##             Current Version: RJ Runbook
##
########################################################

<#
  .SYNOPSIS
  Teams Phone Inventory - User Mapping

  .DESCRIPTION
  This runbook updates the UserMapping list so that new users are mapped to their location and the runbooks can use the appropriate defaults.
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.4.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.19.0" }

########################################################
##             Variable/Parameter declaration
##          
########################################################

Param(
        # Define Sharepoint Parameters       
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointSite" } )]
        [string] $SharepointSite,
        
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointTPIList" } )]
        [string] $SharepointTPIList = "TeamsPhoneInventory",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointNumberRangeList" } )]
        [String] $SharepointNumberRangeList = "TPI-NumberRange",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointExtensionRangeList" } )]
        [String] $SharepointExtensionRangeList = "TPI-ExtensionRange",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLegacyList" } )]
        [String] $SharepointLegacyList = "TPI-Legacy",
        
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointBlockExtensionList" } )]
        [String] $SharepointBlockExtensionList = "TPI-BlockExtension",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLocationDefaultsList" } )]
        [String] $SharepointLocationDefaultsList = "TPI-LocationDefaults",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointCivicAddressMappingList" } )]
        [string] $SharepointCivicAddressMappingList = "TPI-CivicAddressMapping",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointLocationMappingList" } )]
        [String] $SharepointLocationMappingList = "TPI-LocationMapping",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointUserMappingList" } )]
        [String] $SharepointUserMappingList = "TPI-UserMapping",

        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.BlockExtensionDays" } )]
        [int] $BlockExtensionDays = 30,

        # CallerName is tracked purely for auditing purposes
        [string] $CallerName
)

########################################################
##             Variable/Parameter declaration
##          
########################################################

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

    #Limit access to 2000 items (Default is 200)
    $GraphAPIUrl_StatusQuoSharepointList = $ListBaseURL + '/items?expand=fields'
    try {
        $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8'
    }
    catch {
        Write-Warning "First try to get TPI list failed - reconnect MgGraph and test again"
        
        try {
            Connect-MgGraph -Identity
            $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8'
        }
        catch {
            Write-Error "Getting TPI list failed - stopping script" -ErrorAction Continue
            Exit
        }
        
    }
    
    $AllItems = $AllItemsResponse.value.fields

    #Check if response is paged:
    $AllItemsResponseNextLink = $AllItemsResponse."@odata.nextLink"

    while ($null -ne $AllItemsResponseNextLink) {

        $AllItemsResponse = Invoke-MgGraphRequest -Uri $AllItemsResponseNextLink -Method Get -ContentType 'application/json; charset=utf-8'
        $AllItemsResponseNextLink = $AllItemsResponse."@odata.nextLink"
        $AllItems += $AllItemsResponse.value.fields

    }

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
        $Body,
        [parameter(Mandatory = $true)]
        [String]
        $ProcessPart
    )

    #ToFetchErrors (Throw)
    $ExitError = 0

    if (($Method -like "Post") -or ($Method -like "Patch")) {
        try {
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body (($Body) | ConvertTo-Json -Depth 6) -ContentType 'application/json; charset=utf-8'
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
            Start-Sleep -Seconds 5
            Write-Output "$TimeStamp - GraphAPI - GraphAPI Session refresh"
            #Connect-MgGraph -Identity
            try {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body (($Body) | ConvertTo-Json -Depth 6) -ContentType 'application/json; charset=utf-8'
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
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - Uri $Uri -Method $Method : $ProcessPart"
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method
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
            Start-Sleep -Seconds 5
            Write-Output "$TimeStamp - GraphAPI - GraphAPI Session refresh"
            #Connect-MgGraph -Identity
            try {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method 
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
Write-Output "$TimeStamp - Connection - Connect to Microsoft Teams (PowerShell as managed identity)"

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
Write-RjRbLog -Message "SharepointCivicAddressMappingList: '$SharepointCivicAddressMappingList'" -Verbose
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

#region Get StatusQuo
########################################################
##             Block 1 - Get StatusQuo
##          
########################################################

# Get all users which filled with City,Street and Company
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Get StatusQuo"
Write-Output "$TimeStamp - Block 1 - Get all Teams User..."
$AllUsers = Get-CsOnlineUser -Filter {City -notlike '' -and Street -notlike '' -and Company -notlike ''}  | select-Object UserPrincipalName,Displayname,LineUri,City,Street,Company


$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Get current mapping tables"

#Setup URL for User Mapping and Location Mapping List
$SharepointUserMappingListURL = $BaseURL + $SharepointUserMappingList
$SharepointUserMappingListContent = Get-TPIList -ListBaseURL $SharepointUserMappingListURL -ListName $SharepointUserMappingList | Select-Object Title,LocationIdentifier,id


#Setup URL for User Mapping and Location Mapping List
$SharepointLocationMappingListURL = $BaseURL + $SharepointLocationMappingList
$LocationMappingTable = Get-TPIList -ListBaseURL $SharepointLocationMappingListURL -ListName $SharepointLocationMappingList | Select-Object Title,City,Street,Company,id

#endregion


#region Build work table
########################################################
##             Block 2 - Create table of current user <-> location mapping
##          
########################################################

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Create table of current user <-> location mapping"


[System.Collections.ArrayList]$UserMappingTable = @()

foreach ($User in $AllUsers) {

    $CurrentLocationIdentifier = $($LocationMappingTable | Where-Object {($_.City -like $User.City) -and ($_.Street -like $User.Street) -and ($_.Company -like $User.Company)}).Title
    
    #Add item only if matching location identifier exists
    if ($CurrentLocationIdentifier -notlike '') {
        $CurrentUserPrincipalName = $User.UserPrincipalName

        #Key has to be 'Title' and could not be 'UserPrincipalName' cause the Sharepoint List Column Name is 'Title' - important for the compare
        $NewRow += [pscustomobject]@{'Title'=$CurrentUserPrincipalName;'LocationIdentifier'=$CurrentLocationIdentifier}
        $UserMappingTable += $NewRow
        $NewRow = $null       
    
        Clear-Variable CurrentLocationIdentifier,CurrentUserPrincipalName
    }

}
#endregion

#region Compare
########################################################
##             Block 3 - Compare Sharepoint List with work table
##          
########################################################

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 3 - Compare Sharepoint List with work table"

if (($SharepointUserMappingListContent | Measure-Object).Count -gt 0) {
    $EntrysToDelete = Compare-Object -ReferenceObject $UserMappingTable -DifferenceObject $SharepointUserMappingListContent -Property Title,LocationIdentifier | Where-Object SideIndicator -Like '=>' | Where-Object Title -NotLike ""
}

if (($SharepointUserMappingListContent | Measure-Object).Count -gt 0) {
    $EntrysToAdd = Compare-Object -ReferenceObject $UserMappingTable -DifferenceObject $SharepointUserMappingListContent -Property Title,LocationIdentifier | Where-Object SideIndicator -Like '<=' | Where-Object Title -NotLike ""
}else{
    # Empty Sharepoint List - initial RampUp 
    $EntrysToAdd = $UserMappingTable
}
#endregion

#region - Check if update is needed
if (!(($EntrysToDelete | Measure-Object).Count -eq 0)) {

    #region Delete wrong or outdated items
    ########################################################
    ##             Block 4 - Delete wrong or outdated items
    ##          
    ########################################################
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 4 - Delete wrong or outdated items"
    $EntrysToDeleteCount = ($EntrysToDelete | Measure-Object).Count

    if ($EntrysToDeleteCount -gt 0) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output "$TimeStamp - Block 4 - Number of items in the SharePoint List which will be removed: $EntrysToDeleteCount"
              
        foreach ($DeleteItem in $EntrysToDelete) {
            if ($DeleteItem.Title -notlike "") {
                $UPN = $DeleteItem.Title
                $ID = ($SharepointUserMappingListContent | Where-Object Title -like $UPN).ID
                $GraphAPIUrl_DeleteElement = $SharepointUserMappingListURL + '/items/'+ $ID
    
                if ($ID -notlike "") {
                    $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_DeleteElement -Method Delete -ProcessPart "User Mapping List - Delete item: $UPN"
                }else{
                    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                    Write-Output "$TimeStamp - Block 4 - Error! - Entry could not be removed - UPN: $UPN"
                }
    
                Clear-Variable UPN,ID,GraphAPIUrl_DeleteElement
            }
        }
    }else {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output "$TimeStamp - Block 4 - There are no items that need to be removed from the SharePoint User Mapping List."
    }
}
    #endregion

#region Add missing items
if (!(($EntrysToAdd | Measure-Object).Count -eq 0)) {
    ########################################################
    ##             Block 5 - Add missing items
    ##          
    ########################################################
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 5 - Add missing items"
    $EntrysToAddCount = ($EntrysToAdd | Measure-Object).Count

    if ($EntrysToAddCount -gt 0) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output "$TimeStamp - Block 5 - Number of items in the SharePoint List which will be added: $EntrysToAddCount"
        $GraphAPIUrl = $SharepointUserMappingListURL + '/items'

        foreach ($AddItem in $EntrysToAdd) {
            $UPN = $AddItem.Title
            $LocationIdentifier = $AddItem.LocationIdentifier
            $HTTPBody_NewElement = @{
                "fields" = @{
                    "Title"= $UPN
                    "LocationIdentifier"= $LocationIdentifier
                }
            }
            $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl -Method Post -Body $HTTPBody_NewElement -ProcessPart "User Mapping List - Add item: $UPN"
            Clear-Variable UPN,LocationIdentifier,HTTPBody_NewElement,TMP
        }


    }else {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output "$TimeStamp - Block 5 - There are no items that need to be added to the SharePoint User Mapping List."
    }
    #endregion
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Done!"
}else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Done! - no List update required"
}
#endregion