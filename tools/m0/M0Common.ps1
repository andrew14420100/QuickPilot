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

# Chiede conferma esplicita (s/n) prima di un'azione visibile, salvo -Force del chiamante.
function Confirm-M0Action {
    param([string]$Message, [switch]$Force)
    if ($Force) { return $true }
    $answer = Read-Host ("{0} Procedere? (s/n)" -f $Message)
    $answer -match '^\s*(s|si|sì|y|yes)\s*$'
}
