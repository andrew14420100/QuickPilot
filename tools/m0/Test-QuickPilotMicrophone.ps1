<#
.SYNOPSIS
    M0-B, preparazione B3/B4: elenca i microfoni e misura livello del parlato e rumore di fondo
    del dispositivo scelto esplicitamente.

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto.
    - Elenca i dispositivi di acquisizione (API waveIn di Windows) e fa scegliere esplicitamente
      quale usare: non usa il dispositivo predefinito di sistema.
    - Registra in memoria qualche secondo di silenzio e qualche secondo di parlato
      (16 kHz, mono, 16 bit, formato tipico dei motori ASR) e calcola livelli RMS, picco,
      rapporto segnale/rumore stimato e percentuale di campioni saturati.
    - L'audio non viene mai salvato: il JSON contiene solo le statistiche.
    - Nessuna rete, nessuna installazione, nessuna modifica di sistema.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-QuickPilotMicrophone.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-QuickPilotMicrophone.ps1 -DeviceId 1 -SpeechSeconds 5
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 31)][int]$DeviceId = -1,
    [ValidateRange(1, 10)][int]$SilenceSeconds = 3,
    [ValidateRange(1, 15)][int]$SpeechSeconds = 4,
    [switch]$ListOnly,
    [string]$OutputDir = 'D:\QuickPilotM0\results'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
Assert-M0WindowsPowerShell
$OutputDir = Resolve-M0OutputDir -Path $OutputDir -RequiredMB 5

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

# Statistiche di livello in dBFS (0 dBFS = fondo scala a 16 bit).
function Get-LevelStatistic {
    param([int16[]]$Samples)
    if ($Samples.Count -eq 0) { return [ordered]@{ samples = 0 } }
    $sumSquares = 0.0
    $peak = 0
    $clipped = 0
    foreach ($s in $Samples) {
        $a = [math]::Abs([int]$s)
        $sumSquares += [double]$a * $a
        if ($a -gt $peak) { $peak = $a }
        if ($a -ge 32767) { $clipped++ }
    }
    $rms = [math]::Sqrt($sumSquares / $Samples.Count)
    [ordered]@{
        samples        = $Samples.Count
        rmsDbfs        = $(if ($rms -gt 0) { [math]::Round(20 * [math]::Log10($rms / 32768), 1) } else { $null })
        peakDbfs       = $(if ($peak -gt 0) { [math]::Round(20 * [math]::Log10($peak / 32768), 1) } else { $null })
        clippedPercent = [math]::Round(100 * $clipped / $Samples.Count, 3)
    }
}

$names = [QuickPilotM0.WaveIn]::GetDeviceNames()
Write-Output 'Dispositivi di acquisizione (i nomi possono essere troncati a 31 caratteri):'
for ($i = 0; $i -lt $names.Count; $i++) { Write-Output ("  [{0}] {1}" -f $i, $names[$i]) }
if ($names.Count -eq 0) { throw 'Nessun dispositivo di acquisizione trovato.' }
if ($ListOnly) { return }

if ($DeviceId -lt 0) {
    $choice = Read-Host 'Numero del microfono da provare (es. il Katana V2X)'
    if ($choice -notmatch '^\d+$') { throw 'Scelta non valida.' }
    $DeviceId = [int]$choice
}
if ($DeviceId -ge $names.Count) { throw "Dispositivo $DeviceId inesistente." }
Write-Output ("Dispositivo scelto: [{0}] {1}" -f $DeviceId, $names[$DeviceId])

$sampleRate = 16000
Read-Host ("Fase 1: resta in SILENZIO per {0} s (con il PC nelle condizioni abituali). Premi Invio per iniziare" -f $SilenceSeconds) | Out-Null
$silence = [QuickPilotM0.WaveIn]::Record([uint32]$DeviceId, $sampleRate, $SilenceSeconds)
Read-Host ("Fase 2: dopo Invio PARLA per {0} s, ad esempio «Quick Pilot, apri Steam e Discord». Premi Invio per iniziare" -f $SpeechSeconds) | Out-Null
$speech = [QuickPilotM0.WaveIn]::Record([uint32]$DeviceId, $sampleRate, $SpeechSeconds)

$noiseStats = Get-LevelStatistic $silence
$speechStats = Get-LevelStatistic $speech
$snr = $null
if ($null -ne $noiseStats.rmsDbfs -and $null -ne $speechStats.rmsDbfs) {
    $snr = [math]::Round($speechStats.rmsDbfs - $noiseStats.rmsDbfs, 1)
}

# Soglie indicative per la scelta del microfono (da rivedere con i risultati di B3/B4).
$notes = @()
if ($null -eq $speechStats.rmsDbfs -or $speechStats.rmsDbfs -lt -45) { $notes += 'Parlato molto debole: dispositivo sbagliato, muto o guadagno basso.' }
if ($speechStats.clippedPercent -gt 0.1) { $notes += 'Saturazione: ridurre il guadagno del microfono.' }
if ($null -ne $snr -and $snr -lt 15) { $notes += 'Rapporto segnale/rumore basso (< 15 dB).' }
if ($notes.Count -eq 0) { $notes += 'Livelli adeguati per le prove ASR.' }

$report = [ordered]@{
    test           = 'B3-prep-microphone'
    collectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    device         = [ordered]@{ id = $DeviceId; name = $names[$DeviceId] }
    allDevices     = $names
    format         = '16 kHz, mono, PCM 16 bit'
    silence        = $noiseStats
    speech         = $speechStats
    snrDb          = $snr
    notes          = $notes
    audioSaved     = $false
}
$path = Save-M0Result -Object $report -OutputDir $OutputDir -Name 'b3-microphone'
Write-Output ($report | ConvertTo-Json -Depth 5)
Write-Output ("Risultati salvati in: {0} (nessun audio salvato)" -f $path)
