# This rename a user object. This will not update the DisplayName, GivenName, Surname.
#
# Currently, removing the old eMail-address "in one go" seems not to work reliably
# Updating the SIP takes some minutes tp propagate
#
# Permissions: MS Graph API
# - Directory.Read.All
# - User.ReadWrite.All

#Permissons -MSGraph Directory.Read.All:Api, User.ReadWrite.All:Api -ExchangeOnline Exchange.ManageAsApp:Api -AzureADRole "Application administrator"

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }, ExchangeOnlineManagement

param(
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [Parameter(Mandatory = $true)] [string] $UserId,
    [Parameter(Mandatory = $true)] [string] $NewUpn,
    [bool] $ChangeMailnickname = $true,
    [bool] $UpdatePrimaryAddress = $true
    # [bool] $RemoveOldAddress = $false
)

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
               # not smtp: not specifying the SIP address will automatically update it.
            }
        }
        Set-Mailbox -Identity $UserId -EmailAddresses $newAdresses | Out-Null
    }
}
    
"User '$UserId' successfully renamed to '$NewUpn'"

Disconnect-ExchangeOnline -ErrorAction SilentlyContinue -Confirm:$true | Out-Null

