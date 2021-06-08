# This will generate a Office 365 licensing report

#Requires -Module AzureAD, @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.0" }

Connect-RjRbAzureAD
Connect-RjRbExchangeOnline

$AllUserMailboxes = (Get-EXOMailbox -ResultSize Unlimited | Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" }).UserPrincipalName

# This report heavily uses "all users" lists. Will fetch them one time.
$allUsers = Get-AzureADUser -All:$true

# Taken from https://docs.microsoft.com/de-de/microsoft-365/enterprise/view-licensed-and-unlicensed-users-with-microsoft-365-powershell?view=o365-worldwide
$AllNoLicenseUsers = $allUsers | ForEach-Object { $licensed = $False ; For ($i = 0; $i -le ($_.AssignedLicenses | Measure-Object).Count ; $i++) { If ( [string]::IsNullOrEmpty(  $_.AssignedLicenses[$i].SkuId ) -ne $True) { $licensed = $true } } ; If ( $licensed -eq $false) { $_.UserPrincipalName } }
$AllLicensedUsers = $allUsers | ForEach-Object { $licensed = $False ; For ($i = 0; $i -le ($_.AssignedLicenses | Measure-Object).Count ; $i++) { If ( [string]::IsNullOrEmpty(  $_.AssignedLicenses[$i].SkuId ) -ne $True) { $licensed = $true } } ; If ( $licensed -eq $True) { $_.UserPrincipalName } }

$NoLicenseMailboxes = $AllUserMailboxes | Where-Object { $AllNoLicenseUsers -contains $_ }

# Get SKUs and build a lookuptable for SKU IDs
$SkuHashtable = @{}
$Skus = Get-AzureADSubscribedSku
$Skus | ForEach-Object {
    $SkuHashtable.Add($_.SkuId, $_.SkuPartNumber)
}

$DuplicateLicenseUsers = ($allUsers | Where-Object { $AllLicensedUsers -contains $_.UserPrincipalName } | Where-Object { $SkuHashtable[$_.AssignedLicenses.SkuId] -eq "ENTERPRISEPACK" -and $SkuHashtable[$_.AssignedLicenses.SkuId] -eq "EXCHANGEENTERPRISE" }).UserPrincipalName

$TotalP1 = ($Skus | Where-Object { $_.SkuPartNumber -eq "EXCHANGESTANDARD" }).PrepaidUnits.Enabled
$UsedP1 = ($Skus | Where-Object { $_.SkuPartNumber -eq "EXCHANGESTANDARD" }).ConsumedUnits
$AvailableP1 = $TotalP1 - $UsedP1

$TotalP2 = ($Skus | Where-Object { $_.SkuPartNumber -eq "EXCHANGEENTERPRISE" }).PrepaidUnits.Enabled
$UsedP2 = ($Skus | Where-Object { $_.SkuPartNumber -eq "EXCHANGEENTERPRISE" }).ConsumedUnits
$AvailableP2 = $TotalP2 - $UsedP2

$TotalE1 = ($Skus | Where-Object { $_.SkuPartNumber -eq "STANDARDPACK" }).PrepaidUnits.Enabled
$UsedE1 = ($Skus | Where-Object { $_.SkuPartNumber -eq "STANDARDPACK" }).ConsumedUnits
$AvailableE1 = $TotalE1 - $UsedE1

$TotalE3 = ($Skus | Where-Object { $_.SkuPartNumber -eq "ENTERPRISEPACK" }).PrepaidUnits.Enabled
$UsedE3 = ($Skus | Where-Object { $_.SkuPartNumber -eq "ENTERPRISEPACK" }).ConsumedUnits
$AvailableE3 = $TotalE3 - $UsedE3

$TotalCRMBasic = ($Skus | Where-Object { $_.SkuPartNumber -eq "CRMPLAN2" }).PrepaidUnits.Enabled
$UsedCRMBasic = ($Skus | Where-Object { $_.SkuPartNumber -eq "CRMPLAN2" }).ConsumedUnits
$AvailableCRMBasic = $TotalCRMBasic - $UsedCRMBasic

$TotalCRMPro = ($Skus | Where-Object { $_.SkuPartNumber -eq "CRMSTANDARD" }).PrepaidUnits.Enabled
$UsedCRMPro = ($Skus | Where-Object { $_.SkuPartNumber -eq "CRMSTANDARD" }).ConsumedUnits
$AvailableCRMPro = $TotalCRMPro - $UsedCRMPro

$TotalCRMInstance = ($Skus | Where-Object { $_.SkuPartNumber -eq "CRMINSTANCE" }).PrepaidUnits.Enabled
$UsedCRMInstance = ($Skus | Where-Object { $_.SkuPartNumber -eq "CRMINSTANCE" }).ConsumedUnits
$AvailableCRMInstance = $TotalCRMInstance - $UsedCRMInstance

$TotalBIFree = ($Skus | Where-Object { $_.SkuPartNumber -eq "POWER_BI_STANDARD" }).PrepaidUnits.Enabled
$UsedBIFree = ($Skus | Where-Object { $_.SkuPartNumber -eq "POWER_BI_STANDARD" }).ConsumedUnits
$AvailableBIFree = $TotalBIFree - $UsedBIFree

$TotalBIPro = ($Skus | Where-Object { $_.SkuPartNumber -eq "POWER_BI_PRO" }).PrepaidUnits.Enabled
$UsedBIPro = ($Skus | Where-Object { $_.SkuPartNumber -eq "POWER_BI_PRO" }).ConsumedUnits
$AvailableBIPro = $TotalBIPro - $UsedBIPro

$TotalATP = ($Skus | Where-Object { $_.SkuPartNumber -eq "ATP_ENTERPRISE" }).PrepaidUnits.Enabled
$UsedATP = ($Skus | Where-Object { $_.SkuPartNumber -eq "ATP_ENTERPRISE" }).ConsumedUnits
$AvailableATP = $TotalATP - $UsedATP

$TotalProjectEssentials = ($Skus | Where-Object { $_.SkuPartNumber -eq "PROJECTESSENTIALS" }).PrepaidUnits.Enabled
$UsedProjectEssentials = ($Skus | Where-Object { $_.SkuPartNumber -eq "PROJECTESSENTIALS" }).ConsumedUnits
$AvailableProjectEssentials = $TotalProjectEssentials - $UsedProjectEssentials

$TotalProjectPremium = ($Skus | Where-Object { $_.SkuPartNumber -eq "PROJECTPREMIUM" }).PrepaidUnits.Enabled
$UsedProjectPremium = ($Skus | Where-Object { $_.SkuPartNumber -eq "PROJECTPREMIUM" }).ConsumedUnits
$AvailableProjectPremium = $TotalProjectPremium - $UsedProjectPremium

$TotalPowerApps = ($Skus | Where-Object { $_.SkuPartNumber -eq "POWERAPPS_VIRAL" }).PrepaidUnits.Enabled
$UsedPowerApps = ($Skus | Where-Object { $_.SkuPartNumber -eq "POWERAPPS_VIRAL" }).ConsumedUnits
$AvailablePowerApps = $TotalPowerApps - $UsedPowerApps

$TotalStream = ($Skus | Where-Object { $_.SkuPartNumber -eq "STREAM" }).PrepaidUnits.Enabled
$UsedStream = ($Skus | Where-Object { $_.SkuPartNumber -eq "STREAM" }).ConsumedUnits
$AvailableStream = $TotalStream - $UsedStream

if ($NoLicenseMailboxes) {
    "Mailboxes with no license:"
    $NoLicenseMailboxes
    ""
}

if ($DuplicateLicenseUsers) {
    "Mailboxes with duplicate license:"
    $DuplicateLicenseUsers
    ""
}

"Totals of licenses we have:"
""
if ($TotalP1 -gt 0) {
    "Exchange Online Plan1:"
    "We have: $TotalP1"
    "Used: $UsedP1"
    "Available: $AvailableP1"
    ""
}

if ($TotalP2 -gt 0) {
    "Exchange Online Plan2:"
    "We have: $TotalP2"
    "Used: $UsedP2"
    "Available: $AvailableP2"
    ""
}

if ($TotalE1 -gt 0) {
    "Office365 Enterprise E1:"
    "We have: $TotalE1"
    "Used: $UsedE1"
    "Available: $AvailableE1"
    ""
}

if ($TotalE3 -gt 0) {
    "Office365 Enterprise E3:"
    "We have: $TotalE3"
    "Used: $UsedE3"
    "Available: $AvailableE3"
    ""
}

if ($TotalCRMBasic -gt 0) {
    "Microsoft Dynamics CRM Online Basic:"
    "We have: $TotalCRMBasic"
    "Used: $UsedCRMBasic"
    "Available: $AvailableCRMBasic"
    ""
}

if ($TotalCRMPro -gt 0) {
    "Microsoft Dynamics CRM Online Professional:"
    "We have: $TotalCRMPro"
    "Used: $UsedCRMPro"
    "Available: $AvailableCRMPro"
    ""
}

if ($TotalCRMInstance -gt 0) {
    "Microsoft Dynamics CRM Online Instance:"
    "We have: $TotalCRMInstance"
    "Used: $UsedCRMInstance"
    "Available: $AvailableCRMInstance"
    ""
}

if ($TotalBIFree -gt 0) {
    "Power BI (free):"
    "We have: $TotalBIFree"
    "Used: $UsedBIFree"
    "Available: $AvailableBIFree"
    ""
}

if ($TotalBIPro -gt 0) {
    "Power BI Pro:"
    "We have: $TotalBIPro"
    "Used: $UsedBIPro"
    "Available: $AvailableBIPro"
    ""
}

if ($TotalATP -gt 0) {
    "Exchange Online Advance Thread Protection:"
    "We have: $TotalATP"
    "Used: $UsedATP"
    "Available: $AvailableATP"
    ""
}

if ($TotalProjectEssentials -gt 0) {
    "Project Online Essentials:"
    "We have: $TotalProjectEssentials"
    "Used: $UsedProjectEssentials"
    "Available: $AvailableProjectEssentials"
    ""
}

if ($TotalProjectPremium -gt 0) {
    "Project Online Premium:"
    "We have: $TotalProjectPremium"
    "Used: $UsedProjectPremium"
    "Available: $AvailableProjectPremium"
    ""
}

if ($TotalPowerApps -gt 0) {
    "Microsoft Power Apps and Flow:"
    "We have: $TotalPowerApps"
    "Used: $UsedPowerApps"
    "Available: $AvailablePowerApps"
    ""
}

if ($TotalStream -gt 0) {
    "Microsoft Stream:"
    "We have: $TotalStream"
    "Used: $UsedStream"
    "Available: $AvailableStream"
    ""
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null