param(
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "privilege_check.ps1 - Report admin privileges and impact."
    Write-Host ""
    Write-Host "Usage: privilege_check.ps1 [--help]"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "privilege_check" -KeyParts @()
Write-ToolkitHeader -Title "Privilege Check" -Path $logPath -Metadata @{}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

Write-ToolkitLog ("Is Administrator: {0}" -f $isAdmin) -Path $logPath
Write-ToolkitLog "------------------------------------------------------------" -Path $logPath
Write-ToolkitLog "Tools needing admin for best results:" -Path $logPath
Write-ToolkitLog "  - dhcp_renew_trace (--release)" -Path $logPath
Write-ToolkitLog "  - net_snapshot (netstat may require admin on locked-down hosts)" -Path $logPath
Write-ToolkitLog "  - interface_flap_detect (reading some drivers)" -Path $logPath
Write-ToolkitLog "  - arp_watch_once / who_has_ip (ARP tables may be limited without admin)" -Path $logPath

$result = if ($isAdmin) { "HEALTHY" } else { "INCONCLUSIVE" }
$exitCode = if ($isAdmin) { $ToolkitExitCodes.Success } else { $ToolkitExitCodes.Success }

Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
