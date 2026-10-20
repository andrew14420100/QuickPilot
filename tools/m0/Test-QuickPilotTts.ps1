<#
.SYNOPSIS
    M0-B, prova B2: verifica le voci TTS italiane di Windows (OneCore) e ne misura la latenza di sintesi.

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto.
    - Elenca le voci WinRT/OneCore e seleziona quelle con lingua it-*.
    - Per ogni voce sintetizza una frase di prova più volte e misura il tempo di sintesi.
    - Riproduce l'audio (salvo -NoPlayback) e chiede all'utente se la voce è davvero italiana
      e comprensibile: il codice di lingua da solo non basta.
    - Nessuna rete, nessuna installazione, nessuna modifica di sistema.
    Output: JSON con i risultati e un WAV per voce nella cartella di output.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-QuickPilotTts.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-QuickPilotTts.ps1 -OutputDir D:\QuickPilotM0 -Repetitions 5
#>
[CmdletBinding()]
param(
    [string]$OutputDir = 'D:\QuickPilotM0\results',
    [string]$Text = 'Quick Pilot. Ordine da 89 euro e 90 centesimi su un negozio di prova: confermi?',
    [ValidateRange(1, 20)][int]$Repetitions = 3,
    [switch]$NoPlayback
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
Assert-M0WindowsPowerShell
$OutputDir = Resolve-M0OutputDir -Path $OutputDir -RequiredMB 20

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
$null = [Windows.Media.SpeechSynthesis.SpeechSynthesisStream, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]

# Attende un'operazione asincrona WinRT (IAsyncOperation<T>) e ne restituisce il risultato.
$asTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
function Wait-WinRtOperation {
    param($Operation, [Type]$ResultType)
    $task = $asTaskMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.Wait()
    $task.Result
}

$allVoices = @([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices)
$italian = @($allVoices | Where-Object { $_.Language -like 'it*' })
Write-Output ("Voci WinRT totali: {0}; con lingua it-*: {1}" -f $allVoices.Count, $italian.Count)

$results = @()
foreach ($voice in $italian) {
    Write-Output ("--- {0} ({1}, {2})" -f $voice.DisplayName, $voice.Language, $voice.Gender)
    $synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
    $synth.Voice = $voice
    $timings = @()
    $stream = $null
    for ($i = 1; $i -le $Repetitions; $i++) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $stream = Wait-WinRtOperation ($synth.SynthesizeTextToStreamAsync($Text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        $sw.Stop()
        $timings += $sw.Elapsed.TotalMilliseconds
    }

    # Salva l'ultima sintesi come WAV (contiene solo la frase di prova).
    $safeName = ($voice.DisplayName -replace '[^\w\-]', '_')
    $wavPath = Join-Path $OutputDir ("b2-tts-{0}.wav" -f $safeName)
    $wavSource = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream.GetInputStreamAt(0))
    $file = [IO.File]::Create($wavPath)
    try { $wavSource.CopyTo($file) } finally { $file.Dispose(); $wavSource.Dispose() }

    $playbackMs = $null
    $heardItalian = $null
    if (-not $NoPlayback) {
        $player = New-Object System.Media.SoundPlayer($wavPath)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $player.PlaySync()
        $sw.Stop()
        $playbackMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
        $answer = Read-Host 'Hai sentito una voce italiana chiara, con il numero letto correttamente? (s/n)'
        $heardItalian = $answer -match '^\s*(s|si|sì|y|yes)\s*$'
    }

    $results += [ordered]@{
        displayName       = $voice.DisplayName
        language          = $voice.Language
        gender            = "$($voice.Gender)"
        synthesisMs       = Get-M0Summary $timings
        firstSynthesisMs  = [math]::Round($timings[0], 1)
        playbackMs        = $playbackMs
        userConfirmedItalian = $heardItalian
        wavFile           = (Split-Path $wavPath -Leaf)
    }
    $synth.Dispose()
}

$report = [ordered]@{
    test           = 'B2-tts'
    collectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    text           = $Text
    repetitions    = $Repetitions
    totalVoices    = $allVoices.Count
    italianVoices  = $results
    verdict        = $(
        if ($italian.Count -eq 0) { 'FAIL: nessuna voce it-* trovata' }
        elseif ($NoPlayback) { 'PARZIALE: voci trovate, ascolto non verificato (-NoPlayback)' }
        elseif (@($results | Where-Object { $_.userConfirmedItalian }).Count -gt 0) { 'PASS: almeno una voce italiana confermata all''ascolto' }
        else { 'FAIL: nessuna voce confermata all''ascolto' })
}
$path = Save-M0Result -Object $report -OutputDir $OutputDir -Name 'b2-tts'
Write-Output ''
Write-Output ("Esito: {0}" -f $report.verdict)
Write-Output ("Risultati salvati in: {0}" -f $path)
