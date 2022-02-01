#Requires -Version 5.0
$Scheduled = $False
$SessionManager = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
$PendingRenameProperty = "PendingFileRenameOperations"
$filePath = "$($env:TEMP)\chkdsk.txt"
$newRenameOperation =  [System.Collections.Generic.List[string]]::new()
$physicalVolumes = Get-WmiObject win32_logicaldisk | where-object { $_.DriveType -eq 3}
foreach($volume in $physicalVolumes) {
  if ($volume.DeviceID.ToLower() -contains "c:") {
    $run_line = "/C ECHO Y | chkdsk /F "
    if ([System.Convert]::ToBoolean($env:IncludeBadSectors) -eq $True) { 
      $run_line += " /R "
    }
    $run_line += "$($volume.DeviceID)"
  }
  else {
    $run_line = "/C ECHO N > $filePath; ECHO Y >> $filePath; TYPE $filePath | chkdsk /F "
    if ([System.Convert]::ToBoolean($env:IncludeBadSectors) -eq $True) { 
      $run_line += " /R "
    }
    $run_line += "$($volume.DeviceID)"
  }
  Start-Process -WindowStyle Hidden -FilePath "$($env:SystemRoot)\System32\cmd.exe" -ArgumentList $run_line
  $Scheduled = $True
}
if ($Scheduled) {
    if (Test-Path $SessionManager\$PendingRenameProperty) {
      $currentRenameOperation = Get-ItemPropertyValue -Path $SessionManager -Name $PendingRenameProperty
      foreach($fileRenameItem in $currentRenameOperation) {
        if ([string]::IsNullOrWhiteSpace($item) -eq $False) { [void]$newRenameOperation.Add($fileRenameItem) }
      }
      Remove-ItemProperty -Path $SessionManager -Name $PendingRenameProperty
    }
    $newRenameOperation.Add($filePath)
    $sbPropertyValue = [System.Text.StringBuilder]::new()
    $count=1
    $maxcount=$newRenameOperation.Count
    foreach($fileRenameItem in $newRenameOperation) {
      [void]$sbPropertyValue.Append($fileRenameItem)
      if ($count -lt $maxcount) {
        [void]$sbPropertyValue.Append([char]0)
        [void]$sbPropertyValue.Append([char]0)
      }
      else {
        [void]$sbPropertyValue.Append([char]0)
      }
      $count++
    }
    New-ItemProperty -Path $SessionManager -Name $PendingRenameProperty -PropertyType MultiString | Out-Null
    Set-ItemProperty -Path $SessionManager -Name $PendingRenameProperty -Value $sbPropertyValue.ToString() | Out-Null
    New-Item -Type File -Path "$env:AllUsersProfile\CentraStage\reboot.flag" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
}
