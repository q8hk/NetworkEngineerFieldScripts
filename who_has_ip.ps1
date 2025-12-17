param(
    [string]$IpAddress,
    [string]$OuiFile = "$PSScriptRoot/data/oui.csv",
    [switch]$NoVendor,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "who_has_ip.ps1 - Identify the MAC/vendor using an IP."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  who_has_ip.ps1 -IpAddress <IP> [-OuiFile <path>] [--no-vendor] [--help]"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  who_has_ip.ps1 -IpAddress 192.0.2.10"
    Write-Host "  who_has_ip.ps1 -IpAddress 198.51.100.5 -OuiFile data/oui.csv"
    Write-Host ""
    Write-Host "Exit codes: 0 healthy, 1 inconclusive/problem, 2 usage error, 3 unexpected failure"
}

if ($Help -or $args -contains '/?' -or -not $IpAddress) {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

try {
    [System.Net.IPAddress]::Parse($IpAddress) | Out-Null
} catch {
    Write-Host "Invalid IP address."
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "who_has_ip" -KeyParts @($IpAddress)
Write-ToolkitHeader -Title "Who Has IP" -Path $logPath -Metadata @{IP=$IpAddress; VendorLookup=(! $NoVendor)}

Write-ToolkitLog "Pinging to warm ARP cache..." -Path $logPath
try { ping -n 2 $IpAddress | Out-Null } catch {}
$arpOutput = arp -a $IpAddress 2>$null
$arpLine = $arpOutput | Select-String -Pattern "([0-9a-f]{2}-){5}[0-9a-f]{2}" | Select-Object -First 1
$ifaceLine = $arpOutput | Select-String -Pattern "Interface:" | Select-Object -First 1
$interface = if ($ifaceLine) { ($ifaceLine.ToString() -split ':\s*')[1].Split()[0] } else { "unknown" }

if (-not $arpLine) {
    Write-ToolkitLog "No ARP entry found. Result: INCONCLUSIVE" -Path $logPath
    Complete-ToolkitRun -Result "INCONCLUSIVE" -LogPath $logPath -ExitCode $ToolkitExitCodes.Problem
}

$macRaw = ($arpLine.Matches[0].Value).ToUpper()
$normalized = $macRaw -replace '-', ':'

$vendor = "Unknown"
if (-not $NoVendor) {
    if (Test-Path -LiteralPath $OuiFile) {
        try {
            $prefix = $normalized.Replace(":", "").Substring(0,6)
            $csv = Import-Csv -Path $OuiFile
            $hit = $csv | Where-Object { $_.Prefix.Replace(":","").Replace("-","").Substring(0,6).ToUpper() -eq $prefix } | Select-Object -First 1
            if ($hit) { $vendor = $hit.Vendor }
        } catch {
            Write-ToolkitLog "Vendor lookup failed: $($_.Exception.Message)" -Path $logPath
        }
    } else {
        Write-ToolkitLog "OUI file not found at $OuiFile. Skipping vendor lookup." -Path $logPath
    }
}

Write-ToolkitLog ("IP     : {0}" -f $IpAddress) -Path $logPath
Write-ToolkitLog ("MAC    : {0}" -f $normalized) -Path $logPath
Write-ToolkitLog ("Vendor : {0}" -f $vendor) -Path $logPath
Write-ToolkitLog ("Iface  : {0}" -f $interface) -Path $logPath

Complete-ToolkitRun -Result "HEALTHY" -LogPath $logPath -ExitCode $ToolkitExitCodes.Success
