# Set initial configs in the Azure Automation Account
# - Add ClientSecret to AzureRunasAccount, store in Automation Account
# - Add Variables to Automation Account, to enable automatic module import.
#
# Implements https://dev.azure.com/c4a8/GKGAB%20Managed%20Services/_workitems/edit/779

param(
    [Parameter(Mandatory = $true)]
    [string]$automationAccountName,
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupName
)

$connectionName = "AzureRunAsConnection"

#region Add Variables to enable module management

Write-Output "Sign in to AzureRM"
# Try to load Az modules if available
if (Get-Module -ListAvailable Az.Accounts) {
    Import-Module Az.Accounts
}
if (Get-Module -ListAvailable Az.Automation) {
    Import-Module Az.Automation
}

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

Write-Output "Querying Variable AzAAResourceGroup..."
$result = Get-AutomationVariable -Name "AzAAResourceGroup" -ErrorAction SilentlyContinue

if ($null -eq $result) {
    Write-Output "Setting AzAAResourceGroup..."
    if (Get-Command "New-AzAutomationVariable") {
        New-AzAutomationVariable -Name "AzAAResourceGroup" -Encrypted $false -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue | Out-Null
        Set-AzAutomationVariable -Name "AzAAResourceGroup" -Encrypted $false -Value $resourceGroupName -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue
        Write-Output ""
    }
    else {
        if (Get-Command "New-AzureRMAutomationVariable") {
            New-AzureRMAutomationVariable -Name "AzAAResourceGroup" -Encrypted $false -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue | Out-Null
            Set-AzureRMAutomationVariable -Name "AzAAResourceGroup" -Encrypted $false -Value $resourceGroupName -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue
            Write-Output ""
        }
        else {
            throw "No Automation provider found. Install Az.Automation module."
        }
    }
}

Write-Output "Querying Variable AzAAName..."
$result = Get-AutomationVariable -Name "AzAAName" -ErrorAction SilentlyContinue

if ($null -eq $result) {
    Write-Output "Setting AzAAName..."
    if (Get-Command "New-AzAutomationVariable") {
        New-AzAutomationVariable -Name "AzAAName" -ResourceGroupName $resourceGroupName -Encrypted $false -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue | Out-Null
        Set-AzAutomationVariable -Name "AzAAName" -Encrypted $false -Value $automationAccountName -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue
        Write-Output ""
    }
    else {
        if (Get-Command "New-AzureRMAutomationVariable") {
            New-AzureRMAutomationVariable -Name "AzAAName" -ResourceGroupName $resourceGroupName -Encrypted $false -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue | Out-Null
            Set-AzureRMAutomationVariable -Name "AzAAName" -Encrypted $false -Value $automationAccountName -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ErrorAction SilentlyContinue
            Write-Output ""
        }
        else {
            throw "No Automation provider found. Install Az.Automation module."
        }
    }
}

#region Add ClientSecret
#endregion