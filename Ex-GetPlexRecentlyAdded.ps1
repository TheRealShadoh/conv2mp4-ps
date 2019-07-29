<#
Author: TheRealShadoh
Dependencies:
            -   Clone the github files to your system
Script Setup:
            -   Import the conv2mp4.psm1 file, targetting where you've place it

Example Scenario: Get Plex Recently Added

#>

# Module Import
Import-Module C:\git\conv2mp4-ps\modules\conv2mp4.psm1 -Force

# Gather credeentials for plex
$creds = Get-Credential -Message "Enter your Plex credentials, they will be used to get the plex token. *NOTE* Once you've gotten the token, you can reuse the token, negating the need to execute this portion"

# Configure personalized parameters
$plexIP = "192.168.1.9"
$plexToken = Get-PlexToken -Credential $creds # Internet access is required for this module at this time.

# Do the thing
$recentFiles = Get-PlexRecentlyAddded -PlexIP $plexip -plexToken $plexToken # Parsing of the list to determine what you care about is not covered here, example of current time in the same format as this variable has $currentTime = (Get-Date (Get-Date).ToUniversalTime() -UFormat %s).split('.')[0]
