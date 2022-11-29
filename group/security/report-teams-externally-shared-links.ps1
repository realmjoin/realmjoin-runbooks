<#
  .SYNOPSIS
  Scan a single Team for externally shared links. Report those to team owners.

  .DESCRIPTION
  Scan a single Team for externally shared links. Report those to team owners.

  .PARAMETER fromUser
  Email-Address of a shared mailbox to be the sender of the reports.

  .PARAMETER failsafeRecipient
  Email-Address to send the report to if no owners exist.

  .PARAMETER ccToFailsafeRecipient
  CC the report to failsafeRecipient additionally to the owners.

  .PARAMETER overrideRecipient
  Ignore owners and failsafeRecipient and send the report exclusively to this recipient.
  Primarilly intended for testing.


  .NOTES
  Permissions
   MS Graph (API): 
   - Policy.Read.All
   - User.SendMail
   

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            },
            "overrideRecipient": {
                "Hide": true
            },
            "groupId": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules PnP.PowerShell,RealmJoin.RunbookHelper

param(
    [string]$fromUser = "RoboReports@contoso.com",
    [string]$failsafeRecipient = "ciso@contoso.com",
    [bool]$ccToFailsafeRecipient = $false,
    [string]$overrideRecipient = "",
    [Parameter(Mandatory = $true)]
    [string]$groupId
)

Connect-RjRbGraph

$groupObj = Invoke-RjRbRestMethodGraph -Resource "/groups/$groupId"
$site = $groupObj.displayName
#"# Reporting Site '$site'"
try {
    $siteObj = Invoke-RjRbRestMethodGraph -Resource "/groups/$groupId/sites/root"
}
catch {
    "## '$site' is not a SharePoint site"
    return
}

$siteUrls = @()

# Collect main site's URL
"## Main Site found - '$($siteObj.webUrl)'"
$siteUrls += $siteObj.webUrl

# Collect private and shared channels
$pattern = [regex] '\.sharepoint\.com/sites/.*'
$adminUrl = ($siteObj.webUrl -replace $pattern) + "-admin.sharepoint.com"
#"adminUrl: $adminUrl"
Connect-PnPOnline -Url $adminUrl -ManagedIdentity | Out-Null
$allSites = get-PnPTenantSite
$privateChannels = $allSites | Where-Object { ($_.RelatedGroupId -eq $groupId) -and ($_.GroupId -eq "00000000-0000-0000-0000-000000000000") }
foreach ($channel in $privateChannels) {
    "## Channel Site found - '$($channel.Url)'"
    $siteUrls += $channel.Url
}
Disconnect-PnPOnline | Out-Null
""

foreach ($webUrl in $siteUrls) {
    $siteObj = $allSites | Where-Object { $_.Url -eq $webUrl}
    $site = $siteObj.Title
    "# Reporting Site '$site'"
    $ReportFolder = (get-date -Format yyyy-MM-dd)
    $ReportOutput = $ReportFolder + "\" + ($site -replace "[$([RegEx]::Escape([string][IO.Path]::GetInvalidFileNameChars()))]+", "_") + "_ExternalSharedLinks.csv"

    if (Test-Path -Path $ReportOutput) {
        "## File '$ReportOutput' exists. Skipping Site '$site'..."
    }
    else {

        Connect-PnPOnline -ManagedIdentity -Url $webUrl | Out-Null
        $context = Get-PnPContext

        $list = "Dokumente"
        $ItemCount = [int](get-pnplist -Identity $list -ErrorAction SilentlyContinue).ItemCount
        #$ListItems = Get-PnPListItem -List $list -PageSize 2000 -ErrorAction SilentlyContinue 
        if ($ItemCount -lt 1) {
            $list = "Documents"
            $ItemCount = [int](get-pnplist -Identity $list -ErrorAction SilentlyContinue).ItemCount
            #$ListItems = Get-PnPListItem -List $list -PageSize 2000 -ErrorAction SilentlyContinue 
        }
        if ($ItemCount -lt 1) {
            "## No items found in '$site'. Wrong List?"
            throw ("no listitems found")
        }

        $Results = @()
        "## List contains $ItemCount objects"

        [int]$itemsProcessed = 0
        $result = $null
        do {
            if (-not $result) {
                $result = Invoke-PnPSPRestMethod -Url "$webUrl/_api/web/lists/getByTitle('$list')/items`?`$select=ID,hasuniqueroleassignments"
            }
            else {
                $result = Invoke-PnPSPRestMethod -Url $result.'odata.nextLink'
            }
            $ListItems = $result.value
   
            ForEach ($ItemRaw in $ListItems) {
                $itemsProcessed++
                if (($itemsProcessed % 1000) -eq 0) {
                    "## items processed: $itemsProcessed"
                }
                #Check if the Item has unique permissions
                If ($ItemRaw.HasUniqueRoleAssignments) {       
                    $Item = Get-PnPListItem -List $list -Id $ItemRaw.ID -ErrorAction SilentlyContinue
                    if ($item) {
                        #Get Sharing Info / Shared Links
                        $SharingInfo = [Microsoft.SharePoint.Client.ObjectSharingInformation]::GetObjectSharingInformation($context, $Item, $false, $false, $false, $true, $true, $true, $true)
                        $context.Load($SharingInfo)
                        $context.ExecuteQuery()

                        #Get "Shared-With"-Users
                        $context.Load($SharingInfo.SharedWithUsersCollection)
                        $context.ExecuteQuery()
                        $externalUsers = @()
                        foreach ($sharedUser in $SharingInfo.SharedWithUsersCollection) {
                            if ($sharedUser.IsExternalUser) {
                                if ($sharedUser.Email) {
                                    $externalUsers += $sharedUser.Email
                                }
                                else {
                                    $externalUsers += $sharedUser.LoginName.Split("|")[2]
                                }
                            }
                        }
                        if ($externalUsers.count -gt 0) {
                            " - Item $($item.id) - external link found."
                            #"   URL: $($Item.FieldValues["FileRef"])"
                            #"   eMail: $externalUser"
                            foreach ($externalUser in $externalUsers) {
                                $Results += New-Object PSObject -property $([ordered]@{    
                                        RelativeURL  = $Item.FieldValues["FileRef"]
                                        ExternalUser = $externalUser
                                    }) 
                            }
                        }
                    }
                }            
            } 
        } while ($result.'odata.nextLink') 

        if (-not (Test-Path -Path $ReportFolder -PathType Container)) {
            mkdir $ReportFolder | Out-Null
        }

        $Results | Export-CSV -Path $ReportOutput -NoTypeInformation -Delimiter ";" -Encoding Unicode

        Disconnect-PnPOnline | Out-Null
    }

    $contentRaw = Get-Content -Path $ReportOutput -Raw 
    
    if ($contentRaw) {
        $enc = [System.Text.Encoding]::Unicode
        $content = $enc.GetBytes($contentRaw)
        $contentBytes = [System.Convert]::ToBase64String($content)

        $message = @{
            subject     = "[Autom. erstellter Report] Team '$site' Shared Links"
            body        = @{
                contentType = "HTML"
                content     = @"
<p>Dies ist eine automatisch erstellte Mail.</p>
<h1>Team '$site' Sharing Links</h1>
<p>Im Anhang finden Sie eine &Uuml;bersicht &uuml;ber externe Sharing-Links in Team '$site'.</p> 
<p>Bitte pr&uuml;fen Sie, ob diese noch ben&ouml;tigt werden und entfernen Sie nicht ben&ouml;tigte Zugriffsrechte.</p>
<p>Danke!</p>
"@
            }
            attachments = [array]@{
                "@odata.type" = "#microsoft.graph.fileAttachment"
                name          = "excel.csv"
                contentType   = "text/plain"
                contentBytes  = $contentBytes
            }    
        }

        $message.toRecipients = @()

        if (-not $overrideRecipient) {
            $owners = Invoke-RjRbRestMethodGraph -Resource "/groups/$($groupId)/owners"
            if ($owners) {
                foreach ($owner in $owners) {
                    $message.toRecipients += @{
                        emailAddress = @{
                            address = $owner.Mail
                        }
                    }    
                }
                if ($ccToFailsafeRecipient) {
                    $message.ccRecipients = [array]@{
                        emailAddress = @{
                            address = $failsafeRecipient
                        }
                    }
                }
            }
            else {
                # No owners found
                $message.toRecipients += @{
                    emailAddress = @{
                        address = $failsafeRecipient
                    }
                } 
            }
        }
        else {
            # override recipients = do not mail to owners or failsafe
            $message.toRecipients += @{
                emailAddress = @{
                    address = $overrideRecipient
                }
            } 
        }
    
        Invoke-RjRbRestMethodGraph -Resource "/users/$fromUser/sendMail" -Method POST -Body @{ message = $message } | Out-Null
        "## Mail sent"
    }
}