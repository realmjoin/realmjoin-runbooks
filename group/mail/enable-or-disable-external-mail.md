## Implementation notes

The setting is changed through Exchange Online (`RequireSenderAuthenticationEnabled`), not through Microsoft Graph. Writing the corresponding `allowExternalSenders` property of the group via Microsoft Graph is a documented known issue (as of 2021-06-28), see [Setting the allowExternalSenders property](https://docs.microsoft.com/en-us/graph/known-issues#setting-the-allowexternalsenders-property).
