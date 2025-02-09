<#----------------------------------------------------------------------------------
Functions
----------------------------------------------------------------------------------#>
# Logging and console output
Function Log
{
   Param ([string]$logString)
   Write-Output $logString | Tee-Object -filepath $log -append
}
# Prints the current script version header
Function PrintVersion
{
    Log "conv2mp4-ps $version - https://github.com/BrianDMG/conv2mp4-ps"
    Log "------------------------------------------------------------------------------------"
}
# Append log conditions
Function AppendLog
{
    #Check whether log file is empty
        $logEmpty = Get-Content $log
    #Should the log append or clear
        If ($appendLog -eq $False)
        {
            Clear-Content $log
            PrintVersion
        }
        Elseif ($appendLog -eq $True -AND $logEmpty -eq $Null)
        {
            PrintVersion
        }
        Else
        {
            Log "`n------------------------------------------------------------------------------------"
            Log ">>>>> New Session (started $($time.Invoke()))"
        }
}
# List files in the queue in the log
Function ListFiles
{
    If ($fileCount -eq 1)
    {
        AppendLog
        Log ("`nThere is $fileCount file in the queue:`n")
    }
    Elseif ($fileCount -gt 1)
    {
        AppendLog
        Log ("`nThere are $fileCount files in the queue:`n")
    }
    Else
    {
        Write-Host ("`nThere are no files to be converted in $mediaPath. Congrats!`n")
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

    $num = 0
        ForEach ($file in $fileList)
            {
                $num++
                Log "$($num). $file"
            }
            Log ""
}
# Find out what video and audio codecs a file is using
Function CodecDiscovery
{
    # Check video codec with ffprobe
        $vCodecArg1 = "-v"
        $vCodecArg2 = "error"
        $vCodecArg3 = "-select_streams"
        $vCodecArg4 = "v:0"
        $vCodecArg5 = "-show_entries"
        $vCodecArg6 = "stream=codec_name"
        $vCodecArg7 = "-of"
        $vCodecArg8 = "default=nokey=1:noprint_wrappers=1"
        $vCodecArg9 = "$oldFile"
        $vCodecArgs = @($vCodecArg1, $vCodecArg2, $vCodecArg3, $vCodecArg4, $vCodecArg5, $vCodecArg6, $vCodecArg7, $vCodecArg8, $vCodecArg9)
        $script:vCodecCMD = &$ffprobe $vCodecArgs
    # Check audio codec with ffprobe
        $aCodecArg1 = "-v"
        $aCodecArg2 = "error"
        $aCodecArg3 = "-select_streams"
        $aCodecArg4 = "a:0"
        $aCodecArg5 = "-show_entries"
        $aCodecArg6 = "stream=codec_name"
        $aCodecArg7 = "-of"
        $aCodecArg8 = "default=nokey=1:noprint_wrappers=1"
        $aCodecArg9 = "$oldFile"
        $aCodecArgs = @($aCodecArg1, $aCodecArg2, $aCodecArg3, $aCodecArg4, $aCodecArg5, $aCodecArg6, $aCodecArg7, $aCodecArg8, $aCodecArg9)
        $script:aCodecCMD = &$ffprobe $aCodecArgs
    #Get duration of file
        $durArg1 = "-v"
        $durArg2 = "error"
        $durArg3 = "-show_entries"
        $durArg4 = "format=duration"
        $durArg5 = "-of"
        $durArg6 = "default=noprint_wrappers=1:nokey=1"
        $durArg7 = "$oldFile"
        $durArgs = @($durArg1, $durArg2, $durArg3, $durArg4, $durArg5, $durArg6, $durArg7)
        $durCMD = &$ffprobe $durArgs
        $durTemp = [timespan]::fromseconds($durCMD)
        $script:durTicks = $durTemp.ticks
        If ($durTemp -eq 0 -OR $durTemp -eq "N/A")
        {
            $script:duration = "00:01:00"
        }
        Else
        {
            $script:duration = "$($durTemp.hours):$($durTemp.minutes):$($durTemp.seconds)"
        }
}
# If new and old files are the same size
Function IfSame
{
        Try
        {
            Remove-Item -LiteralPath $oldFile -Force -ErrorAction Stop
            Log "$($time.Invoke()) Same file size."
            Log "$($time.Invoke()) $oldFile deleted."
        }
        Catch
        {
            Log "$($time.Invoke()) ERROR: $oldFile could not be deleted. Full error below."
            Log $_
        }
}
# If new file is larger than old file
Function IfLarger
    {
    $diffGT = [Math]::Round($fileNew.length - $fileOld.length)/1MB
    $diffGT = [Math]::Round($diffGT,2)
        Try
        {
            Remove-Item -LiteralPath $oldFile -Force -ErrorAction Stop
            Log "$($time.Invoke()) $oldFile deleted."

            If ($diffGT -lt 1)
            {
                $diffGT_KB = ($diffGT * 1024)
                $diffGT_KB = [Math]::Round($diffGT_KB,2)
                Log "$($time.Invoke()) New file is $($diffGT_KB)KB larger."
            }
            Elseif ($diffGT -gt 1024)
            {
                $diffGT_GB = ($diffGT / 1024)
                $diffGT_GB = [Math]::Round($diffGT_GB,2)
                Log "$($time.Invoke()) New file is $($diffGT_GB)GB larger."
            }
            Else
            {
                Log "$($time.Invoke()) New file is $($diffGT)MB larger."
            }

            $script:diskUsage = $script:diskUsage + $diffGT

                If ($script:diskUsage -gt -1 -AND $script:diskUsage -lt 1)
                {
                    $diskUsage_KB = ($script:diskUsage * 1024)
                    $diskUsage_KB = [Math]::Round($diskUsage_KB,2)
                    Log "$($time.Invoke()) Current cumulative storage difference: $($diskUsage_KB)KB"
                }
                Elseif ($script:diskUsage -lt -1024 -OR $script:diskUsage -gt 1024)
                {
                    $diskUsage_GB = ($script:diskUsage / 1024)
                    $diskUsage_GB = [Math]::Round($diskUsage_GB,2)
                    Log "$($time.Invoke()) Current cumulative storage difference: $($diskUsage_GB)GB"
                }
                Else
                {
                    $script:diskUsage = [Math]::Round($script:diskUsage,2)
                    Log "$($time.Invoke()) Current cumulative storage difference: $($script:diskUsage)MB"
                }
        }
        Catch
        {
            Log "$($time.Invoke()) ERROR: $oldFile could not be deleted. Full error below."
            Log $_
        }
    }
# If new file is smaller than old file
Function IfSmaller
{
    $diffLT = [Math]::Round($fileOld.length-$fileNew.length)/1MB
    $diffLT = [Math]::Round($diffLT,2)
        Try
        {
            Remove-Item -LiteralPath $oldFile -Force -ErrorAction Stop
            Log "$($time.Invoke()) $oldFile deleted."

            If ($diffLT -lt 1)
            {
                $diffLT_KB = ($diffLT * 1024)
                $diffLT_KB = [Math]::Round($diffLT_KB,2)
                Log "$($time.Invoke()) New file is $($diffLT_KB)KB smaller."
            }
            Elseif ($diffLT -lt -1024)
            {
                $diffLT_GB = ($diffLT / 1024)
                $diffLT_GB = [Math]::Round($diffLT_GB,2)
                Log "$($time.Invoke()) New file is $($diffLT_GB)GB smaller."
            }
            Else
            {
            Log "$($time.Invoke()) New file is $($diffLT)MB smaller."
            }

            $script:diskUsage = $script:diskUsage - $diffLT

                If ($script:diskUsage -gt -1 -AND $script:diskUsage -lt 1)
                {
                    $diskUsage_KB = ($script:diskUsage * 1024)
                    $diskUsage_KB = [Math]::Round($diskUsage_KB,2)
                    Log "$($time.Invoke()) Current cumulative storage difference: $($diskUsage_KB)KB"
                }
                Elseif ($script:diskUsage -lt -1024 -OR $script:diskUsage -gt 1024)
                {
                    $diskUsage_GB = ($script:diskUsage / 1024)
                    $diskUsage_GB = [Math]::Round($diskUsage_GB,2)
                    Log "$($time.Invoke()) Current cumulative storage difference: $($diskUsage_GB)GB"
                }
                Else
                {
                    $script:diskUsage = [Math]::Round($script:diskUsage,2)
                    Log "$($time.Invoke()) Current cumulative storage difference: $($script:diskUsage)MB"
                }
        }
        Catch
        {
            Log "$($time.Invoke()) ERROR: $oldFile could not be deleted. Full error below."
            Log $_
        }
}
## If new file is over 25% smaller than the original file, trigger encoding failure
Function FailureDetected
{
    $diffErr = [Math]::Round($fileNew.length-$fileOld.length)/1MB
    $diffErr = [Math]::Round($diffErr,2)
    Try
    {
        Remove-Item -LiteralPath $newFile -Force -ErrorAction Stop
        Log "$($time.Invoke()) EXCEPTION: New file is over 25% smaller ($($diffErr)MB). $newFile deleted."
        Log "$($time.Invoke()) FAILOVER: Re-encoding $oldFile with Handbrake."
    }
    Catch
    {
        Log "$($time.Invoke()) ERROR: $newFile could not be deleted. Full error below."
        Log $_
    }
}
# If a file video codec is already H264 and audio codec is already AAC, use these arguments
Function SimpleConvert
{
    Log "$($time.Invoke()) Video: $($script:vCodecCMD.ToUpper()), Audio: $($script:aCodecCMD.ToUpper()). Performing simple container conversion to MP4."

    # ffmpeg arguments
            $ffArg01 = "-n" 		#Do not overwrite output files, and exit immediately if a specified output file already exists.
            $ffArg02 = "-fflags" 	#Allows setting of formal flags
            $ffArg03 = "+genpts"	#Suppresses pointer warning messages
            $ffArg04 = "-i"			#Flag to designate input file
            $ffArg05 = "$oldFile"	#Input file
            $ffArg06 = "-threads"	#Flag to set maximum number of threads (CPU) to use
            $ffArg07 = "6"			#Maximum number of threads (CPU) to use
            $ffArg08 = "-map"		#Flag to use channel mapping
            $ffArg09 = "0"			#Channel to map (0 is default)
            $ffArg10 = "-c:v"		#Video codec flag
            $ffArg11 = "copy"		#Copy input file codec settings
            $ffArg12 = "-c:a"		#Audio codec flag
            $ffArg13 = "copy"		#Copy input file codec settings
            $ffArg14 = "-c:s"		#Subtitle codec flag
            $ffArg15 = "-sn"		#Option to remove any existing subtitles
            $ffArg16 = "mov_text"	#Name of subtitle channel after export
            $ffArg17 = "$newFile"	#Output file
    If ($keepSubs -eq $True)
    {
            $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg14, $ffArg16, $ffArg17)
            $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operation
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
    Else
    {
            $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg15, $ffArg17)
            $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operation
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
}
# If a file video codec is already H264, but audio codec is not AAC, use these arguments
Function EncodeAudio
{
    Log "$($time.Invoke()) Video: $($script:vCodecCMD.ToUpper()), Audio: $($script:aCodecCMD.ToUpper()). Encoding audio to AAC"

    # ffmpeg arguments
        $ffArg01 = "-n"			#Do not overwrite output files, and exit immediately if a specified output file already exists.
        $ffArg02 = "-fflags"	#Allows setting of formal flags
        $ffArg03 = "+genpts"	#Suppresses pointer warning messages
        $ffArg04 = "-i"			#Flag to designate input file
        $ffArg05 = "$oldFile"	#Input file
        $ffArg06 = "-threads"	#Flag to set maximum number of threads (CPU) to use
        $ffArg07 = "6"			#Maximum number of threads (CPU) to use
        $ffArg08 = "-map"		#Flag to use channel mapping
        $ffArg09 = "0"			#Channel to map (0 is default)
        $ffArg10 = "-c:v"		#Video codec flag
        $ffArg11 = "copy"		#Copy input file codec settings
        $ffArg12 = "-c:a"		#Audio codec flag
        $ffArg13 = "aac"		#Use AAC audio codec
        $ffArg14 = "-c:s"		#Subtitle codec flag
        $ffArg15 = "mov_text"	#Name of subtitle channel after export
        $ffArg16 = "$newFile"	#Output file
        $ffArg17 = "-sn"		#Option to remove any existing subtitles

    If ($keepSubs -eq $True)
    {

            $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg14, $ffArg15, $ffArg16)
            $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operation
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
    Else
    {
            $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg17, $ffArg16)
            $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operation
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
}
# If a file video codec is not H264, and audio codec is already AAC, use these arguments
Function EncodeVideo
{
    Log "$($time.Invoke()) Video: $($script:vCodecCMD.ToUpper()), Audio: $($script:aCodecCMD.ToUpper()). Encoding video to H264."

    # ffmpeg arguments
        $ffArg01 = "-n" 		#Do not overwrite output files, and exit immediately if a specified output file already exists.
        $ffArg02 = "-fflags"	#Allows setting of formal flags
        $ffArg03 = "+genpts"	#Suppresses pointer warning messages
        $ffArg04 = "-i"			#Flag to designate input file
        $ffArg05 = "$oldFile"	#Input file
        $ffArg06 = "-threads"	#Flag to set maximum number of threads (CPU) to use
        $ffArg07 = "6"			#Maximum number of threads (CPU) to use
        $ffArg08 = "-map"		#Flag to use channel mapping
        $ffArg09 = "0"			#Channel to map (0 is default)
        $ffArg10 = "-c:v"		#Video codec flag
        $ffArg11 = "libx264"	#Use x264 video codec
        $ffArg12 = "-preset"	#Video quality preset flag
        $ffArg13 = "medium"		#Video quality preset
        $ffArg14 = "-crf"		#Constant rate factor flag
        $ffArg15 = "18"			#CRF value
        $ffArg16 = "-c:a"		#Audio codec flag
        $ffArg17 = "copy"		#Copy input file codec settings
        $ffArg18 = "-c:s"		#Subtitle codec flag
        $ffArg19 = "mov_text"	#Name of subtitle channel after export
        $ffArg20 = "$newFile"	#Output file
        $ffArg21 = "-sn"		#Option to remove any existing subtitles

    If ($keepSubs -eq $True)
    {

        $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg14, $ffArg15, $ffArg16, $ffArg17, $ffArg18, $ffArg19, $ffArg20)
        $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operation
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
    Else
    {
        $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg14, $ffArg15, $ffArg16, $ffArg17, $ffArg21, $ffArg20)
        $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operation
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
}
# If a file video codec is not H264, and audio codec is not AAC, use these arguments
Function EncodeBoth
{
    Log "$($time.Invoke()) Video: $($script:vCodecCMD.ToUpper()), Audio: $($script:aCodecCMD.ToUpper()). Encoding video to H264 and audio to AAC."

    # ffmpeg arguments
        $ffArg01 = "-n"			#Do not overwrite output files, and exit immediately if a specified output file already exists.
        $ffArg02 = "-fflags"	#Allows setting of formal flags
        $ffArg03 = "+genpts"	#Suppresses pointer warning messages
        $ffArg04 = "-i"			#Flag to designate input file
        $ffArg05 = "$oldFile"	#Input file
        $ffArg06 = "-threads"	#Flag to set maximum number of threads (CPU) to use
        $ffArg07 = "6"			#Maximum number of threads (CPU) to use
        $ffArg08 = "-map"		#Flag to use channel mapping
        $ffArg09 = "0"			#Channel to map (0 is default)
        $ffArg10 = "-c:v"		#Video codec flag
        $ffArg11 = "libx264"	#Use x264 video codec
        $ffArg12 = "-preset"	#Video quality preset flag
        $ffArg13 = "fast"		#Video quality preset
        $ffArg14 = "-crf"		#Constant rate factor flag
        $ffArg15 = "18"			#CRF value
        $ffArg16 = "-c:a"		#Audio codec flag
        $ffArg17 = "aac"		#Use AAC audio codec
        $ffArg18 = "-c:s"		#Subtitle codec flag
        $ffArg19 = "mov_text"	#Name of subtitle channel after export
        $ffArg20 = "$newFile"	#Output file
        $ffArg21 = "-sn"		#Option to remove any existing subtitles

    If ($keepSubs -eq $True)
    {

        $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg14, $ffArg15, $ffArg16, $ffArg17, $ffArg18, $ffArg19, $ffArg20)
        $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operations
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
    Else
    {

        $ffArgs = @($ffArg01, $ffArg02, $ffArg03, $ffArg04, $ffArg05, $ffArg06, $ffArg07, $ffArg08, $ffArg09, $ffArg10, $ffArg11, $ffArg12, $ffArg13, $ffArg14, $ffArg15, $ffArg16, $ffArg17, $ffArg21, $ffArg20)
        $ffCMD = &$ffmpeg $ffArgs

        # Begin ffmpeg operations
            $ffCMD
            Log "$($time.Invoke()) ffmpeg completed"
    }
}
#If new file is much smaller than old file (indicating a failed conversion), log status, delete new file, and re-encode with HandbrakeCLI
Function EncodeHandbrake
{
    # Handbrake CLI: https://trac.handbrake.fr/wiki/CLIGuide#presets
    # Handbrake arguments
        $hbArg01 = "-i"							#Flag to designate input file
        $hbArg02 = "$oldFile"					#Input file
        $hbArg03 = "-o"							#Flag to designate output file
        $hbArg04 = "$newFile"					#Output file
        $hbArg05 = "-f"							#Format flag
        $hbArg06 = "mp4"						#Format value
        $hbArg07 = "-a"							#Audio channel flag
        $hbArg08 = "1,2,3,4,5,6,7,8,9,10"		#Audio channels to scan
        $hbArg09 = "--subtitle"					#Subtitle channel flag
        $hbArg10 = "scan,1,2,3,4,5,6,7,8,9,10"	#Subtitle channels to scan
        $hbArg11 = "-e"							#Output video codec flag
        $hbArg12 = "x264"						#Output using x264
        $hbArg13 = "--encoder-preset"			#Flag to set encode speed preset
        $hbArg14 = "slow"						#Encode speed preset
        $hbArg15 = "--encoder-profile"			#Flag to set encode quality preset
        $hbArg16 = "high"						#Encode quality preset
        $hbArg17 = "--encoder-level"			#Profile version to use for encoding
        $hbArg18 = "4.1"						#Encode profile value
        $hbArg19 = "-q"							#Equivalent to CRF in ffmpeg
        $hbArg20 = "18"							#CFR value
        $hbArg21 = "-E"							#Flag to set audio codec
        $hbArg22 = "aac"						#Use AAC as audio codec
        $hbArg23 = "--audio-copy-mask"			#Flag to set permitted audio codecs for copying
        $hbArg24 = "aac"						#Set only AAC as allowed for copying
        $hbArg25 = "--verbose=1"				#Flag to set logging level
        $hbArg26 = "--decomb"					#Flag to set deinterlace video
        $hbArg27 = "--loose-anamorphic"			#Keep aspect ratio as close as possible to the source videos
        $hbArg28 = "--modulus"					#Flag to set storage width modulus
        $hbArg29 = "2"							#Storage width modulus value

    If ($keepSubs -eq $True)
    {
        $hbArgs = @($hbArg01, $hbArg02, $hbArg03, $hbArg04, $hbArg05, $hbArg06, $hbArg07, $hbArg08, $hbArg09, $hbArg10, $hbArg11, $hbArg12, $hbArg13, $hbArg14, $hbArg15, $hbArg16, $hbArg17, $hbArg18, $hbArg19, $hbArg20, $hbArg21, $hbArg22, $hbArg23, $hbArg24, $hbArg25, $hbArg26, $hbArg27. $hbArg28. $hbArg29)
        $hbCMD = &$handbrake $hbArgs
        # Begin Handbrake operation
            Try
            {
                $hbCMD
                Log "$($time.Invoke()) Handbrake finished."
            }
            Catch
            {
                Log "$($time.Invoke()) ERROR: Handbrake has encountered an error."
                Log $_
            }
    }
    Else
    {
        $hbArgs = @($hbArg01, $hbArg02, $hbArg03, $hbArg04, $hbArg05, $hbArg06, $hbArg07, $hbArg08, $hbArg11, $hbArg12, $hbArg13, $hbArg14, $hbArg15, $hbArg16, $hbArg17, $hbArg18, $hbArg19, $hbArg20, $hbArg21, $hbArg22, $hbArg23, $hbArg24, $hbArg25, $hbArg26, $hbArg27. $hbArg28. $hbArg29)
        $hbCMD = &$handbrake $hbArgs

        # Begin Handbrake operation
            Try
            {
                $hbCMD
                Log "$($time.Invoke()) Handbrake finished."
            }
            Catch
            {
                Log "$($time.Invoke()) ERROR: Handbrake has encountered an error."
                Log $_
            }
    }
}
# Delete garbage files
Function GarbageCollection
{
    $garbageList = Get-ChildItem "$($mPath.FullName)\*" -i $script:garbage -recurse
    $garbageNum = 0

        ForEach ($turd in $garbageList)
        {
            $garbageNum++
        }

            If ($garbageNum -eq 1)
            {
                Log "`nGarbage Collection: The following file was deleted:"
            }
            Elseif ($garbageNum -gt 1)
            {
                Log "`nGarbage Collection: The following $garbageNum files were deleted:"
            }
            Else
            {
                Log ("`nGarbage Collection: No garbage found in $mediaPath. Congrats!")
            }
            Log ""

    $garbageNum = 0

        ForEach ($turd in $garbageList)
        {
            $garbageNum++
            Log "$($garbageNum). $turd"
                Try
                {
                    Remove-Item -LiteralPath $turd -Force -ErrorAction Stop
                }
                Catch
                {
                    Log "$($time.Invoke()) ERROR: $turd could not be deleted. Full error below."
                    Log $_
                }
        }
}
# Log various session statistics
Function FinalStatistics
{
    Log "`n====================================================================================`n"
    #Print total session disk usage changes
        If ($script:diskUsage -gt -1 -AND $script:diskUsage -lt 1)
        {
            $diskUsage_KB = ($script:diskUsage * 1024)
            $diskUsage_KB = [Math]::Round($diskUsage_KB,2)
            Log "$($time.Invoke()) Total cumulative storage difference: $($diskUsage_KB)KB"
        }
        Elseif ($script:diskUsage -lt -1024 -OR $script:diskUsage -gt 1024)
        {
            $diskUsage_GB = ($script:diskUsage / 1024)
            $diskUsage_GB = [Math]::Round($diskUsage_GB,2)
            Log "$($time.Invoke()) Total cumulative storage difference: $($diskUsage_GB)GB"
        }
        Else
        {
            $script:diskUsage = [Math]::Round($script:diskUsage,2)
            Log "$($time.Invoke()) Total cumulative storage difference: $($script:diskUsage)MB"
        }
    #Do some time math to get total script runtime
        $script:scriptDurTemp = new-timespan $script:scriptDurStart $(get-date -format "HH:mm:ss")
        $script:scriptDurTotal = "$($script:scriptDurTemp.hours):$($script:scriptDurTemp.minutes):$($script:scriptDurTemp.seconds)"
        Log "`n$script:durTotal of video processed in $script:scriptDurTotal"
    #Do some math/rounding to get session average conversion speed
        Try
        {
            $avgConv = $script:durTicksTotal / $script:scriptDurTemp.Ticks
            $avgConv = [math]::Round($avgConv,2)
            Log "Average conversion speed of $($avgConv)x"
        }
        Catch
        {
            Log "No time elapsed."
        }

    Log "`n===================================================================================="
}
Function Get-PlexRecentlyAddded
{
    # Parameter help description
    param(
        [Parameter(Mandatory=$True)]
        $PlexIP,
        $PlexPort = [string]"32400",
        [string]$plexToken = "plextoken"
        )
    $plexURL = "http://$($plexIP):$($plexPort)/library/recentlyAdded/refresh?X-Plex-Token=$plexToken"
    $RawResult = Invoke-WebRequest $plexURL -UseBasicParsing -Method Get -ContentType 'application/json' -Headers @{"Accept"="application/json"}
    $RawResult = ($RawResult.content | ConvertFrom-Json).mediacontainer.metadata
    $RawResult = $RawResult | Where {$_.media -ne $null} # Filter to only return recently added video files
    $RecentlyAddedArray = @()
    ForEach($obj in $RawResult)
    {
        $RemoteObj = New-Object PSCustomObject
        $RemoteObj | Add-Member -MemberType NoteProperty -Name dateAdded -Value $obj.addedAt # Epoch time
        $RemoteObj | Add-Member -MemberType NoteProperty -Name plexMediaPath -Value $obj.media.part.file # File path in relation to plex mapping
        $RecentlyAddedArray += $RemoteObj
    }
   $RecentlyAddedArray
}

Function Compare-AddedTimeCurrentTime
{
    param(
        [Parameter(Mandatory=$True)]
        $LastRunTime,
        [Parameter(Mandatory=$True)]
        $AddedTime
        )
    if($AddedTime -ge $LastRunTime)
    {
       return $True
    }
    else
    {
        return $false    
    }
} 
    
Function Get-PlexMediaPath
{
    param(
        [Parameter(Mandatory=$True)]
        $PlexMediaPath,
        [Parameter(Mandatory=$True)]
        $UniversalFileList
        )
    $matchedFileList = @()
    Foreach($obj in $PlexMediaPath)
    {
        $mediaTitle = $obj.plexMediaPath.split('/')[-1]
        $match = $fileList | Where {$_.Name -eq $mediaTitle}
        if($match -ne $null)
        {
            $matchedFileList += $match
        }
        else 
        {
            return    
        }
        return $matchedFileList.FullName
    }        
}

Function Get-PlexToken {
    <#
        Based on original Powershell to pull token posted on Plex forum by ccarvell-plex.
    
        Updated to be a function, and to accept PSCredentials passed in via get-credential
    #>
        param(
            [Parameter(Mandatory=$True)]
            [System.Management.Automation.PSCredential]$Credential
            )
       
        $url = "https://plex.tv/users/sign_in.xml"
        $headers = @{}
        $headers.Add("Authorization","Basic $($EncodedPassword)") | out-null
        $headers.Add("X-Plex-Client-Identifier","TESTSCRIPTV1") | Out-Null
        $headers.Add("X-Plex-Product","Test script") | Out-Null
        $headers.Add("X-Plex-Version","V1") | Out-Null
        [xml]$res = Invoke-RestMethod -Headers:$headers -Method Post -Uri:$url -Credential $Credential
        $token = $res.user.authenticationtoken
        return $token
    }
    
    
Function Set-Conv2Mp4
{
	param(
        [Parameter(Mandatory=$True)]
        $Path,
		[ValidateSet('mkv','avi','flv','mpeg','ts')]
		$FileTypes,
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
        $OutPath,
        $plexToken = [string]"plextoken",
        $tempScriptRoot
        )

    #Configure parameters for local use
    switch ($FileTypes) {
        'mkv' { $SetFileTypeTo = "*." + $Filetypes };
        'avi' { $SetFileTypeTo = "*." + $Filetypes };
        'flv' { $SetFileTypeTo = "*." + $Filetypes };
        'mpeg' { $SetFileTypeTo = "*." + $Filetypes };
        'ts' { $SetFileTypeTo = "*." + $Filetypes };
        Default { $SetFileTypeTo = "*.mkv", "*.avi", "*.flv", "*.mpeg", "*.ts" }
    }
	#Create lock file (for the purpose of ensuring only one instance of this script is running)
    $lockPath = $tempScriptRoot
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
	$fileList = Get-ChildItem "$($mPath.FullName)\*" -i $SetFileTypeTo -recurse 
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
		$plexURL = "http://$($plexIP):$($plexPort)/library/sections/all/refresh?X-Plex-Token=$plexToken"
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
