# GTOL GoreBox modloader updater

This terminal updater installs the GB27 loader and nine bundled mods into your existing Steam GoreBox folder. The release ZIP contains `GB27-Mods-Setup.exe`, which embeds the loader, native menu, multiplayer bridge, and the nine mod DLLs. It does **not** contain the game executable or original Steam asset files. Some compiled mods contain geometry derived from game content, so check redistribution rights before sharing the release publicly.

## Run

Download [`gorebox-updater.ps1`](./gorebox-updater.ps1), open PowerShell as administrator if Steam lives in `Program Files (x86)`, and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gorebox-updater.ps1
```

The updater detects GoreBox in Steam libraries. If yours is elsewhere, add `-GameRoot 'D:\SteamLibrary\steamapps\common\GoreBox'`. It stores downloads and its release marker under `C:\gtol`. The installer writes the loader and mods into the actual Steam game folder. Keep the terminal open for checks every two minutes. Use `-Once` for one update check.

When a new release is available, the updater verifies the release ZIP checksum, verifies the installer accepts the game build, closes the running GoreBox and loader processes, installs with verified backups, then starts the game through `GB27Loader.exe --launch`. It preserves unrelated mods and per-mod tuning files. If installation fails, the installer restores files it changed and the updater attempts to restart the previous game session.

**Compatibility:** the current GB27 loader only accepts the inspected November 5, 2026 GoreBox build. A Steam game update may require a new modloader build; the updater will refuse a mismatched game instead of changing its files. The native DLLs are a community test build; multiplayer behavior is not fully verified.

## Publish an update

On the development PC, after building and checking the loader and mods, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\make-gorebox-release.ps1
```

The script reads only these local Steam files: `GB27_ModLoader` build sources, the native menu and bridge, and `Mods\{OGGrab,OGSyringes,Vape,Child,OldContent,Pee,Plush,HLWeapons,Headcrab}\*.dll`. It rebuilds the full installer and verifies that its embedded mod DLLs match the local files. It creates `gb27-modpack.zip` beside the script. Upload that ZIP to a **new normal GitHub release** in this repository. The updater uses the most recent release and requires exactly one `gb27-modpack.zip` asset.

The legacy `GTOL.exe` starter is a separate demonstration. Use `gorebox-updater.ps1` for GoreBox.
