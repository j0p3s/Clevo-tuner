using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

namespace ClevoTune
{
    // ---------------------------------------------------------------- i18n
    public static class L
    {
        static Dictionary<string, string> map = new Dictionary<string, string>();
        public static void Load(IDictionary<string, string> m) { map = new Dictionary<string, string>(m); }
        public static string T(string k)
        {
            string v;
            return (k != null && map.TryGetValue(k, out v)) ? v : k;
        }
    }

    // ------------------------------------------------------------------ PawnIO
    public class PawnIo : IDisposable
    {
        const uint IOCTL_LOAD = 0xA1B22084;
        const uint IOCTL_EXEC = 0xA1B22104;

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CreateFileW")]
        static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool DeviceIoControl(SafeFileHandle h, uint code, byte[] inBuf, int inSize, byte[] outBuf, int outSize, out int returned, IntPtr ov);

        SafeFileHandle handle;

        static SafeFileHandle OpenDevice()
        {
            return CreateFile(@"\\?\GLOBALROOT\Device\PawnIO", 0xC0000000u, 3u, IntPtr.Zero, 3u, 0x80u, IntPtr.Zero);
        }

        public static bool DriverPresent()
        {
            SafeFileHandle h = OpenDevice();
            bool ok = !h.IsInvalid;
            h.Dispose();
            return ok;
        }

        public PawnIo(byte[] module)
        {
            handle = OpenDevice();
            if (handle.IsInvalid)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "PawnIO driver not available");
            int r;
            if (!DeviceIoControl(handle, IOCTL_LOAD, module, module.Length, null, 0, out r, IntPtr.Zero))
            {
                int e = Marshal.GetLastWin32Error();
                handle.Dispose();
                throw new Win32Exception(e, "PawnIO module load failed");
            }
        }

        public long[] Exec(string fn, long[] input, int outCount)
        {
            byte[] inb = new byte[32 + input.Length * 8];
            byte[] name = Encoding.ASCII.GetBytes(fn);
            Buffer.BlockCopy(name, 0, inb, 0, Math.Min(31, name.Length));
            Buffer.BlockCopy(input, 0, inb, 32, input.Length * 8);
            byte[] outb = outCount > 0 ? new byte[outCount * 8] : null;
            int ret;
            if (!DeviceIoControl(handle, IOCTL_EXEC, inb, inb.Length, outb, outb == null ? 0 : outb.Length, out ret, IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            long[] res = new long[outCount];
            if (outb != null) Buffer.BlockCopy(outb, 0, res, 0, Math.Min(ret, outb.Length));
            return res;
        }

        public void Dispose()
        {
            if (handle != null) handle.Dispose();
        }
    }

    // ------------------------------------------------------- Clevo EC (0x62/0x66)
    public class ClevoEc : IDisposable
    {
        const int CMD = 0x66, DATA = 0x62;
        PawnIo io;
        Mutex mtx;

        public ClevoEc(byte[] module)
        {
            io = new PawnIo(module);
            try { mtx = new Mutex(false, @"Global\Access_EC"); } catch { mtx = null; }
        }

        int In(int port) { return (int)(io.Exec("ioctl_pio_read", new long[] { port }, 1)[0] & 0xFF); }
        void Out(int port, int v) { io.Exec("ioctl_pio_write", new long[] { port, v & 0xFF }, 0); }

        void WaitIbf()
        {
            Stopwatch sw = Stopwatch.StartNew();
            while ((In(CMD) & 2) != 0)
            {
                if (sw.ElapsedMilliseconds > 60) throw new TimeoutException("EC IBF timeout");
                Thread.Yield();
            }
        }

        void WaitObf()
        {
            Stopwatch sw = Stopwatch.StartNew();
            while ((In(CMD) & 1) == 0)
            {
                if (sw.ElapsedMilliseconds > 60) throw new TimeoutException("EC OBF timeout");
                Thread.Yield();
            }
        }

        void Drain()
        {
            for (int i = 0; i < 16 && (In(CMD) & 1) != 0; i++) In(DATA);
        }

        void Cmd(int c) { WaitIbf(); Out(CMD, c); }
        void Dat(int d) { WaitIbf(); Out(DATA, d); }
        int Rd() { WaitObf(); return In(DATA); }

        void Lock()
        {
            if (mtx == null) return;
            try
            {
                if (!mtx.WaitOne(250)) throw new TimeoutException("EC busy (Access_EC)");
            }
            catch (AbandonedMutexException) { }
        }

        void Unlock()
        {
            if (mtx == null) return;
            try { mtx.ReleaseMutex(); } catch { }
        }

        public int ReadReg(int addr)
        {
            Lock();
            try { Drain(); Cmd(0x80); Dat(addr); return Rd(); }
            finally { Unlock(); }
        }

        // returns { remote temp, local temp, duty raw 0-255 }
        public int[] FanInfo(int idx)
        {
            Lock();
            try
            {
                Drain(); Cmd(0x9E); Dat(idx);
                int a = Rd(); int b = Rd(); int c = Rd();
                return new int[] { a, b, c };
            }
            finally { Unlock(); }
        }

        public int FanRpm(int idx)
        {
            int baseReg = 0xD0 + (idx - 1) * 2;
            int hi = ReadReg(baseReg);
            int lo = ReadReg(baseReg + 1);
            int raw = (hi << 8) | lo;
            if (raw <= 0) return 0;
            int rpm = 2156220 / raw;
            return rpm > 12000 ? 0 : rpm;
        }

        public void SetDuty(int idx, int raw)
        {
            if (raw < 1) raw = 1;
            if (raw > 255) raw = 255;
            Lock();
            try { Drain(); Cmd(0x99); Dat(idx); Dat(raw); }
            finally { Unlock(); }
        }

        public void SetAuto(int idx)
        {
            Lock();
            try { Drain(); Cmd(0x99); Dat(0xFF); Dat(idx); }
            finally { Unlock(); }
        }

        public void Dispose()
        {
            if (io != null) io.Dispose();
            if (mtx != null) mtx.Dispose();
        }
    }

    // --------------------------------------------------------------- Intel MSR
    public class IntelMsr : IDisposable
    {
        PawnIo io;
        public IntelMsr(byte[] module) { io = new PawnIo(module); }
        public ulong Read(uint msr) { return unchecked((ulong)io.Exec("ioctl_read_msr", new long[] { msr }, 1)[0]); }
        public void Dispose() { if (io != null) io.Dispose(); }
    }

    // --------------------------------------------------------------------- PDH
    public class Pdh : IDisposable
    {
        [StructLayout(LayoutKind.Explicit)]
        struct FmtValue
        {
            [FieldOffset(0)] public uint CStatus;
            [FieldOffset(8)] public double Value;
        }

        [DllImport("pdh.dll", CharSet = CharSet.Unicode, EntryPoint = "PdhOpenQueryW")]
        static extern int PdhOpenQuery(string src, IntPtr user, out IntPtr q);
        [DllImport("pdh.dll", CharSet = CharSet.Unicode, EntryPoint = "PdhAddEnglishCounterW")]
        static extern int PdhAddEnglishCounter(IntPtr q, string path, IntPtr user, out IntPtr c);
        [DllImport("pdh.dll")]
        static extern int PdhCollectQueryData(IntPtr q);
        [DllImport("pdh.dll")]
        static extern int PdhGetFormattedCounterValue(IntPtr c, uint fmt, IntPtr type, out FmtValue v);
        [DllImport("pdh.dll")]
        static extern int PdhCloseQuery(IntPtr q);

        IntPtr q, cUtil, cPerf, cTime;
        bool ok;

        public Pdh()
        {
            if (PdhOpenQuery(null, IntPtr.Zero, out q) != 0) return;
            if (PdhAddEnglishCounter(q, @"\Processor Information(_Total)\% Processor Utility", IntPtr.Zero, out cUtil) != 0) cUtil = IntPtr.Zero;
            if (PdhAddEnglishCounter(q, @"\Processor Information(_Total)\% Processor Performance", IntPtr.Zero, out cPerf) != 0) cPerf = IntPtr.Zero;
            if (PdhAddEnglishCounter(q, @"\Processor(_Total)\% Processor Time", IntPtr.Zero, out cTime) != 0) cTime = IntPtr.Zero;
            PdhCollectQueryData(q);
            ok = true;
        }

        double Get(IntPtr c)
        {
            if (c == IntPtr.Zero) return double.NaN;
            FmtValue v;
            if (PdhGetFormattedCounterValue(c, 0x200 | 0x8000, IntPtr.Zero, out v) != 0) return double.NaN;
            return v.Value;
        }

        public void Collect(out double load, out double perfPct)
        {
            load = double.NaN; perfPct = double.NaN;
            if (!ok) return;
            PdhCollectQueryData(q);
            load = Get(cUtil);
            if (double.IsNaN(load)) load = Get(cTime);
            perfPct = Get(cPerf);
        }

        public void Dispose() { if (ok) PdhCloseQuery(q); ok = false; }
    }

    // -------------------------------------------------------------------- NVML
    public static class Nvml
    {
        [StructLayout(LayoutKind.Sequential)] public struct Util { public uint Gpu; public uint Memory; }
        [StructLayout(LayoutKind.Sequential)] public struct Mem { public ulong Total; public ulong Free; public ulong Used; }

        [DllImport("nvml.dll", EntryPoint = "nvmlInit_v2")] public static extern int Init();
        [DllImport("nvml.dll", EntryPoint = "nvmlShutdown")] public static extern int Shutdown();
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetHandleByIndex_v2")] public static extern int GetHandle(uint idx, out IntPtr dev);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetName", CharSet = CharSet.Ansi)] public static extern int GetName(IntPtr dev, StringBuilder name, uint len);
        [DllImport("nvml.dll", EntryPoint = "nvmlSystemGetDriverVersion", CharSet = CharSet.Ansi)] public static extern int GetDriver(StringBuilder ver, uint len);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetTemperature")] public static extern int GetTemp(IntPtr dev, int sensor, out uint t);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetClockInfo")] public static extern int GetClock(IntPtr dev, int type, out uint mhz);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetUtilizationRates")] public static extern int GetUtil(IntPtr dev, out Util u);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetPowerUsage")] public static extern int GetPower(IntPtr dev, out uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetMemoryInfo")] public static extern int GetMem(IntPtr dev, out Mem m);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetEnforcedPowerLimit")] public static extern int GetEnforcedLimit(IntPtr dev, out uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetPowerManagementDefaultLimit")] public static extern int GetDefaultLimit(IntPtr dev, out uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetPowerManagementLimitConstraints")] public static extern int GetLimitConstraints(IntPtr dev, out uint minMw, out uint maxMw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceSetPowerManagementLimit")] public static extern int SetPowerLimit(IntPtr dev, uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceSetGpuLockedClocks")] public static extern int SetLockedClocks(IntPtr dev, uint minMhz, uint maxMhz);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceResetGpuLockedClocks")] public static extern int ResetLockedClocks(IntPtr dev);
        [DllImport("nvml.dll", EntryPoint = "nvmlErrorString")] static extern IntPtr ErrorStringPtr(int code);

        public static string ErrorString(int code)
        {
            try { return Marshal.PtrToStringAnsi(ErrorStringPtr(code)); }
            catch { return "NVML error " + code; }
        }
    }

    // ------------------------------------------------------------------- NVAPI
    public class OffsetInfo
    {
        public int Status = -1;
        public int CoreMHz, CoreMin, CoreMax, MemMHz, MemMin, MemMax;
        public bool CoreEditable, MemEditable, CoreFound, MemFound;
        public int CoreBaseMHz, MemBaseMHz;
    }

    public class PowerPolicy
    {
        public int InfoStatus = -1, StatusStatus = -1;
        public bool Valid;
        public double MinPct = double.NaN, DefPct = double.NaN, MaxPct = double.NaN, CurPct = double.NaN;
    }

    public static class NvApi
    {
        [DllImport("nvapi64.dll", EntryPoint = "nvapi_QueryInterface", CallingConvention = CallingConvention.Cdecl)]
        static extern IntPtr QueryInterface(uint id);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DInit();
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DEnum([Out, MarshalAs(UnmanagedType.LPArray, SizeConst = 64)] IntPtr[] handles, out int count);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DPstates(IntPtr gpu, IntPtr info);

        const int PS_BASE = 20, PS_SIZE = 456, CLK_BASE = 8, CLK_SIZE = 44, BUF_SIZE = 7416;
        static readonly uint[] Versions = new uint[] { 0x11C94, 0x21CF8, 0x31CF8 };

        static IntPtr gpu = IntPtr.Zero;
        static DPstates getPs, setPs;
        static DPstates ppGetInfo, ppGetStatus, ppSetStatus;   // client power policies (power target %)
        const int PP_INFO_SIZE = 184, PP_STATUS_SIZE = 72;
        static int verIdx = 0;
        public static bool Ready;
        public static void Reset() { Ready = false; gpu = IntPtr.Zero; }
        public static string LastError = "";

        static Delegate Fn(uint id, Type t)
        {
            IntPtr p = QueryInterface(id);
            if (p == IntPtr.Zero) return null;
            return Marshal.GetDelegateForFunctionPointer(p, t);
        }

        public static bool Init()
        {
            try
            {
                DInit init = (DInit)Fn(0x0150E828, typeof(DInit));
                if (init == null) { LastError = "NvAPI_Initialize missing"; return false; }
                int st = init();
                if (st != 0) { LastError = "NvAPI_Initialize " + st; return false; }
                DEnum en = (DEnum)Fn(0xE5AC921F, typeof(DEnum));
                IntPtr[] h = new IntPtr[64]; int n;
                st = en(h, out n);
                if (st != 0 || n < 1) { LastError = "EnumPhysicalGPUs " + st; return false; }
                gpu = h[0];
                getPs = (DPstates)Fn(0x6FF81213, typeof(DPstates));
                setPs = (DPstates)Fn(0x0F4DAE6B, typeof(DPstates));
                if (getPs == null || setPs == null) { LastError = "Pstates20 API missing"; return false; }
                ppGetInfo = (DPstates)Fn(0x34206D86, typeof(DPstates));
                ppGetStatus = (DPstates)Fn(0x70916171, typeof(DPstates));
                ppSetStatus = (DPstates)Fn(0xAD95F5ED, typeof(DPstates));
                Ready = true;
                return true;
            }
            catch (Exception ex) { LastError = ex.Message; return false; }
        }

        static void Zero(IntPtr p)
        {
            byte[] z = new byte[BUF_SIZE];
            Marshal.Copy(z, 0, p, BUF_SIZE);
        }

        public static OffsetInfo GetOffsets()
        {
            OffsetInfo r = new OffsetInfo();
            if (!Ready) return r;
            IntPtr buf = Marshal.AllocHGlobal(BUF_SIZE);
            try
            {
                int st = -1;
                for (int i = 0; i < Versions.Length; i++)
                {
                    Zero(buf);
                    Marshal.WriteInt32(buf, 0, unchecked((int)Versions[i]));
                    st = getPs(gpu, buf);
                    if (st == 0) { verIdx = i; break; }
                }
                r.Status = st;
                if (st != 0) return r;
                int numPs = Marshal.ReadInt32(buf, 8);
                int numClk = Marshal.ReadInt32(buf, 12);
                if (numPs > 16) numPs = 16;
                if (numClk > 8) numClk = 8;
                for (int p = 0; p < numPs; p++)
                {
                    int ps = PS_BASE + p * PS_SIZE;
                    if (Marshal.ReadInt32(buf, ps) != 0) continue; // P0 only
                    for (int c = 0; c < numClk; c++)
                    {
                        int o = ps + CLK_BASE + c * CLK_SIZE;
                        int dom = Marshal.ReadInt32(buf, o);
                        bool ed = (Marshal.ReadInt32(buf, o + 8) & 1) != 0;
                        int val = Marshal.ReadInt32(buf, o + 12) / 1000;
                        int mn = Marshal.ReadInt32(buf, o + 16) / 1000;
                        int mx = Marshal.ReadInt32(buf, o + 20) / 1000;
                        int freq = Marshal.ReadInt32(buf, o + 24) / 1000;
                        if (dom == 0) { r.CoreFound = true; r.CoreEditable = ed; r.CoreMHz = val; r.CoreMin = mn; r.CoreMax = mx; r.CoreBaseMHz = freq; }
                        else if (dom == 4) { r.MemFound = true; r.MemEditable = ed; r.MemMHz = val; r.MemMin = mn; r.MemMax = mx; r.MemBaseMHz = freq; }
                    }
                }
                return r;
            }
            catch (Exception ex) { LastError = ex.Message; r.Status = -1; return r; }
            finally { Marshal.FreeHGlobal(buf); }
        }

        // domain 0 = graphics, 4 = memory. Returns NVAPI status (0 = OK)
        public static int SetOffset(int domain, int mhz)
        {
            if (!Ready) return -1;
            IntPtr buf = Marshal.AllocHGlobal(BUF_SIZE);
            try
            {
                int st = -1;
                for (int k = 0; k < Versions.Length; k++)
                {
                    int i = (verIdx + k) % Versions.Length;
                    Zero(buf);
                    Marshal.WriteInt32(buf, 0, unchecked((int)Versions[i]));
                    Marshal.WriteInt32(buf, 8, 1);  // numPstates
                    Marshal.WriteInt32(buf, 12, 1); // numClocks
                    Marshal.WriteInt32(buf, 16, 0); // numBaseVoltages
                    int ps = PS_BASE;
                    Marshal.WriteInt32(buf, ps, 0); // P0
                    int o = ps + CLK_BASE;
                    Marshal.WriteInt32(buf, o, domain);
                    Marshal.WriteInt32(buf, o + 4, 0);
                    Marshal.WriteInt32(buf, o + 12, mhz * 1000);
                    st = setPs(gpu, buf);
                    if (st != -9) break; // -9 = incompatible struct version
                }
                return st;
            }
            catch (Exception ex) { LastError = ex.Message; return -1; }
            finally { Marshal.FreeHGlobal(buf); }
        }

        static IntPtr Alloc(int size)
        {
            IntPtr p = Marshal.AllocHGlobal(size);
            Marshal.Copy(new byte[size], 0, p, size);
            return p;
        }

        // power target in percent of the default limit (what MSI Afterburner calls "Power Limit %")
        public static PowerPolicy GetPowerPolicy()
        {
            PowerPolicy r = new PowerPolicy();
            if (!Ready || ppGetInfo == null) return r;
            IntPtr info = Alloc(PP_INFO_SIZE), st = Alloc(PP_STATUS_SIZE);
            try
            {
                Marshal.WriteInt32(info, 0, PP_INFO_SIZE | (1 << 16));
                r.InfoStatus = ppGetInfo(gpu, info);
                if (r.InfoStatus == 0 && Marshal.ReadByte(info, 5) >= 1)
                {
                    r.MinPct = Marshal.ReadInt32(info, 8 + 12) / 1000.0;
                    r.DefPct = Marshal.ReadInt32(info, 8 + 24) / 1000.0;
                    r.MaxPct = Marshal.ReadInt32(info, 8 + 36) / 1000.0;
                }
                if (ppGetStatus != null)
                {
                    Marshal.WriteInt32(st, 0, PP_STATUS_SIZE | (1 << 16));
                    r.StatusStatus = ppGetStatus(gpu, st);
                    if (r.StatusStatus == 0 && Marshal.ReadInt32(st, 4) >= 1) r.CurPct = Marshal.ReadInt32(st, 8 + 8) / 1000.0;
                }
                r.Valid = r.InfoStatus == 0 && ppSetStatus != null && r.MaxPct > 0 && r.MaxPct >= r.MinPct && r.MaxPct < 1000;
            }
            catch (Exception ex) { LastError = ex.Message; }
            finally { Marshal.FreeHGlobal(info); Marshal.FreeHGlobal(st); }
            return r;
        }

        public static int SetPowerTarget(double pct)
        {
            if (!Ready || ppSetStatus == null) return -104;
            IntPtr st = Alloc(PP_STATUS_SIZE);
            try
            {
                Marshal.WriteInt32(st, 0, PP_STATUS_SIZE | (1 << 16));
                Marshal.WriteInt32(st, 4, 1);                                   // one entry
                Marshal.WriteInt32(st, 8, 0);                                   // P0
                Marshal.WriteInt32(st, 8 + 8, (int)Math.Round(pct * 1000.0));   // per cent mille
                return ppSetStatus(gpu, st);
            }
            catch (Exception ex) { LastError = ex.Message; return -1; }
            finally { Marshal.FreeHGlobal(st); }
        }

        public static string StatusText(int st)
        {
            switch (st)
            {
                case 0: return "OK";
                case -1: return string.Format(L.T("error ({0})"), LastError);
                case -5: return L.T("invalid argument / out of range");
                case -6: return L.T("NVIDIA GPU not found");
                case -9: return L.T("incompatible structure version");
                case -104: return L.T("not supported by this GPU/vBIOS");
                case -137: return L.T("no permission");
                default: return "NVAPI " + st;
            }
        }
    }

    // ------------------------------------------------------------- fan control
    public class CurvePoint : INotifyPropertyChanged
    {
        int temp, pct;
        public event PropertyChangedEventHandler PropertyChanged;
        public CurvePoint() { }
        public CurvePoint(int t, int p) { temp = Clamp(t, 0, 110); pct = Clamp(p, 0, 100); }
        static int Clamp(int v, int a, int b) { return v < a ? a : (v > b ? b : v); }
        public int Temp
        {
            get { return temp; }
            set { int v = Clamp(value, 0, 110); if (v != temp) { temp = v; Raise("Temp"); } }
        }
        public int Pct
        {
            get { return pct; }
            set { int v = Clamp(value, 0, 100); if (v != pct) { pct = v; Raise("Pct"); } }
        }
        void Raise(string n) { PropertyChangedEventHandler h = PropertyChanged; if (h != null) h(this, new PropertyChangedEventArgs(n)); }
    }

    public class FanChannel
    {
        public int Index;
        public string Name = "";
        public int Mode;          // 0 = EC auto, 1 = curve, 2 = fixed
        public int Source;        // 0 = CPU, 1 = GPU, 2 = max(CPU, GPU)
        public int Fixed = 60;
        public ObservableCollection<CurvePoint> Points = new ObservableCollection<CurvePoint>();

        public bool Present;
        public int Rpm;
        public double DutyPct = double.NaN;
        public double EcTemp = double.NaN;
        public double InputTemp = double.NaN;
        public double EffTemp = double.NaN;
        public double LoadEma = double.NaN;
        public bool IsLoad { get { return Source >= 3; } }
        public double CurPct = double.NaN;
        public bool Manual;
        public int LastRaw = -1;
        public DateTime LastWrite = DateTime.MinValue;
        public string Status = "";
        public bool InfoCmd = true;
    }

    public class Hw : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)]
        struct MemStatus
        {
            public uint Length; public uint Load;
            public ulong TotalPhys, AvailPhys, TotalPage, AvailPage, TotalVirt, AvailVirt, AvailExt;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool GlobalMemoryStatusEx(ref MemStatus m);

        public ClevoEc Ec;
        public IntelMsr Msr;
        public string EcError = "", MsrError = "", NvmlError = "";
        public bool NvmlOk;
        IntPtr dev = IntPtr.Zero;
        public string GpuName = "NVIDIA GPU", Driver = "";
        public double DefaultPowerW = double.NaN, MinPowerW = double.NaN, MaxPowerW = double.NaN;

        public double CpuTemp = double.NaN, CpuPower = double.NaN, CpuLoad = double.NaN, CpuClock = double.NaN;
        public double RamUsed = double.NaN, RamTotal = double.NaN;
        public double GpuTemp = double.NaN, GpuClock = double.NaN, MemClock = double.NaN, GpuLoad = double.NaN;
        public double GpuPower = double.NaN, GpuPowerLimit = double.NaN, VramUsed = double.NaN, VramTotal = double.NaN;

        public List<FanChannel> Fans = new List<FanChannel>();
        public bool GpuTempFromEc;
        public double Hysteresis = 3, DownRate = 3, FailsafeTemp = 92, LoadSmoothSec = 3;
        public bool FailsafeActive;
        public List<string> Messages = new List<string>();

        int tjMax = 100;
        double energyUnit = double.NaN;
        uint lastEnergy; long lastEnergyTicks; bool energyInit;
        Pdh pdh;
        double baseMhz;

        public Hw(string ecModule, string msrModule, double baseClockMhz)
        {
            baseMhz = baseClockMhz > 0 ? baseClockMhz : 3700;
            try { pdh = new Pdh(); } catch (Exception ex) { Msg("PDH: " + ex.Message); }

            Fans.Add(new FanChannel { Index = 1, Name = "CPU", Source = 0 });
            Fans.Add(new FanChannel { Index = 2, Name = "GPU", Source = 1 });

            bool driver = false;
            try { driver = PawnIo.DriverPresent(); } catch { }

            if (!driver) { EcError = MsrError = "PawnIO driver not installed"; }
            else
            {
                if (ecModule != null && File.Exists(ecModule))
                {
                    try { Ec = new ClevoEc(File.ReadAllBytes(ecModule)); }
                    catch (Exception ex) { EcError = ex.Message; Ec = null; }
                }
                else EcError = "LpcACPIEC.bin not found";

                if (msrModule != null && File.Exists(msrModule))
                {
                    try
                    {
                        Msr = new IntelMsr(File.ReadAllBytes(msrModule));
                        ulong tt = Msr.Read(0x1A2);
                        int tj = (int)((tt >> 16) & 0xFF);
                        if (tj >= 70 && tj <= 115) tjMax = tj;
                        ulong units = Msr.Read(0x606);
                        energyUnit = 1.0 / Math.Pow(2, (double)((units >> 8) & 0x1F));
                    }
                    catch (Exception ex) { MsrError = ex.Message; Msr = null; }
                }
                else MsrError = "IntelMSR.bin not found";
            }

            if (Ec != null) DetectFans();

            try
            {
                int st = Nvml.Init();
                if (st == 0) st = Nvml.GetHandle(0, out dev);
                if (st == 0)
                {
                    NvmlOk = true;
                    StringBuilder sb = new StringBuilder(96);
                    if (Nvml.GetName(dev, sb, 96) == 0) GpuName = sb.ToString();
                    sb = new StringBuilder(80);
                    if (Nvml.GetDriver(sb, 80) == 0) Driver = sb.ToString();
                    uint a, b;
                    if (Nvml.GetDefaultLimit(dev, out a) == 0) DefaultPowerW = a / 1000.0;
                    if (Nvml.GetLimitConstraints(dev, out a, out b) == 0) { MinPowerW = a / 1000.0; MaxPowerW = b / 1000.0; }
                }
                else NvmlError = Nvml.ErrorString(st);
            }
            catch (Exception ex) { NvmlError = ex.Message; }

            NvApi.Init();
        }

        void Msg(string s)
        {
            lock (Messages) { Messages.Add(s); }
        }

        public string[] TakeMessages()
        {
            lock (Messages) { string[] a = Messages.ToArray(); Messages.Clear(); return a; }
        }

        public void DetectFans()
        {
            foreach (FanChannel f in Fans)
            {
                int rpm = -1, duty = -1;
                f.InfoCmd = true;
                try { duty = Ec.FanInfo(f.Index)[2]; }
                catch { f.InfoCmd = false; }
                try { rpm = Ec.FanRpm(f.Index); } catch { rpm = -1; }
                f.Present = f.InfoCmd || rpm >= 0;
            }
        }

        public bool PowerLimitSupported
        {
            get { return NvmlOk && !double.IsNaN(MinPowerW) && !double.IsNaN(MaxPowerW) && MaxPowerW - MinPowerW >= 1; }
        }

        public int SetPowerLimitW(double w) { return NvmlOk ? Nvml.SetPowerLimit(dev, (uint)Math.Round(w * 1000)) : 999; }
        public int LockClocks(int minMhz, int maxMhz) { return NvmlOk ? Nvml.SetLockedClocks(dev, (uint)minMhz, (uint)maxMhz) : 999; }
        public int ResetClocks() { return NvmlOk ? Nvml.ResetLockedClocks(dev) : 999; }
        public string NvmlText(int st) { return st == 999 ? L.T("NVML unavailable") : (st == 0 ? "OK" : Nvml.ErrorString(st)); }

        public void Tick(double dtSec)
        {
            ReadCpu();
            ReadRam();
            ReadGpu();
            ReadFans();
            if (double.IsNaN(GpuTemp) && Fans.Count > 1) GpuTempFromEc = !double.IsNaN(Fans[1].EcTemp); else GpuTempFromEc = false;
            Control(dtSec);
        }

        void ReadCpu()
        {
            if (pdh != null)
            {
                double load, perf;
                pdh.Collect(out load, out perf);
                CpuLoad = double.IsNaN(load) ? double.NaN : Math.Max(0, Math.Min(100, load));
                CpuClock = double.IsNaN(perf) ? double.NaN : baseMhz * perf / 100.0;
            }
            if (Msr != null)
            {
                try
                {
                    ulong ts = Msr.Read(0x1B1);
                    CpuTemp = tjMax - (int)((ts >> 16) & 0x7F);
                    uint e = (uint)(Msr.Read(0x611) & 0xFFFFFFFF);
                    long now = Stopwatch.GetTimestamp();
                    if (energyInit)
                    {
                        double dt = (now - lastEnergyTicks) / (double)Stopwatch.Frequency;
                        uint de = unchecked(e - lastEnergy);
                        if (dt > 0.05) CpuPower = de * energyUnit / dt;
                    }
                    lastEnergy = e; lastEnergyTicks = now; energyInit = true;
                }
                catch (Exception ex) { CpuTemp = double.NaN; CpuPower = double.NaN; Msg("MSR: " + ex.Message); }
            }
            else
            {
                CpuTemp = (Fans.Count > 0) ? Fans[0].EcTemp : double.NaN;
            }
        }

        void ReadRam()
        {
            MemStatus m = new MemStatus();
            m.Length = (uint)Marshal.SizeOf(typeof(MemStatus));
            if (GlobalMemoryStatusEx(ref m))
            {
                RamTotal = m.TotalPhys / 1073741824.0;
                RamUsed = (m.TotalPhys - m.AvailPhys) / 1073741824.0;
            }
        }

        int nvmlBadTicks;
        DateTime nvmlLastReinit = DateTime.MinValue;
        public int NvmlReinits;

        // after a driver/GPU reset the cached NVML handle goes stale and returns errors or garbage
        public bool ReinitNvml()
        {
            try { Nvml.Shutdown(); } catch { }
            NvmlOk = false;
            try
            {
                int st = Nvml.Init();
                if (st == 0) st = Nvml.GetHandle(0, out dev);
                NvmlOk = st == 0;
                if (!NvmlOk) NvmlError = Nvml.ErrorString(st);
                else
                {
                    uint a, b;
                    if (Nvml.GetDefaultLimit(dev, out a) == 0) DefaultPowerW = a / 1000.0;
                    if (Nvml.GetLimitConstraints(dev, out a, out b) == 0) { MinPowerW = a / 1000.0; MaxPowerW = b / 1000.0; }
                }
            }
            catch (Exception ex) { NvmlError = ex.Message; NvmlOk = false; }
            try { NvApi.Reset(); NvApi.Init(); } catch { }
            NvmlReinits++;
            return NvmlOk;
        }

        void ReadGpu()
        {
            if (!NvmlOk)
            {
                if ((DateTime.Now - nvmlLastReinit).TotalSeconds >= 30) { nvmlLastReinit = DateTime.Now; if (ReinitNvml()) Msg("NVML: GPU found again"); }
                if (!NvmlOk) { GpuTemp = GpuClock = MemClock = GpuPower = GpuLoad = double.NaN; return; }
            }
            uint v;
            int stT = Nvml.GetTemp(dev, 0, out v);
            GpuTemp = (stT == 0 && v > 0 && v < 125) ? v : double.NaN;
            int stC = Nvml.GetClock(dev, 0, out v);
            GpuClock = (stC == 0 && v < 4000) ? v : double.NaN;
            int stM = Nvml.GetClock(dev, 2, out v);
            MemClock = (stM == 0 && v < 20000) ? v : double.NaN;
            int stP = Nvml.GetPower(dev, out v);
            GpuPower = (stP == 0 && v < 1000000) ? v / 1000.0 : double.NaN;
            GpuPowerLimit = (Nvml.GetEnforcedLimit(dev, out v) == 0 && v > 0 && v < 1000000) ? v / 1000.0 : double.NaN;
            Nvml.Util u;
            int stU = Nvml.GetUtil(dev, out u);
            GpuLoad = (stU == 0 && u.Gpu <= 100) ? u.Gpu : double.NaN;
            Nvml.Mem mm;
            if (Nvml.GetMem(dev, out mm) == 0) { VramTotal = mm.Total / 1073741824.0; VramUsed = mm.Used / 1073741824.0; }

            // temperature and clock both unusable for 3 reads in a row: reconnect (at most every 30 s)
            bool bad = double.IsNaN(GpuTemp) && double.IsNaN(GpuClock);
            nvmlBadTicks = bad ? nvmlBadTicks + 1 : 0;
            if (nvmlBadTicks >= 3 && (DateTime.Now - nvmlLastReinit).TotalSeconds >= 30)
            {
                nvmlLastReinit = DateTime.Now;
                nvmlBadTicks = 0;
                Msg(string.Format("NVML: invalid readings (temp {0}, clock {1}, power {2}, load {3}) - reconnecting to the GPU", stT, stC, stP, stU));
                if (ReinitNvml()) Msg("NVML: reconnected"); else Msg("NVML: " + NvmlError);
            }
        }

        void ReadFans()
        {
            if (Ec == null) return;
            foreach (FanChannel f in Fans)
            {
                if (!f.Present) continue;
                try
                {
                    if (f.InfoCmd)
                    {
                        int[] info = Ec.FanInfo(f.Index);
                        f.EcTemp = (info[0] > 0 && info[0] < 120) ? info[0] : double.NaN;
                        f.DutyPct = Math.Round(info[2] * 100.0 / 255.0);
                    }
                    else
                    {
                        f.DutyPct = Math.Round(Ec.ReadReg(0xCE + f.Index - 1) * 100.0 / 255.0);
                    }
                    f.Rpm = Ec.FanRpm(f.Index);
                }
                catch (Exception ex) { f.DutyPct = double.NaN; f.Status = ex.Message; }
            }
        }

        public static double Interp(IList<CurvePoint> pts, double t)
        {
            if (pts == null || pts.Count == 0) return double.NaN;
            List<CurvePoint> s = new List<CurvePoint>(pts);
            s.Sort(delegate (CurvePoint a, CurvePoint b) { return a.Temp.CompareTo(b.Temp); });
            if (t <= s[0].Temp) return s[0].Pct;
            if (t >= s[s.Count - 1].Temp) return s[s.Count - 1].Pct;
            for (int i = 0; i < s.Count - 1; i++)
            {
                CurvePoint a = s[i], b = s[i + 1];
                if (t >= a.Temp && t <= b.Temp)
                {
                    if (b.Temp == a.Temp) return Math.Max(a.Pct, b.Pct);
                    return a.Pct + (b.Pct - a.Pct) * (t - a.Temp) / (double)(b.Temp - a.Temp);
                }
            }
            return s[s.Count - 1].Pct;
        }

        // sources: 0 CPU temp, 1 GPU temp, 2 max temp, 3 CPU load, 4 GPU load, 5 max load
        double SourceValue(FanChannel f, double dt)
        {
            if (f.Source >= 3)
            {
                double cl = CpuLoad, gl = GpuLoad, v;
                if (f.Source == 3) v = cl;
                else if (f.Source == 4) v = gl;
                else if (double.IsNaN(cl)) v = gl;
                else if (double.IsNaN(gl)) v = cl;
                else v = Math.Max(cl, gl);
                if (double.IsNaN(v)) { f.LoadEma = double.NaN; return v; }
                if (double.IsNaN(f.LoadEma) || LoadSmoothSec <= 0) f.LoadEma = v;
                else f.LoadEma += (v - f.LoadEma) * Math.Min(1.0, dt / LoadSmoothSec);
                return f.LoadEma;
            }
            double c = !double.IsNaN(CpuTemp) ? CpuTemp : (Fans.Count > 0 ? Fans[0].EcTemp : double.NaN);
            double g = !double.IsNaN(GpuTemp) ? GpuTemp : (Fans.Count > 1 ? Fans[1].EcTemp : double.NaN);
            if (f.Source == 0) return c;
            if (f.Source == 1) return g;
            if (double.IsNaN(c)) return g;
            if (double.IsNaN(g)) return c;
            return Math.Max(c, g);
        }

        void Control(double dt)
        {
            if (Ec == null) return;
            double hot = double.NaN;
            if (!double.IsNaN(CpuTemp)) hot = CpuTemp;
            double gT = !double.IsNaN(GpuTemp) ? GpuTemp : (Fans.Count > 1 ? Fans[1].EcTemp : double.NaN);   // EC fallback keeps the safety check working
            if (!double.IsNaN(gT)) hot = double.IsNaN(hot) ? gT : Math.Max(hot, gT);
            bool fs = !double.IsNaN(hot) && hot >= FailsafeTemp;
            if (fs && !FailsafeActive) Msg(string.Format(L.T("Safety: {0} °C ≥ {1} °C → fans at 100%"), hot.ToString("0"), FailsafeTemp.ToString("0")));
            FailsafeActive = fs;

            foreach (FanChannel f in Fans)
            {
                if (!f.Present) continue;
                try
                {
                    if (f.Mode == 0)
                    {
                        if (f.Manual) { Ec.SetAuto(f.Index); f.Manual = false; f.LastRaw = -1; f.CurPct = double.NaN; f.EffTemp = double.NaN; f.LoadEma = double.NaN; }
                        f.Status = "EC auto";
                        continue;
                    }
                    double t = SourceValue(f, dt);
                    f.InputTemp = t;
                    double target;
                    if (fs) target = 100;
                    else if (f.Mode == 2) target = f.Fixed;
                    else
                    {
                        if (double.IsNaN(t))
                        {
                            if (f.Manual) { Ec.SetAuto(f.Index); f.Manual = false; f.LastRaw = -1; }
                            f.Status = "sem sensor → EC auto";
                            continue;
                        }
                        if (double.IsNaN(f.EffTemp) || t >= f.EffTemp) f.EffTemp = t;
                        else if (t <= f.EffTemp - Hysteresis) f.EffTemp = t + Hysteresis;
                        target = Interp(f.Points, f.EffTemp);
                        if (double.IsNaN(target)) target = 100;
                    }
                    if (double.IsNaN(f.CurPct) || target >= f.CurPct || fs) f.CurPct = target;
                    else f.CurPct = Math.Max(target, f.CurPct - DownRate * dt);

                    int raw = (int)Math.Round(f.CurPct * 2.55);
                    if (raw < 1) raw = 1;
                    if (raw > 255) raw = 255;
                    if (raw != f.LastRaw || (DateTime.Now - f.LastWrite).TotalSeconds >= 3)
                    {
                        Ec.SetDuty(f.Index, raw);
                        f.LastRaw = raw; f.LastWrite = DateTime.Now; f.Manual = true;
                    }
                    f.Status = fs ? "SEGURANÇA 100%" : (f.Mode == 2 ? "fixo" : "curva");
                }
                catch (Exception ex) { f.Status = "erro: " + ex.Message; Msg(string.Format(L.T("Fan {0}: {1}"), f.Name, ex.Message)); }
            }
        }

        public void ReleaseAll()
        {
            if (Ec == null) return;
            foreach (FanChannel f in Fans)
            {
                if (!f.Present) continue;
                for (int i = 0; i < 2; i++)
                {
                    try { Ec.SetAuto(f.Index); break; } catch { Thread.Sleep(20); }
                }
                f.Manual = false; f.LastRaw = -1; f.CurPct = double.NaN; f.EffTemp = double.NaN;
            }
        }

        public void Dispose()
        {
            try { ReleaseAll(); } catch { }
            if (Ec != null) Ec.Dispose();
            if (Msr != null) Msr.Dispose();
            if (pdh != null) pdh.Dispose();
            try { if (NvmlOk) Nvml.Shutdown(); } catch { }
        }
    }

    // ---------------------------------------------------------------- helpers
    public static class Win
    {
        [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
        [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
        public static void ClickThrough(IntPtr h)
        {
            int ex = GetWindowLong(h, -20);
            SetWindowLong(h, -20, ex | 0x20 | 0x80000 | 0x80); // TRANSPARENT | LAYERED | TOOLWINDOW
        }
    }
}
