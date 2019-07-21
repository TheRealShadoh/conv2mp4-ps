$plexip = "192.168.1.9:32400"
$plexURL = "http://$plexIP/library/recentlyAdded/refresh?X-Plex-Token=$plexToken"


<#
 First run create a file recording the current epoch time
 After first run record time of last run
 Report files with a time stamp newer or equal to the last run time
 Compare media path file name to conv2mp4 file scan to pull correct file path
 Pass in new files to be scanned for conversion
#>
$currentTime = (Get-Date (Get-Date).ToUniversalTime() -UFormat %s).split('.')[0]
$lastRunTime = Get-Content -Path C:\git\conv2mp4-ps\timestamp.txt

$RawResult = Invoke-WebRequest $plexURL -UseBasicParsing -Method Get -ContentType 'application/json' -Headers @{"Accept"="application/json"}
$RawResult = ($RawResult.content | ConvertFrom-Json).mediacontainer.metadata
$RawResult = $RawResult | Where {$_.media -ne $null} # Filter to only return recently added video files
$RecentlyAddedArray = @()
ForEach($obj in $RawResult)
{
    $RemoteObj = New-Object PSCustomObject
    $RemoteObj | Add-Member -MemberType NoteProperty -Name dateAdded -Value $obj.addedAt # Epoch time
    $RemoteObj | Add-Member -MemberType NoteProperty -Name plexMediaPath -Value $obj.media.part.file # File path in relation to plex mapping
    
    if($RemoteObj.dateAdded -ge $lastRunTime)
    {
        $RecentlyAddedArray += $RemoteObj
    }
}
$RecentlyAddedArray


### DELETE FOR IMPLEMENTATION
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
$fileList = Get-ChildItem "$($mPath.FullName)\*" -i $fileTypes -recurse | Select FullName, name | ForEach-Object {$b++; If ($b -eq 1){Write-Host -NoNewLine "`rFound $b file so far..."} Else{Write-Host -NoNewLine "`rFound $b files so far..." -foregroundcolor green};$_}
$num = $fileList | measure
$fileCount = $num.count

### DELETE FOR IMPLEMENTATION ^^^^^


#Compare recentlyAddedArray to fileList
$matchedFileList = @()
Foreach($obj in $RecentlyAddedArray)
{
    $mediaTitle = $obj.plexMediaPath.split('/')[-1]
    $match = $fileList | Where {$_.Name -eq $mediaTitle}
    $matchedFileList += $match
}
$fileList = $matchedFileList.FullName
#Pass matchedFileList to conv2mp4.ps1
#$currentTime | Out-File -FilePath "$PSScriptRoot\timestamp.txt" # Remove old file first... still needs done...only execute if no errors
