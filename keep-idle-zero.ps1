# Keeps Windows last-input idle time near 0.
# GetLastInputInfo only resets on real input (SendInput / mouse_event).
# SetThreadExecutionState alone will NOT fool an idle detector.
#
# Run:
#   powershell -ExecutionPolicy Bypass -File .\keep-idle-zero.ps1
# Stop: Ctrl+C

param(
    [int]$IntervalSeconds = 5
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class IdleKeepAlive {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [DllImport("user32.dll")]
    private static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("kernel32.dll")]
    private static extern uint GetTickCount();

    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);

    private const uint MOUSEEVENTF_MOVE = 0x0001;
    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;

    public static uint GetIdleMs() {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref info)) {
            return uint.MaxValue;
        }
        return GetTickCount() - info.dwTime;
    }

    // 1px right then 1px left. This is user input as far as GetLastInputInfo is concerned.
    public static void NudgeMouse() {
        mouse_event(MOUSEEVENTF_MOVE, 1, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_MOVE, -1, 0, 0, UIntPtr.Zero);
    }
}
"@

$keepAwake = [IdleKeepAlive]::ES_CONTINUOUS -bor
             [IdleKeepAlive]::ES_SYSTEM_REQUIRED -bor
             [IdleKeepAlive]::ES_DISPLAY_REQUIRED

[void][IdleKeepAlive]::SetThreadExecutionState($keepAwake)

Write-Host "Idle keep-alive running. Nudge every $IntervalSeconds s. Ctrl+C to stop."
Write-Host "Idle ms is GetLastInputInfo (what most 'are you idle?' apps read)."

try {
    while ($true) {
        [IdleKeepAlive]::NudgeMouse()
        $idle = [IdleKeepAlive]::GetIdleMs()
        Write-Host ("{0:HH:mm:ss}  idle={1} ms" -f (Get-Date), $idle)
        Start-Sleep -Seconds $IntervalSeconds
    }
}
finally {
    [void][IdleKeepAlive]::SetThreadExecutionState([IdleKeepAlive]::ES_CONTINUOUS)
    Write-Host "Stopped. Idle timer will climb again if you leave the machine alone."
}
