param(
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "nic_health.ps1 - Summarize NIC health indicators."
    Write-Host ""
    Write-Host "Usage: nic_health.ps1 [--help]"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "nic_health" -KeyParts @()
Write-ToolkitHeader -Title "NIC Health" -Path $logPath -Metadata @{}

$adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
if (-not $adapters) {
    Write-ToolkitLog "No adapters found." -Path $logPath
    Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Problem
}

$suspicions = @()
foreach ($nic in $adapters) {
    Write-ToolkitLog ("Adapter: {0}" -f $nic.Name) -Path $logPath
    Write-ToolkitLog ("  Status  : {0}" -f $nic.Status) -Path $logPath
    Write-ToolkitLog ("  Link    : {0}" -f $nic.LinkSpeed) -Path $logPath
    Write-ToolkitLog ("  Driver  : {0} {1}" -f $nic.DriverName, $nic.DriverVersion) -Path $logPath
    $adv = Get-NetAdapterAdvancedProperty -Name $nic.Name -ErrorAction SilentlyContinue
    $power = $adv | Where-Object { $_.DisplayName -match "Power" }
    if ($power) {
        foreach ($p in $power) {
            Write-ToolkitLog ("  {0}: {1}" -f $p.DisplayName, $p.DisplayValue) -Path $logPath
        }
    }
    if ($nic.Status -ne 'Up') { $suspicions += "$($nic.Name): Down/Disabled" }
    $speedFlagged = $false
    if ($nic.LinkSpeed -match '([0-9\.]+)\s*Gbps') {
        $gbps = [double]$Matches[1]
        if ($gbps -lt 1) { $speedFlagged = $true }
    } elseif ($nic.LinkSpeed -match '([0-9\.]+)\s*Mbps') {
        $speedFlagged = $true
    }
    if ($speedFlagged) { $suspicions += "$($nic.Name): Link <$($nic.LinkSpeed)" }
    if ($power | Where-Object { $_.DisplayValue -match "Enabled" }) { $suspicions += "$($nic.Name): Power saving enabled" }
}

Write-ToolkitLog "------------------------------------------------------------" -Path $logPath
if ($suspicions.Count -eq 0) {
    Write-ToolkitLog "Suspicions: none" -Path $logPath
    Complete-ToolkitRun -Result "HEALTHY" -LogPath $logPath -ExitCode $ToolkitExitCodes.Success
} else {
    Write-ToolkitLog "Suspicions:" -Path $logPath
    $suspicions | ForEach-Object { Write-ToolkitLog ("  - {0}" -f $_) -Path $logPath }
    Complete-ToolkitRun -Result "PROBLEM" -LogPath $logPath -ExitCode $ToolkitExitCodes.Problem
}
