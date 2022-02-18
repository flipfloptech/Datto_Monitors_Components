$dnsFilterSvc = Get-Service -Name "DNSFilter Agent" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace($env:DnsFilter_SiteToken) -eq $True) {
  Write-Error "No Site Secret Key Specified"
  exit 1
}
if ($dnsFilterSvc -ne $null) {
  Write-Host "Stopping DNSFilter Service"
  try {
    Stop-Service -Name "DNSFilter Agent"
    Write-Host "Stopped DNSFilter Service" 
  }
  catch {
    Write-Error "Failed to Stop DNSFilter Service"
    exit 1
  }
  try {
    Write-Host "Updating Site Secret Key"
    Set-ItemProperty -Path HKLM:\Software\DNSFilter\Agent -Name "NetworkKey" -Value $env:DnsFilter_SiteToken
    Write-Host "Updated Site Secret Key to: $($env:DnsFilter_SiteToken)"
  }
  catch {
    Write-Error "Failed to Update Site Secret Key"
    exit 1
  }
  Write-Host "Starting DNSFilter Service"
  try {
    Start-Service -Name "DNSFilter Agent"
    Write-Host "Started DNSFilter Service" 
  }
  catch {
    Write-Error "Failed to Start DNSFilter Service"
    exit 1
  }
  $dnsFilterSvc=Get-Service -Name "DNSFilter Agent"
  Write-Host "DNSFilter Service status: $($dnsFilterSvc.Status)"
  exit 0
}else{
  Write-Host "DNSFilter not Installed"
  exit 0
}