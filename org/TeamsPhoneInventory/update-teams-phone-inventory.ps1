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
  1.2.2 - 2026-09-16 - Fix removal of expired BlockExtension entries (SharePoint item id was not read, delete call failed with 400)
                     - Unify BlockUntil date evaluation (dd.MM.yyyy, d.M.yy, "/" as separator) - entries are removed the day after BlockUntil
                     - Continue the run if a BlockExtension entry cannot be removed (warning instead of abort)
                     - Fix Get-TPIList for lists with zero or one item and for an empty result (an empty inventory list is filled on the first run)
                     - Fix extension ranges with leading zeros (e.g. 000-099 was expanded to 00-99)
                     - Abort the run if the phone number export fails (no download link within 120 s or download error) instead of rewriting the inventory without tenant data; warn if the export is empty
                     - Detect Common Area Phones by a directly or group assigned TeamsIPPhonePolicy again
                     - Apply BlockExtension, unassigned tenant numbers and legacy numbers only to the matching inventory entry (a missing match no longer writes to the last entry)
                     - Keep MainLineUri and Company of legacy numbers that are part of a number range
                     - Block 6: delete only orphaned and duplicate inventory rows, handle duplicate rows without abort, evaluate the status of batch responses
                     - Resolve nested groups with zero or one member, skip circular group nesting, mark nested members correctly
                     - Validate number and extension ranges (swapped or empty ranges are reported and stop the run)
                     - Warn on duplicate CivicAddressMapping entries, duplicate LineUris of Teams users and unknown columns in a SharePoint list
  1.2.1 - 2025-11-13 - Update Module Versions
                     - Update Array handling
                     - Fix LineUri handling regarding Legacy numbers
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "MicrosoftTeams"; ModuleVersion = "7.5.0" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.32.0" }

########################################################
#region Parameter declaration
##
########################################################

param(
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
    $AllItems = [System.Collections.ArrayList]::new()

    try {
        do {
            $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8' -Verbose:$VerboseGraphAPILogging
            # @() keeps a page with exactly one item (member enumeration unwraps it to a single hashtable) and an empty page ($null) from breaking the list
            foreach ($ItemFields in @($AllItemsResponse.value.fields)) {
                if ($null -ne $ItemFields) { [void]$AllItems.Add($ItemFields) }
            }
            $GraphAPIUrl_StatusQuoSharepointList = $AllItemsResponse."@odata.nextLink"
        } while ($null -ne $GraphAPIUrl_StatusQuoSharepointList)
    }
    catch {
        Write-Warning "First try to get TPI list failed - reconnect MgGraph and test again"

        try {
            Connect-MgGraph -Identity
            do {
                $AllItemsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_StatusQuoSharepointList -Method Get -ContentType 'application/json; charset=utf-8' -Verbose:$VerboseGraphAPILogging
                foreach ($ItemFields in @($AllItemsResponse.value.fields)) {
                    if ($null -ne $ItemFields) { [void]$AllItems.Add($ItemFields) }
                }
                $GraphAPIUrl_StatusQuoSharepointList = $AllItemsResponse."@odata.nextLink"
            } while ($null -ne $GraphAPIUrl_StatusQuoSharepointList)
        }
        catch {
            Write-Error "Getting TPI list failed - stopping script" -ErrorAction Continue
            throw "Get-TPIList - Getting the SharePoint list $ListName failed twice - $($_.Exception.Message)"
        }
    }

    # Warn on requested properties that are no column of the list (typo in the property definition or in the list) - "id" is an item property, not a column
    if ($Properties) {
        try {
            $ListColumnNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $GraphAPIUrl_ListColumns = $ListBaseURL + '/columns?$select=name,displayName'
            do {
                $ListColumnsResponse = Invoke-MgGraphRequest -Uri $GraphAPIUrl_ListColumns -Method Get -ContentType 'application/json; charset=utf-8' -Verbose:$VerboseGraphAPILogging
                foreach ($ListColumn in @($ListColumnsResponse.value)) {
                    if ($null -ne $ListColumn) {
                        [void]$ListColumnNames.Add("$($ListColumn.name)")
                        [void]$ListColumnNames.Add("$($ListColumn.displayName)")
                    }
                }
                $GraphAPIUrl_ListColumns = $ListColumnsResponse."@odata.nextLink"
            } while ($null -ne $GraphAPIUrl_ListColumns)
            foreach ($property in $Properties) {
                if (($property -ne "id") -and (-not $ListColumnNames.Contains($property))) {
                    Write-Warning "Get-TPIList - List $ListName - the requested column '$property' does not exist in the list - check the column name in the list and in the property definition"
                }
            }
        }
        catch {
            Write-Verbose "Get-TPIList - List $ListName - column check skipped: $($_.Exception.Message)"
        }
    }

    if (($AllItems | Measure-Object).Count -gt 0) {
        $CustomObjects = [System.Collections.ArrayList]::new()
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
            [void]$CustomObjects.Add([PSCustomObject]$objProps)
        }
        return $CustomObjects
    }
    else {
        # Return an empty array (not $null) - the caller can use it in foreach, Measure-Object and Compare-Object
        return , @()
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
        A hashtable containing the mapping of Teams user identities to UserPrincipalNames. If this parameter is not provided and the MapUserPrincipalNames switch is set, the function will generate the hashtable automatically.

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
        $status = Get-CsExportAcquiredPhoneNumberStatus -OrderId $orderID
        $link = $status.DownloadLink
        $tries++
        Write-Verbose "Attempt $($tries)/$($MaxTries): Status = $($status.Status)"
    }

    if ([string]::IsNullOrEmpty($link)) {
        # A failed export must stop the run - without the tenant phone numbers the inventory would be rewritten without capabilities, emergency addresses and unassigned numbers
        Write-Error "No download link received after $MaxTries attempts ($($MaxTries * $WaitTime) seconds). Aborting."
        throw "Export-TeamsPhoneNumbers - No download link received after $MaxTries attempts ($($MaxTries * $WaitTime) seconds) - the phone number export failed or timed out"
    }

    Write-Verbose ""
    Write-Verbose "Download link received"#: $link"
    Write-Verbose ""

    # Download the file content directly into memory - a failed download must stop the run as well
    $content = Invoke-RestMethod -Uri $link -ErrorAction Stop

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
            # AssignedPstnTargetId is the column name of the export (see the Block 2 usage of the returned objects)
            if (!([string]::IsNullOrEmpty($obj.AssignedPstnTargetId))) {
                try {
                    if ($TeamsUsers[$obj.AssignedPstnTargetId] -notlike "") {
                        $obj | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $TeamsUsers[$obj.AssignedPstnTargetId] -Force -ErrorAction Stop
                    }
                    else {
                        Write-Verbose "AssignedPstnTargetId $($obj.AssignedPstnTargetId) not found in TeamsUsers hashtable. Adding UserPrincipalName as null."
                        $obj | Add-Member -MemberType NoteProperty -Name "UserPrincipalName" -Value $null -Force
                    }
                }
                catch {
                    Write-Verbose "An error occurred while adding UserPrincipalName. Stopping script. Current User Identity: $($obj.AssignedPstnTargetId)"
                    throw "Export-TeamsPhoneNumbers - Mapping the UserPrincipalName failed for AssignedPstnTargetId $($obj.AssignedPstnTargetId) - $($_.Exception.Message)"
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
        [string]$GroupObjectId,
        [Parameter(Mandatory = $false)]
        [switch]$Nested,
        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.HashSet[string]]$VisitedGroups
    )

    <#
        .SYNOPSIS
        Retrieves the members of a group, even if the groups are nested.

        .DESCRIPTION
        This function retrieves the members of a group, even if the groups are nested. It uses the Microsoft Graph API to retrieve the members of the group and processes them recursively. If a member is a user, it adds it to the report. If a member is a group, it calls the function recursively to retrieve the members of that group.
        Every group is resolved only once per top-level call, so circular nesting (group A contains group B contains group A) terminates.

        .PARAMETER GroupObjectId
        The object ID of the group to retrieve the members for. This parameter is mandatory.

        .PARAMETER Nested
        Set by the recursive call - members found in this call are nested members of the top-level group.

        .PARAMETER VisitedGroups
        Set by the recursive call - the groups already resolved in this top-level call.

        .EXAMPLE
        Get-GroupMembership -GroupObjectId "00000000-0000-0000-0000-000000000000"
        Retrieves the members of the group with the object ID "00000000-0000-0000-0000-000000000000".

        .OUTPUTS
        The function returns an ArrayList of objects with the following properties:
        - UserPrincipalName: The user principal name of the member.
        - Id: The ID of the member.
        - DirectMember: Indicates whether the member is a direct member of the group or a nested member.

        .NOTES
        Required Graph API permissions:
        - Group.Read.All
        - User.Read.All
    #>

    $report = [System.Collections.ArrayList]::new()

    # Guard against circular or repeated group nesting - every group is resolved only once per top-level call
    if ($null -eq $VisitedGroups) {
        $VisitedGroups = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }
    if (-not $VisitedGroups.Add($GroupObjectId)) {
        Write-Verbose "Get-GroupMembership - Group $GroupObjectId was already resolved in this call (circular or repeated nesting) - skipped"
        return , $report
    }

    # Get the members of the group
    $members = [System.Collections.ArrayList]::new()
    $uri = "https://graph.microsoft.com/v1.0/groups/$($GroupObjectId)/members"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        foreach ($member in @($response.value)) {
            if ($null -ne $member) { [void]$members.Add($member) }
        }
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    # Process the members - if a member is a user, add it to the report, if it's a group, call the function recursively
    $DirectMemberStatus = if ($Nested) { "No" } else { "Yes" }
    foreach ($member in $members) {
        if ($member."@odata.type" -eq "#microsoft.graph.user") {
            [void]$report.Add([PSCustomObject]@{
                UserPrincipalName = $member.UserPrincipalName
                Id                = $member.id
                DirectMember      = $DirectMemberStatus
            })
        }
        elseif ($member."@odata.type" -eq "#microsoft.graph.group") {
            $nestedMembers = Get-GroupMembership -GroupObjectId $($member.id) -Nested -VisitedGroups $VisitedGroups
            # @() and the null check keep a nested group with zero or one member from breaking the report (AddRange needs a collection)
            foreach ($nestedMember in @($nestedMembers)) {
                if ($null -ne $nestedMember) { [void]$report.Add($nestedMember) }
            }
        }
    }

    # Return the ArrayList as one object (not unrolled), so an empty or single-member result stays a collection
    return , $report
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
    "BlockReason",
    "id"
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
$Version = "1.2.2"
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
        exit
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
    exit
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
        exit
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
#  - Build arrays
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
    $BeginNumberRange = "$($NumberRange.BeginNumberRange)".Trim()
    $EndNumberRange = "$($NumberRange.EndNumberRange)".Trim()
    $Name = $NumberRange.NumberRangeName
    if (($BeginNumberRange -notmatch '^[0-9]+$') -or ($EndNumberRange -notmatch '^[0-9]+$')) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the NumberRange: $Name"
        Write-Error "$TimeStamp - Block 1 - BeginNumberRange '$BeginNumberRange' or EndNumberRange '$EndNumberRange' is empty or not numeric. This will terminate the script."
        Start-Sleep -Seconds 5
        exit
    }
    if ([int]$BeginNumberRange -gt [int]$EndNumberRange) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the NumberRange: $Name"
        Write-Error "$TimeStamp - Block 1 - The start number is greater than the end number. This will terminate the script."
        Start-Sleep -Seconds 5
        exit
    }
    if ($EndNumberRange.Length -lt $BeginNumberRange.Length) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the NumberRange: $Name"
        Write-Error "$TimeStamp - Block 1 - The Start NumberRange is longer than the End NumberRange! This will terminate the script."
        Start-Sleep -Seconds 5
        exit
    }
}

foreach ($ExtensionRange in $ExtensionRanges) {
    # No typed ([int]) variables here: a type constraint sticks to the variable and would convert the strings in the fill loop below (leading zeros would be lost)
    $BeginExtensionRange = "$($ExtensionRange.BeginExtensionRange)".Trim()
    $EndExtensionRange = "$($ExtensionRange.EndExtensionRange)".Trim()
    $Name = $ExtensionRange.ExtensionRangeName
    if (($BeginExtensionRange -notmatch '^[0-9]+$') -or ($EndExtensionRange -notmatch '^[0-9]+$')) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the ExtensionRange: $Name"
        Write-Error "$TimeStamp - Block 1 - BeginExtensionRange '$BeginExtensionRange' or EndExtensionRange '$EndExtensionRange' is empty or not numeric. This will terminate the script."
        Start-Sleep -Seconds 5
        exit
    }
    if ([int]$BeginExtensionRange -gt [int]$EndExtensionRange) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the ExtensionRange: $Name"
        Write-Error "$TimeStamp - Block 1 - The start extension is greater than the end extension! This will terminate the script."
        Start-Sleep -Seconds 5
        exit
    }
    if ($EndExtensionRange.Length -lt $BeginExtensionRange.Length) {
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Error "$TimeStamp - Block 1 - Error in the ExtensionRange: $Name"
        Write-Error "$TimeStamp - Block 1 - The Start ExtensionRange is longer than the End ExtensionRange! This will terminate the script."
        Start-Sleep -Seconds 5
        exit
    }

}
#endregion


#region Fill Up MainArray (ExtensionRange)
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 1 - List all numbers in defined extension ranges and fill MainArray"
$ExtensionRangeCounter = 0
$ExtensionRangeAmount = ($ExtensionRanges | Measure-Object).Count

[System.Collections.ArrayList]$MainArray = [System.Collections.ArrayList]::new()
$Counter = 0

foreach ($ExtensionRange in $ExtensionRanges) {
    # Keep the values as strings - the length of EndExtensionRange defines the padding of the extension (e.g. 000-099 -> 000, 001, ... 099)
    [string]$StartNumber = "$($ExtensionRange.BeginExtensionRange)".Trim()
    [string]$EndNumber = "$($ExtensionRange.EndExtensionRange)".Trim()
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
                $CurrentExtension = $_.ToString().PadLeft($EndNumber.Length, '0')
                $CurrentLineUri = $CurrentMainNumber + $CurrentExtension
                if ($MainArray.FullLineUri -notcontains $CurrentLineUri) {
                    $NewRow = [pscustomobject]@{'FullLineUri' = $CurrentLineUri; 'MainLineUri' = $CurrentLineUri; 'DID' = $CurrentExtension; 'TeamsEXT' = ''; 'NumberRangeName' = $NumberRangeName; 'ExtensionRangeName' = $ExtensionRangeName; 'CivicAddressMappingName' = 'NoneDefined'; 'UPN' = ''; 'Display_Name' = ''; 'OnlineVoiceRoutingPolicy' = ''; 'TeamsCallingPolicy' = ''; 'DialPlan' = ''; 'TenantDialPlan' = ''; 'TeamsPrivateLine' = ''; 'VoiceType' = ''; 'UserType' = ''; 'NumberCapability' = 'User and Service'; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = $CurrentExtensionRangeIndex; 'CivicAddressMappingIndex' = 'NoneDefined'; 'Country' = $Country; 'City' = $City; 'Company' = $Company; 'EmergencyAddressName' = ''; 'Status' = '' }
                    [void]$MainArray.Add($NewRow)
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

[System.Collections.ArrayList]$NumberRangeArray = [System.Collections.ArrayList]::new()
# Create a hashtable for fast lookup by LineUri
$NumberRangeHashTable = @{}

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

    # Determine minimum digits based on BeginNumberRange, and maximum digits based on EndNumberRange
    $MinNumberDigits = $NumberRange.BeginNumberRange.Length
    $MaxNumberDigits = $NumberRange.EndNumberRange.Length
    $DIDSet = [System.Collections.Generic.HashSet[string]]::new()

    if ($CurrentStartNumber -le $CurrentEndNumber) {
        for ($i = $CurrentStartNumber; $i -le $CurrentEndNumber; $i++) {
            # Determine the number of digits for current number
            $CurrentNumberLength = $i.ToString().Length

            # Use the length based on the current number, but at least MinNumberDigits
            if ($CurrentNumberLength -lt $MinNumberDigits) {
                $CurrentExtension = $i.ToString().PadLeft($MinNumberDigits, '0')
            }
            else {
                $CurrentExtension = $i.ToString()
            }

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
                # Add to hashtable for fast lookup
                $NumberRangeHashTable[$CurrentLineUri] = $NewRow
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
Write-Output "$TimeStamp - Block 1 - Finished Helper Array (Whole Number Range) with $($NumberRangeHashTable.Count) entries"

#endregion

#endregion

########################################################
#region Teams
##
########################################################

# # Block 2 Teams
# - Retrieve users
# - Foreach -> Merge into Main Array
#     - not in Main Array -> Add Entry

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "--------------------"
Write-Output "$TimeStamp - Block 2 - Retrieve all Microsoft Teams Users, which have an LineUri"
$AllTeamsUser = Get-CsOnlineUser -Filter { LineUri -like "tel:*" } | Select-Object Identity, DisplayName, UserPrincipalName, LineUri, TeamsCallingPolicy, OnlineVoiceRoutingPolicy, TeamsIPPhonePolicy, InterpretedUserType, EnterpriseVoiceEnabled, HostingProvider, DialPlan, TenantDialPlan, AssignedPlan
$CounterAllTeamsUser = ($AllTeamsUser | Measure-Object).Count

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Received Microsoft Teams users, which have an LineUri: $CounterAllTeamsUser"

#region Retrieve all phone numbers and LIS addresses from the tenant
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Retrieve all phone numbers and LIS addresses from the tenant"
# NumberType - Supported values are DirectRouting, CallingPlan, and OperatorConnect. "-Top" thing is required to get all entries.
# Wait up to 120 s for the export (default 60 s) - large tenants need more time. A failed export throws and stops the run (see Export-TeamsPhoneNumbers).
$PhoneNumberAssignment = Export-TeamsPhoneNumbers -MaxTries 120 -Verbose:$VerboseGraphAPI
$OnlineLisCivicAddress = Get-CsOnlineLisCivicAddress

$CounterPhoneNumber = ($PhoneNumberAssignment | Measure-Object).Count
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Received phone numbers from tenant: $CounterPhoneNumber"

if ($CounterPhoneNumber -eq 0) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Warning "$TimeStamp - Block 2 - The phone number export of the tenant returned no phone numbers - capabilities, emergency addresses and unassigned numbers cannot be determined in this run"
}

# Warn once on duplicate CivicAddressIDs in the CivicAddressMapping list - only the first entry is used, otherwise the mapping values would become arrays
$DuplicateCivicAddressMappings = $CivicAddressMappings | Where-Object { "$($_.CivicAddressID)" -notlike "" } | Group-Object -Property CivicAddressID | Where-Object Count -gt 1
foreach ($DuplicateCivicAddressMapping in $DuplicateCivicAddressMappings) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Warning "$TimeStamp - Block 2 - CivicAddressID $($DuplicateCivicAddressMapping.Name) is defined $($DuplicateCivicAddressMapping.Count) times in the CivicAddressMapping list (CivicAddressMappingIndex: $(($DuplicateCivicAddressMapping.Group.CivicAddressMappingIndex) -join ', ')) - only the first entry is used"
}

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 2 - Rearrange phone number array"

[System.Collections.ArrayList]$OnlinePhoneNumbers = [System.Collections.ArrayList]::new()
foreach ($PhoneNumber in $PhoneNumberAssignment ) {
    $CurrentLISCivicAddress = $OnlineLisCivicAddress | Where-Object CivicAddressId -Like $($PhoneNumber.CivicAddressId) | Select-Object -First 1
    $CurrentCivicAddressMapping = $CivicAddressMappings | Where-Object CivicAddressID -Like $($CurrentLISCivicAddress.CivicAddressId) | Select-Object -First 1
    $CurrentUser = $AllTeamsUser | Where-Object Identity -Like $($PhoneNumber.AssignedPstnTargetId) | Select-Object -First 1

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

    if ("$($PhoneNumber.CivicAddressId)" -notlike "") {
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
    [void]$OnlinePhoneNumbers.Add($NewRow)
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
$teamsGroupPolicyAssignments = [System.Collections.ArrayList]::new()

foreach ($user in $userPolicies.Keys) {
    foreach ($policyType in $userPolicies[$user].Keys) {
        [void]$teamsGroupPolicyAssignments.Add([PSCustomObject]@{
            UserPrincipalName = $user
            UserID            = $userPolicies[$user][$policyType].UserID
            PolicyType        = $policyType
            PolicyName        = $userPolicies[$user][$policyType].PolicyName
        })
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
            else {
                $Teams_LineUri = $TeamsUser.LineUri
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
        $CurrentPhoneNumberAssignment = $OnlinePhoneNumbers | Where-Object AssignedPstnTargetId -Like $TeamsUser.Identity

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

        # TeamsIPPhonePolicy - same object/string handling as the policies above. Get-CsTeamsIPPhonePolicy returns the identity as "Tag:<Name>",
        # the user object and the group policy assignment return the bare name, so the prefix is added for the lookup below.
        if ($TeamsUser.TeamsIPPhonePolicy.PSObject.Properties.Name -contains "Authority") {
            $Teams_TeamsIPPhonePolicy = $TeamsUser.TeamsIPPhonePolicy.Name -replace $null, ""
        }
        else {
            $Teams_TeamsIPPhonePolicy = $TeamsUser.TeamsIPPhonePolicy -replace $null, ""
        }
        $Teams_TeamsIPPhonePolicy = $Teams_TeamsIPPhonePolicy -replace '^Tag:', ''

        if ($Teams_TeamsIPPhonePolicy -like "") {
            $TMPUserTeamsIPPhonePolicy = ($teamsGroupPolicyAssignments | Where-Object { $_.UserID -eq $TeamsUser.Identity -and $_.PolicyType -eq "TeamsIPPhonePolicy" }).PolicyName
            if ($TMPUserTeamsIPPhonePolicy -like "") {
                $TMPUserTeamsIPPhonePolicy = "Global"
            }
            else {
                $TMPUserTeamsIPPhonePolicy = "Tag:" + ($TMPUserTeamsIPPhonePolicy -replace '^Tag:', '')
            }
        }
        else {
            $TMPUserTeamsIPPhonePolicy = "Tag:" + $Teams_TeamsIPPhonePolicy
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
        #Check if FullLineUri Already in MainArray - the check uses IndexOf itself, so a result of -1 (not found) can never address the last entry of the array
        $ArrayIndex = [array]::IndexOf($MainArray.FullLineUri, $Teams_FullLineUri)
        $MainLineUriArrayIndex = [array]::IndexOf($MainArray.MainLineUri, $Teams_MainLineUri)
        if ($ArrayIndex -ge 0) {
            # Two Teams users with the same LineUri (e.g. hybrid setups) - keep this visible in the status instead of silently overwriting the entry
            if (($MainArray[$ArrayIndex].UPN -notlike "") -and ($MainArray[$ArrayIndex].UPN -ne $Teams_UPN)) {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                Write-Warning "$TimeStamp - Block 2 - LineUri $Teams_FullLineUri is assigned to $($MainArray[$ArrayIndex].UPN) and to $Teams_UPN - the entry is overwritten with $Teams_UPN and marked with DuplicateUPN in the status"
                $MainArray[$ArrayIndex].Status = $MainArray[$ArrayIndex].Status + 'DuplicateUPN_' + $MainArray[$ArrayIndex].UPN + ';'
            }
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
        elseif ($MainLineUriArrayIndex -ge 0) {
            #If not, check if Main LineUri - so without Teams Ext - is in Main Array included
            $ArrayIndex = $MainLineUriArrayIndex

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

            $NewRow = [pscustomobject]@{'FullLineUri' = $Teams_FullLineUri; 'MainLineUri' = $Teams_MainLineUri; 'DID' = $CurrentDID; 'TeamsEXT' = $Teams_LineUri_Extension; 'NumberRangeName' = $CurrentNumberRangeName; 'ExtensionRangeName' = $CurrentExtensionRangeName; 'CivicAddressMappingName' = $CurrentCivicAddressMappingName; 'UPN' = $Teams_UPN; 'Display_Name' = $Teams_DisplayName; 'OnlineVoiceRoutingPolicy' = $Teams_OnlineVoiceRoutingPolicy; 'TeamsCallingPolicy' = $Teams_TeamsCallingPolicy; 'DialPlan' = $Teams_DialPlan; 'TenantDialPlan' = $Teams_TenantDialPlan; 'TeamsPrivateLine' = $Teams_PrivateLine; 'VoiceType' = $Teams_VoiceType; 'UserType' = $Teams_UserType; 'NumberCapability' = $CurrentCapability; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = $CurrentExtensionRangeIndex; 'CivicAddressMappingIndex' = $CurrentCivicAddressMappingIndex; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = $CurrentCivicAddressDescription; 'Status' = '' }
            [void]$MainArray.Add($NewRow)
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentExtensionRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow")

        }
        elseif ($NumberRangeHashTable.ContainsKey($Teams_MainLineUri)) {
            #If not, check if LineUri is in NumberRangeArray included
            $CurrentNumberRangeEntry = $NumberRangeHashTable[$Teams_MainLineUri]

            $CurrentDID = $CurrentNumberRangeEntry.DID -replace $null, ""
            $CurrentNumberRangeName = $CurrentNumberRangeEntry.NumberRangeName -replace $null, ""
            $CurrentNumberRangeIndex = $CurrentNumberRangeEntry.NumberRangeIndex -replace $null, ""
            $CurrentCountry = $CurrentNumberRangeEntry.Country -replace $null, ""
            $CurrentCity = $CurrentNumberRangeEntry.City -replace $null, ""
            $CurrentCompany = $CurrentNumberRangeEntry.Company -replace $null, ""

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

            $NewRow = [pscustomobject]@{'FullLineUri' = $Teams_FullLineUri; 'MainLineUri' = $Teams_MainLineUri; 'DID' = $CurrentDID; 'TeamsEXT' = $Teams_LineUri_Extension; 'NumberRangeName' = $CurrentNumberRangeName; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = $CurrentCivicAddressMappingName; 'UPN' = $Teams_UPN; 'Display_Name' = $Teams_DisplayName; 'OnlineVoiceRoutingPolicy' = $Teams_OnlineVoiceRoutingPolicy; 'TeamsCallingPolicy' = $Teams_TeamsCallingPolicy; 'DialPlan' = $Teams_DialPlan; 'TenantDialPlan' = $Teams_TenantDialPlan; 'TeamsPrivateLine' = $Teams_PrivateLine; 'VoiceType' = $Teams_VoiceType; 'UserType' = $Teams_UserType; 'NumberCapability' = $CurrentCapability; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = $CurrentCivicAddressMappingIndex; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = $CurrentCivicAddressDescription; 'Status' = '' }
            [void]$MainArray.Add($NewRow)
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

            $NewRow = [pscustomobject]@{'FullLineUri' = $Teams_FullLineUri; 'MainLineUri' = $Teams_MainLineUri; 'DID' = 'NoneDefined'; 'TeamsEXT' = $Teams_LineUri_Extension; 'NumberRangeName' = 'NoneDefined'; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = $CurrentCivicAddressMappingName; 'UPN' = $Teams_UPN; 'Display_Name' = $Teams_DisplayName; 'OnlineVoiceRoutingPolicy' = $Teams_OnlineVoiceRoutingPolicy; 'TeamsCallingPolicy' = $Teams_TeamsCallingPolicy; 'DialPlan' = $Teams_DialPlan; 'TenantDialPlan' = $Teams_TenantDialPlan; 'TeamsPrivateLine' = $Teams_PrivateLine; 'VoiceType' = $Teams_VoiceType; 'UserType' = $Teams_UserType; 'NumberCapability' = $CurrentCapability; 'NumberRangeIndex' = 'NoneDefined'; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = $CurrentCivicAddressMappingIndex; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = $CurrentCivicAddressDescription; 'Status' = '' }
            [void]$MainArray.Add($NewRow)
            $NewRow = $null
        }
        Clear-Variable -Name ("Teams_UPN", "Teams_LineUri", "Teams_FullLineUri", "Teams_MainLineUri", "Teams_LineUri_Extension", "Teams_VoiceType", "Teams_UserType")
    }
    #endregion
}
else {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Error "$TimeStamp - Error: No Teams user, which has a LineUri, was found. The script will be terminated now!"
    Start-Sleep -Seconds 5
    exit
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
        # Check and index the same column (FullLineUri) - a number that exists only as MainLineUri of an entry with extension gets its own entry below
        $ArrayIndex = [array]::IndexOf($MainArray.FullLineUri, "$($CurrentUnassignedOnlinePhoneNumber.TelephoneNumber)")
        if ($ArrayIndex -ge 0) {
            #Update existing entry
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
            $NewRow = [pscustomobject]@{'FullLineUri' = $($CurrentUnassignedOnlinePhoneNumber.TelephoneNumber); 'MainLineUri' = $($CurrentUnassignedOnlinePhoneNumber.TelephoneNumber); 'DID' = 'NoneDefined'; 'TeamsEXT' = ''; 'NumberRangeName' = 'NoneDefined'; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressMappingName); 'UPN' = ''; 'Display_Name' = ''; 'OnlineVoiceRoutingPolicy' = ''; 'TeamsCallingPolicy' = ''; 'DialPlan' = ''; 'TenantDialPlan' = ''; 'TeamsPrivateLine' = ''; 'VoiceType' = $($CurrentUnassignedOnlinePhoneNumber.NumberType); 'UserType' = ''; 'NumberCapability' = $($CurrentUnassignedOnlinePhoneNumber.Capability); 'NumberRangeIndex' = 'NoneDefined'; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressMappingIndex); 'Country' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressCountryOrRegion); 'City' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressCity); 'Company' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressCompanyName); 'EmergencyAddressName' = $($CurrentUnassignedOnlinePhoneNumber.CivicAddressDescription); 'Status' = '' }
            [void]$MainArray.Add($NewRow)
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
    [System.Collections.ArrayList]$Duplicate = [System.Collections.ArrayList]::new()

    foreach ($LegacyPhoneNumber in $LegacyPhoneNumbers) {
        # Trim and normalize ";EXT=" to ";ext=" - IndexOf compares ordinal (case-sensitive), Teams LineUris are lower case
        $Legacy_LineUri = "$($LegacyPhoneNumber.LineUri)".Trim() -replace '(?i);ext=', ';ext='
        $Legacy_DisplayName = $LegacyPhoneNumber.LegacyName
        $Legacy_Type = "LegacyPhoneNumber"

        $ArrayIndex = [array]::IndexOf($MainArray.FullLineUri, $Legacy_LineUri)
        if ($ArrayIndex -ge 0) {

            # Add LineUri and UPN to duplicate error, if LineUri is already assigned to a Teams User
            if ($MainArray[$ArrayIndex].UPN -notlike "") {
                $DuplicateUPN = $MainArray[$ArrayIndex].UPN
                $NewRow = [pscustomobject]@{'LineUri' = $Legacy_LineUri; 'UPN' = $DuplicateUPN }
                [void]$Duplicate.Add($NewRow)
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

            # Check if NumberRangeName is "NoneDefined" and update from NumberRangeHashTable if available
            if ($MainArray[$ArrayIndex].NumberRangeName -eq "NoneDefined" -and $NumberRangeHashTable.ContainsKey($Legacy_LineUri)) {
                $CurrentNumberRangeEntry = $NumberRangeHashTable[$Legacy_LineUri]

                $MainArray[$ArrayIndex].DID = $CurrentNumberRangeEntry.DID -replace $null, ""
                $MainArray[$ArrayIndex].NumberRangeName = $CurrentNumberRangeEntry.NumberRangeName -replace $null, ""
                $MainArray[$ArrayIndex].NumberRangeIndex = $CurrentNumberRangeEntry.NumberRangeIndex -replace $null, ""
                $MainArray[$ArrayIndex].Country = $CurrentNumberRangeEntry.Country -replace $null, ""
                $MainArray[$ArrayIndex].City = $CurrentNumberRangeEntry.City -replace $null, ""
                $MainArray[$ArrayIndex].Company = $CurrentNumberRangeEntry.Company -replace $null, ""
                # The NumberRangeHashTable entries carry the number as LineUri (there is no MainLineUri property)
                $MainArray[$ArrayIndex].MainLineUri = $CurrentNumberRangeEntry.LineUri -replace $null, ""
                $MainArray[$ArrayIndex].NumberCapability = "User and Service" -replace $null, ""
            }

        }
        elseif ($NumberRangeHashTable.ContainsKey($Legacy_LineUri)) {
            $CurrentNumberRangeEntry = $NumberRangeHashTable[$Legacy_LineUri]

            $CurrentDID = $CurrentNumberRangeEntry.DID -replace $null, ""
            $CurrentNumberRangeName = $CurrentNumberRangeEntry.NumberRangeName -replace $null, ""
            $CurrentNumberRangeIndex = $CurrentNumberRangeEntry.NumberRangeIndex -replace $null, ""
            $CurrentCountry = $CurrentNumberRangeEntry.Country -replace $null, ""
            $CurrentCity = $CurrentNumberRangeEntry.City -replace $null, ""
            $CurrentCompany = $CurrentNumberRangeEntry.Company -replace $null, ""

            $NewRow = [pscustomobject]@{'FullLineUri' = $Legacy_LineUri; 'MainLineUri' = $Legacy_LineUri; 'DID' = $CurrentDID; 'TeamsEXT' = 'NoneDefined'; 'NumberRangeName' = $CurrentNumberRangeName; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = 'NoneDefined'; 'UPN' = 'NoneDefined'; 'Display_Name' = $Legacy_DisplayName; 'OnlineVoiceRoutingPolicy' = 'NoneDefined'; 'TeamsCallingPolicy' = 'NoneDefined'; 'DialPlan' = 'NoneDefined'; 'TenantDialPlan' = 'NoneDefined'; 'TeamsPrivateLine' = 'NoneDefined'; 'VoiceType' = $Legacy_Type; 'UserType' = 'NoneDefined'; 'NumberCapability' = 'NoneDefined'; 'NumberRangeIndex' = $CurrentNumberRangeIndex; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = 'NoneDefined'; 'Country' = $CurrentCountry; 'City' = $CurrentCity; 'Company' = $CurrentCompany; 'EmergencyAddressName' = 'NoneDefined'; 'Status' = '' }
            [void]$MainArray.Add($NewRow)
            Clear-Variable -Name ("CurrentDID", "CurrentNumberRangeName", "CurrentNumberRangeIndex", "CurrentCountry", "CurrentCity", "CurrentCompany", "NewRow", "CurrentNumberRangeEntry")

        }
        else {
            # Legacy number not found in MainArray or NumberRangeHashTable
            if ($EnableEnhancedLoggingOutput) {
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                Write-Output "$TimeStamp - Block 3 - ## EnhancedLog: Legacy number not found: $Legacy_LineUri (Name: $Legacy_DisplayName)"
                Write-Output "$TimeStamp - Block 3 - ## EnhancedLog:   Length: $($Legacy_LineUri.Length)"
                Write-Output "$TimeStamp - Block 3 - ## EnhancedLog:   Bytes: $([System.Text.Encoding]::UTF8.GetBytes($Legacy_LineUri) -join ' ')"

                # Check for non-standard characters
                $hasNonStandardChars = $false
                $charDetails = @()
                for ($i = 0; $i -lt $Legacy_LineUri.Length; $i++) {
                    $char = $Legacy_LineUri[$i]
                    $charCode = [int][char]$char
                    if ($char -eq '+') {
                        $charDetails += "[$i]='$char' (Plus, Code:$charCode)"
                    }
                    elseif ($char -match '[0-9]') {
                        $charDetails += "[$i]='$char' (Digit, Code:$charCode)"
                    }
                    else {
                        $charDetails += "[$i]='$char' (UNEXPECTED, Code:$charCode)"
                        $hasNonStandardChars = $true
                    }
                }
                Write-Output "$TimeStamp - Block 3 - ## EnhancedLog:   Character Analysis: $($charDetails -join ', ')"
                if ($hasNonStandardChars) {
                    Write-Output "$TimeStamp - Block 3 - ## EnhancedLog:   WARNING: Non-standard characters detected!"
                }

                # Try to find similar numbers in NumberRangeHashTable
                $similarKeys = $NumberRangeHashTable.Keys | Where-Object { $_ -like "$($Legacy_LineUri.Substring(0, [Math]::Min(10, $Legacy_LineUri.Length)))*" } | Select-Object -First 5
                if ($similarKeys) {
                    Write-Output "$TimeStamp - Block 3 - ## EnhancedLog:   Similar keys in HashTable: $($similarKeys -join ', ')"
                }
            }
            $NewRow = [pscustomobject]@{'FullLineUri' = $Legacy_LineUri; 'MainLineUri' = $Legacy_LineUri; 'DID' = ''; 'TeamsEXT' = ''; 'NumberRangeName' = 'NoneDefined'; 'ExtensionRangeName' = 'NoneDefined'; 'CivicAddressMappingName' = 'NoneDefined'; 'UPN' = 'NoneDefined'; 'Display_Name' = $Legacy_DisplayName; 'OnlineVoiceRoutingPolicy' = 'NoneDefined'; 'TeamsCallingPolicy' = 'NoneDefined'; 'DialPlan' = 'NoneDefined'; 'TenantDialPlan' = 'NoneDefined'; 'TeamsPrivateLine' = 'NoneDefined'; 'VoiceType' = $Legacy_Type; 'UserType' = 'NoneDefined'; 'NumberCapability' = 'NoneDefined'; 'NumberRangeIndex' = 'NoneDefined'; 'ExtensionRangeIndex' = 'NoneDefined'; 'CivicAddressMappingIndex' = 'NoneDefined'; 'Country' = 'NoneDefined'; 'City' = 'NoneDefined'; 'Company' = 'NoneDefined'; 'EmergencyAddressName' = 'NoneDefined'; 'Status' = '' }
            [void]$MainArray.Add($NewRow)
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

#Define Date for today (00:00:00) - an entry is removed on the day AFTER BlockUntil
$NowDate = (Get-Date).Date
$BlockItemDeleteErrorCount = 0

foreach ($BlockListItem in $BlockExtensionList) {
    if ($($BlockListItem.LineUri) -notlike "") {
        # Reset per item - never reuse values of the previous loop run
        $ExpirationDate = $null
        $BlockItemLineUri = $BlockListItem.LineUri.Trim()
        $BlockItemReason = $BlockListItem.BlockReason
        $BlockItemID = "$($BlockListItem.id)".Trim()
        $BlockItemDate = "$($BlockListItem.BlockUntil)".Trim()

        if ($BlockItemDate -like "") {
            # No BlockUntil -> permanent block - keep entry
            if ($EnableEnhancedLoggingOutput) {
                Write-Output "## EnhancedLog: Keep Block Item $BlockItemLineUri - no BlockUntil date (permanent block) Reason: $BlockItemReason"
            }
            continue
        }

        # Accepted formats: d.M.yy, d.M.yyyy, dd.MM.yy, dd.MM.yyyy - separator "." or "/"
        if ($BlockItemDate -match '^(?<Day>[0-3]?[0-9])[./](?<Month>[01]?[0-9])[./](?<Year>(?:[0-9]{2})?[0-9]{2})$') {
            $Day = $Matches.Day.PadLeft(2, '0')
            $Month = $Matches.Month.PadLeft(2, '0')
            $Year = $Matches.Year
            if ($Year.Length -eq 2) {
                # BlockUntil is always a future date when it is created -> a 2-digit year is always 20xx
                $Year = "20" + $Year
            }
            $BlockItemDateNormalized = $Day + '.' + $Month + '.' + $Year
            try {
                $ExpirationDate = [datetime]::ParseExact($BlockItemDateNormalized, 'dd.MM.yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
            }
            catch {
                $ExpirationDate = $null
            }
        }

        if ($null -eq $ExpirationDate) {
            $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
            Write-Output ""
            Write-Output "$TimeStamp - Block 4 - Error: Date validation fail - Skip Entry $BlockItemLineUri - $BlockItemDate - $BlockItemReason"
            Write-Output ""
            continue
        }

        if ($NowDate -gt $ExpirationDate) {
            # Block item is expired and could be deleted
            if ($BlockItemID -notlike "") {
                $GraphAPIUrl_DeleteElement = $BlockExtensionListURL + '/items/' + $BlockItemID
                if ($EnableEnhancedLoggingOutput) {
                    Write-Output "## EnhancedLog: Delete Block Item $BlockItemLineUri Date: $BlockItemDate Reason: $BlockItemReason ID: $BlockItemID"
                }
                try {
                    $TMP = Invoke-TPIRestMethod -Uri $GraphAPIUrl_DeleteElement -Method Delete -ProcessPart "BlockExtension List: Delete item: $BlockItemLineUri" -VerboseGraphAPILogging:$VerboseGraphAPI
                }
                catch {
                    # Not fatal: the entry stays in the list and is still applied as block in Block 5 - the inventory update (Block 5 and 6) continues
                    $BlockItemDeleteErrorCount++
                    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                    Write-Warning "$TimeStamp - Block 4 - Error! - Expired entry could not be removed - LineUri: $BlockItemLineUri BlockUntil: $BlockItemDate ID: $BlockItemID - entry stays in the list and is still applied as block in Block 5 - $($_.Exception.Message)"
                }
                $GraphAPIUrl_DeleteElement = $null
            }
            else {
                $BlockItemDeleteErrorCount++
                $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                Write-Warning "$TimeStamp - Block 4 - Error! - Expired entry could not be removed - no SharePoint item id for LineUri: $BlockItemLineUri BlockUntil: $BlockItemDate"
            }
        }
    }
}

if ($BlockItemDeleteErrorCount -gt 0) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Warning "$TimeStamp - Block 4 - $BlockItemDeleteErrorCount expired BlockExtension entries could not be removed - see warnings above"
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
    # Trim and normalize ";EXT=" to ";ext=" - IndexOf compares ordinal (case-sensitive), Teams LineUris are lower case
    $BlockExtensionLineUri = "$($BlockExtensionItem.LineUri)".Trim() -replace '(?i);ext=', ';ext='
    if ($BlockExtensionLineUri -like "") {
        continue
    }
    $ArrayIndex = [array]::IndexOf($MainArray.FullLineUri, $BlockExtensionLineUri)
    if ($ArrayIndex -lt 0) {
        # -1 would address the last entry of the MainArray - never write the block status to a foreign entry
        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
        Write-Warning "$TimeStamp - Block 5 - BlockExtension entry $BlockExtensionLineUri is not part of the inventory (not in a number or extension range, not assigned in Teams, not a legacy number) - skipped"
        continue
    }
    $CurrentStatus = $MainArray[$ArrayIndex].Status
    $BlockStatus = 'BlockNumber_Until' + $($BlockExtensionItem.BlockUntil) + '_Reason' + $($BlockExtensionItem.BlockReason) + ';'
    $MainArray[$ArrayIndex].Status = $CurrentStatus + $BlockStatus
}

$BlockExtension = $null

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
#Clear $NumberRangeArray and HashTable for less memory usage before starting TPI read (huge amount of memory needed)
$NumberRangeArray = $null
$NumberRangeHashTable = $null

# Try to clear unused memory
$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Host "$TimeStamp - CleanUp - Memory used before collection: $([System.GC]::GetTotalMemory($false))"
[System.GC]::Collect()

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Host "$TimeStamp - CleanUp - Memory used after full collection: $([System.GC]::GetTotalMemory($true))"
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

# Duplicate FullLineUris in the list (e.g. from a repeated batch request) - the first entry is updated, the additional entries are removed in the delete step below
$DuplicateTPIListEntries = $TPIList | Group-Object -Property FullLineUri | Where-Object Count -gt 1
if (($DuplicateTPIListEntries | Measure-Object).Count -gt 0) {
    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
    Write-Warning "$TimeStamp - Block 6 - The SharePoint list contains $(($DuplicateTPIListEntries | Measure-Object).Count) FullLineUri(s) more than once - the additional entries will be removed: $(($DuplicateTPIListEntries.Name) -join ', ')"
}

$TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
Write-Output "$TimeStamp - Block 6 - Compare the MainArray with the SharePoint List to check if items in the list need to be updated"
$DifferentEntries = Compare-Object -ReferenceObject $MainArray -DifferenceObject $TPIList -Property FullLineUri, MainLineUri, DID, TeamsEXT, NumberRangeName, ExtensionRangeName, CivicAddressMappingName, UPN, Display_Name, OnlineVoiceRoutingPolicy, TeamsCallingPolicy, DialPlan, TenantDialPlan, TeamsPrivateLine, VoiceType, UserType, NumberCapability, NumberRangeIndex, ExtensionRangeIndex, CivicAddressMappingIndex, Country, City, Company, EmergencyAddressName, Status | Where-Object SideIndicator -Like "<="
$NoUpdate = 0
$Counter = 0

if ($($DifferentEntries | Measure-Object).Count -gt 0) {
    if ($EnableEnhancedLoggingOutput -and (($DifferentEntries | Measure-Object).Count -lt 100)) {
        Write-Output "## EnhancedLog: Detailed Information for different entries"
        foreach ($Entry in $DifferentEntries) {
            $ReferenceEntry = $MainArray | Where-Object FullLineUri -EQ $Entry.FullLineUri
            $DifferenceEntry = $TPIList | Where-Object FullLineUri -EQ $Entry.FullLineUri
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

            # First entry only - a duplicate would turn $ID into an array and the URL into "/items/12 13"; the additional entries are removed in the delete step
            $ID = ($TPIList | Where-Object FullLineUri -eq $Entry.FullLineUri | Select-Object -First 1).ID
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
                    if (([int]"$($Response.status)" -ge 400) -or ($Response.body.error.message -notlike "")) {
                        $ID = $response.id
                        $ResponseError = $Response.body.error.message
                        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                        Write-Error "$TimeStamp - Block 6 - Error in ID $ID - Error: $ResponseError"
                        exit
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
                    if (([int]"$($Response.status)" -ge 400) -or ($Response.body.error.message -notlike "")) {
                        $ID = $response.id
                        $ResponseError = $Response.body.error.message
                        $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                        Write-Error "$TimeStamp - Block 6 - Error in ID $ID - Error: $ResponseError"
                        exit
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
# Key comparison on FullLineUri only: an entry whose values still differ after the update step is kept (and updated again in the next run), not deleted and re-created.
# Set based (not Compare-Object, which matches one-to-one and would report one of two duplicates as orphan) - every entry to delete carries its own item id.
$MainArrayLineUris = [System.Collections.Generic.HashSet[string]]::new()
foreach ($MainArrayEntry in $MainArray) {
    [void]$MainArrayLineUris.Add("$($MainArrayEntry.FullLineUri)")
}
$EntrysToDelete = [System.Collections.ArrayList]::new()
foreach ($TPIListEntry in @($TPIList)) {
    if (($null -ne $TPIListEntry) -and (-not $MainArrayLineUris.Contains("$($TPIListEntry.FullLineUri)"))) {
        [void]$EntrysToDelete.Add([PSCustomObject]@{ FullLineUri = $TPIListEntry.FullLineUri; ID = $TPIListEntry.ID; Display_Name = $TPIListEntry.Display_Name; VoiceType = $TPIListEntry.VoiceType; Reason = "orphan" })
    }
}
# Duplicate FullLineUris: keep the first entry (the one the update step addresses), remove the additional ones
$DuplicateTPIListEntries = $TPIList | Group-Object -Property FullLineUri | Where-Object Count -gt 1
foreach ($DuplicateTPIListEntry in $DuplicateTPIListEntries) {
    foreach ($AdditionalEntry in ($DuplicateTPIListEntry.Group | Select-Object -Skip 1)) {
        if ($EntrysToDelete.ID -notcontains $AdditionalEntry.ID) {
            [void]$EntrysToDelete.Add([PSCustomObject]@{ FullLineUri = $AdditionalEntry.FullLineUri; ID = $AdditionalEntry.ID; Display_Name = $AdditionalEntry.Display_Name; VoiceType = $AdditionalEntry.VoiceType; Reason = "duplicate" })
        }
    }
}

$EntrysToDeleteCount = $($EntrysToDelete | Measure-Object).Count
if ($EntrysToDeleteCount -gt 0) {
    if ($EnableEnhancedLoggingOutput -and ($EntrysToDeleteCount -lt 100)) {
        Write-Output "## EnhancedLog: Detailed Information for entries to be deleted"
        foreach ($Entry in $EntrysToDelete) {
            Write-Output "## EnhancedLog:   - Entry $($Entry.FullLineUri) (ID: $($Entry.ID)) is in TPIList but needs to be deleted - reason: $($Entry.Reason)"
        }
    }
    elseif ($EnableEnhancedLoggingOutput) {
        Write-Output "## EnhancedLog: Detailed Information for entries to be deleted"
        Write-Output "## EnhancedLog: Too many entries to display detailed information. (Amount of entries: $EntrysToDeleteCount)"
    }

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
        # The item id comes from the SharePoint entry itself (see the compare above) - no lookup by FullLineUri, so duplicates are removed one by one
        $ID = $DeleteItem.ID
        $GraphAPIUrl_DeleteElement = $($TPIListURL + '/items/' + $ID) -replace "https://graph.microsoft.com/v1.0", ""

        $BatchPart = [PSCustomObject][ordered]@{
            id     = $TMP_Counter20
            method = "DELETE"
            URL    = $GraphAPIUrl_DeleteElement
            headers = $BatchHeader
        }
        $CurrentBatch += $BatchPart

        if ($BatchReady) {
            $BatchReady = $false
            $BatchCount++
            $BatchRequestBody = [ordered]@{requests = $CurrentBatch }
            $TMP = Invoke-TPIRestMethod -Uri 'https://graph.microsoft.com/v1.0/$batch' -Method Post -Body $BatchRequestBody -ProcessPart "TPI List - Delete item - BatchCount: $BatchCount" -VerboseGraphAPILogging:$VerboseGraphAPI
            foreach ($Response in $TMP.responses) {
                if (([int]"$($Response.status)" -ge 400) -or ($Response.body.error.message -notlike "")) {
                    $ID = $response.id
                    $ResponseError = $Response.body.error.message
                    $TimeStamp = ([datetime]::now).tostring("yyyy-MM-dd HH:mm:ss")
                    Write-Error "$TimeStamp - Block 6 - Error in ID $ID - Error: $ResponseError"
                    exit
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