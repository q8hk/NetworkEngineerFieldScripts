param(
    [switch]$IncludeNetstat,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "net_snapshot.ps1 - Capture network state to a log file."
    Write-Host ""
    Write-Host "Usage: net_snapshot.ps1 [--include-netstat] [--help]"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "net_snapshot" -KeyParts @()
Write-ToolkitHeader -Title "Network Snapshot" -Path $logPath -Metadata @{IncludeNetstat=$IncludeNetstat}

function Append-Command {
    param($Label,$Command)
    Write-ToolkitLog ("### {0}" -f $Label) -Path $logPath
    try {
        $output = Invoke-Expression $Command 2>&1
        Add-Content -Path $logPath -Value $output
    } catch {
        Write-ToolkitLog ("Failed to run {0}: {1}" -f $Command, $_.Exception.Message) -Path $logPath
    }
    Write-ToolkitLog "" -Path $logPath
}

Append-Command -Label "ipconfig /all" -Command "ipconfig /all"
Append-Command -Label "route print" -Command "route print"
Append-Command -Label "arp -a" -Command "arp -a"
Append-Command -Label "netsh interface ip show config" -Command "netsh interface ip show config"
if ($IncludeNetstat) {
    Append-Command -Label "netstat -ano" -Command "netstat -ano"
}

Complete-ToolkitRun -Result "HEALTHY" -LogPath $logPath -ExitCode $ToolkitExitCodes.Success
