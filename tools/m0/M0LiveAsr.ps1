# Logica della prova ASR dal vivo (M0), separata dall'hardware per poterla verificare con il self-test.
# Strumento usa e getta per M0, non codice di prodotto. Da includere dopo M0Common.ps1:
#   . "$PSScriptRoot\M0LiveAsr.ps1"
# Acquisizione e riconoscimento sono passati come scriptblock: lo script reale usa microfono e
# sherpa-onnx, il self-test usa sostituti finti. Il testo riconosciuto non viene mai eseguito.

# Prefisso dei file WAV temporanei della prova dal vivo (solo nella cartella temporanea dedicata).
$script:M0LiveWavPrefix = 'qp-live-'

# Indice del dispositivo di acquisizione il cui nome contiene $Pattern, escludendo dispositivi virtuali.
# Errore se nessuno o più di uno corrisponde: in quel caso l'utente sceglie con -DeviceId.
function Select-M0CaptureDevice {
    param([string[]]$Names, [Parameter(Mandatory)][string]$Pattern)
    $virtual = 'Steam Streaming|Virtual|VB-Audio|CABLE|Voicemeeter|NVIDIA Broadcast'
    $all = @($Names | Where-Object { $_ })
    $matching = @()
    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($all[$i] -like "*$Pattern*" -and $all[$i] -notmatch $virtual) { $matching += $i }
    }
    if ($matching.Count -eq 0) {
        throw ("Nessun microfono corrispondente a '{0}' (dispositivi: {1}). Collegarlo o indicare -DeviceId." -f $Pattern, ($all -join '; '))
    }
    if ($matching.Count -gt 1) {
        throw ("Più microfoni corrispondono a '{0}': indicare -DeviceId tra {1}." -f $Pattern, ($matching -join ', '))
    }
    $matching[0]
}

# Elimina i WAV temporanei lasciati da una sessione interrotta in modo brusco (solo il prefisso della prova).
function Remove-M0LiveLeftover {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Rimuove solo i WAV temporanei della prova nella cartella dedicata.')]
    param([Parameter(Mandatory)][string]$TempDir)
    $removed = 0
    if (Test-Path -LiteralPath $TempDir) {
        foreach ($f in @(Get-ChildItem -LiteralPath $TempDir -Filter ($script:M0LiveWavPrefix + '*.wav') -File)) {
            Remove-Item -LiteralPath $f.FullName -Force
            $removed++
        }
    }
    $removed
}

# Una prova: acquisizione in memoria, WAV temporaneo, riconoscimento, metriche. Il WAV viene eliminato nel
# blocco finally in ogni caso (errore, timeout, Ctrl+C). Non lancia eccezioni: gli errori finiscono nel risultato.
function Invoke-M0LiveTrial {
    param(
        [Parameter(Mandatory)][string]$Phrase,
        [Parameter(Mandatory)][string]$TempDir,
        [Parameter(Mandatory)][scriptblock]$Capture,
        [Parameter(Mandatory)][scriptblock]$Recognize,
        [int]$SampleRate = 16000
    )
    $wav = Join-Path $TempDir ('{0}{1}.wav' -f $script:M0LiveWavPrefix, [guid]::NewGuid().ToString('N'))
    $result = [ordered]@{
        expected = $Phrase; status = 'error'; error = $null; recognized = $null
        wer = $null; exactMatch = $false; wakePhrase = $false
        captureMs = $null; asrWallMs = $null; decodeMs = $null; modelLoadMs = $null
        speechRmsDbfs = $null; lowLevel = $false; tempWavDeleted = $null
    }
    try {
        # $Capture deve restituire l'array intero (es. ,$array) per evitare lo srotolamento campione per campione.
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $captured = & $Capture
        $result.captureMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
        $samples = [int16[]]@()
        if ($null -ne $captured) { $samples = [int16[]]$captured }
        if ($samples.Count -eq 0) { throw 'nessun campione audio acquisito' }
        $level = Get-M0LevelStatistic $samples
        $result.speechRmsDbfs = $level.rmsDbfs
        $result.lowLevel = ($null -eq $level.rmsDbfs -or $level.rmsDbfs -lt -50)

        Write-M0WaveFile -Path $wav -Samples $samples -SampleRate $SampleRate
        $run = & $Recognize $wav
        $result.asrWallMs = [math]::Round($run.wallSeconds * 1000, 1)
        if ($run.exitCode -ne 0) { throw ("il riconoscitore è terminato con codice {0}" -f $run.exitCode) }
        $parsed = ConvertFrom-M0SherpaOutput -Stdout $run.stdout -Stderr $run.stderr
        if (-not $parsed.ok) { throw "output del riconoscitore non interpretabile: $($parsed.error)" }

        $hypothesis = @(Get-M0NormalizedWordList $parsed.text)
        $result.recognized = $parsed.text
        $result.wer = Get-M0WordErrorRate -Reference @(Get-M0NormalizedWordList $Phrase) -Hypothesis $hypothesis
        $result.exactMatch = ($result.wer -eq 0)
        $result.wakePhrase = (($hypothesis -join ' ') -match '^quick\s?pilot\b')
        $result.decodeMs = [math]::Round($parsed.decodeSeconds * 1000, 1)
        if ($null -ne $parsed.loadSeconds) { $result.modelLoadMs = [math]::Round($parsed.loadSeconds * 1000, 1) }
        $result.status = 'ok'
    }
    catch {
        $result.error = $_.Exception.Message
    }
    finally {
        # Se il file è ancora bloccato (es. riconoscitore interrotto) la rimozione può fallire: lo si segnala
        # in tempWavDeleted e il file viene eliminato da Remove-M0LiveLeftover all'avvio successivo.
        try { if (Test-Path -LiteralPath $wav) { Remove-Item -LiteralPath $wav -Force } } catch { $result.error = "$($result.error) | WAV temporaneo non eliminato: $($_.Exception.Message)".Trim(' |') }
        $result.tempWavDeleted = -not (Test-Path -LiteralPath $wav)
    }
    $result
}

# Sessione: consenso esplicito, poi una frase alla volta. Nessuna acquisizione senza consenso.
# Restituisce solo l'oggetto della sessione; i messaggi per l'utente vanno a schermo (Write-Host).
# $ReadAnswer riceve il testo della domanda e restituisce la risposta (Read-Host nello script reale).
function Invoke-M0LiveSession {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Messaggi interattivi: lo stream di output contiene solo il risultato della sessione.')]
    param(
        [Parameter(Mandatory)][string[]]$Phrases,
        [Parameter(Mandatory)][string]$TempDir,
        [Parameter(Mandatory)][string]$ConsentText,
        [Parameter(Mandatory)][scriptblock]$ReadAnswer,
        [Parameter(Mandatory)][scriptblock]$Capture,
        [Parameter(Mandatory)][scriptblock]$Recognize,
        [int]$SampleRate = 16000
    )
    $session = [ordered]@{ consented = $false; cancelled = $false; trials = @() }
    Write-Host $ConsentText
    $answer = & $ReadAnswer 'Acconsenti a registrare con queste condizioni? (s/n)'
    if ("$answer" -notmatch '^\s*(s|si|sì|y|yes)\s*$') {
        Write-Host 'Consenso non dato: nessuna acquisizione eseguita.'
        return $session
    }
    $session.consented = $true

    for ($i = 0; $i -lt $Phrases.Count; $i++) {
        Write-Host ''
        Write-Host ('Frase {0}/{1}:  {2}' -f ($i + 1), $Phrases.Count, $Phrases[$i])
        $choice = & $ReadAnswer 'Invio = registra ora, p = passa, q = termina'
        if ("$choice" -match '^\s*q') { $session.cancelled = $true; Write-Host 'Prova terminata dall''utente.'; break }
        if ("$choice" -match '^\s*p') {
            $session.trials += [ordered]@{ expected = $Phrases[$i]; status = 'skipped' }
            continue
        }
        Write-Host 'Registrazione in corso: pronuncia la frase...'
        $trial = Invoke-M0LiveTrial -Phrase $Phrases[$i] -TempDir $TempDir -Capture $Capture -Recognize $Recognize -SampleRate $SampleRate
        if ($trial.status -eq 'ok') {
            Write-Host ('  riconosciuto: {0}' -f $trial.recognized)
            Write-Host ('  WER {0}  prefisso «quick pilot»: {1}  decodifica {2} ms' -f $trial.wer, $trial.wakePhrase, $trial.decodeMs)
            if ($trial.lowLevel) { Write-Host '  attenzione: livello del parlato molto basso' }
        }
        else {
            Write-Host ('  ERRORE: {0}' -f $trial.error)
        }
        $session.trials += $trial
    }
    $session
}
