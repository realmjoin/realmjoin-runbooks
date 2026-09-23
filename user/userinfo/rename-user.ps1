<#
    .SYNOPSIS
    Change this user's sign-in name (UPN) and mailbox alias

    .DESCRIPTION
    Gives this user a new user principal name in Entra ID and, optionally, updates the mailbox alias and the primary email address in Exchange Online to match. Display name, given name and surname are not touched.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER NewUpn
    New sign-in name, for example jane.doe@contoso.com.

    .PARAMETER ChangeMailnickname
    Sets the mailbox alias and name from the new user principal name.

    .PARAMETER UpdatePrimaryAddress
    Makes the new user principal name the primary email address; the previous addresses stay as aliases.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "NewUpn": {
                "DisplayName": "New user principal name"
            },
            "ChangeMailnickname": {
                "DisplayName": "Update the mailbox alias?"
            },
            "UpdatePrimaryAddress": {
                "DisplayName": "Update the primary email address?"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $NewUpn,
    [bool] $ChangeMailnickname = $true,
    [bool] $UpdatePrimaryAddress = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
    ## Currently, removing the old eMail-address "in one go" seems not to work reliably
    # [bool] $RemoveOldAddress = $false
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

"## Trying to rename a user/mailbox '$UserName'. Will not update metadata like DisplayName, GivenName, Surname."

try {
    Connect-RjRbGraph
    Connect-RjRbExchangeOnline

    ## Get original UPN
    # $userObject = Invoke-RjRbRestMethodGraph -resource "/users/$UserName"

    # Change UPN
    $body = @{
        userPrincipalName = $NewUpn
    }
    Invoke-RjRbRestMethodGraph -resource "/users/$UserName" -Method Patch -Body $body | Out-Null

    # Change eMail-Adresses
    $mailbox = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if ($mailbox) {

        if ($ChangeMailnickname) {
            Set-Mailbox -Identity $UserName -Name $NewUpn.split('@')[0] -alias $NewUpn.split('@')[0] | Out-Null
        }

        if ($UpdatePrimaryAddress) {

            $newAdresses = New-Object System.Collections.ArrayList
            $newAdresses.Add("SMTP:$NewUpn") | Out-Null

            foreach ($address in $mailbox.EmailAddresses) {
                $prefix = $address.Split(":")[0]
                $mail = $address.Split(":")[1]

                if ($prefix -notlike "sip") {
                    if ($mail -ne $NewUpn ) {
                        $newAdresses.Add($address.ToLower()) | Out-Null
                    }
                    # not smtp: not including the SIP address will automatically update it to the new default address.
                    # Updating SIP takes some minutes to propagate after rename
                }
            }
            Set-Mailbox -Identity $UserName -EmailAddresses $newAdresses | Out-Null
        }
    }

    "## User '$UserName' successfully renamed to '$NewUpn'"
}
finally {
    Disconnect-ExchangeOnline -ErrorAction SilentlyContinue -Confirm:$false | Out-Null
}

