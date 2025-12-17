param(
    [string]$IpAddress,
    [int]$Seconds = 60,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "arp_watch_once.ps1 - Observe ARP activity for a single IP."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  arp_watch_once.ps1 -IpAddress <IP> [-Seconds <N>] [--help]"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  arp_watch_once.ps1 -IpAddress 192.0.2.10"
    Write-Host "  arp_watch_once.ps1 -IpAddress 198.51.100.15 -Seconds 120"
    Write-Host ""
    Write-Host "Exit codes: 0 healthy/inconclusive, 1 problem, 2 usage error, 3 unexpected failure"
}

if ($Help -or $args -contains '/?' -or -not $IpAddress) {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

try {
    Require-Argument -Value $IpAddress -Message "IP address is required."
    if ($Seconds -le 0) { throw "Seconds must be > 0." }
    [System.Net.IPAddress]::Parse($IpAddress) | Out-Null
} catch {
    Write-Host $_.Exception.Message
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "arp_watch_once" -KeyParts @($IpAddress, "$Seconds" + "s")
Write-ToolkitHeader -Title "ARP Watch Once" -Path $logPath -Metadata @{IP=$IpAddress; Duration="$Seconds seconds"}

$macStats = @{}
$result = "INCONCLUSIVE"
$exitCode = $ToolkitExitCodes.Success

for ($i = 1; $i -le $Seconds; $i++) {
    Write-ToolkitLog ("[{0}/{1}] Probing {2}" -f $i, $Seconds, $IpAddress) -Path $logPath
    try { ping -n 1 $IpAddress | Out-Null } catch {}
    $entries = arp -a $IpAddress 2>$null | Select-String -Pattern "([0-9a-f]{2}-){5}[0-9a-f]{2}" -AllMatches
    if ($entries) {
        foreach ($line in $entries) {
            $mac = ($line.Matches[0].Value).ToUpper()
            if (-not $macStats.ContainsKey($mac)) {
                $macStats[$mac] = [ordered]@{Count=0; First=$i; Last=$i}
                Write-ToolkitLog ("  New MAC observed: {0}" -f $mac) -Path $logPath
            }
            $macStats[$mac].Count++
            $macStats[$mac].Last = $i
        }
        if ($macStats.Keys.Count -gt 1) {
            $result = "PROBLEM"
            $exitCode = $ToolkitExitCodes.Problem
            break
        } else {
            $result = "HEALTHY"
            $exitCode = $ToolkitExitCodes.Success
        }
    }
    Start-Sleep -Seconds 1
}

if (-not $macStats.Keys.Count) {
    $result = "INCONCLUSIVE"
    $exitCode = $ToolkitExitCodes.Success
    Write-ToolkitLog "No ARP responses observed; marking INCONCLUSIVE." -Path $logPath
}

Write-ToolkitLog "------------------------------------------------------------" -Path $logPath
Write-ToolkitLog "Summary:" -Path $logPath
foreach ($mac in $macStats.Keys) {
    $info = $macStats[$mac]
    Write-ToolkitLog ("  {0} => Count: {1}, First: {2}s, Last: {3}s" -f $mac, $info.Count, $info.First, $info.Last) -Path $logPath
}
Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
