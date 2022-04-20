<#
  .SYNOPSIS
  List App registrations, which had no recent user logons.

  .DESCRIPTION
  List App registrations, which had no recent user logons.

  .NOTES
  Permissions
  MS Graph (API):
  - Directory.Read.All
  - Device.Read.All

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }

param(
    [ValidateScript( { Use-RJInterface -DisplayName "Days without user logon" } )]
    [int] $Days = 90,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
#Get the current date
$date = (get-date -f dd-MM-yyyy-hhmmss)
#Store the outputfile
$file="$dir\ListAzureADApps-$date.csv"
#Email to be sent from
$From="NewAADApps@eskonr"
$To="Sec1@eskonr.com","sec1@eskonr.com"
$Subject="New Azure AD apps added by Microsoft"
$Body="Hi,
Please find the list of newly added Microsoft apps in Azure Active Directory.
Thanks,
AAD Team
"

Get-AzureADServicePrincipal -All:$true | Where-Object {$_.PublisherName -like "*Microsoft*"}|
Select-Object DisplayName, AccountEnabled,ObjectId, AppId, AppOwnerTenantId,AppRoleAssignmentRequired,Homepage,LogoutUrl,PublisherName  |
Export-Csv -path $file -NoTypeInformation -Append
$New = Import-Csv (Get-Item "$dir\ListAzureADApps*.csv" | Sort-Object LastWriteTime -Descending |Select-Object -First 1 -ExpandProperty name)
$Old = Import-Csv (Get-Item "$dir\ListAzureADApps*.csv" | Sort-Object LastWriteTime -Descending |Select-Object -Skip 1 -First 1 -ExpandProperty name)
$AppsInBoth = Compare-Object -ReferenceObject $Old.DisplayName -DifferenceObject $New.DisplayName -IncludeEqual |
Where-Object {$_.SideIndicator -eq "=>"} |
Select-Object -ExpandProperty InputObject 
$results = ForEach($App in $AppsInBoth) {
    $o = $Old | Where-Object {$_.DisplayName -eq $App}
    $n = $new | Where-Object {$_.DisplayName -eq $app}
    New-Object -TypeName psobject -Property @{
        "DisplayName" = $app
        "AccountEnabled"=$n.AccountEnabled
        "ObjectId"=$n.ObjectID
        "AppId"=$n.AppId
        "AppOwnerTenantId"=$n.AppOwnerTenantId
        "AppRoleAssignmentRequired"=$n.AppRoleAssignmentRequired
        "Homepage"=$n.Homepage
        "LogoutUrl"=$n.LogoutUrl
        "PublisherName"=$n.PublisherName
  }
}
If ($results)
{
$results | select displayname,AccountEnabled,ObjectId,AppId,AppOwnerTenantId,AppRoleAssignmentRequired,Homepage,LogoutUrl,PublisherName `
| Export-CSV -Path "$dir\NewAzureADApps-$date.csv" -NoTypeInformation -Append

$NewApps=(Get-Item "$dir\NewAzureADApps*.csv" | Sort-Object LastWriteTime -Descending|Select-Object -First 1 -ExpandProperty name)
Send-MailMessage -From $From -To $To -SmtpServer "outlook.office365.com" -Subject $Subject -Body $Body -Attachments "$dir\$NewApps"
}