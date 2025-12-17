<#
.SYNOPSIS
Shared helpers for Network Engineer Field Toolkit PowerShell utilities.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Global:ToolkitRoot) {
    $Global:ToolkitRoot = Split-Path -Parent $PSScriptRoot
}

$Global:ToolkitExitCodes = @{
    Success = 0
    Problem = 1
    Usage   = 2
    Failure = 3
}

function Get-LogDirectory {
    param(
        [string]$BasePath = $Global:ToolkitRoot
    )
    $logDir = Join-Path -Path $BasePath -ChildPath "logs"
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    return $logDir
}

function New-ToolkitLog {
    param(
        [string]$ToolName,
        [string[]]$KeyParts,
        [string]$Result = 'pending'
    )
    $logDir = Get-LogDirectory
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeKeys = ($KeyParts | Where-Object { $_ -and $_.Trim() -ne '' }) -join "_"
    $fileName = "$($ToolName)_$ts"
    if ($safeKeys) { $fileName += "_$safeKeys" }
    $fileName += "_$Result.log"
    $path = Join-Path -Path $logDir -ChildPath $fileName
    New-Item -ItemType File -Path $path -Force | Out-Null
    return $path
}

function Update-ToolkitLogResult {
    param(
        [string]$LogPath,
        [string]$Result
    )
    if (-not $LogPath) { return $null }
    $dir = Split-Path -Parent $LogPath
    $base = [IO.Path]::GetFileNameWithoutExtension($LogPath)
    $parts = $base -split "_"
    if ($parts.Count -gt 0) {
        $last = $parts[-1]
        if ($last -in @('pending', 'HEALTHY', 'PROBLEM', 'INCONCLUSIVE')) {
            $parts[-1] = $Result
        }
    } else {
        $parts = @($base, $Result)
    }
    $newName = ($parts -join "_") + ".log"
    $newPath = Join-Path -Path $dir -ChildPath $newName
    if ($newPath -ne $LogPath) {
        Move-Item -Path $LogPath -Destination $newPath -Force
    }
    return $newPath
}

function Write-ToolkitLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Path
    )
    Write-Host $Message
    if ($Path) {
        Add-Content -Path $Path -Value $Message
    }
}

function Write-ToolkitHeader {
    param(
        [string]$Title,
        [string]$Path,
        [hashtable]$Metadata
    )
    Write-ToolkitLog "============================================================" -Path $Path
    Write-ToolkitLog (" {0}" -f $Title) -Path $Path
    Write-ToolkitLog "============================================================" -Path $Path
    Write-ToolkitLog (" Host       : {0}" -f $env:COMPUTERNAME) -Path $Path
    Write-ToolkitLog (" User       : {0}" -f $env:USERNAME) -Path $Path
    Write-ToolkitLog (" Timestamp  : {0}" -f (Get-Date)) -Path $Path
    if ($Metadata) {
        $Metadata.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-ToolkitLog (" {0,-10}: {1}" -f $_.Name, $_.Value) -Path $Path
        }
    }
    Write-ToolkitLog "------------------------------------------------------------" -Path $Path
}

function Complete-ToolkitRun {
    param(
        [string]$Result,
        [string]$LogPath,
        [int]$ExitCode
    )
    Write-ToolkitLog (" Result: {0}" -f $Result) -Path $LogPath
    Write-ToolkitLog (" Log   : {0}" -f $LogPath) -Path $LogPath
    Write-ToolkitLog "============================================================" -Path $LogPath
    $finalPath = Update-ToolkitLogResult -LogPath $LogPath -Result $Result
    if ($finalPath -and $finalPath -ne $LogPath) {
        Write-Host ("Renamed log to {0}" -f $finalPath)
    }
    exit $ExitCode
}

function Require-Argument {
    param(
        [string]$Value,
        [string]$Message
    )
    if (-not $Value) {
        throw $Message
    }
}

function Resolve-ToolkitAdapter {
    param(
        [string]$AdapterName
    )
    $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -ne 'Disabled' }
    if ($AdapterName) {
        $match = $adapters | Where-Object { $_.Name -eq $AdapterName -or $_.InterfaceDescription -like "*$AdapterName*" } | Select-Object -First 1
        if (-not $match) {
            throw "Adapter '$AdapterName' not found."
        }
        return $match
    }
    return ($adapters | Sort-Object -Property ifIndex | Select-Object -First 1)
}

function Normalize-ToolkitMac {
    param(
        [string]$Mac
    )
    $clean = ($Mac -replace '[^0-9A-Fa-f]', '').ToUpper()
    if ($clean.Length -ne 12) { return $null }
    return $clean -replace '(.{2})(?=.)', '$1:'
}
