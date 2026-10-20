# Strumenti M0

Strumenti **usa e getta** per la fase M0 di Quick Pilot. Non sono codice di prodotto.

Regole comuni:
- Si eseguono con **Windows PowerShell 5.1** (`powershell.exe`), da utente standard. Non serve né viene installato un .NET SDK.
- Nessuna rete, nessuna installazione, nessuna modifica di permessi o impostazioni.
- I risultati delle prove B2–B9 vanno in **`D:\QuickPilotM0\results`** (scelta dell'utente), fuori dal repository. Si può cambiare con `-OutputDir`. Gli strumenti si fermano se l'unità non è collegata o lo spazio è insufficiente, e avvisano sotto i 10 GB. L'inventario B1 resta in `local-data\` (escluso da Git).
- I file prodotti restano locali. Se li condividi, controllali prima.

| Prova | Script | Cosa fa |
|---|---|---|
| B1 | `Get-QuickPilotInventory.ps1` | Inventario di hardware, toolchain e permessi in sola lettura |
| B3/B4 prep | `Test-QuickPilotMicrophone.ps1` | Elenca i microfoni, fa scegliere esplicitamente il dispositivo e misura parlato, rumore, SNR e saturazione (l'audio non viene salvato) |
| B2 | `Test-QuickPilotTts.ps1` | Elenca le voci italiane OneCore, misura la sintesi, riproduce la frase e chiede se la voce è davvero italiana |
| B5 | `Measure-QuickPilotLaunch.ps1` | Tempi di avvio (dispatch e finestra visibile) di notepad, Steam, Discord e Spotify |
| B9 | `Measure-QuickPilotResources.ps1` | Campiona RAM, CPU, GPU e i processi indicati |
| B4 passo 1 | `Get-QuickPilotM0Models.ps1` | Scarica **solo** sherpa-onnx CPU e Parakeet v3 int8 in `D:\QuickPilotM0\models`, verifica dimensione e SHA-256, estrae solo con `-Extract`, non esegue nulla. Provare prima con `-DryRun` |

## Ordine consigliato

```powershell
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

## Limiti noti

- **B5:** misura solo la parte di sistema (dispatch e finestra), non il riconoscimento vocale, che fa parte di B3/B4. Se l'app è già aperta la misura viene saltata. Per Steam, Discord e Spotify lo strumento non chiude mai l'app.
- **B9:** finché non esistono prototipi di Quick Pilot misura il budget disponibile, non il consumo di Quick Pilot.
- **Verifiche:** gli script sono stati controllati per sintassi e con PSScriptAnalyzer e le funzioni comuni sono state provate. **Su Windows non sono ancora stati eseguiti:** la prima esecuzione sul PC è anche il loro collaudo.

## Prossimi strumenti (dopo la conferma della cartella per i modelli)

- **B3/B4:** benchmark della parola di attivazione e dell'ASR. Richiedono download di modelli di centinaia di MB. Partiranno solo dopo che avrai scelto la cartella, per esempio su D:, e approvato il download. Il microfono, per esempio il Katana V2X, verrà selezionato esplicitamente e non preso dal dispositivo predefinito.
- **B6/B7/B8:** impatto in gioco, estensione Chrome, packaging.
