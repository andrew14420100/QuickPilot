<#
.SYNOPSIS
    M0-B, B4: confronto quantitativo fra i risultati Parakeet e Whisper sugli stessi campioni.

.DESCRIPTION
    Strumento usa e getta per M0, non codice di prodotto. Sola lettura dei JSON prodotti da
    Measure-QuickPilotAsr.ps1 (Parakeet) e Measure-QuickPilotWhisper.ps1 (Whisper): per impostazione
    predefinita prende il più recente di ciascuno in -ResultsDir. Stampa, per motore e per voce:
    campioni validi, WER medio, corrispondenze esatte, «quick pilot» nel testo, latenza
    (decodifica Parakeet / trascrizione Whisper, entrambe senza caricamento del modello) e caricamento.
    Salva il confronto come JSON in -ResultsDir. Nessuna rete, nessun processo esterno.
    Limiti: corpus sintetico; il controllo del testo «quick pilot» non misura i falsi positivi.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Compare-QuickPilotAsr.ps1
#>
[CmdletBinding()]
param(
    [string]$ResultsDir = 'D:\QuickPilotM0\results',
    [string]$ParakeetFile,
    [string]$WhisperFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')

function Get-LatestResult {
    param([string]$Pattern)
    $file = Get-ChildItem -LiteralPath $ResultsDir -Filter $Pattern -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $file) { throw "Nessun risultato $Pattern in $ResultsDir." }
    $file.FullName
}
if (-not $ParakeetFile) { $ParakeetFile = Get-LatestResult 'b4-asr-parakeet-cpu-*.json' }
if (-not $WhisperFile) { $WhisperFile = Get-LatestResult 'b4-asr-whisper-cpu-*.json' }

# Normalizza un risultato per campione dei due runner in una forma comune.
function ConvertTo-ComparableSample {
    param($Item, [string]$LatencyField, [string]$LoadField, [double]$LatencyScale)
    $names = $Item.PSObject.Properties.Name
    $valid = -not ($names -contains 'status') -or $Item.status -eq 'ok'
    [ordered]@{
        file      = $Item.file
        # Chiave di voce comune ai due motori: dal nome del file generato da New-QuickPilotAsrSamples.ps1
        # (cmdNN-<voce>.wav), perché i risultati Parakeet già misurati non hanno il campo voice.
        voice     = $(if ($Item.file -match '^cmd\d+-([A-Za-z]+)\.wav$') { $Matches[1].ToLowerInvariant() }
                      elseif ($names -contains 'voice' -and $Item.voice) { $Item.voice }
                      else { '(non indicata)' })
        valid     = $valid
        wer       = $(if ($valid) { [double]$Item.wer } else { $null })
        exact     = $valid -and [bool]$Item.exactMatch
        wake      = $valid -and [bool]$Item.wakePhrase
        latencyMs = $(if ($valid -and $null -ne $Item.$LatencyField) { [double]$Item.$LatencyField * $LatencyScale } else { $null })
        loadMs    = $(if ($valid -and $null -ne $Item.$LoadField) { [double]$Item.$LoadField * $(if ($LoadField -eq 'loadSeconds') { 1000 } else { 1 }) } else { $null })
    }
}

function Get-GroupSummary {
    param([object[]]$Items)
    $valid = @($Items | Where-Object { $_.valid })
    $wer = [double[]]@($valid | ForEach-Object { $_.wer })
    [ordered]@{
        samples     = @($Items).Count
        valid       = $valid.Count
        werMean     = $(if ($wer.Count) { [math]::Round(($wer | Measure-Object -Average).Average, 3) } else { $null })
        exact       = @($valid | Where-Object { $_.exact }).Count
        wakePhrase  = @($valid | Where-Object { $_.wake }).Count
        latencyMs   = Get-M0Summary ([double[]]@($valid | Where-Object { $null -ne $_.latencyMs } | ForEach-Object { $_.latencyMs }))
        modelLoadMs = Get-M0Summary ([double[]]@($valid | Where-Object { $null -ne $_.loadMs } | ForEach-Object { $_.loadMs }))
    }
}

$parakeet = Get-Content -LiteralPath $ParakeetFile -Raw -Encoding UTF8 | ConvertFrom-Json
$whisper = Get-Content -LiteralPath $WhisperFile -Raw -Encoding UTF8 | ConvertFrom-Json
$engines = [ordered]@{
    parakeet = @(@($parakeet.results) | ForEach-Object { ConvertTo-ComparableSample -Item $_ -LatencyField 'decodeSeconds' -LoadField 'loadSeconds' -LatencyScale 1000 })
    whisper  = @(@($whisper.results) | ForEach-Object { ConvertTo-ComparableSample -Item $_ -LatencyField 'transcribeMs' -LoadField 'loadMs' -LatencyScale 1 })
}

$pFiles = @($engines.parakeet | ForEach-Object { $_.file } | Sort-Object)
$wFiles = @($engines.whisper | ForEach-Object { $_.file } | Sort-Object)
$sameSamples = (($pFiles -join '|') -eq ($wFiles -join '|'))
if (-not $sameSamples) { Write-Warning 'I due risultati non contengono gli stessi campioni: il confronto non è omogeneo.' }

$comparison = [ordered]@{
    test           = 'B4-asr-comparison'
    collectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    parakeetFile   = (Split-Path -Leaf $ParakeetFile)
    whisperFile    = (Split-Path -Leaf $WhisperFile)
    parakeetEngine = $parakeet.engine
    whisperEngine  = $whisper.engine
    sameSamples    = $sameSamples
    latencyNote    = 'Parakeet: decodifica riportata da sherpa-onnx; Whisper: total meno load di whisper.cpp. Entrambe escludono il caricamento del modello.'
    engines        = [ordered]@{}
}
$rows = @()
foreach ($engine in $engines.Keys) {
    $items = @($engines[$engine])
    $byVoice = [ordered]@{}
    foreach ($voice in @($items | ForEach-Object { $_.voice } | Sort-Object -Unique)) {
        $byVoice[$voice] = Get-GroupSummary @($items | Where-Object { $_.voice -eq $voice })
    }
    $total = Get-GroupSummary $items
    $comparison.engines[$engine] = [ordered]@{ total = $total; byVoice = $byVoice }
    foreach ($group in @(@{ name = 'tutte'; s = $total }) + @($byVoice.Keys | ForEach-Object { @{ name = $_; s = $byVoice[$_] } })) {
        $rows += [pscustomobject]@{
            Motore      = $engine
            Voce        = $group.name
            Validi      = '{0}/{1}' -f $group.s.valid, $group.s.samples
            WER         = $group.s.werMean
            Esatte      = $group.s.exact
            QuickPilot  = $group.s.wakePhrase
            'Lat.p50ms' = $(if ($group.s.latencyMs.n) { $group.s.latencyMs.p50 } else { $null })
            'Lat.p95ms' = $(if ($group.s.latencyMs.n) { $group.s.latencyMs.p95 } else { $null })
            'Load.p50ms' = $(if ($group.s.modelLoadMs.n) { $group.s.modelLoadMs.p50 } else { $null })
        }
    }
}

Write-Output ($rows | Format-Table -AutoSize | Out-String -Width 160)
Write-Output $comparison.latencyNote
$path = Save-M0Result -Object $comparison -OutputDir (Resolve-M0OutputDir -Path $ResultsDir -RequiredMB 1) -Name 'b4-asr-comparison'
Write-Output ("Confronto salvato in: {0}" -f $path)
