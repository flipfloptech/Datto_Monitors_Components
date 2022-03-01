#Requires -Version 5.0
function Import-PowerHtml {
    If (-not (Get-Module -ErrorAction Ignore -ListAvailable PowerHTML)) {
        Write-Host "[!] PowerHTML NOT FOUND [!]"
        Write-Host -NoNewLine "[*] Installing PowerHTML module..."
        try {
            Install-Module PowerHTML -Scope CurrentUser -Force -Confirm:$False -ErrorAction Stop
            Write-Host "INSTALLED"
        }
        catch {
            Write-Host "FAILED"
            throw "Installation of PowerHTML module Failed"
        }
    }
    try {
        Write-Host -NoNewLine "[*] Importing PowerHTML module..."
        Import-Module -ErrorAction Stop PowerHTML
        Write-Host "IMPORTED"
    }
    catch {
        Write-Host "FAILED"
        throw "Importation of PowerHTML module Failed"
    }
}
function Download-TechPowerUpSoftware {
    param (
        [string]$TechPowerUpLabel,
        [int]$TechPowerUpID,
        [int]$TechPowerUpServerID
    )
    $OutputFileName = $null
    $ProgressPreference = 'SilentlyContinue'
    try {
        $DownloadResponse = Invoke-WebRequest -Method POST -Uri "https://www.techpowerup.com/download/$($TechPowerUplabel)" -Body "id=$($TechPowerUpID)&server_id=$($TechPowerUpServerID)"
        if ($DownloadResponse.StatusCode -eq 200) {
            $DownloadedFileName = $DownloadResponse.BaseResponse.ResponseUri.Segments[-1]
            $OutputFileName = Join-Path "$($PSScriptRoot)" -ChildPath "$($DownloadedFileName)"
            Set-Content -Path $OutputFileName -Value $DownloadResponse.Content -Encoding Byte -Force -Confirm:$False
        }
    }
    catch {
        $OutputFileName = $null
    }
    $ProgressPreference = 'Continue'
    return $OutputFileName
}
function Get-TechPowerUpDownloadServers {
    param(
        [string]$TechPowerUpLabel,
        [int]$TechPowerUpID
    )
    $ServerListResponse = Invoke-WebRequest -Method POST -Uri "https://www.techpowerup.com/download/$($TechPowerUpLabel)" -Body "id=$($TechPowerUpID)"
    $htmlData = ConvertFrom-Html -Content $ServerListResponse.Content
    $downloadButtons = $htmlData.SelectNodes("//button")
    $DownloadServers = @()
    try {
        foreach($downloadButton in $downloadButtons)
        {
            $SubElements = $downloadButton.Elements("span")
            $ServerID = $downloadButton.Attributes["value"].Value
            $IsServerClosest = $False
            $ServerName = $null
            $ServerLoad = $null
            foreach($SubElement in $SubElements)
            {
                if ($SubElement.InnerText -like "TechPowerUp*") {
                    $ServerName = $SubElement.InnerText.Split(" ")[1]
                }
                elseif ($SubElement.InnerText -like "Server load:*") {
                    $ServerLoad = $SubElement.InnerText.Split(":")[1].Trim().Replace("%","")
                }
                elseif ($SubElement.InnerText -like "(closest to you)") {
                    $IsServerClosest = $True
                }
            }
            $DownloadServers += [PSCustomObject] @{
                ID = $ServerID
                Name = $ServerName
                Load = [System.Convert]::ToUInt16($ServerLoad)
                Closest = $IsServerClosest
            }
        }
    }
    catch {
        Write-Error $_
        $DownloadServers = @()
    }
    return $DownloadServers
}
#Component Variables
$env:ForceReboot = $False
$env:ForceRebootDelay = 4
$env:UseClosestServer = $False
#BeginCode
try {
    Import-PowerHtml
}
catch {
    exit 1
}
$DownloadServers = Get-TechPowerUpDownloadServers -TechPowerUpLabel "visual-c-redistributable-runtime-package-all-in-one" -TechPowerUpID 2060
if ($DownloadServers.Count -le 0) {
    Write-Host "[!] UNABLE TO GET DOWNLOAD SERVERS [!]"
    exit 1
}
$SelectedServer = $null
$ClosestServer = $DownloadServers | Where-Object { $_.Closest -eq $True }
$FastestServer = $DownloadServers[0]
foreach($DownloadServer in $DownloadServers) {
    if ($DownloadServer.Load -eq 0) { break } #we already have as fast as it can be
    if ($DownloadServer.Load -lt $FastestServer.Load) { $FastestServer = $DownloadServer }
}
if ([System.Convert]::ToBoolean($env:UseClosestServer) -eq $True) { 
    $SelectedServer = $ClosestServer 
} else { 
    $SelectedServer = $FastestServer 
}
Write-Host "[*] Selected Server Details [*]"
Write-Host " Server: $($SelectedServer.Name)"
Write-Host "   Load: $($SelectedServer.Load)"
Write-Host "Closest: $($SelectedServer.Closest)"
Write-Host -NoNewLine "[*] Downloading TechPowerUp Installation Files..."
$WorkingFile = $null
try {
    $WorkingFile = Download-TechPowerUpSoftware -TechPowerUpLabel "visual-c-redistributable-runtime-package-all-in-one" -TechPowerUpID 2060 -TechPowerUpServerID $SelectedServer.ID    
    Write-Host "DOWNLOADED"
}
catch {
    $WorkingFile = $Null
    Write-Host "FAILED"
    exit 1
}
Write-Host "[*] Saved file to $($WorkingFile)"
$ExtractedPath = Join-Path "$($PSScriptRoot)" -ChildPath "$([System.IO.Path]::GetRandomFileName())"
Write-Host -NoNewLine "[*] Extracting downloaded file contents..."
$ProgressPreference = 'SilentlyContinue'
try {
    New-Item -Path $ExtractedPath -ItemType Directory -Force -Confirm:$False | Out-Null
    Expand-Archive -Path $WorkingFile -DestinationPath $ExtractedPath -Force:$True -Confirm:$False
    Write-Host "EXTRACTED"
}
catch {
    Write-Host "FAILED"
    exit 1
}
$ProgressPreference = 'Continue'
Write-Host "[*] Extracted file contents to $($ExtractedPath)"
$InstallPackagePath = Join-Path $ExtractedPath -ChildPath "install_all.bat"
Write-Host -NoNewLine "[*] Starting package installation..."
$InstallProcess = Start-Process -FilePath $InstallPackagePath -PassThru -Wait
Write-Host "COMPLETED."
Write-Host "[*] Installation Results [*]"
Write-Host "`tExitCode: $($InstallProcess.ExitCode)"
Write-Host "`t  Result:" -NoNewline
if ($InstallProcess.ExitCode -eq 0) {
    Write-Host "Success"
    exit 0
} elseif ($InstallProcess.ExitCode -eq 3010) {
    Write-Host "Reboot Required"
    if ($env:ForceReboot -eq $True) { 
        Write-Host "ForceReboot=true, rebooting."; 
        Start-Process -FilePath "$([System.Environment]::SystemDirectory)\shutdown.exe" -ArgumentList "/r","/f","/t",$env:ForceRebootDelay
    }
    exit 0
} else {
    Write-Host "Failed"
    Write-Host "Check ExitCode @ https://docs.microsoft.com/en-us/windows/win32/msi/error-codes"
}
exit 1