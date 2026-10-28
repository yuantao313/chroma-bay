# Verify HID collection UsagePage/Usage of the LampArray interface via P/Invoke.
# Prints UsagePage (expect 0x59) and Usage (expect 0x01 LampArray).
$cs = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class HidProbe {
    [StructLayout(LayoutKind.Sequential)]
    public struct HIDD_ATTRIBUTES { public int Size; public ushort VendorID; public ushort ProductID; public ushort VersionNumber; }
    [StructLayout(LayoutKind.Sequential)]
    public struct HIDP_CAPS {
        public ushort Usage; public ushort UsagePage;
        public ushort InputReportByteLength; public ushort OutputReportByteLength; public ushort FeatureReportByteLength;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 17)] public ushort[] Reserved;
        public ushort NumberLinkCollectionNodes; public ushort NumberInputButtonCaps; public ushort NumberInputValueCaps;
        public ushort NumberInputDataIndices; public ushort NumberOutputButtonCaps; public ushort NumberOutputValueCaps;
        public ushort NumberOutputDataIndices; public ushort NumberFeatureButtonCaps; public ushort NumberFeatureValueCaps;
        public ushort NumberFeatureDataIndices;
    }
    [DllImport("hid.dll")] public static extern void HidD_GetHidGuid(out Guid g);
    [DllImport("hid.dll")] public static extern bool HidD_GetPreparsedData(IntPtr h, out IntPtr p);
    [DllImport("hid.dll")] public static extern bool HidD_FreePreparsedData(IntPtr p);
    [DllImport("hid.dll")] public static extern bool HidD_GetAttributes(IntPtr h, out HIDD_ATTRIBUTES a);
    [DllImport("hid.dll")] public static extern int HidP_GetCaps(IntPtr p, out HIDP_CAPS caps);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr SetupDiGetClassDevs(ref Guid g, string enumr, IntPtr hwnd, uint flags);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr info, ref Guid g, uint idx, ref SP_DEVICE_INTERFACE_DATA d);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_DEVICE_INTERFACE_DATA d, IntPtr detail, uint size, out uint req, IntPtr info);
    [DllImport("setupapi.dll")] public static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    [StructLayout(LayoutKind.Sequential)]
    public struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid InterfaceClassGuid; public uint Flags; public IntPtr Reserved; }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);

    public const uint DIGCF_PRESENT = 0x2, DIGCF_DEVICEINTERFACE = 0x10;
    public const uint GENERIC_READ = 0x80000000, GENERIC_WRITE = 0x40000000;
    public const uint FILE_SHARE_READ = 0x1, FILE_SHARE_WRITE = 0x2, OPEN_EXISTING = 0x3;

    public static string Probe(string vidPid) {
        Guid g; HidD_GetHidGuid(out g);
        IntPtr set = SetupDiGetClassDevs(ref g, null, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
        var sb = new StringBuilder();
        for (uint i = 0; ; i++) {
            var d = new SP_DEVICE_INTERFACE_DATA(); d.cbSize = Marshal.SizeOf(d);
            if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref g, i, ref d)) break;
            uint req = 0;
            SetupDiGetDeviceInterfaceDetail(set, ref d, IntPtr.Zero, 0, out req, IntPtr.Zero);
            IntPtr buf = Marshal.AllocHGlobal((int)req);
            Marshal.WriteInt32(buf, IntPtr.Size == 8 ? 8 : 6);
            if (!SetupDiGetDeviceInterfaceDetail(set, ref d, buf, req, out req, IntPtr.Zero)) { Marshal.FreeHGlobal(buf); continue; }
            string path = Marshal.PtrToStringUni(buf + 4);
            Marshal.FreeHGlobal(buf);
            if (path == null || path.IndexOf(vidPid, StringComparison.OrdinalIgnoreCase) < 0) continue;

            IntPtr h = CreateFile(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
            if (h.ToInt64() <= 0) { sb.AppendLine("OPEN_FAIL: " + path); continue; }
            HIDD_ATTRIBUTES at; at.Size = Marshal.SizeOf(typeof(HIDD_ATTRIBUTES));
            HidD_GetAttributes(h, out at);
            IntPtr pp;
            if (HidD_GetPreparsedData(h, out pp)) {
                HIDP_CAPS caps;
                int st = HidP_GetCaps(pp, out caps);
                sb.AppendLine(string.Format("PATH: {0}", path));
                sb.AppendLine(string.Format("  UsagePage=0x{0:X2} Usage=0x{1:X2} FeatureReportByteLength={2} Status={3}",
                    caps.UsagePage, caps.Usage, caps.FeatureReportByteLength, st));
                HidD_FreePreparsedData(pp);
            }
            h = IntPtr.Zero;
        }
        SetupDiDestroyDeviceInfoList(set);
        return sb.ToString();
    }
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.dll
[HidProbe]::Probe("VID_1209&PID_A16C")
