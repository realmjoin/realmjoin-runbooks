# This will print a list of all available InformationProtectionPolicy labels in an org.
#
# Permissions MS Graph, at least:
# - InformationProtectionPolicy.Read.All

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.5.1" }

Connect-RjRbGraph

# TODO: Currently only in preview / beta. Change when available in v1.0
$labels = Invoke-RjRbRestMethodGraph -Resource "/informationProtection/policy/labels" -Beta -ErrorAction SilentlyContinue

if (-not $labels) {
    throw "Could not read InformationProtection labels. Either missing permission, or no InformationProtection policy is set."
}

# TODO check formatting
$labels | Format-Table | Out-String