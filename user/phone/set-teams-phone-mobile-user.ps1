<#
  .SYNOPSIS
  Assigns the mobile phone number stored in the EntraID to a Microsoft Teams user as a Teams Phone Mobile number.
  
  .DESCRIPTION
  Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. 
  The prerequisite for this is that the phone number has already been added to the tenant by the carrier and the user has the appropriate licenses.
  The runbook is part of the TeamsPhoneInventory.

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
          "CallerName": {
              "Hide": true
          }
      }
  }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.6.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.24.0" }

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

#region Block 0 - Connect Part
########################################################
##             Block 0 - Connect Part
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

# Needs a Microsoft Teams Connection First!
Write-Output "Connection - Connect to Microsoft Teams (PowerShell as RealmJoin managed identity)"

$VerbosePreference = "SilentlyContinue"
try {
    $TeamsConnect = Connect-MicrosoftTeams -Identity -ErrorAction Stop 
}
catch {
    Write-Error "Connection - Teams PowerShell session could not be established. Stopping script!" 
}

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
        Write-Error "Connection - Teams PowerShell session could not be established. Stopping script!" 
        Exit
    }
}

# Initiate Graph Session
Write-Output "Connection - Initiate MGGraph Session"
try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    Exit 
}

#endregion
#region Block 1 - preflight-check
########################################################
##             Block 1 - preflight-check
##          
########################################################
Write-Output ""
$Message = "Block 1 - preflight-check"
Write-Output $Message
Write-Output ("-" * $($Message.Length))


Write-Output "Getting StatusQuo for user with ID: $UserName"
$StatusQuoTeamsUser = Get-CsOnlineUser $UserName
Write-Output ""

    #region license check
# If no license has been assigned to the user, respectively if the license is not yet replicated 
# in the teams backend or if the appropriate applications are not available within the license, 
# the script will be stopped!
$AssignedPlan = $StatusQuoTeamsUser.AssignedPlan

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

    #region check if EntraID mobile number exist in Tenant as Teams Phone Mobile Number
Write-Output ""
Write-Output "Check mobile phone number"

# Use Invoke-MgGraphRequest to get the user based on the ID
# The '$select=mobilePhone' in the URI filters the response to only include the mobilePhone attribute
try {
    $URI = 'https://graph.microsoft.com/v1.0/users/'+$UserName+'/?$select=mobilePhone,id'
    $StatusQuoEntraID = Invoke-MgGraphRequest -Method GET -Uri $URI
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__ 
    $StatusDescription = $_.Exception.Response.ReasonPhrase
    Write-Error "Mobile Phone number of the user could not be retrieved. Error: $StatusCode - $StatusDescription"
}

$CurrentMobileNumber = $StatusQuoEntraID.mobilePhone
$CurrentObjectID = $StatusQuoEntraID.id

$NumberAlreadyAssigned = $false

if ($CurrentMobileNumber -notlike "") {
    Write-Output "The mobile phone number of the current user in EntraID is: $CurrentMobileNumber"

    if ($CurrentMobileNumber -match '[-\s]') {
        $CurrentMobileNumber = $CurrentMobileNumber -replace '[-\s]', ''
        Write-Warning "The phone number contains minus signs or spaces which are automatically removed - Cleaned version: $CurrentMobileNumber"
    }

    Write-Output "Check whether the called number corresponds to the E.164 standard (1 to 15 digits, starting with a plus sign (+), no other characters (e.g. () or similar)."
    $E164Pattern = '^\+[1-9]\d{1,14}$'

    if ($CurrentMobileNumber -match $E164Pattern) {
        Write-Output "Mobile phone number in EntraID follows the E.164 standard, or could be adjusted automatically."
        $PhoneNumberInTenant = Get-CsPhoneNumberAssignment -TelephoneNumber $CurrentMobileNumber
        if ($PhoneNumberInTenant.AssignedPstnTargetId -like $CurrentObjectID) {
            $NumberAlreadyAssigned = $true
            Write-Warning "Number is already assigned to the user!"
        }else {
            if ($PhoneNumberInTenant.TelephoneNumber -notlike "") {
                if ($PhoneNumberInTenant.PstnAssignmentStatus -like "Unassigned") {
                    Write-Output "Phone number exists in the tenant and is not assigned to a user"
                    if (($PhoneNumberInTenant.Capability -notcontains "UserAssignment") -and ($PhoneNumberInTenant.Capability -notcontains "TeamsPhoneMobile")) {
                        Write-Error "Although the mobile number is available in the tenant, it is either not stored as a user (but as a service number) or is not marked as a TeamsPhoneMobile number and therefore cannot be assigned!" -ErrorAction Stop
                    }else {
                        Write-Output "Check of the mobile phone number: Ok"
                    }
                }else {
                    try {
                        $URI = 'https://graph.microsoft.com/v1.0/users/'+$($PhoneNumberInTenant.AssignedPstnTargetId)+'/?$select=UserPrincipalName'
                        $UPNofMobileNumber = (Invoke-MgGraphRequest -Method GET -Uri $URI | ConvertFrom-Json).UserPrincipalName
                    }
                    catch {
                        $StatusCode = $_.Exception.Response.StatusCode.value__ 
                        $StatusDescription = $_.Exception.Response.ReasonPhrase
                        Write-Error "Error: $StatusCode - $StatusDescription" -ErrorAction Continue
                        Write-Warning "Phone number is already assigned, but UPN could not be identified!"
                    }
                    if ($UPNofMobileNumber -notlike "") {
                        Write-Error "The phone number is already assigned to a Teams user! The Teams user is: $UPNofMobileNumber" -ErrorAction Stop
                    }else {
                        Write-Error "The phone number is already assigned to a Teams user! However, the UPN of the Teams user could not be resolved. The following ObjectID has been assigned to the phone number: $($PhoneNumberInTenant.AssignedPstnTargetId)" -ErrorAction Stop
                    }                
                }
            }
        }   

    }else {
        Write-Error "The mobile number does not correspond to the E.164 standard with which Teams, among others, work. Adapt the number to the international E.164 standard (1 to 15 digits, starting with a plus sign (+), no other characters (e.g. () or similar) and restart the runbook" -ErrorAction Stop
    }

}else {
    Write-Error 'The "Mobile phone" attribute of the user in the EntraID is empty. Please maintain the phone number in the EntraID first. The runbook will now be stopped!' -ErrorAction Stop
}

    #endregion

#endregion

########################################################
##             Block 2 - Teams User StatusQuo
##          
########################################################
Write-Output ""

# Get StatusQuo
$UPN = $StatusQuoTeamsUser.UserPrincipalName

$Message = "Block 2 - List StatusQuo for user with UPN: $($UPN)"
Write-Output $Message
Write-Output ("-" * $($Message.Length))

$CurrentLineUri = $StatusQuoTeamsUser.LineURI -replace("tel:","")

if (!($CurrentLineUri.ToString().StartsWith("+"))) {
    # Add prefix "+", if not there
    $CurrentLineUri = "+" + $CurrentLineUri
}

if ($CurrentLineUri -like "+") { # Change Current LineUri to "none" if it is blank
    $CurrentLineUri = "none"
}

if ($StatusQuoTeamsUser.OnlineVoiceRoutingPolicy -like "") {
    $CurrentOnlineVoiceRoutingPolicy = "Global"
}else {
    $CurrentOnlineVoiceRoutingPolicy = $StatusQuoTeamsUser.OnlineVoiceRoutingPolicy
}

if ($StatusQuoTeamsUser.CallingPolicy -like "") {
    $CurrentCallingPolicy = "Global"
}else {
    $CurrentCallingPolicy = $StatusQuoTeamsUser.CallingPolicy
}

if ($StatusQuoTeamsUser.DialPlan -like "") {
    $CurrentDialPlan = "Global"
}else {
    $CurrentDialPlan = $StatusQuoTeamsUser.DialPlan
}

if ($StatusQuoTeamsUser.TenantDialPlan -like "") {
    $CurrentTenantDialPlan = "Global"
}else {
    $CurrentTenantDialPlan = $StatusQuoTeamsUser.TenantDialPlan
}

if ($StatusQuoTeamsUser.TeamsIPPhonePolicy -like "") {
    $CurrentTeamsIPPhonePolicy = "Global"
}else {
    $CurrentTeamsIPPhonePolicy = $StatusQuoTeamsUser.TeamsIPPhonePolicy
}

Write-Output "Current LineUri: $CurrentLineUri"
Write-Output "Current OnlineVoiceRoutingPolicy: $CurrentOnlineVoiceRoutingPolicy"
Write-Output "Current CallingPolicy: $CurrentCallingPolicy"
Write-Output "Current DialPlan: $CurrentDialPlan"
Write-Output "Current TenantDialPlan: $CurrentTenantDialPlan"
Write-Output "Current TeamsIPPhonePolicy: $CurrentTeamsIPPhonePolicy"


########################################################
##             Block 3 - Main Part
##          
########################################################
Write-Output ""
$Message = "Block 3 - Main Part"
Write-Output $Message
Write-Output ("-" * $($Message.Length))

$PhoneNumber = $PhoneNumberInTenant.TelephoneNumber

Write-Output "Number provisioning:"

if ($NumberAlreadyAssigned) {
    Write-Output "Number $PhoneNumber is already set to $UPN - skip phone number assignment"
}else {
    Write-Output "Set $PhoneNumber to $UPN"
    try {
        Set-CsPhoneNumberAssignment -Identity $UPN -PhoneNumber $PhoneNumber -PhoneNumberType OperatorConnect -ErrorAction Stop
    }catch {
        $message = $_
        Write-Error "Error: The assignment for $UPN could not be performed! - Error Message: $message"
        throw "Error: The assignment for $UPN could not be performed! Further details in ""All Logs"""
    }
}

Write-Output ""
Write-Output "Clear policies:"

Write-Output "Clear Online Voice Routing Policy"
Grant-CsOnlineVoiceRoutingPolicy -Identity $UPN -PolicyName $null #reset to default

Write-Output "Clear Tenant Dial Plan"
Grant-CsTenantDialPlan -Identity $UPN -PolicyName $null #reset to default

if ($NumberAlreadyAssigned) {
    Write-Output ""
    Write-Output "As phone number already assigned - skip Teams Phone Inventory List update"
    Write-Output ""
    Write-Output "Done!"
    Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
    Get-PSSession | Remove-PSSession | Out-Null
    Exit
}
########################################################
##             Block 4 - Setup base URL
##          
########################################################
Write-Output ""
$Message = "Block 4 - Check basic connection to TPI List and build base URL"
Write-Output $Message
Write-Output ("-" * $($Message.Length))

Write-Output "Check basic connection to TPI List"

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

Write-Output "SharePoint TPI List URL: $TPIListURL"

################################################################################################################
##             Block 5 - Get Status Quo of the main TPI SharePoint List
##
################################################################################################################
Write-Output ""
$Message = "Block 5 - Get StatusQuo of the SharePoint List"
Write-Output $Message
Write-Output ("-" * $($Message.Length))

$TPI_AllItems = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList

Write-Output "Items in $SharepointTPIList SharePoint List: $($TPI_AllItems.Count)"
Write-Output "Check if mobile phone number exists in Teams Phone Inventory"

$TPI_CurrentNumber = $TPI_AllItems | Where-Object Title -Like $CurrentMobileNumber

if (($TPI_CurrentNumber| Measure-Object).Count -eq 0) {
    Write-Warning "No entry with the phone number could be found in the Teams Phone Inventory, so no entry is adjusted. The entry will be added automatically during the next Teams Phone Inventory update cycle."
    Write-Output ""
    Write-Output "Done!"
    Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
    Get-PSSession | Remove-PSSession | Out-Null
    Exit
}

Write-Output "Related entry found - List ID: $($TPI_CurrentNumber.ID)"

########################################################
##             Block 6 - Write Output to TPI
##          
########################################################

Write-Output ""
$Message = "Block 6 - Write Output to TPI"
Write-Output $Message
Write-Output ("-" * $($Message.Length))

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
$ID = $($TPI_CurrentNumber.ID)
$GraphAPIUrl_UpdateElement = $TPIListURL + '/items/'+ $ID
$HTTPBody_UpdateElement = @{
    "fields" = @{
        "Title"= $CurrentMobileNumber
        "UPN"= $UPN
        "OnlineVoiceRoutingPolicy"= ""
        "TenantDialPlan"= ""
        "Status"= "Filled by Set Teams Phone Mobile User Runbook - $TimeStamp"
    }
}
Write-Output "Update entry: $CurrentMobileNumber"
$TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_UpdateElement -Method Patch -Body $HTTPBody_UpdateElement -ProcessPart "TPI List - Update item: $CurrentLineUri"
$HTTPBody_UpdateElement = $null

Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null