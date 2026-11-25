param(
    [string]$GameRoot,
    [string]$Repo = 'dizvf/gtol',
    [int]$CheckEverySeconds = 120,
    [switch]$Once
)

# Terminal updater for the GB27 GoreBox modloader and its bundled nine mods.
# Run in an elevated PowerShell window if Steam is installed in Program Files.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$assetName = 'gb27-modpack.zip'
$installRoot = 'C:\gtol'
$archive = Join-Path $installRoot '_download.zip'
$stage = Join-Path $installRoot '_stage'
$stateFile = Join-Path $installRoot 'gorebox-release.json'
$headers = @{ 'User-Agent' = 'gtol-gorebox-updater'; 'Accept' = 'application/vnd.github+json' }
$expectedExeHash = 'C7F908F004F26DFAA9A841317513F07D2C7EBE0677B0C11FB3B15705160F57AB'
$expectedAssemblyHash = 'AD604F098958A158DD04BDA45CFCA4E6007E6C6064A873D0693C94B0C572DA5F'

function Log([string]$message) {
    Write-Host ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message)
}

function Clean-Temporary([string]$path) {
    $parent = [IO.Path]::GetFullPath((Split-Path -Parent $path)).TrimEnd('\')
    if (-not [string]::Equals($parent, [IO.Path]::GetFullPath($installRoot).TrimEnd('\'),
        [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside C:\gtol.' }
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}

function Find-Game {
    if ($GameRoot) { return [IO.Path]::GetFullPath($GameRoot) }
    $steamPaths = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if ($props.SteamPath) { $steamPaths += $props.SteamPath }
        if ($props.InstallPath) { $steamPaths += $props.InstallPath }
    }
    foreach ($steam in ($steamPaths | Select-Object -Unique)) {
        $libraries = @($steam)
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($line in (Get-Content -LiteralPath $vdf)) {
                if ($line -match '"path"\s+"([^"]+)"') {
                    $libraries += $Matches[1].Replace('\\', '\')
                }
            }
        }
        foreach ($library in ($libraries | Select-Object -Unique)) {
            $candidate = Join-Path $library 'steamapps\common\GoreBox'
            if (Test-Path -LiteralPath (Join-Path $candidate 'GoreBox.exe') -PathType Leaf) {
                return [IO.Path]::GetFullPath($candidate)
            }
        }
    }
    throw 'GoreBox was not found in Steam. Supply -GameRoot with the game folder.'
}

function Check-Game([string]$root) {
    foreach ($pair in @(@('GoreBox.exe', $expectedExeHash), @('GameAssembly.dll', $expectedAssemblyHash))) {
        $path = Join-Path $root $pair[0]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $pair[1]) {
            throw "Unsupported GoreBox build: $($pair[0]). The modloader requires the November 5 2026 build."
        }
    }
}

function Get-OwnedProcess([string]$name, [string]$path) {
    @(Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -and [string]::Equals($_.Path, $path, [StringComparison]::OrdinalIgnoreCase)
    })
}

function Stop-OwnedProcess([string]$name, [string]$path) {
    foreach ($process in (Get-OwnedProcess $name $path)) {
        Log "Closing $name ($($process.Id))"
        if ($process.MainWindowHandle -ne 0) {
            $null = $process.CloseMainWindow()
            Wait-Process -Id $process.Id -Timeout 15 -ErrorAction SilentlyContinue
        }
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
        }
    }
    for ($i = 0; $i -lt 50 -and (Get-OwnedProcess $name $path).Count -gt 0; $i++) {
        [Threading.Thread]::Sleep(200)
    }
    if ((Get-OwnedProcess $name $path).Count -gt 0) { throw "$name is still running." }
}

function Launch-Game([string]$root) {
    $gameExe = Join-Path $root 'GoreBox.exe'
    if ((Get-OwnedProcess 'GoreBox' $gameExe).Count -gt 0) { return }
    $loader = Join-Path $root 'GB27_ModLoader\bin\GB27Loader.exe'
    if (-not (Test-Path -LiteralPath $loader -PathType Leaf)) { return }
    Start-Process -FilePath $loader -ArgumentList '--launch' -WorkingDirectory $root -NoNewWindow | Out-Null
    Log 'Started GoreBox through GB27Loader.exe.'
}

if ($Repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Repo must be owner/name.' }
if ($CheckEverySeconds -lt 60) { throw 'CheckEverySeconds must be at least 60.' }
$root = Find-Game
Check-Game $root
$null = New-Item -ItemType Directory -Path $installRoot -Force
Log "Using $root"

do {
    $gameWasRunning = $false
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers
        $latest = [string]$release.id
        if ($latest -notmatch '^[0-9]+$') { throw 'Invalid GitHub release ID.' }
        $assets = @($release.assets | Where-Object { $_.name -eq $assetName })
        if ($assets.Count -ne 1) { throw "Latest release has no $assetName. Waiting for a GB27 release." }
        $asset = $assets[0]
        if ([string]$asset.browser_download_url -notmatch '^https://github\.com/') {
            throw 'Unexpected asset URL.'
        }
        if ([string]$asset.digest -notmatch '^sha256:([0-9a-f]{64})$') {
            throw 'Release asset has no SHA-256 digest.'
        }
        $expectedDigest = $Matches[1]
        $installed = ''
        if (Test-Path -LiteralPath $stateFile) {
            $installed = [string]((Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json).releaseId)
        }
        if ($installed -ne $latest) {
            Log "Downloading $($release.tag_name)"
            Clean-Temporary $archive
            Clean-Temporary $stage
            Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $archive -UseBasicParsing
            if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedDigest) {
                throw 'Downloaded ZIP failed the GitHub SHA-256 check.'
            }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [IO.Compression.ZipFile]::OpenRead($archive)
            try {
                $entries = @($zip.Entries | ForEach-Object { $_.FullName })
                if ($entries.Count -ne 1 -or $entries[0] -ne 'GB27-Mods-Setup.exe') {
                    throw 'ZIP must contain exactly GB27-Mods-Setup.exe at its root.'
                }
            } finally { $zip.Dispose() }
            $null = New-Item -ItemType Directory -Path $stage
            Expand-Archive -LiteralPath $archive -DestinationPath $stage
            $setup = Join-Path $stage 'GB27-Mods-Setup.exe'
            # Installer checks the game build before touching the installation.
            $preflight = Start-Process -FilePath $setup -ArgumentList @('/check', ('"' + $root + '"')) -Wait -PassThru
            if ($preflight.ExitCode -ne 0) { throw "Installer compatibility check failed ($($preflight.ExitCode))." }

            $gameExe = Join-Path $root 'GoreBox.exe'
            $loader = Join-Path $root 'GB27_ModLoader\bin\GB27Loader.exe'
            $gameWasRunning = (Get-OwnedProcess 'GoreBox' $gameExe).Count -gt 0
            Stop-OwnedProcess 'GoreBox' $gameExe
            Stop-OwnedProcess 'GB27Loader' $loader
            # /elevated-install is the installer's terminal path; it leaves the
            # per-user tray startup setting alone. The installer backs up every
            # owned file and restores them if a write fails.
            $result = Start-Process -FilePath $setup -ArgumentList @('/elevated-install', ('"' + $root + '"')) -Wait -PassThru
            if ($result.ExitCode -ne 0) { throw "Installer failed ($($result.ExitCode)); previous files were kept." }
            $tempState = Join-Path $installRoot 'gorebox-release.tmp'
            @{ releaseId = $latest; tag = [string]$release.tag_name } |
                ConvertTo-Json | Set-Content -LiteralPath $tempState -Encoding UTF8
            Move-Item -LiteralPath $tempState -Destination $stateFile -Force
            Log "Installed $($release.tag_name) with the nine bundled mods."
            Launch-Game $root
        } elseif ($Once) {
            Log 'Already up to date.'
        }
    } catch {
        Log "Update check failed: $_"
        if ($gameWasRunning) { Launch-Game $root }
    } finally {
        Clean-Temporary $stage
        Clean-Temporary $archive
    }
    if (-not $Once) { Start-Sleep -Seconds $CheckEverySeconds }
} while (-not $Once)
