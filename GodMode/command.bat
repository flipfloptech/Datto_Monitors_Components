#Requires -Version 3.0
#helper functions
function Get-UserSID {
    param (
        [String] $Username
    )
    $internal_ReturnValue = $null
    if ([string]::IsNullOrWhiteSpace($Username) -eq $False) {
        try {
            $internal_currentConsoleUser = (Get-WmiObject -class Win32_ComputerSystem).Username
            $internal_NTAccount = New-Object System.Security.Principal.NTAccount($internal_currentConsoleUser)
            $internal_SecurityIdentifier = $internal_NTAccount.Translate([System.Security.Principal.SecurityIdentifier])
            if ($internal_SecurityIdentifier -ne $null) {
                $internal_ReturnValue = $internal_SecurityIdentifier.Value
            }
        }
        catch { $internal_ReturnValue = $null }
    }
    return $internal_ReturnValue
}
function Get-UserProfilePath {
    param (
        [String] $Username
    )
    $internal_ReturnValue = $null
    if ([string]::IsNullOrWhiteSpace($Username) -eq $False) {
        try {
            $internal_consoleUserProfile = Get-WmiObject -Class Win32_UserProfile -Filter "SID = '$(Get-UserSID -Username $Username)'"
            if ($internal_consoleUserProfile -ne $null) {
                $internal_ReturnValue = $internal_consoleUserProfile.LocalPath
            }
        }
        catch { $internal_ReturnValue = $null }
    }
    return $internal_ReturnValue
}
function Get-UserDesktopPath {
    param (
        [String] $Username
    )
    $internal_ReturnValue = $null
    if ([string]::IsNullOrWhiteSpace($Username) -eq $False) {
        try {
            $internal_SID = Get-UserSID -Username $Username
            if ($internal_SID -ne $null)
            {
                New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
                $internal_ReturnValue = Get-ItemPropertyValue "HKU:\$internal_SID\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Desktop -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                Remove-PSDrive -Name HKU -PSProvider Registry -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Force -Confirm:$False | Out-Null
            }
        }
        catch { $internal_ReturnValue = $null }
    }
    return $internal_ReturnValue
}
#SCript
$env:GodModeTime=[int]$env:GodModeTime
$internal_LogFolder = "$((Get-WmiObject Win32_OperatingSystem).SystemDrive)\Temp"
$internal_LogPath = "$($internal_LogFolder)\datto_god_mode.log"
Write-Host "Console User God Mode v0.1b by Justin Oberdorf"
Write-Host "------------------------------------------------"
if ((Test-Path $internal_LogFolder) -eq $False) { New-Item -Path $internal_LogFolder -Force -Confirm:$False -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
$currentConsoleUser = (Get-WmiObject -class Win32_ComputerSystem).Username
$currentConsoleUserDesktopPath = Get-UserDesktopPath -Username $currentConsoleUser
if ([String]::IsNullOrWhiteSpace($currentConsoleUser) -eq $True) {
    Write-Host "NO CONSOLE USER PRESENT! THERE CAN BE NO GOD!"
    exit 0
}
if (([int]$env:GodModeTime -le 0) -or ([int]$env:GodModeTime -gt 480)) {
    Write-Host "Invalid GodMode Time Length Specified 1 to 480 minutes"
    exit 1
}
try {
    Write-Host "Adding $currentConsoleUser to local Administrators Group..." -NoNewLine
    Add-Content -Path "$internal_LogPath" -Value "Added $currentConsoleUser to Administrators group at $([DateTime]::Now.ToString())"
    Add-LocalGroupMember -Group "Administrators" -Member "$currentConsoleUser" -WarningAction Stop -ErrorAction Stop
    Write-Host "OK"
}
catch [Microsoft.PowerShell.Commands.PrincipalNotFoundException] {
    Write-Host "USER NOT FOUND."
    exit 1
}
catch [ Microsoft.PowerShell.Commands.ObjectExistsException] {
    Write-Host "EXISTS."
}
catch {
    Write-Host "ERROR OCCURED:"
    Write-Host $_
    exit 1
}
if ((Get-WmiObject win32_OperatingSystem).BuildNumber -ge 10240) {
    try {
        Write-Host "Creating Windows 10 and above GodMode Folder..." -NoNewline
        if ([string]::IsNullOrWhiteSpace($currentConsoleUserProfilePath) -eq $False) {
            New-Item -Path "$($currentConsoleUserDesktopPath)\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}" -ItemType Directory -Force -Confirm:$False | Out-Null
            Write-Host "OK."
        }
    }
    catch { Write-Host "ERROR." }
}
$task_Name = "Console User God Mode Cleanup Task"
$task_Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($env:GodModeTime)
$task_User = "NT AUTHORITY\SYSTEM"
$plain_pwshRemoveGodmode = "Remove-LocalGroupMember -Group `"Administrators`" -Member `"$currentConsoleUser`"; Remove-Item -Path `"$($currentConsoleUserDesktopPath)\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}`" -Force -Confirm:`$False -ErrorAction SilentlyContinue -WarningAction SilentlyContinue;Unregister-ScheduledTask -TaskName `"$task_Name`" -Confirm:`$False; Add-Content -Path `"$internal_LogPath`" -Value `"Removed $currentConsoleUser from Administrators group at `$([DateTime]::Now.ToString())`";"
$bytes_pwshRemoveGodmode = [System.Text.Encoding]::Unicode.GetBytes($plain_pwshRemoveGodmode)
$encoded_pwshRemoveGodmode = [Convert]::ToBase64String($bytes_pwshRemoveGodmode)
$task_Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-encodedCommand $encoded_pwshRemoveGodmode"
$task_Settings = New-ScheduledTaskSettingsSet -DisallowHardTerminate:$False -StartWhenAvailable -WakeToRun -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
try {
    Write-Host "Creating Scheduled Task to remove God Mode..." -NoNewLine
    Register-ScheduledTask -TaskName $task_Name -Settings $task_Settings -Trigger $task_Trigger -User $task_User -Action $task_Action -RunLevel Highest -Force -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
    $task_Created = Get-ScheduledTask -TaskName $task_Name -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($task_Created -eq $null) { throw "Task Creation Failed" }
    $task_Created.Author = "Atlantic Computer Services"
    $task_Created.Settings.AllowHardTerminate = $True
    $task_Created.Settings.volatile = $False
    $task_Created | Set-ScheduledTask | Out-Null
    Write-Host "CREATED."
    exit 0
}
catch {
    Write-Host "Scheduled task creation failed. Cleaning up."
    try {
        Write-Host "Removing scheduled task if exists..."
        Unregister-ScheduledTask -TaskName $task_Name -Confirm:$False -WarningAction Stop -ErrorAction Stop
        Write-Host "OK"
    }
    catch [System.ArgumentException] {
        Write-Host "DOES NOT EXIST."
    }
    catch {
        Write-Host "ERROR OCCURED:"
        Write-Host $_
    }
    try {
        Write-Host "Removing $currentConsoleUser from local Administrators Group..." -NoNewLine
        Add-Content -Path "$internal_LogPath" -Value "Removed $currentConsoleUser from Administrators group at $([DateTime]::Now.ToString())"
        Remove-LocalGroupMember -Group "Administrators" -Member "$currentConsoleUser" -WarningAction Stop -ErrorAction Stop
        Write-Host "OK"
    }
    catch [Microsoft.PowerShell.Commands.PrincipalNotFoundException] {
        Write-Host "USER NOT FOUND."
    }
    catch {
        Write-Host "ERROR OCCURED:"
        Write-Host $_
    }
    if ((Get-WmiObject win32_OperatingSystem).BuildNumber -ge 10240) {
        try {
            Write-Host "Removing Windows 10 and above God Mode Folder..." -NoNewline
            if ([string]::IsNullOrWhiteSpace($currentConsoleUserProfilePath) -eq $False) {
                if ((Test-Path "$($currentConsoleUserProfilePath)\Desktop\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}") -eq $True)
                {
                    Remove-Item -Path "$($currentConsoleUserProfilePath)\Desktop\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}" -Force -Confirm:$False | Out-Null
                    Write-Host "OK."
                } else { Write-Host "NOT FOUND." }
            }
        }
        catch { Write-Host "ERROR." }
    }
    Write-Host "Verify User Was Removed!"
    exit 1
}