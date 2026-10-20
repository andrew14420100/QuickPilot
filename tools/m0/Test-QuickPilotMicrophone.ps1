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

. (Join-Path $PSScriptRoot 'M0WaveIn.ps1')
Import-M0WaveIn

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

$noiseStats = Get-M0LevelStatistic $silence
$speechStats = Get-M0LevelStatistic $speech
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
