
param(
	[string]
	$subscriptionId,

	[Parameter(Mandatory=$True)]
	[string]
	$resourceGroupName,

	[Parameter(Mandatory=$True)]
	[string]
	$location
	
)
# sign in
Write-Host "Logging in...";
#Login-AzureRmAccount

# Getting the subsciptions from the portal
$subscriptions=Get-AzureRmSubscription -SubscriptionId $subscriptionId

#select subscription
Write-Host "Select the subscriptions from";
Set-AzureRmContext -Subscription $SubID

#Create or exists resourceGroup 
Write-Host "Verifying ResourceGroup: '$resourceGroupName'"
$resourcegroup = Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -erroraction silentlycontinue
if(!$resourcegroup)
{
	Write-Host "Creating ResourceGroup: '$resourceGroupName'"
	New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
}
else
{
	Write-Host "resourcegroup is exisited"
}

#Deploy VM
$name="MyUbuntuVM"
$vm = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "Templates\azuredeploy.json"  -TemplateParameterFile "Templates\azuredeploy.parameters.json"
if ($vm.ProvisioningState -eq "Succeeded")
{
		$MaxTimeOut=300
		$i=0
		while($MaxTimeOut -gt $i)
		{
			$vmDetail=Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $name  -Status
			if($vmDetail.Statuses[0].DisplayStatus -eq  "Provisioning succeeded")
			{
				Write-Host "Deployment completed succesfully"
				break
			}
			else
			{
				Write-Host -NoNewline "." #print a . without newline
			}
			$i=$i+1
		}
		if ($MaxTimeOut -eq $i)
		{
			Write-Host "Deployment failed"
		} 
}
#Get Ipaddress,Username,Password,ssh details
if($vm.ProvisioningState -eq "Succeeded")
{
	$var = Get-Content "Templates\azuredeploy.parameters.json" | ConvertFrom-Json
	$adminUsername = $var.parameters.adminUsername.value
	Write-Host "Username of vm is:"$adminUsername

	$adminPassword = $var.Parameters.adminPassword.value
	$SPassword= ConvertTo-SecureString $adminPassword -AsPlainText -Force 
	Write-Host "Password of vm is:"$SPassword

	$IPAddress=Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName  -Name MyPublicIp | Select-Object  IpAddress 
    Write-Host "IPAddress is" $IPAddress.IpAddress 
    $sshdetails= 'ssh ' + $adminUsername + '@' + $IPAddress.IpAddress 
    $sshdetails
}
else
{
	Write-Host "Deployment failed"
}

