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
| TTS | **Voci italiane Windows OneCore** (Windows.Media.SpeechSynthesis) | Piper (licenze da verificare) | Zero dipendenze e già presenti nel sistema (da confermare con l'inventario) |
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
| B1 | Inventario | `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\m0\Get-QuickPilotInventory.ps1` da utente standard; inviare (dopo revisione) `local-data\m0-inventory.json` | JSON completo, nessun dato personale |
| B2 | Voci TTS italiane | Dal JSON (sezione `speech`) | Almeno una voce `it-IT` OneCore |
| B3 | Parola «Quick Pilot» | Prototipo di benchmark (sherpa-onnx KWS) con microfono reale: 50 attivazioni, 30 min di parlato normale, 30 min di voice chat + audio di gioco | ≥ 95% attivazioni; ≤ 1 falso trigger/ora (soglia da confermare) |
| B4 | ASR comandi | 30 comandi × 3–5 ripetizioni (corpus solo opt-in) su Parakeet, Whisper (vari modelli) e Vosk | Accuratezza intenti, latenza p50/p95, VRAM/RAM |
| B5 | Dispatch | Fine frase → avvio di Steam/Discord, e → finestra visibile | p95 < 2 s per il dispatch |
| B6 | Impatto in gioco | Gioco con PresentMon, Quick Pilot spento/acceso/ASR su GPU o CPU | Differenza FPS/frametime documentata |
| B7 | Estensione Chrome | Estensione di prova + host Native Messaging in HKCU: elenco schede, cronologia | Funziona da utente standard |
| B8 | Packaging | Installer Velopack per utente + portable di un'app vuota | Nessun UAC, avvio automatico per utente, aggiornamento da release di prova |
| B9 | Memoria a riposo | Host + ASR caricato | Valore misurato e mostrato in dashboard |

Per B3–B9 servono piccoli prototipi di benchmark (programmi console usa e getta, non codice di prodotto), da preparare nel prossimo passo ed eseguire sul PC.

## 8. Roadmap aggiornata

M0-B (misure) → **M1** motore (registro, policy, workflow, log) → **M2** app/giochi/file → **M3** voce (parola + ASR scelti in M0-B) → routine vocali, modalità gioco, dashboard, packaging = **prima release** → gruppo 2 browser e siti → gruppo 3 diagnostica → gruppo 4 messaggi e prenotazioni → gruppo 5 acquisti.
