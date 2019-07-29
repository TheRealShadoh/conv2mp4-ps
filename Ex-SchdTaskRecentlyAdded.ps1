<#
Author: TheRealShadoh
Dependencies:
            -   Clone the github files to your system
            -   Download ffmpeg
            -   Download Handbrake CLI
Script Setup:
            -   Import the conv2mp4.psm1 file, targetting where you've place it
            -   Call Set-Conv2Mp4 and fill in the parameters, not all parameters are mandatory
            -   Get-help on specific modules for more information

Example Scenario: Scan new files on Plex, convert if needed, to be used as a scheduled task
    The script targets a parent directory containing sub folders for Anime, Movies, and TV Shows. 
    The script keeps subtitles, and does not update plex when complete. 
    Requires you to have executed the Get-PlexToken module and recorded the token. Enter the recorded token in the configuration section of this script.
    The script creates a timestamp.txt file in the running directory, this file is used to determine the last run time, and which files are newer than
        that file. The first time you run the script this file is created. 

#>
# Module Import
Import-Module C:\git\conv2mp4-ps\modules\conv2mp4.psm1 -Force

# Configure personalized parameters
$mediaPath = "\\192.168.1.5\media"
$plexIP = "192.168.1.9"
$ffmpegDir = "C:\ffmpeg\bin"
$handbrakeDir = "C:\Program Files\HandBrake"
$plexToken = "" # Execute Get-PlexToken and paste the returned token into this variable.



#############################
# DONT EDIT BELOW THIS LINE #
#############################

# Setup time values
$currentTime = (Get-Date (Get-Date).ToUniversalTime() -UFormat %s).split('.')[0]

#First run file creation for time stamp
if((Test-Path -Path $PSScriptRoot+"\timestamp.txt") -ne $false)
{
	$currentTime | Out-File -FilePath $PSScriptRoot+"\timestamp.txt"
}

#Get last run time 
$lastRunTime = Get-Content -Path "$PSScriptRoot\timestamp.txt"

# Pull recently added files from plex
$recentFiles = Get-PlexRecentlyAddded -PlexIP $plexip -plexToken $plexToken

# Return files added after last scan (lastRunTime)
# Match the plex media path and the path found in the universal file list
$recentlyAddedFileList = @()
Foreach ($obj in $recentFiles)
{
	if (Compare-AddedTimeCurrentTime -LastRunTime $lastRunTime -AddedTime $obj.dateAdded)
	{
		$match = Get-PlexMediaPath -PlexMediaPath $obj -UniversalFileList $fileList	
		$recentlyAddedFileList += $match
	}
}
$fileList = $recentlyAddedFileList | Get-ChildItem

# Convert matched files, keep subs, update Plex for each file completed. 
Foreach ($obj in $fileList)
{
    Set-Conv2Mp4 -Path $mediaPath -PlexIP $plexIP -ffmpegDir $ffmpegDir -HandbrakeDir $handbrakeDir -KeepSubs $True -UsePlex $True -plexToken $plexToken
}