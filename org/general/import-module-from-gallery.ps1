param(
    [Parameter(Mandatory = $true)]
    [string]$moduleName = "Az.Accounts",
    [string]$automationAccountName = "rj-test-automation-01",
    [string]$resourceGroupName = "rj-test-runbooks-01"
)

# Adapted from https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/getting-latest-powershell-gallery-module-version
function Get-PublishedModuleVersion
{
    param(
        [string]$Name
    )
   # access the main module page
   $url = "https://www.powershellgallery.com/packages/$Name"
   $request = [System.Net.WebRequest]::Create($url)
   # do not allow to redirect. The result is a "MovedPermanently"
   $request.AllowAutoRedirect=$false
   try
   {
     # send the request
     $response = $request.GetResponse()
     # get back the URL of the true destination page, and split off the version
     $response.GetResponseHeader("Location").Split("/")[-1]
     # make sure to clean up
     $response.Close()
     $response.Dispose()
   }
   catch
   {
     Write-Error $_.Exception.Message
   }
}

# Ask PowerShellGallery for newest version
[string]$moduleVersion = Get-PublishedModuleVersion -Name $moduleName

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
        $result = Connect-AzAccount `
            -ServicePrincipal `
            -Tenant $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    }
    elseif (Get-Command "Add-AzureRmAccount" -ErrorAction SilentlyContinue) {
        $result = Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
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

if (Get-Command "New-AzAutomationModule" -ErrorAction SilentlyContinue) {
    New-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -ContentLink "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion"
} elseif (Get-Command "New-AzureRMAutomationModule" -ErrorAction SilentlyContinue) {
    New-AzureRMAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -ContentLink "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion"
}
else {
    $ErrorMessage = "No automation management module found"
    throw $ErrorMessage
}