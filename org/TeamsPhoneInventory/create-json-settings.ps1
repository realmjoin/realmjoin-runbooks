<#
  .SYNOPSIS
  Teams Phone Inventory - Create JSON Settings

  .DESCRIPTION
  This runbook collects locations, team policies and other information in order to prepare them so that a JSON string is output. 
  This is stored in the runbook customizations and controls the runbooks and their options. The output must then be adapted respectively consolidated with the existing settings.
  In order to use this runbook, a few variables must be stored in the Automation account.
  The runbook is part of the TeamsPhoneInventory.

  .NOTES
  Runbook requires PS-Version 7.2 and does not work with 5.1!
#>

#Require: PS-Version 7.2
#Require: PS-Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.4.0" }, @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.20.0" }

# Define Sharepoint Parameters
# Example:
# $SharepointSite = "SiteName"
try {
    $SharepointSite = Get-AutomationVariable -Name TPI_SharepointSite -ErrorAction Stop
}
catch {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Error "$TimeStamp - Required automation account variable for the tenant domain name does not exist! Variable: TPI_SharepointSite" 
    Exit
}
if ($SharepointSite -like "") {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Error "$TimeStamp - Required automation account variable for the tenant domain name is empty! Variable: TPI_SharepointSite" 
    Exit
}

# Optional: Define the list names. The preset default names can be used and do not need to be changed. If the names have been changed, they must be taken into account in all further steps (runbooks, etc.).
# Defaults would be used, if variables does not exist or empty

# SharepointTPIList
try {
    $SharepointTPIList = Get-AutomationVariable -Name TPI_SharepointTPIList -ErrorAction Stop
    if ($SharepointTPIList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointTPIList is empty - use default value"
        $SharepointTPIList = "TeamsPhoneInventory"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointTPIList does not exist - use default value"
    $SharepointTPIList = "TeamsPhoneInventory"
}

# SharepointNumberRangeList
try {
    $SharepointNumberRangeList = Get-AutomationVariable -Name TPI_SharepointNumberRangeList -ErrorAction Stop
    if ($SharepointNumberRangeList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointNumberRangeList is empty - use default value"
        $SharepointNumberRangeList = "TPI-NumberRange"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointNumberRangeList does not exist - use default value"
    $SharepointNumberRangeList = "TPI-NumberRange"
}

# SharepointExtensionRangeList
try {
    $SharepointExtensionRangeList = Get-AutomationVariable -Name TPI_SharepointExtensionRangeList -ErrorAction Stop
    if ($SharepointExtensionRangeList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointExtensionRangeList is empty - use default value"
        $SharepointExtensionRangeList = "TPI-ExtensionRange"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointExtensionRangeList does not exist - use default value"
    $SharepointExtensionRangeList = "TPI-ExtensionRange"
}

# SharepointLegacyList
try {
    $SharepointLegacyList = Get-AutomationVariable -Name TPI_SharepointLegacyList -ErrorAction Stop
    if ($SharepointLegacyList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointLegacyList is empty - use default value"
        $SharepointLegacyList = "TPI-Legacy"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointLegacyList does not exist - use default value"
    $SharepointLegacyList = "TPI-Legacy"
}

# SharepointBlockExtensionList
try {
    $SharepointBlockExtensionList = Get-AutomationVariable -Name TPI_SharepointBlockExtensionList -ErrorAction Stop
    if ($SharepointBlockExtensionList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointBlockExtensionList is empty - use default value"
        $SharepointBlockExtensionList = "TPI-BlockExtension"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointBlockExtensionList does not exist - use default value"
    $SharepointBlockExtensionList = "TPI-BlockExtension"
}

# SharepointCivicAddressMappingList
try {
    $SharepointCivicAddressMappingList = Get-AutomationVariable -Name TPI_SharepointCivicAddressMappingList -ErrorAction Stop
    if ($SharepointCivicAddressMappingList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointCivicAddressMappingList is empty - use default value"
        $SharepointCivicAddressMappingList = "TPI-CivicAddressMapping"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointCivicAddressMappingList does not exist - use default value"
    $SharepointCivicAddressMappingList = "TPI-CivicAddressMapping"
}

# SharepointLocationDefaultsList
try {
    $SharepointLocationDefaultsList = Get-AutomationVariable -Name TPI_SharepointLocationDefaultsList -ErrorAction Stop
    if ($SharepointLocationDefaultsList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointLocationDefaultsList is empty - use default value"
        $SharepointLocationDefaultsList = "TPI-LocationDefaults"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointLocationDefaultsList does not exist - use default value"
    $SharepointLocationDefaultsList = "TPI-LocationDefaults"
}


# SharepointLocationDefaultsList
try {
    $SharepointLocationDefaultsList = Get-AutomationVariable -Name TPI_SharepointLocationDefaultsList -ErrorAction Stop
    if ($SharepointLocationDefaultsList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointLocationDefaultsList is empty - use default value"
        $SharepointLocationMappingList = "TPI-LocationMapping"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointLocationDefaultsList does not exist - use default value"
    $SharepointLocationMappingList = "TPI-LocationMapping"
}


# SharepointUserMappingList
try {
    $SharepointUserMappingList = Get-AutomationVariable -Name TPI_SharepointUserMappingList -ErrorAction Stop
    if ($SharepointUserMappingList -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_SharepointUserMappingList is empty - use default value"
        $SharepointUserMappingList = "TPI-UserMapping"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_SharepointUserMappingList does not exist - use default value"
    $SharepointUserMappingList = "TPI-UserMapping"
}

# BlockExtensionDays
# Optional: Define the range in days, if a user get offboarded, how long the number should be blocked
try {
    $BlockExtensionDays = Get-AutomationVariable -Name TPI_BlockExtensionDays -ErrorAction Stop
    if ($BlockExtensionDays -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_BlockExtensionDays is empty - use default value"
        $BlockExtensionDays = 30
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_BlockExtensionDays does not exist - use default value"
    $BlockExtensionDays = 30
}

# RunbookNameSetTeamsTelephonyCustom
# Optional: Define name of the Runbook
try {
    $RunbookNameSetTeamsTelephonyCustom = Get-AutomationVariable -Name TPI_RunbookNameSetTeamsTelephonyCustom -ErrorAction Stop
    if ($RunbookNameSetTeamsTelephonyCustom -like "") {
        Write-Verbose "Sharepoint TPI List variable TPI_RunbookNameSetTeamsTelephonyCustom is empty - use default value"
        $RunbookNameSetTeamsTelephonyCustom = "rjgit_user_phone_set-teams-phone-user-custom"
    }
}
catch {
    Write-Verbose "Sharepoint TPI List variable TPI_RunbookNameSetTeamsTelephonyCustom does not exist - use default value"
    $RunbookNameSetTeamsTelephonyCustom = "rjgit_user_phone_set-teams-phone-user-custom"
}

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
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body $Body
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

            try {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Body $Body
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
        $Test = Get-CsTenant -ErrorAction Stop |  Out-Null
    }
    catch {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Teams PowerShell session could not be established. Stopping script!" 
        Exit
    }
}

# Initiate Graph Session
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Initiate Graph Session"
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    Exit 
}

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
#############################################################################
#           Settings Block
#
#############################################################################

$SettingsTPI = [PSCustomObject]@{
    'SharepointURL' = $SharepointURL;
    'SharepointSite' = $SharepointSite;
    'SharepointTPIList' = $SharepointTPIList;
    'SharepointNumberRangeList' = $SharepointNumberRangeList;
    'SharepointExtensionRangeList' = $SharepointExtensionRangeList;
    'SharepointLegacyList' = $SharepointLegacyList;
    'SharepointBlockExtensionList' = $SharepointBlockExtensionList;
    'SharepointCivicAddressMappingList' = $SharepointCivicAddressMappingList
    'SharepointLocationDefaultsList' = $SharepointLocationDefaultsList;
    'SharepointLocationMappingList' = $SharepointLocationMappingList;
    'SharepointUserMappingList' = $SharepointUserMappingList;
    'BlockExtensionDays' = $BlockExtensionDays;
}

$Settings_jsonBase = [PSCustomObject]@{
    'TPI' = $SettingsTPI
}

#############################################################################
#           Get current Teams policies
#
#############################################################################

$OnlineVoiceRoutingPolicy = Get-CsOnlineVoiceRoutingPolicy
$TeamsCallingPolicy = Get-CsTeamsCallingPolicy
$TenantDialPlan = Get-CsTenantDialPlan
$OnlineVoicemailPolicy = Get-CsOnlineVoicemailPolicy

#############################################################################
#           OnlineVoiceRoutingPolicy - short version: OVRP
#
#############################################################################

$OVRP_jsonBase = @{}
$OVRP_list = New-Object System.Collections.ArrayList

foreach ($OVRP in $OnlineVoiceRoutingPolicy) {
    if ($OVRP.Identity -notlike "Global") {  #Only if it is not the global policy
        $OVRP_list.Add(@{"ParameterValue" = ($OVRP.Identity.SubString(4));}) | Out-Null
    }
}

$OVRP_jsonBase.Add('$values',$OVRP_list)
$OVRP_jsonBase.Add('$id','TPI-OnlineVoiceRoutingPolicy')

#############################################################################
#           TeamsCallingPolicy - short version: TCP
#
#############################################################################

$TCP_jsonBase = @{}
$TCP_list = New-Object System.Collections.ArrayList

foreach ($TCP in $TeamsCallingPolicy) {
    if ($TCP.Identity -notlike "Global") {  #Only if it is not the global policy
        $TCP_list.Add(@{"ParameterValue" = ($TCP.Identity.SubString(4));}) | Out-Null
    }
}

$TCP_jsonBase.Add('$values',$TCP_list)
$TCP_jsonBase.Add('$id','TPI-TeamsCallingPolicy')

#############################################################################
#           TenantDialPlan - short version: TDP
#
#############################################################################

$TDP_jsonBase = @{}
$TDP_list = New-Object System.Collections.ArrayList

foreach ($TDP in $TenantDialPlan) {
    if ($TDP.Identity -notlike "Global") {  #Only if it is not the global policy
        $TDP_list.Add(@{"ParameterValue" = ($TDP.SimpleName);}) | Out-Null
    }
}

$TDP_jsonBase.Add('$values',$TDP_list)
$TDP_jsonBase.Add('$id','TPI-TenantDialPlan')

#############################################################################
#           OnlineVoicemailPolicy - short version: OVMP
#
#############################################################################

$OVMP_jsonBase = @{}
$OVMP_list = New-Object System.Collections.ArrayList

foreach ($OVMP in $OnlineVoicemailPolicy) {
    if ($OVMP.Identity -notlike "Global") {  #Only if it is not the global policy
        $OVMP_list.Add(@{"ParameterValue" = ($OVMP.Identity.SubString(4));}) | Out-Null
    }
}

$OVMP_jsonBase.Add('$values',$OVMP_list)
$OVMP_jsonBase.Add('$id','TPI-OnlineVoicemailPolicy')

#############################################################################
#           ExtensionRange - short version: ER
#
#############################################################################

$ExtensionRangeListURL = $BaseURL + $SharepointExtensionRangeList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Get StatusQuo of ExtensionRange SharePoint List - ListName: $SharepointExtensionRangeList"
$ExtensionRangeList = Get-TPIList -ListBaseURL $ExtensionRangeListURL -ListName $SharepointExtensionRangeList | Select-Object ExtensionRangeName,BeginExtensionRange,EndExtensionRange

$ER_jsonBase = @{}
$ER_list = New-Object System.Collections.ArrayList

foreach ($ER in $ExtensionRangeList) {
    if ($ER.ExtensionRangeName -notlike "") {  #Only if it is not an empty entry
        $ER_list.Add(@{"ParameterValue" = ($ER.ExtensionRangeName);}) | Out-Null
    }
}

$ER_jsonBase.Add('$values',$ER_list)
$ER_jsonBase.Add('$id','TPI-ExtensionRange')


#############################################################################
#           CivicAddressMapping - short version: CAM
#
#############################################################################

$CivicAddressMappingListURL = $BaseURL + $SharepointCivicAddressMappingList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Get StatusQuo of CivicAddressMapping SharePoint List - ListName: $SharepointCivicAddressMappingList"
$CivicAddressMappingList = Get-TPIList -ListBaseURL $CivicAddressMappingListURL -ListName $SharepointCivicAddressMappingList | Select-Object CivicAddressMappingIndex,CivicAddressMappingName,CivicAddressID

$CAM_jsonBase = @{}
$CAM_list = New-Object System.Collections.ArrayList

foreach ($CAM in $CivicAddressMappingList) {
    if ($CAM.CivicAddressMappingName -notlike "") {  #Only if it is not an empty entry
        $CAM_list.Add(@{"ParameterValue" = ($CAM.CivicAddressMappingName);}) | Out-Null
    }
}

$CAM_jsonBase.Add('$values',$CAM_list)
$CAM_jsonBase.Add('$id','TPI-CivicAddressMapping')


#############################################################################
#           LocationDefaults - short version: LD
#
#############################################################################

$LocationDefaultsListURL = $BaseURL + $SharepointLocationDefaultsList

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Get StatusQuo of LocationDefaults SharePoint List - ListName: $SharepointLocationDefaultsList"
$LocationDefaultsList = Get-TPIList -ListBaseURL $LocationDefaultsListURL -ListName $SharepointLocationDefaultsList | Select-Object Title,ExtensionRangeIndex,CivicAddressMappingIndex,OnlineVoiceRoutingPolicy,TeamsCallingPolicy,TenantDialPlan,TeamsIPPhonePolicy

$LD_jsonBase = @{}
$subLocation = @()

foreach ($LD in $LocationDefaultsList) {
    if ($LD.Title -notlike "") {  #Only if it is not an empty entry
        $DisplayName = $LD.Title
        $ExtensionRangeIndex = $LD.ExtensionRangeIndex
        $CivicAddressMappingIndex = $LD.CivicAddressMappingIndex
        $OnlineVoiceRoutingPolicy = $LD.OnlineVoiceRoutingPolicy
        $TeamsCallingPolicy = $LD.TeamsCallingPolicy
        $TenantDialPlan = $LD.TenantDialPlan
        $TeamsIPPhonePolicy = $LD.TeamsIPPhonePolicy
        $OnlineVoicemailPolicy = $LD.OnlineVoicemailPolicy

        $Details = [PSCustomObject]@{
            'ExtensionRangeIndex'=$ExtensionRangeIndex;
            'CivicAddressMappingIndex'=$CivicAddressMappingIndex;
            'OnlineVoiceRoutingPolicy'= $OnlineVoiceRoutingPolicy;
            'TenantDialPlan'= $TenantDialPlan;
            'TeamsCallingPolicy'= $TeamsCallingPolicy;
            'TeamsIPPhonePolicy'=$TeamsIPPhonePolicy;
            'OnlineVoicemailPolicy'=$OnlineVoicemailPolicy;
        }
        $Defaults = [PSCustomObject]@{
            'Default' = $Details
        }

        $subLocation += [pscustomobject]@{
            'Display'=$DisplayName;
            'Customization' = $Defaults
        }
    }
}


$LD_jsonBase.Add('$values',$subLocation)
$LD_jsonBase.Add('$id','TPI-Locations')


#############################################################################
#           Runbook Options
#
#############################################################################

$RunbookRAW = '
{
    "'+ $RunbookNameSetTeamsTelephonyCustom + '": {
        "ParameterList": [
            {
                "Name": "PhoneNumber",
                "DisplayAfter" : "UserName",
                "Mandatory" : true,
                "DisplayName": "Phone number to assign (E.164 Format - Example:+49123987654)",               
            },
            {
                "DisplayName": "Location",
                "DisplayAfter" : "PhoneNumber",
                "Select": {
                    "Options": {
                        "$ref": "TPI-Locations"
                    }
                }
            },
            {
                "Name": "OnlineVoiceRoutingPolicy",
                "DisplayAfter" : "Location",
                "DisplayName": "Online Voice Routing Policy",
                "Select": {
                    "Options": {
                        "$ref": "TPI-OnlineVoiceRoutingPolicy"
                    }
                }
                
            },
            {
                "Name": "TeamsCallingPolicy",
                "DisplayAfter" : "OnlineVoiceRoutingPolicy",
                "DisplayName": "Teams Calling Policy",
                "Select": {
                    "Options": {
                        "$ref": "TPI-TeamsCallingPolicy"
                    }
                }
                
            },
            {
                "Name": "TenantDialPlan",
                "DisplayAfter" : "TeamsCallingPolicy",
                "DisplayName": "Tenant DialPlan",
                "Select": {
                    "Options": {
                        "$ref": "TPI-TenantDialPlan"
                    }
                }
                
            },
            {
                "Name": "SharepointURL",
                "Hide": true
            },
            {
                "Name": "SharepointSite",
                "Hide": true
            },
            {
                "Name": "SharepointTPIList",
                "Hide": true
            },
            {
                "Name": "ExtensionRangeIndex",
                "Hide": true
            },
            {
                "Name": "TeamsIPPhonePolicy",
                "Hide": true
            }
        ]
    }
}
'
$Runbooks = $RunbookRAW | ConvertFrom-Json

#############################################################################
#           Combine everything
#
#############################################################################

$AllElements = New-Object System.Collections.ArrayList
$AllElements += $LD_jsonBase
$AllElements += $OVRP_jsonBase
$AllElements += $TCP_jsonBase
$AllElements += $TDP_jsonBase
$AllElements += $OVMP_jsonBase
$AllElements += $ER_jsonBase

$Options_jsonBase = @{}
$Options_jsonBase.Add("Options",$AllElements)

$jsonBase = [ordered]@{}
$jsonBase.Add("Settings",$Settings_jsonBase)
$jsonBase.Add("Templates",$Options_jsonBase)
$jsonBase.Add("Runbooks",$Runbooks)


$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "$TimeStamp - Final JSON Output:"

$jsonBase | ConvertTo-Json -depth 10