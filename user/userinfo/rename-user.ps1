<#
  .SYNOPSIS
  Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

  .DESCRIPTION
  Rename a user or mailbox. Will not update metadata like DisplayName, GivenName, Surname.

  .PARAMETER ChangeMailnickname
  If 'true', change the mailNickname based on the new UPN

  .NOTES
  Permissions: 
  MS Graph API
  - Directory.Read.All
  - User.ReadWrite.All
  AzureAD Roles:
  - Exchange administrator
  Office 365 Exchange Online API
  - Exchange.ManageAsApp

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }, ExchangeOnlineManagement

param(
    [Parameter(Mandatory = $true)] 
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserId,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "New UserPrincipalName" } )]
    [string] $NewUpn,
    [bool] $ChangeMailnickname = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Update primary eMail address" } )]
    [bool] $UpdatePrimaryAddress = $true
    ## Currently, removing the old eMail-address "in one go" seems not to work reliably
    # [bool] $RemoveOldAddress = $false
)

try {
    Connect-RjRbGraph
    Connect-RjRbExchangeOnline

    ## Get original UPN
    # $userObject = Invoke-RjRbRestMethodGraph -resource "/users/$UserId" 

    # Change UPN
    $body = @{
        userPrincipalName = $NewUpn
    }
    Invoke-RjRbRestMethodGraph -resource "/users/$UserId" -Method Patch -Body $body | Out-Null

    # Change eMail-Adresses
    $mailbox = Get-EXOMailbox -Identity $UserId -ErrorAction SilentlyContinue
    if ($mailbox) {

        if ($ChangeMailnickname) {
            Set-Mailbox -Identity $UserId -Name $NewUpn.split('@')[0] -alias $NewUpn.split('@')[0] | Out-Null
        }

        if ($UpdatePrimaryAddress) {

            $newAdresses = New-Object System.Collections.ArrayList
            $newAdresses.Add("SMTP:$NewUpn") | Out-Null

            foreach ($address in $mailbox.EmailAddresses) {
                $prefix = $address.Split(":")[0] 
                $mail = $address.Split(":")[1]
            
                if ($prefix -eq "smtp") {
                    if ($mail -ne $NewUpn ) {
                        $newAdresses.Add($address.ToLower()) | Out-Null
                    }
                    # not smtp: not including the SIP address will automatically update it to the new default address.
                    # Updating SIP takes some minutes to propagate after rename
                }
            }
            Set-Mailbox -Identity $UserId -EmailAddresses $newAdresses | Out-Null
        }
    }
    
    "User '$UserId' successfully renamed to '$NewUpn'"
}
finally {
    Disconnect-ExchangeOnline -ErrorAction SilentlyContinue -Confirm:$true | Out-Null
}

