param(
    $moduleName = "Az.Accounts",
    $moduleVersion = "2.2.7",
    $automationAccountName = "rj-test-automation-01",
    $resourceGroupName = "rj-test-runbooks-01"
)

$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    #"Logging in to Azure..."
    if (Get-Command "Add-AzureRmAccount" -ErrorAction SilentlyContinue) {
        $result = Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    elseif (Get-Command "Connect-AzAccount" -ErrorAction SilentlyContinue) {
        #TODO: Test
        $result = Connect-AzAccount `
            -ServicePrincipal `
            -Tenant $servicePrincipalConnection.TenantId `
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

if (Get-Command "New-AzureRMAutomationModule" -ErrorAction SilentlyContinue) {
    New-AzureRMAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -ContentLink "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion"
}
elseif (Get-Command "New-AzAutomationModule" -ErrorAction SilentlyContinue) {
    New-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName -Name $moduleName -ContentLink "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion"
}
else {
    $ErrorMessage = "No automation management module found"
    throw $ErrorMessage
}