<#
.SYNOPSIS
    M0-B, prova B9: campiona l'uso di risorse del sistema (e facoltativamente di processi scelti).

.DESCRIPTION
    Strumento di benchmark usa e getta, non codice di prodotto.
    Campiona per la durata indicata:
    - RAM disponibile e CPU totale (classi CIM, indipendenti dalla lingua di Windows);
    - memoria e utilizzo GPU tramite nvidia-smi, se presente;
    - working set e memoria privata dei processi indicati con -ProcessName.
    Serve a stabilire il budget disponibile a riposo e in gioco, e in seguito a misurare
    i prototipi M0-B (host, ASR). Sola lettura: nessuna rete, nessuna modifica di sistema.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotResources.ps1 -Seconds 60 -Label riposo
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotResources.ps1 -Seconds 300 -Label gioco -ProcessName steam,discord
#>
[CmdletBinding()]
param(
    [ValidateRange(5, 3600)][int]$Seconds = 60,
    [ValidateRange(250, 10000)][int]$IntervalMs = 1000,
    [ValidatePattern('^[\w\-\.]+$')][string[]]$ProcessName = @(),
    [ValidatePattern('^[\w\-]+$')][string]$Label = 'riposo',
    [string]$OutputDir = 'D:\QuickPilotM0\results'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'M0Common.ps1')
Assert-M0WindowsPowerShell
$OutputDir = Resolve-M0OutputDir -Path $OutputDir -RequiredMB 5

$smi = Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue
$totalRamMB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB, 0)

$availableMB = @(); $cpuPercent = @(); $gpuUsedMB = @(); $gpuUtil = @()
$perProcess = @{}
foreach ($name in $ProcessName) { $perProcess[$name] = @{ workingSetMB = @(); privateMB = @() } }

Write-Output ("Campionamento per {0} s (etichetta: {1})..." -f $Seconds, $Label)
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
    $availableMB += [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB, 0)
    $cpuPercent += [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime

    if ($smi) {
        $line = & $smi.Source '--query-gpu=memory.used,utilization.gpu' '--format=csv,noheader,nounits' 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and $line) {
            $f = "$line" -split ',\s*'
            $gpuUsedMB += [double]$f[0]
            $gpuUtil += [double]$f[1]
        }
    }

    foreach ($name in $ProcessName) {
        $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if ($procs.Count -gt 0) {
            $perProcess[$name].workingSetMB += [math]::Round((($procs | Measure-Object WorkingSet64 -Sum).Sum) / 1MB, 1)
            $perProcess[$name].privateMB += [math]::Round((($procs | Measure-Object PrivateMemorySize64 -Sum).Sum) / 1MB, 1)
        }
    }
    Start-Sleep -Milliseconds $IntervalMs
}

$processReport = [ordered]@{}
foreach ($name in $ProcessName) {
    $processReport[$name] = [ordered]@{
        workingSetMB = Get-M0Summary ([double[]]$perProcess[$name].workingSetMB)
        privateMB    = Get-M0Summary ([double[]]$perProcess[$name].privateMB)
    }
}

$report = [ordered]@{
    test           = 'B9-resources'
    collectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    label          = $Label
    seconds        = $Seconds
    intervalMs     = $IntervalMs
    totalRamMB     = $totalRamMB
    availableRamMB = Get-M0Summary ([double[]]$availableMB)
    cpuPercent     = Get-M0Summary ([double[]]$cpuPercent)
    gpuMemoryUsedMB = $(if ($smi) { Get-M0Summary ([double[]]$gpuUsedMB) } else { 'nvidia-smi non trovato' })
    gpuUtilPercent = $(if ($smi) { Get-M0Summary ([double[]]$gpuUtil) } else { 'nvidia-smi non trovato' })
    processes      = $processReport
}
$path = Save-M0Result -Object $report -OutputDir $OutputDir -Name "b9-resources-$Label"
Write-Output ($report | ConvertTo-Json -Depth 6)
Write-Output ("Risultati salvati in: {0}" -f $path)
