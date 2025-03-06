<#
  .SYNOPSIS
  Teams Phone Inventory - Main Part (Updater)

  .DESCRIPTION
  This runbook fills the defined SharePoint list with all available phone numbers, which can be assigned as extension. 
  This list of phone numbers is then merged with a current state of the assigned phone numbers in Microsoft Teams, 
  as well as the stored legacy numbers and thus results in a current overview of assigned and free phone numbers.
  The runbook is part of the TeamsPhoneInventory.

  .NOTES
  Version Changelog:
  1.2.0 - 2025-03-07 - Fix region handling
                     - Add function Export-TeamsPhoneNumbers to resolve the error regarding MC950880 - Update to Get-CsPhoneNumberAssignment (Only 1000 numbers are returned)
                     - Add handling of group based policy assignments
  1.1.0 - 2025-01-09 - Fix "EmptyString"/$null missmatch for NumberCapability and EmergencyAddressName
                     - New Get-TPIList function
                       - For better handling of SharePoint Lists
                       - Removed conversion of returned list object (no longer needed, cause of the new function)
                     - Simplified Invoke-TPIRestMethod function
                     - Improved logging with Enhanced Logging Output (switchable with $EnableEnhancedLoggingOutput in the script)
                     - Disabled Verbose output for GraphAPI (by the own functions) by default (for performance reasons)
  1.0.0 - 2024-12-20 - Initial Version (=first version in which versioning is defined)

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
  The name of the SharePoint list, which inlucdes the extension ranges.
  Example: TPI-ExtensionRange

  .PARAMETER SharepointLegacyList
  The name of the SharePoint list, which inlucdes assigned legacy phone numbers.
  Example: TPI-Legacy

  .PARAMETER SharepointBlockExtensionList
  The name of the SharePoint list, which inlucdes the blocked extensions.
  Example: TPI-BlockExtension

  .PARAMETER SharepointCivicAddressMappingList
  The name of the SharePoint list, which includes the mapping of the emergency address
  Example: TPI-CivicAddressMapping

  .PARAMETER SharepointLocationDefaultsList
  The name of the SharePoint list that contains the standard for a location with regard to phone numbers and policies
  Example: TPI-LocationDefaults

  .PARAMETER SharepointLocationMappingList
  The name of the SharePoint list that contains the assignment of AD attributes to locations
  Example: TPI-LocationMapping

  .PARAMETER SharepointUserMappingList
  The name of the SharePoint list that contains the assignment of users to locations.
  Example: TPI-UserMapping

  .PARAMETER BlockExtensionDays
  How long should a number been blocked after offboarding (in days) 
  Example: 180

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
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
            "SharepointCivicAddressMappingList": {
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
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "6.8.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.25.0" }

########################################################
#region Parameter declaration
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
    [int] $BlockExtensionDays = 180,

    # CallerName is tracked purely for auditing purposes
    [string] $CallerName
)

#endregion

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
        }
        else {
            $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Verbose:$VerboseGraphAPILogging
        }
    }
    catch {
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
            }
            else {
                $TPIRestMethod = Invoke-MgGraphRequest -Uri $Uri -Method $Method -Verbose:$VerboseGraphAPILogging
            }
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output "$TimeStamp - GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
        }
        catch {
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

function Export-TeamsPhoneNumbers {
    param (
        [int]$WaitTime = 1,
        [int]$MaxTries = 60,
        [switch]$MapUserPrincipalNames,
        [hashtable]$TeamsUsers
    )

    <#
        .SYNOPSIS
        Exports all phone numbers within the tenant.

        .DESCRIPTION
        This function exports all phone numbers within the tenant. It uses the Teams PowerShell module to export the phone numbers and then processes the CSV-like content into PSCustomObjects. 
        The function also maps the UserPrincipalNames to the phone numbers if the MapUserPrincipalNames switch is set. Therefore, a hashtable with the TeamsUsers is required or will be generated if the TeamsUsers hashtable is not provided.

        .PARAMETER WaitTime
        The time in seconds to wait between status queries. The default value is 1 second.

        .PARAMETER MaxTries
        The maximum number of attempts to query the status. The default value is 60.

        .PARAMETER MapUserPrincipalNames
        A switch to enable the mapping of UserPrincipalNames to the phone numbers. If this switch is set, the UserPrincipalNames will be mapped to the phone numbers. The default value is $false.

        .PARAMETER TeamsUsers

    #>

    if (!$MapUserPrincipalNames) {
        Write-Verbose "Export-TeamsPhoneNumbers - MapUserPrincipalNames switch not set. UserPrincipalNames will not be mapped."
    }
    else {
        Write-Verbose "Export-TeamsPhoneNumbers - MapUserPrincipalNames switch set. UserPrincipalNames will be mapped."
    }

    # If the TeamsUsers hashtable is not provided and the DontMapUserPrincipalNames switch is not set, generate the TeamsUsers hashtable
    if ($null -eq $TeamsUsers -and $MapUserPrincipalNames) {
        Write-Verbose "TeamsUsers hashtable not provided. Generate it now..."
        $TeamsUsers = @{}
        $users = Get-CsOnlineUser -Filter { LineUri -like "tel:*" }
        foreach ($user in $users) {
            $TeamsUsers.Add($user.Identity, $user.UserPrincipalName)
        }
    }

    # Start the export of phone numbers
    Write-Verbose "Starting export of phone numbers..."
    $orderID = Export-CsAcquiredPhoneNumber

    $tries = 0
    $link = $null

    Write-Verbose "Export started... Waiting for download link."
    Write-Verbose "Defined wait time between status queries: $($WaitTime) seconds"

    # Repeated status query until the download link is available or the maximum number of attempts is reached
    while ($tries -lt $MaxTries -and [string]::IsNullOrEmpty($link)) {
        Start-Sleep -Seconds $WaitTime
        $status = Get-CsExportAcquiredPhoneNumberStatus -orderID $orderID
        $link = $status.DownloadLink
        $tries++
        Write-Verbose "Attempt $($tries)/$($MaxTries): Status = $($status.Status)"
    }

    if ([string]::IsNullOrEmpty($link)) {
        Write-Error "No download link received. Aborting."
        return $null
    }

    Write-Verbose ""
    Write-Verbose "Download link received"#: $link"
    Write-Verbose ""

    # Download the file content directly into memory
    $content = Invoke-RestMethod -Uri $link

    # Convert CSV content into objects without saving to disk
    $phoneNumbers = $content | ConvertFrom-Csv

    # Transform the CSV objects into PSCustomObjects with resolved array values for multiple properties
    $customObjects = $phoneNumbers | ForEach-Object {
        $LocationUpdateSupported = $false
        $obj = $_ | Select-Object *
        foreach ($prop in $_.PSObject.Properties.Name) {
            if ($_.$prop -match "^\[.*\]") {
                $arrayValues = ($_.$prop -replace "\[|\]" -split ",").Trim() | ForEach-Object { $_ -replace '"', '' }
                if (($prop -like "SupportedCustomerActions") -and ($arrayValues -contains "LocationUpdate")) {
                    $LocationUpdateSupported = $true
                    $obj | Add-Member -MemberType NoteProperty -Name "LocationUpdateSupported" -Value $true -Force
                }
                $obj | Add-Member -MemberType NoteProperty -Name $prop -Value $arrayValues -Force
            }
        }
        if ($LocationUpdateSupported -eq $false) {
            $obj | Add-Member -MemberType NoteProperty -Name "LocationUpdateSupported" -Value $false -Force
        }
        if ($MapUserPrincipalNames) {
            if (!([string]::IsNullOrEmpty($obj.TargetId))) {
                try {
                    if ($TeamsUsers[$obj.TargetId] -notlike "") {
                        $obj | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $TeamsUsers[$obj.TargetId] -Force -ErrorAction Stop
                    }
                    else {
                        Write-Verbose "TargetId $($obj.TargetId) not found in TeamsUsers hashtable. Adding UserPrincipalName as null."
                        $obj | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $null -Force
                    }
                }
                catch {
                    Write-Verbose "An error occurred while adding UserPrincipalName. Stopping script. Current User Identity: $($obj.TargetId)"
                    exit
                }
            }
        }
        else {
            $obj | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $null -Force
        }
        $obj
    }

    Write-Verbose "Export completed. Number of phone numbers: $($customObjects.Count)"
    return $customObjects
}

function Get-GroupMembership {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupObjectId
    )

    <#
        .SYNOPSIS
        Retrieves the members of a group, even if the groups are nested.

        .DESCRIPTION
        This function retrieves the members of a group, even if the groups are nested. It uses the Microsoft Graph API to retrieve the members of the group and processes them recursively. If a member is a user, it adds it to the report. If a member is a group, it calls the function recursively to retrieve the members of that group.

        .PARAMETER GroupObjectId
        The object ID of the group to retrieve the members for. This parameter is mandatory.

        .EXAMPLE
        Get-GroupMembership -GroupObjectId "00000000-0000-0000-0000-000000000000"
        Retrieves the members of the group with the object ID "00000000-0000-0000-0000-000000000000".

        .OUTPUTS
        The function returns an array of objects with the following properties:
        - UserPrincipalName: The user principal name of the member.
        - Id: The ID of the member.
        - DirectMember: Indicates whether the member is a direct member of the group or a nested member.

        .NOTES
        Required Graph API permissions:
        - Group.Read.All
        - User.Read.All
    #>

    $report = @()

    # Get the group object
    $group = Invoke-MGGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$GroupObjectId"
    
    # Get the members of the group
    $members = @()
    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupObjectId/members"
    do {
        $response = Invoke-MGGraphRequest -Method GET -Uri $uri
        $members += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    # Process the members - if a member is a user, add it to the report, if it's a group, call the function recursively
    foreach ($member in $members) {
        if ($member."@odata.type" -eq "#microsoft.graph.user") {
            $DirectMemberStatus = if ($ParentGroupPath) { "No" } else { "Yes" }
            $report += [PSCustomObject]@{
                UserPrincipalName = $member.UserPrincipalName
                Id                = $member.id
                DirectMember      = $DirectMemberStatus
            }
        }
        elseif ($member."@odata.type" -eq "#microsoft.graph.group") {
            $report += Get-GroupMembership -GroupObjectId $($member.id)
        }
    }

    return $report
}

#endregion

########################################################
#region Logo Part
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


#endregion

########################################################
#region Properties declaration
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


#endregion

########################################################
#region RJ Log Part
##          
########################################################

# Add Caller in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

# Add Version in Verbose output
$Version = "1.2.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SharepointSite: $SharepointSite" -Verbose
Write-RjRbLog -Message "SharepointTPIList: $SharepointTPIList" -Verbose
Write-RjRbLog -Message "SharepointNumberRangeList: $SharepointNumberRangeList" -Verbose
Write-RjRbLog -Message "SharepointExtensionRangeList: $SharepointExtensionRangeList" -Verbose
Write-RjRbLog -Message "SharepointLegacyList: $SharepointLegacyList" -Verbose
Write-RjRbLog -Message "SharepointBlockExtensionList: $SharepointBlockExtensionList" -Verbose
Write-RjRbLog -Message "SharepointCivicAddressMappingList: $SharepointCivicAddressMappingList" -Verbose
Write-RjRbLog -Message "SharepointLocationDefaultsList: $SharepointLocationDefaultsList" -Verbose
Write-RjRbLog -Message "SharepointLocationMappingList: $SharepointLocationMappingList" -Verbose
Write-RjRbLog -Message "SharepointUserMappingList: $SharepointUserMappingList" -Verbose
Write-RjRbLog -Message "BlockExtensionDays: $BlockExtensionDays" -Verbose

# To enable enhanced verbose logging, set the following variable to $true.
# For performance reasons, in a production environment, this has to be set to $false, 
# as it would massively extend the runtime of the script.
$EnableEnhancedLoggingOutput = $false

# !!!!! Verbose output is disabled by default !!!!!
# Important to know in context of logging and specially for verbose logging:
# The Function Get-TPIList, Invoke-TPIRestMethod and Export-TeamsPhoneNumbers have a parameter called "VerboseGraphAPILogging".
# This parameter is used to enable or disable the verbose output of the function.
# By default, the verbose output is disabled.
$VerboseGraphAPI = $false

#endregion
########################################################
#region Connect Part
##          
########################################################

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Connect to Microsoft Teams (PowerShell as managed identity)"

try {
    $VerbosePreference = "SilentlyContinue"
    $tmp = Connect-MicrosoftTeams -Identity -ErrorAction Stop
    $VerbosePreference = "Continue"
    # Check if Teams connection is active
    Get-CsTenant -ErrorAction Stop | Out-Null
}
catch {
    Start-Sleep -Seconds 5
    try {
        $VerbosePreference = "SilentlyContinue"
        $tmp = Connect-MicrosoftTeams -Identity -ErrorAction Stop
        $VerbosePreference = "Continue"
        # Check if Teams connection is active
        Get-CsTenant -ErrorAction Stop | Out-Null
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
    $VerbosePreference = "SilentlyContinue"
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    $VerbosePreference = "Continue"
}
catch {
    Write-Error "MGGraph Connect failed - stopping script"
    Exit 
}

#endregion
########################################################
#region RampUp Connection Details
##          
########################################################

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Connection - Check basic connection to TPI List"

$SharepointURL = (Invoke-TPIRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/root" -Method GET -ProcessPart "Get SharePoint WebURL"  -VerboseGraphAPILogging:$VerboseGraphAPI).webUrl
if ($SharepointURL -like "https://*") {
    $SharepointURL = $SharepointURL.Replace("https://", "")
}
elseif ($SharepointURL -like "http://*") {
    $SharepointURL = $SharepointURL.Replace("http://", "")
}

# Setup Base URL - not only for NumberRange etc.
$BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/teams/' + $SharepointSite + ':/lists/'
$TPIListURL = $BaseURL + $SharepointTPIList
try {
    Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" -ErrorAction Stop -VerboseGraphAPILogging:$VerboseGraphAPI | Out-Null
}
catch {
    $BaseURL = 'https://graph.microsoft.com/v1.0/sites/' + $SharepointURL + ':/sites/' + $SharepointSite + ':/lists/'
    $TPIListURL = $BaseURL + $SharepointTPIList
    try {
        Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" -ErrorAction Stop -VerboseGraphAPILogging:$VerboseGraphAPI | Out-Null
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
#region Get Content NumberRange, Extensionrange, CivicAddressMapping
##          
########################################################

# # Block 1
#  - Arrays aufbauen
#  - ExtensionRange Array
#  - NumberRange Array

#Setup URL for NumberRange, ExtensionRange & CivicAddressMapping List
$NumberRangeListURL = $BaseURL + $SharepointNumberRangeList
$ExtensionRangeListURL = $BaseURL + $SharepointExtensionRangeList
$CivicAddressMappingListURL = $BaseURL + $SharepointCivicAddressMappingList


$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 1 - RampUp: Get content from NumberRange, ExtensionRange and CivicAddressMapping List"

#Get List for NumberRange, ExtensionRange & CivicAddressMapping List 
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Get StatusQuo of NumberRange SharePoint List - ListName: $($SharepointNumberRangeList)"
$NumberRanges = Get-TPIList -ListBaseURL $NumberRangeListURL -ListName $SharepointNumberRangeList -Properties $ListProperties_NumberRange -TitelNameReplacement $TitelNameReplacement_NumberRange -VerboseGraphAPILogging:$VerboseGraphAPI

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Get StatusQuo of ExtensionRange SharePoint List - ListName: $($SharepointExtensionRangeList)"
$ExtensionRanges = Get-TPIList -ListBaseURL $ExtensionRangeListURL -ListName $SharepointExtensionRangeList -Properties $ListProperties_ExtensionRange -TitelNameReplacement $TitelNameReplacement_ExtensionRange -VerboseGraphAPILogging:$VerboseGraphAPI 

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Get StatusQuo of CivicAddressMapping SharePoint List - ListName: $($SharepointCivicAddressMappingList)"
$CivicAddressMappings = Get-TPIList -ListBaseURL $CivicAddressMappingListURL -ListName $SharepointCivicAddressMappingList -Properties $ListProperties_CivicAddressMapping -TitelNameReplacement $TitelNameReplacement_CivicAddressMapping -VerboseGraphAPILogging:$VerboseGraphAPI 


#region Check Extension Ranges
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Check if there are errors in the number or extension ranges (e.g. extension 90 to 10 (values swapped))"

foreach ($NumberRange in $NumberRanges) {
    if ($NumberRange.BeginUserRange -gt $NumberRange.EndUserRange) {
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
    if ($StartNumber -gt $EndNumber) {
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
Write-Output "$TimeStamp - Block 1 - List all numbers in defined extension ranges and fill MainArray"
$ExtensionRangeCounter = 0
$ExtensionRangeAmount = ($ExtensionRanges | Measure-Object).Count

[System.Collections.ArrayList]$MainArray = @()
$Counter = 0

foreach ($ExtensionRange in $ExtensionRanges) {
    $StartNumber = $ExtensionRange.BeginExtensionRange
    $EndNumber = $ExtensionRange.EndExtensionRange
    $ExtensionRangeName = $ExtensionRange.ExtensionRangeName
    $CurrentNumberRangeIndex = $ExtensionRange.NumberRangeIndex
    $CurrentExtensionRangeIndex = $ExtensionRange.ExtensionRangeIndex
    
    $ExtensionRangeCounter++
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 1 - $($ExtensionRangeCounter.toString().PadLeft($($ExtensionRangeAmount.toString().length),'0'))/$($ExtensionRangeAmount) - Current extension range: $($ExtensionRangeName)"
    
    foreach ($NumberRange in $NumberRanges) {
        if ($NumberRange.NumberRangeIndex -like $CurrentNumberRangeIndex) {
            $Country = $NumberRange.Country
            $City = $NumberRange.City
            $Company = $NumberRange.Company
            $NumberRangeName = $NumberRange.NumberRangeName
            $CurrentMainNumber = $NumberRange.MainNumber
            
            $StartNumber..$EndNumber | ForEach-Object {
                $CurrentExtension = $_.toString().PadLeft(($EndNumber.toString().Length), '0')
                $CurrentLineUri = $CurrentMainNumber + $CurrentExtension
                if ($MainArray.LineUri -notcontains $CurrentLineUri) {
                    $NewRow += [pscustomobject]@{'FullLineUri' = $CurrentLineUri; 'MainLineUri' = $CurrentLineUri; 'DID' = $CurrentExtension; 'TeamsEXT' = ''; 'NumberRangeName' = $NumberRangeName; 'ExtensionRangeName' = $ExtensionRangeName; 'CivicAddressMappingName' = 'NoneDefined'; 'UPN' = ''; 'Display_Name' = ''; 'OnlineVoiceRoutingPolicy' = ''; 'TeamsCallingPolicy' = ''; 'DialPlan' = ''; 'TenantDialPlan' = ''; 'TeamsPrivateLine' = ''; 'VoiceType' = ''; 'UserType' = ''; 'NumberCapability' = 'User and Service'; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = $CurrentExtensionRangeIndex; 'CivicAddressMappingIndex' = 'NoneDefined'; 'Country' = $Country; 'City' = $City; 'Company' = $Company; 'EmergencyAddressName' = ''; 'Status' = '' }
                    $MainArray += $NewRow
                    $NewRow = $null  
                }
                else {
                    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                    Write-Error "$TimeStamp - Error - $CurrentLineUri from Current Extension Range $ExtensionRangeName is already in MainArray - Extension Range duplicate or overlap!"
                }  
            }
        }
    }        
}
#endregion

#region Fill the NumberRangeArray with every single extension of the entire number ranges
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Fill the NumberRangeArray with every single extension of the entire number ranges"
$NumberRangeCounter = 0
$NumberRangeAmount = ($NumberRanges | Measure-Object).Count

[System.Collections.ArrayList]$NumberRangeArray = @()

foreach ($NumberRange in $NumberRanges) {
    $CurrentNumberRangeIndex = $NumberRange.NumberRangeIndex
    $CurrentName = $NumberRange.NumberRangeName
    $CurrentMainNumber = $NumberRange.MainNumber
    $CurrentStartNumber = [int]$NumberRange.BeginNumberRange
    $CurrentEndNumber = [int]$NumberRange.EndNumberRange
    $CurrentCountry = $NumberRange.Country
    $CurrentCity = $NumberRange.City
    $CurrentCompany = $NumberRange.Company

    $NumberRangeCounter++
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 1 - $($NumberRangeCounter.toString().PadLeft($($NumberRangeAmount.toString().length),'0'))/$($NumberRangeAmount) - Current number range: $($CurrentName)"

    $EndNumberDigits = $NumberRange.EndNumberRange.Length
    $DIDSet = [System.Collections.Generic.HashSet[string]]::new()

    if ($CurrentStartNumber -le $CurrentEndNumber) {
        for ($i = $CurrentStartNumber; $i -le $CurrentEndNumber; $i++) {
            $CurrentExtension = $i.ToString().PadLeft($EndNumberDigits, '0')
            if (-not $DIDSet.Contains($CurrentExtension)) {
                $CurrentLineUri = $CurrentMainNumber + $CurrentExtension
                $NewRow = [pscustomobject]@{
                    'NumberRangeIndex' = $CurrentNumberRangeIndex
                    'NumberRangeName'  = $CurrentName
                    'LineUri'          = $CurrentLineUri
                    'DID'              = $CurrentExtension
                    'Country'          = $CurrentCountry
                    'City'             = $CurrentCity
                    'Company'          = $CurrentCompany
                }
                [void]$NumberRangeArray.Add($NewRow)
                [void]$DIDSet.Add($CurrentExtension)
                # [void] - suppress output
            }
        }
    }
    else {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output ""
        Write-Output "$TimeStamp - Block 1  - Error: Start Number is greater than End Number"
        Write-Output "$TimeStamp - Block 1  - Current Number Range: $CurrentName"
    }
}

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - Finished Helper Array (Whole Number Range)"
#endregion

#endregion
########################################################
#region Teams
##          
########################################################

# # Block 2 Teams
# - User abrufen
# - Foreach -> Merge in Main Array
#     - not in Main Array -> Add Entry

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 2 - Retrieve all Microsoft Teams Users, which have an LineUri"
$AllTeamsUser = Get-CsOnlineUser -Filter { LineUri -like "tel:*" } | Select-Object Identity, DisplayName, UserPrincipalName, LineUri, TeamsCallingPolicy, OnlineVoiceRoutingPolicy, InterpretedUserType, EnterpriseVoiceEnabled, HostingProvider, DialPlan, TenantDialPlan, AssignedPlan
$CounterAllTeamsUser = ($AllTeamsUser | Measure-Object).Count

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Received Microsoft Teams users, which have an LineUri: $CounterAllTeamsUser"

#region Retrieve all phone numbers and LIS addresses from the tenant
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Retrieve all phone numbers and LIS addresses from the tenant"
# NumberType - Supported values are DirectRouting, CallingPlan, and OperatorConnect. "-Top" thing is required to get all entries.
$PhoneNumberAssignment = Export-TeamsPhoneNumbers -Verbose:$VerboseGraphAPILogging
$OnlineLisCivicAddress = Get-CsOnlineLisCivicAddress

$CounterPhoneNumber = ($PhoneNumberAssignment | Measure-Object).Count
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Received phone numbers from tenant: $CounterPhoneNumber"

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Rearrange phone number array"

[System.Collections.ArrayList]$OnlinePhoneNumbers = @()
foreach ($PhoneNumber in $PhoneNumberAssignment ) {
    $CurrentLISCivicAddress = $OnlineLisCivicAddress | Where-Object CivicAddressId -Like $($PhoneNumber.CivicAddressId)
    $CurrentCivicAddressMapping = $CivicAddressMappings | Where-Object CivicAddressID -Like $($CurrentLISCivicAddress.CivicAddressId)
    $CurrentUser = $AllTeamsUser | Where-Object Identity -Like $($PhoneNumber.AssignedPstnTargetId)

    if ($CurrentUser -notlike "") {
        $Teams_LineUri = $null
        $Teams_LineUri_Extension = $null
        $Teams_FullLineUri = $null
        $Teams_MainLineUri = $null
    
        # Cut off tel: prefix
        if ($CurrentUser.LineUri.StartsWith('tel:')) {
            $Teams_LineUri = $CurrentUser.LineUri.Substring(4, ($CurrentUser.LineUri.Length - 4))
            if (!($Teams_LineUri.StartsWith('+'))) {
                $Teams_LineUri = '+' + $($Teams_LineUri -replace $null, "")
            }
        }
        else {
            #Check if number start with '+' - if not - add it
            if (!($CurrentUser.LineUri.StartsWith('+'))) {
                $Teams_LineUri = '+' + $($CurrentUser.LineUri -replace $null, "")
            }
            else {
                $Teams_LineUri = $CurrentUser.LineUri
            }
        }

        if ($Teams_LineUri -like '*;ext=*') {
            $Teams_LineUri_Extension = $Teams_LineUri.Substring(($Teams_LineUri.IndexOf(';') + 1), ($Teams_LineUri.Length - ($Teams_LineUri.IndexOf(';') + 1))).Replace("ext=", "")
            $Teams_MainLineUri = $Teams_LineUri.Substring(0, $Teams_LineUri.IndexOf(';')) #Cut off Extensions - +49432156789;ext=789 -> finallly +49432156789
            $Teams_FullLineUri = $Teams_LineUri
        }
        else {
            $Teams_FullLineUri = $Teams_LineUri
            $Teams_MainLineUri = $Teams_LineUri
            $Teams_LineUri_Extension = ""
        }

    }
    else {
        $Teams_LineUri = $null
        $Teams_LineUri_Extension = $null
        $Teams_FullLineUri = $null
        $Teams_MainLineUri = $null
    }
    $IsTeamsPhoneMobile = $false
    $CurrentCapability = $null
    if (($PhoneNumber.Capability | Measure-Object).Count -gt 1) {
        if ($PhoneNumber.Capability -contains "UserAssignment") {
            if ($PhoneNumber.Capability -contains "TeamsPhoneMobile") {
                $CurrentCapability = "User"
                $IsTeamsPhoneMobile = $true
            }
            else {
                $CurrentCapability = "User and Service"
            }
        
        }
        else {
            $CurrentCapability = "Service"
        }
    }
    else {
        if ($PhoneNumber.Capability -like "UserAssignment") {
            $CurrentCapability = "User"
        }
        else {
            $CurrentCapability = "Service"
        }
    }

    $TMPCivicAddressMappingIndex = "NoneDefined"
    $TMPCivicAddressMappingName = "NoneDefined"
    $TMPCivicAddressDescription = "NoneDefined"
    $TMPCivicAddressID = "NoneDefined"

    if (($($PhoneNumber.CivicAddressId) -notlike "") -or ($null -ne $PhoneNumber.CivicAddressId)) {
        if ($CurrentCivicAddressMapping.CivicAddressMappingIndex -notlike "") {
            $TMPCivicAddressMappingIndex = $CurrentCivicAddressMapping.CivicAddressMappingIndex
        }
        else {
            $TMPCivicAddressMappingIndex = "NoneDefined"
        }
    
        if ($CurrentCivicAddressMapping.CivicAddressMappingName -notlike "") {
            $TMPCivicAddressMappingName = $CurrentCivicAddressMapping.CivicAddressMappingName
        }
        else {
            $TMPCivicAddressMappingName = "NoneDefined"
        }
    
        if ($CurrentCivicAddressMapping.CivicAddressID -notlike "") {
            $TMPCivicAddressID = $CurrentCivicAddressMapping.CivicAddressID
        }
        else {
            $TMPCivicAddressID = "NoneDefined"
        }

        if ($CurrentLISCivicAddress.Description -notlike "") {
            $TMPCivicAddressDescription = $CurrentLISCivicAddress.Description
        }
        else {
            $TMPCivicAddressDescription = "NoneDefined"
        }
    }

    if ($IsTeamsPhoneMobile) {
        $CurrentNumberType = "TeamsPhoneMobile"
    }
    else {
        $CurrentNumberType = $($PhoneNumber.NumberType -replace $null, "")
    }

    $NewRow = [pscustomobject]@{
        'TelephoneNumber'               = $($PhoneNumber.TelephoneNumber -replace $null, "")
        'NumberType'                    = $CurrentNumberType
        'ActivationState'               = $($PhoneNumber.ActivationState -replace $null, "")
        'AssignedPstnTargetId'          = $($PhoneNumber.AssignedPstnTargetId -replace $null, "")
        'AssignedPstnTargetUPN'         = $($CurrentUser.UserPrincipalName)
        'AssignedPstnTargetDisplayName' = $($CurrentUser.DisplayName)
        'AssignedPstnTargetFullLineUri' = $Teams_FullLineUri
        'AssignedPstnTargetMainLineUri' = $Teams_MainLineUri
        'AssignedPstnTargetTeamsEXT'    = $Teams_LineUri_Extension
        'AssignmentCategory'            = $($PhoneNumber.AssignmentCategory -replace $null, "")
        'Capability'                    = $($CurrentCapability -replace $null, "")
        'City'                          = $($PhoneNumber.City -replace $null, "")
        'CivicAddressMappingIndex'      = $($TMPCivicAddressMappingIndex -replace $null, "")
        'CivicAddressMappingName'       = $($TMPCivicAddressMappingName -replace $null, "")
        'CivicAddressID'                = $($TMPCivicAddressID -replace $null, "")
        'CivicAddressCity'              = $($CurrentLISCivicAddress.City -replace $null, "")
        'CivicAddressCityAlias'         = $($CurrentLISCivicAddress.CityAlias -replace $null, "")
        'CivicAddressCountryOrRegion'   = $($CurrentLISCivicAddress.CountryOrRegion -replace $null, "")
        'CivicAddressDescription'       = $($TMPCivicAddressDescription -replace $null, "")
        'CivicAddressCompanyName'       = $($CurrentLISCivicAddress.CompanyName -replace $null, "")
        'IsoCountryCode'                = $($PhoneNumber.IsoCountryCode -replace $null, "")
        'LocationId'                    = $($PhoneNumber.LocationId -replace $null, "")
        'PstnAssignmentStatus'          = $($PhoneNumber.PstnAssignmentStatus -replace $null, "")
        'IsTeamsPhoneMobile'            = $IsTeamsPhoneMobile
    }
    $OnlinePhoneNumbers += $NewRow
    $NewRow = $null
    try {
        Clear-Variable -Name ("CurrentUser", "Teams_FullLineUri", "Teams_MainLineUri", "Teams_LineUri_Extension", "CurrentCapability", "TMPCivicAddressMappingIndex", "TMPCivicAddressMappingName", "TMPCivicAddressID", "IsTeamsPhoneMobile")
    }
    catch {
    }

}

$PhoneNumberAssignment = $null
#endregion
#region Retrieve all Microsoft Teams IP-Phone policies
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Retrieve all Microsoft Teams IP-Phone policies"
$TeamsIPPhonePolicies = Get-CsTeamsIPPhonePolicy

#endregion

#region Retrieve all group policy assignments
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Retrieve all group policy assignments"
$groupPolicyAssignments = Get-CsGroupPolicyAssignment

# Initialize a hashtable to store the highest priority policy for each user
$userPolicies = @{}
$relevantPolicyTypes = @("OnlineVoiceRoutingPolicy", "TeamsCallingPolicy", "TenantDialPlan", "TeamsIPPhonePolicy")

foreach ($assignment in $groupPolicyAssignments) {
    if ($null -eq $relevantPolicyTypes -or $assignment.PolicyType -in $relevantPolicyTypes) {
        $policyType = $assignment.PolicyType
        $policyName = $assignment.PolicyName
        $groupMembers = Get-GroupMembership -GroupObjectId $assignment.GroupId
    
        foreach ($member in $groupMembers) {
            $userPrincipalName = $member.UserPrincipalName
    
            if (-not $userPolicies.ContainsKey($userPrincipalName)) {
                $userPolicies[$userPrincipalName] = @{}
            }
    
            if (-not $userPolicies[$userPrincipalName].ContainsKey($policyType) -or $assignment.Priority -lt $userPolicies[$userPrincipalName][$policyType].Priority) {
                $userPolicies[$userPrincipalName][$policyType] = @{
                    PolicyName = $policyName
                    UserID     = $member.Id
                    Priority   = $assignment.Priority
                }
            }
        }
    }

}

# Create a list to store the final output
$teamsGroupPolicyAssignments = @()

foreach ($user in $userPolicies.Keys) {
    foreach ($policyType in $userPolicies[$user].Keys) {
        $teamsGroupPolicyAssignments += [PSCustomObject]@{
            UserPrincipalName = $user
            UserID            = $userPolicies[$user][$policyType].UserID
            PolicyType        = $policyType
            PolicyName        = $userPolicies[$user][$policyType].PolicyName
        }
    }
}

#endregion
#region Merge all collected Microsoft Teams user in the main array
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Merge all collected Microsoft Teams user in the main array"

$Counter = 0

if ($CounterAllTeamsUser -gt 0) {
    # Merge Teams Users into the main array
    foreach ($TeamsUser in $AllTeamsUser) {

        # Cut off tel: prefix
        if ($TeamsUser.LineUri.StartsWith('tel:')) {
            $Teams_LineUri = $TeamsUser.LineUri.Substring(4, ($TeamsUser.LineUri.Length - 4))
            if (!($Teams_LineUri.StartsWith('+'))) {
                $Teams_LineUri = '+' + $($Teams_LineUri -replace $null, "")
            }
        }
        else {
            #Check if number start with '+' - if not - add it
            if (!($TeamsUser.LineUri.StartsWith('+'))) {
                $Teams_LineUri = '+' + $($TeamsUser.LineUri -replace $null, "")
            }
        }

        # Check if LineUri contains an extension
        if ($Teams_LineUri -like '*;ext=*') {
            $Teams_LineUri_Extension = $Teams_LineUri.Substring(($Teams_LineUri.IndexOf(';') + 1), ($Teams_LineUri.Length - ($Teams_LineUri.IndexOf(';') + 1))).Replace("ext=", "")
            $Teams_MainLineUri = $Teams_LineUri.Substring(0, $Teams_LineUri.IndexOf(';')) #Cut off Extensions - +49432156789;ext=789 -> finallly +49432156789
            $Teams_FullLineUri = $Teams_LineUri
        }
        else {
            $Teams_FullLineUri = $Teams_LineUri
            $Teams_MainLineUri = $Teams_LineUri
            $Teams_LineUri_Extension = ""
        }

        $Teams_UPN = $TeamsUser.UserPrincipalName -replace $null, ""
        $Teams_DisplayName = $TeamsUser.DisplayName -replace $null, ""
        
        $CurrentPhoneNumberAssignment = $null
        $CurrentPhoneNumberAssignment = $OnlinePhoneNumbers | Where-Object AssignedPstnTargetId -like $TeamsUser.Identity
        
        $PhoneNumberExistInTenant = $false

        $Teams_PrivateLine = ($CurrentPhoneNumberAssignment | Where-Object AssignmentCategory -Like "Private").TelephoneNumber -replace $null, ""

        if ($Teams_PrivateLine -like "") {
            $Teams_PrivateLine = "NoneDefined"
        }

        if (($CurrentPhoneNumberAssignment | Where-Object AssignmentCategory -Like "Primary").TelephoneNumber -notlike "") {
            $PhoneNumberExistInTenant = $true
            $CurrentPrimaryPhoneNumberAssignment = $CurrentPhoneNumberAssignment | Where-Object AssignmentCategory -Like "Primary"
        }
        # During tests it was noticed in some tenants that the return value differs from tenant to tenant
        # For some tenants the name of the policy could be retrieved directly, for some it has to be differentiated again by .name
        if ($TeamsUser.DialPlan.PSObject.Properties.Name -contains "Authority") {
            $Teams_DialPlan = $TeamsUser.DialPlan.Name -replace $null, ""
        }
        else {
            $Teams_DialPlan = $TeamsUser.DialPlan -replace $null, ""
        }

        if ($Teams_DialPlan -like "") {
            $Teams_DialPlan = "Global"
        }

        if ($TeamsUser.OnlineVoiceRoutingPolicy.PSObject.Properties.Name -contains "Authority") {
            $Teams_OnlineVoiceRoutingPolicy = $TeamsUser.OnlineVoiceRoutingPolicy.Name -replace $null, ""
        }
        else {
            $Teams_OnlineVoiceRoutingPolicy = $TeamsUser.OnlineVoiceRoutingPolicy -replace $null, ""
        }
        
        if ($Teams_OnlineVoiceRoutingPolicy -like "") {
            $Teams_OnlineVoiceRoutingPolicy = ($teamsGroupPolicyAssignments | Where-Object { $_.UserID -eq $TeamsUser.Identity -and $_.PolicyType -eq "OnlineVoiceRoutingPolicy" }).PolicyName
            if ($Teams_OnlineVoiceRoutingPolicy -like "") {
                $Teams_OnlineVoiceRoutingPolicy = "Global"
            }
        }
        
        if ($TeamsUser.TeamsCallingPolicy.PSObject.Properties.Name -contains "Authority") {
            $Teams_TeamsCallingPolicy = $TeamsUser.TeamsCallingPolicy.Name -replace $null, ""
        }
        else {
            $Teams_TeamsCallingPolicy = $TeamsUser.TeamsCallingPolicy -replace $null, ""
        }
        
        if ($Teams_TeamsCallingPolicy -like "") {
            $Teams_TeamsCallingPolicy = ($teamsGroupPolicyAssignments | Where-Object { $_.UserID -eq $TeamsUser.Identity -and $_.PolicyType -eq "TeamsCallingPolicy" }).PolicyName
            if ($Teams_TeamsCallingPolicy -like "") {
                $Teams_TeamsCallingPolicy = "Global"
            }
        }
        
        if ($TeamsUser.TenantDialPlan.PSObject.Properties.Name -contains "Authority") {
            $Teams_TenantDialPlan = $TeamsUser.TenantDialPlan.Name -replace $null, ""
        }
        else {
            $Teams_TenantDialPlan = $TeamsUser.TenantDialPlan -replace $null, ""
        }
        
        if ($Teams_TenantDialPlan -like "") {
            $Teams_TenantDialPlan = ($teamsGroupPolicyAssignments | Where-Object { $_.UserID -eq $TeamsUser.Identity -and $_.PolicyType -eq "TenantDialPlan" }).PolicyName
            if ($Teams_TenantDialPlan -like "") {
                $Teams_TenantDialPlan = "Global"
            }
        }
        
        if ($TeamsUser.TeamsIPPhonePolicy.Name -like "") {
            $TMPUserTeamsIPPhonePolicy = ($teamsGroupPolicyAssignments | Where-Object { $_.UserID -eq $TeamsUser.Identity -and $_.PolicyType -eq "TeamsIPPhonePolicy" }).PolicyName
            if ($TMPUserTeamsIPPhonePolicy -like "") {
                $TMPUserTeamsIPPhonePolicy = "Global"
            }
        }
        else {
            $TMPUserTeamsIPPhonePolicy = "Tag:" + $TeamsUser.TeamsIPPhonePolicy.Name
        }

        # Define Entry Voice Type
        if ($TeamsUser.LineURI -notlike "") {
            if ($TeamsUser.InterpretedUserType -like "HybridOnPremSfBUserWithTeamsLicense") {
                $Teams_VoiceType = "SkypeForBusiness"
                #Alternative via Hostingprovider SRV: instead of sipfed.online.lync.com
            }
            else {
                if ($TeamsUser.EnterpriseVoiceEnabled -eq $true) {
                    if ($PhoneNumberExistInTenant) {
                        $Teams_VoiceType = $CurrentPrimaryPhoneNumberAssignment.NumberType
                    }
                    else {
                        $Teams_VoiceType = "DirectRouting"
                    }
                }
                else {
                    $Teams_VoiceType = "ActiveDirectory-Legacy"
                }   
            }
        }
        else {
            $Teams_VoiceType = ""
        }

        # Define Entry User Type
        if ($TeamsUser.InterpretedUserType -like "*ApplicationInstance*") {
            $Teams_UserType = "ResourceAccount"
        }
        elseif (($TeamsUser.AssignedPlan.Capability -contains "MCOCAP") -or ($($TeamsIPPhonePolicies | Where-Object Identity -Like  $TMPUserTeamsIPPhonePolicy).SignInMode -like "CommonAreaPhoneSignIn")) {
            $Teams_UserType = "CommonAreaPhone"
        }
        elseif (($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Standard") -or ($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Basic") -or ($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Pro") -or ($TeamsUser.AssignedPlan.Capability -contains "Teams_Room_Premium")) {
            $Teams_UserType = "MeetingRoom"
        }
        else {
            $Teams_UserType = "DefaultUser"
        }
        if ($PhoneNumberExistInTenant) {
            if ($CurrentPrimaryPhoneNumberAssignment.IsTeamsPhoneMobile) {
                # Set all got from the tenant to this number
                $CurrentCivicAddressMappingIndex = "NoneDefined"
                $CurrentCivicAddressMappingName = "NoneDefined"
                $CurrentCivicAddressCity = "Mobile"
                $CurrentCapability = $CurrentPrimaryPhoneNumberAssignment.Capability -replace $null, ""
                $CurrentCivicAddressCountryOrRegion = $CurrentPrimaryPhoneNumberAssignment.IsoCountryCode -replace $null, ""
                $CurrentCivicAddressCompanyName = ""
                $CurrentCivicAddressDescription = "NoneDefined"
                # Handling?
                # PstnAssignmentStatus
            }
            else {
                # Set all got from the tenant to this number
                $CurrentCivicAddressMappingIndex = $CurrentPrimaryPhoneNumberAssignment.CivicAddressMappingIndex -replace $null, ""
                $CurrentCivicAddressMappingName = $CurrentPrimaryPhoneNumberAssignment.CivicAddressMappingName -replace $null, ""
                $CurrentCivicAddressCity = $CurrentPrimaryPhoneNumberAssignment.CivicAddressCity -replace $null, ""
                $CurrentCapability = $CurrentPrimaryPhoneNumberAssignment.Capability -replace $null, ""
                $CurrentCivicAddressCountryOrRegion = $CurrentPrimaryPhoneNumberAssignment.CivicAddressCountryOrRegion -replace $null, ""
                $CurrentCivicAddressCompanyName = $CurrentPrimaryPhoneNumberAssignment.CivicAddressCompanyName -replace $null, ""
                $CurrentCivicAddressDescription = $CurrentPrimaryPhoneNumberAssignment.CivicAddressDescription -replace $null, ""
                # Handling?
                # PstnAssignmentStatus
            }
        }
        else {
            if ($Teams_VoiceType -like "DirectRouting") {
                $CurrentCapability = "User and Service"
            }
            else {
                $CurrentCapability = "NoneDefined"
            }
            $CurrentCivicAddressMappingIndex = "NoneDefined"
            $CurrentCivicAddressMappingName = "NoneDefined"
            $CurrentCivicAddressCity = ""
            $CurrentCivicAddressCountryOrRegion = ""
            $CurrentCivicAddressCompanyName = ""
            $CurrentCivicAddressDescription = "NoneDefined"
        }

        #region Fill MainArray
        #Check if FullLineUri Already in MainArray
        if ($MainArray.FullLineUri -contains $Teams_FullLineUri) {
            $ArrayIndex = [array]::indexof($MainArray.FullLineUri, $Teams_FullLineUri)
            $MainArray[$ArrayIndex].Display_Name = $Teams_DisplayName
            $MainArray[$ArrayIndex].OnlineVoiceRoutingPolicy = $Teams_OnlineVoiceRoutingPolicy
            $MainArray[$ArrayIndex].TeamsCallingPolicy = $Teams_TeamsCallingPolicy
            $MainArray[$ArrayIndex].DialPlan = $Teams_DialPlan
            $MainArray[$ArrayIndex].TenantDialPlan = $Teams_TenantDialPlan
            $MainArray[$ArrayIndex].TeamsPrivateLine = $Teams_PrivateLine
            $MainArray[$ArrayIndex].VoiceType = $Teams_VoiceType
            $MainArray[$ArrayIndex].UserType = $Teams_UserType
            $MainArray[$ArrayIndex].UPN = $Teams_UPN
            
            # Part from tenant based phone number entry
            if (($MainArray[$ArrayIndex].City -like "NoneDefined") -and ($CurrentCivicAddressCity -notlike "")) {
                $MainArray[$ArrayIndex].City = $CurrentCivicAddressCity
            }
            if (($MainArray[$ArrayIndex].Country -like "NoneDefined") -and ($CurrentCivicAddressCountryOrRegion -notlike "")) {
                $MainArray[$ArrayIndex].Country = $CurrentCivicAddressCountryOrRegion
            }
            if (($MainArray[$ArrayIndex].Company -like "NoneDefined") -and ($CurrentCivicAddressCompanyName -notlike "")) {
                $MainArray[$ArrayIndex].Company = $CurrentCivicAddressCompanyName
            }
            
            # Part from tenant based phone number entry
            $MainArray[$ArrayIndex].NumberCapability = $CurrentCapability -replace $null, ""
            $MainArray[$ArrayIndex].CivicAddressMappingIndex = $CurrentCivicAddressMappingIndex -replace $null, ""
            $MainArray[$ArrayIndex].CivicAddressMappingName = $CurrentCivicAddressMappingName -replace $null, ""
            $MainArray[$ArrayIndex].EmergencyAddressName = $CurrentCivicAddressDescription -replace $null, ""            
            
            
        }
        elseif ($MainArray.MainLineUri -contains $Teams_MainLineUri) {
            #If not, check if Main LineUri - so without Teams Ext - is in Main Array included
            $ArrayIndex = [array]::indexof($MainArray.MainLineUri, $Teams_MainLineUri) | Select-Object -First 1
            
            $CurrentDID = $MainArray[$ArrayIndex].DID -replace $null, ""
            $CurrentNumberRangeName = $MainArray[$ArrayIndex].NumberRangeName -replace $null, ""
            $CurrentExtensionRangeName = $MainArray[$ArrayIndex].ExtensionRangeName -replace $null, ""
            $CurrentNumberRangeIndex = $MainArray[$ArrayIndex].NumberRangeIndex -replace $null, ""
            $CurrentExtensionRangeIndex = $MainArray[$ArrayIndex].ExtensionRangeIndex -replace $null, ""
            $CurrentCountry = $MainArray[$ArrayIndex].Country -replace $null, ""
            $CurrentCity = $MainArray[$ArrayIndex].City -replace $null, ""
            $CurrentCompany = $MainArray[$ArrayIndex].Company -replace $null, ""

            # Part from tenant based phone number entry
            # $CurrentCapability
            # $CurrentCivicAddressMappingIndex
            # $CurrentCivicAddressMappingName
            # $CurrentCivicAddressDescription    

            $NewRow += [pscustomobject]@{'FullLineUri' = $Teams_FullLineUri; 'MainLineUri' = $Teams_MainLineUri; 'DID' = $CurrentDID; 'TeamsEXT' = $Teams_LineUri_Extension; 'NumberRangeName' = $CurrentNumberRangeName; 'ExtensionRangeName' = $CurrentExtensionRangeName; 'CivicAddressMappingName' = $CurrentCivicAddressMappingName; 'UPN' = $Teams_UPN; 'Display_Name' = $Teams_DisplayName; 'OnlineVoiceRoutingPolicy' = $Teams_OnlineVoiceRoutingPolicy; 'TeamsCallingPolicy' = $Teams_TeamsCallingPolicy; 'DialPlan' = $Teams_DialPlan; 'TenantDialPlan' = $Teams_TenantDialPlan; 'TeamsPrivateLine' = $Teams_PrivateLine; 'VoiceType' = $Teams_VoiceType; 'UserType' = $Teams_UserType; 'NumberCapability' = $CurrentCapability; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = $CurrentExtensionRangeIndex; 'CivicAddressMappingIndex' = $CurrentCivicAddressMappingIndex; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = $CurrentCivicAddressDescription; 'Status' = '' }
            $MainArray += $NewRow
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentExtensionRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow")
            
        }
        elseif ($NumberRangeArray.LineUri -contains $Teams_MainLineUri) {
            #If not, check if LineUri is in NumberRangeArray included
            $ArrayIndex = [array]::indexof($NumberRangeArray.LineUri, $Teams_MainLineUri)
            
            $CurrentDID = $NumberRangeArray[$ArrayIndex].DID -replace $null, ""
            $CurrentNumberRangeName = $NumberRangeArray[$ArrayIndex].NumberRangeName -replace $null, ""
            $CurrentNumberRangeIndex = $NumberRangeArray[$ArrayIndex].NumberRangeIndex -replace $null, ""
            $CurrentCountry = $NumberRangeArray[$ArrayIndex].Country -replace $null, ""
            $CurrentCity = $NumberRangeArray[$ArrayIndex].City -replace $null, ""
            $CurrentCompany = $NumberRangeArray[$ArrayIndex].Company -replace $null, ""

            # Part from tenant based phone number entry
            if (($CurrentCity -like "NoneDefined") -and ($CurrentCivicAddressCity -notlike "")) {
                $CurrentCity = $CurrentCivicAddressCity
            }
            if (($CurrentCountry -like "NoneDefined") -and ($CurrentCivicAddressCountryOrRegion -notlike "")) {
                $CurrentCountry = $CurrentCivicAddressCountryOrRegion
            }
            if (($CurrentCompany -like "NoneDefined") -and ($CurrentCivicAddressCompanyName -notlike "")) {
                $CurrentCompany = $CurrentCivicAddressCompanyName
            }
            
            # $CurrentCapability
            # $CurrentCivicAddressMappingIndex
            # $CurrentCivicAddressMappingName
            # $CurrentCivicAddressDescription    

            $NewRow += [pscustomobject]@{'FullLineUri' = $Teams_FullLineUri; 'MainLineUri' = $Teams_MainLineUri; 'DID' = $CurrentDID; 'TeamsEXT' = $Teams_LineUri_Extension; 'NumberRangeName' = $CurrentNumberRangeName; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = $CurrentCivicAddressMappingName; 'UPN' = $Teams_UPN; 'Display_Name' = $Teams_DisplayName; 'OnlineVoiceRoutingPolicy' = $Teams_OnlineVoiceRoutingPolicy; 'TeamsCallingPolicy' = $Teams_TeamsCallingPolicy; 'DialPlan' = $Teams_DialPlan; 'TenantDialPlan' = $Teams_TenantDialPlan; 'TeamsPrivateLine' = $Teams_PrivateLine; 'VoiceType' = $Teams_VoiceType; 'UserType' = $Teams_UserType; 'NumberCapability' = $CurrentCapability; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = $CurrentCivicAddressMappingIndex; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = $CurrentCivicAddressDescription; 'Status' = '' }
            $MainArray += $NewRow
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow")
            
        }
        else {
            #If not add Entry as a new MainArray entry
            # Part from tenant based phone number entry
            if ($CurrentCivicAddressCity -notlike "") {
                $CurrentCity = $CurrentCivicAddressCity
            }
            else {
                $CurrentCity = "NoneDefined"
            }

            if ($CurrentCivicAddressCountryOrRegion -notlike "") {
                $CurrentCountry = $CurrentCivicAddressCountryOrRegion
            }
            else {
                $CurrentCountry = "NoneDefined"
            }

            if ($CurrentCivicAddressCompanyName -notlike "") {
                $CurrentCompany = $CurrentCivicAddressCompanyName
            }
            else {
                $CurrentCompany = "NoneDefined"
            }

            $NewRow += [pscustomobject]@{'FullLineUri' = $Teams_FullLineUri; 'MainLineUri' = $Teams_MainLineUri; 'DID' = 'NoneDefined'; 'TeamsEXT' = $Teams_LineUri_Extension; 'NumberRangeName' = 'NoneDefined'; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = $CurrentCivicAddressMappingName; 'UPN' = $Teams_UPN; 'Display_Name' = $Teams_DisplayName; 'OnlineVoiceRoutingPolicy' = $Teams_OnlineVoiceRoutingPolicy; 'TeamsCallingPolicy' = $Teams_TeamsCallingPolicy; 'DialPlan' = $Teams_DialPlan; 'TenantDialPlan' = $Teams_TenantDialPlan; 'TeamsPrivateLine' = $Teams_PrivateLine; 'VoiceType' = $Teams_VoiceType; 'UserType' = $Teams_UserType; 'NumberCapability' = $CurrentCapability; 'NumberRangeIndex' = 'NoneDefined'; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = $CurrentCivicAddressMappingIndex; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = $CurrentCivicAddressDescription; 'Status' = '' }
            $MainArray += $NewRow
            $NewRow = $null
        }
        Clear-Variable -Name ("Teams_UPN", "Teams_FullLineUri", "Teams_MainLineUri", "Teams_LineUri_Extension", "Teams_VoiceType", "Teams_UserType")
    }
    #endregion
}
else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Error "$TimeStamp - Error: No Teams user, which has a LineUri, was found. The script will be terminated now!"
    Start-Sleep -Seconds 5
    Exit
}

$AllTeamsUser = $null

#endregion
#endregion
#region Check whether there are phone numbers in the tenant that are not assigned
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Check whether there are phone numbers in the tenant that are not assigned"
$UnassignedOnlinePhoneNumbers = $OnlinePhoneNumbers | Where-Object PstnAssignmentStatus -NotLike "UserAssigned" |  Where-Object PstnAssignmentStatus -NotLike "VoiceApplicationAssigned"

if ($($UnassignedOnlinePhoneNumbers | Measure-Object).Count -eq 0) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 2 - No unassigned phone numbers exist in Teams respectively the tenant." 
}
else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 2 - Number of phone numbers in the tenant that are not assigned: $($($UnassignedOnlinePhoneNumbers | Measure-Object).Count)"
    Write-Output "$TimeStamp - Block 2 - Merging these numbers into the MainArray"

    foreach ($CurrentUnassignedOnlinePhoneNumber in $UnassignedOnlinePhoneNumbers) {
        if ($MainArray.MainLineUri -contains $CurrentUnassignedOnlinePhoneNumber.TelephoneNumber) {
            #Update existing entry
            $ArrayIndex = [array]::indexof($MainArray.FullLineUri, $CurrentUnassignedOnlinePhoneNumber.TelephoneNumber)
            $MainArray[$ArrayIndex].NumberCapability = $CurrentUnassignedOnlinePhoneNumber.Capability
            $MainArray[$ArrayIndex].CivicAddressMappingIndex = $CurrentUnassignedOnlinePhoneNumber.CivicAddressMappingIndex
            $MainArray[$ArrayIndex].CivicAddressMappingName = $CurrentUnassignedOnlinePhoneNumber.CivicAddressMappingName
            $MainArray[$ArrayIndex].EmergencyAddressName = $CurrentUnassignedOnlinePhoneNumber.CivicAddressDescription
            $MainArray[$ArrayIndex].VoiceType = $CurrentUnassignedOnlinePhoneNumber.NumberType

            if (($MainArray[$ArrayIndex].City -like "NoneDefined") -and ($CurrentUnassignedOnlinePhoneNumber.CivicAddressCity -notlike "")) {
                $MainArray[$ArrayIndex].City = $CurrentUnassignedOnlinePhoneNumber.CivicAddressCity
            }
            if (($MainArray[$ArrayIndex].Country -like "NoneDefined") -and ($CurrentUnassignedOnlinePhoneNumber.CivicAddressCountryOrRegion -notlike "")) {
                $MainArray[$ArrayIndex].Country = $CurrentUnassignedOnlinePhoneNumber.CivicAddressCountryOrRegion
            }
            if (($MainArray[$ArrayIndex].Company -like "NoneDefined") -and ($CurrentUnassignedOnlinePhoneNumber.CivicAddressCompanyName -notlike "")) {
                $MainArray[$ArrayIndex].Company = $CurrentUnassignedOnlinePhoneNumber.CivicAddressCompanyName
            }

        }
        else {
            # Add missing entry
            $NewRow += [pscustomobject]@{'FullLineUri' = $($CurrentUnassignedOnlinePhoneNumber.TelephoneNumber); 'MainLineUri' = $($CurrentUnassignedOnlinePhoneNumber.TelephoneNumber); 'DID' = 'NoneDefined'; 'TeamsEXT' = ''; 'NumberRangeName' = 'NoneDefined'; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressMappingName); 'UPN' = ''; 'Display_Name' = ''; 'OnlineVoiceRoutingPolicy' = ''; 'TeamsCallingPolicy' = ''; 'DialPlan' = ''; 'TenantDialPlan' = ''; 'TeamsPrivateLine' = ''; 'VoiceType' = $($CurrentUnassignedOnlinePhoneNumber.NumberType); 'UserType' = ''; 'NumberCapability' = $($CurrentUnassignedOnlinePhoneNumber.Capability); 'NumberRangeIndex' = 'NoneDefined'; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressMappingIndex); 'Country' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressCountryOrRegion); 'City' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressCity); 'Company' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressCompanyName); 'EmergencyAddressName' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressDescription); 'Status' = '' }
            $MainArray += $NewRow
            $NewRow = $null
        }
    }
    
}

#endregion
########################################################
#region Legacy and Duplicats
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
Write-Output "$TimeStamp - Block 3 - Get StatusQuo of Legacy SharePoint List - ListName: $($SharepointLegacyList)"
$LegacyPhoneNumbers = Get-TPIList -ListBaseURL $LegacyListURL -ListName $SharepointLegacyList -Properties $ListProperties_Legacy -TitelNameReplacement $TitelNameReplacement_Legacy -VerboseGraphAPILogging:$VerboseGraphAPI 

$CounterLegacyPhoneNumber = $($LegacyPhoneNumbers | Measure-Object).Count 

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 3 - Received legacy phone numbers: $CounterLegacyPhoneNumber"

if ($CounterLegacyPhoneNumber -gt 0) {
    $Counter = 0

    #Create array for duplicates
    [System.Collections.ArrayList]$Duplicate = @()

    foreach ($LegacyPhoneNumber in $LegacyPhoneNumbers) {
        $Legacy_LineUri = $LegacyPhoneNumber.LineUri.Trim()
        $Legacy_DisplayName = $LegacyPhoneNumber.LegacyName
        $Legacy_Type = "LegacyPhoneNumber"

        if ($MainArray.FullLineUri -contains $Legacy_LineUri) {
            $ArrayIndex = [array]::indexof($MainArray.FullLineUri, $Legacy_LineUri)
            
            # Add LineUri and UPN to duplicate error, if LineUri is already assigned to a Teams User
            if ($MainArray[$ArrayIndex].UPN -notlike "") {
                $DuplicateUPN = $MainArray[$ArrayIndex].UPN
                $NewRow += [pscustomobject]@{'LineUri' = $Legacy_LineUri; 'UPN' = $DuplicateUPN }
                $Duplicate += $NewRow
                $NewRow = $null
                $MainArray[$ArrayIndex].Status = 'DuplicateUPN_' + $DuplicateUPN + ';'
            }

            $MainArray[$ArrayIndex].Display_Name = $Legacy_DisplayName -replace $null, "" 
            $MainArray[$ArrayIndex].VoiceType = $Legacy_Type -replace $null, ""
            $MainArray[$ArrayIndex].UPN = ""
            $MainArray[$ArrayIndex].OnlineVoiceRoutingPolicy = ""
            $MainArray[$ArrayIndex].TeamsCallingPolicy = ""
            $MainArray[$ArrayIndex].DialPlan = ""
            $MainArray[$ArrayIndex].TenantDialPlan = ""
            
        }
        elseif ($NumberRangeArray.LineUri -contains $Legacy_LineUri) {
            $ArrayIndex = [array]::indexof($NumberRangeArray.LineUri, $Legacy_LineUri)
            
            $CurrentDID = $NumberRangeArray[$ArrayIndex].DID -replace $null, ""
            $CurrentNumberRangeName = $NumberRangeArray[$ArrayIndex].NumberRangeName -replace $null, ""
            $CurrentNumberRangeIndex = $NumberRangeArray[$ArrayIndex].NumberRangeIndex -replace $null, ""
            $CurrentCountry = $NumberRangeArray[$ArrayIndex].Country -replace $null, ""
            $CurrentCity = $NumberRangeArray[$ArrayIndex].City -replace $null, ""
            $CurrentCompany = $NumberRangeArray[$ArrayIndex].Company -replace $null, ""

            $NewRow += [pscustomobject]@{'FullLineUri' = $Legacy_LineUri; 'MainLineUri' = $Legacy_LineUri; 'DID' = $CurrentDID; 'TeamsEXT' = 'NoneDefined'; 'NumberRangeName' = $CurrentNumberRangeName; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = 'NoneDefined'; 'UPN' = 'NoneDefined'; 'Display_Name' = $Legacy_DisplayName; 'OnlineVoiceRoutingPolicy' = 'NoneDefined'; 'TeamsCallingPolicy' = 'NoneDefined'; 'DialPlan' = 'NoneDefined'; 'TenantDialPlan' = 'NoneDefined'; 'TeamsPrivateLine' = 'NoneDefined'; 'VoiceType' = $Legacy_Type; 'UserType' = 'NoneDefined'; 'NumberCapability' = 'NoneDefined'; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = 'NoneDefined'; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = 'NoneDefined'; 'Status' = '' }
            $MainArray += $NewRow
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow")
            
        }
        else {
            $NewRow += [pscustomobject]@{'FullLineUri' = $Legacy_LineUri; 'MainLineUri' = $Legacy_LineUri; 'DID' = ''; 'TeamsEXT' = ''; 'NumberRangeName' = 'NoneDefined'; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = 'NoneDefined'; 'UPN' = 'NoneDefined'; 'Display_Name' = $Legacy_DisplayName; 'OnlineVoiceRoutingPolicy' = 'NoneDefined'; 'TeamsCallingPolicy' = 'NoneDefined'; 'DialPlan' = 'NoneDefined'; 'TenantDialPlan' = 'NoneDefined'; 'TeamsPrivateLine' = 'NoneDefined'; 'VoiceType' = $Legacy_Type; 'UserType' = 'NoneDefined'; 'NumberCapability' = 'NoneDefined'; 'NumberRangeIndex' = 'NoneDefined'; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = 'NoneDefined'; 'Country' = 'NoneDefined'; 'City' = 'NoneDefined'; 'Company' = 'NoneDefined'; 'EmergencyAddressName' = 'NoneDefined'; 'Status' = '' }
            $MainArray += $NewRow
            $NewRow = $null
        }

        $Legacy_LineUri = $null
        $Legacy_DisplayName = $null

    }

}

$LegacyPhoneNumbers = $null

#endregion
########################################################
#region Check for outdated items BlockExtension
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
Write-Output "$TimeStamp - Block 4 - Get StatusQuo of BlockExtension List - ListName: $($SharepointBlockExtensionList)"
$BlockExtensionList = Get-TPIList -ListBaseURL $BlockExtensionListURL -ListName $SharepointBlockExtensionList -Properties $ListProperties_BlockExtension -TitelNameReplacement $TitelNameReplacement_BlockExtension -VerboseGraphAPILogging:$VerboseGraphAPI 

#Define Date String for today
$NowString = (Get-Date).ToString('dd.MM.yyyy')
$NowDate = [datetime]::ParseExact($NowString, 'dd.MM.yyyy', $null)

foreach ($BlockListItem in $BlockExtensionList) {
    if ($($BlockListItem.LineUri) -notlike "") {
        $BlockItemDate = $BlockListItem.BlockUntil
        $NeedBlockItemUpdate = 0
        $DateValdidationError = 0
        $BlockItemLineUri = $BlockListItem.LineUri.Trim()
        $BlockItemReason = $BlockListItem.BlockReason
        if ($BlockItemDate -match '^[0-3][0-9][/.][0-3][0-9][/.](?:[0-9][0-9])?[0-9][0-9]$') {
            # Check if Date is correct (with leading zero - 01.02.2022)
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
        }
        elseif ($BlockItemDate -match '^[0-3]?[0-9][/.][0-3]?[0-9][/.](?:[0-9]{2})?[0-9]{2}$') {
            # Check if Date is correct (without leading zero - 1.2.2022)
            $ConvertDate = $BlockItemDate.Split('.')
            $Day = $ConvertDate[0].PadLeft(2, '0')
            $Month = $ConvertDate[1].PadLeft(2, '0')
            $Year = $ConvertDate[2]
            if ($Year.Length -eq 2) {
                if ([int]$Year -gt 70) {
                    $Year = "19" + $Year
                }
                else {
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
            $GraphAPIUrl_DeleteElement = $BlockExtensionListURL + '/items/' + $BlockListItem.ID
            if ($EnableEnhancedLoggingOutput) {
                Write-Output "## EnhancedLog: Delete Block Item $BlockItemLineUri Date: $BlockItemDate Reason: $BlockItemReason"
            }
            $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_DeleteElement -Method Delete -ProcessPart "BlockExtension List: Delete item: $BlockItemLineUri"  -VerboseGraphAPILogging:$VerboseGraphAPI 
            $GraphAPIUrl_DeleteElement = $null

        }
    }
}

$BlockExtensionList = $null

#endregion


########################################################
#region BlockExtension
##          
########################################################

# # Block 5 BlockExtension
# - Read List BlockExtension
# - Merge in Main Array (Fill/Add Status)

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 5 - Blocked Extension Handling"

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 5 - Get fresh StatusQuo of BlockExtension List - ListName: $($SharepointBlockExtensionList)"
$BlockExtension = Get-TPIList -ListBaseURL $BlockExtensionListURL -ListName $SharepointBlockExtensionList -Properties $ListProperties_BlockExtension -TitelNameReplacement $TitelNameReplacement_BlockExtension -VerboseGraphAPILogging:$VerboseGraphAPI 

foreach ($BlockExtensionItem in $BlockExtension) {
    $BlockExtensionLineUri = $BlockExtensionItem.LineUri.Trim()
    $ArrayIndex = [array]::indexof($MainArray.FullLineUri, $BlockExtensionLineUri)
    $CurrentStatus = $MainArray[$ArrayIndex].Status
    $BlockStatus = 'BlockNumber_Until' + $($BlockExtensionItem.BlockUntil) + '_Reason' + $($BlockExtensionItem.BlockReason) + ';'
    $MainArray[$ArrayIndex].Status = $CurrentStatus + $BlockStatus
}

$BlockExtensionList = $null

#endregion
########################################################
#region Compare + Update TPI List
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
Start-Sleep -Seconds 5

#region Compare the MainArray with the SharePoint List to check if items in the list need to be updated
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 6 - Compare the MainArray with the SharePoint List"
Write-Output "$TimeStamp - Block 6 - Get StatusQuo of TPI SharePoint List - ListName: $SharepointTPIList"
$TPIList = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList -Properties $ListProperties_TeamsPhoneInventory -TitelNameReplacement $TitelNameReplacement_TeamsPhoneInventory -VerboseGraphAPILogging:$VerboseGraphAPI 

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Items in SharePoint List: $($($TPIList | Measure-Object).Count)"
Write-Output "$TimeStamp - Block 6 - Items in MainArray: $($($MainArray | Measure-Object).Count)"


$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Compare the MainArray with the SharePoint List to check if items in the list need to be updated"
$DifferentEntries = Compare-Object -ReferenceObject $MainArray -DifferenceObject $TPIList -Property FullLineUri, MainLineUri, DID, TeamsEXT, NumberRangeName, ExtensionRangeName, CivicAddressMappingName, UPN, Display_Name, OnlineVoiceRoutingPolicy, TeamsCallingPolicy, DialPlan, TenantDialPlan, TeamsPrivateLine, VoiceType, UserType, NumberCapability, NumberRangeIndex, ExtensionRangeIndex, CivicAddressMappingIndex, Country, City, Company, EmergencyAddressName, Status | Where-Object SideIndicator -Like "<="
$NoUpdate = 0
$Counter = 0

if ($($DifferentEntries | Measure-Object).Count -gt 0) {
    if ($EnableEnhancedLoggingOutput -and (($DifferentEntries | Measure-Object).Count -lt 100)) {
        Write-Output "## EnhancedLog: Detailed Information for different entries"
        foreach ($Entry in $DifferentEntries) {
            $ReferenceEntry = $MainArray | Where-Object FullLineUri -eq $Entry.FullLineUri
            $DifferenceEntry = $TPIList | Where-Object FullLineUri -eq $Entry.FullLineUri
            Write-Output "##"
            Write-Output "## EnhancedLog: Entry FullLineUri: $($Entry.FullLineUri)"
            $Table = @()
            if ($null -eq $DifferenceEntry) {
                Write-Output "## EnhancedLog:   - Entry $($Entry.FullLineUri) is missing in TPIList and needs to be added."
            }
            elseif ($MainArray.FullLineUri -notcontains $Entry.FullLineUri) {
                Write-Output "## EnhancedLog:   - Entry $($Entry.FullLineUri) is in TPIList but needs to be deleted."
            }
            else {
                Write-Output "## EnhancedLog:   - Entry $($Entry.FullLineUri) is in TPIList but needs to be updated."
                foreach ($Property in $Entry.PSObject.Properties.Name) {
                    $ReferenceValue = $ReferenceEntry.$Property
                    $DifferenceValue = $DifferenceEntry.$Property

                    if ($ReferenceValue -ne $DifferenceValue) {
                        $Table += [PSCustomObject]@{
                            Property       = $Property
                            # ReferenceValue = MainArray
                            MainArrayValue = if ($null -eq $ReferenceValue) { "is null" } elseif ($ReferenceValue -eq "") { "empty string" } else { "-$($ReferenceValue)-" }
                            # DifferenceValue = TPIList
                            TPIListValue   = if ($null -eq $DifferenceValue) { "is null" } elseif ($DifferenceValue -eq "") { "empty string" } else { "-$($DifferenceValue)-" }
                        }
                    }
                }
                if ($Table.Count -gt 0) {
                    $Table | Format-Table -AutoSize
                }
            }
            Write-Output "##"
        }
    }
    elseif (($EnableEnhancedLoggingOutput) -and (($DifferentEntries | Measure-Object).Count -ge 100)) {
        Write-Output "## EnhancedLog: Detailed Information for different entries"
        Write-Output "## EnhancedLog: Too many entries to display detailed information. (Amount of entries: $($($DifferentEntries | Measure-Object).Count))"
    }
}

if ($($DifferentEntries | Measure-Object).Count -gt 0) {
    $DifferentCounter = $($DifferentEntries | Measure-Object).Count 
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Items in SharePoint List which need an update: $DifferentCounter"
    Write-Output "$TimeStamp - Block 6 - Prepare for batched processing"
    $All_HTTPBody_NewElements = @()
    $All_HTTPBody_UpdateElements = @()
    foreach ($Entry in $DifferentEntries) {
        if ($TPIList.FullLineUri -notcontains $Entry.FullLineUri) {
            #Add new element to the list
            $CurrentLineUri = $Entry.FullLineUri
            $All_HTTPBody_NewElements += @{
                "fields" = @{
                    "Title"                    = $Entry.FullLineUri -replace $null, ""
                    "MainLineUri"              = $Entry.MainLineUri -replace $null, ""
                    "DID"                      = $Entry.DID.ToString() -replace $null, ""
                    "TeamsEXT"                 = $Entry.TeamsEXT -replace $null, ""
                    "NumberRangeName"          = $Entry.NumberRangeName -replace $null, ""
                    "ExtensionRangeName"       = $Entry.ExtensionRangeName -replace $null, ""
                    "CivicAddressMappingName"  = $Entry.CivicAddressMappingName -replace $null, ""
                    "UPN"                      = $Entry.UPN -replace $null, ""
                    "Display_Name"             = $Entry.Display_Name -replace $null, ""
                    "OnlineVoiceRoutingPolicy" = $Entry.OnlineVoiceRoutingPolicy -replace $null, ""
                    "TeamsCallingPolicy"       = $Entry.TeamsCallingPolicy -replace $null, ""
                    "DialPlan"                 = $Entry.DialPlan -replace $null, ""
                    "TenantDialPlan"           = $Entry.TenantDialPlan -replace $null, ""
                    "TeamsPrivateLine"         = $Entry.TeamsPrivateLine -replace $null, ""
                    "VoiceType"                = $Entry.VoiceType -replace $null, ""
                    "UserType"                 = $Entry.UserType -replace $null, ""
                    "NumberCapability"         = $Entry.NumberCapability -replace $null, ""
                    "NumberRangeIndex"         = $Entry.NumberRangeIndex -replace $null, ""
                    "ExtensionRangeIndex"      = $Entry.ExtensionRangeIndex -replace $null, ""
                    "CivicAddressMappingIndex" = $Entry.CivicAddressMappingIndex -replace $null, ""
                    "Country"                  = $Entry.Country -replace $null, ""
                    "City"                     = $Entry.City -replace $null, ""
                    "Company"                  = $Entry.Company -replace $null, ""
                    "EmergencyAddressName"     = $Entry.EmergencyAddressName -replace $null, ""
                    "Status"                   = $Entry.Status -replace $null, ""
                }
            }
            if ($EnableEnhancedLoggingOutput) {
                Write-Output "## EnhancedLog: Add $($Entry.FullLineUri) Name: $($Entry.Display_Name) Type: $($Entry.VoiceType)"
            }
            
        }
        else {
            # Update Element in the list (based on MainArray)
            
            $ID = ($TPIList | Where-Object FullLineUri -like $Entry.FullLineUri).ID
            $GraphAPIUrl_UpdateElement = $TPIListURL + '/items/' + $ID
            $All_HTTPBody_UpdateElements += @{
                "body" = @{
                    "fields" = @{
                        "Title"                    = $Entry.FullLineUri -replace $null, ""
                        "MainLineUri"              = $Entry.MainLineUri -replace $null, ""
                        "DID"                      = $Entry.DID.ToString() -replace $null, ""
                        "TeamsEXT"                 = $Entry.TeamsEXT -replace $null, ""
                        "NumberRangeName"          = $Entry.NumberRangeName -replace $null, ""
                        "ExtensionRangeName"       = $Entry.ExtensionRangeName -replace $null, ""
                        "CivicAddressMappingName"  = $Entry.CivicAddressMappingName -replace $null, ""
                        "UPN"                      = $Entry.UPN -replace $null, ""
                        "Display_Name"             = $Entry.Display_Name -replace $null, ""
                        "OnlineVoiceRoutingPolicy" = $Entry.OnlineVoiceRoutingPolicy -replace $null, ""
                        "TeamsCallingPolicy"       = $Entry.TeamsCallingPolicy -replace $null, ""
                        "DialPlan"                 = $Entry.DialPlan -replace $null, ""
                        "TenantDialPlan"           = $Entry.TenantDialPlan -replace $null, ""
                        "TeamsPrivateLine"         = $Entry.TeamsPrivateLine -replace $null, ""
                        "VoiceType"                = $Entry.VoiceType -replace $null, ""
                        "UserType"                 = $Entry.UserType -replace $null, ""
                        "NumberCapability"         = $Entry.NumberCapability -replace $null, ""
                        "NumberRangeIndex"         = $Entry.NumberRangeIndex -replace $null, ""
                        "ExtensionRangeIndex"      = $Entry.ExtensionRangeIndex -replace $null, ""
                        "CivicAddressMappingIndex" = $Entry.CivicAddressMappingIndex -replace $null, ""
                        "Country"                  = $Entry.Country -replace $null, ""
                        "City"                     = $Entry.City -replace $null, ""
                        "Company"                  = $Entry.Company -replace $null, ""
                        "EmergencyAddressName"     = $Entry.EmergencyAddressName -replace $null, ""
                        "Status"                   = $Entry.Status -replace $null, ""
                    }
                }
                "URL"  = $GraphAPIUrl_UpdateElement
            }
            if ($EnableEnhancedLoggingOutput) {
                Write-Output "## EnhancedLog: Update $($Entry.FullLineUri) Name: $($Entry.Display_Name) Type: $($Entry.VoiceType)"
            }
        }
        
    }
    $BatchHeader = @{
        "Content-Type" = "application/json"
    }
    # Add missing items
    if ($($All_HTTPBody_NewElements | Measure-Object).Count -ne 0) {
        $AllElementsCount = $($All_HTTPBody_NewElements | Measure-Object).Count
        
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output "$TimeStamp - Block 6 - Start adding entries to the list in batches - number of new entries: $AllElementsCount"
        
        $GraphAPIUrl = $($TPIListURL + '/items') -replace "https://graph.microsoft.com/v1.0", ""
        $TMP_Counter20 = 0 
        $TMP_Counter = 0
        $BatchCount = 0
        $BatchReady = $false
        $CurrentBatch = @()

        foreach ($NewElement in $All_HTTPBody_NewElements) {
            $TMP_Counter20 ++ # 20 cause, it´s max batch size (statusquo March 2024)
            $TMP_Counter ++
            if (($TMP_Counter20 -eq 20) -or ($AllElementsCount -eq $TMP_Counter)) {
                $BatchReady = $true
                $TMP_Counter20 = 0
            }
            $BatchPart = [PSCustomObject][ordered]@{
                id      = $TMP_Counter20
                method  = "POST"
                URL     = $GraphAPIUrl
                headers = $BatchHeader
                body    = $NewElement
            }
            $CurrentBatch += $BatchPart

            if ($BatchReady) {
                $BatchReady = $false
                $BatchCount++
                $BatchRequestBody = [PSCustomObject][ordered]@{requests = $CurrentBatch }
                $TMP = Invoke-TPIRestMethod -Uri 'https://graph.microsoft.com/v1.0/$batch' -Method Post -Body $BatchRequestBody -ProcessPart "TPI List - Add item - BatchCount: $BatchCount" -VerboseGraphAPILogging:$VerboseGraphAPI 
                foreach ($Response in $TMP.responses) {
                    if ($Response.body.error.message -notlike "") {
                        $ID = $response.id
                        $ResponseError = $Response.body.error.message 
                        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                        Write-Error "$TimeStamp - Block 6 - Error in ID $ID - Error: $ResponseError"
                        Exit
                    }
                }
                $BatchRequestBody = $null
                $CurrentBatch = @()
            }

        }

        $TMP_Counter20 = $null
        $TMP_Counter = $null
        $BatchCount = $null
        $AllElementsCount = $null
        $All_HTTPBody_NewElements = $null

    }

    # Update outdated items
    if ($($All_HTTPBody_UpdateElements | Measure-Object).Count -ne 0) {
        $AllElementsCount = $($All_HTTPBody_UpdateElements | Measure-Object).Count
        
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Output "$TimeStamp - Block 6 - Start updating entries in the list in batches - number of new entries: $AllElementsCount"

        $TMP_Counter20 = 0 
        $TMP_Counter = 0
        $BatchCount = 0
        $BatchReady = $false
        $CurrentBatch = @()
        $BatchRequestBody = @{}

        foreach ($NewElement in $All_HTTPBody_UpdateElements) {
            $TMP_Counter20 ++ # 20 cause, it´s max batch size (statusquo March 2024)
            $TMP_Counter ++
            if (($TMP_Counter20 -eq 20) -or ($AllElementsCount -eq $TMP_Counter)) {
                $BatchReady = $true
                $TMP_Counter20 = 0
            }
            
            $BatchPart = [PSCustomObject][ordered]@{
                id      = $TMP_Counter20
                method  = "PATCH"
                URL     = $($NewElement.URL -replace "https://graph.microsoft.com/v1.0", "" ) 
                headers = $BatchHeader
                body    = $NewElement.body
            }
            $CurrentBatch += $BatchPart

            if ($BatchReady) {
                $BatchReady = $false
                $BatchCount++
                $BatchRequestBody = [ordered]@{requests = $CurrentBatch } 
                $TMP = Invoke-TPIRestMethod -Uri 'https://graph.microsoft.com/v1.0/$batch' -Method Post -Body $BatchRequestBody -ProcessPart "TPI List - Update item - BatchCount: $BatchCount" -VerboseGraphAPILogging:$VerboseGraphAPI 
                foreach ($Response in $TMP.responses) {
                    if ($Response.body.error.message -notlike "") {
                        $ID = $response.id
                        $ResponseError = $Response.body.error.message 
                        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                        Write-Error "$TimeStamp - Block 6 - Error in ID $ID - Error: $ResponseError"
                        Exit
                    }
                }
                $BatchRequestBody = @{}
                $CurrentBatch = @()
            }

        }

        $TMP_Counter20 = $null
        $TMP_Counter = $null
        $BatchCount = $null
        $AllElementsCount = $null
        $All_HTTPBody_UpdateElements = $null

    }
    
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Update of the list completed"

    $NoUpdate = 0
}
else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - SharePoint List is up to date - no need for an update"
    $NoUpdate = 1
}
#endregion

#region Get Status Quo of the Sharepoint List if needed
if ($NoUpdate -ne 1) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Get fresh StatusQuo of TPI SharePoint List - ListName: $($SharepointTPIList)"
    $TPIList = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList -Properties $ListProperties_TeamsPhoneInventory -TitelNameReplacement $TitelNameReplacement_TeamsPhoneInventory -VerboseGraphAPILogging:$VerboseGraphAPI 

    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Items in SharePoint List: $($($TPIList | Measure-Object).Count)"
    Write-Output "$TimeStamp - Block 6 - Items in MainArray: $($($MainArray | Measure-Object).Count)"
}

#endregion

#region Compare the MainArray with the SharePoint List to check if items in the list need to be deleted
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Compare the MainArray with the SharePoint List to check if items in the list need to be deleted"
$EntrysToDelete = Compare-Object -ReferenceObject $MainArray -DifferenceObject $TPIList -Property FullLineUri, MainLineUri, DID, TeamsEXT, NumberRangeName, ExtensionRangeName, CivicAddressMappingName, UPN, Display_Name, OnlineVoiceRoutingPolicy, TeamsCallingPolicy, DialPlan, TenantDialPlan, TeamsPrivateLine, VoiceType, UserType, NumberCapability, NumberRangeIndex, ExtensionRangeIndex, CivicAddressMappingIndex, Country, City, Company, EmergencyAddressName, Status | Where-Object SideIndicator -Like "=>"

if ($($EntrysToDelete | Measure-Object).Count -gt 0) {
    if ($EnableEnhancedLoggingOutput -and (($EntrysToDelete | Measure-Object).Count -lt 100)) {
        Write-Output "## EnhancedLog: Detailed Information for different entries"
        foreach ($Entry in $EntrysToDelete) {
            $ReferenceEntry = $MainArray | Where-Object FullLineUri -eq $Entry.FullLineUri
            $DifferenceEntry = $TPIList | Where-Object FullLineUri -eq $Entry.FullLineUri
            Write-Output "##"
            Write-Output "## EnhancedLog: Entry FullLineUri: $($Entry.FullLineUri)"
            $Table = @()
            Write-Output "## EnhancedLog:   - Entry $($Entry.FullLineUri) is in TPIList but needs to be updated."
            foreach ($Property in $Entry.PSObject.Properties.Name) {
                $ReferenceValue = $ReferenceEntry.$Property
                $DifferenceValue = $DifferenceEntry.$Property

                if ($ReferenceValue -ne $DifferenceValue) {
                    $Table += [PSCustomObject]@{
                        Property       = $Property
                        # ReferenceValue = MainArray
                        MainArrayValue = if ($null -eq $ReferenceValue) { "is null" } elseif ($ReferenceValue -eq "") { "empty string" } else { "-$($ReferenceValue)-" }
                        # DifferenceValue = TPIList
                        TPIListValue   = if ($null -eq $DifferenceValue) { "is null" } elseif ($DifferenceValue -eq "") { "empty string" } else { "-$($DifferenceValue)-" }
                    }
                }
            }

            if ($Table.Count -gt 0) {
                $Table | Format-Table -AutoSize
            }
        }
        if ($Table.Count -gt 0) {
            $Table | Format-Table -AutoSize
        }
        Write-Output "##"
    }
    elseif (($EnableEnhancedLoggingOutput) -and (($EntrysToDelete | Measure-Object).Count -ge 100)) {
        Write-Output "## EnhancedLog: Detailed Information for different entries"
        Write-Output "## EnhancedLog: Too many entries to display detailed information. (Amount of entries: $($($EntrysToDelete | Measure-Object).Count))"
    }
}

$EntrysToDeleteCount = $($EntrysToDelete | Measure-Object).Count 
if ($EntrysToDeleteCount -gt 0) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - Start deleting entries in the list in batches - number of entries to be removed: $EntrysToDeleteCount"
    
    $TMP_Counter20 = 0 
    $TMP_Counter = 0
    $BatchCount = 0
    $BatchReady = $false
    $CurrentBatch = @()
    $BatchRequestBody = @{}
    
    foreach ($DeleteItem in $EntrysToDelete) {
        $TMP_Counter20 ++ # 20 cause, it´s max batch size (statusquo March 2024)
        $TMP_Counter ++
        if ($EnableEnhancedLoggingOutput) {
            Write-Output "## EnhancedLog: Delete $($DeleteItem.FullLineUri) Name: $($DeleteItem.Display_Name) Type: $($DeleteItem.VoiceType)"
        }
    
        if (($TMP_Counter20 -eq 20) -or ($EntrysToDeleteCount -eq $TMP_Counter)) {
            $BatchReady = $true
            $TMP_Counter20 = 0
        }
        $ID = ($TPIList | Where-Object FullLineUri -like $DeleteItem.FullLineUri).ID
        $GraphAPIUrl_DeleteElement = $($TPIListURL + '/items/' + $ID) -replace "https://graph.microsoft.com/v1.0", ""
        
        $BatchPart = [PSCustomObject][ordered]@{
            id     = $TMP_Counter20
            method = "DELETE"
            URL    = $GraphAPIUrl_DeleteElement
            header = $BatchHeader
        }
        $CurrentBatch += $BatchPart
    
        if ($BatchReady) {
            $BatchReady = $false
            $BatchCount++
            $BatchRequestBody = [ordered]@{requests = $CurrentBatch }
            $TMP = Invoke-TPIRestMethod -Uri 'https://graph.microsoft.com/v1.0/$batch' -Method Post -Body $BatchRequestBody -ProcessPart "TPI List - Delete item - BatchCount: $BatchCount" -VerboseGraphAPILogging:$VerboseGraphAPI 
            foreach ($Response in $TMP.responses) {
                if ($Response.body.error.message -notlike "") {
                    $ID = $response.id
                    $ResponseError = $Response.body.error.message 
                    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                    Write-Error "$TimeStamp - Block 6 - Error in ID $ID - Error: $ResponseError"
                    Exit
                }
            }
            $BatchRequestBody = @{}
            $CurrentBatch = @()
        }
    
    }
    
    $TMP_Counter20 = $null
    $TMP_Counter = $null
    $BatchCount = $null
    $EntrysToDeleteCount = $null
    $EntrysToDelete = $null
}
else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Output "$TimeStamp - Block 6 - There are no items that need to be removed from the SharePoint List."
}

#endregion
#endregion 

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - finished TPI run!"