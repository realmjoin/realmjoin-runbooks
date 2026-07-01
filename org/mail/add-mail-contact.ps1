<#
	.SYNOPSIS
	Create a new Exchange Online mail contact with optional display name and address list settings

	.DESCRIPTION
	This runbook creates a new Exchange Online mail contact (external contact) using the New-MailContact cmdlet. You can optionally set the contact's first name, last name, email alias, and control whether it appears in the Global Address List. All names default to the provided display name if not explicitly set.

	.PARAMETER ExternalEmailAddress
	The external SMTP email address for the mail contact. This is the primary email address used for communication with the contact.

	.PARAMETER DisplayName
	The display name shown for the mail contact in Exchange Online and the Global Address List.

	.PARAMETER Name
	The unique contact name used for management and identification. If left empty, defaults to the DisplayName value.

	.PARAMETER FirstName
	The first name of the contact. If not specified, the field is left empty.

	.PARAMETER LastName
	The last name of the contact. If not specified, the field is left empty.

	.PARAMETER Alias
	The mail nickname (alias) for the mail contact. If not specified, the system generates one automatically from the display name.

	.PARAMETER HideFromAddressLists
	If set to true, the mail contact will be hidden from the Global Address List and other address lists. If false, the contact is visible to all users. Defaults to false.

	.PARAMETER CallerName
	Caller name for auditing purposes.

	.INPUTS
	RunbookCustomization: {
		"Parameters": {
			"ExternalEmailAddress": {
				"DisplayName": "External Email Address"
			},
			"DisplayName": {
				"DisplayName": "Display Name"
			},
			"Name": {
				"DisplayName": "Contact Name (optional - defaults to Display Name)"
			},
			"FirstName": {
				"DisplayName": "First Name (optional)"
			},
			"LastName": {
				"DisplayName": "Last Name (optional)"
			},
			"Alias": {
				"DisplayName": "Mail Alias (optional)"
			},
			"HideFromAddressLists": {
				"DisplayName": "Hide from Global Address List"
			},
			"CallerName": {
				"Hide": true
			}
		}
	}
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.5" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.0" }

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
