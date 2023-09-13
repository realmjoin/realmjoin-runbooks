<#
  .SYNOPSIS
  Assign a calendar sharing policy to a user's (shared) mailbox.

  .DESCRIPTION
  Assign a calendar sharing policy to a user's (shared) mailbox E.g. to share free/busy hours.

  .NOTES
  Permissions
  Azure AD Roles
   - Exchange administrator

  .INPUTS
  RunbookCustomization: {
        "Parameters": {    
            "SharingPolicyName": {
                "Display": Name of the Calendar Sharing Policy
            },
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.1" }, @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.2.0" }

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

try{
    Connect-RjRbExchangeOnline

    ## Check the mailbox exists
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if ($null -eq $user.PrimarySmtpAddress) {
        throw "Mailbox for user $UserName does not exist."
    }

    ## Check policy exists / is spelled correctly
    "## Checking the requested policy exists... ##"
    try {
        $policy = Get-SharingPolicy -Identity $SharingPolicyName

        "Policy found. Assigning to (shared) Mailbox..."
    }
    catch {
        throw "## Sharing policy '$SharingPolicyName' does not exist. Check spelling and try again. ##" 
    }

    ## Assign the wanted policy
    try {
        Set-Mailbox -Identity $user.UserPrincipalName -SharingPolicy $policy.Name

        ## double checking the policy was successfully assigned
        $check = Get-Mailbox -Identity $user.UserPrincipalName | Select-Object SharingPolicy
        if($policy.Name -eq $check.SharingPolicy){
            "## Assignment successful."
        }
    }
    catch {
        throw "## Assignment failed. Aborting... ##"
    } 

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}