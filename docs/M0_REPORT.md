# M0 — Report di validazione tecnica

Stato al 2026-10-20: **parte A (ricerca e fonti) completata; parte B (misure sul PC) in corso.** Riferimenti: `docs/REQUIREMENTS.md` (approvata), `docs/M0_VALIDATION.md`, `docs/M0_TTS_PLAN.md`, `tools/m0/README.md`.

> **Come leggere il report.** Ogni risultato indica dove è stato ottenuto:
> - **PC:** misura eseguita dall'utente sul PC di destinazione, con i dati riportati dall'utente;
> - **cloud:** prova eseguita da Claude in un container Linux, utile per verificare gli strumenti ma non rappresentativa del PC;
> - **mancante:** non ancora eseguita.
>
> Nessun valore è stimato senza dichiararlo. I file grezzi (JSON, audio, modelli) restano sul PC, in `D:\QuickPilotM0`, e non sono nel repository.

---

## 1. Ambienti

| Ambiente | Caratteristiche | Uso |
|---|---|---|
| **PC dell'utente** | Windows 11 Pro x64 (build 26300), Ryzen 7 9800X3D (8 core / 16 thread), 32 GB di RAM, RTX 5070 Ti 16 GB, Windows PowerShell 5.1, microfono SB Katana V2X; C: con poco spazio libero, D: disco USB esterno | Tutte le misure di parte B. Modelli in `D:\QuickPilotM0\models`, risultati in `D:\QuickPilotM0\results` |
| **Cloud** | Container Linux, PowerShell 7.4.6, 4 vCPU generiche, nessun microfono, nessuna GPU, nessun Windows | Ricerca delle fonti, analisi e self-test degli script, prove con sherpa-onnx e whisper.cpp per Linux |

## 2. Stato delle prove (tabella di riferimento)

| ID | Prova | Strumento | Dove | Stato e risultato |
|---|---|---|---|---|
| B1 | Inventario | `Get-QuickPilotInventory.ps1` | PC | ✅ Eseguita (§3.1) |
| — | Self-test funzioni comuni | `Test-M0Common.ps1` | PC + cloud | ✅ PC: 25/25 nella versione allora presente, con un campione GPU reale. Cloud: 58/58 nella versione attuale; **la versione con i test della prova dal vivo non è ancora stata eseguita sul PC** |
| B2 | Voci TTS di sistema (solo per generare campioni) | `Test-QuickPilotTts.ps1` | PC | ✅ PASS: Microsoft Cosimo ed Elsa (it-IT) confermate all'ascolto, numero letto correttamente. **Non sono la voce di risposta** (§6) |
| — | Microfono | `Test-QuickPilotMicrophone.ps1` | PC | ✅ PASS preliminare: SB Katana V2X scelto esplicitamente, 16 kHz mono; silenzio −96,6 dBFS, parlato −33,2 dBFS RMS, picco −13,9 dBFS, saturazione 0%, SNR 63,4 dB. Audio non salvato |
| B5 | Avvio app | `Measure-QuickPilotLaunch.ps1` | PC (parziale) | 🟡 Solo Notepad, 10 avvii eseguiti con una correzione temporanea dell'utente prima della correzione alla radice: dispatch mediano ≈ 23,8 ms (max 50,9), finestra visibile mediana ≈ 160,2 ms (143,3–282,6). È il riferimento di Notepad, non il tempo end-to-end vocale. **Mancano** Steam, Discord e Spotify, e una ripetizione con lo script corretto |
| B9 | Risorse | `Measure-QuickPilotResources.ps1` | PC (parziale) | 🟡 Riposo eseguito (60 s, 41 campioni): RAM disponibile p50 18.679 MB su 31.621 MB (≈ 12,9 GB in uso), CPU p50 1%, p95 5%, massimo 8%, media 1,6%. **GPU non misurata** (0 campioni validi, causa probabile la lettura di nvidia-smi in PS 5.1, corretta dopo): da ripetere a riposo e **mancante** in gioco |
| B4 | Download passo 1 (sherpa-onnx CPU + Parakeet int8) | `Get-QuickPilotM0Models.ps1` | PC | ✅ Dry run e download: 5 file verificati per dimensione e SHA-256, runtime estratto (37 voci), nessun programma avviato |
| B4 | Campioni sintetici | `New-QuickPilotAsrSamples.ps1` | PC | ✅ 20 WAV (10 Cosimo, 10 Elsa) in `D:\QuickPilotM0\results\b4-samples` |
| B4 | Parakeet int8 su CPU (campioni sintetici) | `Measure-QuickPilotAsr.ps1` | PC | ✅ §3.2 |
| B4 | Download passo 2 (whisper.cpp CPU + large-v3-turbo q5_0) | `Get-QuickPilotWhisperModels.ps1` | PC | ✅ Dry run e download autorizzati: 2 file verificati, 21 voci estratte, nessun programma avviato |
| B4 | Whisper su CPU (campioni sintetici) | `Measure-QuickPilotWhisper.ps1` | PC | ✅ §3.2 |
| B4 | Confronto Parakeet / Whisper | `Compare-QuickPilotAsr.ps1` | PC | ✅ §3.2 |
| B4 | Parakeet sulla **voce reale** (opt-in) | `Test-QuickPilotLiveAsr.ps1` | cloud | 🟡 **Predisposto, non eseguito sul PC** (§4) |
| B3 | Parola di attivazione e falsi positivi | da preparare | — | ⏸ **Mancante.** La sessione di ascolto richiede una nuova approvazione separata |
| T1–T4 | Voce di risposta JARVIS (CosyVoice 3) | da preparare | — | ⏸ **Mancante.** Piano in `docs/M0_TTS_PLAN.md` |
| B6 | Impatto in gioco (PresentMon) | da preparare | — | ⏸ **Mancante** |
| B7 | Estensione Chrome + Native Messaging | da preparare | — | ⏸ **Mancante** |
| B8 | Packaging Velopack | da preparare | — | ⏸ **Mancante** |

## 3. Risultati sul PC

### 3.1 Inventario (B1)

Il JSON grezzo resta sul PC. Indicazioni rilevanti:

| Voce | Esito | Conseguenza |
|---|---|---|
| .NET SDK | Nessun SDK, runtime .NET 8 presenti | Gli strumenti M0 sono script Windows PowerShell 5.1: non serve un SDK e nulla viene installato |
| Spazio disco | C: sotto i 10 GB liberi; D: disco USB esterno con ampio spazio | Modelli, campioni, risultati e audio temporaneo solo su D:; gli script rifiutano l'unità di sistema o avvisano |
| Voci TTS | OneCore Cosimo ed Elsa (it-IT) | Usate solo per i campioni sintetici |
| Microfoni | SB Katana V2X e Steam Streaming Microphone (virtuale) | Selezione sempre esplicita del Katana |
| Browser | Chrome 155, 2 profili | Per B7 |
| Performance Log Users | Utente già membro | Nessuna azione per PresentMon; da riverificare in B6 |

Valutazione preliminare (stima, non misura): CPU, RAM e VRAM sono ampiamente sufficienti per ASR locale. Il vincolo è lo spazio su C:. I caricamenti da D: (USB) rientrano nei tempi di caricamento misurati in B4.

### 3.2 ASR su campioni sintetici (B4, CPU, 4 thread, stessi 20 campioni)

| Motore | WER medio | Esatte | «quick pilot» all'inizio | Latenza p50 / p95 (senza caricamento) | Caricamento p50 |
|---|---|---|---|---|---|
| Parakeet TDT 0.6B v3 int8 (sherpa-onnx 1.13.8) | **0,18** | 5/20 | 12/20 | **99 / 115 ms** (decodifica) | 1.074 ms |
| Whisper large-v3-turbo q5_0 (whisper.cpp 1.8.3, `-l it`, contesto predefinito) | 0,298 | 4/20 | **20/20** | 14.800 / 15.156 ms (`total − load`) | 467 ms |

Per voce (`Compare-QuickPilotAsr.ps1`):
- **Parakeet:** Cosimo WER 0,208 e prefisso 5/10; Elsa WER 0,151 e prefisso 7/10.
- **Whisper:** WER 0,298 e prefisso 10/10 per entrambe le voci.

Regole di confronto, identiche per i due motori:
- minuscole, punteggiatura rimossa, trattini come spazi;
- numeri in cifre e in lettere **non** equiparati.

**Lettura:**
- Parakeet è il **candidato ASR predefinito** per i comandi interattivi, per il WER più basso e la latenza circa 149 volte inferiore. È la raccomandazione condivisa con l'utente, non ancora una scelta definitiva.
- Whisper large-v3-turbo q5_0 su CPU, così configurato, è fuori dal budget dei 2 s. La causa attesa è l'encoder, che elabora sempre una finestra di 30 s.
- Varianti di Whisper non provate:
  - più thread o `-AudioContext` ridotto, possibili senza nuovi download;
  - un modello più piccolo o la GPU, che richiederebbero nuovi download (e per la GPU una verifica CUDA con la RTX 5070 Ti).
- Il prefisso «quick pilot» trovato in 12/20 frasi da Parakeet indica che il solo confronto del testo **non** basta come parola di attivazione.

**Limiti:** 20 frasi sintetiche con due voci OneCore. Queste misure **non** dicono quanto è accurato il riconoscimento sul parlato reale dell'utente, né misurano i falsi positivi con voice chat o audio di gioco. Il controllo del prefisso non è un benchmark della parola di attivazione.

## 4. Strumenti predisposti e verifiche nel cloud

- **Prova dal vivo `Test-QuickPilotLiveAsr.ps1`** (Parakeet sulla voce reale, opt-in). Non ancora eseguita sul PC.
  - Prima di qualsiasi registrazione: verifica di eseguibile e modello, selezione del Katana con esclusione dei dispositivi virtuali, spiegazione e consenso. Con «n» non registra nulla.
  - Una frase fissa alla volta (5 s dopo Invio); `p` salta, `q` termina.
  - WAV temporaneo solo in `D:\QuickPilotM0\tmp-live`, cancellato nel `finally`. La cancellazione non impedisce il recupero forense. I residui di sessioni interrotte vengono rimossi all'avvio.
  - Risultati solo testuali. Il riconoscitore viene riavviato a ogni frase: il caricamento è misurato a parte.
  - **Cloud:** self-test 58/58 con microfono e riconoscitore finti. Coperti: consenso negato, annullamento, frase saltata, array di un elemento, microfono mancante, virtuale o ambiguo, modello mancante o hash errato, errore del processo, timeout, output vuoto o malformato, WAV eliminato in ogni caso, pulizia dei residui. In più, una prova reale con sherpa-onnx v1.13.8 per Linux e il modello verificato su campioni PCM di un audio ufficiale: WER 0,062, WAV eliminato.
  - **Non verificati:** microfono reale, waveIn e binario Windows con questo strumento.
- **Whisper:**
  - whisper.cpp v1.8.3 compilato dai sorgenti nel cloud per verificare il formato di output: testo su stdout con `-nt`, tempi su stderr.
  - Prova reale del runner con gestione degli errori per campione.
  - Su 4 vCPU cloud circa 60 s per campione, valore non indicativo del PC, dove ne sono stati misurati circa 14,8.
- **Downloader:**
  - redirect seguiti a mano, al massimo 5, solo HTTPS verso `github.com`, `huggingface.co`, `*.githubusercontent.com`, `*.hf.co`;
  - verifica di dimensione e SHA-256;
  - nessuna sovrascrittura senza chiedere; rifiuto dell'unità di sistema.
  
  Provati nel cloud con download reali e casi di errore, poi eseguiti con successo sul PC.

## 5. Correzioni emerse dalle prove sul PC

- **`.Count` in Windows PowerShell 5.1.**
  - Con StrictMode, un array di un elemento restituito da una funzione diventa uno scalare senza `.Count`: questo bloccava B5.
  - Corretto alla radice: conteggi come interi, helper chiamati dentro `@(...)`, `Read-M0JsonArray` per l'array JSON che PS 5.1 restituisce come oggetto unico.
  - B5 si ferma senza chiusure forzate se il target resta in esecuzione.
  - Il bug non si riproduce in PowerShell 7: per questo il self-test va eseguito anche sul PC.
- **GPU in B9.** nvidia-smi ora viene eseguito con un processo dedicato (codice di uscita, timeout, motivi d'errore in `gpuErrors`) e cercato anche nei percorsi standard del driver. Il self-test sul PC ha letto un campione GPU reale; **B9 con GPU va ripetuto**.

## 6. Voce di risposta (decisione dell'utente)

La voce di risposta di Quick Pilot è la **voce personalizzata JARVIS** (CosyVoice 3 `Fun-CosyVoice3-0.5B`, servizio locale già usato da JARVIS sulla porta 8765):
- da riutilizzare senza modificare JARVIS e senza ri-clonare la voce;
- le voci OneCore (Cosimo, Elsa) servono solo a generare campioni sintetici e non vengono usate per rispondere;
- se la voce non è disponibile, la riserva è non vocale (bolla e suono);
- ASR e TTS restano separati.

Il piano di misura T1–T4 (caricamento, primo audio, latenza totale, RTF, RAM/VRAM, impatto in gioco) è in `docs/M0_TTS_PLAN.md`. Nessuna misura è stata ancora eseguita.

## 7. Fonti e versioni verificate (ricerca, parte A)

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

## 8. Architettura e stack raccomandati

| Modulo | Scelta raccomandata | Alternative da misurare | Motivazione |
|---|---|---|---|
| Runtime | **.NET 10 LTS, C#** | — | Supporto fino a 11/2028, ecosistema Windows nativo |
| Host / UI | **WPF** (tray, bolla, dashboard) | WinUI 3 | Maturo, distribuibile senza MSIX, avvio rapido; da misurare memoria a riposo |
| Cattura audio | WASAPI tramite NAudio (MIT) | API Windows dirette | Accesso a basso livello al Katana V2X |
| Parola «Quick Pilot» | **Da decidere con B3** (non ancora eseguita). Ipotesi: sherpa-onnx keyword spotting, ma la licenza dei pesi del modello KWS non è dichiarata | ASR + confronto del testo (Parakeet ha trovato il prefisso in 12/20 frasi sintetiche: insufficiente da solo); openWakeWord addestrato su misura | Requisito: nessun falso trigger in gioco |
| ASR comandi | **Parakeet TDT 0.6B v3 int8** (sherpa-onnx, CC-BY-4.0): candidato predefinito dopo B4 su TTS sintetico, da confermare con la prova sul parlato reale | Whisper large-v3-turbo q5_0 su CPU escluso nella configurazione provata (≈ 14,8 s per frase); Vosk non provato | WER più basso e latenza ≈ 149 volte inferiore sui campioni sintetici |
| Intenti | Parser deterministico + corrispondenza approssimata su catalogo app/giochi | — | Percorso critico senza LLM |
| TTS | **Voce personalizzata JARVIS** (CosyVoice 3 `Fun-CosyVoice3-0.5B`, servizio locale persistente con streaming). Decisione dell'utente del 2026-10-20 | Nessuna voce robotica: OneCore esclusa per le risposte, usata solo per i campioni ASR; riserva non vocale | Naturalezza e riconoscibilità; latenza da misurare (T1–T4 in `docs/M0_TTS_PLAN.md`) |
| LLM opzionale | llama.cpp (MIT) con modello scelto per licenza e VRAM | — | Modulo separato, mai nel percorso rapido |
| App desktop | Shell/Win32, UI Automation (es. FlaUI, MIT, da verificare) | — | |
| Steam / Discord / Spotify | Protocolli `steam://`, `discord://`; controlli media di Windows (SMTC) | — | Interfacce supportate, nessun hook nei processi |
| Browser | **Estensione Chrome MV3 + Native Messaging** registrato in HKCU | CDP solo sul profilo dedicato (consentito con `--user-data-dir`) | Nessun admin, nessun server, funziona anche sul profilo principale per schede e cronologia |
| Diagnostica | Contatori Windows, NVML/nvidia-smi (GPU), PresentMon (FPS) | LibreHardwareMonitor solo opzionale | Vedi §5 per i limiti dei permessi |
| Persistenza | SQLite (Microsoft.Data.Sqlite) | JSON | Registro senza scadenza (PRIV-3), routine, preferenze |
| Packaging / aggiornamenti | **Velopack** (installer per utente + portable, aggiornamenti da GitHub Releases) | — | Copre UI-5 e UI-6; da verificare l'installazione senza UAC |

**Esclusi:** Picovoice Porcupine, perché richiede validazione online di una chiave e il piano gratuito ha uno stato incerto (in contrasto con «nessun servizio a pagamento obbligatorio» e con il funzionamento offline).

## 9. Impatti sui requisiti approvati (da decidere con l'utente)

1. **Messaggi Discord (MSG-1).** I termini di Discord vietano l'automazione degli account utente. Proposta: per Discord solo **apertura del canale e bozza**; l'invio lo fa l'utente. Il riepilogo e la frase di conferma restano invariati per gli altri servizi.
2. **WhatsApp e Telegram.** Termini da verificare prima del gruppo 4; possibile riduzione alla sola bozza.
3. **Amazon.** Le condizioni d'uso escludono robot e strumenti automatici: un connettore Amazon rischierebbe la sospensione dell'account. Da considerare nella scelta dei negozi (decisione aperta 1).
4. **Temperature CPU/scheda madre (DIAG-3).** Richiedono un driver kernel e privilegi elevati (**R3**). Default proposto: solo temperature GPU tramite NVML (nessun admin); il resto come passaggio manuale opzionale.
5. **FPS/frametime (DIAG-2).** PresentMon richiede che l'utente sia nel gruppo *Performance Log Users*: operazione amministrativa **una tantum**, eseguita manualmente dall'utente (R3), dopo la quale Quick Pilot funziona da utente standard.
6. **Profilo Chrome dedicato.** Compatibile sia con l'estensione sia con CDP (Chrome 136+ richiede proprio un profilo non predefinito per CDP).

## 10. Rischi residui

| Rischio | Impatto | Mitigazione / prova |
|---|---|---|
| Accuratezza sul parlato reale (italiano con nomi inglesi) | App o destinatario sbagliati | Prova dal vivo (§4), poi corrispondenza approssimata e disambiguazione |
| Parola di attivazione con voice chat e audio di gioco | Falsi trigger (errore inaccettabile) | B3 con sessione di ascolto approvata separatamente; il prefisso testuale da solo non basta |
| Latenza di Whisper su CPU | Fuori budget | Whisper escluso dal percorso interattivo nella configurazione provata |
| Voce JARVIS: latenza e VRAM in gioco | Risposte lente o cali di FPS | T1–T4 e B6 (`docs/M0_TTS_PLAN.md`) |
| VRAM in gioco (ASR, TTS, eventuale LLM) | Cali di FPS | B6; ASR già su CPU |
| Conferme solo vocali e audio esterno | Conferma involontaria | Frase con importo/destinatario, monouso, scadenza |
| SmartScreen senza firma del codice | Avvisi all'installazione | Dichiarato; firma valutabile solo con costi |
| Termini dei servizi (Discord, Amazon, WhatsApp) | Sospensione account | §9, verifica prima di ogni connettore |

## 11. Download: manifest e stato

Dati raccolti il 2026-10-20.
- **Dimensioni:** in byte quando la fonte le pubblica.
- **SHA-256:** pubblicato dalla fonte (digest GitHub o oid LFS di Hugging Face); «calcolato da noi» quando la fonte non lo pubblica.
- Nessun file viene scritto su C: o nel repository.

| # | File | Fonte ufficiale | Dimensione | Dopo estrazione | Licenza pesi / binari | SHA-256 |
|---|---|---|---|---|---|---|
| 1 | `sherpa-onnx-v1.13.8-win-x64-shared-MT-Release-no-tts.tar.bz2` (runtime CPU, CRT statico, quindi nessun VC++ redistributable) | [release v1.13.8](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.8) | 23.271.851 B | 63.623.365 B (37 voci, una sola cartella radice; misurato) | Apache-2.0 (codice) | `4b0a94f7b5c606b1b64a19a831c2127559e4b3d34e195465ebc7be73d9ed4783` |
| 2a | Parakeet TDT 0.6B v3 **int8**: `encoder.int8.onnx` | [HF csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8](https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8) | 652.184.281 B | nessuna estrazione | **CC-BY-4.0** (pesi NVIDIA, [model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)); il repo di conversione non dichiara una licenza propria | `acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247` |
| 2b | `decoder.int8.onnx` | idem | 11.845.275 B | — | CC-BY-4.0 | `179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e` |
| 2c | `joiner.int8.onnx` | idem | 6.355.277 B | — | CC-BY-4.0 | `3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3` |
| 2d | `tokens.txt` | idem | 93.939 B | — | CC-BY-4.0 | `d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d` (calcolato da noi) |
| 3 | `sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01.tar.bz2` (parola di attivazione, inglese) | [release kws-models](https://github.com/k2-fsa/sherpa-onnx/releases/tag/kws-models) | 16,8 MB | da misurare (stima 20–40 MB) | **non dichiarata** (addestrato su GigaSpeech) → da chiarire prima del download | non pubblicato (la release contiene un `checksum.txt` da leggere prima del download) |
| 4a | `whisper-bin-x64.zip` (whisper.cpp **CPU**) | [release v1.8.3](https://github.com/ggml-org/whisper.cpp/releases/tag/v1.8.3), l'ultima con binari Windows (v1.9.4–1.9.5 pubblicano solo sorgenti) | 3.968.674 B | 9.944.064 B (21 file in `Release/`) | codice MIT; include `SDL2.dll` (zlib); richiede VC++ Redistributable 2015-2022 x64 | `d824b1e37599f882b396e73f1ee0bfd5d0529f700314c48311dcbd00b803321d` |
| 4b | `ggml-large-v3-turbo-q5_0.bin` | [HF ggerganov/whisper.cpp, revisione `5359861c`](https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1) | 574.041.195 B (547 MiB) | nessuna estrazione | MIT (pesi Whisper OpenAI) | `394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2` |
| 5 | `whisper-cublas-12.4.0-bin-x64.zip` (opzionale, GPU) | release v1.8.3 | 439 MB | da misurare | MIT; include DLL CUDA NVIDIA (licenza CUDA) | `c12a563333d3c3707be70754dc0e87c1cb58aa6333a87055bbcf9b524488dfb0` |
| 6 | `vosk-model-small-it-0.22.zip` (opzionale, riferimento) | [alphacephei.com/vosk/models](https://alphacephei.com/vosk/models) | 49.665.141 B | 91.299.150 B (20 file) | Apache-2.0 | `9ec65e75861d1c6c2e457cccd932705340dcdf233f5b239f00733b4de0bf3267` (calcolato da noi; la fonte non pubblica checksum) |


| Passo | Elementi | Stato |
|---|---|---|
| 1 | 1, 2a–2d (`Get-QuickPilotM0Models.ps1`) | ✅ Scaricato e verificato sul PC |
| 2 | 4a, 4b (`Get-QuickPilotWhisperModels.ps1`, revisione HF `5359861c`); richiede il VC++ Redistributable 2015-2022 x64 già presente | ✅ Scaricato e verificato sul PC; benchmark eseguito |
| — | 3 (modello KWS) | ⏸ Non scaricato: licenza dei pesi non dichiarata; decisione legata a B3 |
| — | 5 (whisper CUDA 12.4), 6 (Vosk) | ⏸ Non scaricati e non necessari al momento. La versione CUDA 12.4 potrebbe non supportare la RTX 5070 Ti (Blackwell richiede CUDA 12.8+); Vosk richiede anche la sua libreria runtime |

## 12. Criteri per le prove mancanti

| ID | Prova | Criterio proposto |
|---|---|---|
| B3 | Parola di attivazione: attivazioni volute, 30 min di parlato normale, 30 min di voice chat e audio di gioco | ≥ 95% di attivazioni; ≤ 1 falso trigger/ora (soglia da confermare) |
| B4 dal vivo | Parakeet sulla voce reale | Accuratezza dei comandi e del prefisso; latenza di decodifica p50/p95 |
| B5 | Avvio di Steam, Discord, Spotify | Dispatch p95 < 2 s |
| B6 | Impatto in gioco (PresentMon) con Quick Pilot spento, inattivo e attivo | Differenza FPS/frametime documentata |
| B7 | Estensione Chrome + Native Messaging in HKCU | Funziona da utente standard |
| B8 | Installer Velopack per utente + portable | Nessun UAC, avvio automatico per utente, aggiornamento da release di prova |
| B9 | Risorse con GPU, a riposo e in gioco | Valori misurati con campioni GPU validi |
| T1–T4 | Voce JARVIS | Vedi `docs/M0_TTS_PLAN.md` |

## 13. Prossimi passi

1. **Prova dal vivo** `Test-QuickPilotLiveAsr.ps1` sul PC, opt-in. Prima conviene eseguire il self-test aggiornato.
2. **Riepilogo M0** per l'approvazione: prove eseguite e mancanti, rischi, proposta ASR, piano TTS.
3. Le prove mancanti (B3, B5 sulle altre app, B9 con GPU e in gioco, B6, B7, B8, T1–T4) vanno eseguite in M0 o pianificate esplicitamente come prerequisiti delle milestone successive, secondo la decisione dell'utente nel riepilogo.

Roadmap: M0 (in corso) → **M1** motore (registro, policy, workflow, log) → **M2** app/giochi/file → **M3** voce (parola + ASR) → routine vocali, modalità gioco, dashboard, packaging = **prima release** → browser e siti → diagnostica → messaggi e prenotazioni → acquisti. **M1 inizia solo dopo l'approvazione esplicita di M0.**
