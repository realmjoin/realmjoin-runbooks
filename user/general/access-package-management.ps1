<#
  .SYNOPSIS
  Manage User Assignments to Access Packages

  .DESCRIPTION
  Manage User Assignment to Access Packages in the 'Bauprojekte' Catalog.

  .NOTES
  Permissions: 
  MS Graph (API):
  - EntitlementManagement.ReadWrite.All
  - User.Read.All
  - User.SendMail

  .INPUTS
  RunbookCustomization: {
    "Parameters": {
        "UserName" : {
            "Hide" : true
        },
        "CallerName": {
            "Hide": true
        },
        "Action" : {
            "DisplayName" : "Approve or deny the user's request: ",
            "Select" : {
                "Options" : [
                    {
                        "Display" : "Approve",
                        "ParameterValue" : true
                    },
                    {
                        "Display" : "Deny",
                        "ParameterValue" : false
                    }
                ]
            },
            "Default" : "Approve"
        },
        "sendNotificationMail": {
            "DisplayName" : "Send a notification Email to the user?",
            "Select" : {
                "Options": [
                    {
                        "Display": "Send an Email",
                        "ParameterValue": true
                    },
                    {
                        "Display": "Do not send an Email",
                        "ParameterValue": false,
                        "Customization": {
                            "Hide": [
                                "fromMailAddress"
                            ]
                        }
                    }
                ]
            }
        }
    }
  }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper" ; ModuleVersion = "0.6.0"}

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "UserName" } )]    ## Username Input
    [String] $UserName,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "The Catalog at hand: " } )]    ## Catalog Name Input
    [String] $Catalog = "Bauprojekte",
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "Approve or deny the user's request: " } )]    ## Access Package Name
    [String] $accessPackage,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "Assignment Policy: " } )]    ## Assignment Policy Name Input
    [String] $Policy,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "Approve or deny the user's request: " } )]   ## Action dropdown selector
    [bool] $Action = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "Send a notification Email to the user?" } )]  ## send email bool switch
    [bool] $sendNotificationMail = $false,
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -DisplayName "Send Email from account: " } )]  ## send email from this account
    [string] $fromMailAddress = "runbooks@contoso.com",
    [Parameter(Mandatory = $true)]  ## logging caller purely for auditing purposes
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

## Sanity checks input
##--------------start region----------------

## User
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("## User $UserName not found. Try again.")
}

## Catalog
$targetCatalog = Invoke-RjRbRestMethodGraph -Method GET -Resource "/identityGovernance/entitlementManagement/accessPackageCatalogs" -OdFilter "displayName eq '$Catalog'" -Beta
if (-not $targetCatalog) {
    throw ("## Catalog $Catalog not found. Try again.")
}

## Access Package
$targetPackage = Invoke-RjRbRestMethodGraph -Method Get -Resource "/identityGovernance/entitlementManagement/accessPackages" -OdFilter "displayName eq '$accessPackage'" -Beta
if (-not $targetPackage) {
    throw ("## Access Package $accessPackage not found in catalog. Try again.")
}

## --------------end region--------------- 


## Find the request of the User 
$requests = Invoke-RjRbRestMethodGraph -Method Get -Resource "/identityGovernance/entitlementManagement/assignmentRequests" -UriQueryRaw "`?`$expand=requestor"
foreach ($request in $requests) {
    if ($request.requestor.objectId -eq $targetUser.id) {
        "## Request found. Proceeding with action."
        $request ##delete later, just want to see output
        ##TODO: process the chosen action and send notification email if chosen.

        if ($Action) {
            "## Approving Request $($request.id) and assigning the resources of the package to User $UserName."
            ##TODO: Graph POST query to approve the request and assign the resources. Set $request.state to 

            ## Send mail?
            if ($sendNotificationMail) {
                ## Notification email Assigned
                $messageApprove = @{
                    subject = "[Automated eMail] Access Package Request Approved."
                    body    = @{
                        contentType = "HTML"
                        content     = @"
    <p>This is an automated message, no reply is possible.</p>
    <p>An Access Package has been assigned to your account to use. Check it out under <a href="https://myaccess.microsoft.com">myaccess.microsoft.com</a>.</p>
"@
                    }
                }
                ## Build the recipient params
                $messageApprove.toRecipients = [array]@{
                    emailAddress = @{
                        address = $UserName
                    }
                }
                ## Graph POST Querry to send email + Audit Log confirming email is sent
                Invoke-RjRbRestMethodGraph -Resource "/users/$fromMailAddress/sendMail" -Method POST -Body @{ message = $message } | Out-Null
                "## Mail to '$UserName' sent."
            }
        }
        else {
            "## Denying Request $($request.id) of User $UserName. "
            "## Deleting Request."

            $params = @{
                requestType = $request.requestType
                assignment  = @{
                    id = $request.id
                }
            }
            Invoke-RjRbRestMethodGraph -Resource "identityGovernance/entitlementManagement/assignmentRequests" -Method Post -Body $params

            ## Send mail?
            if ($sendNotificationMail) {
                ## Notification email Unassigned
                $messageDeny = @{
                    subject = "[Automated eMail] Access Package ."
                    body    = @{
                        contentType = "HTML"
                        content     = @"
    <p>This is an automated message, no reply is possible.</p>
    <p>Your request for the Access Package '$accessPackage' has been denied. If you think this is a mistake you can open a new request under<a href="https://myaccess.microsoft.com">myaccess.microsoft.com</a>.</p>
"@
                    }
                }
                ## Build the recipient params
                $messageDeny.toRecipients = [array]@{
                    emailAddress = @{
                        address = $UserName
                    }
                }
                ## Graph POST Querry to send email + Audit Log confirming email is sent
                Invoke-RjRbRestMethodGraph -Resource "/users/$fromMailAddress/sendMail" -Method POST -Body @{ message = $message } | Out-Null
                "## Mail to '$UserName' sent."
            }
        }
    }
    else {
        throw ("## User's Assignment Request could not be found. Double check with User if the request has been made.")
    }
}