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

Example Scenario: Keep Subs Yes Plex
    The script targets a parent directory containing sub folders for Anime, Movies, and TV Shows. 
    The script keeps subtitles, and does update plex when complete. 
    The script connects to plex.tv and uses the credentials you've supplied to pull the Plex token, which is then used to update plex after conversion. Currently this requires internet access.

#>

# Module Import
Import-Module C:\git\conv2mp4-ps\modules\conv2mp4.psm1 -Force

# Gather credeentials for plex
$creds = Get-Credential -Message "Enter your Plex credentials, they will be used to get the plex token. *NOTE* Once you've gotten the token, you can reuse the token, negating the need to execute this portion"

# Configure personalized parameters
$mediaPath = "\\192.168.1.5\media"
$plexIP = "192.168.1.9"
$ffmpegDir = "C:\ffmpeg\bin"
$handbrakeDir = "C:\Program Files\HandBrake"
$plexToken = Get-PlexToken -Credential $creds # Internet access is required for this module at this time.

# Do the thing
Set-Conv2Mp4 -Path $mediaPath -PlexIP $plexIP -ffmpegDir $ffmpegDir -HandbrakeDir $handbrakeDir -KeepSubs $True -UsePlex $True -plexToken $plexToken
