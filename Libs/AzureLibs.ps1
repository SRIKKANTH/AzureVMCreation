
function LogMsg([int]$level, [string]$msg, [string]$BackGround, [string]$ForeGround)  
{
<#
.Synopsis
    Write a message to the log file and the console.
.Description
    Add a time stamp and write the message to the test log.  In
    addition, write the message to the console.  Color code the
    text based on the level of the message.
.Parameter level
    Debug level of the message
.Parameter msg
    The message to be logged
.Example
    LogMsg 3 "This is a test"
#>

    if ($level -le $dbgLevel)
    {
        $now = [Datetime]::Now.ToString("MM/dd/yyyy HH:mm:ss : ")
        ($now + $msg) | out-file -encoding ASCII -append -filePath $logfile
		if ( $ForeGround -eq "" )
		{
			$ForeGround = "Gray"
			if ( $msg.StartsWith("Error"))
			{
				$ForeGround = "red"
			}
			elseif ($msg.StartsWith("Warn"))
			{
				$ForeGround = "Yellow"
			}
			elseif ($msg.StartsWith("Debug"))
			{
				$ForeGround = "Green"
			}
			else
			{
				$ForeGround = "White"
			}
		}
		if ($BackGround -ne "")
		{
			write-host -f $ForeGround -b $BackGround "$msg"
		}
		else
		{
			write-host -f $ForeGround "$msg"
		}
    }
}


#GetVMDetails $VMDetails, $resourceGroupName, $VMName, $ParametersFile)
Function GetVMDetails
{
    [cmdletbinding()]
    Param (
        [Object[]] $RGDetails
    ) 
    LogMsg 0 "Info : Getting the Username, Password and IPAddress of the VM"
    
    $VMDetails = New-Object -TypeName PSObject -Property $VMproperties

    $VMParams = Get-Content $RGDetails.ParametersFile | ConvertFrom-Json
    $VMDetails.VMName = $VMParams.parameters.VMName.value
    $VMDetails.UserName = $VMParams.parameters.adminUsername.value
    $VMDetails.PassWord = $VMParams.Parameters.adminPassword.value
        
    $VMDetails.IP = (AzureRmVmPublicIP -ResourceGroupName $RGDetails.resourceGroupName -VMName $VMDetails.VMName).PublicIP

    return $VMDetails
}

function  LoginAzureAccount
{
    [cmdletbinding()]
    Param (
        [string] $subscriptionId = "UnDeclared"
    ) 
    # Sigining in to the Azure Account
    LogMsg 0 "Info : Logging into Azure Account"
    try {
        Login-AzureRmAccount
    }
    catch {
        LogMsg 0 "Error : Login failed"
        exit
    }
    LogMsg 0 "Info : Azure Login succesful!"
    
    if ($subscriptionId -ne "UnDeclared")
    {
        #Select subscription
        LogMsg 0 "Info : Select the subscription: $subscriptionId"
        Select-AzureRmSubscription -SubscriptionID $subscriptionId
    }
}
function VerifyAndCleanUpResourceGroup
{
    [cmdletbinding()]
    Param (
        [Object[]] $RGDetails,
        [switch] $DeleteIfExists = $False
    ) 
    # Create or using existing resourceGroup 
    LogMsg 0 "Info: Verifying if ResourceGroupName $($RGDetails.resourceGroupName) exists or not.."
    try {
        $resourcegroup = Get-AzureRmResourceGroup -Name $RGDetails.resourceGroupName -erroraction silentlycontinue
        if($resourcegroup)
        {
            LogMsg 5 "Debug: Resourcegroup: $($RGDetails.resourceGroupName) already exists"
            if ($DeleteIfExists)
            {
                LogMsg 0 "Warn: Deleting Resourcegroup: $($RGDetails.resourceGroupName) as '-DeleteIfExists' option is passed"
                Remove-AzureRmResourceGroup -Name $RGDetails.resourceGroupName -Force
                LogMsg 0 "Info: Deleting Resourcegroup: $($RGDetails.resourceGroupName) completed."
                
                LogMsg 0 "Info: Re-creating ResourceGroup: $($RGDetails.resourceGroupName) ..."
                New-AzureRmResourceGroup -Name $RGDetails.resourceGroupName -Location $RGDetails.location >$null 2>&1
                LogMsg 0 "Info: Re-creating ResourceGroup: $($RGDetails.resourceGroupName) done!"
            }
        }
        else {
            LogMsg 0 "Info: Creating ResourceGroup: $($RGDetails.resourceGroupName)"
            New-AzureRmResourceGroup -Name $RGDetails.resourceGroupName -Location $RGDetails.location >$null 2>&1               
        }
    }
    catch {
        LogMsg 0 "Info: Creating ResourceGroup: $($RGDetails.resourceGroupName)"
        New-AzureRmResourceGroup -Name $RGDetails.resourceGroupName -Location $RGDetails.location >$null 2>&1
    }
}

function CleanUpResourceGroup
{
    [cmdletbinding()]
    Param (
        [Object[]] $RGDetails
    ) 
    # Create or using existing resourceGroup 
    LogMsg 0 "Info : Removing ResourceGroupName $($RGDetails.resourceGroupName) .."
    try 
    {
        Remove-AzureRmResourceGroup -Name $RGDetails.resourceGroupName -Verbose -Force
        LogMsg 0 "Info : Deleting Resourcegroup: $($RGDetails.resourceGroupName) completed."
    }
    catch {
        LogMsg 0 "Info : Failed to delete ResourceGroup: $($RGDetails.resourceGroupName)"
    }
}

<#
#   Deploying VM and checking whether it is succeeded or not
#   Syntax GetRGDetails <TestName>
#>

function GetRGDetails 
{
    [cmdletbinding()]
    Param (
        [string] $TestName = "UnDeclared"
    )

    $RGDetails = New-Object -TypeName PSObject -Property $RGproperties
    
    $RGDetails.resourceGroupName = $resourceGroupName
    $RGDetails.subscriptionId = $subscriptionId

    $TestDefinitions = Get-Content "Templates\TestDefinitions.json" | ConvertFrom-Json
    LogMsg 5 "Debug: TestDefinitions : `n $($TestDefinitions | ConvertTo-Json)"

    $RGDetails.TestDetails = $TestDefinitions.TestDefinitions.$TestName
    LogMsg 5 "Debug: TestDetails : `n $($RGDetails.TestDetails | ConvertTo-Json)"

    if ($RGDetails.TestDetails)
    {
        $RGDetails.TemplateFile = $TestDefinitions.Templates.$TemplateType.TemplateFile
        $RGDetails.ParametersFile = $TestDefinitions.Templates.$TemplateType.ParametersFile
        LogMsg 5 "Debug: TemplateFile : $($RGDetails.TemplateFile)"
        LogMsg 5 "Debug: ParametersFile : $($RGDetails.ParametersFile)"
        if (-not $RGDetails.TemplateFile)
        {
            LogMsg 0 "Error: Unknown Test TemplateType: '$TemplateType'"
            exit
        }
        else {
            LogMsg 5 "Debug: Contents of ParametersFile : `n $(Get-Content $RGDetails.ParametersFile )"
        }    
    }
    else 
    {
        LogMsg 0 "Error: Unknown Test: '$TestName'"
        exit
    }

    # Creating temp Parameters file with given VM size
    if ( $RGDetails.ParametersFile -ne "UnDeclared" )
    {
        $VMParams = Get-Content $RGDetails.ParametersFile | ConvertFrom-Json
        $RGDetails.Location = $VMParams.parameters.location.value
        $RGDetails.VMName = $VMParams.parameters.VMName.value

        if ( $vmSize -ne "UnDeclared" )
        {
            $VMParams.parameters.vmSize.value = $vmSize
            $VMParams | ConvertTo-Json -depth 100 | Set-Content "$($LogFolder)\azuredeploy.parameters_temp.json"
            $RGDetails.ParametersFile = "$($LogFolder)\azuredeploy.parameters_temp.json"
        }
    }

    return $RGDetails
}

<#
#   Deploying VM and checking whether it is succeeded or not
#   Syntax DeploySingleVM $RGDetails
#>
Function DeploySingleVM
{
    [cmdletbinding()]
    Param (
        [Object[]] $RGDetails
    )

    LogMsg 0 "Info: Deploying the ResourceGroup '$($RGDetails.ResourceGroupName)'..."
    $RGdeployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $RGDetails.ResourceGroupName -TemplateFile $RGDetails.TemplateFile -TemplateParameterFile $RGDetails.ParametersFile
    
    if ($RGdeployment.ProvisioningState -eq "Succeeded")
    {
        $MaxTimeOut=300
        $i=0
        while($MaxTimeOut -gt $i)
        {
            $vmStatus=Get-AzureRmVM -ResourceGroupName $RGDetails.ResourceGroupName -Name $RGDetails.vmName  -Status
            if($vmStatus.Statuses[0].DisplayStatus -eq  "Provisioning succeeded")
            {
                LogMsg 0 "Info: Deployment completed succesfully"
                break
            }
            else
            {
                <#
                    Warning: Don't use LogMsg here.
                #>
                Write-Host "." -NoNewline
            }
            $i=$i+1
        }

        if ($MaxTimeOut -eq $i)
        {
            LogMsg 0 "Error: Deployment failed"
        }       
    }    
}

function WaitTillMachineBoots 
{
    [cmdletbinding()]
    Param (
        [Object[]] $VMDetails
    ) 
    LogMsg 5 "Debug: Checking if VM is up:"
    for($count = 0; $count -le 30; $count++ )
    {
        $output = echo y | .\bin\plink.exe  -pw $VMDetails.PassWord -P 22 -l $VMDetails.UserName $VMDetails.IP "uptime" 2>&1
        $output = $output | Select-String -Pattern 'load average'

        if ( $output )
        {
            break
        }
        else
        {
            <#
                Warning: Don't use LogMsg here.
            #>            
            Write-Host "." -NoNewline  
        }
    }

    ""
    if ( $output )
    {
        LogMsg 5 "Debug: VM is up"
        return $true
    }
    else {
        LogMsg 5 "Debug: VM isn't up"
        return $false
    }    
}

function DownloadFilesAndLogs 
{
    [cmdletbinding()]
    Param (
        [Object[]] $VMDetails
    ) 
	$VMLogDownloadFolder = $(Join-Path $LogFolder $vm.vmName)

	If( -not (test-path $VMLogDownloadFolder))
	{
		New-Item -ItemType Directory -Force -Path $VMLogDownloadFolder | out-null
	}
    RunLinuxCmd -username $VMDetails.UserName -password $VMDetails.PassWord -ip $VMDetails.IP -port 22 -command "dmesg > dmesg.log"  -runAsSudo -ignoreLinuxExitCode
    RunLinuxCmd -username $VMDetails.UserName -password $VMDetails.PassWord -ip $VMDetails.IP -port 22 -command "cat /var/log/messages >  messages.log"  -runAsSudo -ignoreLinuxExitCode
    RunLinuxCmd -username $VMDetails.UserName -password $VMDetails.PassWord -ip $VMDetails.IP -port 22 -command "cat /var/log/syslog > syslog.log"  -runAsSudo -ignoreLinuxExitCode
     
	RemoteCopy -download -downloadFrom $VMDetails.IP -files "*" -downloadTo $VMLogDownloadFolder -port $VMDetails.Port -username $VMDetails.UserName -password $VMDetails.PassWord
}

<#
Upload files related to the test
Syntax:
    UploadFiles -VMDetails $VMDetails -RGDetails  $RGDetails 
#>
function UploadFiles
{
    [cmdletbinding()]
    Param (
        [Object[]] $VMDetails,
        [Object[]] $RGDetails
    ) 
    .\bin\dos2unix.exe .\LinuxScripts\* 2>&1  >$null
    $SupportFilesList = $RGDetails.TestDetails.SupportFiles -split ","
    $SupportFilesList = $RGDetails.TestDetails.TestScript + $SupportFilesList
    if ($SupportFilesList.count -ne 0 )
    {
        ForEach ( $File in $SupportFilesList )
        {
            LogMsg 5 "Debug: Uploading $File"
            RemoteCopy -uploadTo $VMDetails.IP -port $VMDetails.Port -files ".\LinuxScripts\$File" -username $VMDetails.UserName -password $VMDetails.PassWord -upload
        }
    }
    else 
    {
        LogMsg 5 "Debug: No files are uploaded as both 'SupportFiles' & 'TestScript' are empty"
    }
}

<#
Syntax:
    RunTestScript -VMDetails $VMDetails -RGDetails  $RGDetails
#>

function RunTestScript
{
    [cmdletbinding()]
    Param (
        [Object[]] $VMDetails,
        [Object[]] $RGDetails,
        [int16] $runMaxAllowedTime=500
    ) 
    RunLinuxCmd -username $VMDetails.UserName -password $VMDetails.PassWord -ip $VMDetails.IP -port $VMDetails.Port -command "bash $($RGDetails.TestDetails.TestScript) > ConsoleLogFile.log" -runAsSudo -runMaxAllowedTime $runMaxAllowedTime
}

function ValidateInputs 
{
    if ( $subscriptionId -eq "UnDeclared")
    {
        LogMsg 0 "Error: Please provide valid subscriptionId"
        Exit
    }
    
    if ( $TestName -eq "UnDeclared")
    {
        LogMsg 0 "Error: Please provide valid TestName"
        Exit
    }    
}

<#####################################################################################################
#   Script execution starts from here..
#####################################################################################################>

$dbgLevel_Debug=10
$dbgLevel_Release=1
if ($Debug)
{
	$dbgLevel=$dbgLevel_Debug
}
else
{
	$dbgLevel=$dbgLevel_Release
}

$WorkingDir=(Get-Item -Path ".\").FullName
$DateString=$((Get-Date).ToString('yyyy_MM_dd_hh_mm_ss'))
$LogDir="Logs\$DateString"
$LogFolder="$($WorkingDir)\$($LogDir)"
$logfile="$($LogFolder)\LocalLogFile.log"

New-Item -ItemType Directory -Force -Path $LogFolder | out-null

ValidateInputs

$RGproperties = @{  'subscriptionId' = "UnDeclared";
                    'resourceGroupName' = "UnDeclared";
                    'Location' = "UnDeclared";
                    'VMName' = "UnDeclared";
                    'TemplateFile' = "UnDeclared";
                    'ParametersFile' = "UnDeclared";
                    'TestDetails' = {}
                }

$VMproperties = @{  'IP'="UnDeclared";
                    'Port'=22;
                    'VMName'="UnDeclared";
                    'UserName'="UnDeclared";
                    'PassWord'="UnDeclared"
                }
