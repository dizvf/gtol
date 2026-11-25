using System;
using System.IO;
using System.Threading;

var versionFile = Path.Combine(AppContext.BaseDirectory, "version.txt");
var version = File.Exists(versionFile) ? File.ReadAllText(versionFile).Trim() : "local build";

Console.WriteLine($"GTOL test app | version {version} | PID {Environment.ProcessId}");
Console.WriteLine("Keep the updater running. A new release will close and restart this app.");

using var done = new ManualResetEventSlim(false);
Console.CancelKeyPress += (_, e) => { e.Cancel = true; done.Set(); };

while (!done.Wait(TimeSpan.FromSeconds(30)))
{
    Console.WriteLine($"GTOL is running | {DateTime.Now:HH:mm:ss} | version {version}");
}
