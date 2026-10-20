<#
.SYNOPSIS
    M0-B, passo 1: scarica e verifica il runtime sherpa-onnx (CPU) e il modello Parakeet TDT 0.6B v3 int8.

.DESCRIPTION
    Strumento usa e getta per M0, non codice di prodotto. Scarica ESCLUSIVAMENTE:
      1. sherpa-onnx v1.13.8, archivio Windows x64 CPU (shared-MT-Release-no-tts);
      2. i quattro file di Parakeet TDT 0.6B v3 int8 (encoder, decoder, joiner, tokens),
         da una revisione immutabile del repository Hugging Face.
    Regole:
    - Scrive solo sotto -ModelsRoot (predefinito D:\QuickPilotM0\models); rifiuta l'unità di sistema.
      I download parziali (*.partial) restano nella stessa cartella, quindi su D:.
    - Verifica dimensione e SHA-256 di ogni file prima di considerarlo valido o di estrarlo;
      al primo controllo fallito elimina il proprio file parziale e si interrompe.
    - Non sovrascrive né elimina file esistenti senza chiedere.
    - Non installa nulla, non modifica registro o permessi e non esegue i programmi scaricati.
      L'unica operazione facoltativa (-Extract) usa tar.exe incluso in Windows, dopo aver
      controllato che l'archivio non contenga percorsi assoluti o con «..».
    - Chiede sempre conferma prima di iniziare. -DryRun mostra il piano senza usare la rete.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotM0Models.ps1 -DryRun
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotM0Models.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotM0Models.ps1 -Extract
#>
[CmdletBinding()]
param(
    [string]$ModelsRoot = 'D:\QuickPilotM0\models',
    [switch]$Extract,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# Manifest fisso del passo 1 (fonti: docs/M0_REPORT.md §7.1). Nessun altro file viene scaricato.
$parakeetRepo = 'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8'
$parakeetRevision = '2bda32ec70b097a55adaa07d9a7173915b43cc78'
$manifest = @(
    [ordered]@{
        id      = 'sherpa-onnx-runtime'
        folder  = 'sherpa-onnx'
        file    = 'sherpa-onnx-v1.13.8-win-x64-shared-MT-Release-no-tts.tar.bz2'
        url     = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-v1.13.8-win-x64-shared-MT-Release-no-tts.tar.bz2'
        size    = [int64]23271851
        sha256  = '4b0a94f7b5c606b1b64a19a831c2127559e4b3d34e195465ebc7be73d9ed4783'
        archive = $true
        archiveRoot = 'sherpa-onnx-v1.13.8-win-x64-shared-MT-Release-no-tts'
        extractedBytes = [int64]63623365
    },
    [ordered]@{
        id = 'parakeet-encoder'; folder = 'parakeet-tdt-0.6b-v3-int8'; file = 'encoder.int8.onnx'
        url = "$parakeetRepo/resolve/$parakeetRevision/encoder.int8.onnx"
        size = [int64]652184281; sha256 = 'acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247'; archive = $false
    },
    [ordered]@{
        id = 'parakeet-decoder'; folder = 'parakeet-tdt-0.6b-v3-int8'; file = 'decoder.int8.onnx'
        url = "$parakeetRepo/resolve/$parakeetRevision/decoder.int8.onnx"
        size = [int64]11845275; sha256 = '179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e'; archive = $false
    },
    [ordered]@{
        id = 'parakeet-joiner'; folder = 'parakeet-tdt-0.6b-v3-int8'; file = 'joiner.int8.onnx'
        url = "$parakeetRepo/resolve/$parakeetRevision/joiner.int8.onnx"
        size = [int64]6355277; sha256 = '3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3'; archive = $false
    },
    [ordered]@{
        id = 'parakeet-tokens'; folder = 'parakeet-tdt-0.6b-v3-int8'; file = 'tokens.txt'
        url = "$parakeetRepo/resolve/$parakeetRevision/tokens.txt"
        size = [int64]93939; sha256 = 'd58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d'; archive = $false
    }
)
$allowedHosts = @('github.com', 'huggingface.co')

function Test-YesAnswer {
    param([string]$Prompt)
    (Read-Host $Prompt) -match '^\s*(s|si|sì|y|yes)\s*$'
}

function Get-FileSha256 {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# Verifica dimensione e hash di un file; restituisce un messaggio di errore o $null se valido.
function Test-ManifestFile {
    param([string]$Path, $Entry)
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -ne $Entry.size) { return ("dimensione {0} B, attesa {1} B" -f $length, $Entry.size) }
    $hash = Get-FileSha256 $Path
    if ($hash -ne $Entry.sha256) { return ("SHA-256 {0}, atteso {1}" -f $hash, $Entry.sha256) }
    $null
}

# Scarica in streaming su un file .partial nella cartella di destinazione, senza superare la dimensione attesa.
function Invoke-ManifestDownload {
    param($Entry, [string]$PartialPath, $Client)
    $response = $Client.GetAsync($Entry.url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    try {
        if (-not $response.IsSuccessStatusCode) { throw ("HTTP {0} per {1}" -f [int]$response.StatusCode, $Entry.url) }
        if ($response.RequestMessage.RequestUri.Scheme -ne 'https') { throw 'Redirect verso una connessione non HTTPS: interrotto.' }
        $declared = $response.Content.Headers.ContentLength
        if ($null -ne $declared -and $declared -ne $Entry.size) {
            throw ("Il server dichiara {0} B, attesi {1} B: interrotto prima del download." -f $declared, $Entry.size)
        }
        $source = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $target = New-Object IO.FileStream($PartialPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $buffer = New-Object byte[] (1MB)
            [int64]$total = 0
            $nextReport = 0
            while (($read = $source.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $total += $read
                if ($total -gt $Entry.size) { throw 'Ricevuti più byte del previsto: interrotto.' }
                $target.Write($buffer, 0, $read)
                $percent = [int](100 * $total / $Entry.size)
                if ($percent -ge $nextReport) {
                    Write-Progress -Activity "Download $($Entry.file)" -Status ("{0:N1} / {1:N1} MB" -f ($total / 1MB), ($Entry.size / 1MB)) -PercentComplete $percent
                    $nextReport = $percent + 5
                }
            }
        }
        finally {
            $target.Dispose()
            $source.Dispose()
            Write-Progress -Activity "Download $($Entry.file)" -Completed
        }
    }
    finally {
        $response.Dispose()
    }
}

# Controlla che le voci dell'archivio stiano tutte sotto la cartella radice attesa.
function Assert-SafeArchive {
    param([string]$TarPath, [string]$ArchivePath, [string]$ExpectedRoot)
    $entries = @(& $TarPath -tjf $ArchivePath)
    if ($LASTEXITCODE -ne 0) { throw 'Impossibile leggere l''elenco dell''archivio.' }
    foreach ($name in $entries) {
        $normalized = $name -replace '\\', '/'
        if ($normalized.StartsWith('/') -or $normalized -match '^[A-Za-z]:' -or $normalized -match '(^|/)\.\.(/|$)' -or
            -not ($normalized -eq $ExpectedRoot -or $normalized.StartsWith("$ExpectedRoot/"))) {
            throw "Voce dell'archivio non ammessa: $name"
        }
    }
    $entries.Count
}

# --- Controlli preliminari sulla destinazione -----------------------------------------------
$root = [IO.Path]::GetFullPath($ModelsRoot)
$driveRoot = [IO.Path]::GetPathRoot($root)
if ($env:SystemDrive -and $driveRoot.TrimEnd('\').ToUpperInvariant() -eq $env:SystemDrive.TrimEnd('\').ToUpperInvariant()) {
    throw "La cartella $root è sull'unità di sistema ($env:SystemDrive): scelta rifiutata."
}
$drive = New-Object IO.DriveInfo($driveRoot)
if (-not $drive.IsReady) { throw "Unità $driveRoot non disponibile (disco esterno scollegato?)." }

$downloadBytes = ($manifest | ForEach-Object { $_.size } | Measure-Object -Sum).Sum
$extractBytes = $(if ($Extract) { ($manifest | Where-Object { $_.archive } | ForEach-Object { $_.extractedBytes } | Measure-Object -Sum).Sum } else { 0 })
$requiredBytes = $downloadBytes + $extractBytes + 100MB
$freeBytes = $drive.AvailableFreeSpace

Write-Output 'Quick Pilot M0-B, passo 1: file previsti'
foreach ($e in $manifest) {
    Write-Output ("  - {0}\{1}  {2:N0} B  sha256 {3}" -f $e.folder, $e.file, $e.size, $e.sha256)
    Write-Output ("      {0}" -f $e.url)
}
Write-Output ("Destinazione: {0}" -f $root)
Write-Output ("Totale download: {0:N1} MB; estrazione: {1}; spazio richiesto (con margine): {2:N1} MB; libero: {3:N1} MB" -f
    ($downloadBytes / 1MB), $(if ($Extract) { '{0:N1} MB' -f ($extractBytes / 1MB) } else { 'no' }), ($requiredBytes / 1MB), ($freeBytes / 1MB))

if ($DryRun) {
    Write-Output 'DryRun: nessuna cartella creata e nessun accesso alla rete.'
    return
}
if ($freeBytes -lt $requiredBytes) { throw 'Spazio libero insufficiente sull''unità di destinazione.' }
if (-not (Test-YesAnswer 'Procedere con download e verifica di questi file? (s/n)')) {
    Write-Output 'Annullato: nessun file scaricato.'
    return
}

# --- Download e verifica, un file alla volta ------------------------------------------------
foreach ($e in $manifest) {
    $hostName = ([Uri]$e.url).Host
    if ($allowedHosts -notcontains $hostName) { throw "Host non ammesso nel manifest: $hostName" }
}

Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $true
$client = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromMinutes(60)
$client.DefaultRequestHeaders.UserAgent.ParseAdd('QuickPilot-M0/1.0')

$verified = @()
try {
    foreach ($e in $manifest) {
        $folder = Join-Path $root $e.folder
        if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
        $finalPath = Join-Path $folder $e.file
        $partialPath = "$finalPath.partial"

        if (Test-Path -LiteralPath $finalPath) {
            $problem = Test-ManifestFile $finalPath $e
            if ($null -eq $problem) {
                Write-Output ("[OK] {0}: già presente e verificato." -f $e.file)
                $verified += $e
                continue
            }
            if (-not (Test-YesAnswer ("{0} esiste ma non corrisponde ({1}). Sostituirlo? (s/n)" -f $finalPath, $problem))) {
                throw "Interrotto: $finalPath non è stato modificato."
            }
            Remove-Item -LiteralPath $finalPath
        }
        if (Test-Path -LiteralPath $partialPath) {
            if (-not (Test-YesAnswer ("Trovato un download parziale {0}. Eliminarlo e riscaricare? (s/n)" -f $partialPath))) {
                throw "Interrotto: $partialPath non è stato modificato."
            }
            Remove-Item -LiteralPath $partialPath
        }

        Write-Output ("Scarico {0} ..." -f $e.file)
        try {
            Invoke-ManifestDownload -Entry $e -PartialPath $partialPath -Client $client
            $problem = Test-ManifestFile $partialPath $e
            if ($null -ne $problem) { throw ("Verifica fallita per {0}: {1}" -f $e.file, $problem) }
        }
        catch {
            # Il file parziale è stato creato da questo script: lo si rimuove per non lasciare dati non verificati.
            if (Test-Path -LiteralPath $partialPath) { Remove-Item -LiteralPath $partialPath }
            throw
        }
        Move-Item -LiteralPath $partialPath -Destination $finalPath
        Write-Output ("[OK] {0}: dimensione e SHA-256 verificati." -f $e.file)
        $verified += $e
    }
}
finally {
    $client.Dispose()
}

# --- Estrazione facoltativa dell'archivio verificato ----------------------------------------
if ($Extract) {
    $tarPath = $(if ($env:SystemRoot) { Join-Path $env:SystemRoot 'System32\tar.exe' } else { (Get-Command tar).Source })
    if (-not (Test-Path -LiteralPath $tarPath)) { throw "tar non trovato in $tarPath." }
    foreach ($e in ($manifest | Where-Object { $_.archive })) {
        $folder = Join-Path $root $e.folder
        $archivePath = Join-Path $folder $e.file
        $problem = Test-ManifestFile $archivePath $e
        if ($null -ne $problem) { throw "Archivio non valido, estrazione annullata: $problem" }
        $target = Join-Path $folder $e.archiveRoot
        if (Test-Path -LiteralPath $target) {
            Write-Output ("Cartella già presente, estrazione saltata (nessuna sovrascrittura): {0}" -f $target)
            continue
        }
        $count = Assert-SafeArchive -TarPath $tarPath -ArchivePath $archivePath -ExpectedRoot $e.archiveRoot
        & $tarPath -xjf $archivePath -C $folder
        if ($LASTEXITCODE -ne 0) { throw "Estrazione fallita per $($e.file)." }
        Write-Output ("[OK] Estratte {0} voci in {1}. Nessun programma è stato eseguito." -f $count, $target)
    }
}

# Registro locale della verifica (resta su D:, fuori dal repository).
$log = [ordered]@{
    step           = 'M0-B passo 1'
    verifiedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
    parakeetRevision = $parakeetRevision
    files          = @($verified | ForEach-Object { [ordered]@{ path = "$($_.folder)\$($_.file)"; size = $_.size; sha256 = $_.sha256 } })
    extracted      = [bool]$Extract
}
$logPath = Join-Path $root ('m0-step1-verified-{0}.json' -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
[IO.File]::WriteAllText($logPath, ($log | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
Write-Output ("Completato. Registro della verifica: {0}" -f $logPath)
