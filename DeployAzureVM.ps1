
# Declaring the parameter that to give at run time 
param (
	[string] $subscriptionId = "Your subscription",
	[string] $resourceGroupName = "MyRG",
	[string] $location = "eastus",
    [string] $TemplateFile = "Templates\azuredeploy.json",
    [string] $TemplateParameterFile = "Templates\azuredeploy.parameters.json",
	[switch] $Debug = $false
)

. .\libs\sshUtils.ps1
# Sigining in to the portal
Write-Host "Logging in..."
Login-AzureRmAccount

# Getting the subsciptions from the portal
Get-AzureRmSubscription -SubscriptionId $subscriptionId

# select subscription
Write-Host  -ForegroundColor Yellow "Set the subscriptions";
Set-AzureRmContext -Subscription $subscriptionId

# Deploying VM and checking whether it is succeeded or not
Function DeploySingleLinuxVM()
{
	$name="MyUbuntuVM"
	$VMdeploy = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $TemplateFile  -TemplateParameterFile $TemplateParameterFile
	if ($VMdeploy.ProvisioningState -eq "Succeeded")
	{
		$MaxTimeOut=300
		$i=0
		while($MaxTimeOut -gt $i)
		{
			$vmDetail=Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $name  -Status
			if($vmDetail.Statuses[0].DisplayStatus -eq  "Provisioning succeeded")
			{
				Write-Host "Created VM successfully"
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
			Write-Host  -ForegroundColor Yellow "Deployment failed"
		} 
    
	}
	#calling the function to get the sshdetails
	Getsshdetails
}

#Function get the Username, Password and PublicIp Address of the VM that created
Function Getsshdetails()
{
	Write-Host  -ForegroundColor Yellow "Getting the Username and IpAddress of the VM"
    if ($VMdeploy.ProvisioningState -eq "Succeeded")
    {
        $var=Get-Content $TemplateParameterFile | ConvertFrom-Json 
        $Username=$var.parameters.adminUsername.value
        Write-Host " UserName of the VM is : "$Username

        $Password=$var.parameters.adminPassword.value 
        Write-Host " Password is : " $Password

        $IPAddress=Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName  -Name MyPublicIp | Select-Object  IpAddress
        Write-Host  " IPAddress of VM is :" $IPAddress.IpAddress

        $sshdetails= 'ssh ' + $Username + '@' + $IPAddress.IpAddress
        $sshdetails  
    }
    else
    {
        Write-Host "VM does not exit"
    }
}

# Create or using existing resourceGroup 
Write-Host  -ForegroundColor Yellow "Verifying the ResourceGroup exist or not: '$resourceGroupName'"
$resourcegroup = Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -erroraction silentlycontinue
if(!$resourcegroup)
{
	Write-Host  -ForegroundColor Yellow "Creating ResourceGroup: '$resourceGroupName'"
	New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
}
else
{
	Write-Host  -ForegroundColor Yellow "ResourceGroupName is alresy exisited"
}

Write-Host -ForegroundColor Yellow "Creating and Deploying the VM"

#Calling the function to create and deploy the VM
DeploySingleLinuxVM




 