<#
Moves Roblox Studio windows that open after this script starts (multiplayer test server/clients) onto the first
non-primary monitor, without activating them, so they don't land on top of a game on the main screen.

Usage (start it BEFORE launching a multiplayer test; it exits by itself):
  powershell -NoProfile -File tools/move-studio-test-windows.ps1 [-Seconds 90]
#>
param([int]$Seconds = 90)

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class StudioWin {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int ht, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
}
"@

$second = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | Select-Object -First 1
if (-not $second) { Write-Output "No second monitor; nothing to do."; exit 0 }
$area = $second.WorkingArea
$started = Get-Date
$moved = @{}
$SWP_NOZORDER = 0x0004; $SWP_NOACTIVATE = 0x0010
$deadline = $started.AddSeconds($Seconds)
while ((Get-Date) -lt $deadline) {
    foreach ($p in Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue) {
        if ($p.StartTime -lt $started -or $p.MainWindowHandle -eq [IntPtr]::Zero) { continue }
        $key = "$($p.Id)-$($p.MainWindowHandle)"
        if ($moved.ContainsKey($key)) { continue }
        # Tile the test windows side by side on the second monitor.
        $i = $moved.Count
        $w = [int]($area.Width / 2); $h = [int]($area.Height / 2)
        $x = $area.X + ($i % 2) * $w; $y = $area.Y + [int]([math]::Floor($i / 2) % 2) * $h
        [StudioWin]::ShowWindow($p.MainWindowHandle, 4) | Out-Null # SW_SHOWNOACTIVATE (restore if maximised)
        [StudioWin]::SetWindowPos($p.MainWindowHandle, [IntPtr]::Zero, $x, $y, $w, $h, $SWP_NOZORDER -bor $SWP_NOACTIVATE) | Out-Null
        $moved[$key] = $true
        Write-Output ("moved {0} (pid {1}) to {2},{3}" -f $p.MainWindowTitle, $p.Id, $x, $y)
    }
    Start-Sleep -Milliseconds 150
}
Write-Output "done: moved $($moved.Count) window(s)"
