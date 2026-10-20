# Funzioni condivise dagli strumenti di benchmark M0-B (usa e getta, non codice di prodotto).
# Da includere con: . "$PSScriptRoot\M0Common.ps1"

Set-StrictMode -Version 2.0

# Verifica di girare in Windows PowerShell 5.1 (necessario per le API WinRT e per i contatori CIM).
function Assert-M0WindowsPowerShell {
    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        throw 'Eseguire con Windows PowerShell 5.1: powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>'
    }
}

# Risolve e crea la cartella di output, controllando lo spazio libero dell'unità.
# Fallisce se lo spazio è inferiore a RequiredMB; avvisa sotto i 10 GB.
function Resolve-M0OutputDir {
    param(
        [Parameter(Mandatory)][string]$Path,
        [double]$RequiredMB = 50
    )
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    $drive = New-Object IO.DriveInfo($root)
    if (-not $drive.IsReady) {
        throw ("Unità {0} non disponibile (disco esterno scollegato?). Collegarla o indicare -OutputDir." -f $root)
    }
    $freeMB = [math]::Round($drive.AvailableFreeSpace / 1MB, 0)
    if ($freeMB -lt $RequiredMB) {
        throw ("Spazio insufficiente su {0}: {1} MB liberi, servono almeno {2} MB. Usare -OutputDir su un'altra unità." -f $root, $freeMB, $RequiredMB)
    }
    if ($freeMB -lt 10240) {
        Write-Warning ("Su {0} restano {1} MB liberi. Per file grandi usare -OutputDir su un'altra unità." -f $root, $freeMB)
    }
    if (-not (Test-Path -LiteralPath $full)) {
        New-Item -ItemType Directory -Path $full | Out-Null
    }
    $full
}

# Salva un oggetto come JSON UTF-8 (senza BOM) con nome univoco per data e ora; restituisce il percorso.
function Save-M0Result {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$Name
    )
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $path = Join-Path $OutputDir ("{0}-{1}.json" -f $Name, $stamp)
    $json = $Object | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding($false)))
    $path
}

# Percentile con metodo nearest-rank; restituisce $null se non ci sono valori.
function Get-M0Percentile {
    param([double[]]$Values, [double]$Percentile)
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $sorted = [double[]]($Values | Sort-Object)
    $rank = [math]::Ceiling(($Percentile / 100) * $sorted.Count)
    $index = [math]::Min([math]::Max([int]$rank - 1, 0), $sorted.Count - 1)
    $sorted[$index]
}

# Riepilogo statistico (n, min, p50, p95, max, media) arrotondato a una cifra decimale.
function Get-M0Summary {
    param([double[]]$Values)
    if (-not $Values -or $Values.Count -eq 0) {
        return [ordered]@{ n = 0 }
    }
    $stats = $Values | Measure-Object -Minimum -Maximum -Average
    [ordered]@{
        n    = $Values.Count
        min  = [math]::Round($stats.Minimum, 1)
        p50  = [math]::Round((Get-M0Percentile $Values 50), 1)
        p95  = [math]::Round((Get-M0Percentile $Values 95), 1)
        max  = [math]::Round($stats.Maximum, 1)
        mean = [math]::Round($stats.Average, 1)
    }
}

# Nota per Windows PowerShell 5.1 con StrictMode: le funzioni «srotolano» gli array restituiti,
# quindi 0 elementi diventano $null e 1 elemento diventa uno scalare senza .Count.
# Le funzioni seguenti restituiscono un intero, oppure vanno sempre richiamate dentro @(...).

# Numero di processi in esecuzione con i nomi indicati (sempre un intero).
function Get-M0ProcessCount {
    param([string[]]$Name)
    @(Get-Process -Name $Name -ErrorAction SilentlyContinue).Count
}

# Id dei processi con una finestra principale. Chiamare come @(Get-M0WindowProcessId ...).
function Get-M0WindowProcessId {
    param([string[]]$Name)
    @(Get-Process -Name $Name -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
        ForEach-Object { $_.Id })
}

# Legge un file JSON che contiene un array. Chiamare come @(Read-M0JsonArray ...): in Windows
# PowerShell 5.1 ConvertFrom-Json emette l'array come unico oggetto, qui viene riaperto.
function Read-M0JsonArray {
    param([Parameter(Mandatory)][string]$Path)
    $parsed = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    @($parsed)
}

# Parole normalizzate (minuscole, senza punteggiatura). Chiamare come @(Get-M0NormalizedWordList ...).
function Get-M0NormalizedWordList {
    param([string]$Text)
    if (-not $Text) { return }
    $clean = $Text.ToLowerInvariant() -replace '[^\p{L}\p{Nd}\s-]', ' ' -replace '-', ' '
    @($clean -split '\s+' | Where-Object { $_ })
}

# Word error rate tramite distanza di Levenshtein sulle parole; accetta anche liste vuote o $null.
function Get-M0WordErrorRate {
    param([string[]]$Reference, [string[]]$Hypothesis)
    $ref = @($Reference | Where-Object { $_ })
    $hyp = @($Hypothesis | Where-Object { $_ })
    $n = $ref.Count; $m = $hyp.Count
    if ($n -eq 0) { return $(if ($m -eq 0) { 0.0 } else { 1.0 }) }
    $prev = @(0..$m)
    for ($i = 1; $i -le $n; $i++) {
        $cur = @($i) + @(@(0) * $m)
        for ($j = 1; $j -le $m; $j++) {
            $cost = $(if ($ref[$i - 1] -eq $hyp[$j - 1]) { 0 } else { 1 })
            $cur[$j] = [math]::Min([math]::Min($prev[$j] + 1, $cur[$j - 1] + 1), $prev[$j - 1] + $cost)
        }
        $prev = $cur
    }
    [math]::Round($prev[$m] / $n, 3)
}

# Percorso di nvidia-smi: PATH, poi le posizioni standard del driver NVIDIA. $null se assente.
function Find-M0NvidiaSmi {
    $cmd = Get-Command 'nvidia-smi' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in @(
            $(if ($env:SystemRoot) { Join-Path $env:SystemRoot 'System32\nvidia-smi.exe' }),
            $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe' }))) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    $null
}

# Un campione GPU da nvidia-smi (prima GPU). Usa Process invece dell'operatore & per avere
# codice di uscita e stderr affidabili anche in Windows PowerShell 5.1. Non lancia eccezioni:
# in caso di problemi restituisce ok = $false con il motivo in «error».
function Get-M0NvidiaSample {
    param([Parameter(Mandatory)][string]$SmiPath, [int]$TimeoutMs = 5000)
    $result = [ordered]@{ ok = $false; memoryUsedMB = $null; utilizationPercent = $null; error = $null }
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $SmiPath
        $psi.Arguments = '--query-gpu=memory.used,utilization.gpu --format=csv,noheader,nounits'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $process = [Diagnostics.Process]::Start($psi)
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMs)) {
            $process.Kill()
            $result.error = "timeout dopo $TimeoutMs ms"
            return $result
        }
        $process.WaitForExit()
        $stdout = $stdoutTask.Result
        if ($process.ExitCode -ne 0) {
            $result.error = ("codice di uscita {0}: {1} {2}" -f $process.ExitCode, $stdout.Trim(), $stderrTask.Result.Trim()).Trim()
            return $result
        }
        $line = @($stdout -split "`r?`n" | Where-Object { $_.Trim() })[0]
        $fields = @("$line" -split ',\s*')
        $memory = 0.0; $util = 0.0
        $invariant = [Globalization.CultureInfo]::InvariantCulture
        if ($fields.Count -lt 2 -or
            -not [double]::TryParse($fields[0].Trim(), [Globalization.NumberStyles]::Float, $invariant, [ref]$memory) -or
            -not [double]::TryParse($fields[1].Trim(), [Globalization.NumberStyles]::Float, $invariant, [ref]$util)) {
            $result.error = "output non interpretabile: '$line'"
            return $result
        }
        $result.ok = $true
        $result.memoryUsedMB = $memory
        $result.utilizationPercent = $util
    }
    catch {
        $result.error = $_.Exception.Message
    }
    $result
}

# Percorso di un file esistente da passare a un processo esterno tra virgolette: si rifiutano
# caratteri che altererebbero la riga di comando. Restituisce il percorso completo.
function Assert-M0SafePath {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -match '["\r\n]') { throw "Percorso non ammesso: $Path" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File mancante: $Path" }
    [IO.Path]::GetFullPath($Path)
}

# Verifica dimensione e, salvo -SkipHash, SHA-256 di un file; lancia un errore se non corrispondono.
function Assert-M0FileIntegrity {
    param([Parameter(Mandatory)][string]$Path, [int64]$Size, [string]$Sha256, [switch]$SkipHash)
    $name = Split-Path -Leaf $Path
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -ne $Size) { throw ("{0}: dimensione {1} B, attesa {2} B." -f $name, $length, $Size) }
    if (-not $SkipHash) {
        $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $Sha256) { throw ("{0}: SHA-256 non corrispondente." -f $name) }
    }
}

# Esegue un programma con argomenti già validati, senza shell, catturando stdout/stderr.
# Termina il processo se supera il timeout. Restituisce codice di uscita, durata e output.
function Invoke-M0Process {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$Arguments,
        [int]$TimeoutSeconds = 120
    )
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = Split-Path -Parent $FilePath
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::Start($psi)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        throw ("{0} non ha terminato entro {1} s." -f (Split-Path -Leaf $FilePath), $TimeoutSeconds)
    }
    $process.WaitForExit()
    $sw.Stop()
    [ordered]@{
        exitCode    = $process.ExitCode
        wallSeconds = $sw.Elapsed.TotalSeconds
        stdout      = $stdoutTask.Result
        stderr      = $stderrTask.Result
    }
}

# Tempo in millisecondi da una riga «whisper_print_timings: <nome> time = <valore> ms»; $null se assente.
function Get-M0WhisperTiming {
    param([string]$Stderr, [string]$Name)
    if (-not $Stderr) { return $null }
    $m = [regex]::Match($Stderr, 'whisper_print_timings:\s+' + [regex]::Escape($Name) + ' time =\s+([\d.]+) ms')
    if (-not $m.Success) { return $null }
    [double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

# Interpreta l'output di whisper-cli eseguito con -nt (testo senza timestamp su stdout,
# tempi su stderr), formato verificato con whisper.cpp v1.8.3. Non lancia eccezioni:
# se l'output non è quello atteso restituisce ok = $false con il motivo in «error».
function ConvertFrom-M0WhisperOutput {
    param([string]$Stdout, [string]$Stderr)
    $result = [ordered]@{ ok = $false; text = $null; loadMs = $null; encodeMs = $null; totalMs = $null; transcribeMs = $null; error = $null }
    $result.loadMs = Get-M0WhisperTiming $Stderr 'load'
    $result.encodeMs = Get-M0WhisperTiming $Stderr 'encode'
    $result.totalMs = Get-M0WhisperTiming $Stderr 'total'
    if ($null -eq $result.loadMs -or $null -eq $result.totalMs) {
        $result.error = 'tempi whisper_print_timings (load/total) non trovati'
        return $result
    }
    $lines = @("$Stdout" -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($lines.Count -eq 0) {
        $result.error = 'nessuna trascrizione su stdout'
        return $result
    }
    if (@($lines | Where-Object { $_ -match '^\[\d{2}:\d{2}' }).Count -gt 0) {
        $result.error = 'formato inatteso: trascrizione con timestamp (atteso -nt)'
        return $result
    }
    $result.text = ($lines -join ' ').Trim()
    $result.transcribeMs = [math]::Round($result.totalMs - $result.loadMs, 1)
    $result.ok = $true
    $result
}

# Statistiche di livello in dBFS (0 dBFS = fondo scala a 16 bit).
function Get-M0LevelStatistic {
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

# Rifiuta un percorso sull'unità di sistema (di norma C:), dove l'utente non vuole dati M0.
function Assert-M0NotSystemDrive {
    param([Parameter(Mandatory)][string]$Path)
    $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    if ($env:SystemDrive -and $root.TrimEnd('\').ToUpperInvariant() -eq $env:SystemDrive.TrimEnd('\').ToUpperInvariant()) {
        throw "Il percorso $Path è sull'unità di sistema ($env:SystemDrive): scelta rifiutata."
    }
}

# Comandi di prova fissi (dai casi d'uso di docs/REQUIREMENTS.md), condivisi da campioni sintetici e prova dal vivo.
function Get-M0CommandList {
    @(
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
}

# File del modello Parakeet int8 (stessi valori del manifest -Step 1 di Get-QuickPilotM0Models.ps1).
function Get-M0ParakeetModelSpec {
    [ordered]@{
        encoder = @{ file = 'encoder.int8.onnx'; size = [int64]652184281; sha256 = 'acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247' }
        decoder = @{ file = 'decoder.int8.onnx'; size = [int64]11845275; sha256 = '179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e' }
        joiner  = @{ file = 'joiner.int8.onnx'; size = [int64]6355277; sha256 = '3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3' }
        tokens  = @{ file = 'tokens.txt'; size = [int64]93939; sha256 = 'd58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d' }
    }
}

# Verifica i file Parakeet in <ModelsRoot>\parakeet-tdt-0.6b-v3-int8 e restituisce i loro percorsi completi.
function Get-M0VerifiedParakeetPath {
    param([Parameter(Mandatory)][string]$ModelsRoot, [switch]$SkipHash)
    $modelDir = Join-Path $ModelsRoot 'parakeet-tdt-0.6b-v3-int8'
    $spec = Get-M0ParakeetModelSpec
    $paths = @{}
    foreach ($key in $spec.Keys) {
        $path = Assert-M0SafePath (Join-Path $modelDir $spec[$key].file)
        Assert-M0FileIntegrity -Path $path -Size $spec[$key].size -Sha256 $spec[$key].sha256 -SkipHash:$SkipHash
        $paths[$key] = $path
    }
    $paths
}

# Argomenti fissi per sherpa-onnx-offline: modello verificato, solo CPU, un file audio.
function Get-M0SherpaArgument {
    param([Parameter(Mandatory)][hashtable]$ModelPath, [Parameter(Mandatory)][string]$WavPath, [int]$Threads = 4)
    @(
        "--tokens=`"$($ModelPath.tokens)`"", "--encoder=`"$($ModelPath.encoder)`"",
        "--decoder=`"$($ModelPath.decoder)`"", "--joiner=`"$($ModelPath.joiner)`"",
        '--model-type=nemo_transducer', "--num-threads=$Threads", '--provider=cpu',
        "`"$WavPath`""
    ) -join ' '
}

# Interpreta l'output di sherpa-onnx-offline v1.13.8 (una riga JSON per file su stdout; tempi su stderr).
# Non lancia eccezioni: se l'output non è quello atteso restituisce ok = $false con il motivo.
function ConvertFrom-M0SherpaOutput {
    param([string]$Stdout, [string]$Stderr)
    $result = [ordered]@{ ok = $false; text = $null; loadSeconds = $null; decodeSeconds = $null; audioSeconds = $null; error = $null }
    $invariant = [Globalization.CultureInfo]::InvariantCulture
    if ("$Stderr" -match 'recognizer created in ([\d.]+) s') { $result.loadSeconds = [double]::Parse($Matches[1], $invariant) }
    if ("$Stderr" -match 'Elapsed seconds:\s*([\d.]+)') { $result.decodeSeconds = [double]::Parse($Matches[1], $invariant) }
    if ("$Stderr" -match 'RTF\):\s*[\d.]+\s*/\s*([\d.]+)') { $result.audioSeconds = [double]::Parse($Matches[1], $invariant) }
    $jsonLine = @("$Stdout" -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') }) | Select-Object -First 1
    if (-not $jsonLine) {
        $result.error = 'nessuna riga JSON su stdout'
        return $result
    }
    try { $parsed = $jsonLine | ConvertFrom-Json }
    catch {
        $result.error = 'riga JSON non valida'
        return $result
    }
    if (-not ($parsed.PSObject.Properties.Name -contains 'text')) {
        $result.error = 'campo text assente nel JSON'
        return $result
    }
    if ($null -eq $result.decodeSeconds) {
        $result.error = 'tempo di decodifica (Elapsed seconds) non trovato'
        return $result
    }
    $result.text = "$($parsed.text)".Trim()
    $result.ok = $true
    $result
}

# Scrive campioni PCM 16 bit mono come file WAV (intestazione RIFF standard di 44 byte).
function Write-M0WaveFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][int16[]]$Samples, [int]$SampleRate = 16000)
    $dataBytes = $Samples.Count * 2
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int32](36 + $dataBytes))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int32]16)             # dimensione del blocco fmt
        $writer.Write([int16]1)              # PCM
        $writer.Write([int16]1)              # mono
        $writer.Write([int32]$SampleRate)
        $writer.Write([int32]($SampleRate * 2))
        $writer.Write([int16]2)              # block align
        $writer.Write([int16]16)             # bit per campione
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int32]$dataBytes)
        foreach ($sample in $Samples) { $writer.Write($sample) }
    }
    finally {
        $writer.Dispose()
    }
}

# Chiede conferma esplicita (s/n) prima di un'azione visibile, salvo -Force del chiamante.
function Confirm-M0Action {
    param([string]$Message, [switch]$Force)
    if ($Force) { return $true }
    $answer = Read-Host ("{0} Procedere? (s/n)" -f $Message)
    $answer -match '^\s*(s|si|sì|y|yes)\s*$'
}
