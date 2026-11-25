# Terminal-only GTOL updater for GitHub Releases.
$Repo = 'dizvf/gtol'
$ZipAssetName = 'gtol-win-x64.zip'
$ExeRelativePath = 'GTOL.exe'
$InstallRoot = 'C:\gtol'
$CheckEverySeconds = 60

# Run with: powershell.exe -NoProfile -File .\gtol-updater.ps1
# Keep this PowerShell window open for automatic update checks and app output.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ 'User-Agent' = 'gtol-updater'; 'Accept' = 'application/vnd.github+json' }
$app = Join-Path $InstallRoot 'app'
$staging = Join-Path $InstallRoot '_staging'
$backup = Join-Path $InstallRoot '_previous'
$archive = Join-Path $InstallRoot '_download.zip'
$statePath = Join-Path $InstallRoot 'updater-state.json'

function Log([string]$message) {
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message)
}

function Remove-Safe([string]$path) {
    # Cleanup is limited to direct children of the requested installation folder.
    $parent = [IO.Path]::GetFullPath((Split-Path -Parent $path)).TrimEnd('\')
    $root = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
    if (-not [string]::Equals($parent, $root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a path outside $InstallRoot"
    }
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

function Get-ExePath([string]$directory) {
    $full = [IO.Path]::GetFullPath((Join-Path $directory $ExeRelativePath))
    $base = [IO.Path]::GetFullPath($directory).TrimEnd('\') + '\'
    if (-not $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'ExeRelativePath must point inside the installed app folder.'
    }
    return $full
}

function Get-AppProcesses {
    $target = Get-ExePath $app
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.ExecutablePath -and [string]::Equals(
            $_.ExecutablePath, $target, [StringComparison]::OrdinalIgnoreCase)
    })
}

function Start-App {
    $exe = Get-ExePath $app
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        Log "No executable at $exe yet. Files are installed; add the exe and update the repository."
        return
    }
    if ((Get-AppProcesses).Count -gt 0) { return }
    Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) -NoNewWindow | Out-Null
    Log "Started $exe"
}

function Stop-App {
    foreach ($item in (Get-AppProcesses)) {
        $process = Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $process) { continue }
        Log "Stopping $($process.Id) before updating"
        if ($process.MainWindowHandle -ne 0) {
            $null = $process.CloseMainWindow()
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
        }
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction Stop
        }
    }
    if ((Get-AppProcesses).Count -gt 0) { throw 'The executable is still running.' }
}

function Save-State([string]$releaseId) {
    $tempState = Join-Path $InstallRoot 'updater-state.tmp'
    @{ releaseId = $releaseId } | ConvertTo-Json | Set-Content -LiteralPath $tempState -Encoding UTF8
    Move-Item -LiteralPath $tempState -Destination $statePath -Force
}

if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Set Repo to owner/name.' }
if ($ZipAssetName -notmatch '^[A-Za-z0-9_.-]+\.zip$') { throw 'Set ZipAssetName to a release zip filename.' }
if ([string]::IsNullOrWhiteSpace($ExeRelativePath) -or [IO.Path]::IsPathRooted($ExeRelativePath)) {
    throw 'Set ExeRelativePath to a relative exe path such as bin\GTOL.exe.'
}
if ($CheckEverySeconds -lt 10) { throw 'CheckEverySeconds must be at least 10.' }

# Terminal-only GTOL updater for GitHub Releases.
$Repo = 'dizvf/gtol'
$ZipAssetName = 'gtol-win-x64.zip'
$ExeRelativePath = 'GTOL.exe'
$InstallRoot = 'C:\gtol'
$CheckEverySeconds = 60

# Run with: powershell.exe -NoProfile -File .\gtol-updater.ps1
# Keep this PowerShell window open for automatic update checks and app output.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ 'User-Agent' = 'gtol-updater'; 'Accept' = 'application/vnd.github+json' }
$app = Join-Path $InstallRoot 'app'
$staging = Join-Path $InstallRoot '_staging'
$backup = Join-Path $InstallRoot '_previous'
$archive = Join-Path $InstallRoot '_download.zip'
$statePath = Join-Path $InstallRoot 'updater-state.json'

function Log([string]$message) {
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message)
}

function Remove-Safe([string]$path) {
    # Cleanup is limited to direct children of the requested installation folder.
    $parent = [IO.Path]::GetFullPath((Split-Path -Parent $path)).TrimEnd('\')
    $root = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
    if (-not [string]::Equals($parent, $root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a path outside $InstallRoot"
    }
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

function Get-ExePath([string]$directory) {
    $full = [IO.Path]::GetFullPath((Join-Path $directory $ExeRelativePath))
    $base = [IO.Path]::GetFullPath($directory).TrimEnd('\') + '\'
    if (-not $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'ExeRelativePath must point inside the installed app folder.'
    }
    return $full
}

function Get-AppProcesses {
    $target = Get-ExePath $app
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.ExecutablePath -and [string]::Equals(
            $_.ExecutablePath, $target, [StringComparison]::OrdinalIgnoreCase)
    })
}

function Start-App {
    $exe = Get-ExePath $app
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        Log "No executable at $exe yet. Files are installed; add the exe and update the repository."
        return
    }
    if ((Get-AppProcesses).Count -gt 0) { return }
    Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) -NoNewWindow | Out-Null
    Log "Started $exe"
}

function Stop-App {
    foreach ($item in (Get-AppProcesses)) {
        $process = Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $process) { continue }
        Log "Stopping $($process.Id) before updating"
        if ($process.MainWindowHandle -ne 0) {
            $null = $process.CloseMainWindow()
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
        }
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction Stop
        }
    }
    if ((Get-AppProcesses).Count -gt 0) { throw 'The executable is still running.' }
}

function Save-State([string]$releaseId) {
    $tempState = Join-Path $InstallRoot 'updater-state.tmp'
    @{ releaseId = $releaseId } | ConvertTo-Json | Set-Content -LiteralPath $tempState -Encoding UTF8
    Move-Item -LiteralPath $tempState -Destination $statePath -Force
}

if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Set Repo to owner/name.' }
if ($ZipAssetName -notmatch '^[A-Za-z0-9_.-]+\.zip$') { throw 'Set ZipAssetName to a release zip filename.' }
if ([string]::IsNullOrWhiteSpace($ExeRelativePath) -or [IO.Path]::IsPathRooted($ExeRelativePath)) {
    throw 'Set ExeRelativePath to a relative exe path such as bin\GTOL.exe.'
}
if ($CheckEverySeconds -lt 10) { throw 'CheckEverySeconds must be at least 10.' }

$null = New-Item -ItemType Directory -Path $InstallRoot -Force
$null = Get-ExePath $app  # Validate the target before downloading anything.

# Recover an interrupted folder swap.
if (-not (Test-Path -LiteralPath $app) -and (Test-Path -LiteralPath $backup)) {
    Move-Item -LiteralPath $backup -Destination $app
    Log 'Restored the previous installation after an interrupted update.'
}
if (Test-Path -LiteralPath $backup) { Remove-Safe $backup }
Start-App

while ($true) {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers
        $latest = [string]$release.id
        if ($latest -notmatch '^[0-9]+$') { throw 'GitHub did not return a valid release ID.' }
        $assets = @($release.assets | Where-Object { $_.name -eq $ZipAssetName })
        if ($assets.Count -ne 1) { throw "The latest release must have exactly one $ZipAssetName asset." }
        $asset = $assets[0]
        if ([string]$asset.browser_download_url -notmatch '^https://github\.com/') {
            throw 'Unexpected release download URL.'
        }

        $installed = ''
        if (Test-Path -LiteralPath $statePath) {
            $installed = [string]((Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json).releaseId)
        }
        if ($installed -ne $latest -or -not (Test-Path -LiteralPath $app)) {
            Log "Downloading release $($release.tag_name)"
            Remove-Safe $staging
            Remove-Safe $archive
            Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $archive -UseBasicParsing
            if ([string]$asset.digest -match '^sha256:([0-9a-f]{64})$') {
                $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
                if ($actual -ne $Matches[1]) { throw 'Release zip SHA-256 does not match GitHub.' }
            }
            $null = New-Item -ItemType Directory -Path $staging
            Expand-Archive -LiteralPath $archive -DestinationPath $staging -Force
            $newApp = $staging
            $newExe = Get-ExePath $newApp
            if (-not (Test-Path -LiteralPath $newExe -PathType Leaf)) {
                throw "Release has no executable at $ExeRelativePath; keeping the current version."
            }

            Stop-App
            Remove-Safe $backup
            $movedOld = $false
            try {
                if (Test-Path -LiteralPath $app) {
                    Move-Item -LiteralPath $app -Destination $backup
                    $movedOld = $true
                }
                Move-Item -LiteralPath $newApp -Destination $app
                Start-App
                Save-State $latest
                Log "Installed release $($release.tag_name)"
            } catch {
                Log "Install failed; restoring previous version: $_"
                if ($movedOld) {
                    Stop-App
                    Remove-Safe $app
                    Move-Item -LiteralPath $backup -Destination $app
                    Start-App
                }
                throw
            }
            if ($movedOld) { Remove-Safe $backup }
        }
    } catch {
        Log "Update check failed: $_"
    } finally {
        Remove-Safe $staging
        Remove-Safe $archive
    }
    Start-Sleep -Seconds $CheckEverySeconds
}
