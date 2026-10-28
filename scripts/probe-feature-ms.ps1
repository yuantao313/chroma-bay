# Enumerate ALL HID interface paths for the given VID/PID, open each accessible
# collection, read its HID caps, and probe GET_FEATURE report 1 on the
# LampArray collection (UsagePage=0x59, Usage=0x01).
param([string]$VidPid = "VID_CAFE&PID_4005")
$cs = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class MsProbe {
    [DllImport("hid.dll")] public static extern void HidD_GetHidGuid(out Guid g);
    [DllImport("hid.dll", SetLastError = true)] public static extern bool HidD_GetFeature(IntPtr h, byte[] r, uint len);
    [DllImport("hid.dll", SetLastError = true)] public static extern bool HidD_SetFeature(IntPtr h, byte[] r, uint len);
    [DllImport("hid.dll", SetLastError = true)] public static extern bool HidD_GetPreparsedData(IntPtr h, out IntPtr pp);
    [DllImport("hid.dll")] public static extern int HidP_GetCaps(IntPtr pp, out HidpCaps caps);
    [DllImport("hid.dll")] public static extern bool HidD_FreePreparsedData(IntPtr pp);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr SetupDiGetClassDevs(ref Guid g, string e, IntPtr h, uint f);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr info, ref Guid g, uint idx, ref SP_D d);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_D d, IntPtr det, uint size, out uint req, IntPtr info);
    [DllImport("setupapi.dll")] public static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    [StructLayout(LayoutKind.Sequential)]
    public struct SP_D { public int cbSize; public Guid guid; public uint flags; public IntPtr rsv; }
    [StructLayout(LayoutKind.Sequential)]
    public struct HidpCaps {
        public ushort Usage; public ushort UsagePage;
        public ushort InputReportByteLength; public ushort OutputReportByteLength; public ushort FeatureReportByteLength;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 17)] public ushort[] Reserved;
        public ushort NumberLinkCollectionNodes; public ushort NumberInputButtonCaps; public ushort NumberInputValueCaps;
        public ushort NumberInputDataIndices; public ushort NumberOutputButtonCaps; public ushort NumberOutputValueCaps;
        public ushort NumberOutputDataIndices; public ushort NumberFeatureButtonCaps; public ushort NumberFeatureValueCaps;
        public ushort NumberFeatureDataIndices;
    }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateFile(string n, uint a, uint s, IntPtr sec, uint disp, uint fl, IntPtr t);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    public static int LastErr() { return Marshal.GetLastWin32Error(); }

    public static string[] FindPaths(string vidPid) {
        var list = new System.Collections.Generic.List<string>();
        Guid g; HidD_GetHidGuid(out g);
        IntPtr set = SetupDiGetClassDevs(ref g, null, IntPtr.Zero, 0x2 | 0x10);
        for (uint i = 0; ; i++) {
            var d = new SP_D(); d.cbSize = Marshal.SizeOf(d);
            if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref g, i, ref d)) break;
            uint req = 0;
            SetupDiGetDeviceInterfaceDetail(set, ref d, IntPtr.Zero, 0, out req, IntPtr.Zero);
            IntPtr buf = Marshal.AllocHGlobal((int)req);
            Marshal.WriteInt32(buf, IntPtr.Size == 8 ? 8 : 6);
            bool ok = SetupDiGetDeviceInterfaceDetail(set, ref d, buf, req, out req, IntPtr.Zero);
            string path = ok ? Marshal.PtrToStringUni(buf + 4) : null;
            Marshal.FreeHGlobal(buf);
            if (path != null && path.IndexOf(vidPid, StringComparison.OrdinalIgnoreCase) >= 0) list.Add(path);
        }
        SetupDiDestroyDeviceInfoList(set);
        return list.ToArray();
    }

    public static string Hex(byte[] b, int n) {
        var sb = new StringBuilder();
        for (int i = 0; i < n; i++) sb.Append(b[i].ToString("X2") + " ");
        return sb.ToString();
    }
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.dll

$paths = [MsProbe]::FindPaths($VidPid)
Write-Output "found $($paths.Count) HID path(s)"
foreach ($p in $paths) {
    Write-Output "--- $p"
    $h = [MsProbe]::CreateFile($p, [uint32]3221225472, [uint32]3, [IntPtr]::Zero, [uint32]3, [uint32]0, [IntPtr]::Zero)
    if ($h.ToInt64() -le 0) { Write-Output "    open failed err=$([MsProbe]::LastErr())"; continue }
    $pp = [IntPtr]::Zero
    $caps = New-Object MsProbe+HidpCaps
    if ([MsProbe]::HidD_GetPreparsedData($h, [ref]$pp)) {
        [void][MsProbe]::HidP_GetCaps($pp, [ref]$caps)
        Write-Output ("    UsagePage=0x{0:X2} Usage=0x{1:X2} FeatureLen={2}" -f $caps.UsagePage, $caps.Usage, $caps.FeatureReportByteLength)
        [MsProbe]::HidD_FreePreparsedData($pp) | Out-Null
    }
    if ($caps.UsagePage -eq 0x59) {
        $len = [Math]::Max($caps.FeatureReportByteLength, 1)
        $buf = New-Object byte[] $len
        $buf[0] = 1
        $ok = [MsProbe]::HidD_GetFeature($h, $buf, [uint32]$len)
        Write-Output "    GET ID1 ok=$ok err=$([MsProbe]::LastErr())"
        Write-Output ("    raw: " + [MsProbe]::Hex($buf, [Math]::Min($len, 23)))
        if ($ok) {
            $lampCount = [BitConverter]::ToUInt16($buf, 1)
            $kind = [BitConverter]::ToUInt32($buf, 15)
            $interval = [BitConverter]::ToUInt32($buf, 19)
            Write-Output "    LampCount=$lampCount Kind=$kind MinInterval=${interval}us"
        }
    }
    [MsProbe]::CloseHandle($h) | Out-Null
}
