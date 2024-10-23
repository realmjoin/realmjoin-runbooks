<#
    .SYNOPSIS
    Assign a phone number to a Microsoft Teams enabled user, enable calling and Grant specific Microsoft Teams policies. The runbook is part of the TeamsPhoneInventory.

    .DESCRIPTION
    Assigns a manually defined phone number and (pre-filled, if applicable) selected voice policies to a Microsoft Teams user. The runbook is part of the TeamsPhoneInventory. 
  
    .NOTES
    Permissions: 
    The connection of the Microsoft Teams PowerShell module is ideally done through the Managed Identity of the Automation account of RealmJoin.
    If this has not yet been set up and the old "Service User" is still stored, the connect is still included for stability reasons. However, it should be switched to Managed Identity as soon as possible.
    
    RunbookCustomization:
    RunbookCustomization is defined separately in the associated RealmJoin portal settings

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.5.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.22.0" }

param(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,

    #Number which should be assigned
    [ValidateScript( { Use-RJInterface -DisplayName "Phone number to assign (E.164 Format - Example:+49123987654" } )]
    [String] $PhoneNumber,

    [String] $OnlineVoiceRoutingPolicy,
    [String] $TenantDialPlan,
    [String] $TeamsCallingPolicy,

    # Define TeamsPhoneInventory SharePoint List
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


########################################################
##             Block 0 - Connect Part
##          
########################################################
# Add Caller in Verbose output
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Add Parameter in Verbose output:
Write-RjRbLog -Message "SharepointSite: '$SharepointSite'" -Verbose
Write-RjRbLog -Message "SharepointTPIList: '$SharepointTPIList'" -Verbose

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
##             Block 1 - License check
##          
########################################################
Write-Output ""
Write-Output "Block 1 - License check"
# If no license has been assigned to the user, respectively if the license is not yet replicated 
# in the teams backend or if the appropriate applications are not available within the license, 
# the script will be stopped!

Write-Output "Getting StatusQuo for user with ID:  $UserName"
$StatusQuo = Get-CsOnlineUser $UserName

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


########################################################
##             Block 2 - Checkup Part
##          
########################################################
Write-Output ""
Write-Output "Block 2 - Check basic parameter"

# Lookup UPN
$UPN = (Get-CsOnlineUser -Identity $UserName).UserPrincipalName

# Check if number is E.164
if ($PhoneNumber -notmatch "^\+\d{8,15}(;ext=\d{1,10})?") {
    Write-Error -Message  "Error: Phone number needs to be in E.164 format ( '+#######...' )." -ErrorAction Continue
    throw "Phone number needs to be in E.164 format ( '+#######...' )."
}else {
    if ($PhoneNumber -match "^\+\d{8,15}") {
        Write-Output "Phone number is in the correct E.164 format (Number: $PhoneNumber)."
    }else {
        Write-Output "Phone number is in the correct E.164 with extension format (Number: $PhoneNumber)."
    }
}

# Check if number is already assigned
$NumberCheck = "Empty"
$CleanNumber = "tel:+"+($PhoneNumber.Replace("+",""))
$NumberCheck = (Get-CsOnlineUser | Where-Object LineURI -Like "*$CleanNumber*").UserPrincipalName
$PhoneNumberAssignment = Get-CsPhoneNumberAssignment | Where-Object { $_.TelephoneNumber -like "$PhoneNumber" }
$PstnAssignmentStatus = $PhoneNumberAssignment.PstnAssignmentStatus

$NumberAlreadyAssigned = 0

if ($PstnAssignmentStatus -like "" -or $PstnAssignmentStatus -like "Unassigned") {
    Write-Output "Phone number is not yet assigned to a Microsoft Teams user"
}else {
    if ($UPN -like $Numbercheck) { #Check if number is already assigned to the target user
        $NumberAlreadyAssigned = 1
        Write-Output "Phone number is already assigned to the user!"
    }elseif ($PhoneNumberAssignment.AssignmentCategory -like "Private") {
        $CurrentPrivateLineUser = (Get-CsOnlineUser $PhoneNumberAssignment.AssignedPstnTargetId).UserPrincipalName
        Write-Error  "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already as private line assigned to $CurrentPrivateLineUser"
        throw "The assignment for could not be performed. PhoneNumber is already assigned!"
        
    }else{
        Write-Error  "Teams - Error: The assignment for $UPN could not be performed. $PhoneNumber is already assigned to $NumberCheck"
        throw "The assignment for could not be performed. PhoneNumber is already assigned!"
    }
}

########################################################
##             Block 3 - Setup base URL
##          
########################################################
Write-Output ""
Write-Output "Block 3 - Check basic connection to TPI List and build base URL"

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
##             Block 4 - Get Status Quo of the main TPI SharePoint List and find entry
##
################################################################################################################
Write-Output ""
Write-Output "Block 4 - Get StatusQuo of the SharePoint List"

$TPI_AllItems = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList

Write-Output "Items in $SharepointTPIList SharePoint List: $($TPI_AllItems.Count)"

Write-Output "Check if number $PhoneNumber exists in TPI"

$TargetEntry = $TPI_AllItems | Where-Object Title -Like $PhoneNumber

$EntryHandling = 0
if ($TargetEntry.Title.count -eq 0) {
    Write-Output "Entry does not exist in TPI"
    $EntryHandling = 1
}elseif ($TargetEntry.Title.count -eq 1) {
    Write-Output "Entry does exist in TPI"
    $EntryHandling = 2
}else {
    Write-Output "Entry does exist more than once in TPI (could be regarding Microsoft Teams Phone Extensions)"
    $EntryHandling = 3
}

########################################################
##             Block 6 - Teams User StatusQuo
##          
########################################################
Write-Output ""

# Get StatusQuo
Write-Output "Block 6 - List StatusQuo for user with ID:  $UserName"

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


########################################################
##             Block 7 - Pre flight check
##          
########################################################
Write-Output ""
Write-Output "Block 7 - Pre flight check"

#Check if number is a calling plan or operator connect number
Write-Output "Check if LineUri is a Calling Plan, Operator Connect or Direct Routing number"
$CallingPlanNumber = (Get-CsPhoneNumberAssignment -NumberType CallingPlan).TelephoneNumber
$OperatorConnectNumber = (Get-CsPhoneNumberAssignment -NumberType OperatorConnect).TelephoneNumber
if (($CallingPlanNumber| Measure-Object).Count -gt 0) {
    if ($CallingPlanNumber -contains $PhoneNumber) {
        $CallingPlanCheck = $true
        Write-Output "Phone number is a Calling Plan number"
    }else{
        $CallingPlanCheck = $false
        $OperatorConnectCheck = $false
        Write-Output "Phone number is a Direct Routing number"
    }
}elseif (($OperatorConnectNumber | Measure-Object).Count -gt 0) {
    if ($OperatorConnectNumber -contains $PhoneNumber) {
        $OperatorConnectCheck = $true
        Write-Output "Phone number is a Operator Connect number"
    }else{
        $CallingPlanCheck = $false
        $OperatorConnectCheck = $false
        Write-Output "Phone number is a Direct Routing number"
    }
}else{
    Write-Output "Phone number is a Direct Routing number"
    $CallingPlanCheck = $false
    $OperatorConnectCheck = $false
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
Clear-Variable TMP

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
    Clear-Variable TMP
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
    Clear-Variable TMP
}

########################################################
##             Block 8 - Main Part
##          
########################################################
Write-Output ""
Write-Output "Block 8 - Main Part"

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


########################################################
##             Block 9 - Write Output to TPI
##          
########################################################

if ($EntryHandling -eq 2) {
    Write-Output ""
    Write-Output "Block 9 - Write Output to TPI"

    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    $ID = $TargetEntry.ID
    $GraphAPIUrl_UpdateElement = $TPIListURL + '/items/' + $ID
    $HTTPBody_UpdateElement = @{
        "fields" = @{
            "UPN"= $UPN
            "OnlineVoiceRoutingPolicy"= $OnlineVoiceRoutingPolicy
            "TeamsCallingPolicy"= $TeamsCallingPolicy
            "TenantDialPlan"= $TenantDialPlan
            "Status"= "Filled by Set Teams Phone User Custom Runbook - $TimeStamp"
        }
    }
    Write-Output "Updating Entry ID: $ID"
    $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_UpdateElement -Method Patch -Body $HTTPBody_UpdateElement -ProcessPart "TPI List - Update item: $PhoneNumber"
    $HTTPBody_UpdateElement = $null
}else {
    Write-Warning "Block 9 - Write Output to TPI"
    Write-Warning "Currently no TPI entry exists/multiple TPI entries exists(Teams Phone Extension) - TPI List will be updated in the next sync cycle"
}



Write-Output ""
Write-Output "Done!"

Disconnect-MicrosoftTeams -Confirm:$false | Out-Null
Get-PSSession | Remove-PSSession | Out-Null