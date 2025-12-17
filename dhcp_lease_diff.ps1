param(
    [string]$Before,
    [string]$After,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "dhcp_lease_diff.ps1 - Compare DHCP lease snapshots."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  dhcp_lease_diff.ps1 [-Before file] [-After file]"
    Write-Host "  dhcp_lease_diff.ps1   # captures current state and compares to last saved snapshot in /state"
    Write-Host ""
    Write-Host "Snapshots are stored as JSON for easy reuse."
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

$stateDir = Join-Path -Path $PSScriptRoot -ChildPath "state"
if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Path $stateDir | Out-Null }

function Capture-LeaseSnapshot {
    $items = @()
    $adapters = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address }
    foreach ($cfg in $adapters) {
        $lease = Get-DhcpClientLease -InterfaceAlias $cfg.InterfaceAlias -ErrorAction SilentlyContinue | Select-Object -First 1
        $items += [pscustomobject]@{
            Adapter = $cfg.InterfaceAlias
            IPv4    = ($cfg.IPv4Address | Select-Object -First 1).IPv4Address
            Gateway = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
            Dns     = $cfg.DnsServer.ServerAddresses
            LeaseObtained = if ($lease) { $lease.LeaseObtained } else { "" }
            LeaseExpires  = if ($lease) { $lease.LeaseExpires } else { "" }
        }
    }
    return $items
}

function Save-Snapshot {
    param($Path, $Data)
    $Data | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
}

function Load-Snapshot {
    param($Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return Get-Content -Raw -Path $Path | ConvertFrom-Json
}

$logPath = New-ToolkitLog -ToolName "dhcp_lease_diff" -KeyParts @()
Write-ToolkitHeader -Title "DHCP Lease Diff" -Path $logPath -Metadata @{}

if (-not $Before -and -not $After) {
    $Before = Join-Path $stateDir "dhcp_lease_latest.json"
    $currentPath = Join-Path $stateDir ("dhcp_lease_{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    $After = $currentPath
    $current = Capture-LeaseSnapshot
    Save-Snapshot -Path $After -Data $current
    if (-not (Test-Path -LiteralPath $Before)) {
        Copy-Item -Path $After -Destination $Before
        Write-ToolkitLog "First snapshot captured; saved for future comparisons." -Path $logPath
        Complete-ToolkitRun -Result "HEALTHY" -LogPath $logPath -ExitCode $ToolkitExitCodes.Success
    }
} elseif (-not $Before -or -not $After) {
    Write-ToolkitLog "Both -Before and -After must be specified together." -Path $logPath
    Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Usage
}

$beforeData = Load-Snapshot -Path $Before
$afterData = Load-Snapshot -Path $After
if (-not $beforeData -and -not $afterData) {
    Write-ToolkitLog "No snapshot data to compare." -Path $logPath
    Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Problem
}

Write-ToolkitLog ("Comparing {0} (before) -> {1} (after)" -f $Before, $After) -Path $logPath
$changesFound = $false

foreach ($afterItem in $afterData) {
    $match = $beforeData | Where-Object { $_.Adapter -eq $afterItem.Adapter }
    if (-not $match) {
        Write-ToolkitLog ("Adapter added: {0} ({1})" -f $afterItem.Adapter, $afterItem.IPv4) -Path $logPath
        $changesFound = $true
        continue
    }
    if ($match.IPv4 -ne $afterItem.IPv4) {
        Write-ToolkitLog ("{0}: IP {1} -> {2}" -f $afterItem.Adapter, $match.IPv4, $afterItem.IPv4) -Path $logPath
        $changesFound = $true
    }
    if ($match.Gateway -ne $afterItem.Gateway) {
        Write-ToolkitLog ("{0}: Gateway {1} -> {2}" -f $afterItem.Adapter, $match.Gateway, $afterItem.Gateway) -Path $logPath
        $changesFound = $true
    }
    if (($match.Dns -join ',') -ne ($afterItem.Dns -join ',')) {
        Write-ToolkitLog ("{0}: DNS {1} -> {2}" -f $afterItem.Adapter, ($match.Dns -join ','), ($afterItem.Dns -join ',')) -Path $logPath
        $changesFound = $true
    }
    if ($match.LeaseExpires -ne $afterItem.LeaseExpires) {
        Write-ToolkitLog ("{0}: Lease expires {1} -> {2}" -f $afterItem.Adapter, $match.LeaseExpires, $afterItem.LeaseExpires) -Path $logPath
        $changesFound = $true
    }
}

foreach ($beforeItem in $beforeData) {
    $exists = $afterData | Where-Object { $_.Adapter -eq $beforeItem.Adapter }
    if (-not $exists) {
        Write-ToolkitLog ("Adapter removed: {0}" -f $beforeItem.Adapter) -Path $logPath
        $changesFound = $true
    }
}

$result = if ($changesFound) { "PROBLEM" } else { "HEALTHY" }
$exitCode = if ($changesFound) { $ToolkitExitCodes.Problem } else { $ToolkitExitCodes.Success }

Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
