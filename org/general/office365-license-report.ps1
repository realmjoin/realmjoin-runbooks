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

### newly added

# "Microsoft Defender For Endpoint"
$TotalMDATPXPLAT = ($Skus | Where-Object { $_.SkuPartNumber -eq "MDATP_XPLAT" }).PrepaidUnits.Enabled
$UsedMDATPXPLAT = ($Skus | Where-Object { $_.SkuPartNumber -eq "MDATP_XPLAT" }).ConsumedUnits
$AvailableMDATPXPLAT = $TotalMDATPXPLAT - $UsedMDATPXPLAT

# "Microsoft 365 E5 Security"
$TotalE5Sec = ($Skus | Where-Object { $_.SkuPartNumber -eq "IDENTITY_THREAT_PROTECTION" }).PrepaidUnits.Enabled
$UsedE5Sec = ($Skus | Where-Object { $_.SkuPartNumber -eq "IDENTITY_THREAT_PROTECTION" }).ConsumedUnits
$AvailableE5Sec = $TotalE5Sec - $UsedE5Sec

# "Microsoft 365 Phone System"
$TotalMCOEV = ($Skus | Where-Object { $_.SkuPartNumber -eq "MCOEV" }).PrepaidUnits.Enabled
$UsedMCOEV = ($Skus | Where-Object { $_.SkuPartNumber -eq "MCOEV" }).ConsumedUnits
$AvailableMCOEV = $TotalMCOEV - $UsedMCOEV

# Teams Meeting Room
$TotalMEETING_ROOM = ($Skus | Where-Object { $_.SkuPartNumber -eq "MEETING_ROOM" }).PrepaidUnits.Enabled
$UsedMEETING_ROOM = ($Skus | Where-Object { $_.SkuPartNumber -eq "MEETING_ROOM" }).ConsumedUnits
$AvailableMEETING_ROOM = $TotalMEETING_ROOM - $UsedMEETING_ROOM

# "Microsoft 365 Business Standard"
$TotalO365BS = ($Skus | Where-Object { $_.SkuPartNumber -eq "O365_BUSINESS_PREMIUM" }).PrepaidUnits.Enabled
$UsedO365BS = ($Skus | Where-Object { $_.SkuPartNumber -eq "O365_BUSINESS_PREMIUM" }).ConsumedUnits
$AvailableO365BS = $TotalO365BS - $UsedO365BS

# "Audioconferencing in Microsoft 365"
$TotalMCOMEETADV = ($Skus | Where-Object { $_.SkuPartNumber -eq "MCOMEETADV" }).PrepaidUnits.Enabled
$UsedMCOMEETADV = ($Skus | Where-Object { $_.SkuPartNumber -eq "MCOMEETADV" }).ConsumedUnits
$AvailableMCOMEETADV = $TotalMCOMEETADV - $UsedMCOMEETADV

# "Microsoft 365 E3"
$TotalSPE_E3 = ($Skus | Where-Object { $_.SkuPartNumber -eq "SPE_E3" }).PrepaidUnits.Enabled
$UsedSPE_E3 = ($Skus | Where-Object { $_.SkuPartNumber -eq "SPE_E3" }).ConsumedUnits
$AvailableSPE_E3 = $TotalSPE_E3 - $UsedSPE_E3

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

if ($TotalO365BS -gt 0) {
    "Microsoft 365 Business Standard:"
    "We have: $TotalO365BS"
    "Used: $UsedO365BS"
    "Available: $AvailableO365BS"
    ""
}

if ($TotalSPE_E3 -gt 0) {
    "Microsoft 365 E3"
    "We have: $TotalSPE_E3"
    "Used: $UsedSPE_E3"
    "Available: $AvailableSPE_E3"
    ""
}

if ($TotalE5Sec -gt 0) {
    "Microsoft 365 E5 Security"
    "We have: $TotalE5Sec"
    "Used: $UsedE5Sec"
    "Available: $AvailableE5Sec"
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

if ($TotalMDATPXPLAT -gt 0) {
    "Microsoft Defender For Endpoint:"
    "We have: $TotalMDATPXPLAT"
    "Used: $UsedMDATPXPLAT"
    "Available: $AvailableMDATPXPLAT"
    ""
}

if ($TotalMCOEV -gt 0) {
    "Microsoft 365 Phone System:"
    "We have: $TotalMCOEV"
    "Used: $UsedMCOEV"
    "Available: $AvailableMCOEV"
    ""
}

if ($TotalMEETING_ROOM -gt 0) {
    "Teams Meeting Room:"
    "We have: $TotalMEETING_ROOM"
    "Used: $UsedMEETING_ROOM"
    "Available: $AvailableMEETING_ROOM"
    ""
}

if ($TotalMCOMEETADV -gt 0) {
    "Audioconferencing in Microsoft 365:"
    "We have: $TotalMCOMEETADV"
    "Used: $UsedMCOMEETADV"
    "Available: $AvailableMCOMEETADV"
    ""
}

Disconnect-ExchangeOnline -Confirm:$false | Out-Null