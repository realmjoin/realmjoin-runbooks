<#
  .SYNOPSIS
  Assign/Provision a Windows 365 instance

  .DESCRIPTION
  Assign/Provision a Windows 365 instance for this user.

  .NOTES
  Permissions:
  MS Graph (API):
  - User.Read.All
  - GroupMember.ReadWrite.All 
  - Group.ReadWrite.All
  - User.SendMail

  .INPUTS
  RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "cfgProvisioningGroupPrefix": {
                "Hide": true
            },
            "cfgUserSettingsGroupPrefix": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "sendMailWhenProvisioned": {
                "DisplayName": "Notify user once the CloudPC is done provisioning?"
            },
            "customizeMail": {
                "DisplayName": "Would you like to customize the mail sent to the user? (Works only if \"Notify user\" switch is on)",
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
            }
        }
    }

   .EXAMPLE
   "rjgit-user_general_assign-windows365": {
        "Parameters": {
            "cfgProvisioningGroupName": {
                "SelectSimple": {
                    "cfg - Windows 365 - Provisioning - Win11": "cfg - Windows 365 - Provisioning - Win11",
                    "cfg - Windows 365 - Provisioning - Win10": "cfg - Windows 365 - Provisioning - Win10"
                }
            },
            "cfgUserSettingsGroupName": {
                "SelectSimple": {
                    "cfg - Windows 365 - User Settings - restore allowed": "cfg - Windows 365 - User Settings - restore allowed",
                    "cfg - Windows 365 - User Settings - no restore": "cfg - Windows 365 - User Settings - no restore"
                }
            },
            "licWin365GroupName": {
                "SelectSimple": {
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
                }
            }
        }
    }
#>

#Requires -Modules "RealmJoin.RunbookHelper"

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User" } )]
    [String] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Provisioning Policy / FrontLine Assignment to use" } )]
    [string] $cfgProvisioningGroupName = "cfg - Windows 365 - Provisioning - Win11",
    [ValidateScript( { Use-RJInterface -DisplayName "User Settings Policy to use" } )]
    [string] $cfgUserSettingsGroupName = "cfg - Windows 365 - User Settings - restore allowed",
    [ValidateScript( { Use-RJInterface -DisplayName "Windows 365 license to assign (if not FrontLine)" } )]
    [string] $licWin365GroupName = "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
    [string] $cfgProvisioningGroupPrefix = "cfg - Windows 365 - Provisioning - ",
    [string] $cfgUserSettingsGroupPrefix = "cfg - Windows 365 - User Settings - ",
    [ValidateScript( { Use-RJInterface -DisplayName "Notify user when CloudPC is ready?" } )]
    [bool] $sendMailWhenProvisioned,
    [ValidateScript( { Use-RJInterface -DisplayName "Would you like to customize the email?" } )]
    [bool] $customizeMail = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "The custom email to be sent to the user: " } )]
    [string] $customMailMessage = "Insert Custom Message here. (Capped at 3000 characters)",
    [ValidateScript( { Use-RJInterface -DisplayName "Create a service ticket (email) if not enough licenses/FrontLine seats are available?" } )]
    [bool] $createTicketOutOfLicenses = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Where to open a service ticket (via email)" } )]
    [string] $ticketQueueAddress = "support@glueckkanja-gab.com",
    [ValidateScript( { Use-RJInterface -DisplayName "(Shared) Mailbox to send mail from" } )]
    [string] $fromMailAddress = "runbooks@contoso.com",
    [ValidateScript( { Use-RJInterface -DisplayName "Customer ID string for service tickets" } )]
    [string] $ticketCustomerId = "Contoso",
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Verify Provisioning configuration policy and test if it uses provisioningType "shared" (for Frontline Workers)
$cfgProvisioningPolObj = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/provisioningPolicies" -OdFilter "displayName eq '$cfgProvisioningGroupName'" -UriQueryRaw '$expand=assignments' -Beta

if ($cfgProvisioningPolObj -and ($cfgProvisioningPolObj[0].provisioningType -eq "shared")) {
    "## Provisioning policy '$cfgProvisioningGroupName' uses provisioning type 'shared' (FrontLine Worker)."
    # Get the shared use service plan and assignment group from the assignments object of the policy
    $cfgProvisioningGroupId = $null
    $cfgProvisioningSharedUseServicePlanId = $null
    # This will use the FIRST valid assignment - not usable for multiple sizes in one Prov. Policy
    ForEach ($assignment in $cfgProvisioningPolObj.assignments) {
        if (($assignment.target.groupId) -and ($assignment.target.servicePlanId)) {
            "## Found Assignment Group and Shared Use Service Plan for Provisioning policy '$cfgProvisioningGroupName'."
            $cfgProvisioningGroupId = $assignment.target.groupId
            $cfgProvisioningSharedUseServicePlanId = $assignment.target.servicePlanId
            break
        }
    } 
    if (-not $cfgProvisioningGroupId) {
        "## Could not find Assignment Group and Shared Use Service Plan for Provisioning policy '$cfgProvisioningGroupName'."
        throw "cfgProvisioningSharedInfo not found"
    }

    "## Get the Shared Use Service Plan object"
    $cfgProvisioningSharedUseServicePlanObj = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/sharedUseServicePlans/$cfgProvisioningSharedUseServicePlanId" -Beta
    # Check if usedCount is less than totalCount
    if ($cfgProvisioningSharedUseServicePlanObj.totalCount -le $cfgProvisioningSharedUseServicePlanObj.usedCount) {
        "## Shared Use Service Plan '$cfgProvisioningSharedUseServicePlanObj.displayName' is out of licenses."
        if ($createTicketOutOfLicenses) {
            $message = @{
                subject = "$ticketCustomerId-W365Lic '$cfgProvisioningGroupName' out of licenses/seats."
                body    = @{
                    contentType = "HTML"
                    content     = @"
            <p>This is an automated message, no reply is possible.</p>
            <p>Available seats for '$cfgProvisioningGroupName' ran out while '$CallerName' tried to request a new Win365 FrontLine Worker for '$UserName'.</p>
            <p>Please consider stocking up this license type.</p>
"@
                }
            }
            $message.toRecipients = [array]@{
                emailAddress = @{
                    address = $ticketQueueAddress
                }
            }

            Invoke-RjRbRestMethodGraph -Resource "/users/$fromMailAddress/sendMail" -Method POST -Body @{ message = $message } | Out-Null
            "## Support Request to '$ticketQueueAddress' sent."
        }
        throw "Not enough licenses"
    }

    # Get the Assignment Group object
    $cfgProvisioningGroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups/$cfgProvisioningGroupId"
    # Check if user is member of the Assignment Group
    $cfgProvisioningGroupMemberObj = Invoke-RjRbRestMethodGraph -Resource "/groups/$cfgProvisioningGroupId/members"
    $targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'"
    if ($cfgProvisioningGroupMemberObj | Where-Object { $_.id -eq $targetUser.id }) {
        "## User '$UserName' is member of Assignment Group '$cfgProvisioningGroupObj.displayName'."
    }
    else {
        $body = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
        }
        Invoke-RjRbRestMethodGraph -Resource "/groups/$cfgProvisioningGroupId/members/`$ref" -Method Post -Body $body | Out-Null
        "## Assigned '$cfgProvisioningGroupName' to '$UserName'."
        "## Cloud PC provisioning will start shortly."
    }
    $ProvPolIsDedicated = $false;
}
else {
    "## Assuming dedicated (non FrontLine) assignment."
    # Verify Provisioning configuration group
    $cfgProvisioningGroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$cfgProvisioningGroupName'"
    if (-not $cfgProvisioningGroupObj) {
        "## Could not find Provisioning policy group '$cfgProvisioningGroupName'."
        throw "cfgProvisioning not found"
    } 
    $ProvPolIsDedicated = $true;
}

# Verify User Settings configuration group
$cfgUserSettingsGroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$cfgUserSettingsGroupName'"
if (-not $cfgUserSettingsGroupObj) {
    "## Could not find User Settings policy group '$cfgUserSettingsGroupName'."
    throw "cfgUserSettings not found"
}

if ($ProvPolIsDedicated) {
    # Verify Windows 365 license group
    $licWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "DisplayName eq '$licWin365GroupName'"
    if (-not $licWin365GroupObj) {
        "## Could not find Windows 365 license group '$licWin365GroupName'."
        throw "licWin365 not found"
    }

    # Get License / SKU data
    $assignedLicenses = invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/assignedLicenses"
    $skuId = $assignedLicenses.skuId 
    $SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" 
    $skuObj = $SKUs | Where-Object { $_.skuId -eq $skuId }

    # Are licenses available?
    if ($skuObj.prepaidUnits.enabled -le $skuObj.consumedUnits) {
        "## Not enough licenses avaible to assign '$licWin365GroupName'."
        if ($createTicketOutOfLicenses) {
            $message = @{
                subject = "$ticketCustomerId-W365Lic '$licWin365GroupName' out of licenses."
                body    = @{
                    contentType = "HTML"
                    content     = @"
            <p>This is an automated message, no reply is possible.</p>
            <p>The licenses for '$licWin365GroupName' (Sku Part '$($skuObj.skuPartNumber)') ran out while '$CallerName' tried to request a new Win365 Cloud PC for '$UserName'.</p>
            <p>Please consider stocking up this license type.</p>
"@
                }
            }
            $message.toRecipients = [array]@{
                emailAddress = @{
                    address = $ticketQueueAddress
                }
            }

            Invoke-RjRbRestMethodGraph -Resource "/users/$fromMailAddress/sendMail" -Method POST -Body @{ message = $message } | Out-Null
            "## Support Request to '$ticketQueueAddress' sent."
        }
        throw "Not enough licenses. Aborting..."
    }

    $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"
    if ($result -and ($result.userPrincipalName -contains $UserName)) {
        "## '$UserName' already has a Win365 license of this type assigned." 
        "## Can not provision - exiting."
        throw "SKU already assigned."
    }
}

# Prepare for adding a group member
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'"
$body = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($targetUser.id)"
}

# Check / assign memberships of "cfg" groups.

$cfgProvisioningGroupIsAssigned = $false
$cfgUserSettingsGroupIsAssigned = $false
$licWin365GroupIsAssigned = $false

if ($ProvPolIsDedicated) {
    # Assumption: If FrontLine Policies/Groups exist they are not using the same naming/prefix. 
    $allCfgProvisioningGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgProvisioningGroupPrefix')"
    foreach ($group in $allCfgProvisioningGroups) {
        $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
        if ($result -and ($result.userPrincipalName -contains $UserName)) {
            "## '$UserName' already has a Win365 Provisioning Policy '$($group.displayName)' assigned. Skipping."
            $cfgProvisioningGroupIsAssigned = $true
        }
    }
    if (-not $cfgProvisioningGroupIsAssigned) {
        Invoke-RjRbRestMethodGraph -Resource "/groups/$($cfgProvisioningGroupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
        "## Assigned '$cfgProvisioningGroupName' to '$UserName'."
    }
}

$allCfgUserSettingsGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgUserSettingsGroupPrefix')"
foreach ($group in $allCfgUserSettingsGroups) {
    $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
    if ($result -and ($result.userPrincipalName -contains $UserName)) {
        "## '$UserName' already has a Win365 User Settings Policy '$($group.displayName)' assigned. Skipping."
        $cfgUserSettingsGroupIsAssigned = $true
    }
}

if (-not $cfgUserSettingsGroupIsAssigned) {
    Invoke-RjRbRestMethodGraph -Resource "/groups/$($cfgUserSettingsGroupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
    "## Assigned '$cfgUserSettingsGroupName' to '$UserName'."
}

# (Re-)Check assignment status before assigning license.
if ($ProvPolIsDedicated) {
    while (-not $cfgProvisioningGroupIsAssigned) {
        Start-Sleep -Seconds 15
        $allCfgProvisioningGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgProvisioningGroupPrefix')"
        foreach ($group in $allCfgProvisioningGroups) {
            $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
            if ($result -and ($result.userPrincipalName -contains $UserName)) {
                #"## Win365 Provisioning Policy '$($group.displayName)' assigned to '$UserName'."
                $cfgProvisioningGroupIsAssigned = $true
            }
        }
    } 

    while (-not $cfgUserSettingsGroupIsAssigned) {
        Start-Sleep -Seconds 15
        $allCfgUserSettingsGroups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "startswith(DisplayName,'$cfgUserSettingsGroupPrefix')"
        foreach ($group in $allCfgUserSettingsGroups) {
            $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members"
            if ($result -and ($result.userPrincipalName -contains $UserName)) {
                #"## Win365 User Settings Policy '$($group.displayName)' assigned to '$UserName'."
                $cfgUserSettingsGroupIsAssigned = $true
            }
        }
    } 

    # Assign license / Provision Cloud PC
    Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members/`$ref" -Method Post -Body $body | Out-Null
    "## Assigned '$licWin365GroupName' to '$UserName'."
    if (-not $sendMailWhenProvisioned) { 
        "## Cloud PC provisioning will start shortly."
    }
    else {
        while (-not $licWin365GroupIsAssigned) {
            Start-Sleep -Seconds 15
            $result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"
            if ($result -and ($result.userPrincipalName -contains $UserName)) {
                #"## Win365 lic group is '$($group.displayName)' assigned to '$UserName'."
                $licWin365GroupIsAssigned = $true
            }
        }
    }
}

if ($sendMailWhenProvisioned) {
    # Search Cloud PC
    $cloudPCs = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
    if ($ProvPolIsDedicated) {
        $cloudPC = $cloudPCs | Where-Object { $_.servicePlanId -in $skuObj.servicePlans.servicePlanId }
    }
    else {
        $cloudPC = $cloudPCs | Where-Object { $_.provisioningPolicyId -eq $cfgProvisioningPolObj.id }
    }
    
    "## Waiting for Cloud PC to begin provisioning."
    [int]$maxCount = 90
    [int]$count = 0
    while ((([array]$cloudPC).count -ne 1) -and ($count -lt $maxCount)) {
        $count++
        Start-Sleep -Seconds 15
        $cloudPCs = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
        if ($ProvPolIsDedicated) {
            $cloudPC = $cloudPCs | Where-Object { $_.servicePlanId -in $skuObj.servicePlans.servicePlanId }
        }
        else {
            $cloudPC = $cloudPCs | Where-Object { $_.provisioningPolicyId -eq $cfgProvisioningPolObj.id }
        }
        "."
    }

    "## Provisioning started. Waiting for Cloud PC to be ready."
    $cloudPCId = $cloudPC.id
    
    [int]$maxCount = 90
    [int]$count = 0
    do {
        $count++
        $cloudPC = Invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs/$cloudPCId" -Beta -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 60
        "."
    } while ($cloudPC.status -notin @("provisioned", "failed") -and $count -lt $maxCount)
 
    ## customizing email is switched on (true) 
    if ($customizeMail) {
        if ($cloudPC.status -eq "provisioned") {
            "## Cloud PC provisioned."
            $message = @{
                subject = "[Customized Automated eMail] Cloud PC is provisioned."
                body    = @{
                    contentType = "HTML"
                    content     = $customMailMessage
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
            "## Cloud PC provisioning failed."
            throw ("Cloud PC failed.")
        }
    }
    ## customize mail is switched off (false) => standard automated mail
    else {
        if ($cloudPC.status -eq "provisioned") {
            "## Cloud PC provisioned."
            $message = @{
                subject = "[Automated eMail] Cloud PC is provisioned."
                body    = @{
                    contentType = "HTML"
                    content     = @"
                <p>This is an automated message, no reply is possible.</p>
                <p>Your Cloud PC is ready. Access it via <a href="https://windows365.microsoft.com">windows365.microsoft.com</a>.</p>
"@
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
            "## Cloud PC provisioning failed."
            throw ("Cloud PC failed.")
        }
    }
}
