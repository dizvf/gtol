# GTOL GoreBox modloader updater

This repository has a terminal-only updater for the GB27 GoreBox modloader and nine bundled mods. See [setup and release instructions](./GOREBOX-README.md) and the [latest modpack release](./releases/latest).

Download [gorebox-updater.ps1](./gorebox-updater.ps1), open PowerShell in its folder, and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gorebox-updater.ps1
```

Run the terminal as administrator if Steam is installed under Program Files. The updater detects your Steam GoreBox folder, stores updater state under `C:\gtol`, and checks for releases every two minutes while the terminal stays open. It closes GoreBox for an update and restarts it through the modloader. The game must match the inspected November 5, 2026 build.

To build a new ZIP from the development PC, use [make-gorebox-release.ps1](./make-gorebox-release.ps1) and upload its `gb27-modpack.zip` output to a normal GitHub release. The old `GTOL.exe` starter and `gtol-updater.ps1` remain as a separate test.
