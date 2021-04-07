# This runbook will create a copy of a configuration policy (old style "configuration profiles", not newew "configuration settings") and append " - Copy" to the name of the new policy.
# This will currently not copy the device/user assignments. This is intentional, so you can tweak the policy before applying it.
# Problems: This version uses "v1.0" endpoints of graph api. These are stable but incomplete. Some profiles will only work with "beta".
#
# Assumptions: The automations creds in "realmjoin-automation-cred" correlate to an AppRegsitration and are able to sign in to MS Graph and have the following permissions:
# ...

param(
    [string]$automationCredsName = "realmjoin-automation-cred",
    [string]$configPolicyID = ""
)

$connectionName = "AzureRunAsConnection"

#region MEMPSToolkit

# Functions taken from https://github.com/hcoberdalhoff/MEMPSToolkit
# TODO: Turn the toolkit into a module instead of having local version of the functions.

# Authenticate non-interactively against a service principal / app registration with app permissions. 
# Can be used headless, no libraries needed. Recommended. 
function Get-AppLoginToken {
    param (
        $resource = "https://graph.microsoft.com",
        $tenant = "",
        $clientId = "",
        $secretValue = ""
    )

    $LoginRequestParams = @{
        Method = 'POST'
        Uri    = "https://login.microsoftonline.com/" + $tenant + "/oauth2/token?api-version=1.0"
        Body   = @{ 
            grant_type    = "client_credentials"; 
            resource      = $resource; 
            client_id     = $clientId; 
            client_secret = $secretValue 
        }
    }

    try {
        $result = Invoke-RestMethod @LoginRequestParams
    }
    catch {
        Write-Error $_.Exception
        throw "Login with MS Graph API failed. See Error Log."
    }
    
    return @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer " + $result.access_token
        'ExpiresOn'     = $result.expires_on
    }

}

# Use credentials stored in the Azure Automation Account to authenticate against MS Graph API
function Get-AzAutomationCredLoginToken {
    param (
        $resource = "https://graph.microsoft.com",
        $tenant = "",
        $automationCredName = "realmjoin-automation-cred"
    )

    $cred = Get-AutomationPSCredential -Name $automationCredName
    $clientId = $cred.UserName
    $secrectValue = [System.Net.NetworkCredential]::new('', $cred.Password).Password

    return (Get-AppLoginToken -resource $resource -tenant $tenant -clientId $clientId -secretValue $secrectValue)
}

# Standardize Graph API calls / Trigger a REST-Call against MS Graph API and return the result 
function Execute-GraphRestRequest {
    param (
        $method = "GET",
        $prefix = "https://graph.microsoft.com/v1.0/",
        $resource = "deviceManagement/deviceCompliancePolicies",
        $body = $null,
        $authToken = $null,
        $onlyValues = $true,
        $writeToFile = $false,
        $outFile = "default.file"
    )
    
    if ($null -eq $authToken) {
        $authToken = Load-AppLoginToken
        if ($null -eq $authToken) {
            "Please provide an authentication token. You can use Get-DeviceLoginToken to acquire one."
            return
        }
    }

    try {
        if ($writeToFile) {
            $result = Invoke-RestMethod -Uri ($prefix + $resource) -Headers $authToken -Method $method -Body $body -ContentType "application/json" -OutFile $outfile
        }
        else {
            $result = Invoke-RestMethod -Uri ($prefix + $resource) -Headers $authToken -Method $method -Body $body -ContentType "application/json"
        }
    }
    catch {
        Write-Error $_.Exception
        Write-Error ("Method: " + $method)
        Write-Error ("Prefix: " + $prefix)
        Write-Error ("Resource: " + $resource)
        Write-Error ("Body: " + $body)
        throw "Executing Graph Rest Call failed. See Error Log."
    }

    if ($onlyValues) {
        return $result.Value
    }
    else {
        return $result
    }
}
# Import/Create a new Device Configuration Policy
# v1.0 prefix is stable but incomplete. beta seems complete but unstable. *meh*
function Add-DeviceConfiguration {
    param(
        $authToken = $null,
        $prefix = "https://graph.microsoft.com/v1.0/",
        $config = $null
    )
    
    $resource = "deviceManagement/deviceConfigurations"
    
    if ($null -eq $config) {
        "Please provide a Device Configuration. You can create those using Import-PolicyObject."
        return
    }
    
    $config = $config | Select-Object -Property * -ExcludeProperty id, createdDateTime, lastModifiedDateTime, version
    
    $JSON = $config | ConvertTo-Json -Depth 6
    
    Execute-GraphRestRequest -authToken $authToken -prefix $prefix -resource $resource -method "POST" -body $JSON -onlyValues $false
    
}

# Get/Fetch all existing Device Configuration Policies (not Config Settings)
# v1.0 prefix is stable but incomplete. beta seems complete but unstable. *meh*
function Get-DeviceConfigurations {
    param(
        $authToken = $null,
        $prefix = "https://graph.microsoft.com/v1.0/"
    )
    
    $resource = "deviceManagement/deviceConfigurations"
    
    Execute-GraphRestRequest -authToken $authToken -prefix $prefix -resource $resource -method "GET"
    
}
    

# Get/Fetch an existing Device Configuration Policy by its ID (not Config Settings)
# v1.0 prefix is stable but incomplete. beta seems complete but unstable. *meh*
function Get-DeviceConfigurationById {
    param(
        $authToken = $null,
        $prefix = "https://graph.microsoft.com/v1.0/",
        $configId = ""
    )
    
    $resource = "deviceManagement/deviceConfigurations"
    
    if ($configId -eq "") {
        "Please provide an Device Configuration UID. You can get those from the results from Get-DeviceConfigurations"
        return
    }
    
    Execute-GraphRestRequest -authToken $authToken -prefix $prefix -resource ($resource + "/" + $configId) -method "GET" -onlyValues $false
    
}

#endregion

Write-Output "Get Azure Automation Connection..."
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

Write-Output "Connect to Graph API..."
$token = Get-AzAutomationCredLoginToken -tenant $servicePrincipalConnection.TenantId -automationCredName $automationCredsName

Write-Output ("Fetch policy " + $configPolicyID)
$confpol = Get-DeviceConfigurationById -authToken $token -configId $configPolicyID

Write-Output ("New name: " + $confpol.displayName + " - Copy")
$confpol.displayName = ($confpol.displayName + " - Copy")

Write-Output ("Fetch all policies, check I will create no conflict...")
$allPols = Get-DeviceConfigurations -authToken $token
if ($null -ne ($allPols | Where-Object { $_.displayName -eq $confpol.displayName })) { 
    throw ("Target Policyname `"" + $confpol.displayName + "`" already exists.")
 } 

Write-Output ("Import new policy")
Add-DeviceConfiguration -authToken $token -config $confpol | Out-Null
