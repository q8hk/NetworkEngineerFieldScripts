param(
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "self_check.ps1 - Validate toolkit prerequisites."
    Write-Host ""
    Write-Host "Usage: self_check.ps1 [--help]"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "self_check" -KeyParts @()
Write-ToolkitHeader -Title "Toolkit Self-Check" -Path $logPath -Metadata @{}

$checks = @(
    @{Name="ping"; Command="ping"},
    @{Name="arp"; Command="arp"},
    @{Name="powershell"; Command="powershell"},
    @{Name="netsh"; Command="netsh"}
)

$failures = 0
foreach ($c in $checks) {
    $found = Get-Command $c.Command -ErrorAction SilentlyContinue
    if ($found) {
        Write-ToolkitLog ("{0}: OK" -f $c.Name) -Path $logPath
    } else {
        Write-ToolkitLog ("{0}: MISSING" -f $c.Name) -Path $logPath
        $failures++
    }
}

try {
    $dir = Get-LogDirectory
    $probe = Join-Path $dir "write_test.txt"
    "write-test" | Set-Content -Path $probe -Encoding UTF8
    Remove-Item $probe -Force
    Write-ToolkitLog "Log directory write: OK" -Path $logPath
} catch {
    Write-ToolkitLog "Log directory write: FAILED - $($_.Exception.Message)" -Path $logPath
    $failures++
}

$result = if ($failures -eq 0) { "HEALTHY" } else { "PROBLEM" }
$exitCode = if ($failures -eq 0) { $ToolkitExitCodes.Success } else { $ToolkitExitCodes.Problem }

Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
