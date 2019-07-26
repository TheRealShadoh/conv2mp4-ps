Import-Module -Name C:\git\conv2mp4-ps\modules\conv2mp4.psm1 -force
$tempScriptRoot = "C:\git\conv2mp4-ps"

# CONFIG DATA

$PlexMediaPath = "\\192.168.1.5\media\"
$PlexIP = "192.168.1.9"
$ffmpegDir = "C:\ffmpeg\bin"
$HandbrakeDir = "C:\Program Files\HandBrake"

#############################
# DONT EDIT BELOW THIS LINE #
#############################


# Setup time values
$currentTime = (Get-Date (Get-Date).ToUniversalTime() -UFormat %s).split('.')[0]

#First run file creation for time stamp
if((Test-Path -Path $tempScriptRoot+"\timestamp.txt") -ne $false)
{
	$currentTime | Out-File -FilePath $tempScriptRoot+"\timestamp.txt"
}

#Get last run time 
$lastRunTime = Get-Content -Path C:\git\conv2mp4-ps\timestamp.txt

# Authenticate with Plex
Get-PlexCredential

# Pull recently added files from plex
$recentFiles = Get-PlexRecentlyAddded -PlexIP $plexip

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

Foreach ($obj in $fileList)
{
	Set-Conv2Mp4 -Path $PlexMediaPath  -PlexIP $PlexIP -ffmpegDir $ffmpegDir -HandbrakeDir $HandbrakeDir -KeepSubs $True -UsePlex $True -tempScriptRoot $tempScriptRoot
}