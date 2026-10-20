<#
.SYNOPSIS
    M0-B, preparazione B4: genera campioni audio sintetici e non personali di comandi italiani
    con le voci OneCore di Windows.

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto.
    - Sintetizza un elenco fisso di comandi di Quick Pilot con ogni voce it-* disponibile
      (es. Elsa, Cosimo) e li salva come WAV, più un file samples.json con il testo atteso.
    - Nessun microfono, nessuna voce dell'utente, nessuna rete, nessuna installazione.
    - Scrive solo in -SamplesDir (predefinito D:\QuickPilotM0\results\b4-samples).
      Se la cartella contiene già campioni chiede prima di sovrascriverli.
    Limite: una voce sintetica è più pulita del parlato reale; questi campioni misurano la
    pipeline e la latenza, non l'accuratezza sulla voce dell'utente (corpus reale solo opt-in).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\New-QuickPilotAsrSamples.ps1
#>
[CmdletBinding()]
param(
    [string]$SamplesDir = 'D:\QuickPilotM0\results\b4-samples'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
Assert-M0WindowsPowerShell
$SamplesDir = Resolve-M0OutputDir -Path $SamplesDir -RequiredMB 20

# Comandi di prova fissi (dai casi d'uso di docs/REQUIREMENTS.md). Nessun dato personale.
$commands = @(
    'Quick Pilot, apri Steam e Discord.',
    'Quick Pilot, avvia Counter-Strike 2.',
    'Quick Pilot, metti in pausa Spotify.',
    'Quick Pilot, sistema i download di oggi.',
    'Quick Pilot, riapri le pagine di ieri.',
    'Quick Pilot, apri la cartella Documenti.',
    'Quick Pilot, crea la routine serata.',
    'Quick Pilot, cerca un SSD da due terabyte.',
    'Quick Pilot, confermo ordine da ottantanove euro.',
    'Quick Pilot, annulla.'
)

$manifestPath = Join-Path $SamplesDir 'samples.json'
if ((Test-Path -LiteralPath $manifestPath) -and
    -not (Confirm-M0Action -Message "In $SamplesDir esistono già campioni: verranno sovrascritti.")) {
    Write-Output 'Annullato: nessun file modificato.'
    return
}

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

$voices = @([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.Language -like 'it*' })
if ($voices.Count -eq 0) { throw 'Nessuna voce it-* disponibile: impossibile generare i campioni.' }

$samples = @()
foreach ($voice in $voices) {
    $synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
    $synth.Voice = $voice
    $voiceTag = ($voice.DisplayName -replace '^Microsoft\s+', '' -replace '\s.*$', '' -replace '[^\w]', '').ToLowerInvariant()
    for ($i = 0; $i -lt $commands.Count; $i++) {
        $file = 'cmd{0:D2}-{1}.wav' -f ($i + 1), $voiceTag
        $stream = Wait-WinRtOperation ($synth.SynthesizeTextToStreamAsync($commands[$i])) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        $wavSource = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream.GetInputStreamAt(0))
        $target = [IO.File]::Create((Join-Path $SamplesDir $file))
        try { $wavSource.CopyTo($target) } finally { $target.Dispose(); $wavSource.Dispose() }
        $samples += [ordered]@{ file = $file; expected = $commands[$i]; voice = $voice.DisplayName; synthetic = $true }
    }
    $synth.Dispose()
    Write-Output ("Generati {0} campioni con {1}" -f $commands.Count, $voice.DisplayName)
}

[IO.File]::WriteAllText($manifestPath, (ConvertTo-Json -InputObject @($samples) -Depth 4), (New-Object Text.UTF8Encoding($false)))
Write-Output ("Campioni sintetici e indice salvati in: {0}" -f $SamplesDir)
