#Requires -Version 2
function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

function independent_IsNullOrWhiteSpace
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $InputString
    )
    if ([String]::IsNullOrWhiteSpace) { 
        return [String]::IsNullOrWhiteSpace($inputString)
    }elseif ([String]::IsNullOrEmpty) {
        return [String]::IsNullOrEmpty($inputString.Replace(" ",""))
    }
}

function Is64BitOS
{
    if ((gwmi win32_operatingsystem).osarchitecture -eq "64-bit") { return $True }else { return $False}
}
function IsInstalled
{
    $svcName = "DNSFilter Agent"
    $svcRegistry = "HKLM:\SOFTWARE\DNSFilter\Agent\"
    $svcFound = Get-Service $svcName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($svcFound -ne $null)
    {
        if (Test-Path $svcRegistry) {
            try {
                $svcRegistryData = Get-ItemProperty -Path $svcRegistry
                $DNSFilter_ClientID = $svcRegistryData.ClientId
                $DNSFilter_NetworkKey = $svcRegistryData.NetworkKey
                $DNSFilter_Version = $svcRegistryData.Version
                $DNSFilter_LastApiSync = $svcRegistryData.LastApiSync
                $DNSFilter_Registered = $svcRegistryData.Registered
                return $True
            }
            catch {

            }
        }
    }
    return $False
}
function checkCode ($code) {
    if ($code -gt 0) {
        write-host "Installation exited with code $code. This may indicate an error."
    } elseif ($code -eq 1603) {
        write-host "ERROR: Installation reported exit code 1603."
        write-host "  This is a generic Windows Installer error indicating a failure; please scrutinise"
        write-host "  the Windows Event Log on this device to see what the issue is."
        exit 1    
    }
}
$already_installed = IsInstalled
if ($already_installed -eq $False)
{
    $varSiteSecretKey = $ENV:DnsFilter_SiteToken
    $varScriptDirectory = Get-ScriptDirectory
    $varScriptPath = "$varScriptDirectory\DNSFilter.msi"
    if (Test-path $varScriptPath) { Remove-Item -Path $varScriptPath -Force -Confirm:$False }
    if ((independent_IsNullOrWhiteSpace -InputString $varSiteSecretKey) -eq $True)
    {
        Write-Error "Invalid Site Secret Key"
        exit 1
    }
    Write-Host "Building download URL"
    $dnsFilterBase = "https://download.dnsfilter.com/User_Agent/Windows/DNSFilter_Agent_Setup"
    $detected64bit = Is64BitOS
    if ($detected64bit -eq $False)
    {
        Write-Host "Detected x86 platform."
        $dnsFilterBase += "_x86"
    }else
    {
        Write-Host "Detected x64 platform."
    }
    $dnsFilterBase += ".msi"
    try {
        Write-Host "Downloading $dnsFilterBase to $varScriptPath"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($dnsFilterBase, $varScriptPath)
        Write-Host "Download completed"
    }
    catch {
        Write-Error "Download FAILED."
        exit 1
    }
    Write-Host "Installing DNSFilter with $varSiteSecretKey"
    # install
    msiexec /i "`"$varScriptPath`"" NKEY="`"$varSiteSecretKey`"" /qn /NORESTART
    $varLastCode=$LASTEXITCODE; checkCode $varLastCode
    Write-Host "Waiting 1 minute for installation to finish and service to start."
    Start-Sleep -Seconds 60
    $already_installed = IsInstalled
    if ($already_installed -eq $True)
    {
        write-host "DNS Filter Agent Installation Successful."
        exit 0
    }else {
        Write-Host "DNS Filter Agent Installation Failed."
        exit 1
    }
}else {
    Write-Host "DNS Filter Agent Already Installed."
    exit 0
}