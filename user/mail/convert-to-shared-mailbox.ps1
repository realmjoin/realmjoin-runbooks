<#
    .SYNOPSIS
    Convert this user's mailbox to a shared mailbox or back

    .DESCRIPTION
    Turns the mailbox of this user into a shared mailbox, or turns a shared mailbox back into a regular user mailbox. When converting to shared, a delegate can get full access and the user's group memberships can be removed. A license group can be assigned when the mailbox needs an Exchange Online Plan 2. Turning it back removes the full access, send as and send on behalf permissions of all other users. A Bookings mailbox or another type that Exchange Online cannot convert stops the run before anything changes.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER delegateTo
    User who gets full access to the shared mailbox. Leave empty to grant no access.

    .PARAMETER Remove
    Whether the shared mailbox is turned back into a regular mailbox. Set by the "Action" choice.

    .PARAMETER AutoMapping
    Makes the shared mailbox appear automatically in the delegate's Outlook.

    .PARAMETER RemoveGroups
    Takes the user out of all groups, including license groups, when converting to shared. This happens only once Exchange Online reports the mailbox as shared.

    .PARAMETER ArchivalLicenseGroup
    Group that assigns an Exchange Online Plan 2 license, needed when the shared mailbox has an archive, is larger than 50 GB or is on litigation hold. Leave empty if not needed. A name shared by several groups stops the run.

    .PARAMETER RegularLicenseGroup
    Group that assigns the mailbox license when converting back to a regular mailbox. Leave empty to assign none. A name shared by several groups stops the run.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "Remove": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            }
        },
        "ParameterList": [
            {
                "DisplayName": "Action",
                "DisplayBefore": "AutoMapping",
                "Select": {
                    "Options": [
                        {
                            "Display": "Turn mailbox into shared mailbox",
                            "ParameterValue": "Turn mailbox into shared mailbox",
                            "Customization": {
                                "Default": {
                                    "Remove": false
                                },
                                "Hide": [
                                    "RegularLicenseGroup"
                                ]
                            }
                        },
                        {
                            "Display": "Turn shared mailbox back into regular mailbox",
                            "ParameterValue": "Turn shared mailbox back into regular mailbox",
                            "Customization": {
                                "Default": {
                                    "Remove": true,
                                    "RemoveGroups": false
                                },
                                "Hide": [
                                    "AutoMapping",
                                    "delegateTo",
                                    "RemoveGroups",
                                    "ArchivalLicenseGroup"
                                ]
                            }
                        }
                    ]
                },
                "Default": "Turn mailbox into shared mailbox"
            },
            {
                "Name": "CallerName",
                "Hide": true
            }
        ]
    }

#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.9.2" }

param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "User/Mailbox" } )]
    [string] $UserName,
    [ValidateScript( { Use-RJInterface -Type Graph -Entity User -DisplayName "Delegate access to" -Filter "userType eq 'Member'" } )]
    [string] $delegateTo,
    [ValidateScript( { Use-RJInterface -DisplayName "Turn mailbox back to regular mailbox" } )]
    [bool] $Remove = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Map the mailbox in Outlook automatically?" } )]
    [bool] $AutoMapping = $false,
    [ValidateScript( { Use-RJInterface -DisplayName "Remove group memberships?" } )]
    [bool] $RemoveGroups = $true,
    [ValidateScript( { Use-RJInterface -DisplayName "License group for Exchange Online Plan 2" } )]
    [string] $ArchivalLicenseGroup = "",
    [ValidateScript( { Use-RJInterface -DisplayName "License group for the regular mailbox" } )]
    [string] $RegularLicenseGroup = "",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName

)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.2"
Write-RjRbLog -Message "Version: $Version" -Verbose

# Finds a license group by display name. None found: warning, no license. Several found: stop before anything changes.
function Get-LicenseGroup {
    param([string] $DisplayName)
    $groups = @(Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "displayName eq '$($DisplayName -replace "'", "''")'" -ErrorAction Stop)
    if ($groups.Count -gt 1) {
        throw "$($groups.Count) groups are named '$DisplayName', so the license group is ambiguous. Give the license group a unique name and run the runbook again. Nothing was changed."
    }
    if ($groups.Count -eq 0) {
        Write-RjRbLog -Message "WARNING: License group '$DisplayName' was not found. No license is assigned through it." -Verbose
        Write-Warning "License group '$DisplayName' was not found. No license is assigned through it."
        return $null
    }
    return $groups[0]
}

# Direct membership check over all pages of the group's members (the first page holds only 100)
function Test-GroupMember {
    param([string] $GroupId, [string] $MemberId)
    $memberIds = @(Invoke-RjRbRestMethodGraph -Resource "/groups/$GroupId/members" -FollowPaging -ErrorAction Stop | ForEach-Object { $_.id })
    return ($memberIds -contains $MemberId)
}

# Ends the run after a failed step and says which steps were done and which were not
function Stop-Conversion {
    param([string] $TargetType, [string[]] $PlannedSteps, [int] $StepsDone, [System.Management.Automation.ErrorRecord] $ErrorRecord)
    $doneSteps = @($PlannedSteps | Select-Object -First $StepsDone)
    $openSteps = @($PlannedSteps | Select-Object -Skip $StepsDone)
    $message = "Converting mailbox '$UserName' to a $TargetType mailbox stopped at the step '$($openSteps[0])': $($ErrorRecord.Exception.Message) " +
    "Done: $(if ($doneSteps.Count -gt 0) { $doneSteps -join '; ' } else { 'nothing' }). Not done: $($openSteps -join '; ')."
    Write-Error $message -ErrorAction Continue
    throw $message
}

Connect-RjRbGraph

$outputString = "## Trying to convert mailbox '$UserName' "
if ($Remove) {
    $outputString += "to a regular mailbox."
}
else {
    $outputString += "to a shared mailbox."
}
$outputString

if ($delegateTo) {
    $delegateObj = Invoke-RjRbRestMethodGraph -Resource "/users/$delegateTo" -ErrorAction Stop
    "## Give access to mailbox '$UserName' to '$($delegateObj.userPrincipalName)'."
}
if ($AutoMapping) {
    "## Mailbox will automatically appear in Outlook."
}

try {
    Connect-RjRbExchangeOnline

    # Check if User has a mailbox
    # No need to check trustee for a mailbox with "FullAccess"
    $user = Get-EXOMailbox -Identity $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        throw "User '$UserName' has no mailbox."
    }

    [bool] $archivalLicNeeded = $false
    "## Check Mailbox Size"
    $stats = Get-EXOMailboxStatistics -Identity $UserName -ErrorAction Stop
    if ($stats.TotalItemSize.Value -gt 50GB) {
        " -> Mailbox is larger than 50GB -> license required"
        $archivalLicNeeded = $true
    }

    "## Check for litigation hold"
    $result = Get-Mailbox -Identity $UserName -ErrorAction Stop
    if ($result.LitigationHoldEnabled) {
        " -> Mailbox is on litigation hold -> license required"
        $archivalLicNeeded = $true
    }

    "## Check for Mailbox Archive"
    # Not using "ArchiveState", see https://docs.microsoft.com/en-us/office365/troubleshoot/archive-mailboxes/archivestatus-set-none
    if (($result.ArchiveGuid -and ($result.ArchiveGuid.GUID -ne "00000000-0000-0000-0000-000000000000")) -or ($result.ArchiveDatabase)) {
        " -> Mailbox has an archive -> license required"
        $archivalLicNeeded = $true
    }

    # Exchange Online converts only these types and rejects others, such as Bookings mailboxes; stop before the first change
    $currentMailboxType = [string]$result.RecipientTypeDetails
    if ($currentMailboxType -notin @("UserMailbox", "SharedMailbox", "RoomMailbox", "EquipmentMailbox")) {
        $typeText = if ($currentMailboxType -eq "SchedulingMailbox") { "a Bookings mailbox (SchedulingMailbox)" } else { "of type '$currentMailboxType'" }
        throw "Mailbox '$UserName' is $typeText. Exchange Online converts only user, shared, room and equipment mailboxes. Nothing was changed."
    }

    # Each step stops the run on an error, so a failed step is never followed by a "Success" line
    $stepsDone = 0
    if ($Remove) {
        $groupObj = $null
        if ($RegularLicenseGroup) {
            $groupObj = Get-LicenseGroup -DisplayName $RegularLicenseGroup
        }
        $plannedSteps = @("remove the full access permissions of other users", "remove the send as permissions of other users")
        if ($groupObj) {
            $plannedSteps += "add the user to license group '$RegularLicenseGroup'"
        }
        $plannedSteps += "enable sign-in of the user account", "turn the mailbox into a regular mailbox and remove all send on behalf permissions"

        try {
            "## Removing access for other users..."
            # Inherited and deny entries do not give access and cannot be removed this way
            $PermittedUsers = Get-MailboxPermission -Identity $UserName -ErrorAction Stop | Where-Object { ($_.User -ne "NT AUTHORITY\SELF") -and (-not $_.IsInherited) -and (-not $_.Deny) }
            foreach ($PermittedUser in $PermittedUsers) {
                "## Reverting Mailbox Access Permission for '$($PermittedUser.User)' from mailbox '$UserName'"
                Remove-MailboxPermission -Identity $UserName -User $PermittedUser.User -AccessRights $PermittedUser.AccessRights -InheritanceType All -confirm:$false -ErrorAction Stop | Out-Null
            }
            $stepsDone++
            $PermittedRecipients = Get-RecipientPermission -Identity $UserName -ErrorAction Stop | Where-Object { ($_.Trustee -ne "NT AUTHORITY\SELF") -and (-not $_.IsInherited) -and ($_.AccessControlType -ne "Deny") }
            foreach ($PermittedRecipient in $PermittedRecipients) {
                "## Reverting SendAs/SendOnBehalf Permission for '$($PermittedRecipient.Trustee)' from mailbox '$UserName'"
                Remove-RecipientPermission -Identity $UserName -Trustee $PermittedRecipient.Trustee -AccessRights $PermittedRecipient.AccessRights -confirm:$false -ErrorAction Stop | Out-Null
            }
            $stepsDone++

            if ($groupObj) {
                # Assign lic. group
                if (-not (Test-GroupMember -GroupId $groupObj.id -MemberId $user.ExternalDirectoryObjectId)) {
                    "## Assigning license group '$RegularLicenseGroup' to mailbox '$UserName'"
                    $body = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.ExternalDirectoryObjectId)"
                    }
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($groupObj.id)/members/`$ref" -Method Post -Body $body -ErrorAction Stop | Out-Null
                }
                else {
                    "## License group '$RegularLicenseGroup' already assigned to mailbox '$UserName'"
                }
                $stepsDone++
            }

            "## Enabling user object '$UserName'"
            $userObj = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -ErrorAction Stop
            $body = @{
                accountEnabled = $true
            }
            Invoke-RjRbRestMethodGraph -Resource "/users/$($userObj.id)" -Method Patch -Body $body -ErrorAction Stop | Out-Null
            $stepsDone++

            "## Turning mailbox '$UserName' into regular user mailbox"
            foreach ($sendOnBehalfUser in @($result.GrantSendOnBehalfTo | Where-Object { $_ })) {
                "## Removing send on behalf permission for '$sendOnBehalfUser' from mailbox '$UserName'"
            }
            Set-Mailbox $UserName -Type regular -GrantSendOnBehalfTo $null -ErrorAction Stop | Out-Null
            $stepsDone++
        }
        catch {
            Stop-Conversion -TargetType "regular" -PlannedSteps $plannedSteps -StepsDone $stepsDone -ErrorRecord $_
        }

        ""
        "## Success: Mailbox '$UserName' is now a regular mailbox."
    }
    else {
        $groupObj = $null
        if ($ArchivalLicenseGroup -and $archivalLicNeeded) {
            $groupObj = Get-LicenseGroup -DisplayName $ArchivalLicenseGroup
        }
        $plannedSteps = @("block sign-in of the user account", "turn the mailbox into a shared mailbox")
        if ($delegateTo) {
            $plannedSteps += "grant full access to '$($delegateObj.userPrincipalName)'"
        }
        if ($RemoveGroups) {
            $plannedSteps += "remove the group memberships"
        }
        if ($groupObj) {
            $plannedSteps += "add the mailbox to license group '$ArchivalLicenseGroup'"
        }
        $failedGroups = @()

        try {
            "## Disabling user object '$UserName' (no login for shared mailboxes)"
            $userObj = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName" -ErrorAction Stop
            $body = @{
                accountEnabled = $false
            }
            Invoke-RjRbRestMethodGraph -Resource "/users/$($userObj.id)" -Method Patch -Body $body -ErrorAction Stop | Out-Null
            $stepsDone++

            "## Turning mailbox '$UserName' into shared mailbox"
            Set-Mailbox $UserName -Type shared -ErrorAction Stop | Out-Null
            # Removing groups can take away the license; go on only once Exchange Online reports a shared mailbox
            $mailboxType = $null
            for ($attempt = 1; $attempt -le 3; $attempt++) {
                $mailboxType = [string](Get-Mailbox -Identity $UserName -ErrorAction Stop).RecipientTypeDetails
                if ($mailboxType -eq "SharedMailbox") {
                    break
                }
                if ($attempt -lt 3) {
                    Start-Sleep -Seconds 10
                }
            }
            if ($mailboxType -ne "SharedMailbox") {
                throw "Exchange Online still reports the mailbox as '$mailboxType' instead of 'SharedMailbox'."
            }
            $stepsDone++

            # Add access
            if ($delegateTo) {
                "## Adding FullAccess Permission for '$($delegateObj.userPrincipalName)' to mailbox '$UserName'"
                Add-MailboxPermission $UserName -User $delegateTo -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -confirm:$false -ErrorAction Stop | Out-Null
                $stepsDone++
            }

            if ($RemoveGroups) {
                # Remove all group memberships; memberOf also lists directory roles and administrative units, which are no groups
                $memberships = Invoke-RjRbRestMethodGraph -Resource "/users/$UserName/memberOf" -FollowPaging -ErrorAction Stop | Where-Object { (-not $_.'@odata.type') -or ($_.'@odata.type' -eq "#microsoft.graph.group") }
                # A failed group does not stop the others; the run fails at the end
                $memberships | ForEach-Object {
                    if ($_.GroupTypes -contains "DynamicMembership") {
                        "## Skipping dynamic group '$($_.displayName)'"
                    }
                    elseif ($_.onPremisesSyncEnabled) {
                        "## Skipping on-premises group '$($_.displayName)'"
                        "## - please remove manually"
                    }
                    elseif ($_.isAssignableToRoles) {
                        # this would require RoleManagement.ReadWrite.Directory permission and "Privileged Role Administrator" Role for RJ
                        "## Skipping role group '$($_.displayName)'"
                        "## - Role assignable groups can not be managed via RJ - Privileged Role Management permission required"
                    }
                    else {
                        $group = $_
                        "## Removing group membership '$($group.displayName)' from mailbox '$UserName'"
                        try {
                            if (($group.GroupTypes -contains "Unified") -or (-not $group.MailEnabled)) {
                                "## .. using Graph API"
                                Invoke-RjRbRestMethodGraph -Resource "/groups/$($group.id)/members/$($user.ExternalDirectoryObjectId)/`$ref" -Method Delete -ErrorAction Stop | Out-Null
                            }
                            else {
                                "## .. using Exchange Online PowerShell"
                                Remove-DistributionGroupMember -Identity $group.id -Member $UserName -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop | Out-Null
                            }
                        }
                        catch {
                            Write-RjRbLog -Message "WARNING: Could not remove mailbox '$UserName' from group '$($group.displayName)': $($_.Exception.Message)" -Verbose
                            Write-Warning "Could not remove mailbox '$UserName' from group '$($group.displayName)': $($_.Exception.Message)"
                            $failedGroups += [string]$group.displayName
                        }
                    }
                }
                if ($failedGroups.Count -gt 0) {
                    $plannedSteps[$stepsDone] += " (failed for: $($failedGroups -join ', '))"
                }
                $stepsDone++
            }

            if ($groupObj) {
                # Assign lic. group to preserve online arhive etc.
                if (-not (Test-GroupMember -GroupId $groupObj.id -MemberId $user.ExternalDirectoryObjectId)) {
                    "## Assigning license group '$ArchivalLicenseGroup' to mailbox '$UserName'"
                    $body = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.ExternalDirectoryObjectId)"
                    }
                    Invoke-RjRbRestMethodGraph -Resource "/groups/$($groupObj.id)/members/`$ref" -Method Post -Body $body -ErrorAction Stop | Out-Null
                }
                else {
                    "## License group '$ArchivalLicenseGroup' already assigned to mailbox '$UserName'"
                }
                $stepsDone++
            }
        }
        catch {
            Stop-Conversion -TargetType "shared" -PlannedSteps $plannedSteps -StepsDone $stepsDone -ErrorRecord $_
        }

        if ($failedGroups.Count -gt 0) {
            $message = "Mailbox '$UserName' is now a shared mailbox, but it could not be removed from these groups: $($failedGroups -join ', '). The reason per group is in the warnings above; remove the user from them manually."
            Write-Error $message -ErrorAction Continue
            throw $message
        }

        ""
        "## Success: Mailbox '$UserName' is now a shared mailbox."
    }

    ""
    "## Current Permission Delegations"
    Get-MailboxPermission -Identity $UserName | Select-Object -expandproperty User

}
finally {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Continue | Out-Null
}
