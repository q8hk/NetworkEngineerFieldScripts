param(
    [string]$IpAddress,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "reverse_dns_audit.ps1 - Validate PTR -> A consistency."
    Write-Host ""
    Write-Host "Usage: reverse_dns_audit.ps1 -IpAddress <IP>"
}

if ($Help -or $args -contains '/?' -or -not $IpAddress) {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

try { [System.Net.IPAddress]::Parse($IpAddress) | Out-Null } catch {
    Write-Host "Invalid IP."
    exit $ToolkitExitCodes.Usage
}

function ResolvePTR {
    param($IP)
    try {
        return (Resolve-DnsName -Name $IP -Type PTR -ErrorAction Stop | Select-Object -First 1).NameHost
    } catch { return $null }
}

function ResolveA {
    param($Host)
    try {
        return (Resolve-DnsName -Name $Host -Type A -ErrorAction Stop | Select-Object -ExpandProperty IPAddress)
    } catch { return @() }
}

$logPath = New-ToolkitLog -ToolName "reverse_dns_audit" -KeyParts @($IpAddress)
Write-ToolkitHeader -Title "Reverse DNS Audit" -Path $logPath -Metadata @{IP=$IpAddress}

$ptr = ResolvePTR -IP $IpAddress
if (-not $ptr) {
    Write-ToolkitLog "PTR lookup failed." -Path $logPath
    Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Problem
}

Write-ToolkitLog ("PTR -> {0}" -f $ptr) -Path $logPath
$aRecords = ResolveA -Host $ptr
Write-ToolkitLog ("A({0}) -> {1}" -f $ptr, ($aRecords -join ',')) -Path $logPath

$result = "HEALTHY"
$exitCode = $ToolkitExitCodes.Success
if (-not ($aRecords -contains $IpAddress)) {
    $result = "PROBLEM"
    $exitCode = $ToolkitExitCodes.Problem
}

Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
