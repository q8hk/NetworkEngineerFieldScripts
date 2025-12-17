[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$IpAddress,
    [switch]$SelfTest,
    [switch]$Help
)

function Show-Usage {
    Write-Host "ip_conflict_detect.ps1 - Friendly wrapper around ip_conflict_detect.cmd"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\ip_conflict_detect.ps1 -IpAddress 192.0.2.10"
    Write-Host "  .\ip_conflict_detect.ps1 -SelfTest"
    Write-Host ""
    Write-Host "Exit codes: 0 (no conflict), 1 (conflict/problem), 2 (usage error), 3 (unexpected failure)"
}

if ($Help -or $PSBoundParameters.ContainsKey("Help") -or ($null -eq $IpAddress -and -not $SelfTest)) {
    Show-Usage
    exit 2
}

$cmdPath = Join-Path -Path $PSScriptRoot -ChildPath "ip_conflict_detect.cmd"
if (-not (Test-Path -Path $cmdPath)) {
    Write-Error "Cannot find ip_conflict_detect.cmd next to this script."
    exit 3
}

$argsList = @()
if ($SelfTest) {
    $argsList += "--self-test"
} elseif ($IpAddress) {
    $argsList += $IpAddress
}

$tmpOut = Join-Path $PSScriptRoot "ip_conflict_detect.tmp.out"
$process = Start-Process -FilePath $cmdPath -ArgumentList $argsList -NoNewWindow -PassThru -Wait -RedirectStandardOutput $tmpOut
$outputLines = Get-Content $tmpOut
Remove-Item $tmpOut -ErrorAction SilentlyContinue

$outputLines | ForEach-Object { Write-Host $_ }

$resultLine = $outputLines | Where-Object { $_ -match "^ Result" } | Select-Object -Last 1
$logLine = $outputLines | Where-Object { $_ -match "^ Log file" } | Select-Object -Last 1

if ($resultLine) {
    Write-Host ("[SUMMARY] " + $resultLine.Trim())
}
if ($logLine) {
    Write-Host ("[LOG] " + $logLine.Trim())
}

exit $process.ExitCode
