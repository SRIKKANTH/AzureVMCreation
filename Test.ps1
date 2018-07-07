<#
Use this to test your changes without actually deploying the VM
#>
$Debug = $false
$TestName = "DeploySingleVM"
$TemplateType = "1VM_1ManagedDisk" 

. .\libs\AzureLibs.ps1
. .\libs\sshUtils.ps1


$RGDetails = GetRGDetails $TestName
$VMDetails = New-Object -TypeName PSObject -Property $VMproperties
$VMDetails.IP = "10.135.16.212"
$VMDetails.Port = 22
$VMDetails.VMName = "UnDeclared"
$VMDetails.UserName="naga"
$VMDetails.PassWord="SamplePassword"

#WaitTillMachineBoots $VMDetails
UploadFiles -VMDetails $VMDetails -RGDetails  $RGDetails 


Exit
