#Assign variables
$resourceGroup = "<ENTER Name of ResourceGroup here>"

# These values are used in this tutorial
$automationAccount = "<ENTER Name of automationAccount here>"
$userAssignedManagedIdentity = "<ENTER Name of userAssignedManagedIdentity here>"


#Assign role to system-assigned managed identity. Choose the role you want
$role1 = "Contributor"

$SAMI = (Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccount).Identity.PrincipalId
New-AzRoleAssignment `
    -ObjectId $SAMI `
    -ResourceGroupName $resourceGroup `
    -RoleDefinitionName $role1


$UAMI = (Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $userAssignedManagedIdentity).Identity.PrincipalId
New-AzRoleAssignment `
    -ObjectId $UAMI `
    -ResourceGroupName $resourceGroup `
    -RoleDefinitionName $role1