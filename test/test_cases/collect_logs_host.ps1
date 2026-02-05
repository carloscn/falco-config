# Collect real Falco logs per IDPS case (IDIADA compliance)
# Run from project root: .\test\test_cases\collect_logs_host.ps1

$idpsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $idpsDir "IDIADA_FALCO_LOGS"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$cases = Get-ChildItem -Path $idpsDir -Filter "SYS-*.sh" | Where-Object { 
    $_.Name -notmatch "run_all|collect_" 
} | Sort-Object Name

foreach ($f in $cases) {
    $caseId = $f.BaseName
    $logFile = Join-Path $outDir "$caseId.log"
    Write-Host ">>> $caseId"
    
    docker exec falco-test-ubuntu sudo truncate -s 0 /var/log/falco.log 2>$null
    Start-Sleep -Milliseconds 500
    
    docker exec falco-test-ubuntu bash -c "cd /opt/falco-test/test_cases && bash $($f.Name)" 2>$null | Out-Null
    Start-Sleep -Seconds 2
    
    $logContent = docker exec falco-test-ubuntu cat /var/log/falco.log 2>$null
    $header = @"
# IDIADA Compliance - Real Falco Detection Log
# Case: $caseId
# Collected: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
# Test script: $($f.Name)
# ----------------------------------------

"@
    if ($logContent) {
        Set-Content -Path $logFile -Value ($header + $logContent) -Encoding UTF8
    } else {
        Set-Content -Path $logFile -Value ($header + "# (No Falco detection for this case)") -Encoding UTF8
    }
    Write-Host "    -> $logFile"
}
Write-Host "`nDone. Output: $outDir"
