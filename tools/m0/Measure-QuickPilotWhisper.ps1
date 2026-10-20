<#
.SYNOPSIS
    M0-B, prova B4 (confronto): trascrive gli stessi campioni non personali con whisper.cpp
    (large-v3-turbo q5_0) su CPU e misura caricamento, latenza di trascrizione e accuratezza.

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto.
    Prerequisiti: Get-QuickPilotM0Models.ps1 -Step 2 -Extract e i campioni di
    New-QuickPilotAsrSamples.ps1 (gli stessi usati per Parakeet).
    - Controlla che le DLL del Visual C++ Redistributable 2015-2022 x64 richieste dal binario
      siano già presenti in System32; se mancano si ferma senza installare nulla.
    - Verifica dimensione e SHA-256 del modello prima di usarlo (salvo -SkipHashCheck).
    - Esegue whisper-cli una volta per campione, solo CPU (-ng), con argomenti fissi:
      nessun testo libero entra nella riga di comando; i percorsi sono validati.
    - Separa il caricamento del modello («load time» di whisper.cpp) dalla trascrizione
      («total time» meno «load time»), e riporta anche il tempo dell'encoder.
    - Stesse metriche di Measure-QuickPilotAsr.ps1: WER, corrispondenze esatte e presenza del
      testo «quick pilot». Il controllo del testo NON è un benchmark di parola di attivazione:
      non misura falsi positivi né robustezza con voice chat o audio di gioco.
    - Nessun microfono, nessuna registrazione, nessuna rete. Risultati in -OutputDir (D:).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotWhisper.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotWhisper.ps1 -Threads 8
#>
[CmdletBinding()]
param(
    [string]$ModelsRoot = 'D:\QuickPilotM0\models',
    [string]$SamplesDir = 'D:\QuickPilotM0\results\b4-samples',
    [string]$OutputDir = 'D:\QuickPilotM0\results',
    [ValidateRange(1, 32)][int]$Threads = 4,
    [ValidateSet('it', 'auto')][string]$Language = 'it',
    [ValidateRange(0, 1500)][int]$AudioContext = 0,
    [ValidateRange(10, 1800)][int]$TimeoutSeconds = 300,
    [string]$ExecutablePath,
    [switch]$SkipHashCheck
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
$OutputDir = Resolve-M0OutputDir -Path $OutputDir -RequiredMB 5

# Stessi valori del manifest -Step 2 di Get-QuickPilotM0Models.ps1.
$modelSpec = @{
    file   = 'ggml-large-v3-turbo-q5_0.bin'
    size   = [int64]574041195
    sha256 = '394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2'
}
if (-not $ExecutablePath) {
    $ExecutablePath = Join-Path $ModelsRoot 'whisper-cpp-v1.8.3\Release\whisper-cli.exe'
}

# Il binario Windows di whisper.cpp dipende dal Visual C++ Redistributable (anche OpenMP: vcomp140).
if ($env:SystemRoot) {
    $system32 = Join-Path $env:SystemRoot 'System32'
    $missing = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'vcomp140.dll' |
        Where-Object { -not (Test-Path -LiteralPath (Join-Path $system32 $_)) })
    if ($missing.Count -gt 0) {
        $message = 'Mancano DLL del Visual C++ Redistributable 2015-2022 x64: {0}. Lo strumento non installa nulla: ' -f ($missing -join ', ')
        throw ($message + "installarlo è una scelta dell'utente, da fare manualmente dal sito Microsoft se si vuole proseguire con Whisper.")
    }
}

$exe = Assert-M0SafePath $ExecutablePath
$modelPath = Assert-M0SafePath (Join-Path (Join-Path $ModelsRoot 'whisper-large-v3-turbo-q5_0') $modelSpec.file)
Assert-M0FileIntegrity -Path $modelPath -Size $modelSpec.size -Sha256 $modelSpec.sha256 -SkipHash:$SkipHashCheck
Write-Output ('Modello verificato ({0}).' -f $(if ($SkipHashCheck) { 'solo dimensioni' } else { 'dimensioni e SHA-256' }))

$indexPath = Join-Path $SamplesDir 'samples.json'
if (-not (Test-Path -LiteralPath $indexPath)) { throw "Indice dei campioni mancante: $indexPath (eseguire New-QuickPilotAsrSamples.ps1)." }
$samples = @(Read-M0JsonArray -Path $indexPath)
if ($samples.Count -eq 0) { throw 'Nessun campione nell''indice.' }

# Argomenti fissi: modello verificato, solo CPU, senza timestamp, un file audio per esecuzione.
function Get-WhisperArgument {
    param([string]$WavPath)
    $list = @("-m `"$modelPath`"", "-f `"$WavPath`"", "-l $Language", "-t $Threads", '-nt', '-ng')
    if ($AudioContext -gt 0) { $list += "-ac $AudioContext" }
    $list -join ' '
}

$results = @()
foreach ($sample in $samples) {
    $entry = [ordered]@{
        file = $sample.file
        voice = $(if ($sample.PSObject.Properties.Name -contains 'voice') { $sample.voice } else { $null })
        expected = $sample.expected
        status = 'error'; error = $null; recognized = $null; wer = $null; exactMatch = $false; wakePhrase = $false
        loadMs = $null; encodeMs = $null; transcribeMs = $null; wallSeconds = $null
    }
    try {
        $wav = Assert-M0SafePath (Join-Path $SamplesDir $sample.file)
        $run = Invoke-M0Process -FilePath $exe -Arguments (Get-WhisperArgument -WavPath $wav) -TimeoutSeconds $TimeoutSeconds
        $entry.wallSeconds = [math]::Round($run.wallSeconds, 3)
        if ($run.exitCode -ne 0) {
            $tail = @("$($run.stderr)".Trim() -split "`r?`n" | Select-Object -Last 3) -join ' | '
            throw ("codice di uscita {0}: {1}" -f $run.exitCode, $tail)
        }
        $parsed = ConvertFrom-M0WhisperOutput -Stdout $run.stdout -Stderr $run.stderr
        if (-not $parsed.ok) { throw "output non interpretabile: $($parsed.error)" }
        $reference = @(Get-M0NormalizedWordList $sample.expected)
        $hypothesis = @(Get-M0NormalizedWordList $parsed.text)
        $entry.recognized = $parsed.text
        $entry.wer = Get-M0WordErrorRate -Reference $reference -Hypothesis $hypothesis
        $entry.exactMatch = ($entry.wer -eq 0)
        $entry.wakePhrase = (($hypothesis -join ' ') -match '^quick\s?pilot\b')
        $entry.loadMs = $parsed.loadMs
        $entry.encodeMs = $parsed.encodeMs
        $entry.transcribeMs = $parsed.transcribeMs
        $entry.status = 'ok'
        Write-Output ("{0}: WER {1:N3}  trascrizione {2} ms  -> {3}" -f $sample.file, $entry.wer, $entry.transcribeMs, $entry.recognized)
    }
    catch {
        # L'errore resta nel risultato del campione: nessun valore viene contato come valido.
        $entry.error = $_.Exception.Message
        Write-Warning ("{0}: ERRORE {1}" -f $sample.file, $entry.error)
    }
    $results += $entry
}

$valid = @($results | Where-Object { $_.status -eq 'ok' })
$werValues = [double[]]@($valid | ForEach-Object { $_.wer })
$transcribe = [double[]]@($valid | Where-Object { $null -ne $_.transcribeMs } | ForEach-Object { $_.transcribeMs })
$encode = [double[]]@($valid | Where-Object { $null -ne $_.encodeMs } | ForEach-Object { $_.encodeMs })
$load = [double[]]@($valid | Where-Object { $null -ne $_.loadMs } | ForEach-Object { $_.loadMs })
$report = [ordered]@{
    test            = 'B4-asr-whisper-cpu'
    collectedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
    engine          = 'whisper.cpp v1.8.3 (CPU, -ng), ggml-large-v3-turbo-q5_0'
    threads         = $Threads
    language        = $Language
    audioContext    = $AudioContext
    samples         = $samples.Count
    validSamples    = $valid.Count
    errors          = $samples.Count - $valid.Count
    verdict         = $(if ($valid.Count -eq $samples.Count) { 'COMPLETO' } elseif ($valid.Count -eq 0) { 'FALLITO: nessun campione valido' } else { 'INCOMPLETO: vedere gli errori per campione' })
    syntheticAudio  = (@($samples | Where-Object { $_.PSObject.Properties.Name -contains 'synthetic' -and $_.synthetic }).Count -eq $samples.Count)
    exactMatches    = @($results | Where-Object { $_.exactMatch }).Count
    wakePhraseFound = @($results | Where-Object { $_.wakePhrase }).Count
    werMean         = $(if ($werValues.Count) { [math]::Round(($werValues | Measure-Object -Average).Average, 3) } else { $null })
    transcribeMs    = Get-M0Summary $transcribe
    encodeMs        = Get-M0Summary $encode
    modelLoadMs     = Get-M0Summary $load
    note            = 'wakePhrase verifica solo il testo trascritto: non misura falsi positivi né robustezza in gioco.'
    results         = $results
}
$path = Save-M0Result -Object $report -OutputDir $OutputDir -Name 'b4-asr-whisper-cpu'
Write-Output ''
Write-Output ("Esito: {0} ({1}/{2} campioni validi)" -f $report.verdict, $report.validSamples, $report.samples)
Write-Output ("Corrispondenze esatte: {0}/{1}; «quick pilot» nel testo: {2}/{1}; WER medio: {3} (sui campioni validi)" -f
    $report.exactMatches, $report.validSamples, $report.wakePhraseFound, $report.werMean)
Write-Output ("Trascrizione p50/p95: {0}/{1} ms; caricamento modello p50: {2} ms" -f $report.transcribeMs.p50, $report.transcribeMs.p95, $report.modelLoadMs.p50)
Write-Output ("Risultati salvati in: {0}" -f $path)
