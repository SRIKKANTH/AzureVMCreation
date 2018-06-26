# Declaring the parameter that to give at run time 
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
# Sigining in to the portal
Write-Host "Logging in...";
#Login-AzureRmAccount

# Getting the subsciptions from the portal
$subscriptions=Get-AzureRmSubscription
# select subscription
Write-Host "Select the subscriptions from";
Set-AzureRmContext -Subscription $subscriptionId
# Create or using existing resourceGroup 

Write-Host "Verifying ResourceGroupName exit or not: '$resourceGroupName'"
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

# Deploying VM and checking whether it is succeeded or not
$name="MyUbuntuVM"
Write-Host "Creating and Deploying the VM"
$vm = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "Templates\azuredeploy.json" -TemplateParameterFile "Templates\azuredeploy.parameters.json"
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

#To get the PublicIp Address of the VM that created
Write-Host "Getting the IpAddress of the VM"
if ($vm.ProvisioningState -eq "Succeeded")
{
    Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName  -Name MyPublicIp | Select ResourceGroupName, Name, IpAddress
}
else
{
    Write-Host "IpAddress not found"
}
