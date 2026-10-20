<#
.SYNOPSIS
    M0-B, passo 2: scarica e verifica whisper.cpp v1.8.3 (Windows x64, CPU) e il modello
    ggml-large-v3-turbo-q5_0 per il confronto con Parakeet.

.DESCRIPTION
    Strumento usa e getta per M0, non codice di prodotto. Punto d'ingresso dedicato al passo 2:
    usa lo stesso motore, già provato sul PC per il passo 1, di Get-QuickPilotM0Models.ps1 -Step 2,
    con tutte le sue garanzie:
    - manifest fisso con URL immutabili (release v1.8.3 su GitHub, revisione Hugging Face fissata),
      dimensione, SHA-256 e licenza di codice o pesi per ogni file;
    - -DryRun senza rete, senza cartelle e senza file;
    - conferma esplicita prima di scaricare; redirect solo HTTPS verso host ufficiali in allowlist;
    - file .partial su D:, nessuna sovrascrittura senza chiedere, nessuna scrittura sull'unità di sistema;
    - nessuna installazione e nessuna esecuzione dei programmi scaricati (-Extract usa solo tar.exe).
    Prerequisito non installato dallo strumento: Visual C++ Redistributable 2015-2022 x64
    (msvcp140, vcruntime140, vcruntime140_1, vcomp140), verificato poi dal runner.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotWhisperModels.ps1 -DryRun
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotWhisperModels.ps1 -Extract
#>
[CmdletBinding()]
param(
    [string]$ModelsRoot = 'D:\QuickPilotM0\models',
    [switch]$Extract,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Get-QuickPilotM0Models.ps1') -Step 2 -ModelsRoot $ModelsRoot -Extract:$Extract -DryRun:$DryRun
