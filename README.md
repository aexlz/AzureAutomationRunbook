# AzureAutomationRunbook
Adds devices of a user to a certain DeviceGroup. Triggered via Webhook.

I encountered the problem described here: https://techcommunity.microsoft.com/t5/intune-customer-success/microsoft-endpoint-manager-rbac-auto-assign-scope-tags-to/ba-p/2423576
Auto-assigning a device to a group with no user-interaction is hard, when you want to have all devices of User-GroupA in Device-GroupA and all the devices of User-GroupB in Device-GroupB ....


This script allows us to do the following:
User A purchases a new device.
User A signs in on this device to portal.microsoft.com once (Device-Object will be propagated in Azure).
Admin B calls CallWebhook.ps1 with the UPN of UserA and every attached Device will be added to a certain device-group by the RunbookExample.ps1
If you just want to have specific devices e.g. Windows you have to filter them in the Run-Book-Script.

Make sure to create the AzureAutomationAccount, the ManagedIdentity and the Webhook in advance.
Copy and store the Webhook-URL in a safe place. It must be treated like a password.
Resources:
https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/
https://docs.microsoft.com/en-us/azure/automation/

Enter the according values in the scripts with your own parameter (AutomationAccount, ManagedIdentity, ResourceGroupName, Device-Group-ObjectID)

Run the Assign

The Webhook must be called with the UPN of the certain user.

The Webhook sends this UPN to the Azure Runbook, which then fetches the UPN from AzureAD and assign every device to the device group provided.


