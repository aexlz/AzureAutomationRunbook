param
(
    [Parameter(Mandatory=$false)]
    [object] $WebhookData
)

if ($WebhookData.RequestBody) { 
    $upns = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

        foreach ($x in $upns)
        {
            $upn = $x.UPN
            Write-Output "$upn received from Webhook"
        }
}
else {
    Write-Debug "No input parameter found!"
	exit
}

$automationAccount = "<ENTER automationAccountName here>"
$userAssignedManagedIdentity = "<ENTER Managed Identity here>"
$resourceGroup = "<ENTER ResourceGroup Name here>"

#Optional for App-Roles
$ApplicationId = "<ENTER AppID here>"

$GroupObjectID ="<>ENTER >Group ObjectID here>"

$method = "ua"

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

# Connect using a Managed Service Identity
try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
catch{
        Write-Debug "There is no system-assigned user identity. Aborting."
        exit
    }

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
    -DefaultProfile $AzureContext

#Either system-assigned (SAMI) or user-assigned (UAMI)
$SAMI = (Get-AzAutomationAccount -ResourceGroupName $resourceGroup -Name $automationAccount).Identity.PrincipalId
$UAMI = (Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroup -Name $userAssignedManagedIdentity).PrincipalId

if ($method -eq "SA")
    {
        Write-Debug "Using system-assigned managed identity"
    }
elseif ($method -eq "UA")
    {
        Write-Debug "Using user-assigned managed identity"

        # Connects using the Managed Service Identity of the named user-assigned managed identity
        $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroup `
            -Name $userAssignedManagedIdentity -DefaultProfile $AzureContext

        # validates assignment only, not perms
        if ((Get-AzAutomationAccount -ResourceGroupName $resourceGroup `
                -Name $automationAccount `
                -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId))
            {	
				Write-Debug "Try to connect to Azure with UserAssignedManagedIdentity"
                $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

                # set and store context
                $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

				Write-Debug "Successfully connected to Azure with UserAssignedManagedIdentity"
            }
        else {
				Write-Output "Invalid or unassigned user-assigned managed identity. Consult the admin."
                Write-Error "Invalid or unassigned user-assigned managed identity"
                exit
            }
    }
else {
        Write-Error "Invalid method. Choose UA or SA."
        exit
     }

# Import required modules
try {
    Import-Module -Name AzureAD -ErrorAction Stop
}
catch {
	Write-Output "Failed to import modules. Consult the admin"
    Write-Error -Message "Failed to import modules"
}


#Grab AzureAD-AccessToken AzureRmProfileProvider.Context
$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
$aadToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://graph.windows.net").AccessToken


#Try to connect to AzureAD-Module with AccessToken
try{
	Connect-AzureAD -AadAccessToken $aadToken -AccountId $context.Account.Id -TenantId $context.Tenant.Id > $null
	Write-Output "Successfully conntected to AzureAD-Module"

}catch{
	Write-Output $_
	Write-Output "Failed to connect to AzureAD-Module. Consult the admin"
	Write-Error "Failed to connect to AzureAD-Module"
	exit
}

#Fetch AzureADUser
try{
	$azureADUser = Get-AzureADUser -ObjectId "$($upn)"
	Write-Output "$($azureADUser.UserPrincipalName) fetched from Azure"
}catch{
	Write-Output $_
	Write-Output "Failed to fetch AzureAD-User $($upn) from Azure. Consult the admin"
	Write-Error "Failed to fetch AzureAD-User $($upn) from Azure"
	exit
}

#Get all devices of the user
try{
	$azureADDevices = Get-AzureADUserRegisteredDevice -ObjectId $azureADUser.ObjectId
	foreach ($device in $azureADDevices){
		Write-Output $azureADDevices.ObjectId 
		Write-Output $azureADDevices.DisplayName 
	}
	
}catch{
	Write-Output $_
	Write-Output "Failed to fetch AzureAD-Device for $($upn) from Azure. Consult the admin"
	Write-Error "Failed to fetch AzureAD-Device for $($upn) from Azure"
	exit
}


try{
	foreach ($device in $azureADDevices){
		if ($device.DeviceOSType -eq "Windows")){
			Add-AzureADGroupMember -ObjectId $GroupObjectID -RefObjectId $device.ObjectId > $null
			Write-Output "Added device '$($device.DisplayName)' to DeviceGroup assigned DeviceGroup"
		}
	}
}catch{
	Write-Output $_
	Write-Output "Could not add '$($device.DisplayName)' to DeviceGroup. Consult the admin"
	Write-Output "Are the devices already member of the DeviceGroup?"
	Write-Error "Could not add '$($device.DisplayName)' to DeviceGroup."
}

