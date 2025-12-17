param(
    [int]$Seconds = 60,
    [string]$Adapter,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "interface_flap_detect.ps1 - Monitor link state flaps."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  interface_flap_detect.ps1 [-Adapter ""Name""] [-Seconds 60]"
}

if ($Help -or $args -contains '/?') {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

if ($Seconds -le 0) {
    Write-Host "Seconds must be > 0"
    exit $ToolkitExitCodes.Usage
}

try {
    $adapterObj = Resolve-ToolkitAdapter -AdapterName $Adapter
} catch {
    Write-Host $_.Exception.Message
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "interface_flap_detect" -KeyParts @($adapterObj.Name, "$Seconds" + "s")
Write-ToolkitHeader -Title "Interface Flap Detect" -Path $logPath -Metadata @{Adapter=$adapterObj.Name; Duration="$Seconds seconds"}

$timeline = @()
$lastStatus = (Get-NetAdapter -Name $adapterObj.Name).Status
for ($i=1; $i -le $Seconds; $i++) {
    $status = (Get-NetAdapter -Name $adapterObj.Name).Status
    if ($status -ne $lastStatus) {
        $timeline += ("{0}s: {1} -> {2}" -f $i, $lastStatus, $status)
        Write-ToolkitLog ("[{0}s] State change: {1} -> {2}" -f $i, $lastStatus, $status) -Path $logPath
        $lastStatus = $status
    }
    Start-Sleep -Seconds 1
}

$flaps = $timeline.Count
Write-ToolkitLog "------------------------------------------------------------" -Path $logPath
Write-ToolkitLog ("Flap count: {0}" -f $flaps) -Path $logPath
foreach ($line in $timeline) { Write-ToolkitLog ("  {0}" -f $line) -Path $logPath }

$result = if ($flaps -gt 0) { "PROBLEM" } else { "HEALTHY" }
$exitCode = if ($flaps -gt 0) { $ToolkitExitCodes.Problem } else { $ToolkitExitCodes.Success }
Complete-ToolkitRun -Result $result -LogPath $logPath -ExitCode $exitCode
