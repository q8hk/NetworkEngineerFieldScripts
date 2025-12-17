param(
    [string]$Adapter,
    [switch]$Release,
    [switch]$Force,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "dhcp_renew_trace.ps1 - Safe DHCP renew with timing."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  dhcp_renew_trace.ps1 [-Adapter ""Name""] [--release --force] [--help]"
    Write-Host ""
    Write-Host "Defaults to renew-only. Release requires --release and --force to avoid accidental disconnects."
    Write-Host ""
    Write-Host "Exit codes: 0 healthy, 1 problem/inconclusive, 2 usage error, 3 unexpected failure"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

if ($Release -and -not $Force) {
    Write-Host "Release requested but --force not provided. Aborting for safety."
    exit $ToolkitExitCodes.Usage
}

try {
    $adapterObj = Resolve-ToolkitAdapter -AdapterName $Adapter
} catch {
    Write-Host $_.Exception.Message
    exit $ToolkitExitCodes.Usage
}

function Get-AdapterSnapshot {
    param($AdapterName)
    $cfg = Get-NetIPConfiguration -InterfaceAlias $AdapterName -ErrorAction SilentlyContinue
    if (-not $cfg) {
        return [pscustomobject]@{
            IP = ""
            Gateway = ""
            DNS = @()
            LeaseObtained = ""
            LeaseExpires = ""
        }
    }
    $lease = Get-DhcpClientLease -InterfaceAlias $AdapterName -ErrorAction SilentlyContinue | Select-Object -First 1
    return [pscustomobject]@{
        IP = ($cfg.IPv4Address | Select-Object -First 1).IPv4Address
        Gateway = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
        DNS = $cfg.DnsServer.ServerAddresses
        LeaseObtained = if ($lease) { $lease.LeaseObtained } else { "" }
        LeaseExpires = if ($lease) { $lease.LeaseExpires } else { "" }
    }
}

$logPath = New-ToolkitLog -ToolName "dhcp_renew_trace" -KeyParts @($adapterObj.Name)
Write-ToolkitHeader -Title "DHCP Renew Trace" -Path $logPath -Metadata @{Adapter=$adapterObj.Name; Release=$Release}

$before = Get-AdapterSnapshot -AdapterName $adapterObj.Name
Write-ToolkitLog "Before: IP=$($before.IP) GW=$($before.Gateway) DNS=$($before.DNS -join ',')" -Path $logPath

if ($Release) {
    Write-ToolkitLog "Releasing lease (forced)..." -Path $logPath
    ipconfig /release | Out-Null
}

Write-ToolkitLog "Renewing lease..." -Path $logPath
$sw = [System.Diagnostics.Stopwatch]::StartNew()
ipconfig /renew | Out-Null
$sw.Stop()

$after = Get-AdapterSnapshot -AdapterName $adapterObj.Name

Write-ToolkitLog ("After: IP={0} GW={1} DNS={2}" -f $after.IP, $after.Gateway, ($after.DNS -join ',')) -Path $logPath
Write-ToolkitLog ("Lease timing: {0} ms" -f $sw.ElapsedMilliseconds) -Path $logPath

$changes = @()
if ($before.IP -ne $after.IP) { $changes += "IP changed" }
if ($before.Gateway -ne $after.Gateway) { $changes += "Gateway changed" }
if (($before.DNS -join ',') -ne ($after.DNS -join ',')) { $changes += "DNS changed" }
if ($changes.Count -eq 0) { $changes = @("No changes detected") }

Write-ToolkitLog "Changes: $($changes -join '; ')" -Path $logPath

$result = "HEALTHY"
$exitCode = $ToolkitExitCodes.Success
if (-not $after.IP) {
    $result = "PROBLEM"
    $exitCode = $ToolkitExitCodes.Problem
    Write-ToolkitLog "No IP obtained after renew." -Path $logPath
}

Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
