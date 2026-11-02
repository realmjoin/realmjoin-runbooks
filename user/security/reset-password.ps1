<#
    .SYNOPSIS
    Set a new password for this user

    .DESCRIPTION
    Sets a new password for this user in Entra ID and shows it in the output. A disabled account can be enabled first, and the user can be made to choose their own password at the next sign-in.

    .PARAMETER UserName
    User principal name of the user the runbook acts on. Set by the portal from the selected user.

    .PARAMETER EnableUserIfNeeded
    Enables a disabled account before the password is set.

    .PARAMETER ForceChangePasswordNextSignIn
    Makes the user choose their own password at the next sign-in.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "UserName": {
                "Hide": true
            },
            "CallerName": {
                "Hide": true
            },
            "EnableUserIfNeeded": {
                "DisplayName": "Enable the account if disabled?"
            },
            "ForceChangePasswordNextSignIn": {
                "DisplayName": "Require a new password at next sign-in?"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.10" }
#Requires -Modules @{ModuleName = "Microsoft.Graph.Authentication"; ModuleVersion = "2.41.2" }

param(
    [Parameter(Mandatory = $true)]
    [String] $UserName,
    [bool] $EnableUserIfNeeded = $true,
    [bool] $ForceChangePasswordNextSignIn = $true,
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

########################################################
#region     RJ Log Part
########################################################

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.1.0"
Write-RjRbLog -Message "Version: $Version" -Verbose

Write-RjRbLog -Message "UserName: $UserName" -Verbose
Write-RjRbLog -Message "EnableUserIfNeeded: $EnableUserIfNeeded" -Verbose
Write-RjRbLog -Message "ForceChangePasswordNextSignIn: $ForceChangePasswordNextSignIn" -Verbose

#endregion RJ Log Part

########################################################
#region     Function Definitions
########################################################

function Get-GraphPagedResult {
    <#
        .SYNOPSIS
        Retrieves all items from a paginated Microsoft Graph API endpoint.

        .DESCRIPTION
        Takes an initial Microsoft Graph API URI and retrieves all items across multiple pages
        by following the @odata.nextLink property in the response. Logs progress for slow or
        large pulls and surfaces Graph errors with the failing URI for easier troubleshooting.

        .PARAMETER Uri
        The initial Microsoft Graph API endpoint URI to query. This should be a full URL,
        e.g., "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/healthOverviews".

        .EXAMPLE
        PS C:\> $allIssues = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/issues"
    #>
    param(
        [string]$Uri
    )

    $allResults = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $pageCount = 0

    do {
        try {
            $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to retrieve paged data from '$nextLink': $($_.Exception.Message)" -ErrorAction Continue
            throw
        }

        $pageCount++
        if ($response.value) {
            $allResults.AddRange([object[]]$response.value)
        }

        if ($pageCount % 5 -eq 0) {
            Write-RjRbLog -Message "Pagination progress: $pageCount pages, $($allResults.Count) items retrieved so far" -Verbose
        }

        $nextLink = $response.'@odata.nextLink'
    } while ($nextLink)

    if ($pageCount -gt 1) {
        Write-RjRbLog -Message "Pagination complete: $pageCount pages, $($allResults.Count) total items" -Verbose
    }

    return $allResults.ToArray()
}

function Get-UserDirectoryRoleName {
    # Returns the names of the Entra ID roles assigned directly to the user, or $null when they cannot be read
    param(
        [string]$UserId
    )

    try {
        # The role lookup is optional: 2>$null keeps a missing permission out of the job's error stream, the catch handles it
        $roleAssignments = Get-GraphPagedResult -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$([uri]::EscapeDataString($UserId))'&`$select=roleDefinitionId" 2>$null
        $roleDefinitionIds = @($roleAssignments | ForEach-Object { $_.roleDefinitionId } | Where-Object { $_ } | Sort-Object -Unique)
        $roleNames = foreach ($roleDefinitionId in $roleDefinitionIds) {
            $roleDefinition = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions/$($roleDefinitionId)?`$select=displayName" -Method GET -ErrorAction Stop
            $roleDefinition.displayName
        }
        return , @($roleNames | Where-Object { $_ } | Sort-Object)
    }
    catch {
        Write-RjRbLog -Message "Could not read the Entra ID roles of the user: $($_.Exception.Message)" -Verbose
        return $null
    }
}

function Stop-UserChangeFailure {
    # Ends the run; on a 403 Entra ID protects the user because of an administrator role
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Action,
        [string]$UserPrincipalName,
        [object]$DirectoryRoles
    )

    $errorText = "$($ErrorRecord.ErrorDetails.Message) $($ErrorRecord.Exception.Message)"
    if ($errorText -notmatch 'Authorization_RequestDenied|Forbidden|\b403\b') {
        Write-Error "Failed to $($Action) '$($UserPrincipalName)': $($ErrorRecord.Exception.Message)" -ErrorAction Continue
        throw $ErrorRecord
    }

    if ($null -eq $DirectoryRoles) {
        $roleHint = "The user most likely holds an administrator role; the roles could not be read."
    }
    elseif ($DirectoryRoles.Count -eq 1) {
        $roleHint = "The user holds the Entra ID role $($DirectoryRoles[0])."
    }
    elseif ($DirectoryRoles.Count -gt 1) {
        $roleHint = "The user holds the Entra ID roles $($DirectoryRoles -join ', ')."
    }
    else {
        $roleHint = "The user holds no directly assigned Entra ID role, but may hold one through a role-assignable group."
    }

    Write-Error ("Entra ID denied the request to $($Action) '$($UserPrincipalName)'. $($roleHint) " +
        "For users with administrator roles, Entra ID allows this only to a Privileged Authentication Administrator or Global Administrator. " +
        "With the User Administrator role, the RealmJoin managed identity can change users without administrator roles and a few roles such as Helpdesk Administrator or Password Administrator. " +
        "If the user holds no administrator role, check that the managed identity holds the User Administrator role. Graph error: $($ErrorRecord.Exception.Message)") -ErrorAction Continue
    throw "Insufficient privileges to $($Action) '$($UserPrincipalName)'. $($roleHint) Ask a Global Administrator or Privileged Authentication Administrator to make the change in the Entra admin center."
}

#endregion Function Definitions

########################################################
#region     Connect Part
########################################################

try {
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ErrorAction Continue
    throw
}

#endregion Connect Part

########################################################
#region     StatusQuo & Preflight-Check Part
########################################################

Write-Output ""
Write-Output "Get StatusQuo"
Write-Output "---------------------"

try {
    $targetUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserName))?`$select=id,displayName,userPrincipalName,accountEnabled" -Method GET -ErrorAction Stop
}
catch {
    $errorText = "$($_.ErrorDetails.Message) $($_.Exception.Message)"
    if ($errorText -match 'Request_ResourceNotFound|NotFound|\b404\b') {
        Write-Error "User '$($UserName)' was not found in Entra ID." -ErrorAction Continue
        throw "User '$($UserName)' not found."
    }
    Write-Error "Failed to read user '$($UserName)': $($_.Exception.Message)" -ErrorAction Continue
    throw
}
Write-RjRbLog -Message "User object ID: $($targetUser.id)" -Verbose

$directoryRoles = Get-UserDirectoryRoleName -UserId $targetUser.id

Write-Output "User: $($targetUser.displayName) ($($targetUser.userPrincipalName))"
Write-Output "Sign-in allowed: $(if ($targetUser.accountEnabled) { 'Yes' } else { 'No' })"
if ($null -eq $directoryRoles) {
    Write-Output "Entra ID roles: could not be read"
}
elseif ($directoryRoles.Count -eq 0) {
    Write-Output "Entra ID roles: none assigned directly"
}
else {
    Write-Output "Entra ID roles: $($directoryRoles -join ', ')"
}

#endregion StatusQuo & Preflight-Check Part

########################################################
#region     Main Part
########################################################

Write-Output ""
Write-Output "Reset password"
Write-Output "---------------------"

if (-not $targetUser.accountEnabled) {
    if ($EnableUserIfNeeded) {
        try {
            Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)" -Method PATCH -Body (@{ accountEnabled = $true } | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop | Out-Null
        }
        catch {
            Stop-UserChangeFailure -ErrorRecord $_ -Action "enable the account of" -UserPrincipalName $targetUser.userPrincipalName -DirectoryRoles $directoryRoles
        }
        Write-Output "Account of '$($targetUser.userPrincipalName)' enabled."
    }
    else {
        Write-Output "The account of '$($targetUser.userPrincipalName)' stays disabled; the new password works once it is enabled."
    }
}

# Optional: Set a password for every reset. Otherwise, a random PW will be generated every time (preferred!).
[String] $initialPassword = ""
if ($initialPassword -eq "") {
    $initialPassword = ("Reset" + (Get-Random -Minimum 10000 -Maximum 99999) + "!")
}

$body = @{
    passwordProfile = @{
        forceChangePasswordNextSignIn = $ForceChangePasswordNextSignIn
        password                      = $initialPassword
    }
}
try {
    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($targetUser.id)" -Method PATCH -Body ($body | ConvertTo-Json -Depth 3) -ContentType "application/json" -ErrorAction Stop | Out-Null
}
catch {
    Stop-UserChangeFailure -ErrorRecord $_ -Action "reset the password of" -UserPrincipalName $targetUser.userPrincipalName -DirectoryRoles $directoryRoles
}

Write-Output "Password reset for '$($targetUser.userPrincipalName)'."
if ($ForceChangePasswordNextSignIn) {
    Write-Output "The user has to choose a new password at the next sign-in."
}
Write-Output ""
Write-Output "New password for '$($targetUser.userPrincipalName)':"
Write-Output $initialPassword

#endregion Main Part

########################################################
#region     Cleanup
########################################################

if (Get-MgContext -ErrorAction SilentlyContinue) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

Write-Output ""
Write-Output "Done!"

#endregion Cleanup
