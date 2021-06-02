# This rename a user object
#
# Permissions: MS Graph API
# - Directory.Read.All
# - User.ReadWrite.All

## TODO: Change IM Alias?

#Permissons -MSGraph Directory.Read.All:Api, User.ReadWrite.All:Api -ExchangeOnline Exchange.ManageAsApp:Api -AzureADRole "Application administrator"

#Requires -Module @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }, MEMPSToolkit

param(
    # needs to be prefixed with "http://" / "https://"
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User } )]
    [Parameter(Mandatory = $true)] [string] $UserId,
    [Parameter(Mandatory = $true)] [string] $NewUsername,
    [bool] $SetMailnickname = $true,
    [bool] $RemoveOldMail = $false
)

Connect-RjRbGraph
Connect-RjRbExchangeOnline

# Get original UPN
$userObject = Invoke-RjRbRestMethodGraph -resource "/users/$UserId" 

## Check if desired name is available
## Skip for now - rename will fail gracefully
#$otherUser = Invoke-RjRbRestMethodGraph -resource "/users/$NewUsername" -ErrorAction SilentlyContinue
#if ($otherUser) {
#    throw "Username '$NewUsername' is already taken"
#}

$body = @{
    userPrincipalName = $NewUsername
}

# Change UPN
Invoke-RjRbRestMethodGraph -resource "/users/$UserId" -Method Patch -Body $body

# Get User / Mailbox
$mailbox = Get-EXOMailbox -Identity $UserId -ErrorAction SilentlyContinue
if ($mailbox) {

    if ($SetMailnickname) {
        Set-Mailbox -Identity $mailbox.Identity -Name $NewUsername.split('@')[0] -alias $NewUsername.split('@')[0]
    }

    # Update
    $mailbox = Get-EXOMailbox -Identity $UserId -ErrorAction SilentlyContinue
    
    if ($RemoveOldMail) {
        if ($mailbox.EmailAddresses -icontains "smtp:$($userObject.UserPrincipalName)") {
            # Remove email address
            Set-Mailbox -Identity $mailbox.Identity -EmailAddresses @{remove = "$($userObject.UserPrincipalName)" }
        }
    }
}
    
"User '$UserId' successfully renamed to '$NewUsername'"

Disconnect-ExchangeOnline -ErrorAction SilentlyContinue -Confirm:$true | Out-Null

