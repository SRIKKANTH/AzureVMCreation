# Declaring the parameter that to give at run time 
param(
	[Parameter(Mandatory=$True)]
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
Login-AzureRmAccount

# Getting the subsciptions from the portal
$subscriptions=Get-AzureRmSubscription -SubscriptionId $subscriptionId

#select subscription
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
$Deployvm = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "Templates\azuredeploy.json" -TemplateParameterFile "Templates\azuredeploy.parameters.json"
if ($Deployvm.ProvisioningState -eq "Succeeded")
{
    $MaxTimeOut=300
    $i=0
    while($MaxTimeOut -gt $i)
    {
        $vmDetail=Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $name  -Status
        if($vmDetail.Statuses[0].DisplayStatus -eq  "Provisioning succeeded")
        {	
            Write-Host "Deployment completed succesfully so VM has created "
            break
        }
        else
        {
            Write-Host -NoNewline "." 	#print a . without newline
        }
        $i=$i+1
    }
    if ($MaxTimeOut -eq $i)
    {
        Write-Host "Deployment failed"
    } 
    GetIPAddress
}

#To get the Username, Password and PublicIp Address of the VM that created
Function GetIPAddress
{
	Write-Host "Getting the IpAddress of the VM"
	if ($Deployvm.ProvisioningState -eq "Succeeded")
	{
		$var=Get-Content "Templates\azuredeploy.parameters.json"| ConvertFrom-Json 
		$Username=$var.parameters.adminUsername.value
		Write-Host " UserName of the VM is "$Username

		$Password=$var.parameters.adminPassword.value 
		$SPassword= ConvertTo-SecureString $Password -AsPlainText -Force
		Write-Host " The password is " $SPassword

		$IPAddress=Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName  -Name MyPublicIp | Select-Object  IpAddress
		Write-Host "IPAddress is" $IPAddress.IpAddress

		$sshdetails= 'ssh ' + $Username + '@' + $IPAddress.IpAddress
		$sshdetails
	}
	else
	{
		Write-Host "VM does not exit"
	}
}
