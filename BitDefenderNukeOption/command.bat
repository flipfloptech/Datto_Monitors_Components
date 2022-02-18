#nuke GravityZone
Write-Host "Cleaning Up Registry Keys"
$GZRegistryKeyList = @("HKLM:\SOFTWARE\Bitdefender","HKLM:\SOFTWARE\Classes\CLSID\{D653647D-D607-4df6-A5B8-48D2BA195F7B}","HKLM:\SOFTWARE\Classes\TypeLib\{244B6BCD-AC0E-4F8D-BC75-0909CF809018}","HKLM:\SOFTWARE\Classes\WOW6432Node\TypeLib\{244B6BCD-AC0E-4F8D-BC75-0909CF809018}","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Endpoint Security","HKLM:\SOFTWARE\WOW6432Node\Classes\TypeLib\{244B6BCD-AC0E-4F8D-BC75-0909CF809018}")
foreach($GZRegistryKey in $GZRegistryKeyList)
{
    if (Test-Path "$($GZRegistryKey)")
    {
        try {
            Get-Item "$($GZRegistryKey)" | Remove-Item -Recurse -Force -Confirm:$False -ErrorAction Stop -WarningAction Stop
            Write-Host -ForegroundColor Green "Successfully removed: $($GZRegistryKey)"
        }
        catch {
            Write-Host -ForegroundColor Red "Failed to remove: $($GZRegistryKey)"
        }
    }
}
Write-Host "Cleaning Up Service Entries"
$GZServiceList = @("BdDci","bddevflt","BDElam","EPIntegrationService","EPProtectedService","EPRedline","EPSecurityService","EPUpdateService")
$GZServiceRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\"
foreach($GZService in $GZServiceList)
{
    if (Test-Path "$($GZServiceRoot)$($GZService)") {
        try {
            Get-Item "$($GZServiceRoot)$($GZService)" | Remove-Item -Recurse -Force -Confirm:$False -ErrorAction Stop -WarningAction Stop
            Write-Host -ForegroundColor Green "Successfully removed: $($GZServiceRoot)$($GZService)"
        }
        catch {
            Write-Host -ForegroundColor Red "Failed to remove: $($GZServiceRoot)$($GZService)"
        }
    }
}
Write-Host "Cleaning up Disk Locations"
$GZFilePathList = @("$($env:ALLUSERSPROFILE)\Bitdefender","$($env:ProgramFiles)\BitDefender")
foreach($GZFilePath in $GZFilePathList) {
    if (Test-Path "$($GZFilePath)") {
        try {
            Get-Item "$($GZFilePath)" | Remove-Item -Recurse -Force -Confirm:$False -ErrorAction Stop -WarningAction Stop
            Write-Host -ForegroundColor Green "Successfully removed: $($GZFilePath)"
        }
        catch {
            Write-Host -ForegroundColor Red "Failed to remove: $($GZFilePath)"
        }
    }
}
Write-Host -ForegroundColor Green "[!] If we made it this far we probably completed successfully!"
Write-Host -ForegroundColor Green "[!] Reboot out of Safemode and confirm!"