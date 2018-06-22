#Declaring the parameter that to give at run time 
param(
 [string]
$subscriptionId,

 [Parameter(Mandatory=$True)]
[string]
$resourceGroupName,

[Parameter(Mandatory=$True)]
[string]
$location,

[Parameter(Mandatory=$True)]
[string]
$deploymentName
)

# Sigining in to the portal
Write-Host "Logging in...";
Login-AzureRmAccount

# Getting the subsciptions from the portal
$subscriptions=Get-AzureRmSubscription -SubscriptionId $subscriptionId

#select subscription
Write-Host "Select the subscriptions from";
Set-AzureRmContext -Subscription 23949b93-8072-4516-bbc2-955255d022fd

#Create or use existing resourceGroup
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup) 
{ 
    if(!$rglocation) 
    { 
        $rglocation = Read-Host "resourceGroupLocation"; 
    } 
    Write-Host "Creating resource group '$resourceGroupName' in location '$location'"; 
    $resourcerg=New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
    $resourcerg
     if($resourcerg.ProvisioningState -eq "Succeeded")
      {
       Write-Host "Resourcegroup created successfully"
      }
     else
     {
      Write-Host "Resourcegroup is not created"
     }
    if($resourcerg.ProvisioningState -ne "Succeeded")
     {
      Write-Host "Resourcegroup not yet created"
     }
}  
else
{ 
   Write-Host "Using existing resource group '$resourceGroupName"; 
} 

#Deploying VM and checking whether it is succeeded or not
$name="MyUbuntuVM"
$vm = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile C:\Users\LENORA\Desktop\Powershell\azuredeploy.json  -TemplateParameterFile C:\Users\LENORA\Desktop\Powershell\AzureDeployParameters.json
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
    Write-Host -NoNewline "." 
   }
  $i=$i+1
}
if ($MaxTimeOut -eq $i)
{
   Write-Host "Deployment failed"
}
}
