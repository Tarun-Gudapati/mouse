# Small On/Off app that keeps Windows last-input idle time near 0.
# Double-click "Start Idle Keep-Alive.bat" or run:
#   powershell -STA -ExecutionPolicy Bypass -File .\IdleKeepAliveApp.ps1

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`""
    )
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Hide the host console so only the On/Off window stays visible.
if (-not ([System.Management.Automation.PSTypeName]"NativeConsole").Type) {
    Add-Type -Name NativeConsole -Namespace Win32 -MemberDefinition @"
        [DllImport("kernel32.dll")]
        public static extern System.IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
"@
}
$console = [Win32.NativeConsole]::GetConsoleWindow()
if ($console -ne [IntPtr]::Zero) {
    [void][Win32.NativeConsole]::ShowWindow($console, 0)
}

if (-not ([System.Management.Automation.PSTypeName]"IdleKeepAlive").Type) {
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

    public static void NudgeMouse() {
        mouse_event(MOUSEEVENTF_MOVE, 1, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_MOVE, -1, 0, 0, UIntPtr.Zero);
    }
}
"@
}

$intervalSeconds = 5
$isOn = $false

function Set-KeepAliveOn {
    $script:isOn = $true
    $keepAwake = [IdleKeepAlive]::ES_CONTINUOUS -bor
                 [IdleKeepAlive]::ES_SYSTEM_REQUIRED -bor
                 [IdleKeepAlive]::ES_DISPLAY_REQUIRED
    [void][IdleKeepAlive]::SetThreadExecutionState($keepAwake)
    [IdleKeepAlive]::NudgeMouse()
    $nudgeTimer.Start()
    $statusLabel.Text = "ON"
    $statusLabel.ForeColor = [System.Drawing.Color]::ForestGreen
    $onButton.Enabled = $false
    $offButton.Enabled = $true
}

function Set-KeepAliveOff {
    $script:isOn = $false
    $nudgeTimer.Stop()
    [void][IdleKeepAlive]::SetThreadExecutionState([IdleKeepAlive]::ES_CONTINUOUS)
    $statusLabel.Text = "OFF"
    $statusLabel.ForeColor = [System.Drawing.Color]::Firebrick
    $onButton.Enabled = $true
    $offButton.Enabled = $false
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Idle Keep-Alive"
$form.Size = New-Object System.Drawing.Size(340, 220)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Keep Windows idle time at 0"
$titleLabel.Location = New-Object System.Drawing.Point(20, 16)
$titleLabel.Size = New-Object System.Drawing.Size(290, 24)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($titleLabel)

$statusCaption = New-Object System.Windows.Forms.Label
$statusCaption.Text = "Status"
$statusCaption.Location = New-Object System.Drawing.Point(20, 52)
$statusCaption.Size = New-Object System.Drawing.Size(80, 22)
$statusCaption.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($statusCaption)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "OFF"
$statusLabel.Location = New-Object System.Drawing.Point(100, 50)
$statusLabel.Size = New-Object System.Drawing.Size(200, 24)
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = [System.Drawing.Color]::Firebrick
$form.Controls.Add($statusLabel)

$idleCaption = New-Object System.Windows.Forms.Label
$idleCaption.Text = "Idle"
$idleCaption.Location = New-Object System.Drawing.Point(20, 82)
$idleCaption.Size = New-Object System.Drawing.Size(80, 22)
$idleCaption.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($idleCaption)

$idleLabel = New-Object System.Windows.Forms.Label
$idleLabel.Text = "0 ms"
$idleLabel.Location = New-Object System.Drawing.Point(100, 80)
$idleLabel.Size = New-Object System.Drawing.Size(200, 24)
$form.Controls.Add($idleLabel)

$hintLabel = New-Object System.Windows.Forms.Label
$hintLabel.Text = "Nudges the mouse 1px every $intervalSeconds seconds while ON."
$hintLabel.Location = New-Object System.Drawing.Point(20, 110)
$hintLabel.Size = New-Object System.Drawing.Size(290, 20)
$hintLabel.ForeColor = [System.Drawing.Color]::Gray
$hintLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($hintLabel)

$onButton = New-Object System.Windows.Forms.Button
$onButton.Text = "ON"
$onButton.Location = New-Object System.Drawing.Point(20, 140)
$onButton.Size = New-Object System.Drawing.Size(135, 34)
$onButton.BackColor = [System.Drawing.Color]::ForestGreen
$onButton.ForeColor = [System.Drawing.Color]::White
$onButton.FlatStyle = "Flat"
$onButton.Add_Click({ Set-KeepAliveOn })
$form.Controls.Add($onButton)

$offButton = New-Object System.Windows.Forms.Button
$offButton.Text = "OFF"
$offButton.Location = New-Object System.Drawing.Point(170, 140)
$offButton.Size = New-Object System.Drawing.Size(135, 34)
$offButton.BackColor = [System.Drawing.Color]::Firebrick
$offButton.ForeColor = [System.Drawing.Color]::White
$offButton.FlatStyle = "Flat"
$offButton.Enabled = $false
$offButton.Add_Click({ Set-KeepAliveOff })
$form.Controls.Add($offButton)

$nudgeTimer = New-Object System.Windows.Forms.Timer
$nudgeTimer.Interval = $intervalSeconds * 1000
$nudgeTimer.Add_Tick({
    if ($script:isOn) {
        [IdleKeepAlive]::NudgeMouse()
    }
})

$uiTimer = New-Object System.Windows.Forms.Timer
$uiTimer.Interval = 250
$uiTimer.Add_Tick({
    $idleLabel.Text = "{0:N0} ms" -f [IdleKeepAlive]::GetIdleMs()
})
$uiTimer.Start()

$form.Add_FormClosing({
    Set-KeepAliveOff
    $uiTimer.Stop()
    $nudgeTimer.Stop()
})

$form.Add_Shown({ $onButton.Focus() })

[System.Windows.Forms.Application]::Run($form)
