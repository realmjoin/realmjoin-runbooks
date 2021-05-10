# This will remove a module from the azure automation account.
# 
# requires the Automation Account to have variables created by the "initial setup" runbook.

param(
    [Parameter(Mandatory = $true)]
    [string]$moduleName
)

Write-Output "Querying Automation Account Name and Resource Group"
$automationAccountName = Get-AutomationVariable -name "AzAAName" -ErrorAction SilentlyContinue
$resourceGroupName = Get-AutomationVariable -name "AzAAResourceGroup" -ErrorAction SilentlyContinue

if (($null -eq $automationAccountName) -or ($null -eq $resourceGroupName)) {
    throw "Automation Account not correctly configured. Please use the `"initial setup`" runbook first."
}


#Try to load Az modules IF available
if (Get-Module -ListAvailable Az.Accounts) {
    Import-Module Az.Accounts
}
if (Get-Module -ListAvailable Az.Automation) {
    Import-Module Az.Automation
}

Write-Output ("Sign in to AzureRM")

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
    } elseif (Get-Command "Add-AzureRmAccount" -ErrorAction SilentlyContinue) {
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

Write-Output ("Removing module " + $moduleName)
if (Get-Command "New-AzAutomationModule" -ErrorAction SilentlyContinue) {
    Remove-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -Force
} elseif (Get-Command "New-AzureRMAutomationModule" -ErrorAction SilentlyContinue) {
    Remove-AzureRmAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -Force
} else {
    $ErrorMessage = "No automation management module found"
    throw $ErrorMessage
}

Write-Output ("Removal of module " + $moduleName + " succeded.")