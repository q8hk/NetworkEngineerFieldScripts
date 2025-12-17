param(
    [string]$SnapshotA,
    [string]$SnapshotB,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "diff_snapshots.ps1 - Compare two network snapshots."
    Write-Host ""
    Write-Host "Usage: diff_snapshots.ps1 -SnapshotA path -SnapshotB path"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

if (-not $SnapshotA -or -not $SnapshotB) {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

if (-not (Test-Path $SnapshotA) -or -not (Test-Path $SnapshotB)) {
    Write-Host "Both snapshot files are required."
    exit $ToolkitExitCodes.Usage
}

function Parse-KeyFields {
    param($Path)
    $lines = Get-Content -Path $Path
    $ips = $lines | Select-String -Pattern "IPv4 Address.*: ([0-9\.]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
    $gw = $lines | Select-String -Pattern "Default Gateway.*: ([0-9\.]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
    $dns = $lines | Select-String -Pattern "DNS Servers.*: ([0-9\.]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
    $routes = $lines | Select-String -Pattern "0.0.0.0\s+0.0.0.0\s+([0-9\.]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
    return [pscustomobject]@{
        IPs=$ips
        Gateways=$gw
        DNS=$dns
        DefaultRoutes=$routes
    }
}

$logPath = New-ToolkitLog -ToolName "diff_snapshots" -KeyParts @()
Write-ToolkitHeader -Title "Diff Snapshots" -Path $logPath -Metadata @{A=$SnapshotA;B=$SnapshotB}

$a = Parse-KeyFields -Path $SnapshotA
$b = Parse-KeyFields -Path $SnapshotB

function Compare-List {
    param($Label,$ListA,$ListB)
    $uniqueA = ($ListA | Sort-Object -Unique) -join ','
    $uniqueB = ($ListB | Sort-Object -Unique) -join ','
    if ($uniqueA -ne $uniqueB) {
        Write-ToolkitLog ("{0}: {1} -> {2}" -f $Label, $uniqueA, $uniqueB) -Path $logPath
        return $true
    }
    return $false
}

$changes = $false
$changes = (Compare-List "IPv4" $a.IPs $b.IPs) -or $changes
$changes = (Compare-List "Gateway" $a.Gateways $b.Gateways) -or $changes
$changes = (Compare-List "DNS" $a.DNS $b.DNS) -or $changes
$changes = (Compare-List "Default route next hop" $a.DefaultRoutes $b.DefaultRoutes) -or $changes

if (-not $changes) {
    Write-ToolkitLog "No key differences detected." -Path $logPath
}

$result = if ($changes) { "PROBLEM" } else { "HEALTHY" }
$exitCode = if ($changes) { $ToolkitExitCodes.Problem } else { $ToolkitExitCodes.Success }
Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
