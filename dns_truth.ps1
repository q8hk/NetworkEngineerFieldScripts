param(
    [string]$Hostname,
    [string]$Server,
    [string]$Public,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "dns_truth.ps1 - Compare DNS answers."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  dns_truth.ps1 -Hostname example.com [-Server 192.0.2.53] [-Public 8.8.8.8]"
    Write-Host ""
    Write-Host "Exit codes: 0 healthy (answers align), 1 mismatch/inconclusive, 2 usage error, 3 unexpected failure"
}

if ($Help -or $args -contains '/?' -or -not $Hostname) {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

function Resolve-Host {
    param($Target, $ServerArg)
    try {
        $params = @{Name=$Target; Type='A'; ErrorAction='Stop'}
        if ($ServerArg) { $params.Server = $ServerArg }
        $records = Resolve-DnsName @params | Where-Object { $_.Type -eq 'A' }
        return ($records.IPAddress | Sort-Object -Unique)
    } catch {
        return @()
    }
}

$logPath = New-ToolkitLog -ToolName "dns_truth" -KeyParts @($Hostname)
Write-ToolkitHeader -Title "DNS Truth" -Path $logPath -Metadata @{Host=$Hostname; Server=$Server; Public=$Public}

$defaultAns = Resolve-Host -Target $Hostname
$customAns = if ($Server) { Resolve-Host -Target $Hostname -ServerArg $Server } else { @() }
$publicAns = if ($Public) { Resolve-Host -Target $Hostname -ServerArg $Public } else { @() }

Write-ToolkitLog ("System DNS : {0}" -f ($defaultAns -join ',')) -Path $logPath
if ($Server) { Write-ToolkitLog ("Server {0}: {1}" -f $Server, ($customAns -join ',')) -Path $logPath }
if ($Public) { Write-ToolkitLog ("Public {0}: {1}" -f $Public, ($publicAns -join ',')) -Path $logPath }

$allSets = @($defaultAns, $customAns, $publicAns) | Where-Object { $_ }
$result = "HEALTHY"
$exitCode = $ToolkitExitCodes.Success
if ($allSets.Count -gt 1) {
    $first = ($allSets[0] -join ',')
    foreach ($set in $allSets) {
        if (($set -join ',') -ne $first) {
            $result = "PROBLEM"
            $exitCode = $ToolkitExitCodes.Problem
            break
        }
    }
}
if (-not $defaultAns) {
    $result = "INCONCLUSIVE"
    $exitCode = $ToolkitExitCodes.Problem
}

Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
