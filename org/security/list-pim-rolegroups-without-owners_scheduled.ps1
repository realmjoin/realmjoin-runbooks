<#
    .SYNOPSIS
    Alert on PIM role groups that have no owner

    .DESCRIPTION
    Finds role-assignable groups that hold eligible PIM role assignments but have no owner, so nobody is responsible for their membership. The group names are listed and can be sent by email. Nothing is changed.

    .PARAMETER SendEmailIfFound
    Sends an email with the group names when such groups are found.

    .PARAMETER From
    User in the tenant the alert is sent as; needs a mailbox.

    .PARAMETER To
    Gets the email with the group names.

    .PARAMETER CallerName
    Name of the user who started the runbook. Set by the portal and recorded for auditing.

    .INPUTS
    RunbookCustomization: {
        "Parameters": {
            "SendEmailIfFound": {
                "DisplayName": "Send an email when groups are found?"
            },
            "CallerName": {
                "Hide": true
            },
            "From": {
                "DisplayName": "Alert sender"
            },
            "To": {
                "DisplayName": "Alert recipient"
            }
        }
    }
#>

#Requires -Modules @{ModuleName = "RealmJoin.RunbookHelper"; ModuleVersion = "0.8.9" }

param(
    [bool] $SendEmailIfFound = $true,
    [string] $From = "reports@contoso.com",
    [string] $To = "support@glueckkanja-gab.com",
    # CallerName is tracked purely for auditing purposes
    [Parameter(Mandatory = $true)]
    [string] $CallerName
)

Write-RjRbLog -Message "Caller: '$CallerName'" -Verbose

$Version = "1.0.1"
Write-RjRbLog -Message "Version: $Version" -Verbose

Connect-RjRbGraph

$groups = Invoke-RjRbRestMethodGraph -Resource "/groups" -OdFilter "isAssignableToRole eq true"

"## PIM Groups without owners"
$result = @()
$groups | ForEach-Object {
    $roleAssignments = Invoke-RjRbRestMethodGraph -Resource "/roleManagement/directory/roleEligibilitySchedules" -Beta -OdFilter "principalId eq '$($_.id)'"
    $owners = Invoke-RjRbRestMethodGraph -Resource "/groups/$($_.id)/owners"
    if (($owners.count -eq 0) -and ($roleAssignments.count -gt 0)) {
        "$($_.displayName)"
        $result += $_
    }
}
""

if ($SendEmailIfFound -and ($result.Count -gt 0)) {
    $tenant = Invoke-RjRbRestMethodGraph -Resource "/organization"
    $tenantName = ($tenant.verifiedDomains | Where-Object { $_.isInitial }).name

    $HTMLBody = @"
    Hello Team,<br>
    <br>
    please find below a list of PIM groups without owners.<br>
    <br>
    <b>Tenant:</b> <br>
    $tenantName<br>
    <br>
    <b>Groups:</b><br>
    <table>
        $(foreach ($group in $result) {
            "<tr><td>$($group.displayName)</td></tr>"
        })
    </table>
    <br>
    This is an automated eMail. Please do not reply to this eMail.<br>
"@

    $message = @{
        subject = "[Automated eMail] ALERT - PIM Groups without owners"
        body    = @{
            contentType = "HTML"
            content     = $HTMLBody
        }
    }

    $message.toRecipients = [array]@{
        emailAddress = @{
            address = $To
        }
    }

    Invoke-RjRbRestMethodGraph -Resource "/users/$from/sendMail" -Method POST -Body @{ message = $message } | Out-Null
    "## Alert sent to '$To'."
}
