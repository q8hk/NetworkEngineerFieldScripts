param(
    [switch]$List,
    [string]$Run,
    [string[]]$Args,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "tool_index.ps1 - Discover and launch toolkit commands."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  tool_index.ps1 --list"
    Write-Host "  tool_index.ps1 --run <tool> [args...]"
    Write-Host "  tool_index.ps1            # interactive menu"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "tool_index" -KeyParts @()
$mode = "interactive"
if ($List) {
    $mode = "list"
} elseif ($Run) {
    $mode = "run"
}
$promptForUpdate = ($mode -eq "interactive")
Write-ToolkitHeader -Title "Tool Index" -Path $logPath -Metadata @{Mode=$mode}

Invoke-ToolkitUpdateCheck -LogPath $logPath -Prompt:$promptForUpdate

$tools = @(
    @{Name="arp_watch_once.cmd"; Description="Observe ARP for a single IP"; Path="arp_watch_once.cmd"},
    @{Name="who_has_ip.cmd"; Description="Discover MAC/vendor for an IP"; Path="who_has_ip.cmd"},
    @{Name="subnet_scan_lite.cmd"; Description="Lightweight subnet sweep"; Path="subnet_scan_lite.cmd"},
    @{Name="dhcp_renew_trace.cmd"; Description="DHCP renew with timing"; Path="dhcp_renew_trace.cmd"},
    @{Name="dhcp_lease_diff.ps1"; Description="Diff DHCP lease snapshots"; Path="dhcp_lease_diff.ps1"},
    @{Name="ip_conflict_detect.cmd"; Description="Detect duplicate IP usage"; Path="ip_conflict_detect.cmd"},
    @{Name="nic_health.cmd"; Description="NIC health summary"; Path="nic_health.cmd"},
    @{Name="interface_flap_detect.cmd"; Description="Monitor link flaps"; Path="interface_flap_detect.cmd"},
    @{Name="dns_truth.cmd"; Description="Compare DNS answers"; Path="dns_truth.cmd"},
    @{Name="reverse_dns_audit.cmd"; Description="PTR vs A check"; Path="reverse_dns_audit.cmd"},
    @{Name="normalize_mac.cmd"; Description="Normalize MAC formats"; Path="normalize_mac.cmd"},
    @{Name="net_snapshot.cmd"; Description="Capture network snapshot"; Path="net_snapshot.cmd"},
    @{Name="diff_snapshots.ps1"; Description="Diff snapshots"; Path="diff_snapshots.ps1"},
    @{Name="privilege_check.cmd"; Description="Admin status"; Path="privilege_check.cmd"},
    @{Name="self_check.cmd"; Description="Toolkit prerequisite check"; Path="self_check.cmd"}
)

function Print-Tools {
    param($Path)
    $i = 1
    foreach ($t in $tools) {
        $line = ("{0}. {1} - {2}" -f $i, $t.Name, $t.Description)
        Write-ToolkitLog $line -Path $Path
        $i++
    }
}

function Launch-Tool {
    param($Entry, $ExtraArgs, $LogPath)
    $path = Join-Path $PSScriptRoot $Entry.Path
    if (-not (Test-Path -LiteralPath $path)) {
        Write-ToolkitLog "Tool not found: $($Entry.Name)" -Path $LogPath
        return $ToolkitExitCodes.Problem
    }
    Write-ToolkitLog ("Launching {0} {1}" -f $Entry.Name, ($ExtraArgs -join ' ')) -Path $LogPath
    if ($path -like "*.ps1") {
        powershell -NoProfile -ExecutionPolicy Bypass -File $path @ExtraArgs | Out-Host
    } else {
        & $path @ExtraArgs | Out-Host
    }
    if ($null -eq $LASTEXITCODE) {
        return 0
    }
    return [int]$LASTEXITCODE
}

if ($List) {
    Print-Tools -Path $logPath
    Complete-ToolkitRun -Result "HEALTHY" -LogPath $logPath -ExitCode $ToolkitExitCodes.Success
}

if ($Run) {
    $match = $tools | Where-Object { $_.Name -ieq $Run -or $_.Path -ieq $Run }
    if (-not $match) {
        Write-ToolkitLog "Unknown tool: $Run" -Path $logPath
        Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Usage
    }
    $code = Launch-Tool -Entry $match -ExtraArgs $Args -LogPath $logPath
    $result = if ($code -eq 0) { "HEALTHY" } else { "PROBLEM" }
    Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $code
}

# Interactive
Write-ToolkitLog "Toolkit index - select a tool:" -Path $logPath
Print-Tools -Path $logPath
$choice = Read-Host "Enter number"
$parsed = 0
if (-not [int]::TryParse($choice, [ref]$parsed)) {
    Write-ToolkitLog "Invalid selection." -Path $logPath
    Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Usage
}
$idx = [int]$parsed
if ($idx -lt 1 -or $idx -gt $tools.Count) {
    Write-ToolkitLog "Selection out of range." -Path $logPath
    Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Usage
}
$selected = $tools[$idx-1]
$extra = Read-Host "Optional arguments for $($selected.Name)"
if ($extra) {
    $extraArgs = $extra -split '\s+'
} else {
    $extraArgs = @()
}
$code = Launch-Tool -Entry $selected -ExtraArgs $extraArgs -LogPath $logPath
$result = if ($code -eq 0) { "HEALTHY" } else { "PROBLEM" }
Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $code
