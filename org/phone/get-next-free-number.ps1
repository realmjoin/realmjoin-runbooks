<#
    .SYNOPSIS
    Get next free number from SharePoint List (TPI).

    .DESCRIPTION
    This runbook reads the SharePoint list and displays the next three free numbers according to the filters (=parameters). The default filter "*", which is prefilled for all entries, stands for "any" (wildcard). 
    The runbook is part of the TeamsPhoneInventory.

    .NOTES
    Permissions: MS Graph
    - Site.Selected -> Requires permission on specific SharePoint List!

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
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

Param(
        # App Registration for Update regulary TeamsPhoneInventory List - not for initializing (scoped site permission)
        # Define Sharepoint Parameters
        [ValidateScript( { Use-RJInterface -Type Setting -Attribute "TPI.SharepointURL" } )]
        [string] $SharepointURL,
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
        [String]
        $ListBaseURL,
        [parameter(Mandatory = $false)]
        [String]
        $ListName # Only for easier logging
    )
    
    #Get fresh status quo of the SharePoint List after updating
    
    Write-Output "GraphAPI - Get fresh StatusQuo of the SharePoint List $ListName"

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
            
            Write-Output ""
            Write-Output "GraphAPI - Error! Process part: $ProcessPart"
            $StatusCode = $_.Exception.Response.StatusCode.value__ 
            $StatusDescription = $_.Exception.Response.ReasonPhrase
            Write-Output "GraphAPI - Error! StatusCode: $StatusCode"
            Write-Output "GraphAPI - Error! StatusDescription: $StatusDescription"
            Write-Output ""

            Write-Output "GraphAPI - One Retry after 5 seconds"
            Connect-RjRbGraph -Force
            Start-Sleep -Seconds 5
            try {
                $TPIRestMethod = Invoke-RjRbRestMethodGraph -Resource $Uri -Method $Method -Body $Body
                Write-Output "GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
            } catch {
                
                # $2ndLastError = $_.Exception
                $ExitError = 1
                $StatusCode = $_.Exception.Response.StatusCode.value__ 
                $StatusDescription = $_.Exception.Response.ReasonPhrase
                Write-Output "GraphAPI - Error! Process part: $ProcessPart error is still present!"
                Write-Output "GraphAPI - Error! StatusCode: $StatusCode"
                Write-Output "GraphAPI - Error! StatusDescription: $StatusDescription"
                Write-Output ""
                $ExitError = 1
            } 
        }
    }else{
        try {
            $TPIRestMethod = Invoke-RjRbRestMethodGraph -Resource $Uri -Method $Method
        }
        catch {
            
            Write-Output ""
            Write-Output "GraphAPI - Error! Process part: $ProcessPart"
            $StatusCode = $_.Exception.Response.StatusCode.value__ 
            $StatusDescription = $_.Exception.Response.ReasonPhrase
            Write-Output "GraphAPI - Error! StatusCode: $StatusCode"
            Write-Output "GraphAPI - Error! StatusDescription: $StatusDescription"
            Write-Output ""
            Write-Output "GraphAPI - One Retry after 5 seconds"
            Connect-RjRbGraph -Force
            Start-Sleep -Seconds 5
            try {
                $TPIRestMethod = Invoke-RjRbRestMethodGraph -Resource $Uri -Method $Method
                Write-Output "GraphAPI - 2nd Run for Process part: $ProcessPart is Ok"
            } catch {
                
                # $2ndLastError = $_.Exception
                $ExitError = 1
                $StatusCode = $_.Exception.Response.StatusCode.value__ 
                $StatusDescription = $_.Exception.Response.ReasonPhrase
                Write-Output "GraphAPI - Error! Process part: $ProcessPart error is still present!"
                Write-Output "GraphAPI - Error! StatusCode: $StatusCode"
                Write-Output "GraphAPI - Error! StatusDescription: $StatusDescription"
                Write-Output ""
            } 
        }
    }

    if ($ExitError -eq 1) {
        throw "GraphAPI - Error! Process part: $ProcessPart error is still present! StatusCode: $StatusCode StatusDescription: $StatusDescription"
        $StatusCode = $null
        $StatusDescription = $null
    }

    return $TPIRestMethod
    
}

########################################################
##             Setup Part
##          
########################################################
# Add Caller in Verbose output
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

# Add Parameter in Verbose output
Write-RjRbLog -Message "SharepointURL: '$SharepointURL'" -Verbose
Write-RjRbLog -Message "SharepointSite: '$SharepointSite'" -Verbose
Write-RjRbLog -Message "SharepointTPIList: '$SharepointTPIList'" -Verbose

# Setup connection
Write-Output "Connect to Microsoft Graph"
Connect-RjRbGraph

Write-Output ""
Write-Output "Check basic connection to TPI List and build base URL"

# Setup Base URL - not only for NumberRange etc.
$BaseURL = '/sites/' + $SharepointURL + ':/teams/' + $SharepointSite + ':/lists/' 
$TPIListURL = $BaseURL + $SharepointTPIList
try {
    Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" -ErrorAction Stop | Out-Null
}
catch {
    $BaseURL = '/sites/' + $SharepointURL + ':/sites/' + $SharepointSite + ':/lists/' 

    $TPIListURL = $BaseURL + $SharepointTPIList
    try {
        Invoke-TPIRestMethod -Uri $BaseURL -Method Get -ProcessPart "Check connection to TPI List" | Out-Null
    }
    catch {
        Write-Output ""
        Write-Output "Error:"
        Write-Output "Could not connect to SharePoint TPI List!"
        Write-Output ""
        throw "Could not connect to SharePoint TPI List!"
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

$NextFreeNumber = ($AllItems | Where-Object {($_.Country -Like $Country) -and ($_.City -Like $City) -and ($_.Company -Like $Company) -and ($_.ExtensionRangeName -Like $ExtensionRangeName) -and ($_.Display_Name -Like "") -and ($_.UPN -Like "") -and ($_.Type -NotLike "LegacyPhoneNumber") -and ($_.Status -notmatch '.*BlockNumber-Until([0]?[1-9]|[1|2][0-9]|[3][0|1]).([0]?[1-9]|[1][0-2]).([0-9]{4}|[0-9]{2})\;.*') -and ($_.Status -notmatch '.*BlockNumber-Permanent.*')} | Sort-Object LineUri | Select-Object Title,DID,NumberRangeName,ExtensionRangeName,Country,City,Company -First 1)

if ($NextFreeNumber.count -eq 0) {
    $NextFreeNumber = "NoFreeNumberAvailable"
}

$NextFreeNumber | Format-Table