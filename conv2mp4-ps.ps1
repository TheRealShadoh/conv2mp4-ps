Import-Module C:\git\conv2mp4-ps\modules\conv2mp4.psm1 -Force
$tempScriptRoot = "C:\git\conv2mp4-ps"
Set-Conv2Mp4 -Path "\\192.168.1.5\media" -PlexIP "192.168.1.9" -ffmpegDir "C:\ffmpeg\bin" -HandbrakeDir "C:\Program Files\HandBrake" -KeepSubs $True -UsePlex $True -tempScriptRoot $tempScriptRoot
