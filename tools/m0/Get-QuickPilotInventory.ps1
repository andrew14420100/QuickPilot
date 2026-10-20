<#
.SYNOPSIS
    Inventario M0 di Quick Pilot: rileva hardware, toolchain e prerequisiti in sola lettura.

.DESCRIPTION
    Script di supporto alla fase M0 (non è codice di prodotto).
    - Sola lettura: non modifica sistema, registro, file o impostazioni.
    - Nessuna rete, nessuna elevazione richiesta (eseguire come utente standard).
    - Non raccoglie nome del PC, nome utente, numeri di serie o percorsi personali.
    Il risultato viene stampato a schermo e salvato in .\local-data\m0-inventory.json
    (cartella esclusa da Git). Rivedere il file prima di condividerlo.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotInventory.ps1
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Get-Location) 'local-data\m0-inventory.json')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Esegue un blocco e restituisce $null (con avviso) invece di interrompere l'inventario.
function Invoke-Safely {
    param([string]$Label, [scriptblock]$Block)
    try { & $Block }
    catch {
        Write-Warning ("{0}: non disponibile ({1})" -f $Label, $_.Exception.Message)
        $null
    }
}

# Esegue un eseguibile se presente nel PATH e restituisce l'output come righe di testo.
function Invoke-ToolIfPresent {
    param([string]$Name, [string[]]$Arguments)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    $output = & $cmd.Source @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    @($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
}

function Get-FileVersionIfPresent {
    param([string[]]$Paths)
    foreach ($p in $Paths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            return (Get-Item -LiteralPath $p).VersionInfo.ProductVersion
        }
    }
    $null
}

$inventory = [ordered]@{
    schema        = 'quickpilot-m0-inventory/1'
    collectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
}

$inventory.os = Invoke-Safely 'Sistema operativo' {
    $os = Get-CimInstance Win32_OperatingSystem
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    [ordered]@{
        caption        = $os.Caption
        version        = $os.Version
        build          = $os.BuildNumber
        ubr            = $cv.UBR
        displayVersion = $cv.DisplayVersion
        architecture   = $os.OSArchitecture
        language       = (Get-Culture).Name
    }
}

$inventory.cpu = Invoke-Safely 'CPU' {
    @(Get-CimInstance Win32_Processor | ForEach-Object {
        [ordered]@{
            name              = $_.Name.Trim()
            cores             = $_.NumberOfCores
            logicalProcessors = $_.NumberOfLogicalProcessors
            maxClockMHz       = $_.MaxClockSpeed
        }
    })
}

$inventory.memory = Invoke-Safely 'RAM' {
    $total = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $free = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory * 1KB
    [ordered]@{
        totalGB     = [math]::Round($total / 1GB, 1)
        availableGB = [math]::Round($free / 1GB, 1)
    }
}

$inventory.gpu = Invoke-Safely 'GPU' {
    # AdapterRAM di WMI è limitato a 4 GB: la VRAM reale viene da nvidia-smi quando presente.
    $wmi = @(Get-CimInstance Win32_VideoController | ForEach-Object {
        [ordered]@{ name = $_.Name; driverVersion = $_.DriverVersion; driverDate = "$($_.DriverDate)" }
    })
    $nvidia = $null
    $smi = Invoke-ToolIfPresent 'nvidia-smi' @(
        '--query-gpu=name,driver_version,memory.total,memory.used,temperature.gpu,power.draw',
        '--format=csv,noheader,nounits')
    if ($smi) {
        $nvidia = @($smi | ForEach-Object {
            $f = $_ -split ',\s*'
            [ordered]@{
                name          = $f[0]
                driverVersion = $f[1]
                memoryTotalMB = $f[2]
                memoryUsedMB  = $f[3]
                temperatureC  = $f[4]
                powerDrawW    = $f[5]
            }
        })
    }
    [ordered]@{ wmi = $wmi; nvidiaSmi = $nvidia }
}

$inventory.disks = Invoke-Safely 'Dischi' {
    $physical = @(Get-PhysicalDisk | ForEach-Object {
        [ordered]@{
            model     = $_.FriendlyName
            mediaType = "$($_.MediaType)"
            busType   = "$($_.BusType)"
            sizeGB    = [math]::Round($_.Size / 1GB, 0)
        }
    })
    $volumes = @(Get-Volume | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter | ForEach-Object {
        [ordered]@{
            drive      = "$($_.DriveLetter):"
            fileSystem = $_.FileSystem
            sizeGB     = [math]::Round($_.Size / 1GB, 1)
            freeGB     = [math]::Round($_.SizeRemaining / 1GB, 1)
        }
    })
    [ordered]@{ physical = $physical; volumes = $volumes }
}

$inventory.audio = Invoke-Safely 'Audio' {
    $devices = @(Get-CimInstance Win32_SoundDevice | ForEach-Object {
        [ordered]@{ name = $_.Name; status = $_.Status }
    })
    # Dispositivi di acquisizione attivi registrati da MMDevices (sola lettura).
    $captureRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture'
    $capture = @()
    if (Test-Path $captureRoot) {
        $capture = @(Get-ChildItem $captureRoot | ForEach-Object {
            $state = (Get-ItemProperty $_.PSPath).DeviceState
            $propsPath = Join-Path $_.PSPath 'Properties'
            if ($state -eq 1 -and (Test-Path $propsPath)) {
                $p = Get-ItemProperty $propsPath
                # {a45c254e-...},2 = nome endpoint; {b3f8fa53-...},6 = nome interfaccia.
                $endpoint = $p.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
                $iface = $p.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
                [ordered]@{ endpoint = $endpoint; device = $iface }
            }
        } | Where-Object { $_ })
    }
    [ordered]@{ soundDevices = $devices; activeCaptureEndpoints = $capture }
}

$inventory.speech = Invoke-Safely 'Voci TTS' {
    $voices = @()
    $stores = [ordered]@{
        OneCore = 'HKLM:\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens'
        SAPI    = 'HKLM:\SOFTWARE\Microsoft\Speech\Voices\Tokens'
    }
    foreach ($store in $stores.Keys) {
        $root = $stores[$store]
        if (Test-Path $root) {
            $voices += @(Get-ChildItem $root | ForEach-Object {
                $attrs = Join-Path $_.PSPath 'Attributes'
                if (Test-Path $attrs) {
                    $a = Get-ItemProperty $attrs
                    [ordered]@{ store = $store; name = $a.Name; language = $a.Language }
                }
            } | Where-Object { $_ })
        }
    }
    [ordered]@{ ttsVoices = $voices }
}

$inventory.toolchain = Invoke-Safely 'Toolchain' {
    [ordered]@{
        dotnetSdks     = Invoke-ToolIfPresent 'dotnet' @('--list-sdks')
        dotnetRuntimes = Invoke-ToolIfPresent 'dotnet' @('--list-runtimes')
        git            = Invoke-ToolIfPresent 'git' @('--version')
        winget         = Invoke-ToolIfPresent 'winget' @('--version')
        node           = Invoke-ToolIfPresent 'node' @('--version')
        python         = Invoke-ToolIfPresent 'python' @('--version')
        powershell     = $PSVersionTable.PSVersion.ToString()
    }
}

$inventory.browsers = Invoke-Safely 'Browser' {
    $pf = $env:ProgramFiles
    $pf86 = ${env:ProgramFiles(x86)}
    $local = $env:LOCALAPPDATA
    [ordered]@{
        chrome  = Get-FileVersionIfPresent @("$pf\Google\Chrome\Application\chrome.exe",
                                             "$pf86\Google\Chrome\Application\chrome.exe",
                                             "$local\Google\Chrome\Application\chrome.exe")
        edge    = Get-FileVersionIfPresent @("$pf86\Microsoft\Edge\Application\msedge.exe",
                                             "$pf\Microsoft\Edge\Application\msedge.exe")
        firefox = Get-FileVersionIfPresent @("$pf\Mozilla Firefox\firefox.exe",
                                             "$pf86\Mozilla Firefox\firefox.exe")
        # Numero di profili Chrome (solo conteggio, nessun nome o contenuto).
        chromeProfileCount = $(
            $ud = Join-Path $local 'Google\Chrome\User Data'
            if (Test-Path $ud) { @(Get-ChildItem $ud -Directory | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' }).Count } else { 0 })
    }
}

$inventory.apps = Invoke-Safely 'App prioritarie' {
    # Solo presenza (true/false) delle app indicate nei requisiti; nessun dato di account.
    $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    [ordered]@{
        steam          = [bool]$steamPath
        steamProtocol  = Test-Path 'Registry::HKEY_CLASSES_ROOT\steam'
        discord        = Test-Path (Join-Path $env:LOCALAPPDATA 'Discord')
        discordProtocol = Test-Path 'Registry::HKEY_CLASSES_ROOT\discord'
        spotifyDesktop = Test-Path (Join-Path $env:APPDATA 'Spotify\Spotify.exe')
        spotifyStore   = [bool](Get-AppxPackage -Name 'SpotifyAB.SpotifyMusic' -ErrorAction SilentlyContinue)
        whatsappStore  = [bool](Get-AppxPackage -Name '*WhatsAppDesktop*' -ErrorAction SilentlyContinue)
        telegramStore  = [bool](Get-AppxPackage -Name '*TelegramDesktop*' -ErrorAction SilentlyContinue)
        epic           = Test-Path 'Registry::HKEY_CLASSES_ROOT\com.epicgames.launcher'
        battlenet      = Test-Path 'Registry::HKEY_CLASSES_ROOT\battlenet'
    }
}

$inventory.permissions = Invoke-Safely 'Permessi' {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $groupSids = @($identity.Groups | ForEach-Object { $_.Value })
    [ordered]@{
        # true se lo script gira in una sessione elevata (atteso: false).
        elevated              = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        # S-1-5-32-544 = Administrators (anche se filtrato da UAC).
        memberOfAdministrators = $groupSids -contains 'S-1-5-32-544'
        # S-1-5-32-559 = Performance Log Users, necessario a PresentMon senza elevazione.
        memberOfPerformanceLogUsers = $groupSids -contains 'S-1-5-32-559'
        executionPolicy       = "$(Get-ExecutionPolicy)"
    }
}

$inventory.gaming = Invoke-Safely 'Impostazioni gaming' {
    $gameBar = Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue
    $hags = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -ErrorAction SilentlyContinue
    $gameModeValue = $null
    if ($gameBar -and ($gameBar.PSObject.Properties.Name -contains 'AutoGameModeEnabled')) { $gameModeValue = $gameBar.AutoGameModeEnabled }
    $hagsValue = $null
    if ($hags -and ($hags.PSObject.Properties.Name -contains 'HwSchMode')) { $hagsValue = $hags.HwSchMode }
    [ordered]@{
        autoGameModeEnabled = $gameModeValue
        hardwareGpuScheduling = $hagsValue
    }
}

$json = $inventory | ConvertTo-Json -Depth 8
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
# UTF-8 senza BOM, leggibile da qualsiasi strumento.
[IO.File]::WriteAllText($OutputPath, $json, (New-Object Text.UTF8Encoding($false)))

Write-Output $json
Write-Output ''
Write-Output "Inventario salvato in: $OutputPath"
Write-Output 'Controlla il contenuto prima di condividerlo.'
