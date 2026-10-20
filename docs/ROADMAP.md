# Roadmap strutturata

## M0 — Analisi e prove tecniche

**Obiettivo:** ridurre i rischi prima di scrivere il prodotto.

Attività:
- Inventario ambiente e toolchain.
- Verifica ufficiale di versioni e licenze.
- Confronto motore vocale offline italiano.
- Piano di benchmark ripetibile.
- Valutazione hotkey, Chrome e diagnostica standard.
- Rapporto M0 e decisione dell'architettura.

Criteri di uscita:
- Report documentato in docs/M0_REPORT.md.
- Distinzione esplicita tra risultati misurati, stime e ipotesi.
- Nessun codice di prodotto esteso prematuro.

## M1 — Core deterministico e lancio applicazioni

**Obiettivo:** testo → azione registrata, il più rapidamente possibile.

Attività:
- Host WPF con tray.
- Registro azioni tipizzato.
- Parser intenti e alias configurabili.
- Catalogo applicazioni desktop e Microsoft Store.
- Apertura applicazioni, cartelle note e URL consentiti.
- Log locale e misure temporali.

Criteri:
- Almeno 200 casi di test parser.
- 30 applicazioni o alias risolti sul PC di test, se presenti.
- Test di sicurezza per input ambiguo e parametri non validi.
- p95 testo → dispatch sotto 100 ms sul PC di test, escluso il tempo dell'app esterna.

## M2 — Voce offline in italiano

Attività:
- Push-to-talk configurabile.
- Pipeline audio locale.
- Motore vocale con grammatica limitata.
- Gestione errori, confidenza e comandi sconosciuti.
- Test ripetibili con registrazioni WAV e prove dal vivo.

Criteri:
- Misurare accuratezza su almeno 30 comandi e più ripetizioni.
- Target iniziale: accuratezza intenti almeno 95% sul corpus dedicato.
- Target p95 end-to-end sotto 2 secondi dalla fine del comando al dispatch.
- Nessuna azione per riconoscimenti ambigui o a bassa confidenza.

## M3 — File, cartelle e cronologia web

Attività:
- Apertura cartelle conosciute.
- Ricerca download e file recenti.
- Consultazione Chrome History in sola lettura, attraverso copia temporanea.
- Selezione dei risultati prima di aprire molte schede.

Criteri:
- Nessuna scrittura nel profilo originale di Chrome.
- Gestione di più profili e database temporaneamente occupati.
- URL limitati a schemi sicuri HTTP/HTTPS.
- Date interpretate nel fuso orario locale.

## M4 — Diagnostica rapida PC

Attività:
- Sistema operativo e hardware essenziale.
- CPU, RAM, dischi, spazio libero, GPU e driver disponibili.
- Utilizzo CPU, memoria e disco.
- Rapporti e log locali.
- Stato non disponibile per dati non leggibili.

Criteri:
- Report iniziale preferibilmente entro 3 secondi, misurato sul PC reale.
- Nessun valore inventato o presunto.
- Nessun cambiamento di sistema automatico.
- Diagnostica standard eseguita da utente non amministratore.

## M5 — Snapshot e ripristino sessioni Chrome

Attività:
- Estensione Chrome locale opzionale con permessi minimi.
- Snapshot di finestre, schede, gruppi e tab fissate.
- Registro locale versionato.
- Ripristino di uno snapshot scelto dall'utente.

Criteri:
- La cronologia non viene confusa con le sessioni.
- Test su più finestre, schede fissate e gruppi.
- Nessuna installazione silenziosa o policy amministrativa.
- Documentare chiaramente limiti di ripristino.

## M6 — Diagnostica gaming e prestazioni

Attività:
- Registrazione di utilizzo CPU/GPU, RAM, disco e metriche disponibili.
- Integrazione opzionale con strumenti compatibili per frame time/FPS.
- Rilevazione eventi rilevanti di sistema.
- Regole esplicabili e report con prove numeriche.

Criteri:
- Ogni ipotesi riporta le misure su cui si basa.
- Non dichiarare cause certe da semplici correlazioni.
- Metriche mancanti dichiarate come non disponibili.
- Nessun driver o parametro hardware modificato automaticamente.

## M7 — Packaging e release

Attività:
- Versione portable.
- Installer per utente.
- Disinstallazione pulita.
- Autostart opzionale per utente.
- Documentazione, build e test finale.
- ZIP sorgente e checksum.

Criteri:
- Installazione e disinstallazione su account Windows standard senza UAC per le normali funzionalità.
- Funzionamento senza Internet dopo aver installato/scaricato le dipendenze necessarie, per le funzioni dichiarate offline.
- Nessun segreto o dato personale incluso nel pacchetto.
- Avvisi SmartScreen e assenza di firma documentati onestamente.

## Regole di avanzamento

- Una milestone alla volta.
- Per ogni milestone: piano, implementazione, test, esito e aggiornamento documentazione.
- Non saltare test falliti; risolverli o documentare un blocco verificabile.
- Non fare push automatici di codice senza revisione delle differenze.
