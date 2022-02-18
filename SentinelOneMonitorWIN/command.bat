#SentinelOne Override Script by Jon North, Datto, October 2019 :: sgl/build 3
#Modified/Fixed/Updated by Justin Oberdorf, ACS-ILM, October 2021
$SentinelSvc=(Get-service -name "SentinelAgent" -ErrorAction SilentlyContinue)
$SentinelSvcStatus = "NOT FOUND"
$SentinelSvcFound = $False
$SentinelSvcRunning = $False
$Global:LASTEXITCODE = 1
if ($SentinelSvc -ne $null) {
    $SentinelSvcFound = $True
    $SentinelSvcStatus = $SentinelSvc.Status.ToString()
    If ($SentinelSvcStatus.ToLower() -eq "running") {
        $SentinelSvcRunning=$True;
        $Global:LASTEXITCODE = 0
    } else {
        $SentinelSvcRunning=$False
        $Global:LASTEXITCODE = 1
    }
    $OutputJSON="{`"product`":`"Sentinel Agent`",`"running`":$($SentinelSvcRunning.ToString().ToLower()),`"upToDate`":$($SentinelSvcRunning.ToString().ToLower())}"
}
else {
    $OutputJSON="{`"product`":`"Sentinel Agent`",`"running`":false,`"upToDate`":false}"
}
$OutputJSON | Out-File -FilePath $Env:ProgramData\CentraStage\AEMAgent\antivirus.json -Force
write-host '<-Start Result->'
write-host "Status=$SentinelSvcStatus"
write-host '<-End Result->'
Write-Host '<-Start Diagnostic->'
Write-Host " Service Found: $SentinelSvcFound"
Write-Host "Service Status: $SentinelSvcStatus"
Write-Host "     Exit Code: $($Global:LASTEXITCODE)"
Write-Host '<-End Diagnostic->'
exit $Global:LASTEXITCODE