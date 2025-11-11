<#
    .SYNOPSIS
    Get next free number from SharePoint List (TPI).

    .DESCRIPTION
    This runbook reads the SharePoint list and displays the next three free numbers according to the filters (=parameters). The default filter "*", which is prefilled for all entries, stands for "any" (wildcard).
    The runbook is part of the TeamsPhoneInventory.

    .NOTES
    Version Changelog:
    1.1.0 - 2025-02-17 - Convert to current nativ GraphAPI based functions (Get-TPIList, Invoke-TPIRestMethod)
                       - Add automatic detection of SharePoint URL
                       - Enhance output and change to list format
    1.0.0 - 2024-12-20 - Initial Version (=first version in which versioning is defined)


    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "SharepointSite": {
                "Hide": true
            },
            "SharepointTPIList": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.4" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion="2.32.0" }

Param(
        # App Registration for Update regulary TeamsPhoneInventory List - not for initializing (scoped site permission)
        # Define Sharepoint Parameters
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointSite" } )]
        [string] $SharepointSite,
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointTPIList" } )]
        [string] $SharepointTPIList,

        #Search parameter - default is "*" which means wildcard

        [ValidateScript( { Use-RJInterface -DisplayName "Country" } )]
        [String] $Country = "*",

        [ValidateScript( { Use-RJInterface -DisplayName "City" } )]
        [String] $City = "*",

        [ValidateScript( { Use-RJInterface -DisplayName "Company Name" } )]
        [String] $Company = "*",

        [ValidateScript( { Use-RJInterface -DisplayName "TPI Extension Range Name" } )]
        [String] $ExtensionRangeName = "*",

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

########################################################
##             RJ Log Part
##
########################################################

# Add Caller in Verbose output
if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

# Add Version in Verbose output
$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "Submitted parameters:" -Verbose
Write-RjRbLog -Message "SharepointSite: $SharepointSite" -Verbose
Write-RjRbLog -Message "SharepointTPIList: $SharepointTPIList" -Verbose

#endregion

########################################################
##             Setup Part
##
########################################################

# Setup connection
Write-Output "Connect to Microsoft Graph"
Connect-RjRbGraph

Write-Output ""
Write-Output "Check basic connection to TPI List and build base URL"

# Get SharePoint WebURL
$SharepointURL = (Invoke-TPIRestMethod -Uri "https://graph.microsoft.com/v1.0/sites/root" -Method GET -ProcessPart "Get SharePoint WebURL").webUrl
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


#######################################################
# 		Main Part
#
#######################################################

#Get Status Quo of the Sharepoint List
Write-Output "Get StatusQuo of the SharePoint List"

$AllItems = Get-TPIList -ListBaseURL $TPIListURL -ListName $SharepointTPIList

Write-Output "Analysis - Items in $SharepointTPIList SharePoint List: $($AllItems.Count)"
Write-Output "Analysis - Check for next free number"
Write-Output "Current filter: Country: $Country, City: $City, Company: $Company, ExtensionRangeName: $ExtensionRangeName"
Write-Output 'Filter description - "*" means "any" (wildcard)'
#Get next free number
$NextFreeNumber = ($AllItems | Where-Object {($_.Country -Like $Country) -and ($_.City -Like $City) -and ($_.Company -Like $Company) -and ($_.ExtensionRangeName -Like $ExtensionRangeName) -and ($_.Display_Name -Like "") -and ($_.UPN -Like "") -and ($_.Type -NotLike "LegacyPhoneNumber") -and ($_.Status -notmatch '.*BlockNumber_Until([0]?[1-9]|[1|2][0-9]|[3][0|1]).([0]?[1-9]|[1][0-2]).([0-9]{4}|[0-9]{2}).*') -and ($_.Status -notmatch '.*BlockNumber_Permanent.*') -and ($_.Status -notmatch '.*BlockNumber_permanent.*')} | Sort-Object Title | Select-Object Title,NumberRangeName,ExtensionRangeName,Country,City,Company -First 1)

if ($NextFreeNumber.count -eq 0) {
    $NextFreeNumber = "NoFreeNumberAvailable"
}

Write-Output ""
Write-Output "Next free number:"
$NextFreeNumber | Format-List