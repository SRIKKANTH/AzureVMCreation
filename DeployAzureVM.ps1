
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
# sign in
Write-Host "Logging in...";
Login-AzureRmAccount

# Getting the subsciptions from the portal
$subscriptions=Get-AzureRmSubscription -SubscriptionId $subscriptionId

#select subscription
Write-Host "Select the subscriptions from";
Set-AzureRmContext -Subscription 23949b93-8072-4516-bbc2-955255d022fd

#Create or exists resourceGroup 
$resourcegroup = Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -erroraction silentlycontinue
if(!$resourcegroup)
 {
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
 }
else
 {
    Write-Host "resourcegroup is exisited"
 }

#Deploy VM
$name="MyUbuntuVM"
$vm = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "azuredeploy.json"  -TemplateParameterFile "azuredeploy.parameters.json"
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
