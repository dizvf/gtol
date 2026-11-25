# GTOL updater test

This repo builds a terminal test app called `GTOL.exe`. Each change to `Program.cs`, `GTOL.csproj`, or the build workflow on `main` makes a new Windows release containing `gtol-win-x64.zip`.

## Run the updater

1. Download [`gtol-updater.ps1`](./gtol-updater.ps1) from this repository.
2. Open PowerShell in the folder containing the download. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\gtol-updater.ps1`.
3. Keep the terminal open. The updater installs to `C:\gtol\app`, runs `GTOL.exe` in the same terminal, and checks for releases every two minutes.
4. Edit `Program.cs` on `main`. When the Windows build finishes, the updater stops the old exe, replaces the app folder, and starts the new build.

The updater keeps its own state in `C:\gtol\updater-state.json`. If an update fails before installation, it keeps the old app. If the release workflow has not finished, the updater retries automatically.

When you replace the test app, keep the release zip name `gtol-win-x64.zip` and place your exe at its root, or edit `$ZipAssetName` and `$ExeRelativePath` in the updater. The updater is terminal only and runs until you close its PowerShell window.
