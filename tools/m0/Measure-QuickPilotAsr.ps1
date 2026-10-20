<#
.SYNOPSIS
    M0-B, prova B4 (CPU): trascrive campioni non personali con Parakeet TDT 0.6B v3 int8 tramite
    sherpa-onnx e misura caricamento del modello, latenza di decodifica e accuratezza.

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto.
    Prerequisiti (passo 1, Get-QuickPilotM0Models.ps1 -Extract) e campioni
    (New-QuickPilotAsrSamples.ps1, che scrive samples.json con il testo atteso).
    - Verifica dimensione e SHA-256 dei file del modello prima di usarli (salvo -SkipHashCheck).
    - Esegue sherpa-onnx-offline una volta per campione, solo su CPU, con argomenti fissi:
      nessun testo libero viene passato al processo; i percorsi sono validati.
      Una esecuzione per campione permette di misurare per ciascuno sia il caricamento del
      modello (avvio a freddo) sia la sola decodifica riportata da sherpa-onnx.
    - Calcola WER per campione (normalizzazione: minuscole, senza punteggiatura) e se il testo
      inizia con «quick pilot». I numeri in cifre e in lettere non vengono equiparati.
    - Nessun microfono, nessuna registrazione, nessuna rete. Risultati in -OutputDir (D:).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotAsr.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotAsr.ps1 -Threads 8
#>
[CmdletBinding()]
param(
    [string]$ModelsRoot = 'D:\QuickPilotM0\models',
    [string]$SamplesDir = 'D:\QuickPilotM0\results\b4-samples',
    [string]$OutputDir = 'D:\QuickPilotM0\results',
    [ValidateRange(1, 32)][int]$Threads = 4,
    [ValidateRange(10, 600)][int]$TimeoutSeconds = 120,
    [string]$ExecutablePath,
    [switch]$SkipHashCheck
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
$OutputDir = Resolve-M0OutputDir -Path $OutputDir -RequiredMB 5

# File del modello attesi (stessi valori del manifest di Get-QuickPilotM0Models.ps1).
$modelDir = Join-Path $ModelsRoot 'parakeet-tdt-0.6b-v3-int8'
$modelFiles = [ordered]@{
    encoder = @{ file = 'encoder.int8.onnx'; size = [int64]652184281; sha256 = 'acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247' }
    decoder = @{ file = 'decoder.int8.onnx'; size = [int64]11845275; sha256 = '179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e' }
    joiner  = @{ file = 'joiner.int8.onnx'; size = [int64]6355277; sha256 = '3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3' }
    tokens  = @{ file = 'tokens.txt'; size = [int64]93939; sha256 = 'd58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d' }
}
if (-not $ExecutablePath) {
    $ExecutablePath = Join-Path $ModelsRoot 'sherpa-onnx\sherpa-onnx-v1.13.8-win-x64-shared-MT-Release-no-tts\bin\sherpa-onnx-offline.exe'
}

$exe = Assert-M0SafePath $ExecutablePath
$paths = @{}
foreach ($key in $modelFiles.Keys) {
    $spec = $modelFiles[$key]
    $path = Assert-M0SafePath (Join-Path $modelDir $spec.file)
    Assert-M0FileIntegrity -Path $path -Size $spec.size -Sha256 $spec.sha256 -SkipHash:$SkipHashCheck
    $paths[$key] = $path
}
Write-Output ('Modello verificato ({0}).' -f $(if ($SkipHashCheck) { 'solo dimensioni' } else { 'dimensioni e SHA-256' }))

$indexPath = Join-Path $SamplesDir 'samples.json'
if (-not (Test-Path -LiteralPath $indexPath)) { throw "Indice dei campioni mancante: $indexPath (eseguire New-QuickPilotAsrSamples.ps1)." }
$samples = @(Read-M0JsonArray -Path $indexPath)
if ($samples.Count -eq 0) { throw 'Nessun campione nell''indice.' }

# Argomenti fissi: modello verificato, solo CPU, un file audio per esecuzione.
function Get-RecognizerArgument {
    param([string]$WavPath, [int]$ThreadCount)
    @(
        "--tokens=`"$($paths.tokens)`"", "--encoder=`"$($paths.encoder)`"",
        "--decoder=`"$($paths.decoder)`"", "--joiner=`"$($paths.joiner)`"",
        '--model-type=nemo_transducer', "--num-threads=$ThreadCount", '--provider=cpu',
        "`"$WavPath`""
    ) -join ' '
}

$invariant = [Globalization.CultureInfo]::InvariantCulture
$results = @()
foreach ($sample in $samples) {
    $wav = Assert-M0SafePath (Join-Path $SamplesDir $sample.file)
    $run = Invoke-M0Process -FilePath $exe -Arguments (Get-RecognizerArgument -WavPath $wav -ThreadCount $Threads) -TimeoutSeconds $TimeoutSeconds
    if ($run.exitCode -ne 0) { throw ("sherpa-onnx è terminato con codice {0} su {1}:`n{2}" -f $run.exitCode, $sample.file, $run.stderr) }

    $jsonLine = @($run.stdout -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') }) | Select-Object -First 1
    if (-not $jsonLine) { throw "Nessun risultato JSON per $($sample.file)." }
    $text = ($jsonLine | ConvertFrom-Json).text.Trim()

    $loadSeconds = $null; $decodeSeconds = $null; $audioSeconds = $null
    if ($run.stderr -match 'recognizer created in ([\d.]+) s') { $loadSeconds = [double]::Parse($Matches[1], $invariant) }
    if ($run.stderr -match 'Elapsed seconds:\s*([\d.]+)') { $decodeSeconds = [double]::Parse($Matches[1], $invariant) }
    if ($run.stderr -match 'RTF\):\s*[\d.]+\s*/\s*([\d.]+)') { $audioSeconds = [double]::Parse($Matches[1], $invariant) }

    $reference = @(Get-M0NormalizedWordList $sample.expected)
    $hypothesis = @(Get-M0NormalizedWordList $text)
    $wer = Get-M0WordErrorRate -Reference $reference -Hypothesis $hypothesis
    $results += [ordered]@{
        file          = $sample.file
        voice         = $(if ($sample.PSObject.Properties.Name -contains 'voice') { $sample.voice } else { $null })
        expected      = $sample.expected
        recognized    = $text
        wer           = $wer
        exactMatch    = ($wer -eq 0)
        wakePhrase    = (($hypothesis -join ' ') -match '^quick\s?pilot\b')
        audioSeconds  = $audioSeconds
        loadSeconds   = $loadSeconds
        decodeSeconds = $decodeSeconds
        wallSeconds   = [math]::Round($run.wallSeconds, 3)
    }
    Write-Output ("{0}: WER {1:N3}  decodifica {2} s  -> {3}" -f $sample.file, $wer, $decodeSeconds, $text)
}

$werValues = [double[]]@($results | ForEach-Object { $_.wer })
$decodeMs = [double[]]@($results | Where-Object { $null -ne $_.decodeSeconds } | ForEach-Object { $_.decodeSeconds * 1000 })
$loadMs = [double[]]@($results | Where-Object { $null -ne $_.loadSeconds } | ForEach-Object { $_.loadSeconds * 1000 })
$report = [ordered]@{
    test            = 'B4-asr-parakeet-int8-cpu'
    collectedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
    engine          = 'sherpa-onnx v1.13.8 (CPU), Parakeet TDT 0.6B v3 int8'
    threads         = $Threads
    samples         = $samples.Count
    syntheticAudio  = (@($samples | Where-Object { $_.PSObject.Properties.Name -contains 'synthetic' -and $_.synthetic }).Count -eq $samples.Count)
    exactMatches    = @($results | Where-Object { $_.exactMatch }).Count
    wakePhraseFound = @($results | Where-Object { $_.wakePhrase }).Count
    werMean         = $(if ($werValues.Count) { [math]::Round(($werValues | Measure-Object -Average).Average, 3) } else { $null })
    decodeMs        = Get-M0Summary $decodeMs
    modelLoadMs     = Get-M0Summary $loadMs
    note            = 'wakePhrase verifica solo il testo trascritto: non misura falsi positivi né robustezza in gioco.'
    results         = $results
}
$path = Save-M0Result -Object $report -OutputDir $OutputDir -Name 'b4-asr-parakeet-cpu'
Write-Output ''
Write-Output ("Corrispondenze esatte: {0}/{1}; «quick pilot» riconosciuto: {2}/{1}; WER medio: {3}" -f
    $report.exactMatches, $report.samples, $report.wakePhraseFound, $report.werMean)
Write-Output ("Decodifica p50/p95: {0}/{1} ms; caricamento modello p50: {2} ms" -f $report.decodeMs.p50, $report.decodeMs.p95, $report.modelLoadMs.p50)
Write-Output ("Risultati salvati in: {0}" -f $path)
