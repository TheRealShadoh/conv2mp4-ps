#$mediaPath = "\\192.168.1.5\media"
#$fileTypes = "*.mkv", "*.avi", "*.flv", "*.mpeg", "*.ts" #Do NOT add .mp4!
#$usePlex = $True
#$plexIP = '192.168.1.9:32400'
#$plexToken = 'plextoken'
#$ffmpegBinDir = "C:\ffmpeg\bin"
#$handbrakeDir = "C:\Program Files\HandBrake"
#$collectGarbage = $True
#$script:garbage = "*.nfo"
#$appendLog = $False
#$keepSubs = $True
#$useOutPath = $False
#$outPath = "\\your\output\path\here"
Import-Module C:\git\conv2mp4-ps\modules\conv2mp4.psm1
$PSScriptRoot = "C:\git\conv2mp4-ps"
Function Set-Conv2Mp4
{
	param(
        [Parameter(Mandatory=$True)]
        $Path,
		[Parameter(Mandatory=$True)]
		[ValidateSet('mkv','avi','flv','mpeg','ts','All')]
		$FileTypes,
		$AdditionalFileTypes,
		$PlexIP,
		$PlexPort = [string]"32400",
		[Parameter(Mandatory=$True)]
		[ValidateSet($True,$False)]
		[bool]$UsePlex,
		$ffmpegDir,
		$HandbrakeDir,
		[Parameter(Mandatory=$True)]
		[ValidateSet($True,$False)]
		[bool]$KeepSubs,
		$GarbageFileTypes = "nfo",
		$CollectGarbage,
		$UseOutPath,
		$OutPath
        )

	#Create lock file (for the purpose of ensuring only one instance of this script is running)
	$lockPath = "$PSScriptRoot"
	$lockFile = "conv2mp4-ps.lock"
	$lock = Join-Path "$lockPath" "$lockFile"
	$testLock = test-path -LiteralPath $lock
	If ($testLock -eq $True)
	{
		Write-Output "Script running, waiting for completion." 
		Do
		{
			$testLock = test-path $lock
			$testLock > $null
			Start-Sleep 10
		}
		Until ($testLock -eq $False)
		Write-Output "Other instance ended. We are cleared for takeoff."
	}
	new-item $lock

	#Validating if required tools are installed, and the parameters are accurate
	#ffmpeg
	$ffmpeg = Join-Path "$ffmpegDir" "ffmpeg.exe"
	$testFFMPath = Test-Path $ffmpeg
	If ($testFFMPath -eq $False)
	{
		Write-Output "`nffmpeg.exe could not be found at $($ffmpegDir). Ensure the path in $($ffmpegBinDir) is correct- Aborting." 
		Try
		{
			Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
		}
		Catch
		{
			Write-Output "ERROR: $lock could not be deleted. Please delete manually."
		}
		Exit
	}
	#ffprobe
	$ffprobe = Join-Path "$ffmpegDir" "ffprobe.exe"
	$testFFPPath = Test-Path $ffprobe
		If ($testFFPPath -eq $False)
		{
			Write-Output "`nffprobe.exe could not be found at $($ffmpegDir). Ensure the path in $($ffmpegBinDir) is correct- Aborting." 
			Try
			{
				Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
			}
			Catch
			{
				Write-Output "ERROR: $lock could not be deleted. Please delete manually."
			}
			Exit
		}
	#HandbrakeCLI
	$handbrake = Join-Path "$HandbrakeDir" "HandBrakeCLI.exe"
	$testHBPath = Test-Path $handbrake
	If ($testHBPath -eq $False)
	{
		Write-Output "`nHandbrakeCLI.exe could not be found at $($HandbrakeDir). Ensure the path in $($HandbrakeDir) is correct- Aborting." 
		Exit
	}
	#Media path
	$testMediaPath = Test-Path $Path
	If ($testMediaPath -eq $True)
	{
		$mPath = Get-Item -Path $Path
	}
	Else
	{
		Write-Output "`nPath not found: $($Path). Ensure the path in $($Path) exists and is accessible- Aborting"
		Try
		{
			Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
		}
		Catch
		{
			Write-Output "ERROR: $lock could not be deleted. Please delete manually."
		}
		Exit
	}
	#Build file list
	$fileList = Get-ChildItem "$($mPath.FullName)\*" -i $fileTypes -recurse 
	# Initialize disk usage change to 0
	$diskUsage = 0
	# Initialize 'video length converted' to 0
	$durTotal = [timespan]::fromseconds(0)	

	# Hand off matched file list to encoding
	<#----------------------------------------------------------------------------------
	Begin search loop
	----------------------------------------------------------------------------------#>
	# Begin performing operations of files
	$i = 0
	$baseOutPath = $outpath;
	ForEach ($file in $fileList)
	{
		$i++;
		$oldFile = $file.DirectoryName + "\" + $file.BaseName + $file.Extension;

		$fileSubDirs = ($file.DirectoryName).Substring($mediaPath.Length,($file.DirectoryName).Length-$mediaPath.Length);
		If ($useOutPath -eq $True)
		{
			$outPath = $baseOutPath + $fileSubDirs;

			IF (-Not (test-path $outpath))
			{
				New-Item -ItemType Directory $outPath -Force -Confirm:$false
			}
			$newFile = $outPath + "\" + $file.BaseName + ".mp4";
		}
		Else
		{
			$newFile = $file.DirectoryName + "\" + $file.BaseName + ".mp4";
		}
		$plexURL = "http://$plexIP/library/sections/all/refresh?X-Plex-Token=$plexToken"
		$progress = ($i / $fileCount) * 100
		$progress = [Math]::Round($progress,2)

		<#----------------------------------------------------------------------------------
		Test if $newFile (.mp4) already exists, if yes then delete $oldFile (.mkv)
		This outputs a more specific log message acknowleding the file already existed.
		----------------------------------------------------------------------------------#>
		$testNewExist = Test-Path $newFile
		If ($testNewExist -eq $True)
		{
			Remove-Item -LiteralPath $oldFile -Force
		}
		Else
		{
		<#----------------------------------------------------------------------------------
		Codec discovery to determine whether video, audio, or both needs to be encoded
		----------------------------------------------------------------------------------#>
		CodecDiscovery

		<#----------------------------------------------------------------------------------
		Statistics-gathering derived from Codec Discovery
		----------------------------------------------------------------------------------#>
		#Running tally of session container duration (cumulative length of video processed)
			$script:durTotal = $script:durTotal + $script:duration
		#Running tally of ticks (time expressed as an integer) for script runtime
			$script:durTicksTotal = $script:durTicksTotal + $script:durTicks

		<#----------------------------------------------------------------------------------
		Begin ffmpeg conversion based on codec discovery
		----------------------------------------------------------------------------------#>
		# Video is already H264, Audio is already AAC
			If ($vCodecCMD -eq "h264" -AND $aCodecCMD -eq "aac")
			{
				SimpleConvert
			}
		# Video is already H264, Audio is not AAC
			ElseIf ($vCodecCMD -eq "h264" -AND $aCodecCMD -ne "aac")
			{
				EncodeAudio
			}
		# Video is not H264, Audio is already AAC
			ElseIf ($vCodecCMD -ne "h264" -AND $aCodecCMD -eq "aac")
			{
				EncodeVideo
			}
		# Video is not H264, Audio is not AAC
			ElseIf ($vCodecCMD -ne "h264" -AND $aCodecCMD -ne "aac")
			{
				EncodeBoth
			}
			If ($usePlex -eq $True)
			{
				# Refresh Plex libraries
					Invoke-WebRequest $plexURL -UseBasicParsing
			}
			<#----------------------------------------------------------------------------------
			Begin file comparison between old file and new file to determine conversion success
			-----------------------------------------------------------------------------------#>
			# Load files for comparison
				$fileOld = Get-Item $oldFile
				$fileNew = Get-Item $newFile

			# If new file is the same size as old file, log status and delete old file
				If ($fileNew.length -eq $fileOld.length)
				{
					IfSame
				}
			# If new file is larger than old file, log status and delete old file
				Elseif ($fileNew.length -gt $fileOld.length)
				{
					IfLarger
				}
			# If new file is much smaller than old file (indicating a failed conversion), log status, delete new file, and re-encode with HandbrakeCLI
				Elseif ($fileNew.length -lt ($fileOld.length * .75))
				{
					FailureDetected

						<#----------------------------------------------------------------------------------
						Begin Handbrake encode (lossy)
						----------------------------------------------------------------------------------#>
						EncodeHandbrake

							# Load files for comparison
								$fileOld = Get-Item $oldFile
								$fileNew = Get-Item $newFile

							# If new file is much smaller than old file (likely because the script was aborted re-encode), leave original file alone and print error
								If ($fileNew.length -lt ($fileOld.length * .75))
								{
									$diffErr = [Math]::Round($fileNew.length-$fileOld.length)/1MB
									$diffErr = [Math]::Round($diffErr,2)
									Try
									{
										Remove-Item -LiteralPath $newFile -Force -ErrorAction Stop
									}
									Catch
									{
									}
								}
							# If new file is the same size as old file, log status and delete old file
								Elseif ($fileNew.length -eq $fileOld.length)
								{
									IfSame
								}
							# If new file is larger than old file, log status and delete old file
								Elseif ($fileNew.length -gt $fileOld.length)
								{
									IfLarger
								}
							# If new file is smaller than old file, log status and delete old file
								Elseif ($fileNew.length -lt $fileOld.length)
								{
									IfSmaller
								}
					}

				# If new file is smaller than old file, log status and delete old file
					Elseif ($fileNew.length -lt $fileOld.length)
					{
						IfSmaller
					}
		}
	} # End foreach loop

	<#----------------------------------------------------------------------------------
	Wrap-up
	-----------------------------------------------------------------------------------#>
	FinalStatistics
	If ($collectGarbage -eq $True)
	{
	GarbageCollection
	}
	#Delete lock file
	Try
	{
		Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
	}
	Catch
	{
	}
	return
}



