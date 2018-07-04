
# Declaring the parameter that to give at run time 
param (
    [string] $subscriptionId = "YourSubscription",
    [string] $resourceGroupName = "MyRG",
    [string] $location = "eastus",
    [string] $Template = "Templates\azuredeploy.json",
    [string] $TemplateFile = "Templates\azuredeploy.parameters.json",
    [switch] $Debug = $false
)

. .\libs\sshUtils.ps1
# Sigining in to the portal
LogMsg 0 "Info : Logging in..."
Login-AzureRmAccount

# Getting the subsciptions from the portal
Get-AzureRmSubscription -SubscriptionId $subscriptionId

#select subscription
LogMsg 0 "Info : Select the subscriptions from"
Set-AzureRmContext -Subscription $subscriptionId

# Create or using existing resourceGroup 
LogMsg 0 "Info : Verifying ResourceGroupName exit or not: '$resourceGroupName'"
$resourcegroup = Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -erroraction silentlycontinue
if(!$resourcegroup)
{
    LogMsg 0 "Info : Creating ResourceGroup: '$resourceGroupName'"
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location 
}
else
{
    LogMsg 0 "Info : Resourcegroup: '$resourceGroupName' already exists"
}

# Deploying VM and checking whether it is succeeded or not
Function DeploySingleVM
{
    $name="MyUbuntuVM"
    LogMsg 0 "Info : Creating and Deploying the VM"
    $RGdeployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $Template  -TemplateParameterFile $TemplateFile
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
                LogMsg 0 "Info : Deployment completed succesfully"
                break
            }
            else
            {
                LogMsg 0 "Info : -NoNewline "."  "	#print a . without newline
            }
            $i=$i+1
        }
        if ($MaxTimeOut -eq $i)
        {
            LogMsg 0 "Info : Deployment failed"
        }       
    }
    GetIPAddress    
}


#To get the PublicIp Address of the VM that created
Function GetIPAddress
{
    LogMsg 0 "Info : getting the adminUsername and IPAddress"
    $var = Get-Content "Templates\azuredeploy.parameters.json" | ConvertFrom-Json
    $adminUsername = $var.parameters.adminUsername.value
    LogMsg 0 "Info : Username of vm is:$adminUsername"
    $adminPassword = $var.Parameters.adminPassword.value
    LogMsg 0 "Info : Password of vm is:$adminPassword"

    $IPAddress=Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName  -Name MyPublicIp | Select-Object  IpAddress 
    LogMsg 0 "Info : IPAddress is $IPAddress.IpAddress"
    $sshdetails= 'ssh ' + $adminUsername + '@' + $IPAddress.IpAddress 
    $sshdetails
}
DeploySingleVM
