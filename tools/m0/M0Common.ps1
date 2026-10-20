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

# Chiede conferma esplicita (s/n) prima di un'azione visibile, salvo -Force del chiamante.
function Confirm-M0Action {
    param([string]$Message, [switch]$Force)
    if ($Force) { return $true }
    $answer = Read-Host ("{0} Procedere? (s/n)" -f $Message)
    $answer -match '^\s*(s|si|sì|y|yes)\s*$'
}
