param(
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\GoreBox',
    [string]$OutputZip = (Join-Path $PSScriptRoot 'gb27-modpack.zip')
)

# Builds an installer from the local GB27 source and exactly nine installed mods.
# It only reads Steam files. It does not include GoreBox.exe, GameAssembly.dll,
# logs, receipts, backups, Half-Life assets, or the whole Steam directory.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($GameRoot)
$project = Join-Path $root 'GB27_ModLoader'
$expected = @{
    'GoreBox.exe' = 'C7F908F004F26DFAA9A841317513F07D2C7EBE0677B0C11FB3B15705160F57AB'
    'GameAssembly.dll' = 'AD604F098958A158DD04BDA45CFCA4E6007E6C6064A873D0693C94B0C572DA5F'
}
foreach ($name in $expected.Keys) {
    $path = Join-Path $root $name
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected[$name]) {
        throw "Unsupported game build: $name"
    }
}
$mods = @('OGGrab','OGSyringes','Vape','Child','OldContent','Pee','Plush','HLWeapons','Headcrab')
$scratchRoot = Join-Path $env:LOCALAPPDATA 'Temp'
$scratch = Join-Path $scratchRoot ('gb27-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$mirror = Join-Path $scratch 'GoreBox'
$mirrorProject = Join-Path $mirror 'GB27_ModLoader'
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
try {
    $env:TEMP = $scratchRoot
    $env:TMP = $scratchRoot
    foreach ($relative in @(
        'Build.ps1', 'src\GB27Loader.cs', 'bin\GB27UnityMenu.dll',
        'bin\GB27Multiplayer.dll', 'installer\Setup.cs', 'installer\AutoLoader.cs',
        'installer\AutoStart.cs', 'installer\Setup.manifest',
        'installer\Build-ModpackInstaller.ps1')) {
        $source = Join-Path $project $relative
        $destination = Join-Path $mirrorProject $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $source -Destination $destination
    }
    foreach ($mod in $mods) {
        $relative = "Mods\$mod\$mod.dll"
        $source = Join-Path $root $relative
        $destination = Join-Path $mirror $relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath $source -Destination $destination
    }
    # The installer's legacy fixture test creates very deep temporary paths.
    # In packaged workspaces those can exceed the .NET Framework path limit.
    # Build the unchanged installer and validate its embedded payload below.
    $buildPath = Join-Path $mirrorProject 'installer\Build-ModpackInstaller.ps1'
    $buildText = [IO.File]::ReadAllText($buildPath)
    $start = $buildText.IndexOf('$report=Join-Path $out', [StringComparison]::Ordinal)
    $end = $buildText.IndexOf('$hash=(Get-FileHash $exe).Hash', $start, [StringComparison]::Ordinal)
    if ($start -lt 0 -or $end -lt 0) { throw 'Unexpected installer build script layout.' }
    [IO.File]::WriteAllText($buildPath, $buildText.Substring(0, $start) + $buildText.Substring($end))
    & (Join-Path $mirrorProject 'installer\Build-ModpackInstaller.ps1')
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
    $setup = Join-Path $mirrorProject 'releases\ModsBundle\GB27-Mods-Setup.exe'
    if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { throw 'Installer build did not produce an EXE.' }
    $assembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($setup))
    $resources = @($assembly.GetManifestResourceNames())
    if ($resources.Count -ne 13) { throw "Expected 13 embedded binaries; found $($resources.Count)." }
    foreach ($mod in $mods) {
        $name = "$mod.dll"
        if ($resources -notcontains $name) { throw "Missing embedded mod: $name" }
        $stream = $assembly.GetManifestResourceStream($name)
        try {
            $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($stream)).Replace('-', '')
            if ($hash -ne (Get-FileHash -LiteralPath (Join-Path $root "Mods\$mod\$mod.dll")).Hash) {
                throw "Bundled payload mismatch: $mod"
            }
        } finally { $stream.Dispose() }
    }
    foreach ($component in @('GB27Loader.exe','GB27UnityMenu.dll','GB27AutoLoader.exe','GB27Multiplayer.dll')) {
        if ($resources -notcontains $component) { throw "Missing loader component: $component" }
        $stream = $assembly.GetManifestResourceStream($component)
        try {
            $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($stream)).Replace('-', '')
            $source = if ($component -eq 'GB27Loader.exe' -or $component -eq 'GB27AutoLoader.exe') {
                Join-Path $mirrorProject "installer\build-full\$component"
            } else { Join-Path $project "bin\$component" }
            if ($hash -ne (Get-FileHash -LiteralPath $source).Hash) { throw "Bundled payload mismatch: $component" }
        } finally { $stream.Dispose() }
    }
    $output = [IO.Path]::GetFullPath($OutputZip)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force
    if (Test-Path -LiteralPath $output) { throw "Output already exists: $output" }
    Compress-Archive -LiteralPath $setup -DestinationPath $output
    Write-Host "PACKAGE=$output"
    Write-Host "SHA256=$((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash)"
    Write-Host "MODS=$($mods -join ', ')"
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $resolvedRoot = [IO.Path]::GetFullPath($scratchRoot).TrimEnd('\') + '\'
    if ([IO.Path]::GetFullPath($scratch).StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $scratch)) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
