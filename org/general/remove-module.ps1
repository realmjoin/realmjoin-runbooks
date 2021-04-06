param(
    [string]$moduleName = "Az.Storage",
    [string]$automationAccountName = "rj-test-automation-01",
    [string]$resourceGroupName = "rj-test-runbooks-01"
)

#Try to load Az modules IF available
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
    } elseif (Get-Command "Add-AzureRmAccount" -ErrorAction SilentlyContinue) {
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
    Remove-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -Confirm
} elseif (Get-Command "New-AzureRMAutomationModule" -ErrorAction SilentlyContinue) {
    Remove-AzureRmAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -Confirm
} else {
    $ErrorMessage = "No automation management module found"
    throw $ErrorMessage
}