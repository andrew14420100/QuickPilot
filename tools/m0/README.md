# Strumenti M0

Strumenti **usa e getta** per la fase M0 di Quick Pilot. Non sono codice di prodotto.

Regole comuni:
- Si eseguono con **Windows PowerShell 5.1** (`powershell.exe`), da utente standard. Non serve né viene installato un .NET SDK.
- Nessuna rete, nessuna installazione, nessuna modifica di permessi o impostazioni.
- I risultati delle prove B2–B9 vanno in **`D:\QuickPilotM0\results`** (scelta dell'utente), fuori dal repository. Si può cambiare con `-OutputDir`. Gli strumenti si fermano se l'unità non è collegata o lo spazio è insufficiente, e avvisano sotto i 10 GB. L'inventario B1 resta in `local-data\` (escluso da Git).
- I file prodotti restano locali. Se li condividi, controllali prima.

| Prova | Script | Cosa fa |
|---|---|---|
| Self-test | `Test-M0Common.ps1` | Controlla le funzioni comuni con 0, 1 e molti elementi in StrictMode, con processi finti. Da eseguire in Windows PowerShell 5.1 prima dei benchmark |
| B1 | `Get-QuickPilotInventory.ps1` | Inventario di hardware, toolchain e permessi in sola lettura |
| B3/B4 prep | `Test-QuickPilotMicrophone.ps1` | Elenca i microfoni, fa scegliere esplicitamente il dispositivo e misura parlato, rumore, SNR e saturazione (l'audio non viene salvato) |
| B2 | `Test-QuickPilotTts.ps1` | Elenca le voci italiane OneCore, misura la sintesi, riproduce la frase e chiede se la voce è davvero italiana |
| B5 | `Measure-QuickPilotLaunch.ps1` | Tempi di avvio (dispatch e finestra visibile) di notepad, Steam, Discord e Spotify |
| B9 | `Measure-QuickPilotResources.ps1` | Campiona RAM, CPU, GPU e i processi indicati |
| B4 passo 1 | `Get-QuickPilotM0Models.ps1` | Scarica **solo** sherpa-onnx CPU e Parakeet v3 int8 in `D:\QuickPilotM0\models`. Verifica dimensione e SHA-256 e segue i redirect solo verso host ammessi (`github.com`, `huggingface.co`, `*.githubusercontent.com`, `*.hf.co`). Estrae solo con `-Extract` e non esegue nulla. Provare prima con `-DryRun` |
| B4 campioni | `New-QuickPilotAsrSamples.ps1` | Genera 10 comandi italiani sintetici con le voci OneCore (nessuna voce dell'utente) in `D:\QuickPilotM0\results\b4-samples` |
| B4 | `Measure-QuickPilotAsr.ps1` | Riverifica il modello, poi esegue sherpa-onnx-offline (solo CPU, argomenti fissi) su ogni campione. Riporta testo, WER, riconoscimento di «quick pilot», caricamento e decodifica |
| B4 passo 2 | `Get-QuickPilotWhisperModels.ps1` | Scarica **solo** whisper.cpp v1.8.3 (CPU, Windows x64) e `ggml-large-v3-turbo-q5_0.bin`. Stesso motore e stesse garanzie del passo 1 (`Get-QuickPilotM0Models.ps1 -Step 2`) |
| B4 Whisper | `Measure-QuickPilotWhisper.ps1` | Verifica VC++ Redistributable e modello, poi esegue whisper-cli (solo CPU, `-ng`, argomenti fissi) sugli stessi campioni. Gli errori vengono registrati per singolo campione e non sono mai contati come validi |
| B4 confronto | `Compare-QuickPilotAsr.ps1` | Confronta gli ultimi risultati Parakeet e Whisper per motore e per voce: WER, corrispondenze esatte, «quick pilot», latenza senza caricamento, caricamento |

## Ordine consigliato

```powershell
# 0. Self-test in Windows PowerShell 5.1 (nessun processo reale, file temporanei su D:)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-M0Common.ps1

# B2: voci TTS (riproduce audio dalle casse o dalle cuffie predefinite)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-QuickPilotTts.ps1

# Microfono: scegli esplicitamente il Katana V2X (non lo Steam Streaming Microphone)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Test-QuickPilotMicrophone.ps1

# B5: baseline con notepad (10 avvii, chiude solo le finestre che apre)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotLaunch.ps1 -Target notepad -Repetitions 10

# B5: un avvio per app, con l'app chiusa prima; ripetere più volte (anche dopo un riavvio)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotLaunch.ps1 -Target steam
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotLaunch.ps1 -Target discord
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotLaunch.ps1 -Target spotify

# B9: risorse a riposo (60 s) e durante una sessione di gioco (5 min)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotResources.ps1 -Seconds 60 -Label riposo
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotResources.ps1 -Seconds 300 -Label gioco
```

## B4: sequenza completa (dopo i test leggeri)

```powershell
# 1. Piano senza rete, poi download con verifica ed estrazione (~694 MB su D:)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotM0Models.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotM0Models.ps1 -Extract
# 2. Campioni sintetici non personali
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\New-QuickPilotAsrSamples.ps1
# 3. Benchmark ASR su CPU
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotAsr.ps1
```

## B4 passo 2: confronto Whisper (dopo il consenso al download)

```powershell
# 1. Piano senza rete: file, dimensioni, hash, licenze, spazio richiesto
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotWhisperModels.ps1 -DryRun
# 2. Solo dopo aver controllato il piano e dato il consenso: download verificato ed estrazione
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotWhisperModels.ps1 -Extract
# 3. Benchmark Whisper sugli stessi 20 campioni (stessi thread di Parakeet per un confronto equo)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Measure-QuickPilotWhisper.ps1 -Threads 4
# 4. Confronto quantitativo Whisper / Parakeet
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Compare-QuickPilotAsr.ps1
```

Prerequisito non installato dagli strumenti: Visual C++ Redistributable 2015-2022 x64 (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, `vcomp140.dll` in System32). Il runner lo verifica e si ferma se manca.

Regole di confronto, identiche per i due motori:
- Normalizzazione: minuscole, punteggiatura rimossa, trattini come spazi.
- I numeri in cifre e in lettere **non** vengono equiparati.
- La latenza esclude il caricamento del modello: per Parakeet è la decodifica riportata da sherpa-onnx, per Whisper è `total` meno `load` di whisper.cpp.
- «quick pilot» viene cercato solo all'inizio del testo trascritto. **Non è un benchmark della parola di attivazione** e non misura i falsi positivi.

## Limiti noti

- **B5:** misura solo la parte di sistema (dispatch e finestra), non il riconoscimento vocale, che fa parte di B3/B4. Se l'app è già aperta la misura viene saltata. Per Steam, Discord e Spotify lo strumento non chiude mai l'app.
- **B9:** finché non esistono prototipi di Quick Pilot misura il budget disponibile, non il consumo di Quick Pilot.
- **Verifiche:** sul PC (Windows PowerShell 5.1) sono stati eseguiti B1, B2, microfono, B5 (Notepad), B9 (riposo), il self-test, il download del passo 1, i campioni B4 e il benchmark Parakeet. Gli strumenti Whisper e il confronto sono stati provati **solo nel cloud Linux** (whisper.cpp v1.8.3 compilato dai sorgenti): il binario Windows di whisper.cpp non è ancora stato eseguito.

## Prossimi strumenti

- **B3:** parola di attivazione, con misura dei falsi positivi su parlato, voice chat e audio di gioco.
- **B6/B7/B8:** impatto in gioco, estensione Chrome, packaging.
- **Voce di risposta:** benchmark della voce personalizzata JARVIS (CosyVoice 3), vedi `docs/M0_TTS_PLAN.md`.
