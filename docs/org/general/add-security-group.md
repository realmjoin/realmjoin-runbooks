# Add Security Group

## This runbook creates a Microsoft Entra ID security group with membership type "Assigned".

## Description
This runbook creates a Microsoft Entra ID security group with membership type "Assigned".

## Where to find
Org \ General \ Add Security Group

## Notes
Permissions (according to https://docs.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0 )
GraphAPI: 
- Group.Create 

AssignableToRoles is currently deactivated, as extended rights are required. 
“RoleManagement.ReadWrite.Directory” permission is required to set the ‘isAssignableToRole’ property or update the membership of such groups. 
Reference is made to this in a comment in the course of the code.
(according to https://learn.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0&tabs=http#example-3-create-a-microsoft-365-group-that-can-be-assigned-to-a-microsoft-entra-role)
Also to reactivate this feature, the following extra is in the .INPUTS are required:
"AssignableToRoles": {
    "DisplayName":  "Microsoft Entra roles can be assigned to the group"
},

## Parameters
### -GroupName
Description: The name of the security group.
Default Value: 
Required: true

### -GroupDescription
Description: The description of the security group.
Default Value: 
Required: false

### -Owner
Description: The owner of the security group.
Default Value: 
Required: false


[Back to Table of Content](../../../README.md)

