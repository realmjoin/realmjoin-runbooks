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
    - CloudPC.ReadWrite.All (Beta)
    - User.Read.All
    - User.SendMail (later iterations)

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName":{
                "Hide": false
            },
            "CallerName": {
                "Hide": true
            },
            "licWin365GroupName": {
                "SelectSimple": {
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB",
                    "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB": "lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB"
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
#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.6.0" }
#Requires -Modules "Microsoft.Graph.Users.Actions"

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJRbInterface -Type Graph -Entity User -DisplayName "User" } )]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -DisplayName "Cloud PC of which Windows 365 license should be reprovisioned" } )]
    [Parameter(Mandatory = $true)]
    [string] $licWin365GroupName,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)
# Logging Caller
Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

Connect-RjRbGraph

# Find the user object
$targetUser = Invoke-RjRbRestMethodGraph -Resource "/users" -OdFilter "userPrincipalName eq '$UserName'"

# Fetch the user selected license 
$licWin365GroupObj = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$licWin365GroupName'"
#$licWin365GroupObj.id

# Find which of the licenses are in use/assigned to the user
$result = Invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/members"
#$result
if ($result -and ($result.userPrincipalName -contains $UserName)) {
    $assignedLicenses = invoke-RjRbRestMethodGraph -Resource "/groups/$($licWin365GroupObj.id)/assignedLicenses"
    # If it's exactly one license, grab the Cloud PC info that is registered under this license and start reprovisioning
    if (([array]$assignedLicenses).count -eq 1) {
        $skuId = $assignedLicenses.skuId 
        $SKUs = Invoke-RjRbRestMethodGraph -Resource "/subscribedSkus" 
        $skuObj = $SKUs | Where-Object { $_.skuId -eq $skuId }
        $cloudPCs = invoke-RjRbRestMethodGraph -Resource "/deviceManagement/virtualEndpoint/cloudPCs" -Beta -OdFilter "userPrincipalName eq '$UserName'"
        $cloudPC = $cloudPCs | Where-Object { $_.servicePlanId -in $skuObj.servicePlans.servicePlanId }
        "## Starting reprovision for: " + $cloudPC.managedDeviceName + " with the service plan: " + $cloudPC.servicePlanName
        Invoke-RjRbRestMethodGraph -Resource "deviceManagement
    } 
    # if more than 1 license 
    elseif ($assignedLicenses.count -gt 1) {
        "## More than one license assigned to '$licWin365GroupName'"
    }
    # if the selected license is not applicable to the user
}
else {
    "## '$UserName' does not have '$licWin365GroupName'." 
    "## Can not reprovision."
}

#Dayana@c4a8toydaria.onmicrosoft.com
#lic - Windows 365 Enterprise - 2 vCPU 4 GB 128 GB
#lic - Windows 365 Enterprise - 2 vCPU 4 GB 256 GB
#adm.dayana.hristova@c4a8toydaria.onmicrosoft.com