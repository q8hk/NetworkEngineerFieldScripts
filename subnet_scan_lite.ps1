param(
    [string]$Subnet,
    [int]$TimeoutMs = 500,
    [int]$MaxHosts = 256,
    [switch]$Force,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "subnet_scan_lite.ps1 - Quick ping/ARP sweep."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  subnet_scan_lite.ps1 -Subnet <CIDR or base/24> [-TimeoutMs 500] [-MaxHosts 256] [--force]"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  subnet_scan_lite.ps1 -Subnet 192.0.2.0/24"
    Write-Host "  subnet_scan_lite.ps1 -Subnet 10.0.0.0/23 --force"
    Write-Host ""
    Write-Host "Exit codes: 0 healthy, 1 problem/inconclusive, 2 usage error, 3 unexpected failure"
}

if ($Help -or $args -contains '/?' -or -not $Subnet) {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

function ConvertTo-Network {
    param([string]$Cidr)
    if (-not ($Cidr -match '/')) {
        $Cidr = "$Cidr/24"
    }
    $parts = $Cidr -split '/'
    if ($parts.Count -ne 2) { throw "Invalid subnet." }
    $ipBytes = [System.Net.IPAddress]::Parse($parts[0]).GetAddressBytes()
    $prefix = [int]$parts[1]
    if ($prefix -lt 1 -or $prefix -gt 32) { throw "Invalid prefix." }
    $ipInt = ($ipBytes[0] -shl 24) -bor ($ipBytes[1] -shl 16) -bor ($ipBytes[2] -shl 8) -bor $ipBytes[3]
    $mask = [uint32]0
    for ($i=0; $i -lt $prefix; $i++) { $mask = $mask -bor (1 -shl (31-$i)) }
    $networkInt = $ipInt -band $mask
    $broadcastInt = $networkInt -bor ([uint32]~$mask)
    return [pscustomobject]@{
        NetworkInt   = $networkInt
        BroadcastInt = $broadcastInt
        Prefix       = $prefix
    }
}

function ConvertFrom-UInt32IP {
    param([uint32]$Value)
    $b1 = ($Value -shr 24) -band 255
    $b2 = ($Value -shr 16) -band 255
    $b3 = ($Value -shr 8) -band 255
    $b4 = $Value -band 255
    return [System.Net.IPAddress]::new([byte[]]@($b1,$b2,$b3,$b4))
}

try {
    $net = ConvertTo-Network -Cidr $Subnet
} catch {
    Write-Host "Invalid subnet. Use CIDR like 192.0.2.0/24"
    exit $ToolkitExitCodes.Usage
}

$hostCount = [int64]($net.BroadcastInt - $net.NetworkInt - 1)
$maxToScan = [Math]::Min($hostCount, $MaxHosts)

$logPath = New-ToolkitLog -ToolName "subnet_scan_lite" -KeyParts @( (ConvertFrom-UInt32IP $net.NetworkInt), "max$maxToScan")
Write-ToolkitHeader -Title "Subnet Scan Lite" -Path $logPath -Metadata @{Subnet=$Subnet; TimeoutMs=$TimeoutMs; MaxHosts=$maxToScan}
if ($hostCount -gt $MaxHosts -and -not $Force) {
    Write-ToolkitLog ("Large subnet ({0} hosts). Scanning capped at {1}; use --force to scan more." -f $hostCount, $maxToScan) -Path $logPath
}

$alive = @()
$count = 0
for ($ipInt = $net.NetworkInt + 1; $ipInt -lt $net.BroadcastInt; $ipInt++) {
    $count++
    if ($count -gt $maxToScan) { break }
    $ipAddress = (ConvertFrom-UInt32IP $ipInt).IPAddressToString
    Write-ToolkitLog ("[{0}/{1}] Pinging {2}" -f $count, $maxToScan, $ipAddress) -Path $logPath
    $proc = Start-Process -FilePath ping -ArgumentList @("-n","1","-w",$TimeoutMs,$ipAddress) -NoNewWindow -PassThru -Wait
    $aliveEntry = arp -a $ipAddress 2>$null | Select-String -Pattern "([0-9a-f]{2}-){5}[0-9a-f]{2}" -SimpleMatch | Select-Object -First 1
    if ($proc.ExitCode -eq 0 -or $aliveEntry) {
        $mac = if ($aliveEntry) { $aliveEntry.Matches[0].Value.ToUpper().Replace('-',':') } else { "" }
        $hostName = try { [System.Net.Dns]::GetHostEntry($ipAddress).HostName } catch { "" }
        $alive += [pscustomobject]@{
            IP = $ipAddress
            MAC = $mac
            Hostname = $hostName
        }
    }
}

Write-ToolkitLog "------------------------------------------------------------" -Path $logPath
Write-ToolkitLog ("Alive hosts: {0}" -f $alive.Count) -Path $logPath
foreach ($row in $alive) {
    Write-ToolkitLog ("  {0,-16} {1,-18} {2}" -f $row.IP, $row.MAC, $row.Hostname) -Path $logPath
}

$result = if ($alive.Count -gt 0) { "HEALTHY" } else { "INCONCLUSIVE" }
$exitCode = if ($alive.Count -gt 0) { $ToolkitExitCodes.Success } else { $ToolkitExitCodes.Problem }
Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
