
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
    $vm
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
