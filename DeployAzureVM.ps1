
# Declaring the parameter that to give at run time 
param (
    [string] $subscriptionId = "YourSubscription",
	[string] $resourceGroupName = "bhavaniRG",
	[string] $location = "eastus",
    [string] $Template = "Templates\azuredeploy.json",
    [string] $ParameterFile = "Templates\azuredeploy.parameters.json",
	[switch] $Debug = $false
)
. .\libs\sshUtils.ps1
# Sigining in to the portal
Write-Host "Logging in..."
Login-AzureRmAccount

# Getting the subsciptions from the portal
Get-AzureRmSubscription -SubscriptionId $subscriptionId

#select subscription
Write-Host "Select the subscriptions from"
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
	Write-Host "Resourcegroup: '$resourceGroupName' already exists"
}

# Deploying VM and checking whether it is succeeded or not
Function DeploySingleVM{
$name="MyUbuntuVM"
Write-Host "Creating and Deploying the VM"
$RGdeployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $Template  -TemplateParameterFile $ParameterFile
if ($RGdeployment.ProvisioningState -eq "Succeeded")
{
    $MaxTimeOut=300
    $i=0
    while($MaxTimeOut -gt $i)
    {
        $vmDetail=Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $name  -Status
        if($vmDetail.Statuses[0].DisplayStatus -eq  "Provisioning succeeded")
        {
			$RGdeployment			#Displaying the ssh details of the VM
            Write-Host "Deployment completed succesfully"
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
    }
    GetIPAddress
}


#To get the PublicIp Address of the VM that created
Function GetIPAddress
{
Write-Host "getting the adminUsername and IPAddress"
$var = Get-Content $ParameterFile | ConvertFrom-Json
$adminUsername = $var.parameters.adminUsername.value
Write-Host "Username of vm is:"$adminUsername

$adminPassword = $var.Parameters.adminPassword.value
Write-Host "Password of vm is:"$adminPassword

$IPAddress=Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName  -Name MyPublicIp | Select-Object  IpAddress 
    Write-Host "IPAddress is" $IPAddress.IpAddress 
    $sshdetails= 'ssh ' + $adminUsername + '@' + $IPAddress.IpAddress 
    $sshdetails
} 
    DeploySingleVM

 if($vmDetail.Statuses[0].DisplayStatus -eq "Provisioning succeeded")
 {
    Write-Host "vm deploy is True"
 }
 else
 { 
    Write-Host "vm deploy is False"
 }
    
    