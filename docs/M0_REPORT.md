# M0 — Report di validazione tecnica

Stato: **M0 parte A completata (ricerca e verifica delle fonti)**. **Parte B (misure sul PC reale) da eseguire.**
Data: 2026-10-20. Riferimento: `docs/REQUIREMENTS.md` (approvata), `docs/M0_VALIDATION.md`.

> Regola di lettura: in questo report **nessun valore prestazionale è una misura**. Le misure richiedono il PC di destinazione (Windows 11, RTX 5070 Ti, Katana V2X) e sono pianificate nella §7. Le versioni sono quelle trovate alle fonti indicate e vanno ricontrollate al momento del pin delle dipendenze.

---

## 1. Ambiente delle prove

| Voce | Valore |
|---|---|
| Dove è stata svolta la parte A | Container Linux di Claude Code (cloud), **non** il PC di destinazione |
| Accesso al PC reale | Nessuno: nessun inventario, audio, browser o GPU disponibili da qui |
| Conseguenza | Inventario, benchmark vocali, latenze, impatto in gioco e packaging restano **da eseguire** (§7) |

## 2. Prove realmente eseguite

| Prova | Esito | Note |
|---|---|---|
| Analisi sintattica di `tools/m0/Get-QuickPilotInventory.ps1` (parser PowerShell 7.4.6) | ✅ 0 errori | |
| PSScriptAnalyzer 1.25.0 sullo script | ✅ 0 avvisi dopo le correzioni | corretti `Write-Host` e codifica (BOM necessario per Windows PowerShell 5.1 con testo accentato) |
| Esecuzione di prova dello script su Linux | ✅ termina e scrive il JSON, le sezioni Windows risultano `null` con avviso | verifica solo della gestione errori; **non** sostituisce l'esecuzione su Windows |

Nessun'altra prova è stata eseguita.

## 2b. Esito dell'inventario B1 (eseguito dall'utente su Windows)

Il JSON grezzo resta sul PC e non viene aggiunto al repository. Dati sintetici forniti dall'utente: Windows 11 Pro x64 (build 26300), Ryzen 7 9800X3D, 32 GB di RAM, RTX 5070 Ti 16 GB, Chrome 155 con 2 profili, microfoni SB Katana V2X e Steam Streaming Microphone, voci OneCore Microsoft Cosimo ed Elsa.

Valutazione preliminare (stima, non misura): CPU, RAM e VRAM sono ampiamente sufficienti per ASR locale e per un LLM opzionale di piccole o medie dimensioni. Il vincolo reale è lo **spazio su C:**, quindi modelli e cache vanno su D:. Va però misurata la latenza di caricamento da un disco USB.

Indicazioni rilevanti:

| Voce | Esito | Conseguenza |
|---|---|---|
| .NET SDK | Nessun SDK rilevato, presenti runtime .NET 8. Da confermare con `dotnet --list-sdks` | Gli strumenti M0-B sono script Windows PowerShell 5.1, quindi non serve un SDK. Nessuna installazione automatica |
| Spazio disco | C: sotto i 10 GB liberi; D: disco USB esterno con ampio spazio | Cartelle di modelli, cache e output configurabili (`-OutputDir`), con controllo dello spazio. Nessun modello grande su C: senza una decisione esplicita |
| Voci TTS | Voci italiane OneCore presenti | B2 verifica la lingua all'ascolto, non solo dal codice di lingua |
| Microfoni | Presenti più dispositivi di acquisizione (incluso un microfono virtuale di Steam) | B3/B4 dovranno selezionare il dispositivo in modo esplicito |
| Performance Log Users | Utente già membro | Nessuna azione per PresentMon; da riverificare in B6 |

Correzione allo script: le sezioni della toolchain ora riportano `present`, `exitCode` e `output` in modo esplicito, così «strumento assente» e «nessun SDK» restano distinguibili.

### Bug corretto: `.Count` in Windows PowerShell 5.1

In Windows PowerShell 5.1 con StrictMode, una funzione che restituisce un array di un solo elemento lo «srotola» in uno scalare, che non ha `.Count`. Questo bloccava B5 con un solo processo Notepad.

Correzione alla radice:
- `Get-M0ProcessCount` restituisce sempre un intero; gli altri helper si richiamano solo dentro `@(...)`.
- `Read-M0JsonArray` gestisce anche il caso in cui PS 5.1 restituisce l'array JSON come oggetto unico.
- Controllati tutti gli accessi a `.Count` negli script M0.
- B5 ora si ferma, senza chiusure forzate, se il target resta in esecuzione dopo la chiusura: così un processo Notepad persistente non falsa le misure.
- Nuovo `Test-M0Common.ps1`: 23 controlli su 0, 1 e molti elementi con processi finti. Passano in PowerShell 7.4 su Linux. **In PowerShell 7 il bug originale non si riproduce**, quindi il self-test va eseguito in Windows PowerShell 5.1 sul PC. **Eseguito sul PC in Windows PowerShell 5.1 (Desktop): 25 controlli, 0 falliti**, incluso un campione GPU reale letto da `nvidia-smi` in `System32`.

## 3. Fonti e versioni verificate

| Componente | Stato verificato | Fonte |
|---|---|---|
| .NET 10 | LTS, rilasciato 2025-11-11, supporto fino al **2028-11-14** | [Microsoft .NET support policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core) |
| whisper.cpp | Release recenti 1.8.x–1.9.x, backend CUDA e Vulkan | [GitHub releases](https://github.com/ggml-org/whisper.cpp/releases), [Phoronix](https://www.phoronix.com/news/Whisper-cpp-1.8.3-12x-Perf) |
| Whisper.net (binding .NET) | Runtime 1.9.x su NuGet; pacchetti CUDA (13 / 12) e Vulkan per Windows x64 | [NuGet Cuda.Windows](https://packages.nuget.org/packages/Whisper.net.Runtime.Cuda.Windows), [NuGet Vulkan](https://www.nuget.org/packages/whisper.net.runtime.vulkan) |
| NVIDIA Parakeet TDT 0.6B v3 | ASR multilingue europeo **incluso l'italiano**, licenza **CC-BY-4.0**, export ONNX usabile con sherpa-onnx | [model card ONNX](https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx), [scheda modello](https://www.endorlabs.com/ai-model/nvidia-parakeet-tdt-0-6b-v3) |
| sherpa-onnx | Keyword spotting e ASR, API C#, Windows x64 | [PyPI](https://pypi.org/project/sherpa-onnx/1.10.26), docs k2-fsa.github.io/sherpa/onnx |
| Vosk italiano | Modello rilasciato 2022-09-13; accuratezza riportata inferiore a Whisper (dato di terze parti, non verificato) | [Alpha Cephei news](https://alphacephei.com/en/news.html), [stt.ai](https://stt.ai/transcribe/italian/?lang=ka) |
| openWakeWord | Codice Apache-2.0 (da verificare sul LICENSE); **modelli preaddestrati CC-BY-NC-SA-4.0**; pipeline di addestramento datata e fragile secondo la community | [Hugging Face](https://huggingface.co/davidscripka/openwakeword/raw/main/README.md), [colab 2026](https://github.com/alfiedennen/openwakeword-colab-2026) |
| Picovoice Porcupine | Richiede AccessKey validata online; segnalata la chiusura del free tier al 2026-06-30 (fonte community, pagina prezzi contraddittoria) | [Home Assistant community](https://community.home-assistant.io/t/fyi-picovoice-confirmed-free-tier-accesskeys-will-stop-working-after-june-30-2026/1012744), [Picovoice FAQ](https://picovoice.ai/docs/faq/general) |
| Piper TTS | Voce italiana disponibile; licenza del motore cambiata (fork 1.x GPL, da verificare) e licenze delle voci separate | [tts.ai](https://tts.ai/voices/piper/) |
| Chrome remote debugging | Da **Chrome 136** `--remote-debugging-port` è ignorato sul profilo predefinito; serve `--user-data-dir` non standard | [Chrome for Developers](https://developer.chrome.com/blog/remote-debugging-port) |
| Chrome Native Messaging | Registrazione per utente sotto `HKCU\Software\Google\Chrome\NativeMessagingHosts\<host>`, nessun privilegio admin | [Chrome docs](https://developer.chrome.com/docs/extensions/mv3/nativeMessaging?hl=it) |
| Velopack | Licenza **MIT**; installer + pacchetto portable auto-aggiornante; hosting su GitHub Releases | [GitHub](https://github.com/velopack/velopack), [docs](https://docs.velopack.io/distributing/overview) |
| PresentMon | Open source (MIT, da confermare sul LICENSE); FPS/frametime via ETW; richiede appartenenza al gruppo **Performance Log Users** | [GitHub](https://github.com/blacknut/PresentMon), [igor'sLAB](https://www.igorslab.de/en/measurement-gaming-performance-graphics-card-rating/) |
| LibreHardwareMonitor | Temperature CPU/scheda madre tramite driver kernel; **WinRing0 segnalato da Defender** (CVE-2020-14979), migrazione a PawnIO in corso | [Neowin](https://www.neowin.net/news/windows-1110-is-flagging-winring0-on-your-pc-monitoring-fan-control-apps-heres-why/), [OpenRGB MR](https://gitlab.com/CalcProgrammer1/OpenRGB/-/merge_requests/2885) |
| Discord | L'automazione di account utente («self-bot») è vietata dai termini, con rischio di chiusura dell'account | [copia della policy](https://github.com/sinkaroid/jalter), [Discord support](https://support.discord.com/hc/de/community/posts/360029279832-Bring-back-our-selfbots) |
| Amazon | Le condizioni d'uso escludono robot e strumenti di raccolta dati (analisi di terze parti, testo italiano da verificare) | [ConductAtlas](https://conductatlas.com/platform/amazon/amazon-conditions-of-use/provision/CA-P-018441/prohibition-on-data-mining-and-scraping-tools/) |

## 4. Architettura e stack raccomandati (da confermare con le misure)

| Modulo | Scelta raccomandata | Alternative da misurare | Motivazione |
|---|---|---|---|
| Runtime | **.NET 10 LTS, C#** | — | Supporto fino a 11/2028, ecosistema Windows nativo |
| Host / UI | **WPF** (tray, bolla, dashboard) | WinUI 3 | Maturo, distribuibile senza MSIX, avvio rapido; da misurare memoria a riposo |
| Cattura audio | WASAPI tramite NAudio (MIT) | API Windows dirette | Accesso a basso livello al Katana V2X |
| Parola «Quick Pilot» | **sherpa-onnx keyword spotting** (Apache-2.0) con frase inglese a vocabolario aperto | openWakeWord addestrato su misura; ASR in streaming + confronto frase | Locale, gratuito, nessuna licenza di rete; «Quick Pilot» è foneticamente inglese |
| ASR comandi | **Da scegliere col benchmark** tra Parakeet TDT 0.6B v3 (sherpa-onnx, CC-BY-4.0) e Whisper (whisper.cpp/Whisper.net, CUDA) | Vosk italiano come riferimento leggero | Requisito di precisione su italiano con nomi inglesi |
| Intenti | Parser deterministico + corrispondenza approssimata su catalogo app/giochi | — | Percorso critico senza LLM |
| TTS | **Voce personalizzata JARVIS** (CosyVoice 3 `Fun-CosyVoice3-0.5B`, servizio locale persistente con streaming). Decisione dell'utente del 2026-10-20 | Voci OneCore Cosimo/Elsa solo come riserva | Naturalezza e riconoscibilità; latenza da misurare (T1–T4 in `docs/M0_TTS_PLAN.md`) |
| LLM opzionale | llama.cpp (MIT) con modello scelto per licenza e VRAM | — | Modulo separato, mai nel percorso rapido |
| App desktop | Shell/Win32, UI Automation (es. FlaUI, MIT, da verificare) | — | |
| Steam / Discord / Spotify | Protocolli `steam://`, `discord://`; controlli media di Windows (SMTC) | — | Interfacce supportate, nessun hook nei processi |
| Browser | **Estensione Chrome MV3 + Native Messaging** registrato in HKCU | CDP solo sul profilo dedicato (consentito con `--user-data-dir`) | Nessun admin, nessun server, funziona anche sul profilo principale per schede e cronologia |
| Diagnostica | Contatori Windows, NVML/nvidia-smi (GPU), PresentMon (FPS) | LibreHardwareMonitor solo opzionale | Vedi §5 per i limiti dei permessi |
| Persistenza | SQLite (Microsoft.Data.Sqlite) | JSON | Registro senza scadenza (PRIV-3), routine, preferenze |
| Packaging / aggiornamenti | **Velopack** (installer per utente + portable, aggiornamenti da GitHub Releases) | — | Copre UI-5 e UI-6; da verificare l'installazione senza UAC |

**Esclusi:** Picovoice Porcupine, perché richiede validazione online di una chiave e il piano gratuito ha uno stato incerto (in contrasto con «nessun servizio a pagamento obbligatorio» e con il funzionamento offline).

## 5. Impatti sui requisiti approvati (da decidere con l'utente)

1. **Messaggi Discord (MSG-1).** I termini di Discord vietano l'automazione degli account utente. Proposta: per Discord solo **apertura del canale e bozza**; l'invio lo fa l'utente. Il riepilogo e la frase di conferma restano invariati per gli altri servizi.
2. **WhatsApp e Telegram.** Termini da verificare prima del gruppo 4; possibile riduzione alla sola bozza.
3. **Amazon.** Le condizioni d'uso escludono robot e strumenti automatici: un connettore Amazon rischierebbe la sospensione dell'account. Da considerare nella scelta dei negozi (decisione aperta 1).
4. **Temperature CPU/scheda madre (DIAG-3).** Richiedono un driver kernel e privilegi elevati (**R3**). Default proposto: solo temperature GPU tramite NVML (nessun admin); il resto come passaggio manuale opzionale.
5. **FPS/frametime (DIAG-2).** PresentMon richiede che l'utente sia nel gruppo *Performance Log Users*: operazione amministrativa **una tantum**, eseguita manualmente dall'utente (R3), dopo la quale Quick Pilot funziona da utente standard.
6. **Profilo Chrome dedicato.** Compatibile sia con l'estensione sia con CDP (Chrome 136+ richiede proprio un profilo non predefinito per CDP).

## 6. Rischi residui

| Rischio | Impatto | Mitigazione / prova |
|---|---|---|
| Precisione della parola di attivazione con voice chat e audio di gioco | Falsi trigger (errore inaccettabile) | Benchmark B3 con soglie; fallback ASR + frase |
| Precisione ASR su italiano + nomi inglesi | App o destinatario sbagliati | Benchmark B4, corrispondenza approssimata + disambiguazione |
| VRAM in gioco (ASR + LLM) | Cali di FPS | Prova B6; ASR su CPU in modalità gioco se necessario |
| Conferme solo vocali e audio esterno | Conferma involontaria | Frase con importo/destinatario, monouso, scadenza |
| SmartScreen senza firma del codice | Avvisi all'installazione | Dichiarato; firma valutabile solo con costi |
| Termini dei servizi (Discord, Amazon, WhatsApp) | Sospensione account | §5, verifica prima di ogni connettore |

## 7. Prove da eseguire sul PC reale (M0 parte B)

| # | Prova | Come | Criterio |
|---|---|---|---|
| B1 | Inventario (✅ eseguito) | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotInventory.ps1` da utente standard; inviare (dopo revisione) `local-data\m0-inventory.json` | JSON completo, nessun dato personale |
| B2 | Voci TTS italiane | Dal JSON (sezione `speech`) | Almeno una voce `it-IT` OneCore |
| B3 | Parola «Quick Pilot» | Prototipo di benchmark (sherpa-onnx KWS) con microfono reale: 50 attivazioni, 30 min di parlato normale, 30 min di voice chat + audio di gioco | ≥ 95% attivazioni; ≤ 1 falso trigger/ora (soglia da confermare) |
| B4 | ASR comandi | 30 comandi × 3–5 ripetizioni (corpus solo opt-in) su Parakeet, Whisper (vari modelli) e Vosk | Accuratezza intenti, latenza p50/p95, VRAM/RAM |
| B5 | Dispatch | Fine frase → avvio di Steam/Discord, e → finestra visibile | p95 < 2 s per il dispatch |
| B6 | Impatto in gioco | Gioco con PresentMon, Quick Pilot spento/acceso/ASR su GPU o CPU | Differenza FPS/frametime documentata |
| B7 | Estensione Chrome | Estensione di prova + host Native Messaging in HKCU: elenco schede, cronologia | Funziona da utente standard |
| B8 | Packaging | Installer Velopack per utente + portable di un'app vuota | Nessun UAC, avvio automatico per utente, aggiornamento da release di prova |
| B9 | Memoria a riposo | Host + ASR caricato | Valore misurato e mostrato in dashboard |

Stato degli strumenti (vedi `tools/m0/README.md`), ordinati per priorità:

| Ordine | Prova | Strumento | Stato |
|---|---|---|---|
| 1 | B1 inventario | `Get-QuickPilotInventory.ps1` | ✅ **Eseguita** dall'utente |
| 2 | B2 voci TTS | `Test-QuickPilotTts.ps1` | ✅ **Eseguita sul PC: PASS.** Microsoft Cosimo ed Elsa (it-IT) confermate all'ascolto, numero letto correttamente |
| 3 | Scelta microfono (prerequisito di B3/B4) | `Test-QuickPilotMicrophone.ps1` | ✅ **Eseguita sul PC: PASS preliminare.** SB Katana V2X scelto esplicitamente, 16 kHz mono. Silenzio −96,6 dBFS, parlato −33,2 dBFS RMS, picco −13,9 dBFS, saturazione 0%, SNR 63,4 dB. Audio non salvato |
| 4 | B5 avvio app | `Measure-QuickPilotLaunch.ps1` | 🟡 **Notepad misurato sul PC** (10 avvii, con una correzione temporanea dell'utente): dispatch mediano ≈ 23,8 ms (max 50,9), finestra visibile mediana ≈ 160,2 ms (143,3–282,6). È il riferimento di Notepad, non il tempo end-to-end vocale. Il bug `.Count` in PowerShell 5.1 è corretto alla radice (vedi sotto); Steam, Discord e Spotify sono ancora da misurare |
| 5 | B9 risorse a riposo/in gioco | `Measure-QuickPilotResources.ps1` | 🟡 **Riposo misurato sul PC** (60 s, 41 campioni): RAM disponibile p50 18.679 MB su 31.621 MB (circa 12,9 GB in uso), CPU p50 1%, p95 5%, massimo 8%. **GPU non misurata:** 0 campioni validi, il che non significa GPU a zero. Causa probabile: la lettura di nvidia-smi tramite pipeline in PS 5.1. Corretta: ora usa un processo dedicato con codice di uscita, timeout e motivi d'errore registrati (`gpuErrors`), cerca nvidia-smi anche nei percorsi standard del driver e avvisa se non ci sono campioni. Da ripetere |
| 6 | B4 ASR (CPU) | `Get-QuickPilotM0Models.ps1`, `New-QuickPilotAsrSamples.ps1`, `Measure-QuickPilotAsr.ps1` | 🟡 **Campioni generati sul PC** (10 con Cosimo, 10 con Elsa). Downloader eseguito sul PC con `-Extract`: 5 file verificati, runtime estratto, nessun programma avviato. **B4 Parakeet int8 su CPU eseguito sul PC** (Windows PowerShell 5.1, 4 thread, 20 campioni sintetici, hash del modello verificati): WER medio 0,18 (Cosimo ≈ 0,208, Elsa ≈ 0,151), 5/20 corrispondenze esatte, «quick pilot» riconosciuto 12/20 (60%), decodifica p50 99 ms e p95 115 ms, caricamento del modello p50 1.074 ms.

  **Valutazione:** la pipeline funziona e la decodifica su CPU è molto rapida (ben sotto il budget dei 2 s). Il riconoscimento testuale della parola «Quick Pilot» è però **insufficiente** e non va usato come parola di attivazione. Limiti: audio sintetico, numeri in lettere e in cifre non equiparati, nessuna prova su parlato reale, falsi positivi o audio di gioco. Prossimo confronto: Whisper su CPU con gli stessi 20 campioni, previo consenso al download (§7.1, passo 2).

- **Passo 2 (Whisper), predisposto il 2026-10-20.** Fonti riverificate:
  - `whisper-bin-x64.zip`: release [v1.8.3](https://github.com/ggml-org/whisper.cpp/releases/tag/v1.8.3), l'ultima con binari Windows (v1.9.4–1.9.5 pubblicano solo sorgenti). 3.968.674 B, SHA-256 `d824b1e3…803321d` (digest GitHub, ricalcolato dopo il download), 9.944.064 B dopo l'estrazione (21 file in `Release/`).
  - `ggml-large-v3-turbo-q5_0.bin`: revisione Hugging Face [`5359861c`](https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1), 574.041.195 B, SHA-256 `39422170…5a55ffa7e2`.
  - Licenze: codice MIT (whisper.cpp e ggml; il pacchetto include `SDL2.dll`, licenza zlib). Pesi MIT (OpenAI Whisper; conversione ggml MIT).
  - Totale download 578.009.869 B (≈ 551,2 MiB); con l'estrazione ≈ 561 MiB. Il dry run chiede circa 651 MiB liberi su D: con il margine; con `-Extract`, circa 661 MiB.
  - **Prerequisito:** le tabelle di import del binario Windows richiedono il Visual C++ Redistributable 2015-2022 x64 (`MSVCP140`, `VCRUNTIME140`, `VCRUNTIME140_1`, `VCOMP140`). Non viene installato: il runner verifica le DLL e si ferma se mancano.
- **Prove nel cloud Linux (non sul PC).**
  - whisper.cpp v1.8.3 compilato dai sorgenti dello stesso tag. Il formato di output (testo su stdout con `-nt`, tempi `whisper_print_timings` su stderr) è stato verificato e la conversione dei WAV da 22/24 kHz è automatica.
  - Download ed estrazione reali del passo 2 con `bsdtar`, della stessa famiglia del `tar.exe` di Windows.
  - Runner su due campioni ufficiali: WER 0 e 0,062.
  - Su 4 vCPU cloud generiche la trascrizione ha richiesto circa 60 s per campione: per frasi brevi l'encoder elabora comunque una finestra di 30 s. **Non è indicativo del 9800X3D, ma segnala il rischio principale di Whisper su CPU: la latenza.** Il runner permette di provare `-AudioContext` per ridurre la finestra, con possibile perdita di accuratezza.
  - Gestiti con errori espliciti per campione: codice di uscita non zero, output senza tempi, trascrizione vuota, timestamp inattesi, timeout con chiusura del processo, file mancante, modello alterato, DLL VC++ mancanti.
  - Self-test 30/30, PSScriptAnalyzer pulito.
  - **Il binario Windows di whisper.cpp non è mai stato eseguito.** Download e benchmark in attesa del consenso esplicito dell'utente (§7.1) |
| 6a | B4 confronto Whisper (CPU) | `Get-QuickPilotWhisperModels.ps1`, `Measure-QuickPilotWhisper.ps1`, `Compare-QuickPilotAsr.ps1` | 🟡 **Download autorizzato ed eseguito sul PC:** 2 file verificati per dimensione e SHA-256, 21 voci estratte in `D:\QuickPilotM0\models\whisper-cpp-v1.8.3\Release`, nessun programma avviato. **Benchmark Whisper non ancora eseguito.** |
| 6b | B3 parola di attivazione | da preparare | ⏸ Dopo il confronto ASR |
| 6c | T1–T4 voce di risposta JARVIS | da preparare | ⏸ Dopo il confronto ASR (`docs/M0_TTS_PLAN.md`) |
| 7 | B6 impatto in gioco, B7 estensione Chrome, B8 packaging | da preparare | ⏸ Dopo B3/B4 |

Dettaglio:
- **B1:** eseguito.
- **B2, B5, B9:** script pronti in `tools/m0/`, controllati per sintassi e con PSScriptAnalyzer, **non ancora eseguiti su Windows**.
- **B3, B4:** in attesa della scelta della cartella per i modelli e dell'approvazione dei download.
- **B6, B7, B8:** da preparare.

### 7.1 Manifest dei download per B3/B4 (nessun download ancora autorizzato)

Cartelle scelte dall'utente: modelli in **`D:\QuickPilotM0\models`**, risultati in **`D:\QuickPilotM0\results`**. Niente su C:, niente nel repository, nessuna installazione: gli archivi si estraggono con `tar` già incluso in Windows e i programmi si eseguono dalla cartella.

Dati raccolti il 2026-10-20.
- **Dimensioni esatte:** in byte quando la fonte le pubblica, altrimenti come mostrate dalla pagina delle release.
- **Hash:** SHA-256 pubblicato dalla fonte (digest GitHub o oid LFS di Hugging Face). Dove non è pubblicato, è indicato «non pubblicato». Gli hash marcati «calcolato da noi» li abbiamo ricavati scaricando il file in questo ambiente cloud.

| # | File | Fonte ufficiale | Dimensione | Dopo estrazione | Licenza pesi / binari | SHA-256 |
|---|---|---|---|---|---|---|
| 1 | `sherpa-onnx-v1.13.8-win-x64-shared-MT-Release-no-tts.tar.bz2` (runtime CPU, CRT statico, quindi nessun VC++ redistributable) | [release v1.13.8](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.8) | 23.271.851 B | 63.623.365 B (37 voci, una sola cartella radice; misurato) | Apache-2.0 (codice) | `4b0a94f7b5c606b1b64a19a831c2127559e4b3d34e195465ebc7be73d9ed4783` |
| 2a | Parakeet TDT 0.6B v3 **int8**: `encoder.int8.onnx` | [HF csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8](https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8) | 652.184.281 B | nessuna estrazione | **CC-BY-4.0** (pesi NVIDIA, [model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)); il repo di conversione non dichiara una licenza propria | `acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247` |
| 2b | `decoder.int8.onnx` | idem | 11.845.275 B | — | CC-BY-4.0 | `179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e` |
| 2c | `joiner.int8.onnx` | idem | 6.355.277 B | — | CC-BY-4.0 | `3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3` |
| 2d | `tokens.txt` | idem | 93.939 B | — | CC-BY-4.0 | `d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d` (calcolato da noi) |
| 3 | `sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01.tar.bz2` (parola di attivazione, inglese) | [release kws-models](https://github.com/k2-fsa/sherpa-onnx/releases/tag/kws-models) | 16,8 MB | da misurare (stima 20–40 MB) | **non dichiarata** (addestrato su GigaSpeech) → da chiarire prima del download | non pubblicato (la release contiene un `checksum.txt` da leggere prima del download) |
| 4a | `whisper-bin-x64.zip` (whisper.cpp **CPU**) | [release v1.8.3](https://github.com/ggml-org/whisper.cpp/releases/tag/v1.8.3), l'ultima con binari Windows (v1.9.4–1.9.5 pubblicano solo sorgenti) | 3,78 MB | da misurare | MIT | `d824b1e37599f882b396e73f1ee0bfd5d0529f700314c48311dcbd00b803321d` |
| 4b | `ggml-large-v3-turbo-q5_0.bin` | [HF ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp) | 574.041.195 B (547 MiB) | nessuna estrazione | MIT (pesi Whisper OpenAI) | `394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2` |
| 5 | `whisper-cublas-12.4.0-bin-x64.zip` (opzionale, GPU) | release v1.8.3 | 439 MB | da misurare | MIT; include DLL CUDA NVIDIA (licenza CUDA) | `c12a563333d3c3707be70754dc0e87c1cb58aa6333a87055bbcf9b524488dfb0` |
| 6 | `vosk-model-small-it-0.22.zip` (opzionale, riferimento) | [alphacephei.com/vosk/models](https://alphacephei.com/vosk/models) | 49.665.141 B | 91.299.150 B (20 file) | Apache-2.0 | `9ec65e75861d1c6c2e457cccd932705340dcdf233f5b239f00733b4de0bf3267` (calcolato da noi; la fonte non pubblica checksum) |

Note:
- **Parakeet:** si scaricano **solo** i quattro file int8 (circa 670,5 MB in tutto), non l'intero repository. I file `test_wavs/` non servono.
- **Elemento 5 (whisper CUDA):** è compilato per CUDA 12.4, mentre l'RTX 5070 Ti (architettura Blackwell) è supportata ufficialmente da CUDA 12.8 in poi. Il funzionamento su GPU **non è garantito**, quindi conviene provarlo solo dopo la versione CPU.
- **Elemento 6 (Vosk):** per eseguirlo serve anche la libreria runtime Vosk per Windows, un ulteriore download non ancora censito. WER pubblicato per il modello small: 16,88% su Common Voice. Proposta: rimandarlo, o escluderlo se Parakeet o Whisper bastano.
- **Elemento 3 (parola di attivazione):** finché la licenza dei pesi resta non dichiarata, l'alternativa senza download aggiuntivi è riconoscere «Quick Pilot» con l'ASR (Parakeet) e un confronto di testo. Costa di più in CPU/GPU, ma B3 lo misura comunque.

**Ordine proposto, un passo alla volta, verificando ciascuno prima del successivo:**
1. Elementi 1 + 2 (circa 693 MB): runtime sherpa-onnx CPU e Parakeet int8, poi prova B4 su CPU.
2. Elementi 4a + 4b (circa 578 MB): whisper.cpp CPU con large-v3-turbo q5_0, poi confronto in B4.
3. Elemento 3: solo se la licenza viene chiarita o accettata; poi prova B3.
4. Elemento 5 e/o elemento 6: opzionali, solo se le prove precedenti li giustificano.

Il passo 1 è preparato in `tools/m0/Get-QuickPilotM0Models.ps1`: 693.750.623 B da scaricare, circa 61 MB dopo l'estrazione.

- **Rete.** I redirect vengono seguiti a mano, al massimo 5. Ogni passaggio deve essere HTTPS verso un host ammesso: `github.com`, `huggingface.co`, `*.githubusercontent.com` (asset delle release, oggi `release-assets.githubusercontent.com`) o `*.hf.co` (CDN di Hugging Face, oggi `us.aws.cdn.hf.co`). Gli host di destinazione sono quindi limitati a questi domini, non ai soli due host iniziali. L'integrità dipende comunque da dimensione e SHA-256 fissati.
- **B4 eseguibile subito dopo il download.** `New-QuickPilotAsrSamples.ps1` genera 10 comandi italiani sintetici con le voci OneCore. `Measure-QuickPilotAsr.ps1` riverifica il modello, esegue `sherpa-onnx-offline` solo su CPU e riporta testo, WER, riconoscimento di «quick pilot», tempo di caricamento e di decodifica.
- **Prove nell'ambiente cloud Linux (non sul PC).** Download ed estrazione reali, con controllo di ogni passaggio di redirect. Rifiuto di un redirect verso un host non ammesso e di un URL non HTTPS. Runner B4 eseguito con sherpa-onnx v1.13.8 per Linux e lo stesso modello int8 sui due campioni ufficiali del repository del modello (inglese e spagnolo): WER 0 e 0,062, decodifica 331 e 411 ms, caricamento 2,8–6,3 s su 4 vCPU cloud. **Sono valori indicativi della pipeline, non misure del PC.** Rifiuto di modello alterato (dimensione o hash), indice campioni mancante e percorsi con virgolette.
- **Non verificato:** Windows PowerShell 5.1, la generazione dei campioni WinRT, il binario Windows e il disco USB.

Totale dei passi 1–2: circa 1,27 GB su D:. Ogni download verrà verificato su dimensione e SHA-256 prima dell'uso, e verrà scartato se non corrisponde.

## 8. Roadmap aggiornata

M0-B (misure) → **M1** motore (registro, policy, workflow, log) → **M2** app/giochi/file → **M3** voce (parola + ASR scelti in M0-B) → routine vocali, modalità gioco, dashboard, packaging = **prima release** → gruppo 2 browser e siti → gruppo 3 diagnostica → gruppo 4 messaggi e prenotazioni → gruppo 5 acquisti.
