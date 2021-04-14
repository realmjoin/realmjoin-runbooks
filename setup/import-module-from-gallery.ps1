# Imports a module from PSGallery.
#
# requires the Automation Account to have variables created by the "initial setup" runbook.
#
# You can call this runbook from other runbooks via 
# Start-AutomationRunbook -Name "rjgit-setup_import-module-from-gallery" -Parameters @{"moduleName"="..."}"



param(
    [Parameter(Mandatory = $true)]
    [string]$moduleName,
    # by default the runbook will exit when deployment is started. Set this to wait for completion of the module deployment.
    [switch]$waitForDeployment
)

# Adapted from https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/getting-latest-powershell-gallery-module-version
function Get-PublishedModuleVersion {
    param(
        [string]$Name
    )
    # access the main module page
    $url = "https://www.powershellgallery.com/packages/$Name"
    $request = [System.Net.WebRequest]::Create($url)
    # do not allow to redirect. The result is a "MovedPermanently"
    $request.AllowAutoRedirect = $false
    try {
        # send the request
        $response = $request.GetResponse()
        # get back the URL of the true destination page, and split off the version
        $response.GetResponseHeader("Location").Split("/")[-1]
        # make sure to clean up
        $response.Close()
        $response.Dispose()
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

Write-Output "Querying Automation Account Name and Resource Group"
$automationAccountName = Get-AutomationVariable -name "AzAAName" -ErrorAction SilentlyContinue
$resourceGroupName = Get-AutomationVariable -name "AzAAResourceGroup" -ErrorAction SilentlyContinue

if (($null -eq $automationAccountName) -or ($null -eq $resourceGroupName)) {
    throw "Automation Account not correctly configured. Please use the `"initial setup`" runbook first."
}

Write-Output ("Ask PowerShellGallery for newest version of " + $moduleName)
[string]$moduleVersion = Get-PublishedModuleVersion -Name $moduleName
Write-Output ("Version: " + $moduleVersion)

Write-Output ("Sign in to AzureRM")
# Try to load Az modules if available
if (Get-Module -ListAvailable Az.Accounts) {
    Import-Module Az.Accounts
}
if (Get-Module -ListAvailable Az.Automation) {
    Import-Module Az.Automation
}

$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    #"Logging in to Azure..."
    if (Get-Command "Connect-AzAccount" -ErrorAction SilentlyContinue) {
        Connect-AzAccount `
            -ServicePrincipal `
            -Tenant $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
    }
    elseif (Get-Command "Add-AzureRmAccount" -ErrorAction SilentlyContinue) {
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
    }
    else {
        $ErrorMessage = "No login provider found."
        throw $ErrorMessage
    }
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Write-Output ("Importing module")
if (Get-Command "New-AzAutomationModule" -ErrorAction SilentlyContinue) {
    New-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -ContentLink "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion"
}
elseif (Get-Command "New-AzureRMAutomationModule" -ErrorAction SilentlyContinue) {
    New-AzureRMAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -ContentLink "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion"
}
else {
    $ErrorMessage = "No automation management module found"
    throw $ErrorMessage
}


if ($waitForDeployment) {
    Write-Output ("Waiting for module deployment to complete")
    $moduleState = ""
    while ($moduleState -ne "Succeeded") {
        $moduleState = (Get-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName).ProvisioningState
        if ($moduleState -eq "Failed") {
            throw "Module deployment failed"
        }
        Write-Output ("..")
        Start-Sleep 10
    }
    Write-Output ("Importing module succeeded")
}

