#Requires -version 4.0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Connect-SentinelOne {
    param (
        [Parameter(Mandatory)]
        [string]$ManagementURL,
        [Parameter(Mandatory)]
        [string]$APIToken,
        [Parameter(Mandatory)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
    )
    $objData = @{
        "data" = @{                       
            "reason" = "pwsh mgmt api"   
            "apiToken" = "$APIToken"
        } 
    }
    $jsonData = $objData | ConvertTo-Json
    $result = $null
    try {
        $request = Invoke-RestMethod -Method Post -Uri "$($ManagementURL)/web/api/v2.1/users/login/by-api-token" -Body $jsonData -ContentType "application/json" -WebSession $WebSession -ErrorAction Stop -WarningAction Stop
        if ([bool]($request.PSObject.Properties.name -match "data")) {
            if ([bool]($request.data.PSObject.Properties.name -match "token")) {
                $result = $request.data.token
            }
        }
    }
    catch {
        $result = $null
    }
    Start-Sleep -Seconds 1
    return $result
}
function Get-LatestPackages {
    Param
    (
      [Parameter(Mandatory)]
      [string]$ManagementURL,
      [Parameter(Mandatory)]
      [string]$APIAuthorizationToken,
      [Parameter(Mandatory)]
      [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
      [Parameter(Mandatory)]
      [ValidateSet("windows","macos","linux", IgnoreCase=$False)]
      [string]$OperatingSystem
    )   
    $headers = @{
        "Authorization" = "Token $($APIAuthorizationToken)"
    }
    $result = $null
    try {
        $osArches = "32 bit"
        if (Is64BitOS) { $osArches = "64 bit" }
        $PackagesURI = "$($ManagementURL)/web/api/v2.1/update/agent/packages?platformTypes=$($OperatingSystem)&sortBy=version&sortOrder=desc"
        if ($OperatingSystem -eq "windows")
        {
            $PackagesURI += "&osArches=$($osArches)"
            $PackagesURI += "&fileExtension=.msi"
        }
        $request = Invoke-RestMethod -Method Get -Uri $PackagesURI -WebSession $WebSession
        if ([bool]($request.PSObject.Properties.name -match "data")) {
            $result = $request.data
        }
    }
    catch {
        $result = $null
    }
    Start-Sleep -Seconds 30
    return $result
}
function Download-InstallationPackage {
    Param
    (
      [Parameter(Mandatory)]
      [PSCustomObject]$Package,
      [Parameter(Mandatory)]
      [string]$APIAuthorizationToken,
      [Parameter(Mandatory)]
      [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
    )
    $result = $null   
    $headers = @{
        "Authorization" = "Token $($APIAuthorizationToken)"
    }
    $InstallerDownloadPath = "$($env:TEMP)\$($Package.fileName)"
    if (Test-Path $InstallerDownloadPath) { Remove-Item $InstallerDownloadPath -Force -Confirm:$False }
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Method Get -Headers $headers -Uri $Package.link -OutFile $InstallerDownloadPath
        $ProgressPreference = 'Continue'
        if (Test-Path $InstallerDownloadPath)
        {
            #file downloaded check sha1
            $DownloadedInstallerHash = Get-FileHash -Path $InstallerDownloadPath -Algorithm SHA1
            if ($DownloadedInstallerHash.Hash.ToLower() -eq $Package.sha1.ToLower())
            {
                $result = $InstallerDownloadPath;
            }
            else {
                if (Test-Path $InstallerDownloadPath) { Remove-Item $InstallerDownloadPath -Force -Confirm:$False }
                $result = $null 
            }
        }
    }
    catch {
        if (Test-Path $InstallerDownloadPath) { Remove-Item $InstallerDownloadPath -Force -Confirm:$False }
        $result = $null
    }
    Start-Sleep -Seconds 30
    return $result
}
function Is64BitOS
{
    if ([IntPtr]::Size -eq 4) { return $False } else { return $True }
}
#variables that will be passed by dato
#$env:S1_ManagementURL = "https://sentinelone.net/"
#$env:S1_APIToken = ""
#$env:S1_SiteToken = ""
#$env:PackagePath = ""
#$env:PackageSHA1 = ""
#$env:ForceEmbedded = $False
#$env:ForceReboot = $False
#$env:ForceRebootDelay = 15
#installer code
Write-Host "S1 Deploy for Windows v1.0 by Justin Oberdorf"
Write-Host "---------------------------------------------"
$SentinelSvc=(Get-service -name "SentinelAgent" -ErrorAction SilentlyContinue)
if ($SentinelSvc -ne $null) {
  Write-Host "!!!!! S1 Service Found !!!!!"
  Write-Host "Status: $($SentinelSvc.Status)"
  exit 0
}
$WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession;
$ManagementURI = [System.Uri]$env:S1_ManagementURL
$APIAuthorizationToken = $null
$Global:LASTEXITCODE = 1
$InstallPackagePath = $null
if (([string]::IsNullOrWhiteSpace($env:PackagePath) -eq $False) -and ($env:ForceEmbedded -eq $False))
{
    if ([string]::IsNullOrWhiteSpace($env:PackageSHA1) -eq $False) {
        if (Test-Path $env:PackagePath) {
            $DownloadedInstallerHash = Get-FileHash -Path $env:PackagePath -Algorithm SHA1
            if ($DownloadedInstallerHash.Hash.ToLower() -eq $env:PackageSHA1.ToLower())
            {
                $InstallPackagePath = $env:PackagePath
                Write-Host "Using User Specified Package Path: $($env:PackagePath)"
            }
        }
    }
}
if (([string]::IsNullOrWhiteSpace($InstallPackagePath) -eq $True) -and ($env:ForceEmbedded -eq $False))
{
    Write-Host "Authenticating to S1"
    $APIAuthorizationToken = Connect-SentinelOne -ManagementURL $env:S1_ManagementURL -APIToken $env:S1_APIToken -WebSession $WebSession
    if ([string]::IsNullOrWhiteSpace($APIAuthorizationToken) -eq $False) {
        Write-Host "Logged In to SentinelOne"
        $Cookie  = New-Object System.Net.Cookie
        $Cookie.Name = "Authorization" # Add the name of the cookie
        $Cookie.Value = "Token $($APIAuthorizationToken)" # Add the value of the cookie
        $Cookie.Domain = $ManagementURI.Authority
        $WebSession.Cookies.Add($Cookie)
        Write-Host "Gathering Installation Packages"
        $CurrentPackages = Get-LatestPackages -ManagementURL $env:S1_ManagementURL -APIAuthorizationToken $APIAuthorizationToken -OperatingSystem windows -WebSession $WebSession
        if ($CurrentPackages -ne $null)
        {
            $LatestPackage = $CurrentPackages[0]
            Write-Host "Downloading Package:"
            Write-Host "`tFilename: $($LatestPackage.fileName)"
            Write-Host "`t Version: $($LatestPackage.version)"
            Write-Host "`t    SHA1: $($LatestPackage.sha1)"
            $LatestPackagePath = Download-InstallationPackage -Package $LatestPackage -APIAuthorizationToken $APIAuthorizationToken -WebSession $WebSession
            if ($LatestPackagePath -ne $null)
            {
                if (Test-Path $LatestPackagePath)
                {
                    Write-Host "Package Downloaded and Verified"
                    $InstallPackagePath = $LatestPackagePath
                }
            }
        } else {
            Write-Host "Failed to obtain list of packages."
            $Global:LASTEXITCODE = 1
        }
    } else {
        Write-Host "Failed to authenticate to S1`r`nPlease check the site settings S1_ManagmentURL, S1_APIToken, and S1_SiteToken.`r`nP.S. APITokens can expire."
        $Global:LASTEXITCODE = 1
    }
}
if (([string]::IsNullOrWhiteSpace($InstallPackagePath) -eq $True) -and ($env:ForceEmbedded -eq $True))
{
    Write-Host "Utilizing EMBEDDED Installer"
    $scriptExecutionPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.\')
    $EmbeddedPackageName = "SentinelInstaller_windows_"
    if (Is64BitOS -eq $True) {
        $EmbeddedPackageName += "64bit"
    } else {
        $EmbeddedPackageName += "32bit"
    }
    $EmbeddedPackageName+=".msi"
    $InstallPackagePath = "$scriptExecutionPath\$EmbeddedPackageName"
}
if ([string]::IsNullOrWhiteSpace($InstallPackagePath) -eq $False)
{
    if (Test-Path $InstallPackagePath) {
        Write-Host "Starting Installation"
        $InstallProcess = Start-Process -FilePath "$([System.Environment]::SystemDirectory)\msiexec.exe" -PassThru -ArgumentList "/I",$InstallPackagePath,"/q","/norestart","SITE_TOKEN=`"$($env:S1_SiteToken)`"" -Wait
        Write-Host "Installation Completed"
        Write-Host "`tExitCode: $($InstallProcess.ExitCode)"
        Write-Host "`t  Result:" -NoNewline
        if ($InstallProcess.ExitCode -eq 0) {
            Write-Host "Success"
            $Global:LASTEXITCODE = 0
        } elseif ($InstallProcess.ExitCode -eq 3010) {
            Write-Host "Reboot Required"
            $Global:LASTEXITCODE = 0
            if ($env:ForceReboot -eq $True) { 
                Write-Host "ForceReboot=true, rebooting."; 
                $ShutdownProcess = Start-Process -FilePath "$([System.Environment]::SystemDirectory)\shutdown.exe" -PassThru -ArgumentList "/r","/f","/t",$env:ForceRebootDelay
            }
        } else {
            Write-Host "Failed"
            Write-Host "Check ExitCode @ https://docs.microsoft.com/en-us/windows/win32/msi/error-codes"
            $Global:LASTEXITCODE = 1
        }
    } else {
        Write-Host "Package not Found"
        $Global:LASTEXITCODE = 1
    }
}
else {
    Write-Host "Package Invalid or Corrupt"
    $Global:LASTEXITCODE = 1
}
exit $Global:LASTEXITCODE