# Direct EP0 GET_FEATURE probe: read LampArray attributes (report 1) and one lamp (report 3)
# via HidD_GetFeature. Verifies what firmware actually returns on the control pipe.
param([string]$VidPid = "VID_1209&PID_A16C")
$cs = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class FeatureProbe {
    [DllImport("hid.dll")] public static extern void HidD_GetHidGuid(out Guid g);
    [DllImport("hid.dll", SetLastError = true)] public static extern bool HidD_GetFeature(IntPtr h, byte[] report, uint len);
    [DllImport("hid.dll", SetLastError = true)] public static extern bool HidD_SetFeature(IntPtr h, byte[] report, uint len);
    public static int LastErr() { return Marshal.GetLastWin32Error(); }
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr SetupDiGetClassDevs(ref Guid g, string e, IntPtr h, uint f);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr info, ref Guid g, uint idx, ref SP_D d);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_D d, IntPtr det, uint size, out uint req, IntPtr info);
    [DllImport("setupapi.dll")] public static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    [StructLayout(LayoutKind.Sequential)]
    public struct SP_D { public int cbSize; public Guid guid; public uint flags; public IntPtr rsv; }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateFile(string n, uint a, uint s, IntPtr sec, uint disp, uint fl, IntPtr t);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);

    public static string FindPath(string vidPid) {
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
            if (path != null && path.IndexOf(vidPid, StringComparison.OrdinalIgnoreCase) >= 0) {
                SetupDiDestroyDeviceInfoList(set);
                return path;
            }
        }
        SetupDiDestroyDeviceInfoList(set);
        return null;
    }

    public static string Hex(byte[] b, int n) {
        var sb = new StringBuilder();
        for (int i = 0; i < n; i++) sb.Append(b[i].ToString("X2") + " ");
        return sb.ToString();
    }
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.dll

$path = [FeatureProbe]::FindPath($VidPid)
if (-not $path) { Write-Output "device not found"; exit 1 }
$h = [FeatureProbe]::CreateFile($path, [uint32]3221225472, [uint32]3, [IntPtr]::Zero, [uint32]3, [uint32]0, [IntPtr]::Zero)
if ($h.ToInt64() -le 0) { Write-Output "open failed"; exit 1 }

# GET report 1 (array attributes): buffer = ID + 22 bytes payload, use collection max 51
$buf = New-Object byte[] 51
$buf[0] = 1
$ok = [FeatureProbe]::HidD_GetFeature($h, $buf, 51)
Write-Output "GET ID1 ok=$ok err=$([FeatureProbe]::LastErr())"
Write-Output ("raw: " + [FeatureProbe]::Hex($buf, 23))
if ($ok) {
    $lampCount = [BitConverter]::ToUInt16($buf, 1)
    $bw = [BitConverter]::ToUInt32($buf, 3)
    $bh = [BitConverter]::ToUInt32($buf, 7)
    $bd = [BitConverter]::ToUInt32($buf, 11)
    $kind = [BitConverter]::ToUInt32($buf, 15)
    $interval = [BitConverter]::ToUInt32($buf, 19)
    Write-Output "LampCount=$lampCount BBox=${bw}x${bh}x${bd}um Kind=$kind MinInterval=${interval}us"
}

# SET report 2 (request lamp 0) then GET report 3
$sbuf = New-Object byte[] 51
$sbuf[0] = 2; $sbuf[1] = 0; $sbuf[2] = 0
$ok = [FeatureProbe]::HidD_SetFeature($h, $sbuf, 3)
Write-Output "SET ID2 ok=$ok err=$([FeatureProbe]::LastErr())"
$buf2 = New-Object byte[] 51
$buf2[0] = 3
$ok = [FeatureProbe]::HidD_GetFeature($h, $buf2, 51)
Write-Output "GET ID3 ok=$ok err=$([FeatureProbe]::LastErr())"
Write-Output ("raw: " + [FeatureProbe]::Hex($buf2, 29))
if ($ok) {
    $lid = [BitConverter]::ToUInt16($buf2, 1)
    $px = [BitConverter]::ToUInt32($buf2, 3)
    $py = [BitConverter]::ToUInt32($buf2, 7)
    $pz = [BitConverter]::ToUInt32($buf2, 11)
    Write-Output "LampId=$lid pos=($px,$py,$pz)um"
}
[FeatureProbe]::CloseHandle($h) | Out-Null
