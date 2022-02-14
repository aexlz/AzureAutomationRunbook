#BusinessUnits: 
#Key = ObjectId of BusinessUnit-User-Group
#Value = ObjectId of BusinessUnit-Device-Group
$businessUnits = @{

“<KEY>” = “<VALUE>”

}


#Prepare connection-prereq if 
#
$automationAccount = "<NAME>"
$resourceGroup = "<NAME>"

#Use System-Assigned-MI
$method = "sa"

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

# Connect using a Managed Service Identity (MUST HAVE CONTRIBUTOR ROLE ON AutomationAccount)
try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
catch{
        Write-Output "There is no system-assigned user identity. Aborting."
        exit
    }

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
    -DefaultProfile $AzureContext

if ($method -eq "SA")
    {
        Write-Debug "Using system-assigned managed identity"
    }
elseif ($method -eq "UA")
    {
        Write-Debug "Using user-assigned managed identity"

        # Connects using the Managed Service Identity of the named user-assigned managed identity
        $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroup `
            -Name $userAssignedManagedIdentityWithoutRoles -DefaultProfile $AzureContext

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


### Authentication-Logic

#Connection-Parameter
$enterpriseApplicationClientId = "<ObjectID of SPN>"
$directoryTenantId = "<TENANT ID>

#Fetch Automation-Cert (Must be .pfx. The cert-"representaiton" must be stored in the called EnterpriseApplication)
try{
	$certificate = Get-AutomationCertificate -Name 'DeviceAssignmentRunbook'
	Write-Debug "Certificate fetched successfully"
}catch{
	Write-Output $_
	Write-Output "Could not fetch Automation-Certificate. Check if certificate still exists"
}

#Try to connect to MgGraph-Module with Automation-Certificate via Enterprise Application
try{
	Connect-MgGraph -ClientId $enterpriseApplicationClientId -TenantId $directoryTenantId -Certificate $certificate > $null
	Write-Debug "Successfully conntected to Graph-Module"

}catch{
	Write-Output $_
	Write-Output "Failed to connect to MgGraph-Module. Consult the admin"
	Write-Error "Failed to connect to MgGraph-Module"
	exit
}

### MAIN Business-Logic

#Grab all devices of User
Function FetchAllOwnedDevices {
    param(
         [Parameter(Mandatory=$true)][Object[]]$user
    )
	try{
		$listOfOwnedDevices = Get-MgUserOwnedDevice -UserId $user.id
	}catch{
		Write-Error "Could not fetch devices, which the user owns"
	}
    return $listOfOwnedDevices
}

#Check if device is already member of target-group
Function IsDeviceAlreadyMemberOfGroup {
    param(
         [Parameter(Mandatory=$true, Position=0)][Object[]]$singleOwnedDevice,
		 [Parameter(Mandatory=$true, Position=1)][Object[]]$devicesOfTargetGroup
    )
	foreach ($device in $devicesOfTargetGroup){
		if($device.id -eq $singleOwnedDevice.id){
			return $true
		}
	}return $false
	
}

#Add device to target-group
Function AddNewMemberToTargetGroup {
    param(
         [Parameter(Mandatory=$true, Position=0)][Object[]]$singleOwnedDevice,
		 [Parameter(Mandatory=$true, Position=1)][String]$businessUnitDeviceGroup
    )
	try{
		New-MgGroupMember -GroupId $businessUnitDeviceGroup -DirectoryObjectId $singleOwnedDevice.Id
		Write-Output "New Member $($singleOwnedDevice.id) added to DeviceTargetGroup $($businessUnitDeviceGroup)"
	}catch{
		Write-Error "Could not add new member $($singleOwnedDevice.id) to DeviceTargetGroup $($businessUnitDeviceGroup)"
	}
}

#Main Script Logic
Function Main {
	param(
         [Parameter(Mandatory=$true, Position=0)][Object[]]$userOfGroup,
		 [Parameter(Mandatory=$true, Position=1)][Object[]]$devicesOfTargetGroup,
		 [Parameter(Mandatory=$true, Position=2)][String]$businessUnitDeviceGroupID
    )
	try{
		#Iterate through user in BusinessUnit-UserGroup
		foreach($user in $userOfGroup){
			#Get azure-devices pro user
			$listOfOwnedDevices = FetchAllOwnedDevices($user)
			
			#If the user owns one or more device
			if($listOfOwnedDevices){
				#Check for each owned device. Could be multiple
				foreach ($singleOwnedDevice in $listOfOwnedDevices){
					#Is device a windows and if yes
					if ($singleOwnedDevice.additionalproperties.operatingSystem -eq "Windows"){
						#Check if this device is already member of target-group
						$isAlreadyMember = IsDeviceAlreadyMemberOfGroup $singleOwnedDevice $devicesOfTargetGroup
						#If it not add to targetgroup						
						if($isAlreadyMember -ne $true){
							AddNewMemberToTargetGroup $singleOwnedDevice $businessUnits[$buinessUnitKey]
						}
					}
				}
			}
		}	
	}catch{
		Write-Error $_
		Write-Error "Unexpected error!"
		exit
	}
}

# IT ALL STARTS HERE
try{
	#Take the ObjectIds from the HashTable
	foreach ($buinessUnitKey in $businessUnits.Keys){
		#Key = UserGroupId of BusinessUnit
		#Fetch all group-members
		$userOfGroup = Get-MgGroupMember -GroupId $buinessUnitKey

		#Value = DeviceGroupId of BusinessUnit
		#Fetch all group-members
		$devicesOfTargetGroup = Get-MgGroupMember -GroupId $businessUnits[$buinessUnitKey]

		Main $userOfGroup $devicesOfTargetGroup $businessUnits[$buinessUnitKey]
	}
}catch{
	Write-Output $_
	Write-Output "Failed to fetch MgGroupMember from Azure. Consult the admin"
	Write-Error "Failed to fetch MgGroupMember from Azure"
	exit
}



