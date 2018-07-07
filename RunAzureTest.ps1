<#
    Usage:
    .\RunAzureTest.ps1 -subscriptionId "Your subscriptionId" -resourceGroupName "Resource Group Name" -vmSize "VM size to be deployed"
#>
 
param (
    [string] $subscriptionId = "UnDeclared",
    [string] $resourceGroupName = "MyTestRG",
    [string] $TemplateType = "1VM_1ManagedDisk",
    [string] $TestName = "UnDeclared",
    [string] $location = "eastus",
    [string] $vmSize = "UnDeclared",
    [switch] $Debug = $false
)

. .\libs\AzureLibs.ps1
. .\libs\sshUtils.ps1

<#
#   Script execution starts from here..
#>
$TimeElapsed = [Diagnostics.Stopwatch]::StartNew()

$RGDetails = GetRGDetails $TestName

LoginAzureAccount $RGDetails.subscriptionId 
VerifyAndCleanUpResourceGroup $RGDetails -DeleteIfExists
DeploySingleVM  $RGDetails

$VMDetails = GetVMDetails $RGDetails
""
LogMsg 0 "Info: VM login detais: ssh $($VMDetails.UserName)@$($VMDetails.IP) Password: $($VMDetails.PassWord)" "White" "Black"
""

$VMbootStatus=WaitTillMachineBoots $VMDetails

if ( $VMbootStatus -eq "True")
{
    LogMsg 0 "Info: Virtual Machine '$($VMDetails.VMName)' is up and ready for testing.."
}
else
{
    LogMsg 0 "Error: Failed to boot VM: '$($VMDetails.VMName)'"
    CleanUpResourceGroup $RGDetails 
}

UploadFiles -VMDetails $VMDetails -RGDetails  $RGDetails 
RunTestScript -VMDetails $VMDetails -RGDetails  $RGDetails 
DownloadFilesAndLogs $VMDetails

""
LogMsg 0 "Info: Logs are located at '$LogFolder'" "White" "Blue"
""
$TimeElapsed.Stop()
LogMsg 0 "Info: Total execution time: $($TimeElapsed.Elapsed.TotalSeconds) Seconds"
