<#
  .SYNOPSIS
  Microsoft Teams telephony offboarding
  
  .DESCRIPTION
  Remove the phone number and specific policies from a teams-enabled user. 
  If "Delay possible re-assignment of the current call number" is activated, the phone number is blocked for a defined number of days so that it is not assigned to a new user for this period. The number of days is stored in the RealmJoin settings. The runbook is part of the TeamsPhoneInventory.

  .NOTES
  Permissions: 
  The connection of the Microsoft Teams PowerShell module is done through the Managed Identity of the Automation account of RealmJoin.
  
  .INPUTS
  RunbookCustomization: {
      "Parameters": {
          "AddDays": {
              "Hide": true
          },
          "SharepointSite": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointTPIList": {
              "Hide": true,
              "Mandatory": true
          },
          "SharepointBlockExtensionList": {
              "Hide": true,
              "Mandatory": true
          },
          "CallerName": {
              "Hide": true
          }
      }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.5.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.22.0" }

param(
    # User which should be cleared
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    #Number of days the phone number is blocked for a new assignment
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.BlockNumberforDays" } )]
    [String] $AddDays,
    [ValidateScript( { Use-RJInterface -DisplayName "Delay possible re-assignment of the current call number" } )]
    [bool] $BlockNumber = $true,
    # Define TeamsPhoneInventory SharePoint List
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointSite" } )]
    [string] $SharepointSite,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointTPIList" } )]
    [string] $SharepointTPIList,
    [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointBlockExtensionList" } )]
    [String] $SharepointBlockExtensionList,
    

    # CallerName is tracked purely for auditing purposes
    [string] $CallerName
)


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
##             Block 0 - Connect Part
##          
########################################################
# Add Caller in Verbose output
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "SharepointSite: '$SharepointSite'" -Verbose
Write-RjRbLog -Message "SharepointTPIList: '$SharepointTPIList'" -Verbose
Write-RjRbLog -Message "SharepointBlockExtensionList: '$SharepointBlockExtensionList'" -Verbose
Write-RjRbLog -Message "BlockNumberforDays: '$AddDays'" -Verbose
    
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

########################################################
##             Block 1 - Setup base URL
##          
########################################################
Write-Output ""
Write-Output "Block 1 - Check basic connection to TPI List and build base URL"

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
Write-Output "Connection - SharePoint TPI List URL: $TPIListURL"

########################################################
##             Block 2 - Getting StatusQuo
##          
########################################################

Write-Output ""
Write-Output "Block 2 - Getting StatusQuo for $UserName"
$StatusQuo = Get-CsOnlineUser $UserName

$CurrentLineUri = $StatusQuo.LineURI -replace("tel:","")
$CurrentOnlineVoiceRoutingPolicy = $StatusQuo.OnlineVoiceRoutingPolicy
$CurrentTenantDialPlan = $StatusQuo.TenantDialPlan
$CurrentCallingPolicy = $StatusQuo.TeamsCallingPolicy
$OnlineVoicemailPolicy = $StatusQuo.OnlineVoicemailPolicy

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

if ($CurrentLineUri -like "+") {
    $CurrentLineUri = "none"
}

Write-Output "StatusQuo for $UserName"
Write-Output "Current LineUri - $CurrentLineUri"
Write-Output "Current OnlineVoiceRoutingPolicy - $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Current TenantDialPlan - $CurrentTenantDialPlan"
Write-Output "Current CallingPolicy - $CurrentCallingPolicy"
Write-Output "Current VoiceMailPolicy - $OnlineVoicemailPolicy"
Write-Output ""

if ($CurrentLineUri -like "none") {
    Write-Error "The user has not assigned a phone number, therefore the runbook will be terminated now." -ErrorAction Continue
    Exit
}
########################################################
##             Block 3 - Remove Number from User
##          
########################################################

Write-Output ""
Write-Output "Block 3 - Clearing Teams user"

Write-Output "Remove LineUri"
try {
    Remove-CsPhoneNumberAssignment -Identity $UserName -RemoveAll
}
catch {
    $message = $_
    Write-Error "Teams - Error: Removing the LineUri for $UserName could not be completed! Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the LineUri for $UserName could not be completed!"
}

Write-Output "Remove OnlineVoiceRoutingPolicy (Set to ""global"")"
try {
    Grant-CsOnlineVoiceRoutingPolicy -Identity $UserName -PolicyName $null
}
catch {
    $message = $_
    Write-Error "Teams - Error: Removing the of OnlineVoiceRoutingPolicy for $UserName could not be completed! Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the OnlineVoiceRoutingPolicy for $UserName could not be completed!"
}

Write-Output "Remove (Tenant)DialPlan (Set to ""global"")"
try {
    Grant-CsTenantDialPlan -Identity $UserName -PolicyName $null
}
catch {
    $message = $_
    Write-Error "Teams - Error: Removing the of TenantDialPlan for $UserName could not be completed!Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the of TenantDialPlan for $UserName could not be completed!"
}

Write-Output "Remove Teams IP-Phone Policy (Set to ""global"")"
try {
    Grant-CsTeamsIPPhonePolicy -Identity $UserName -PolicyName $null
}
catch {
    $message = $_
    Write-Error "Teams - Error: Removing the of Teams IP-Phone Policy for $UserName could not be completed!Error Message: $message" -ErrorAction Continue
    throw "Teams - Error: Removing the of Teams IP-Phone Policy for $UserName could not be completed!"
}



########################################################
##             Block 4 - GraphAPI Part
##          
########################################################

Write-Output ""
Write-Output "Block 4 - GraphAPI Part"

#Get Status Quo of the Sharepoint List
Write-Output "Get StatusQuo of the SharePoint List"

$AllItems = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList

Write-Output "List Analysis - Items in SharePoint List: $($AllItems.Count)"

$ID = ($AllItems | Where-Object Title -like $CurrentLineUri).ID
$GraphAPIUrl_UpdateElement = $TPIListURL + '/items/'+ $ID

if (($AddDays -like "") -or ($BlockNumber -eq $false) -or ($AddDays -eq 0)) {
    if($AddDays -like ""){
        $AddDays = 0
        Write-Warning "Block 4 - GraphAPI Part - No number of days defined for which a number is blocked by default before reassignment! Number will not be blocked!"
    }
    if ($AddDays -eq 0) {
        Write-Warning "Block 4 - GraphAPI Part - The number of days defined for how long the current phone number is blocked before reassignment is zero! Number will not be blocked!"
    }

    $HTTPBody_UpdateElement = @{
        "fields" = @{
            "Status" = ""
            "TeamsEXT" = ""
            "UPN" = ""
            "Display_Name" = ""
            "OnlineVoiceRoutingPolicy" = ""
            "TeamsCallingPolicy" = ""
            "DialPlan" = ""
            "TenantDialPlan" = ""
        }
    }
        Write-Output "Clear current entry for $CurrentLineUri in TPI"
}else {
    $BlockDay = (([datetime]::now).AddDays($AddDays)).tostring("dd.MM.yyyy")
    $Status = "TMP-BlockNumber_Until_" + $BlockDay

$HTTPBody_UpdateElement = @{
    "fields" = @{
        "Status" = $Status
        "TeamsEXT" = ""
        "UPN" = ""
        "Display_Name" = ""
        "OnlineVoiceRoutingPolicy" = ""
        "TeamsCallingPolicy" = ""
        "DialPlan" = ""
        "TenantDialPlan" = ""
    }
}
    Write-Output "Clear and block current entry for $CurrentLineUri in TPI"
}

$TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_UpdateElement -Method Patch -Body $HTTPBody_UpdateElement -ProcessPart "TPI List - Update item: $CurrentLineUri"

$HTTPBody_UpdateElement = $null

###################################################################################

if (($AddDays -ne 0) -and ($BlockNumber -eq $true)) {
    $BlockReason = "OffboardedUser_" + $UserName
    $TPIBlockExtensionListURL = $BaseURL + $SharepointBlockExtensionList
    $GraphAPIUrl_NewElement = $TPIBlockExtensionListURL + "/items"

    #Remove teams extension if existing
    if ($CurrentLineUri -like "*;ext=*") {
        $CurrentLineUri = $CurrentLineUri.Substring(0,($CurrentLineUri.Length-($CurrentLineUri.IndexOf(";ext=")-3)))
    }

$HTTPBody_NewElement = @{
    "fields" = @{
        "Title" = $CurrentLineUri
        "BlockUntil" = $BlockDay
        "BlockReason" = $BlockReason
    }
}

    Write-Output "Add a temporary entry in the BlockExtension list which blocks the phone number $CurrentLineUri until $BlockDay"
    $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_NewElement -Method Post -Body $HTTPBody_NewElement -ProcessPart "BlockExtension List - add item: $CurrentLineUri"

    $HTTPBody_NewElement = $null
}

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null