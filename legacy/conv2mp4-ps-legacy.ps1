<#======================================================================================================================
conv2mp4-ps v3.1.2.3 RELEASE - https://github.com/BrianDMG/conv2mp4-ps

This Powershell script will recursively search through a user-defined file path and convert all videos of user-specified
filetypes to MP4 with H264 video and AAC audio using ffmpeg. If a conversion failure is detected, the script re-encodes
the file with HandbrakeCLI. Upon successful encoding, Plex libraries are (optionally) refreshed and source file is deleted.
The purpose of this script is to reduce the amount of transcoding CPU load on a Plex server.
========================================================================================================================

ffmpeg : https://ffmpeg.org/download.html
handbrakecli : https://handbrake.fr/downloads.php #>

<#----------------------------------------------------------------------------------------------------------------------
Import user-defined variables
------------------------------------------------------------------------------------------------------------------------#>
#Create a backup of the cfg file
	$cfgFile = Join-Path "$PSScriptRoot" "cfg_conv2mp4-ps.ps1"
	Copy-Item $cfgFile "$cfgFile.bk"
	Write-Host "`nCreated a backup of $cfgFile" -Foregroundcolor Green
#Load variables from cfg_conv2mp4-ps.ps1
	$testCfg = Test-Path $cfgFile
	If ($testCfg -eq $True)
	{
		. $cfgFile
	}
	else
	{
		Write-Output "Cannot find $cfgFile. Make sure it's in the same directory as the script."
		Start-Sleep 10
		Exit
	}
<#----------------------------------------------------------------------------------
Static variables
----------------------------------------------------------------------------------#>
#Script version information
	$version = "v3.1.2.3 RELEASE"
#Create lock file (for the purpose of ensuring only one instance of this script is running)
	$lockPath = "$PSScriptRoot"
	$lockFile = "conv2mp4-ps.lock"
	$lock = Join-Path "$lockPath" "$lockFile"
	$testLock = test-path -LiteralPath $lock
	If ($testLock -eq $True)
	{
		Write-Host "Script is already running in another instance. Waiting..." -ForegroundColor Red
		Do
		{
			$testLock = test-path $lock
			$testLock > $null
			Start-Sleep 10
		}
		Until ($testLock -eq $False)
		Write-Host "Other instance ended. We are cleared for takeoff." -ForegroundColor Green
	}
	new-item $lock
	Clear-Host
# Time and format used for timestamps in the log
	$time = {Get-Date -format "MM/dd/yy HH:mm:ss"}
#Join-Path for log file
	$log = Join-Path "$logPath" "$logName"
# Print initial wait notice to console
	Write-Host "`nBuilding file list, please wait. This may take a while, especially for large libraries.`n"
# Get current time to store as start time for script
	$script:scriptDurStart = (Get-Date -format "HH:mm:ss")
# Build and test file paths to executables and log
	$ffmpeg = Join-Path "$ffmpegBinDir" "ffmpeg.exe"
	$testFFMPath = Test-Path $ffmpeg
		If ($testFFMPath -eq $False)
		{
			Write-Output "`nffmeg.exe could not be found at $($ffmpegBinDir)." | Tee-Object -filepath $log -append
			Write-Output "Ensure the path in `$ffmpegBinDir is correct." | Tee-Object -filepath $log -append
			Write-Output "Aborting script." | Tee-Object -filepath $log -append
			Try
			{
				Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
			}
			Catch
			{
				Log "$($time.Invoke()) ERROR: $lock could not be deleted. Please delete manually."
			}
			Exit
		}

	$ffprobe = Join-Path "$ffmpegBinDir" "ffprobe.exe"
	$testFFPPath = Test-Path $ffprobe
		If ($testFFPPath -eq $False)
		{
			Write-Output "`nffprobe.exe could not be found at $($ffmpegBinDir)." | Tee-Object -filepath $log -append
			Write-Output "Ensure the path in `$ffmpegBinDir is correct." | Tee-Object -filepath $log -append
			Write-Output "Aborting script." | Tee-Object -filepath $log -append
			Try
			{
				Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
			}
			Catch
			{
				Log "$($time.Invoke()) ERROR: $lock could not be deleted. Please delete manually."
			}
			Exit
		}

	$handbrake = Join-Path "$handbrakeDir" "HandBrakeCLI.exe"
	$testHBPath = Test-Path $handbrake
		If ($testHBPath -eq $False)
		{
			Write-Output "`nhandbrakecli.exe could not be found at $($handbrakeDir)." | Tee-Object -filepath $log -append
			Write-Output "Ensure the path in `$handbrakeDir is correct." | Tee-Object -filepath $log -append
			Write-Output "Aborting script." | Tee-Object -filepath $log -append
			Exit
		}

# Setup for file list loop
	$testMediaPath = Test-Path $mediaPath
	If ($testMediaPath -eq $True)
	{
		$mPath = Get-Item -Path $mediaPath
	}
	Else
	{
		Write-Output "`nPath not found: $mediaPath" | Tee-Object -filepath $log -append
		Write-Output "Ensure the path in `$mediaPath exists and is accessible." | Tee-Object -filepath $log -append
		Write-Output "Aborting script." | Tee-Object -filepath $log -append
		Try
		{
			Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
		}
		Catch
		{
			Log "$($time.Invoke()) ERROR: $lock could not be deleted. Please delete manually."
		}
		Exit
	}
	$b=0
	$fileList = Get-ChildItem "$($mPath.FullName)\*" -i $fileTypes -recurse | ForEach-Object {$b++; If ($b -eq 1){Write-Host -NoNewLine "`rFound $b file so far..."} Else{Write-Host -NoNewLine "`rFound $b files so far..." -foregroundcolor green};$_}
	$num = $fileList | measure
	$fileCount = $num.count
# Initialize disk usage change to 0
	$diskUsage = 0
# Initialize 'video length converted' to 0
	$durTotal = [timespan]::fromseconds(0)

<#----------------------------------------------------------------------------------
Begin search loop
----------------------------------------------------------------------------------#>
# List files in the queue in the log
	ListFiles

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
				md $outPath
			}
			$newFile = $outPath + "\" + $file.BaseName + ".mp4";
			Log "outPath = $outPath"
		}
		Else
		{
			$newFile = $file.DirectoryName + "\" + $file.BaseName + ".mp4";
		}
		$plexURL = "http://$plexIP/library/sections/all/refresh?X-Plex-Token=$plexToken"
		$progress = ($i / $fileCount) * 100
		$progress = [Math]::Round($progress,2)

		Log "------------------------------------------------------------------------------------"
		Log "$($time.Invoke()) Processing - $oldFile"
		Log "$($time.Invoke()) File $i of $fileCount - Total queue $progress%"

		<#----------------------------------------------------------------------------------
		Test if $newFile (.mp4) already exists, if yes then delete $oldFile (.mkv)
		This outputs a more specific log message acknowleding the file already existed.
		----------------------------------------------------------------------------------#>
		$testNewExist = Test-Path $newFile
		If ($testNewExist -eq $True)
		{
			Remove-Item -LiteralPath $oldFile -Force
			Log "$($time.Invoke()) Already exists: $newFile"
			Log "$($time.Invoke()) Deleted: $oldFile."
		}
		Else
		{
		<#----------------------------------------------------------------------------------conv2
		Codec discovery to determine whether video, audio, or both needs to be encoded
		----------------------------------------------------------------------------------#>
		CodecDiscovery

		<#----------------------------------------------------------------------------------conv2
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
					Log "$($time.Invoke()) Plex libraries refreshed"
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
										Log "$($time.Invoke()) ERROR: New file was too small ($($diffErr)MB)."
										Log "$($time.Invoke()) Deleted new file and retained $oldFile."
									}
									Catch
									{
										Log "$($time.Invoke()) ERROR: New file was too small ($($diffErr)MB). Retained $oldFile."
										Log "$($time.Invoke()) ERROR: $newFile could not be deleted. Full error below."
										Log $_
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
		Log "$($time.Invoke()) ERROR: $lock could not be deleted. Full error below."
		Log $_
	}
Log "`nFinished"
Exit