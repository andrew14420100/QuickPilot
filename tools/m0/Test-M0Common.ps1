<#
.SYNOPSIS
    Self-test delle funzioni comuni degli strumenti M0 (zero, uno e molti elementi) in StrictMode.

.DESCRIPTION
    Strumento usa e getta per M0, non codice di prodotto. Va eseguito soprattutto in
    Windows PowerShell 5.1, dove un array di un solo elemento restituito da una funzione diventa
    uno scalare senza .Count (causa del bug di Measure-QuickPilotLaunch.ps1).
    - Get-Process viene sostituito da una funzione finta: nessun processo reale viene letto,
      avviato o chiuso.
    - I file JSON di prova vengono scritti e poi eliminati in -TempDir (predefinito su D:).
    Termina con codice 1 se almeno un controllo fallisce.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-M0Common.ps1
#>
[CmdletBinding()]
param(
    [string]$TempDir = 'D:\QuickPilotM0\results\selftest'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
. (Join-Path $PSScriptRoot 'M0LiveAsr.ps1')
Set-StrictMode -Version 2.0

$script:failures = 0
$script:checks = 0
function Assert-M0Test {
    param([string]$Name, [scriptblock]$Condition)
    $script:checks++
    try {
        if (& $Condition) { Write-Output "PASS  $Name"; return }
        Write-Output "FAIL  $Name"
    }
    catch {
        Write-Output ("FAIL  {0} (eccezione: {1})" -f $Name, $_.Exception.Message)
    }
    $script:failures++
}

# Get-Process finto: le funzioni hanno precedenza sui cmdlet con lo stesso nome.
$script:fakeProcesses = @()
function Get-Process {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Mock intenzionale: nessun processo reale nei test.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Parametri presenti per accettare le stesse chiamate di Get-Process.')]
    param([string[]]$Name, [int]$Id, $ErrorAction)
    $script:fakeProcesses | Where-Object { $Name -contains $_.ProcessName }
}
function New-FakeProcess {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Crea solo un oggetto in memoria.')]
    param([string]$ProcessName, [int]$Id, [bool]$HasWindow)
    [pscustomobject]@{
        ProcessName      = $ProcessName
        Id               = $Id
        MainWindowHandle = $(if ($HasWindow) { [IntPtr]42 } else { [IntPtr]::Zero })
    }
}

Write-Output ("PowerShell {0} ({1}), StrictMode 2.0" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

# --- Processi: 0, 1, molti -------------------------------------------------------------------
$script:fakeProcesses = @()
Assert-M0Test 'conteggio processi: 0' { (Get-M0ProcessCount -Name 'notepad') -eq 0 }
Assert-M0Test 'id finestre: 0 (array vuoto con Count)' { @(Get-M0WindowProcessId -Name 'notepad').Count -eq 0 }

$script:fakeProcesses = @(New-FakeProcess -ProcessName 'notepad' -Id 101 -HasWindow $true)
Assert-M0Test 'conteggio processi: 1' { (Get-M0ProcessCount -Name 'notepad') -eq 1 }
Assert-M0Test 'id finestre: 1' { $ids = @(Get-M0WindowProcessId -Name 'notepad'); $ids.Count -eq 1 -and $ids[0] -eq 101 }

$script:fakeProcesses = @(
    (New-FakeProcess -ProcessName 'steam' -Id 201 -HasWindow $false),
    (New-FakeProcess -ProcessName 'steamwebhelper' -Id 202 -HasWindow $true),
    (New-FakeProcess -ProcessName 'steamwebhelper' -Id 203 -HasWindow $true),
    (New-FakeProcess -ProcessName 'discord' -Id 301 -HasWindow $true))
Assert-M0Test 'conteggio processi: molti, più nomi' { (Get-M0ProcessCount -Name @('steam', 'steamwebhelper')) -eq 3 }
Assert-M0Test 'id finestre: molti, esclusi quelli senza finestra' {
    $ids = @(Get-M0WindowProcessId -Name @('steam', 'steamwebhelper')); $ids.Count -eq 2 -and ($ids -contains 202) -and ($ids -contains 203)
}
Assert-M0Test 'processo con nome diverso ignorato' { (Get-M0ProcessCount -Name 'spotify') -eq 0 }

$script:fakeProcesses = @(New-FakeProcess -ProcessName 'notepad' -Id 102 -HasWindow $false)
Assert-M0Test 'processo senza finestra: conteggio 1, finestre 0' {
    (Get-M0ProcessCount -Name 'notepad') -eq 1 -and @(Get-M0WindowProcessId -Name 'notepad').Count -eq 0
}

# --- JSON: array con 0, 1, molti elementi ------------------------------------------------
$TempDir = Resolve-M0OutputDir -Path $TempDir -RequiredMB 1
$jsonCases = [ordered]@{ zero = '[]'; uno = '[{"file":"a.wav","expected":"ciao"}]'; molti = '[{"file":"a.wav"},{"file":"b.wav"},{"file":"c.wav"}]' }
$expectedCounts = @{ zero = 0; uno = 1; molti = 3 }
foreach ($case in $jsonCases.Keys) {
    $path = Join-Path $TempDir ("selftest-{0}.json" -f $case)
    [IO.File]::WriteAllText($path, $jsonCases[$case], (New-Object Text.UTF8Encoding($false)))
    try {
        Assert-M0Test "JSON array: $case" {
            $items = @(Read-M0JsonArray -Path $path)
            $ok = $items.Count -eq $expectedCounts[$case]
            if ($ok -and $items.Count -gt 0) { $ok = ($items[0].file -eq 'a.wav') }
            $ok
        }
    }
    finally {
        Remove-Item -LiteralPath $path
    }
}

# --- Parole e WER: liste vuote, di una parola e di più parole -------------------------------
Assert-M0Test 'parole: testo vuoto' { @(Get-M0NormalizedWordList '').Count -eq 0 }
Assert-M0Test 'parole: una parola' { $w = @(Get-M0NormalizedWordList 'Annulla.'); $w.Count -eq 1 -and $w[0] -eq 'annulla' }
Assert-M0Test 'parole: più parole e trattini' {
    (@(Get-M0NormalizedWordList 'Quick Pilot, avvia Counter-Strike 2.') -join '|') -eq 'quick|pilot|avvia|counter|strike|2'
}
Assert-M0Test 'WER: entrambi vuoti = 0' { (Get-M0WordErrorRate -Reference @() -Hypothesis @()) -eq 0 }
Assert-M0Test 'WER: ipotesi vuota = 1' { (Get-M0WordErrorRate -Reference @('annulla') -Hypothesis @()) -eq 1 }
Assert-M0Test 'WER: $null gestito' { (Get-M0WordErrorRate -Reference $null -Hypothesis $null) -eq 0 }
Assert-M0Test 'WER: una parola uguale = 0' { (Get-M0WordErrorRate -Reference @('annulla') -Hypothesis @('annulla')) -eq 0 }
Assert-M0Test 'WER: una cancellazione su tre = 0.333' {
    (Get-M0WordErrorRate -Reference @('quick', 'pilot', 'annulla') -Hypothesis @('quick', 'annulla')) -eq 0.333
}
Assert-M0Test 'WER: tutto sbagliato = 1' { (Get-M0WordErrorRate -Reference @('a', 'b') -Hypothesis @('c', 'd')) -eq 1 }

# --- Output di whisper-cli: ben formato, CRLF, senza tempi, senza testo, con timestamp ----------
$timings = "whisper_print_timings:     load time =   703.57 ms`nwhisper_print_timings:   encode time = 31623.78 ms /     1 runs`nwhisper_print_timings:    total time = 33912.77 ms"
Assert-M0Test 'whisper: output ben formato' {
    $r = ConvertFrom-M0WhisperOutput -Stdout "`n Quick Pilot, annulla." -Stderr $timings
    $r.ok -and $r.text -eq 'Quick Pilot, annulla.' -and $r.loadMs -eq 703.57 -and $r.transcribeMs -eq 33209.2 -and $r.encodeMs -eq 31623.78
}
Assert-M0Test 'whisper: righe CRLF unite' {
    $r = ConvertFrom-M0WhisperOutput -Stdout "Quick Pilot,`r`n apri Steam.`r`n" -Stderr $timings
    $r.ok -and $r.text -eq 'Quick Pilot, apri Steam.'
}
Assert-M0Test 'whisper: tempi mancanti -> errore' {
    $r = ConvertFrom-M0WhisperOutput -Stdout 'Quick Pilot' -Stderr 'error: failed to open model'
    (-not $r.ok) -and $r.error -match 'tempi'
}
Assert-M0Test 'whisper: stdout vuoto -> errore' {
    $r = ConvertFrom-M0WhisperOutput -Stdout "`n  `n" -Stderr $timings
    (-not $r.ok) -and $r.error -match 'nessuna trascrizione'
}
Assert-M0Test 'whisper: stdout $null -> errore' {
    $r = ConvertFrom-M0WhisperOutput -Stdout $null -Stderr $null
    (-not $r.ok) -and $r.error
}
Assert-M0Test 'whisper: timestamp inattesi -> errore' {
    $r = ConvertFrom-M0WhisperOutput -Stdout '[00:00:00.000 --> 00:00:02.000]  Quick Pilot' -Stderr $timings
    (-not $r.ok) -and $r.error -match 'timestamp'
}

# --- nvidia-smi: un percorso inesistente produce un errore descritto, non un'eccezione ----------
Assert-M0Test 'GPU: eseguibile mancante -> ok=false con motivo' {
    $r = Get-M0NvidiaSample -SmiPath (Join-Path $TempDir 'non-esiste-nvidia-smi.exe')
    (-not $r.ok) -and $r.error
}
$realSmi = Find-M0NvidiaSmi
if ($realSmi) {
    Assert-M0Test "GPU: campione reale da $realSmi" {
        $r = Get-M0NvidiaSample -SmiPath $realSmi
        if (-not $r.ok) { Write-Output "      motivo: $($r.error)" }
        $r.ok
    }
}
else {
    Write-Output 'SKIP  GPU: nvidia-smi non trovato su questo sistema'
}

# --- Output di sherpa-onnx: ben formato, senza JSON, JSON non valido, senza tempi ---------------
$sherpaErr = "recognizer created in 1.074 s`nElapsed seconds: 0.099 s`nReal time factor (RTF): 0.099 / 2.500 = 0.040"
Assert-M0Test 'sherpa: output ben formato' {
    $r = ConvertFrom-M0SherpaOutput -Stdout '{"lang": "", "text": " Quick Pilot, annulla.", "words": []}' -Stderr $sherpaErr
    $r.ok -and $r.text -eq 'Quick Pilot, annulla.' -and $r.loadSeconds -eq 1.074 -and $r.decodeSeconds -eq 0.099 -and $r.audioSeconds -eq 2.5
}
Assert-M0Test 'sherpa: nessuna riga JSON -> errore' { $r = ConvertFrom-M0SherpaOutput -Stdout '' -Stderr $sherpaErr; (-not $r.ok) -and $r.error -match 'JSON' }
Assert-M0Test 'sherpa: JSON non valido -> errore' { $r = ConvertFrom-M0SherpaOutput -Stdout '{"text": ' -Stderr $sherpaErr; (-not $r.ok) -and $r.error }
Assert-M0Test 'sherpa: campo text assente -> errore' { $r = ConvertFrom-M0SherpaOutput -Stdout '{"lang": ""}' -Stderr $sherpaErr; (-not $r.ok) -and $r.error -match 'text' }
Assert-M0Test 'sherpa: tempi assenti -> errore' { $r = ConvertFrom-M0SherpaOutput -Stdout '{"text": "ciao"}' -Stderr ''; (-not $r.ok) -and $r.error -match 'Elapsed' }

# --- Livelli audio: 0, 1, molti campioni -----------------------------------------------------
Assert-M0Test 'livelli: 0 campioni' { (Get-M0LevelStatistic ([int16[]]@())).samples -eq 0 }
Assert-M0Test 'livelli: 1 campione a fondo scala' { $l = Get-M0LevelStatistic ([int16[]]@(32767)); $l.samples -eq 1 -and $l.clippedPercent -eq 100 }
Assert-M0Test 'livelli: silenzio -> rms null' { $l = Get-M0LevelStatistic ([int16[]](@(0) * 1600)); $l.samples -eq 1600 -and $null -eq $l.rmsDbfs }

# --- Selezione del microfono: mancante, virtuale, ambiguo, unico ------------------------------
Assert-M0Test 'microfono: nessun dispositivo -> errore' { try { Select-M0CaptureDevice -Names @() -Pattern 'Katana'; $false } catch { $_.Exception.Message -match 'Nessun microfono' } }
Assert-M0Test 'microfono: solo Steam Streaming -> errore' {
    try { Select-M0CaptureDevice -Names @('Microfono (Steam Streaming Microphone)') -Pattern 'Microphone'; $false } catch { $_.Exception.Message -match 'Nessun microfono' }
}
Assert-M0Test 'microfono: Katana tra più dispositivi -> indice corretto' {
    (Select-M0CaptureDevice -Names @('Microfono (Steam Streaming Micro', 'Microfono (SB Katana V2X)') -Pattern 'Katana') -eq 1
}
Assert-M0Test 'microfono: due corrispondenze -> errore ambiguo' {
    try { Select-M0CaptureDevice -Names @('Katana A', 'Katana B') -Pattern 'Katana'; $false } catch { $_.Exception.Message -match 'Più microfoni' }
}

# --- Comandi, WAV, unità di sistema, file del modello ----------------------------------------
Assert-M0Test 'comandi di prova: 10 frasi con prefisso' {
    $c = @(Get-M0CommandList); $c.Count -eq 10 -and @($c | Where-Object { $_ -notlike 'Quick Pilot,*' }).Count -eq 0
}
$liveDir = Join-Path $TempDir 'live'
if (-not (Test-Path -LiteralPath $liveDir)) { New-Item -ItemType Directory -Path $liveDir | Out-Null }
Assert-M0Test 'WAV: intestazione PCM 16 kHz mono e dimensione' {
    $w = Join-Path $liveDir 'header-test.wav'
    try {
        Write-M0WaveFile -Path $w -Samples ([int16[]](1..100)) -SampleRate 16000
        $b = [IO.File]::ReadAllBytes($w)
        $b.Length -eq 244 -and [Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'RIFF' -and [BitConverter]::ToInt32($b, 24) -eq 16000 -and [BitConverter]::ToInt16($b, 22) -eq 1 -and [BitConverter]::ToInt32($b, 40) -eq 200
    }
    finally { if (Test-Path -LiteralPath $w) { Remove-Item -LiteralPath $w } }
}
Assert-M0Test 'unità di sistema rifiutata' {
    if (-not $env:SystemDrive) { return $true }
    try { Assert-M0NotSystemDrive -Path (Join-Path $env:SystemDrive 'QuickPilotM0'); $false } catch { $_.Exception.Message -match 'unità di sistema' }
}
Assert-M0Test 'modello: cartella mancante -> errore' {
    try { Get-M0VerifiedParakeetPath -ModelsRoot (Join-Path $liveDir 'non-esiste'); $false } catch { $_.Exception.Message -match 'File mancante' }
}
Assert-M0Test 'file: hash errato -> errore' {
    $f = Join-Path $liveDir 'hash-test.bin'
    try {
        [IO.File]::WriteAllText($f, 'quick pilot')
        try { Assert-M0FileIntegrity -Path $f -Size 11 -Sha256 ('0' * 64); $false } catch { $_.Exception.Message -match 'SHA-256' }
    }
    finally { Remove-Item -LiteralPath $f }
}

# --- Prova dal vivo con microfono e riconoscitore finti ----------------------------------------
$script:captureCalls = 0
$script:wavSeenByRecognizer = $null
$fakeCapture = { $script:captureCalls++; , [int16[]](@(1000, -1000) * 8000) }
$okRecognizer = {
    param($wav)
    $script:wavSeenByRecognizer = Test-Path -LiteralPath $wav
    @{ exitCode = 0; wallSeconds = 1.2; stdout = '{"text": " Quick Pilot, annulla."}'; stderr = $sherpaErr }
}
function Get-LiveWavCount { @(Get-ChildItem -LiteralPath $liveDir -Filter 'qp-live-*.wav' -File).Count }

Assert-M0Test 'prova: successo, metriche e WAV eliminato' {
    $t = Invoke-M0LiveTrial -Phrase 'Quick Pilot, annulla.' -TempDir $liveDir -Capture $fakeCapture -Recognize $okRecognizer
    $t.status -eq 'ok' -and $t.wer -eq 0 -and $t.wakePhrase -and $t.decodeMs -eq 99 -and $t.modelLoadMs -eq 1074 -and
        $script:wavSeenByRecognizer -and $t.tempWavDeleted -and (Get-LiveWavCount) -eq 0
}
Assert-M0Test 'prova: errore del processo -> WAV eliminato' {
    $t = Invoke-M0LiveTrial -Phrase 'Quick Pilot, annulla.' -TempDir $liveDir -Capture $fakeCapture -Recognize { param($wav) $null = $wav; @{ exitCode = 3; wallSeconds = 0.1; stdout = ''; stderr = 'boom' } }
    $t.status -eq 'error' -and $t.error -match 'codice 3' -and $t.tempWavDeleted -and (Get-LiveWavCount) -eq 0
}
Assert-M0Test 'prova: timeout del riconoscitore -> WAV eliminato' {
    $t = Invoke-M0LiveTrial -Phrase 'Quick Pilot, annulla.' -TempDir $liveDir -Capture $fakeCapture -Recognize { param($wav) $null = $wav; throw 'sherpa-onnx-offline.exe non ha terminato entro 60 s.' }
    $t.status -eq 'error' -and $t.error -match 'non ha terminato' -and $t.tempWavDeleted -and (Get-LiveWavCount) -eq 0
}
Assert-M0Test 'prova: output vuoto -> errore, WAV eliminato' {
    $t = Invoke-M0LiveTrial -Phrase 'Quick Pilot, annulla.' -TempDir $liveDir -Capture $fakeCapture -Recognize { param($wav) $null = $wav; @{ exitCode = 0; wallSeconds = 0.1; stdout = ''; stderr = '' } }
    $t.status -eq 'error' -and $t.error -match 'non interpretabile' -and $t.tempWavDeleted -and (Get-LiveWavCount) -eq 0
}
Assert-M0Test 'prova: acquisizione vuota -> errore, nessun WAV' {
    $t = Invoke-M0LiveTrial -Phrase 'Quick Pilot, annulla.' -TempDir $liveDir -Capture { , [int16[]]@() } -Recognize $okRecognizer
    $t.status -eq 'error' -and $t.error -match 'nessun campione' -and (Get-LiveWavCount) -eq 0
}
Assert-M0Test 'prova: errore del microfono -> errore, nessun WAV' {
    $t = Invoke-M0LiveTrial -Phrase 'Quick Pilot, annulla.' -TempDir $liveDir -Capture { throw 'waveInOpen fallita, codice 2' } -Recognize $okRecognizer
    $t.status -eq 'error' -and $t.error -match 'waveInOpen' -and (Get-LiveWavCount) -eq 0
}

# Risposte simulate per la sessione: una coda consumata in ordine.
function New-AnswerQueue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Prepara solo una coda in memoria.')]
    param([string[]]$Answers) $script:answers = New-Object System.Collections.Queue; foreach ($a in $Answers) { $script:answers.Enqueue($a) } }
$queuedAnswer = { param($prompt) $null = $prompt; if ($script:answers.Count -gt 0) { $script:answers.Dequeue() } else { 'q' } }
$phrasesTwo = @('Quick Pilot, annulla.', 'Quick Pilot, apri Steam e Discord.')

Assert-M0Test 'sessione: consenso negato -> nessuna acquisizione e nessun WAV' {
    $script:captureCalls = 0; New-AnswerQueue @('n')
    $r = Invoke-M0LiveSession -Phrases $phrasesTwo -TempDir $liveDir -ConsentText 'test' -ReadAnswer $queuedAnswer -Capture $fakeCapture -Recognize $okRecognizer
    (-not $r.consented) -and @($r.trials).Count -eq 0 -and $script:captureCalls -eq 0 -and (Get-LiveWavCount) -eq 0
}
Assert-M0Test 'sessione: annullamento subito dopo il consenso -> nessuna acquisizione' {
    $script:captureCalls = 0; New-AnswerQueue @('s', 'q')
    $r = Invoke-M0LiveSession -Phrases $phrasesTwo -TempDir $liveDir -ConsentText 'test' -ReadAnswer $queuedAnswer -Capture $fakeCapture -Recognize $okRecognizer
    $r.consented -and $r.cancelled -and @($r.trials).Count -eq 0 -and $script:captureCalls -eq 0
}
Assert-M0Test 'sessione: una frase registrata, una saltata' {
    $script:captureCalls = 0; New-AnswerQueue @('s', '', 'p')
    $r = Invoke-M0LiveSession -Phrases $phrasesTwo -TempDir $liveDir -ConsentText 'test' -ReadAnswer $queuedAnswer -Capture $fakeCapture -Recognize $okRecognizer
    $trials = @($r.trials)
    $trials.Count -eq 2 -and $trials[0].status -eq 'ok' -and $trials[1].status -eq 'skipped' -and $script:captureCalls -eq 1 -and (Get-LiveWavCount) -eq 0
}
Assert-M0Test 'sessione: una sola frase (array di un elemento)' {
    $script:captureCalls = 0; New-AnswerQueue @('s', '')
    $r = Invoke-M0LiveSession -Phrases @('Quick Pilot, annulla.') -TempDir $liveDir -ConsentText 'test' -ReadAnswer $queuedAnswer -Capture $fakeCapture -Recognize $okRecognizer
    @($r.trials).Count -eq 1 -and $script:captureCalls -eq 1
}
Assert-M0Test 'pulizia: WAV rimasti da una sessione interrotta' {
    [IO.File]::WriteAllText((Join-Path $liveDir 'qp-live-orfano.wav'), 'x')
    [IO.File]::WriteAllText((Join-Path $liveDir 'altro-file.wav'), 'x')
    $n = Remove-M0LiveLeftover -TempDir $liveDir
    $ok = $n -eq 1 -and (Get-LiveWavCount) -eq 0 -and (Test-Path -LiteralPath (Join-Path $liveDir 'altro-file.wav'))
    Remove-Item -LiteralPath (Join-Path $liveDir 'altro-file.wav')
    $ok
}
Remove-Item -LiteralPath $liveDir -Recurse -Force

# --- Statistiche: 0, 1, molti valori --------------------------------------------------------
Assert-M0Test 'riepilogo: 0 valori' { (Get-M0Summary ([double[]]@())).n -eq 0 }
Assert-M0Test 'riepilogo: 1 valore' { $s = Get-M0Summary ([double[]]@(42)); $s.n -eq 1 -and $s.p95 -eq 42 }
Assert-M0Test 'riepilogo: molti valori' { $s = Get-M0Summary ([double[]](1..20)); $s.n -eq 20 -and $s.p50 -eq 10 -and $s.p95 -eq 19 }

Write-Output ''
Write-Output ("Controlli: {0}, falliti: {1}" -f $script:checks, $script:failures)
if ($script:failures -gt 0) { exit 1 }
