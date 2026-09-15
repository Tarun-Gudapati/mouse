using System.Runtime.InteropServices;

namespace IdleKeepAlive;

internal static class Native
{
    private const uint MouseeventfMove = 0x0001;
    internal const uint EsContinuous = 0x80000000;
    internal const uint EsSystemRequired = 0x00000001;
    internal const uint EsDisplayRequired = 0x00000002;

    [StructLayout(LayoutKind.Sequential)]
    private struct LastInputInfo
    {
        public uint Size;
        public uint Time;
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LastInputInfo info);

    [DllImport("user32.dll")]
    private static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extraInfo);

    [DllImport("kernel32.dll")]
    private static extern uint GetTickCount();

    [DllImport("kernel32.dll")]
    internal static extern uint SetThreadExecutionState(uint flags);

    internal static uint GetIdleMs()
    {
        var info = new LastInputInfo
        {
            Size = (uint)Marshal.SizeOf<LastInputInfo>()
        };

        if (!GetLastInputInfo(ref info))
        {
            return uint.MaxValue;
        }

        return GetTickCount() - info.Time;
    }

    internal static void NudgeMouse()
    {
        mouse_event(MouseeventfMove, 1, 0, 0, UIntPtr.Zero);
        mouse_event(MouseeventfMove, -1, 0, 0, UIntPtr.Zero);
    }
}
