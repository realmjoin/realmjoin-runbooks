#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }, ExchangeOnlineManagement

<#
  .SYNOPSIS
  En-/Disable Out-of-office-notifications for a user/mailbox.

  .DESCRIPTION
  En-/Disable Out-of-office-notifications for a user/mailbox.

  .PARAMETER Start
  "Now" if left empty

  .PARAMETER End
  10 years into the future ("forever") if left empty

  #>

param
(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Start Date"} )]
    [datetime] $Start = (get-date),
    [ValidateScript( { Use-RJInterface -DisplayName "End Date"} )]
    [datetime] $End = ((get-date) + (new-timespan -Days 3650)),
    [ValidateScript( { Use-RJInterface -Type Textarea } )] [string] $MessageInternal,
    [ValidateScript( { Use-RJInterface -Type Textarea } )] [string] $MessageExternal,
    [ValidateScript( { Use-RJInterface -DisplayName "Disable Out-of-offce notice"} )]
    [bool] $Disable = $false,
    [string] $CallerName
    
)

$VerbosePreference = "SilentlyContinue"
try {
    Write-RjRbLog "Set Out Of Office settings initialized by '$CallerName' for '$UserName'"

    Connect-RjRbExchangeOnline

    if ($Disable) {
        Write-RjRbLog "Disable Out Of Office settings for '$UserName'"
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Disabled
    }
    else {
        Write-RjRbLog "Enabling Out Of Office settings for '$UserName'"
        Set-MailboxAutoReplyConfiguration -Identity $UserName -AutoReplyState Scheduled `
            -ExternalMessage $MessageExternal -InternalMessage $MessageInternal -StartTime $Start -EndTime $End
    }

    Write-RjRbLog "Resulting MailboxAutoReplyConfiguration for user '$UserName': $(Get-MailboxAutoReplyConfiguration $UserName | Format-List | Out-String)"

    "Successfully updated Out Of Office settings for user '$UserName'."

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null    
}

