$key =  "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\CentraStage"
$value = "DisplayVersion"
$ExitCode = 1;
if (Test-Path $key)
{
    Write-Host "[*] Datto RMM Installation Detected"
    $version = (Get-ItemProperty -Path $key -Name $value).$value

    $path = "C:\Windows\System32\config\systemprofile\AppData\Local\CentraStage\CagService.exe_Url_nin2uaxj2lsg1o0rsz2amvmcciusvum4\"
    $file = "\user.config"
    Write-Host "[*] Datto RMM Version: $($version)"
    $combo = "$($path)$($version)$($file)"
    if (Test-Path $combo)
    {
        Write-Host "[*] Datto RMM Configuration File Found"
        try {
            $xml = [xml](Get-Content "$($path)$($version)$($file)")
            $node = $xml.configuration.usersettings."CentraStage.Cag.Core.Settings".setting | Where-Object {$_.Name -eq 'PrivacyMode'}
            $privacyModeCurrentValue = $node.value
            $privacyModeNewValue = (![System.Convert]::ToBoolean($privacyModeCurrentValue)).ToString()
            $node.value = $privacyModeNewValue
            $xml.Save($combo)
            Write-Host "[*] PrivacyMode Status Changed"
            Write-Host "[*] Original Value: $($privacyModeCurrentValue)"
            Write-Host "[*]      New Value: $($privacyModeNewValue)"
            $ExitCode = 0
        }
        catch {
            Write-Host "[!] PrivacyMode Status Change Failed"
            Write-Error "ERROR: $($_)"
        }
        if ($ExitCode -eq 0)
        {
            $restart_args = @("-encodedCommand","UwB0AGEAcgB0AC0AUwBsAGUAZQBwACAALQBTAGUAYwBvAG4AZABzACAANgAwADsAIABTAHQAbwBwAC0AUAByAG8AYwBlAHMAcwAgAC0ATgBhAG0AZQAgACIAQwBhAGcAUwBlAHIAdgBpAGMAZQAiACAALQBGAG8AcgBjAGUAIAAtAEMAbwBuAGYAaQByAG0AOgAkAEYAYQBsAHMAZQA=")
            Start-Process -FilePath "powershell.exe" -ArgumentList $restart_args -WindowStyle Hidden
            Write-Host "[*] Scheduled CagService Termination in 60 seconds"
            Write-Host "[*] Please wait for CagService restart"
            Write-Host "[*] Device will report offline, then online"
        }
    } else {
        Write-Host "[!] Datto RMM Configuration File NOT Found"
    }
} else {
    Write-Host "[!] Datto RMM Installation NOT Detected"
}
exit $ExitCode