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

# --- Statistiche: 0, 1, molti valori --------------------------------------------------------
Assert-M0Test 'riepilogo: 0 valori' { (Get-M0Summary ([double[]]@())).n -eq 0 }
Assert-M0Test 'riepilogo: 1 valore' { $s = Get-M0Summary ([double[]]@(42)); $s.n -eq 1 -and $s.p95 -eq 42 }
Assert-M0Test 'riepilogo: molti valori' { $s = Get-M0Summary ([double[]](1..20)); $s.n -eq 20 -and $s.p50 -eq 10 -and $s.p95 -eq 19 }

Write-Output ''
Write-Output ("Controlli: {0}, falliti: {1}" -f $script:checks, $script:failures)
if ($script:failures -gt 0) { exit 1 }
