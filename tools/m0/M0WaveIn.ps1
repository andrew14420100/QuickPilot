# Acquisizione audio dal microfono tramite l'API waveIn di Windows, solo in memoria.
# Strumento usa e getta per M0, non codice di prodotto. Da includere con: . "$PSScriptRoot\M0WaveIn.ps1"
# Richiede Windows (winmm.dll); il codice C# viene compilato al primo uso con il compilatore di .NET Framework.

# Rende disponibile [QuickPilotM0.WaveIn] (GetDeviceNames, Record) nella sessione corrente.
function Import-M0WaveIn {
    if (-not ('QuickPilotM0.WaveIn' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace QuickPilotM0
{
    public static class WaveIn
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct WaveInCaps
        {
            public ushort wMid;
            public ushort wPid;
            public uint vDriverVersion;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string szPname;
            public uint dwFormats;
            public ushort wChannels;
            public ushort wReserved1;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct WaveFormatEx
        {
            public ushort wFormatTag;
            public ushort nChannels;
            public uint nSamplesPerSec;
            public uint nAvgBytesPerSec;
            public ushort nBlockAlign;
            public ushort wBitsPerSample;
            public ushort cbSize;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct WaveHdr
        {
            public IntPtr lpData;
            public uint dwBufferLength;
            public uint dwBytesRecorded;
            public IntPtr dwUser;
            public uint dwFlags;
            public uint dwLoops;
            public IntPtr lpNext;
            public IntPtr reserved;
        }

        private const uint WHDR_DONE = 0x1;

        [DllImport("winmm.dll")] private static extern uint waveInGetNumDevs();
        [DllImport("winmm.dll", CharSet = CharSet.Unicode)] private static extern uint waveInGetDevCapsW(UIntPtr id, ref WaveInCaps caps, uint size);
        [DllImport("winmm.dll")] private static extern uint waveInOpen(out IntPtr handle, uint id, ref WaveFormatEx format, IntPtr callback, IntPtr instance, uint flags);
        [DllImport("winmm.dll")] private static extern uint waveInPrepareHeader(IntPtr handle, IntPtr header, uint size);
        [DllImport("winmm.dll")] private static extern uint waveInUnprepareHeader(IntPtr handle, IntPtr header, uint size);
        [DllImport("winmm.dll")] private static extern uint waveInAddBuffer(IntPtr handle, IntPtr header, uint size);
        [DllImport("winmm.dll")] private static extern uint waveInStart(IntPtr handle);
        [DllImport("winmm.dll")] private static extern uint waveInReset(IntPtr handle);
        [DllImport("winmm.dll")] private static extern uint waveInClose(IntPtr handle);

        public static string[] GetDeviceNames()
        {
            uint count = waveInGetNumDevs();
            var names = new string[count];
            for (uint i = 0; i < count; i++)
            {
                var caps = new WaveInCaps();
                uint rc = waveInGetDevCapsW(new UIntPtr(i), ref caps, (uint)Marshal.SizeOf(typeof(WaveInCaps)));
                names[i] = rc == 0 ? caps.szPname : "(errore " + rc + ")";
            }
            return names;
        }

        // Registra in memoria e restituisce i campioni PCM 16 bit mono. Nessun dato su disco.
        public static short[] Record(uint deviceId, int sampleRate, int seconds)
        {
            var format = new WaveFormatEx
            {
                wFormatTag = 1, nChannels = 1, nSamplesPerSec = (uint)sampleRate,
                nAvgBytesPerSec = (uint)(sampleRate * 2), nBlockAlign = 2, wBitsPerSample = 16, cbSize = 0
            };
            IntPtr handle;
            uint rc = waveInOpen(out handle, deviceId, ref format, IntPtr.Zero, IntPtr.Zero, 0);
            if (rc != 0) throw new InvalidOperationException("waveInOpen fallita, codice " + rc);

            int bytes = sampleRate * 2 * seconds;
            int headerSize = Marshal.SizeOf(typeof(WaveHdr));
            IntPtr buffer = Marshal.AllocHGlobal(bytes);
            IntPtr header = Marshal.AllocHGlobal(headerSize);
            bool prepared = false;
            try
            {
                var hdr = new WaveHdr { lpData = buffer, dwBufferLength = (uint)bytes };
                Marshal.StructureToPtr(hdr, header, false);
                Check(waveInPrepareHeader(handle, header, (uint)headerSize), "waveInPrepareHeader");
                prepared = true;
                Check(waveInAddBuffer(handle, header, (uint)headerSize), "waveInAddBuffer");
                Check(waveInStart(handle), "waveInStart");

                var deadline = DateTime.UtcNow.AddSeconds(seconds + 5);
                while (true)
                {
                    hdr = (WaveHdr)Marshal.PtrToStructure(header, typeof(WaveHdr));
                    if ((hdr.dwFlags & WHDR_DONE) != 0) break;
                    if (DateTime.UtcNow > deadline) throw new TimeoutException("Registrazione non completata in tempo.");
                    Thread.Sleep(20);
                }

                var samples = new short[hdr.dwBytesRecorded / 2];
                Marshal.Copy(buffer, samples, 0, samples.Length);
                return samples;
            }
            finally
            {
                waveInReset(handle);
                if (prepared) waveInUnprepareHeader(handle, header, (uint)headerSize);
                waveInClose(handle);
                Marshal.FreeHGlobal(header);
                Marshal.FreeHGlobal(buffer);
            }
        }

        private static void Check(uint rc, string call)
        {
            if (rc != 0) throw new InvalidOperationException(call + " fallita, codice " + rc);
        }
    }
}
'@
    }
}
