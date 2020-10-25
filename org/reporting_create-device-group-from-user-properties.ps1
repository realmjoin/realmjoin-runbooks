param
(
[Parameter(Mandatory=$false)]
    [Guid] $GitId = "89F76E91-330C-4DFA-9CF2-90759A745E4E",
    [Parameter(Mandatory = $true)]
    [String] $OrganizationID,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationName,
    [Parameter(Mandatory = $true)]
    [String] $OrganizationInitialDomainName,
    [Parameter(Mandatory = $true)]
    [String] $CallerName
)

"Hello $OrganizationName ($OrganizationID; $OrganizationInitialDomainName)!. I was called by $CallerName."

<#  

Hatte gerade ein Gespräch über Grouping in Intune. Worum geht es? Im Prinzip hat man immer wieder die Anforderung 
auf User Property Basis eine Device Gruppe zu bilden. Beispiel: Alle Nutzer aus Frankreich suchen und deren 
Devices in eine Gruppe packen. Das kann man dann nutzen um RBAC Modell zu bauen, an die device group 
hängt man den scope tag und damit hat man RBAC für fanzösische Admins gebaut. Oder auch einfach alle 
devices in Frankreich sollen eine App oder Config bekommen oder bei der Etex alle Nutzer einer 
Sub Company suchen und deren Rechner wieder in eine Device Group packen etc...
 
Wäre es nicht gut wenn wir unsere RJ Runbook Funktionalität auf Tenant Level zur Verfügung stellen 
(vielleicht hattest du das eh angedacht, weiß es gerade nicht mehr) und dann in unsere 
Runbook Template Library ein Runbook haben (simplified):
 
Get-AzureADUsers -Filter <to-be-defined-by-customer> | Get-AzureADDevices | Add-AzureADGroupMember....
 
Das könnten dann RJ Admin Nutzer auf tenant level aktivieren und damit bekämen sie Gruppen gebaut die heute 
so nicht abbildbar sind durch dynamische Azure AD Groups. Das ganze dann später gepaart mit den 
neuen “Assignment Filters”, könnte eine sehr gute Kombination liefern, um eigentlich alle Fälle 
bzgl. Assignment Anforderungen irgendwie abzubilden.
 
Also am Ende, tenant level Runbooks in RJ und ein Template dieser Natur, so das ein Admin nur 
den filter definiert und schon hat er benötigte Gruppen.
 
Klar das Runbook template sollte dann auch bei re-run vorher checken ist das device schon in der gruppe usw. also 
ein wenig besser ausgearbeitet aber das versteht sich ja von selbst.

#>
