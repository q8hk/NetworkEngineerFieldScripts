param(
    [string]$Mac,
    [switch]$Help
)

. "$PSScriptRoot/scripts/common.ps1"

function Show-Usage {
    Write-Host "normalize_mac.ps1 - Normalize MAC address formats."
    Write-Host ""
    Write-Host "Usage: normalize_mac.ps1 -Mac <mac>"
    Write-Host "Examples: normalize_mac.ps1 -Mac 00:11:22:33:44:55"
}

if ($Help -or $args -contains '/?' -or -not $Mac) {
    Show-Usage
    exit $ToolkitExitCodes.Usage
}

$clean = ($Mac -replace '[^0-9A-Fa-f]', '').ToUpper()
if ($clean.Length -ne 12) {
    Write-Host "Invalid MAC format."
    exit $ToolkitExitCodes.Usage
}

$logPath = New-ToolkitLog -ToolName "normalize_mac" -KeyParts @($clean)
Write-ToolkitHeader -Title "Normalize MAC" -Path $logPath -Metadata @{Input=$Mac}

$linux = $clean -replace '(.{2})(?=.)', '$1:'
$windows = $clean -replace '(.{2})(?=.)', '$1-'
$cisco = ($clean -replace '(.{4})(?=.)', '$1.').TrimEnd('.')

Write-ToolkitLog ("Linux  : {0}" -f $linux) -Path $logPath
Write-ToolkitLog ("Windows: {0}" -f $windows) -Path $logPath
Write-ToolkitLog ("Cisco  : {0}" -f $cisco) -Path $logPath

Complete-ToolkitRun -Result "HEALTHY" -LogPath $logPath -ExitCode $ToolkitExitCodes.Success
