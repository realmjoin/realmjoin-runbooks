<#
  .SYNOPSIS
  Create a room resource.

  .DESCRIPTION
  Create a room resource.

  .NOTES
  Permissions given to the Az Automation RunAs Account:
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "CallerName": {
                "Hide": true
            }
        }
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }, ExchangeOnlineManagement

param (
    [Parameter(Mandatory = $true)] 
    [string] $MailboxName,
    [string] $DisplayName,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Custom domain suffix (will use standard domain if left unfilled)" } )]
    [string] $customDomain,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $DelegateTo,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Room capacity (people)" } )]
    [int] $Capacity,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Automatically accept meeting requests" } )]
    [bool] $AutoAccept = $false,
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Automatically map mailbox in Outlook" } )]
    [bool] $AutoMapping = $false,
    # CallerName is tracked purely for auditing purposes
    [ValidateScript( { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; Use-RJInterface -DisplayName "Disable AAD User" } )]
    [bool] $DisableUser = $true,
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

try {
    Connect-RjRbGraph
    Connect-RjRbExchangeOnline

    $invokeParams = @{
        Name  = $MailboxName
        Alias = $MailboxName
        Room  = $true
    }

    if ($DisplayName) {
        $invokeParams += @{ DisplayName = $DisplayName }
    }

    if ($Capacity -and ($Capacity -gt 0)) {
        $invokeParams += @{ ResourceCapacity = $Capacity }
    }

    ## check if the input contains a @, if so, split and keep the pure domain part
    if ($customDomain -like "*@*") {
        $customDomain = $customDomain.Split("@")[1] 
    }

    ## fetch all domains and check if the custom domain is present in the tenant
    $domains = Invoke-RjRbRestMethodGraph -Resource "/domains" -Method Get -OdSelect "id, supportedServices, isDefault" -ErrorAction Stop
    $found = $false
    $defaultDomain = ""
    foreach ($domain in $domains) {
        if ($domain.isDefault -eq $true) {
            $defaultDomain = $domain.id
        }
        if ($domain.supportedServices -contains "Email" -and $customDomain) {
            if ($domain.id -eq $customDomain) {
                $invokeParams.Name = $MailboxName + "@" + $customDomain
                $found = $true
                break
            }
        }
    }
    if (-not $found) {
        Write-Output "## Custom domain '$customDomain' not found in tenant, using default domain."
        $invokeParams.Name = $MailboxName + "@" + $defaultDomain
    }

    # Create the mailbox
    $mailbox = New-Mailbox @invokeParams

    $found = $false
    while (-not $found) {
        $mailbox = Get-Mailbox -Identity $MailboxName -ErrorAction SilentlyContinue
        if ($null -eq $mailbox) {
            ".. Waiting for mailbox to be created..."
            Start-Sleep -Seconds 5
        }
        else {
            $found = $true
        }
    } 

    if ($DelegateTo) {
        # "Grant SendOnBehalf"
        $mailbox | Set-Mailbox -GrantSendOnBehalfTo $DelegateTo | Out-Null
        # "Grant FullAccess"
        $mailbox | Add-MailboxPermission -User $DelegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false | Out-Null
        # Calendar delegation
        Set-CalendarProcessing -Identity $MailboxName -ResourceDelegates $DelegateTo -AutomateProcessing AutoAccept -AllRequestInPolicy $true -AllBookInPolicy $false
    }

    if ($AutoAccept) {
        Set-CalendarProcessing -Identity $MailboxName -AutomateProcessing "AutoAccept" -AllRequestInPolicy $true -AllBookInPolicy $true
    }

    if ($DisableUser) {
        # Deactive the user account using the Graph API
        $user = $null
        $retryCount = 0
        while (($null -eq $user) -and ($retryCount -lt 10)) {
            $user = Invoke-RjRbRestMethodGraph -Resource "/users" -Method Get -OdFilter "mailNickname eq '$MailboxName'" -ErrorAction Stop
            if ($null -eq $user) {
                $retryCount++
                ".. Waiting for user object to be created..."
                Start-Sleep -Seconds 5
            }
        }
        $body = @{
            accountEnabled = $false
        }
        Invoke-RjRbRestMethodGraph -Resource "/users/$($user.id)" -Method Patch -Body $body -ErrorAction Stop
    }

    "## Room Mailbox '$MailboxName' has been created."

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}