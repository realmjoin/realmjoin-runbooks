#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }, ExchangeOnlineManagement

<#
  .SYNOPSIS
  Performs monthly data updates (3).

  .DESCRIPTION
  The Update-Month.ps1 script updates the registry with new data generated
  during the past month and generates a report.

  .PARAMETER End
  Specifies the path to the CSV-based input file.

  .PARAMETER Message_Extern
  Specifies the name and path for the CSV-based output file. By default,
  MonthlyUpdates.ps1 generates a name from the date and time it runs, and
  saves the output in the local directory.
#>

param
(
    [Parameter(Mandatory = $true)] [string] $UserName,
    [Parameter(Mandatory = $true)] [string] $CallerName,
    [Parameter(Mandatory = $true)] [ValidateScript( { Use-RJInterface -DisplayName "Starting from" } )] [datetime] $Start,
    [Parameter(Mandatory = $true)] [datetime] $End,
    [datetime] $End2 = "2020-12-01",
    [ValidateScript( { Use-RJInterface -Type Textarea -DisplayName "Internal Reply" } )] [string] $Message_Intern,
    [ValidateScript( { Use-RJInterface -Type Textarea -Description "Reply to be sent to external senders" } )] [string] $Message_Extern = "Test nach extern",
    [switch] $Disable,
    [switch] $Disable2 = $true,
    [bool] $Test,
    [bool] $Test2 = $true
)
$VerbosePreference = "SilentlyContinue"

Write-RjRbLog "Set Out Of Office settings initialized by '$CallerName' for '$UserName'"

Connect-RjRbExchangeOnline

if ($Disable) {
    Write-RjRbLog "Disable Out Of Office settings for '$UserName'"
    Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Disabled
}
else {
    Write-RjRbLog "Enabling Out Of Office settings for '$UserName'"
    Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Scheduled `
        -ExternalMessage $Message_Extern -InternalMessage $Message_Intern -StartTime $Start -EndTime $End
}

Write-RjRbLog "Resulting MailboxAutoReplyConfiguration for user '$UserName': $(Get-MailboxAutoReplyConfiguration $UserName | Format-List | Out-String)"

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue

"Successfully updated Out Of Office settings for user '$UserName'."
