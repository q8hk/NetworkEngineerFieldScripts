<#
.SYNOPSIS
Shared helpers for Network Engineer Field Toolkit PowerShell utilities.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize ToolkitRoot without triggering strict mode errors when the variable
# has not been defined yet.
$toolkitRootVar = Get-Variable -Name ToolkitRoot -Scope Global -ErrorAction SilentlyContinue
if (-not $toolkitRootVar -or -not $toolkitRootVar.Value) {
    $Global:ToolkitRoot = Split-Path -Parent $PSScriptRoot
}

$Global:ToolkitExitCodes = @{
    Success = 0
    Problem = 1
    Usage   = 2
    Failure = 3
}

function Get-ToolkitVersion {
    [OutputType([hashtable])]
    param(
        [string]$RepositoryPath = $Global:ToolkitRoot
    )
    $version = @{
        Revision = $null
        Timestamp = $null
        Source = "unknown"
    }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git -and (Test-Path -LiteralPath $RepositoryPath)) {
        try {
            $revision = & $git.Path -C $RepositoryPath rev-parse --short HEAD
            $timestampUnix = & $git.Path -C $RepositoryPath show -s --format=%ct HEAD
            if ($revision) {
                $version.Revision = $revision.Trim()
                $version.Source = "git"
            }
            if ($timestampUnix -and $timestampUnix -match '^\d+$') {
                $version.Timestamp = [DateTimeOffset]::FromUnixTimeSeconds([int64]$timestampUnix).LocalDateTime
            }
            return $version
        } catch {
            # Continue to fallback path
        }
    }
    $versionFile = Join-Path -Path $RepositoryPath -ChildPath "VERSION"
    if (Test-Path -LiteralPath $versionFile) {
        $content = Get-Content -Path $versionFile -Raw
        if ($content) {
            $version.Revision = $content.Trim()
            $version.Source = "file"
        }
    }
    return $version
}

function Get-ToolkitRemoteVersion {
    [OutputType([hashtable])]
    param(
        [string]$Branch = "main"
    )
    $headers = @{ "User-Agent" = "NetworkEngineerFieldScripts-UpdateCheck" }
    $uri = "https://api.github.com/repos/q8hk/NetworkEngineerFieldScripts/commits/$Branch"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
    $timestamp = $null
    if ($response.commit -and $response.commit.committer -and $response.commit.committer.date) {
        $timestamp = Get-Date $response.commit.committer.date
    }
    return @{
        Revision  = $response.sha.Substring(0, 7)
        Timestamp = $timestamp
        Url       = $response.html_url
        Branch    = $Branch
    }
}

function Invoke-ToolkitUpdate {
    param(
        [string]$Branch = "main",
        [string]$RepositoryUrl = "https://github.com/q8hk/NetworkEngineerFieldScripts",
        [string]$LogPath
    )
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-ToolkitLog "git is not available in PATH; cannot update automatically." -Path $LogPath
        return $false
    }
    $repoPath = $Global:ToolkitRoot
    $dirty = & $git.Path -C $repoPath status --porcelain
    if ($dirty) {
        Write-ToolkitLog "Local changes detected. Commit or stash them before running the auto-update." -Path $LogPath
        return $false
    }
    Write-ToolkitLog "Fetching updates from $RepositoryUrl ($Branch)..." -Path $LogPath
    & $git.Path -C $repoPath fetch $RepositoryUrl $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-ToolkitLog "Fetch failed with exit code $LASTEXITCODE." -Path $LogPath
        return $false
    }
    Write-ToolkitLog "Applying updates (fast-forward only)..." -Path $LogPath
    & $git.Path -C $repoPath merge --ff-only FETCH_HEAD
    if ($LASTEXITCODE -ne 0) {
        Write-ToolkitLog "Update could not be applied (exit code $LASTEXITCODE)." -Path $LogPath
        return $false
    }
    return $true
}

function Invoke-ToolkitUpdateCheck {
    param(
        [string]$Branch = "main",
        [string]$LogPath,
        [switch]$Prompt = $true
    )
    $localVersion = Get-ToolkitVersion
    if ($localVersion.Revision) {
        $localMsg = "Current version: $($localVersion.Revision)"
        if ($localVersion.Timestamp) {
            $localMsg += " ($($localVersion.Timestamp))"
        }
        Write-ToolkitLog $localMsg -Path $LogPath
    } else {
        Write-ToolkitLog "Current version: unknown" -Path $LogPath
    }
    try {
        $remoteVersion = Get-ToolkitRemoteVersion -Branch $Branch
    } catch {
        Write-ToolkitLog ("Online update check failed: {0}" -f $_.Exception.Message) -Path $LogPath
        return
    }
    if (-not $remoteVersion.Revision) {
        Write-ToolkitLog "Could not determine remote version." -Path $LogPath
        return
    }
    if ($localVersion.Revision -and $localVersion.Revision -eq $remoteVersion.Revision) {
        Write-ToolkitLog ("You are up to date on branch '{0}' ({1})." -f $Branch, $remoteVersion.Revision) -Path $LogPath
        return
    }
    $remoteMsg = "Update available on branch '$Branch': $($remoteVersion.Revision)"
    if ($remoteVersion.Timestamp) {
        $remoteMsg += " ($($remoteVersion.Timestamp))"
    }
    Write-ToolkitLog $remoteMsg -Path $LogPath
    if ($remoteVersion.Url) {
        Write-ToolkitLog ("Details: {0}" -f $remoteVersion.Url) -Path $LogPath
    }
    if (-not $Prompt) {
        Write-ToolkitLog "Update prompt skipped in non-interactive mode." -Path $LogPath
        return
    }
    $response = Read-Host "Press U to update now, or press Enter to skip"
    if ($response -notmatch '^[Uu]$') {
        Write-ToolkitLog "Skipping update." -Path $LogPath
        return
    }
    $applied = Invoke-ToolkitUpdate -Branch $Branch -LogPath $LogPath
    if ($applied) {
        $updatedVersion = Get-ToolkitVersion
        $versionMsg = "Toolkit updated successfully to $($updatedVersion.Revision)"
        if ($updatedVersion.Timestamp) {
            $versionMsg += " ($($updatedVersion.Timestamp))"
        }
        Write-ToolkitLog $versionMsg -Path $LogPath
    }
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
