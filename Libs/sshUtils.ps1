
Function LogErr ([string]$msg)
{
	LogMsg 0 "Error: $($msg)"
}

Function RemoteCopy($uploadTo, $downloadFrom, $downloadTo, $port=22, $files, $username, $password, [switch]$upload, [switch]$download, [switch]$usePrivateKey, [switch]$doNotCompress) #Removed XML config
{
	$retry=1
	$maxRetry=20
	if($upload)
	{
		if ($files)
		{
			$fileCounter = 0
			$tarFileName = ($uploadTo+"@"+$port).Replace(".","-")+".tar"
			foreach ($f in $files.Split(","))
			{
				if ( !$f )
				{
					continue
				}
				else
				{
					if ( ( $f.Split(".")[$f.Split(".").count-1] -eq "sh" ) -or ( $f.Split(".")[$f.Split(".").count-1] -eq "py" ) )
					{
						$out = .\bin\dos2unix.exe $f 2>&1
						LogMsg 9 "Debug: $out"
					}
					$fileCounter ++
				}
			}
			if (($fileCounter -gt 2) -and (!($doNotCompress)))
			{
				$tarFileName = ($uploadTo+"@"+$port).Replace(".","-")+".tar"
				foreach ($f in $files.Split(","))
				{
					if ( !$f )
					{
						continue
					}
					else
					{
						LogMsg 9 "Debug: Compressing $f and adding to $tarFileName"
						$CompressFile = .\bin\7za.exe a $tarFileName $f
						if ( $CompressFile -imatch "Everything is Ok" )
						{
							$CompressCount += 1
						}
					}
				}
				if ( $CompressCount -eq $fileCounter )
				{
					$retry=1
					$maxRetry=20
					while($retry -le $maxRetry)
					{
						if($usePrivateKey)
						{
							LogMsg 0 "Info: Uploading $tarFileName to $username : $uploadTo, port $port using PrivateKey authentication"
							echo y | .\bin\pscp -i .\ssh\$sshKey -q -P $port $tarFileName $username@${uploadTo}:
							$returnCode = $LASTEXITCODE
						}
						else
						{
							LogMsg 0 "Info: Uploading $tarFileName to $username : $uploadTo, port $port using Password authentication"
							$curDir = $PWD
							$uploadStatusRandomFile = "$LogDir\UploadStatusFile" + (Get-Random -Maximum 9999 -Minimum 1111) + ".txt"
							$uploadStartTime = Get-Date
							$uploadJob = Start-Job -ScriptBlock { cd $args[0]; Write-Host $args; Set-Content -Value "1" -Path $args[6]; $username = $args[4]; $uploadTo = $args[5]; echo y | .\bin\pscp -v -pw $args[1] -q -P $args[2] $args[3] $username@${uploadTo}: ; Set-Content -Value $LASTEXITCODE -Path $args[6];} -ArgumentList $curDir,$password,$port,$tarFileName,$username,${uploadTo},$uploadStatusRandomFile
							sleep -Milliseconds 100
							$uploadJobStatus = Get-Job -Id $uploadJob.Id
							$uploadTimout = $false
							while (( $uploadJobStatus.State -eq "Running" ) -and ( !$uploadTimout ))
							{
								Write-Host "." -NoNewline
								$now = Get-Date
								if ( ($now - $uploadStartTime).TotalSeconds -gt 600 )
								{
									$uploadTimout = $true
									LogErr "Upload Timout!"
								}
								sleep -Seconds 1
								$uploadJobStatus = Get-Job -Id $uploadJob.Id
							}
							Write-Host ""
							$returnCode = Get-Content -Path $uploadStatusRandomFile
							Remove-Item -Force $uploadStatusRandomFile | Out-Null
							Remove-Job -Id $uploadJob.Id -Force | Out-Null
						}
						if(($returnCode -ne 0) -and ($retry -ne $maxRetry))
						{
							LogMsg 0 "Warn: Error in upload, Attempt $retry. Retrying for upload"
							$retry=$retry+1
							WaitFor -seconds 10
						}
						elseif(($returnCode -ne 0) -and ($retry -eq $maxRetry))
						{
							LogMsg 0 "Error: Failed to upload after $retry attempts. Are you passing right VM credentials?"
							$retry=$retry+1
							Throw "Error: Failed to upload after $retry attempts. Are you passing right VM credentials?"
						}
						elseif($returnCode -eq 0)
						{
							LogMsg 0 "Info: Upload Success after $retry Attempt"
							$retry=$maxRetry+1
						}
					}
					LogMsg 0 "Info: Removing compressed file : $tarFileName"
					Remove-Item -Path $tarFileName -Force 2>&1 | Out-Null
					LogMsg 0 "Info: Decompressing files in VM ..."
					if ( $username -eq "root" )
					{
						$out = RunLinuxCmd -username $username -password $password -ip $uploadTo -port $port -command "tar -xf $tarFileName"
					}
					else
					{
						$out = RunLinuxCmd -username $username -password $password -ip $uploadTo -port $port -command "tar -xf $tarFileName" -runAsSudo
					}

				}
				else
				{
					Throw "Failed to compress $files"
					Remove-Item -Path $tarFileName -Force 2>&1 | Out-Null
				}
			}
			else
			{
				$files = $files.split(",")
				foreach ($f in $files)
				{
					if ( !$f )
					{
						continue
					}
					$retry=1
					$maxRetry=20
					$testFile = $f.trim()
					$recurse = ""
					while($retry -le $maxRetry)
					{
						if($usePrivateKey)
						{
							LogMsg 0 "Info: Uploading $testFile to $username : $uploadTo, port $port using PrivateKey authentication"
							echo y | .\bin\pscp -i .\ssh\$sshKey -q -P $port $testFile $username@${uploadTo}:
							$returnCode = $LASTEXITCODE
						}
						else
						{
							LogMsg 0 "Info: Uploading $testFile to $username : $uploadTo, port $port using Password authentication"
							$curDir = $PWD
							$uploadStatusRandomFile = "$LogDir\UploadStatusFile" + (Get-Random -Maximum 9999 -Minimum 1111) + ".txt"
							$uploadStartTime = Get-Date
							$uploadJob = Start-Job -ScriptBlock { cd $args[0]; Write-Host $args; Set-Content -Value "1" -Path $args[6]; $username = $args[4]; $uploadTo = $args[5]; echo y | .\bin\pscp -v -pw $args[1] -q -P $args[2] $args[3] $username@${uploadTo}: ; Set-Content -Value $LASTEXITCODE -Path $args[6];} -ArgumentList $curDir,$password,$port,$testFile,$username,${uploadTo},$uploadStatusRandomFile
							sleep -Milliseconds 100
							$uploadJobStatus = Get-Job -Id $uploadJob.Id
							$uploadTimout = $false
							while (( $uploadJobStatus.State -eq "Running" ) -and ( !$uploadTimout ))
							{
								Write-Host "." -NoNewline
								$now = Get-Date
								if ( ($now - $uploadStartTime).TotalSeconds -gt 600 )
								{
									$uploadTimout = $true
									LogErr "Upload Timout!"
								}
								sleep -Seconds 1
								$uploadJobStatus = Get-Job -Id $uploadJob.Id
							}
							Write-Host ""
							$returnCode = Get-Content -Path $uploadStatusRandomFile
							Remove-Item -Force $uploadStatusRandomFile | Out-Null
							Remove-Job -Id $uploadJob.Id -Force | Out-Null
						}
						if(($returnCode -ne 0) -and ($retry -ne $maxRetry))
						{
							LogMsg 0 "Warn: Error in upload, Attempt $retry. Retrying for upload"
							$retry=$retry+1
							WaitFor -seconds 10
						}
						elseif(($returnCode -ne 0) -and ($retry -eq $maxRetry))
						{
							LogMsg 0 "Error: Failed to upload after $retry attempts. Are you passing right VM credentials?"
							$retry=$retry+1
							Throw "Error: Failed to upload after $retry attempts. Are you passing right VM credentials?"
						}
						elseif($returnCode -eq 0)
						{
							LogMsg 0 "Info: Upload Success after $retry Attempt"
							$retry=$maxRetry+1
						}
					}
				}
			}
		}
		else
		{
			LogMsg 0 "Info: No Files to upload...!"
			Throw "No Files to upload...!"
		}

	}
	elseif($download)
	{
#Downloading the files
		if ($files)
		{
			$files = $files.split(",")
			foreach ($f in $files)
			{
				$retry=1
				$maxRetry=20
				$testFile = $f.trim()
				$recurse = ""
				while($retry -le $maxRetry)
				{
					if($usePrivateKey)
					{
						LogMsg 0 "Info: Downloading $testFile from $username : $downloadFrom,port $port to $downloadTo using PrivateKey authentication"
						$curDir = $PWD
						$downloadStatusRandomFile = "$LogDir\DownloadStatusFile" + (Get-Random -Maximum 9999 -Minimum 1111) + ".txt"
						$downloadStartTime = Get-Date
						$downloadJob = Start-Job -ScriptBlock { $curDir=$args[0];$sshKey=$args[1];$port=$args[2];$testFile=$args[3];$username=$args[4];${downloadFrom}=$args[5];$downloadTo=$args[6];$downloadStatusRandomFile=$args[7]; cd $curDir; Set-Content -Value "1" -Path $args[6]; echo y | .\bin\pscp -i .\ssh\$sshKey -q -P $port $username@${downloadFrom}:$testFile $downloadTo; Set-Content -Value $LASTEXITCODE -Path $downloadStatusRandomFile;} -ArgumentList $curDir,$sshKey,$port,$testFile,$username,${downloadFrom},$downloadTo,$downloadStatusRandomFile
						sleep -Milliseconds 100
						$downloadJobStatus = Get-Job -Id $downloadJob.Id
						$downloadTimout = $false
						while (( $downloadJobStatus.State -eq "Running" ) -and ( !$downloadTimout ))
						{
							Write-Host "." -NoNewline
							$now = Get-Date
							if ( ($now - $downloadStartTime).TotalSeconds -gt 600 )
							{
								$downloadTimout = $true
								LogErr "Download Timout!"
							}
							sleep -Seconds 1
							$downloadJobStatus = Get-Job -Id $downloadJob.Id
						}
						Write-Host ""
						$returnCode = Get-Content -Path $downloadStatusRandomFile
						Remove-Item -Force $downloadStatusRandomFile | Out-Null
						Remove-Job -Id $downloadJob.Id -Force | Out-Null
					}
					else
					{
						LogMsg 0 "Info: Downloading $testFile from $username : $downloadFrom,port $port to $downloadTo using Password authentication"
						$curDir = $PWD
						$downloadStatusRandomFile = "$LogDir\DownloadStatusFile" + (Get-Random -Maximum 9999 -Minimum 1111) + ".txt"
						$downloadStartTime = Get-Date
						
						$downloadJob = Start-Job -ScriptBlock { $curDir=$args[0];$password=$args[1];$port=$args[2];$testFile=$args[3];$username=$args[4];${downloadFrom}=$args[5];$downloadTo=$args[6];$downloadStatusRandomFile=$args[7]; cd $curDir; Set-Content -Value "1" -Path $args[6]; ; echo y | .\bin\pscp -pw $password -q -P $port $username@${downloadFrom}:$testFile $downloadTo ; Set-Content -Value $LASTEXITCODE -Path $downloadStatusRandomFile;} -ArgumentList $curDir,$password,$port,$testFile,$username,${downloadFrom},$downloadTo,$downloadStatusRandomFile
						
						sleep -Milliseconds 100
						$downloadJobStatus = Get-Job -Id $downloadJob.Id
						$downloadTimout = $false
						while (( $downloadJobStatus.State -eq "Running" ) -and ( !$downloadTimout ))
						{
							Write-Host "." -NoNewline
							$now = Get-Date
							if ( ($now - $downloadStartTime).TotalSeconds -gt 600 )
							{
								$downloadTimout = $true
								LogErr "Download Timout!"
							}
							sleep -Seconds 1
							$downloadJobStatus = Get-Job -Id $downloadJob.Id
						}
						Write-Host ""
						$returnCode = Get-Content -Path $downloadStatusRandomFile
						Remove-Item -Force $downloadStatusRandomFile | Out-Null
						Remove-Job -Id $downloadJob.Id -Force | Out-Null
					}
					if(($returnCode -eq 0) -or ($testFile -eq '*'))
					{
						LogMsg 0 "Info: Download Success after $retry Attempt"
						$retry=$maxRetry+1
					}elseif(($returnCode -ne 0) -and ($retry -ne $maxRetry))
					{
						LogMsg 0 "Warn: Error in download, Attempt $retry. Retrying for download(returnCode=$returnCode)"
						$retry=$retry+1
					}
					elseif(($returnCode -ne 0) -and ($retry -eq $maxRetry))
					{
						Write-Host "Error in download after $retry Attempt,Hence giving up"
						$retry=$retry+1
						Throw "Error in download after $retry Attempt,Hence giving up."
					}
				}
			}
		}
		else
		{
			LogMsg 0 "Info: No Files to download...!"
			Throw "No Files to download...!"
		}
	}
	else
	{
		LogMsg 0 "Info: Error: Upload/Download switch is not used!"
	}
}

Function WrapperCommandsToFile([string] $username,[string] $password,[string] $ip,[string] $command, [int] $port)
{
    if ( ( $lastLinuxCmd -eq $command) -and ($lastIP -eq $ip) -and ($lastPort -eq $port) -and ($lastUser -eq $username) )
    {
        #Skip upload if current command is same as last command.
    }
    else
    {
        Set-Variable -Name lastLinuxCmd -Value $command -Scope Global
        Set-Variable -Name lastIP -Value $ip -Scope Global
        Set-Variable -Name lastPort -Value $port -Scope Global
        Set-Variable -Name lastUser -Value $username -Scope Global
	    $command | out-file -encoding ASCII -filepath "$LogDir\runtest.sh"
	    RemoteCopy -upload -uploadTo $ip -username $username -port $port -password $password -files ".\$LogDir\runtest.sh"
	    del "$LogDir\runtest.sh"
    }
}

Function RunLinuxCmd([string] $username,[string] $password,[string] $ip,[string] $command, [int] $port=22, [switch]$runAsSudo, [Boolean]$WriteHostOnly, [Boolean]$NoLogsPlease, [switch]$ignoreLinuxExitCode, [int]$runMaxAllowedTime = 500, [switch]$RunInBackGround)
{
	if ($detectedDistro -ne "COREOS" )
	{
		WrapperCommandsToFile $username $password $ip $command $port
	}
	$randomFileName = [System.IO.Path]::GetRandomFileName()
	$maxRetryCount = 20
	$currentDir = $PWD.Path
	$RunStartTime = Get-Date

	if($runAsSudo)
	{
		$plainTextPassword = $password.Replace('"','');
		if ( $detectedDistro -eq "COREOS" )
		{
			$linuxCommand = "`"export PATH=/usr/share/oem/python/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/oem/bin:/opt/bin && echo $plainTextPassword | sudo -S env `"PATH=`$PATH`" $command && echo AZURE-LINUX-EXIT-CODE-`$? || echo AZURE-LINUX-EXIT-CODE-`$?`""
			$logCommand = "`"export PATH=/usr/share/oem/python/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/oem/bin:/opt/bin && echo $plainTextPassword | sudo -S env `"PATH=`$PATH`" $command`""
		}
		else
		{

			$linuxCommand = "`"echo $plainTextPassword | sudo -S bash -c `'bash runtest.sh ; echo AZURE-LINUX-EXIT-CODE-`$?`' `""
			$logCommand = "`"echo $plainTextPassword | sudo -S $command`""
		}
	}
	else
	{
		if ( $detectedDistro -eq "COREOS" )
		{
			$linuxCommand = "`"export PATH=/usr/share/oem/python/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/oem/bin:/opt/bin && $command && echo AZURE-LINUX-EXIT-CODE-`$? || echo AZURE-LINUX-EXIT-CODE-`$?`""
			$logCommand = "`"export PATH=/usr/share/oem/python/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/oem/bin:/opt/bin && $command`""
		}
		else
		{
			$linuxCommand = "`"bash -c `'bash runtest.sh ; echo AZURE-LINUX-EXIT-CODE-`$?`' `""
			$logCommand = "`"$command`""
		}
	}
	LogMsg 9 "Debug: .\bin\plink.exe -t -pw $password -P $port $username@$ip $logCommand"
	$returnCode = 1
	$attemptswt = 0
	$attemptswot = 0
	$notExceededTimeLimit = $true
	$isBackGroundProcessStarted = $false

	while ( ($returnCode -ne 0) -and ($attemptswt -lt $maxRetryCount -or $attemptswot -lt $maxRetryCount) -and $notExceededTimeLimit)
	{
		if ($runwithoutt -or $attemptswt -eq $maxRetryCount)
		{
			Set-Variable -Name runwithoutt -Value true -Scope Global
			$attemptswot +=1
			$runLinuxCmdJob = Start-Job -ScriptBlock `
			{ `
				$username = $args[1]; $password = $args[2]; $ip = $args[3]; $port = $args[4]; $jcommand = $args[5]; `
				cd $args[0]; `
				#Write-Host ".\bin\plink.exe -t -C -v -pw $password -P $port $username@$ip $jcommand";`
				.\bin\plink.exe -C -v -pw $password -P $port $username@$ip $jcommand;`
			} `
			-ArgumentList $currentDir, $username, $password, $ip, $port, $linuxCommand
		}
		else
		{
			$attemptswt += 1
			$runLinuxCmdJob = Start-Job -ScriptBlock `
			{ `
				$username = $args[1]; $password = $args[2]; $ip = $args[3]; $port = $args[4]; $jcommand = $args[5]; `
				cd $args[0]; `
				#Write-Host ".\bin\plink.exe -t -C -v -pw $password -P $port $username@$ip $jcommand";`
				.\bin\plink.exe -t -C -v -pw $password -P $port $username@$ip $jcommand;`
			} `
			-ArgumentList $currentDir, $username, $password, $ip, $port, $linuxCommand
		}
		$RunLinuxCmdOutput = ""
		$debugOutput = ""
		$LinuxExitCode = ""
		if ( $RunInBackGround )
		{
			While(($runLinuxCmdJob.State -eq "Running") -and ($isBackGroundProcessStarted -eq $false ) -and $notExceededTimeLimit)
			{
				$SSHOut = Receive-Job $runLinuxCmdJob 2> $LogDir\$randomFileName
				$JobOut = Get-Content $LogDir\$randomFileName
				if($jobOut)
				{
					foreach($outLine in $jobOut)
					{
						if($outLine -imatch "Started a shell")
						{
							$LinuxExitCode = $outLine
							$isBackGroundProcessStarted = $true
							$returnCode = 0
						}
						else
						{
							$RunLinuxCmdOutput += "$outLine`n"
						}
					}
				}
				$debugLines = Get-Content $LogDir\$randomFileName
				if($debugLines)
				{
					$debugString = ""
					foreach ($line in $debugLines)
					{
						$debugString += $line
					}
					$debugOutput += "$debugString`n"
				}
				Write-Progress -Activity "Attempt : $attemptswot+$attemptswt : Initiating command in Background Mode : $logCommand on $ip : $port" -Status "Timeout in $($RunMaxAllowedTime - $RunElaplsedTime) seconds.." -Id 87678 -PercentComplete (($RunElaplsedTime/$RunMaxAllowedTime)*100) -CurrentOperation "SSH ACTIVITY : $debugString"
                #Write-Host "Attempt : $attemptswot+$attemptswt : Initiating command in Background Mode : $logCommand on $ip : $port"
				$RunCurrentTime = Get-Date
				$RunDiffTime = $RunCurrentTime - $RunStartTime
				$RunElaplsedTime =  $RunDiffTime.TotalSeconds
				if($RunElaplsedTime -le $RunMaxAllowedTime)
				{
					$notExceededTimeLimit = $true
				}
				else
				{
					$notExceededTimeLimit = $false
					Stop-Job $runLinuxCmdJob
					$timeOut = $true
				}
			}
			WaitFor -seconds 2
			$SSHOut = Receive-Job $runLinuxCmdJob 2> $LogDir\$randomFileName
			if($SSHOut )
			{
				foreach ($outLine in $SSHOut)
				{
					if($outLine -imatch "AZURE-LINUX-EXIT-CODE-")
					{
						$LinuxExitCode = $outLine
						$isBackGroundProcessTerminated = $true
					}
					else
					{
						$RunLinuxCmdOutput += "$outLine`n"
					}
				}
			}

			$debugLines = Get-Content $LogDir\$randomFileName
			if($debugLines)
			{
				$debugString = ""
				foreach ($line in $debugLines)
				{
					$debugString += $line
				}
				$debugOutput += "$debugString`n"
			}
			Write-Progress -Activity "Attempt : $attemptswot+$attemptswt : Executing $logCommand on $ip : $port" -Status $runLinuxCmdJob.State -Id 87678 -SecondsRemaining ($RunMaxAllowedTime - $RunElaplsedTime) -Completed
			if ( $isBackGroundProcessStarted -and !$isBackGroundProcessTerminated )
			{
				LogMsg 0 "Info: $command is running in background with ID $($runLinuxCmdJob.Id) ..."
				Add-Content -Path $LogDir\CurrentTestBackgroundJobs.txt -Value $runLinuxCmdJob.Id
				$retValue = $runLinuxCmdJob.Id
			}
			else
			{
				Remove-Job $runLinuxCmdJob
				if (!$isBackGroundProcessStarted)
				{
					LogErr "Failed to start process in background.."
				}
				if ( $isBackGroundProcessTerminated )
				{
					LogErr "Background Process terminated from Linux side with error code :  $($LinuxExitCode.Split("-")[4])"
					$returnCode = $($LinuxExitCode.Split("-")[4])
					LogErr $SSHOut
				}
				if($debugOutput -imatch "Unable to authenticate")
				{
					LogMsg 0 "Info: Unable to authenticate. Not retrying!"
					Throw "Unable to authenticate"

				}
				if($timeOut)
				{
					$retValue = ""
					Throw "Tmeout while executing command : $command"
				}
				LogErr "Linux machine returned exit code : $($LinuxExitCode.Split("-")[4])"
				if ($attempts -eq $maxRetryCount)
				{
					Throw "Failed to execute : $command."
				}
				else
				{
					if ($notExceededTimeLimit)
					{
						LogMsg 0 "Info: Failed to execute : $command. Retrying..."
					}
				}
			}
			Remove-Item $LogDir\$randomFileName -Force | Out-Null
		}
		else
		{
			While($notExceededTimeLimit -and ($runLinuxCmdJob.State -eq "Running"))
			{
				$jobOut = Receive-Job $runLinuxCmdJob 2> $LogDir\$randomFileName
				if($jobOut)
				{
					foreach ($outLine in $jobOut)
					{
						if($outLine -imatch "AZURE-LINUX-EXIT-CODE-")
						{
							$LinuxExitCode = $outLine
						}
						else
						{
							$RunLinuxCmdOutput += "$outLine`n"
						}
					}
				}
				$debugLines = Get-Content $LogDir\$randomFileName
				if($debugLines)
				{
					$debugString = ""
					foreach ($line in $debugLines)
					{
						$debugString += $line
					}
					$debugOutput += "$debugString`n"
				}
				Write-Progress -Activity "Attempt : $attemptswot+$attemptswt : Executing $logCommand on $ip : $port" -Status "Timeout in $($RunMaxAllowedTime - $RunElaplsedTime) seconds.." -Id 87678 -PercentComplete (($RunElaplsedTime/$RunMaxAllowedTime)*100) -CurrentOperation "SSH ACTIVITY : $debugString"
                #Write-Host "Attempt : $attemptswot+$attemptswt : Executing $logCommand on $ip : $port"
				$RunCurrentTime = Get-Date
				$RunDiffTime = $RunCurrentTime - $RunStartTime
				$RunElaplsedTime =  $RunDiffTime.TotalSeconds
				if($RunElaplsedTime -le $RunMaxAllowedTime)
				{
					$notExceededTimeLimit = $true
				}
				else
				{
					$notExceededTimeLimit = $false
					Stop-Job $runLinuxCmdJob
					$timeOut = $true
				}
			}
			$jobOut = Receive-Job $runLinuxCmdJob 2> $LogDir\$randomFileName
			if($jobOut)
			{
				foreach ($outLine in $jobOut)
				{
					if($outLine -imatch "AZURE-LINUX-EXIT-CODE-")
					{
						$LinuxExitCode = $outLine
					}
					else
					{
						$RunLinuxCmdOutput += "$outLine`n"
					}
				}
			}
			$debugLines = Get-Content $LogDir\$randomFileName
			if($debugLines)
			{
				$debugString = ""
				foreach ($line in $debugLines)
				{
					$debugString += $line
				}
				$debugOutput += "$debugString`n"
			}
			Write-Progress -Activity "Attempt : $attemptswot+$attemptswt : Executing $logCommand on $ip : $port" -Status $runLinuxCmdJob.State -Id 87678 -SecondsRemaining ($RunMaxAllowedTime - $RunElaplsedTime) -Completed
			#Write-Host "Attempt : $attemptswot+$attemptswt : Executing $logCommand on $ip : $port"
            Remove-Job $runLinuxCmdJob
			Remove-Item $LogDir\$randomFileName -Force | Out-Null
			if ($LinuxExitCode -imatch "AZURE-LINUX-EXIT-CODE-0")
			{
				$returnCode = 0
				LogMsg 0 "Info: $command executed successfully in $RunElaplsedTime seconds." -WriteHostOnly $WriteHostOnly -NoLogsPlease $NoLogsPlease
				$retValue = $RunLinuxCmdOutput.Trim()
			}
			else
			{
				if (!$ignoreLinuxExitCode)
				{
					$debugOutput = ($debugOutput.Split("`n")).Trim()
					foreach ($line in $debugOutput)
					{
						if($line)
						{
							LogErr $line
						}
					}
				}
				if($debugOutput -imatch "Unable to authenticate")
					{
						LogMsg 0 "Info: Unable to authenticate. Not retrying!"
						Throw "Unable to authenticate"

					}
				if(!$ignoreLinuxExitCode)
				{
					if($timeOut)
					{
						$retValue = ""
						LogErr "Tmeout while executing command : $command"
					}
					LogErr "Linux machine returned exit code : $($LinuxExitCode.Split("-")[4])"
					if ($attemptswt -eq $maxRetryCount -and $attemptswot -eq $maxRetryCount)
					{
						Throw "Failed to execute : $command."
					}
					else
					{
						if ($notExceededTimeLimit)
						{
							LogErr "Failed to execute : $command. Retrying..."
						}
					}
				}
				else
				{
					LogMsg 0 "Info: Command execution returned return code $($LinuxExitCode.Split("-")[4]) Ignoring.."
					$retValue = $RunLinuxCmdOutput.Trim()
					break
				}
			}
		}
	}
	return $retValue
}
