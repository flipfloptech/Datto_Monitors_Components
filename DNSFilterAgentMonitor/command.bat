#Requires -Version 2
$global:DNSFilter_ClientID = $null
$global:DNSFilter_LastApiSync = $null
$global:DNSFilter_Registered = $null
$global:DNSFilter_NetworkKey = $null
$global:DNSFilter_Version = $null
$global:DNSFilter_Status = $null
$global:DNSFilter_INSTALLED = $False
$global:DNSFilter_Result = $null
$global:DNSFilter_Message = $null
$global:DNSFilter_TryStart = 0
$global:DNSFilter_StartWait = 60
$svcName = "DNSFilter Agent"
$svcRegistry = "HKLM:\SOFTWARE\DNSFilter\Agent\"
$svcRegistryData = $null

function CreateDattoRMMAlert
{
    param([string]$Message)
    $rmmAlert = '<-Start Result->'
    $rmmAlert += ('Status=' + $Message)
    $rmmAlert += '<-End Result->'
    return $rmmAlert
}

function UpdateDiagnosticInfo
{
    if (Test-Path $svcRegistry) {
        $svcRegistryData = Get-ItemProperty -Path $svcRegistry
        $global:DNSFilter_ClientID = $svcRegistryData.ClientId
        $global:DNSFilter_NetworkKey = $svcRegistryData.NetworkKey
        $global:DNSFilter_Version = $svcRegistryData.Version
        $global:DNSFilter_LastApiSync = $svcRegistryData.LastApiSync
        $global:DNSFilter_Registered = $svcRegistryData.Registered
    }
}
function FormatDiagnosticInfo
{
    $DiagnosticData = ""
    $DiagnosticData += "`n     DNSFilter Status: $global:DNSFilter_Status`n"
    $DiagnosticData += "   DNSFilter ClientID: $global:DNSFilter_ClientID`n"
    $DiagnosticData += " DNSFilter NetworkKey: $global:DNSFilter_NetworkKey`n"
    $DiagnosticData += "    DNSFilter Version: $global:DNSFilter_Version`n"
    $DiagnosticData += "DNSFilter LastApiSync: $global:DNSFilter_LastApiSync`n"
    $DiagnosticData += " DNSFilter Registered: $global:DNSFilter_Registered`n"
    return $DiagnosticData;
}
function CreateDattoRMMDiagnostic
{
    $rmmDiagnostic = '<-Start Diagnostic->'
    $rmmDiagnostic += FormatDiagnosticInfo
    $rmmDiagnostic += '<-End Diagnostic->'
    return $rmmDiagnostic
}

$svcFound = Get-Service $svcName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
UpdateDiagnosticInfo
if ($null -ne $svcFound) {
    $global:DNSFilter_Status = $svcFound.Status
    while($global:DNSFilter_TryStart -le 1)
    {
        if ($global:DNSFilter_Status -eq "Running") {
            if ($global:DNSFilter_Registered -eq "1") {
                $lastSync = [datetime]::Parse($global:DNSFilter_LastApiSync)
                $global:DNSFilter_INSTALLED = $True 
                $global:DNSFilter_Message = "OK"
            }else {
                $global:DNSFilter_INSTALLED = $False
                $global:DNSFilter_Message = "NOT REGISTERED"
            }
            $global:DNSFilter_TryStart+=2
        }elseif ($global:DNSFilter_TryStart -eq 0) {
            try {
                $svcFound.Start()
                Start-Sleep $global:DNSFilter_StartWait
                $svcFound = Get-Service $svcName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                $global:DNSFilter_Status = $svcFound.Status
            }
            catch {
                $global:DNSFilter_INSTALLED = $False
                $global:DNSFilter_Message = "CANNOT START"
                $global:DNSFilter_TryStart += 2
            }
        }else {
            $global:DNSFilter_INSTALLED = $False
            $global:DNSFilter_Message = $global:DNSFilter_Status.ToString().ToUpper()
        }
        $global:DNSFilter_TryStart++
    }
}else {
    $global:DNSFilter_INSTALLED = $False
    $global:DNSFilter_Message = "NOT INSTALLED"
}
$global:DNSFilter_Result = CreateDattoRMMAlert($global:DNSFilter_Message)
if (!$global:DNSFilter_INSTALLED) {
   $global:DNSFilter_Result += "`n"
   $global:DNSFilter_Result += CreateDattoRMMDiagnostic
}
Write-Host $global:DNSFilter_Result
exit (!$global:DNSFilter_INSTALLED)