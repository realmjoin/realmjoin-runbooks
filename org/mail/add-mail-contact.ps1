<#
	.SYNOPSIS
	Create a mail contact for an external address

	.DESCRIPTION
	Creates a mail contact in Exchange Online for an external email address, so the person can be found in the address book and added to groups. First name, last name, contact name and alias are optional; the contact can be hidden from the address lists.

	.PARAMETER ExternalEmailAddress
	External address of the person. Mail to the contact is delivered there.

	.PARAMETER DisplayName
	Name shown in the address book.

	.PARAMETER Name
	Unique name used to manage the contact in Exchange Online. Leave empty to use the display name.

	.PARAMETER FirstName
	First name of the person. Can stay empty.

	.PARAMETER LastName
	Last name of the person. Can stay empty.

	.PARAMETER Alias
	Mail alias of the contact. Leave empty to have Exchange derive one from the contact name.

	.PARAMETER HideFromAddressLists
	Hides the contact from the global address list and the other address lists.

	.PARAMETER CallerName
	Name of the user who started the runbook. Set by the portal and recorded for auditing.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"ExternalEmailAddress": {
				"DisplayName": "External email address"
			},
			"DisplayName": {
				"DisplayName": "Display name"
			},
			"Name": {
				"DisplayName": "Contact name"
			},
			"FirstName": {
				"DisplayName": "First name"
			},
			"LastName": {
				"DisplayName": "Last name"
			},
			"Alias": {
				"DisplayName": "Alias"
			},
			"HideFromAddressLists": {
				"DisplayName": "Hide from address lists?"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param (
    [Parameter(Mandatory = $true)]
    [string]$ExternalEmailAddress,

    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [string]$Name = "",

    [string]$FirstName = "",

    [string]$LastName = "",

    [string]$Alias = "",

    [bool]$HideFromAddressLists = $false,

    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string]$CallerName
)

########################################################
#region     RJ Log Part
########################################################

if ($CallerName) {
    Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose
}

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose
Write-RjRbLog -Message "ExternalEmailAddress: $ExternalEmailAddress" -Verbose
Write-RjRbLog -Message "DisplayName: $DisplayName" -Verbose
Write-RjRbLog -Message "Name: $Name" -Verbose
Write-RjRbLog -Message "FirstName: $FirstName" -Verbose
Write-RjRbLog -Message "LastName: $LastName" -Verbose
Write-RjRbLog -Message "Alias: $Alias" -Verbose
Write-RjRbLog -Message "HideFromAddressLists: $HideFromAddressLists" -Verbose

#endregion

########################################################
#region     Parameter Validation
########################################################

# Default the unique contact name to the display name when none was supplied
if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = $DisplayName
}

# Basic SMTP format validation for the external email address.
# Exchange rejects malformed addresses with an unhelpful error, so fail early and clearly.
if ($ExternalEmailAddress -notmatch "^[^@\s]+@[^@\s]+\.[^@\s]+$") {
    Write-Error "The external email address '$ExternalEmailAddress' is not a valid SMTP address. Provide an address in the format 'user@domain.com'." -ErrorAction Continue
    throw "Invalid external email address format: '$ExternalEmailAddress'"
}

#endregion

########################################################
#region     Connect Part
########################################################

Write-Output "Connecting to Exchange Online..."
try {
    Connect-RjRbExchangeOnline -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Exchange Online: $($_.Exception.Message). Ensure the managed identity has the required Exchange Online permissions." -ErrorAction Continue
    throw
}

#endregion

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Preflight-Check"
Write-Output "---------------------"

# Check whether a mail contact with the same external email address already exists.
# Duplicate contacts cause New-MailContact to fail with an unhelpful error, so abort
# before attempting to create anything.
Write-Output "Checking for an existing mail contact with external email address '$ExternalEmailAddress'..."
$StatusQuoByEmail = $null
try {
    $StatusQuoByEmail = Get-MailContact -Filter "ExternalEmailAddress -eq 'SMTP:$ExternalEmailAddress'" -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Get-MailContact (by email) encountered an error: $($_.Exception.Message)"
}

if ($StatusQuoByEmail) {
    Write-Error "A mail contact with external email address '$ExternalEmailAddress' already exists (DisplayName: '$($StatusQuoByEmail.DisplayName)', Alias: '$($StatusQuoByEmail.Alias)'). Remove or update the existing contact instead of creating a duplicate." -ErrorAction Continue
    throw "Duplicate mail contact detected for external email address '$ExternalEmailAddress'"
}
Write-Output "No existing mail contact found for that external email address."

# If an alias was provided, also verify no existing recipient (mailbox, contact, group, etc.)
# already owns that alias - Exchange enforces alias uniqueness across all recipient types.
if ($Alias -notlike "") {
    Write-Output "Checking for an existing recipient with alias '$Alias'..."
    $StatusQuoByAlias = $null
    try {
        $StatusQuoByAlias = Get-Recipient -Filter "Alias -eq '$Alias'" -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Get-Recipient (by alias) encountered an error: $($_.Exception.Message)"
    }

    if ($StatusQuoByAlias) {
        Write-Error "A recipient with alias '$Alias' already exists (DisplayName: '$($StatusQuoByAlias.DisplayName)', RecipientType: '$($StatusQuoByAlias.RecipientType)'). Aliases must be unique across all Exchange Online recipients. Choose a different alias." -ErrorAction Continue
        throw "Alias '$Alias' is already in use by an existing recipient"
    }
    Write-Output "Alias '$Alias' is available."
}

# Check for an existing mail contact with that exact name (Name is always set after Parameter Validation).
Write-Output "Checking for an existing mail contact with name '$Name'..."
$StatusQuoByName = $null
try {
    $StatusQuoByName = Get-MailContact -Identity $Name -ErrorAction SilentlyContinue
}
catch {
    $StatusQuoByName = $null
}

if ($StatusQuoByName) {
    Write-Error "A mail contact with the name '$Name' already exists (ExternalEmailAddress: '$($StatusQuoByName.ExternalEmailAddress)', Alias: '$($StatusQuoByName.Alias)'). Each mail contact must have a unique name. Choose a different Name." -ErrorAction Continue
    throw "A mail contact named '$Name' already exists"
}
Write-Output "Name '$Name' is available."

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"
Write-Output "No mail contact exists for external email address '$ExternalEmailAddress'. A new contact will be created with:"
Write-Output "  Name                : $Name"
Write-Output "  DisplayName         : $DisplayName"
if ($FirstName -notlike "") { Write-Output "  FirstName           : $FirstName" }
if ($LastName -notlike "")  { Write-Output "  LastName            : $LastName" }
if ($Alias -notlike "")     { Write-Output "  Alias               : $Alias" }
Write-Output "  HideFromAddressLists: $HideFromAddressLists"

#endregion

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Creating Mail Contact"
Write-Output "---------------------"

# Build the parameter set for New-MailContact, including only the optional values that were supplied
$newContactParams = @{
    Name                 = $Name
    DisplayName          = $DisplayName
    ExternalEmailAddress = $ExternalEmailAddress
    ErrorAction          = "Stop"
}
if ($FirstName -notlike "") { $newContactParams["FirstName"] = $FirstName }
if ($LastName -notlike "")  { $newContactParams["LastName"]  = $LastName }
if ($Alias -notlike "")     { $newContactParams["Alias"]     = $Alias }

try {
    $newContact = New-MailContact @newContactParams
    Write-Output "Mail contact '$DisplayName' created successfully (Alias: '$($newContact.Alias)')."
}
catch {
    Write-Error "Failed to create mail contact '$DisplayName': $($_.Exception.Message)" -ErrorAction Continue
    throw "Mail contact creation failed for '$ExternalEmailAddress'"
}

# Apply settings that New-MailContact does not support directly
if ($HideFromAddressLists) {
    try {
        Set-MailContact -Identity $newContact.Identity -HiddenFromAddressListsEnabled $true -ErrorAction Stop
        Write-Output "Mail contact hidden from the Global Address List."
    }
    catch {
        Write-Error "The mail contact was created, but hiding it from the address lists failed: $($_.Exception.Message)" -ErrorAction Continue
        throw "Failed to set HiddenFromAddressListsEnabled for '$ExternalEmailAddress'"
    }
}

Write-Output ""
Write-Output "Result"
Write-Output "---------------------"
$resultContact = Get-MailContact -Identity $newContact.Identity -ErrorAction SilentlyContinue
if ($resultContact) {
    Write-Output "  Name                : $($resultContact.Name)"
    Write-Output "  DisplayName         : $($resultContact.DisplayName)"
    Write-Output "  Alias               : $($resultContact.Alias)"
    Write-Output "  ExternalEmailAddress: $($resultContact.ExternalEmailAddress)"
    Write-Output "  HiddenFromGAL       : $($resultContact.HiddenFromAddressListsEnabled)"
}

#endregion

########################################################
#region     Cleanup
########################################################

Disconnect-ExchangeOnline -Confirm:$false | Out-Null

Write-Output ""
Write-Output "Done!"

#endregion
