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
Use this script as an example, the script targets a parent directory containing sub folders for Anime, Movies, and TV Shows. 

#>


Import-Module C:\git\conv2mp4-ps\modules\conv2mp4.psm1 -Force
$tempScriptRoot = "C:\git\conv2mp4-ps"
Set-Conv2Mp4 -Path "\\192.168.1.5\media" -PlexIP "192.168.1.9" -ffmpegDir "C:\ffmpeg\bin" -HandbrakeDir "C:\Program Files\HandBrake" -KeepSubs $True -UsePlex $True -tempScriptRoot $tempScriptRoot
