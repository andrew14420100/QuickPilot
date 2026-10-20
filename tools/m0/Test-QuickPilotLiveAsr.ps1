<#
.SYNOPSIS
    M0-B, prova ASR dal vivo (opt-in): Parakeet int8 su CPU con la voce reale dell'utente,
    una frase fissa alla volta, dal microfono SB Katana V2X scelto esplicitamente.

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto, e non un sistema di automazione:
    il testo riconosciuto viene solo confrontato con la frase attesa e non viene MAI eseguito.

    Prima di qualsiasi acquisizione:
    - verifica eseguibile sherpa-onnx e file del modello (dimensioni e SHA-256);
    - seleziona il microfono per nome (predefinito «Katana»), escludendo i dispositivi virtuali
      come Steam Streaming Microphone, e lo mostra;
    - spiega cosa verrà registrato, dove, per quanto tempo e come verrà eliminato, e chiede il consenso.
      Senza consenso termina senza registrare nulla.

    Per ogni frase: l'utente preme Invio quando è pronto e si registrano -RecordSeconds secondi.
    Non c'è ascolto in background. L'audio resta in memoria; poiché sherpa-onnx-offline legge solo
    file, viene scritto un WAV temporaneo in -TempDir (su D:), trascritto ed eliminato nel blocco finally
    anche in caso di errore, timeout o Ctrl+C. La cancellazione non impedisce il recupero forense del file.
    Se la finestra viene chiusa bruscamente, i WAV rimasti vengono eliminati all'avvio successivo.

    Il riconoscitore viene avviato per ogni frase: il caricamento del modello (circa 1 s sul PC) viene
    misurato a parte e NON è incluso nella latenza ASR (decodifica). Un servizio con modello sempre
    caricato è una scelta di progetto da valutare in M1.

    Risultati (solo testo e metriche, nessun audio) in -OutputDir.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-QuickPilotLiveAsr.ps1
#>
[CmdletBinding()]
param(
    [string]$ModelsRoot = 'D:\QuickPilotM0\models',
    [string]$OutputDir = 'D:\QuickPilotM0\results',
    [string]$TempDir = 'D:\QuickPilotM0\tmp-live',
    [ValidatePattern('^[\w\- ]+$')][string]$DeviceName = 'Katana',
    [ValidateRange(-1, 31)][int]$DeviceId = -1,
    [ValidateRange(2, 10)][int]$RecordSeconds = 5,
    [ValidateRange(1, 32)][int]$Threads = 4,
    [ValidateRange(10, 300)][int]$TimeoutSeconds = 60,
    [switch]$SkipHashCheck
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
. (Join-Path $PSScriptRoot 'M0LiveAsr.ps1')
. (Join-Path $PSScriptRoot 'M0WaveIn.ps1')
Assert-M0WindowsPowerShell

# --- 1. Controlli che precedono qualsiasi acquisizione ------------------------------------------
Assert-M0NotSystemDrive -Path $OutputDir
Assert-M0NotSystemDrive -Path $TempDir
$OutputDir = Resolve-M0OutputDir -Path $OutputDir -RequiredMB 5
$TempDir = Resolve-M0OutputDir -Path $TempDir -RequiredMB 20
$leftover = Remove-M0LiveLeftover -TempDir $TempDir
if ($leftover -gt 0) { Write-Output ("Eliminati {0} WAV temporanei rimasti da una sessione interrotta." -f $leftover) }

$exe = Assert-M0SafePath (Join-Path $ModelsRoot 'sherpa-onnx\sherpa-onnx-v1.13.8-win-x64-shared-MT-Release-no-tts\bin\sherpa-onnx-offline.exe')
$modelPath = Get-M0VerifiedParakeetPath -ModelsRoot $ModelsRoot -SkipHash:$SkipHashCheck
Write-Output ('Modello Parakeet verificato ({0}).' -f $(if ($SkipHashCheck) { 'solo dimensioni' } else { 'dimensioni e SHA-256' }))

Import-M0WaveIn
$names = @([QuickPilotM0.WaveIn]::GetDeviceNames())
if ($DeviceId -ge 0) {
    if ($DeviceId -ge $names.Count) { throw "Dispositivo $DeviceId inesistente." }
    $device = $DeviceId
}
else {
    $device = Select-M0CaptureDevice -Names $names -Pattern $DeviceName
}
Write-Output ("Microfono selezionato: [{0}] {1}" -f $device, $names[$device])

# --- 2. Consenso e prove ----------------------------------------------------------------------
$phrases = @(Get-M0CommandList)
$consent = @"

=== Prova ASR dal vivo (opt-in) ===
Cosa viene registrato: solo la tua voce mentre pronunci {0} frasi fisse mostrate qui, una alla volta,
  {1} secondi per frase, dal microfono «{2}», e solo dopo che premi Invio.
Dove viene elaborato: sul PC, con Parakeet (sherpa-onnx) su CPU. Nessuna rete.
Audio: per ogni frase viene scritto un WAV temporaneo in {3}, trascritto e cancellato subito
  (anche in caso di errore o Ctrl+C). La cancellazione non impedisce un eventuale recupero forense.
  Nessuna copia dell'audio viene conservata o inserita nei risultati.
Risultati: solo testo atteso/riconosciuto e metriche, in {4}.
Puoi terminare in qualsiasi momento con q (o Ctrl+C).
"@ -f $phrases.Count, $RecordSeconds, $names[$device], $TempDir, $OutputDir

$sampleRate = 16000
$capture = { , [QuickPilotM0.WaveIn]::Record([uint32]$device, $sampleRate, $RecordSeconds) }
$timeout = $TimeoutSeconds
$recognize = {
    param($wavPath)
    Invoke-M0Process -FilePath $exe -Arguments (Get-M0SherpaArgument -ModelPath $modelPath -WavPath $wavPath -Threads $Threads) -TimeoutSeconds $timeout
}
$readAnswer = { param($prompt) Read-Host $prompt }

$session = Invoke-M0LiveSession -Phrases $phrases -TempDir $TempDir -ConsentText $consent -ReadAnswer $readAnswer -Capture $capture -Recognize $recognize -SampleRate $sampleRate
if (-not $session.consented) { return }

# --- 3. Risultati (solo testo e metriche) -------------------------------------------------------
$trials = @($session.trials)
$valid = @($trials | Where-Object { $_.status -eq 'ok' })
$wer = [double[]]@($valid | ForEach-Object { $_.wer })
$report = [ordered]@{
    test            = 'B4-live-asr-parakeet-int8-cpu'
    collectedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
    engine          = 'sherpa-onnx v1.13.8 (CPU), Parakeet TDT 0.6B v3 int8'
    device          = $names[$device]
    recordSeconds   = $RecordSeconds
    threads         = $Threads
    realSpeech      = $true
    audioRetained   = $false
    cancelled       = $session.cancelled
    phrases         = $phrases.Count
    attempted       = @($trials | Where-Object { $_.status -ne 'skipped' }).Count
    valid           = $valid.Count
    exactMatches    = @($valid | Where-Object { $_.exactMatch }).Count
    wakePhraseFound = @($valid | Where-Object { $_.wakePhrase }).Count
    werMean         = $(if ($wer.Count) { [math]::Round(($wer | Measure-Object -Average).Average, 3) } else { $null })
    decodeMs        = Get-M0Summary ([double[]]@($valid | ForEach-Object { $_.decodeMs }))
    asrWallMs       = Get-M0Summary ([double[]]@($valid | ForEach-Object { $_.asrWallMs }))
    modelLoadMs     = Get-M0Summary ([double[]]@($valid | Where-Object { $null -ne $_.modelLoadMs } | ForEach-Object { $_.modelLoadMs }))
    captureMs       = Get-M0Summary ([double[]]@($valid | ForEach-Object { $_.captureMs }))
    allTempWavDeleted = (@($trials | Where-Object { $_.Contains('tempWavDeleted') -and -not $_.tempWavDeleted }).Count -eq 0)
    note            = 'decodeMs esclude il caricamento del modello (modelLoadMs), ripetuto a ogni frase perché il CLI viene avviato per ogni file. wakePhrase verifica solo il testo trascritto: non misura falsi positivi.'
    trials          = $trials
}
$path = Save-M0Result -Object $report -OutputDir $OutputDir -Name 'b4-live-asr-parakeet'
Write-Output ''
Write-Output ("Frasi valide: {0}/{1}; esatte: {2}; «quick pilot» all'inizio: {3}; WER medio: {4}" -f
    $report.valid, $report.attempted, $report.exactMatches, $report.wakePhraseFound, $report.werMean)
Write-Output ("Decodifica p50/p95: {0}/{1} ms; caricamento modello p50: {2} ms; WAV temporanei eliminati: {3}" -f
    $report.decodeMs.p50, $report.decodeMs.p95, $report.modelLoadMs.p50, $report.allTempWavDeleted)
Write-Output ("Risultati salvati in: {0} (nessun audio)" -f $path)
