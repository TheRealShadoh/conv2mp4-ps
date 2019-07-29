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

Example Scenario: Keep Subs No Plex
    The script targets a parent directory containing sub folders for Anime, Movies, and TV Shows. 
    The script does not keep subtitles, and does not update plex when complete. 

#>

# Module Import
Import-Module C:\git\conv2mp4-ps\modules\conv2mp4.psm1 -Force

# Configure personalized parameters
$mediaPath = "\\192.168.1.5\media"
$plexIP = "192.168.1.9"
$ffmpegDir = "C:\ffmpeg\bin"
$handbrakeDir = "C:\Program Files\HandBrake"

# Do the thing
Set-Conv2Mp4 -Path $mediaPath -PlexIP $plexIP -ffmpegDir $ffmpegDir -HandbrakeDir $handbrakeDir -KeepSubs $True -UsePlex $false
