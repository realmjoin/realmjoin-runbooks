<#
 .SYNOPSIS
 Reprovision a Windows 365 Cloud PC

 .DESCRIPTION
 Reprovision an already existing Windows 365 Cloud PC without reassigning a new instance for this user.

 .NOTES
 Permissions:
 MS Graph (API):
 - GroupMember.ReadWrite.All 
 - Group.ReadWrite.All
 - Directory.Read.All
 - CloudPC.ReadWrite.All (Beta)
 - User.Read.All
 - User.SendMail

 .INPUTS
 RunbookCustomization: {
 "Parameters": {
    "UserName": {
        "Hide": true
    },
    "CallerName": {
        "Hide": true
    },
    "licWin365GroupName": {
        "SelectSimple": {
            "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
            "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
        }
    },
    "sendMailWhenReprovisioning": {
            "DisplayName": "Notify user when CloudPC reprovisioning has begun?",
            "Select": {
                "Options": [
                    {
                        "Display": "Do not send an Email.",
                        "ParameterValue": false,
                        "Customization": {
                            "Hide": [
                                "fromMailAddress"
                            ]
                        }
                    },
                    {
                        "Display": "Send an Email.",
                        "ParameterValue": true
                    }
                ]
            }
        }
    }
 }
 
 .EXAMPLE
 "user_general_reprovision-windows365": {
    "Parameters": {
        "licWin365GroupName": {
            "SelectSimple": {
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
            }
        }
    }
 }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.3" }

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJRbInterface -Type Graph -Entity User -DisplayName "User" } )]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "The to-be-reprovisioned Cloud PC uses the following Windows365 license: " } )]
    [Parameter(Mandatory = $true)]
    [string] $licWin365GroupName="lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [bool] $sendMailWhenReprovisioning = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "(Shared) Mailbox to send mail from: " } )]
    [string] $fromMailAddress = "reports@contoso.com",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

# Logging Caller
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# User exists?
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'" -ErrorAction SilentlyContinue
if (-not $targetUser) {
    throw ("User $UserName not found.")
}

# Fetch the user selected license 
$licWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$licWin365GroupName'"

# Find which of the licenses are in use/assigned to the user
$result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"

if ($result -and ($result.userPrincipalName -contains $UserName)) {
    $assignedLicenses = invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/assignedLicenses"
    # If it's exactly one license, grab the Cloud PC info that is registered under this license and start reprovisioning
    if (([array]$assignedLicenses).count -eq 1) {
        $skuId = $assignedLicenses.skuId 
        $SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" 
        $skuObj = $SKUs | Where-Object { $_.skuId -eq $skuId }
        $cloudPCs = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
        $cloudPC = $cloudPCs | Where-Object { $_.servicePlanId -in $skuObj.servicePlans.servicePlanId }

        # body of reprovision request
        $body = @{}
        
        "## Starting reprovision for: " + $cloudPC.managedDeviceName + " with the service plan: " + $cloudPC.servicePlanName
        Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs/$($cloudPC.id)/reprovision" -Beta -Method Post -Body $body
        
        # check if "Notify user when CloudPC reprovisioning has begun?" switch has been set to true and send email to the User
        if ($sendMailWhenReprovisioning) {
            "## Cloud PC Reprovisioning has been triggered. Informing User."
            $message = @{
                subject = "[Automated eMail] Cloud PC is being reprovisioned."
                body    = @{
                    contentType = "HTML"
                    content     = @"
                <p>This is an automated message, no reply is possible.</p>
                <p>Your Cloud PC is being reprovisioned and will be unavailable for the next ~hour, please plan accordingly. The Cloud PC will be accessible shortly after the process has finished.</p>
                <p>You can then access it via <a href="https://windows365.microsoft.com">windows365.microsoft.com</a>.</p>
"@
                }
            }
    
            $message.toRecipients = [array]@{
                emailAddress = @{
                    address = $UserName
                }
            }
    
            Invoke-RjRbRestMethodGraph -Resource "/users/$fromMailAddress/sendMail" -Method POST -Body @{ message = $message } | Out-Null
            "## Mail to '$UserName' sent."
        }
        else {
            "## User has chosen not to send Mail to '$UserName'. " 
        }
    } 
    # if more than 1 license 
    elseif ($assignedLicenses.count -gt 1) {
        "## More than one license assigned to '$licWin365GroupName'. Taking no action."
        throw "Multiple Licenses assigned to group."
    }
    # if the selected license is not applicable to the user
}
else {
    "## '$UserName' does not have '$licWin365GroupName'." 
    "## Can not reprovision."
    throw "Wrong license selected."
}
