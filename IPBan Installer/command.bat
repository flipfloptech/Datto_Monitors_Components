#Requires -Version 5.0
#Functions
Function RDPNetworkLevelAuthentication([bool]$Enabled)
{
    [bool]$returnResult = $False
    if ($PSVersionTable.PSVersion.Major -gt 3)
    {
        $cimInstance = Get-CimInstance Win32_TSGeneralSetting -FIlter "TerminalName='RDP-tcp'" -Namespace "root\cimv2\terminalservices"
        if ($cimInstance -ne $null)
        {
            Invoke-CimMethod -InputObject $cimInstance -MethodName "SetUserAuthenticationRequired" -Arguments @{"UserAuthenticationRequired" = [int]$Enabled} | Out-Null
            [bool]$returnResult = $True
        }
    }
    else {
        $wmiObject = Get-WmiObject -Query "Select * FROM Win32_TSGeneralSetting WHERE TerminalName = 'RDP-tcp'" -Namespace "root\cimv2\terminalservices"
        if ($wmiObject -ne $null)
        {
            $wmiObject.SetUserAuthenticationRequired([int]$Enabled) | Out-Null
            [bool]$returnResult = $True
        }
    }
    return $returnResult
}
Function GetProcessParent([int]$ProcessID)
{
    $returnResult = -1
    if ($PSVersionTable.PSVersion.Major -gt 3)
    {
        $cimInstance = Get-CimInstance Win32_Process -Filter "ProcessID = '$ProcessID'"
        if ($cimInstance -ne $null)
        {
            $returnResult = $cimInstance.ParentProcessId
        }
    }
    else {
        $wmiObject = Get-WmiObject -Query "Select * FROM Win32_Process WHERE ProcessID = $ProcessID"
        if ($wmiObject -ne $null)
        {
            $returnResult = $wmiObject.ParentProcessId
        }
    }
    return $returnResult
}
Function FindAndKillNotepad([int]$ParentProcessID)
{
    $find_Notepad = Get-Process -Name "notepad" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($find_Notepad.Count -ge 1)
    {
        foreach($Notepad in $find_Notepad)
        {
            $processParent = GetProcessParent($Notepad.Id)
            if  ($processParent -eq $ParentProcessID) {
                #found ipban notebad process
                Write-Host "Found notepad process($($Notepad.Id)) terminating."
                Stop-Process -Id $Notepad.Id -Force
                return $True
            }
            $processParent = $null
        }
    }
    return $False
}
#Variables
$ipBanInstallation = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/DigitalRuby/IPBan/master/IPBanCore/Windows/Scripts/install_latest.ps1'))"
$ipBanServiceName = "IPBAN"
#BeginScript
try {
    Write-Host -NoNewline "Enabling Windows Defender Firewall..."
    Set-Service -Name "mpssvc" -StartupType Automatic -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Start-Service -Name "mpssvc"
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction Stop -WarningAction Continue
    Write-Host "Enabled"
}
catch {
    Write-Host "ERROR"
    exit 1
}

try {
  Write-Host -NoNewLine "Is IPBAN Installed? "
  $ipBanService = Get-Service -Name $ipBanServiceName -ErrorAction Stop -WarningAction Stop
  Write-Host -NoNewLine "Yes and it is $($ipBanService.Status)"
  if ($ipBanService.Status -eq "Running") {
    exit 0
  }
  else {
    exit 1
  }
}
catch
{
  Write-Host "No"
}
try {
  Write-Host "Installing IPBAN."
  $bytes_ipBanInstallation = [System.Text.Encoding]::Unicode.GetBytes($ipBanInstallation)
  $encoded_ipBanInstallation = [Convert]::ToBase64String($bytes_ipBanInstallation)
  $installArgs = @("-encodedCommand",$encoded_ipBanInstallation)
  Write-Host -NoNewLine "Spawning Powershell Installer: "
  $installProcess = Start-Process "powershell.exe" -WindowStyle hidden -ArgumentList $installArgs -PassThru
  Write-Host $installProcess.Id
  $loop_Bailout = $False
  $loop_Count = 0
  Write-Host "Waiting for notepad to spawn confirming installation completion."
  while ($installProcess.ExitCode -eq $null -and $loop_Bailout -eq $False)
  {
    #powershell is running
    if (FindAndKillNotepad($installProcess.Id) -eq $True)
    {
        $loop_Bailout = $True
        break;
    } else {
        $loop_Count++
        if ($loop_Count -gt 10)
        {
            Write-Host "!!!! TIME OUT WAITING FOR NOTEPAD TO SPAWN. INSTLLATION MAY HAVE FAILED !!!"
            $loop_Bailout = $true
        }
        else {
            Write-Host ".... Waiting 30 more seconds for Installation to complete ...."
            Start-Sleep -Seconds 30
        }
    }
  }
  FindAndKillNotepad($installProcess.Id) | Out-Null
  $ipBanService = Get-Service -Name $ipBanServiceName -ErrorAction Stop -WarningAction Stop
  if ($ipBanService -ne $null) {
    Write-Host "Installation Completed"
    if ([Environment]::OSVersion.Version.Major -le 6 -and [Environment]::OSVersion.Version.Minor -le 2)
    {
        Write-Host "Detected Windows Version older then Windows Server 2012 / Windows 8."
        Write-Host "IPBan Requires NLA being Disabled."
        RDPNetworkLevelAuthentication($False)
    }
    else {
        Write-Host "Enabled NLA for Remote Desktop"
        RDPNetworkLevelAuthentication($True)
    }
    try {
        Write-host -NoNewline "Starting IPBAN..."
        Start-Service -Name $ipBanServiceName -ErrorAction Stop -WarningAction Stop
        Write-Host "STARTED"
        exit 0
    }
    catch {
        Write-Host "FAILED"
        exit 1
    }
  }
  else {
      Write-Host "Installation Failed"
      exit 1
  }
  exit 1
}
catch {
  Write-Host "Unhandled Exception"
  Write-Host $_
  exit 1
}