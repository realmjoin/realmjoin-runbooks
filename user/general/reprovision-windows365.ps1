<#
 .SYNOPSIS
 Reprovision a Windows 365 Cloud PC

 .DESCRIPTION
 Reprovision an already existing Windows 365 Cloud PC without reassigning a new instance for this user.

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
        "DisplayName": "Select the Windows 365 license to be used for reprovisioning",
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
                                "fromMailAddress",
                                "customizeMail",
                                "customMailMessage"
                            ]
                        }
                    },
                    {
                        "Display": "Send an Email.",
                        "ParameterValue": true
                    }
                ]
            }
        },
    "customizeMail": {
        "DisplayName": "Would you like to customize the mail sent to the user?",
        "Select": {
            "Options": [
                {
                    "Display": "Do not customize the email.",
                    "ParameterValue": false,
                    "Customization": {
                        "Hide": [
                            "customMailMessage"
                        ]
                    }
                },
                {
                    "Display": "Customize the email.",
                    "ParameterValue": true
                }
            ]
        }
    },
    "customizeMail": {
        "DisplayName": "Would you like to customize the mail sent to the user?"
    },
    "customMailMessage": {
        "DisplayName": "Custom message to be sent to the user."
    },
    "fromMailAddress": {
        "DisplayName": "(Shared) Mailbox to send mail from: "
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

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }

param(
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    [Parameter(Mandatory = $true)]
    [string] $licWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [bool] $sendMailWhenReprovisioning = $false,
    [string] $fromMailAddress = "reports@contoso.com",
    [bool] $customizeMail = $false,
    [string] $customMailMessage = "Insert Custom Message here. (Capped at 3000 characters)",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

# Logging Caller
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

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

            if ($customizeMail) {
                $message = @{
                    subject = "[Customized Automated eMail] Cloud PC is being reprovisioned."
                    body    = @{
                        contentType = "HTML"
                        content     = $customMailMessage
                    }
                }
            }
            else {
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
            }

            $message.toRecipients = [array]@{
                emailAddress = @{
                    address = $UserName
                }
            }

            ## Check if user has a mailbox. If not do not send an email but continue the RB
            $checkMailboxExists = Invoke-RjRbRestMethodGraph -Resource "/users/$($targetUser.id)" -Method Get -OdSelect mail
            if ($null -ne $checkMailboxExists.mail) {
                Invoke-RjRbRestMethodGraph -Resource "/users/$fromMailAddress/sendMail" -Method POST -Body @{ message = $message } | Out-Null
                "## Mail to '$UserName' sent."
            }
            else {
                "## User $UserName has no mailbox. No email will be sent."
            }
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
