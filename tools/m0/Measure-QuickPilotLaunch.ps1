<#
.SYNOPSIS
    M0-B, prova B5: misura i tempi di avvio delle app (dispatch e finestra visibile).

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto.
    Misura, per un target scelto da un elenco fisso (nessun comando libero):
    - dispatchMs: tempo per inoltrare l'avvio al sistema (la parte che Quick Pilot controlla);
    - visibleMs:  tempo fino alla prima finestra principale di un processo nuovo del target
                  (dipende dall'app esterna).
    Regole di sicurezza:
    - Se il target è già in esecuzione la misura viene saltata: lo strumento non chiude mai
      app che non ha avviato.
    - Solo per notepad (baseline) le ripetizioni chiudono le finestre avviate dallo strumento.
      Per Steam, Discord e Spotify si misura un avvio per esecuzione; l'app va chiusa a mano.
    - Chiede conferma prima di aprire un'app (salvo -Force).
    Non misura il riconoscimento vocale: quella parte è nelle prove B3/B4.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotLaunch.ps1 -Target notepad -Repetitions 10
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotLaunch.ps1 -Target steam
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('notepad', 'steam', 'discord', 'spotify')][string]$Target,
    [ValidateRange(1, 30)][int]$Repetitions = 1,
    [ValidateRange(5, 180)][int]$TimeoutSeconds = 60,
    [string]$OutputDir = 'D:\QuickPilotM0\results',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
Assert-M0WindowsPowerShell
$OutputDir = Resolve-M0OutputDir -Path $OutputDir -RequiredMB 5

# Catalogo fisso: come avviare il target e quali processi ne possiedono la finestra.
$catalog = @{
    notepad = @{ launch = 'notepad.exe';  processes = @('notepad');                  closable = $true }
    steam   = @{ launch = 'steam://open/main'; processes = @('steam', 'steamwebhelper'); closable = $false }
    discord = @{ launch = 'discord://';   processes = @('discord');                  closable = $false }
    spotify = @{ launch = 'spotify:';     processes = @('spotify');                  closable = $false }
}
$entry = $catalog[$Target]
if (-not $entry.closable -and $Repetitions -gt 1) {
    Write-Warning "Per $Target si misura un solo avvio per esecuzione (lo strumento non chiude app di terze parti)."
    $Repetitions = 1
}

function Get-TargetProcess {
    @(Get-Process -Name $entry.processes -ErrorAction SilentlyContinue)
}

$samples = @()
$skipped = $null
for ($i = 1; $i -le $Repetitions; $i++) {
    $before = Get-TargetProcess
    if ($before.Count -gt 0) {
        $skipped = "$Target è già in esecuzione: chiuderlo manualmente per misurare un avvio da zero."
        Write-Warning $skipped
        break
    }
    if ($i -eq 1 -and -not (Confirm-M0Action -Message "Verrà aperto $Target ($Repetitions volte)." -Force:$Force)) {
        $skipped = 'Annullato dall''utente.'
        break
    }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    Start-Process -FilePath $entry.launch
    $dispatchMs = $sw.Elapsed.TotalMilliseconds

    $visibleMs = $null
    $windowPids = @()
    $deadline = [TimeSpan]::FromSeconds($TimeoutSeconds)
    while ($sw.Elapsed -lt $deadline) {
        $withWindow = @(Get-TargetProcess | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
        if ($withWindow.Count -gt 0) {
            $visibleMs = $sw.Elapsed.TotalMilliseconds
            $windowPids = @($withWindow | ForEach-Object { $_.Id })
            break
        }
        Start-Sleep -Milliseconds 25
    }
    $sw.Stop()

    $samples += [ordered]@{
        run        = $i
        dispatchMs = [math]::Round($dispatchMs, 1)
        visibleMs  = $(if ($null -ne $visibleMs) { [math]::Round($visibleMs, 1) } else { $null })
        timedOut   = ($null -eq $visibleMs)
    }
    Write-Output ("Run {0}: dispatch {1:N1} ms, finestra {2}" -f $i, $dispatchMs,
        $(if ($null -ne $visibleMs) { '{0:N1} ms' -f $visibleMs } else { "non vista entro $TimeoutSeconds s" }))

    if ($entry.closable) {
        # Chiude solo le finestre del target avviate da questa misura.
        foreach ($procId in $windowPids) {
            $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($p) { $null = $p.CloseMainWindow(); $null = $p.WaitForExit(5000) }
        }
        Start-Sleep -Milliseconds 500
    }
}

$dispatch = [double[]]@($samples | ForEach-Object { $_.dispatchMs })
$visible = [double[]]@($samples | Where-Object { $null -ne $_.visibleMs } | ForEach-Object { $_.visibleMs })
$report = [ordered]@{
    test             = 'B5-launch'
    collectedAtUtc   = (Get-Date).ToUniversalTime().ToString('o')
    target           = $Target
    skippedReason    = $skipped
    dispatchMs       = Get-M0Summary $dispatch
    visibleMs        = Get-M0Summary $visible
    dispatchTargetMs = 2000
    samples          = $samples
}
$path = Save-M0Result -Object $report -OutputDir $OutputDir -Name "b5-launch-$Target"
Write-Output ("Risultati salvati in: {0}" -f $path)
