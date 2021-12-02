<#
  .SYNOPSIS
  Generate an Office 365 licensing report.

  .DESCRIPTION
  Generate an Office 365 licensing report.
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

try {
    $VerbosePreference = "SilentlyContinue"

    Connect-RjRbGraph
    Connect-RjRbExchangeOnline

    # "This report heavily uses 'all users' lists. Will fetch them one time."
    $allUsers = Invoke-RjRbRestMethodGraph -Resource "/users" -FollowPaging:$true

    # "Adapted from https://docs.microsoft.com/de-de/microsoft-365/enterprise/view-licensed-and-unlicensed-users-with-microsoft-365-powershell?view=o365-worldwide"
    $AllNoLicenseUsers = @()
    $AllLicensedUsers = @()
    $allUsers | ForEach-Object { 
        $licensed = $False ; 
        $assignedLicenses = Invoke-RjRbRestMethodGraph -Resource "/users/$($_.id)/licenseDetails"
        For ($i = 0; $i -lt ($assignedLicenses | Measure-Object).Count ; $i++) { 
            If ( [string]::IsNullOrEmpty($assignedLicenses[$i].skuId) -ne $True) { 
                $licensed = $true 
            } 
        }  
        If ( $licensed ) { 
            # "$($_.UserPrincipalName) is licensed"
            $AllLicensedUsers += $_.userPrincipalName 
        }
        else {
            # "$($_.UserPrincipalName) is not licensed"
            $AllNoLicenseUsers += $_.userPrincipalName 
        }
    }

    # "Get Mailboxes"
    $AllUserMailboxes = (Get-EXOMailbox -ResultSize Unlimited | Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" }).UserPrincipalName
    $NoLicenseMailboxes = $AllUserMailboxes | Where-Object { $AllNoLicenseUsers -contains $_ }

    # "Get SKUs and build a lookuptable for SKU IDs"
    $SkuHashtable = @{}
    $Skus = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus"
    $Skus | ForEach-Object {
        $SkuHashtable.Add($_.skuId, $_.skuPartNumber)
    }

    # "List of well known SKUs - please update/add more when needed."
    $SkuNames = @{
        "EXCHANGESTANDARD"           = "Exchange Online Plan1"
        "EXCHANGEENTERPRISE"         = "Exchange Online Plan2"
        "STANDARDPACK"               = "Office365 Enterprise E1"
        "ENTERPRISEPACK"             = "Office365 Enterprise E3"
        "O365_BUSINESS_PREMIUM"      = "Microsoft 365 Business Standard"
        "SPE_E3"                     = "Microsoft 365 E3"
        "CRMPLAN2"                   = "Microsoft Dynamics CRM Online Basic"
        "CRMSTANDARD"                = "Microsoft Dynamics CRM Online Professional"
        "CRMINSTANCE"                = "Microsoft Dynamics CRM Online Instance"
        "POWER_BI_STANDARD"          = "Power BI (free)"
        "POWER_BI_PRO"               = "Power BI Pro"
        "ATP_ENTERPRISE"             = "Exchange Online Advance Thread Protection"
        "MDATP_XPLAT"                = "Microsoft Defender For Endpoint"
        "PROJECTESSENTIALS"          = "Project Online Essentials"
        "PROJECTPREMIUM"             = "Project Online Premium"
        "POWERAPPS_VIRAL"            = "Microsoft Power Apps and Flow"
        "STREAM"                     = "Microsoft Stream"
        "IDENTITY_THREAT_PROTECTION" = "Microsoft 365 E5 Security"
        "MCOEV"                      = "Microsoft 365 Phone System"
        "MCOMEETADV"                 = "Audioconferencing in Microsoft 365"
        "MEETING_ROOM"               = "Teams Meeting Room"
        "FLOW_FREE"                  = "Microsoft Flow (free)"
        "RMSBASIC"                   = "Rights Management Basic"
        "MCOPSTNC"                   = "Communications Credits"
        "PHONESYSTEM_VIRTUALUSER"    = "Microsoft 365 Phone System - Virtual User"
    }

    # SKUs to ignore
    $ignoreListe = (
        "TEAMS_EXPLORATORY",
        "WINDOWS_STORE"
    )

    # "Prepare results"
    $results = @()

    class LicReportObject {
        [string] $Name
        [int] $Total
        [int] $Used
        [int] $Available
    }

    $SKUs | ForEach-Object {
        #only look at active and relevant licenses
        if (($_.prepaidUnits.enabled -gt 0) -and (-not $ignoreListe.contains($_.skuPartNumber))) {
            $entry = [LicReportObject]::new() 

            if ($SkuNames.contains($_.skuPartNumber)) {
                # "Well known SKU found: $($SkuNames[$_.SkuPartNumber])"
                $entry.Name = $SkuNames[$_.skuPartNumber]
            }
            else {
                # "Fallback if unknown SKU: $($_.SkuPartNumber)"
                $entry.Name = $_.skuPartNumber
            }
            $entry.Total = $_.prepaidUnits.enabled
            $entry.Used = $_.consumedUnits
            $entry.Available = $_.prepaidUnits.enabled - $_.consumedUnits

            $results += $entry
        }
    }

    # "Output trouble cases"

    if ($NoLicenseMailboxes) {
        "## Mailboxes with no license:"
        $NoLicenseMailboxes
        ""
    }

    if ($DuplicateLicenseUsers) {
        "## Mailboxes with duplicate license:"
        $DuplicateLicenseUsers
        ""
    }

    # "Output reporting"

    "## Totals of licenses we have:"
    ""
    $results | sort-object -property Name | format-table | out-string
}
catch { 
    "## Access to either AzureAD or Exchange Online failed. Maybe missing permissions?"
    ""
    "## Please make sure, the follwing permissions are given:"
    "## - Office 365 Exchange Online: Exchange.ManageAsApp (application permission)"
    "## - MS Graph API: User.Read.All (application permission)"
    "## - AzureAD Roles: Exchange Administrator"
    ""
    throw $_
}
finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}