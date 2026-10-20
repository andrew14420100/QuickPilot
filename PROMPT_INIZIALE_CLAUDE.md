# Prima attività di Claude Code — Quick Pilot

Leggi integralmente CLAUDE.md e i documenti in docs prima di prendere decisioni.

## Obiettivo

Analizza e prepara un piano tecnico affidabile per Quick Pilot: motore di automazione locale per Windows 11, comandi deterministici, risposta rapida, riconoscimento vocale italiano offline, diagnostica e integrazione con Chrome. Non è un chatbot e non deve usare un LLM per eseguire i comandi ordinari.

## Vincolo iniziale

**Non iniziare costruendo l'intera applicazione.** Prima esegui analisi del repository e milestone M0. Puoi creare o aggiornare solo documentazione e piccoli esperimenti tecnici isolati necessari a M0. Non introdurre ancora codice di prodotto esteso.

## Informazioni già note sull'ambiente di destinazione

- Windows 11 Pro.
- GPU NVIDIA RTX 5070 Ti con 16 GB di VRAM.
- Microfono Sound Blaster Katana V2X.
- Uso personale, in locale.
- Budget: zero euro di servizi obbligatori.
- Preferenza: C#/.NET e WPF, da verificare tecnicamente.
- Preferenza forte: installer per utente senza privilegi amministrativi e versione portable.
- Browser iniziale: Chrome.
- Obiettivo di latenza: meno di 2 secondi dalla fine del comando al dispatch per i comandi semplici, da misurare.
- Il resto dell'hardware deve essere rilevato automaticamente, non chiesto all'utente se è leggibile dal sistema.

## M0 — Analisi e validazione

1. Verifica lo stato della repository e i file già presenti. Non sovrascrivere lavoro preesistente.
2. Ispeziona in modo non invasivo il sistema di sviluppo e rileva CPU, RAM, GPU, sistema operativo, microfono disponibile, SDK e toolchain presenti. Non richiedere elevazione amministrativa.
3. Verifica tramite fonti ufficiali aggiornate versioni, licenze, manutenzione e requisiti di .NET, WPF, NAudio, Vosk, eventuali alternative speech, Velopack, librerie NVML/driver e strumenti di telemetria che vuoi proporre.
4. Confronta motori vocali offline per italiano. Per la prima versione dai priorità a un vocabolario chiuso di comandi e a una grammatica ristretta. Verifica dimensioni, memoria, licenza e latenza sul PC reale quando possibile.
5. Definisci precisamente la metrica dei 2 secondi e un banco di test ripetibile. Distingui riconoscimento vocale, risoluzione intenti, dispatch e avvio visibile dell'app.
6. Analizza le criticità della hotkey durante giochi e finestre elevate. Non aggirare anti-cheat o controlli di Windows.
7. Distingui lettura della cronologia Chrome da ripristino di una sessione esatta. Definisci un metodo che non modifichi il database Chrome e valuta un'estensione locale opzionale con permessi minimi.
8. Elenca quali metriche diagnostiche sono disponibili all'utente standard e quali richiederebbero privilegi aggiuntivi o strumenti specifici.
9. Stima RAM, spazio disco, costi inevitabili e avvisi SmartScreen. Non dichiarare che SmartScreen non avviserà per un installer non firmato.
10. Produci docs/M0_REPORT.md con risultati, link alle fonti consultate, prove realmente eseguite, ipotesi, rischi e decisione tecnica.

## Milestone successive

Dopo aver completato M0 e presentato il rapporto, procedi per fasi controllate:

- M1: host leggero in tray, registro azioni, parser deterministico per comandi scritti, indice app e apertura programmi/cartelle/URL.
- M2: push-to-talk e motore vocale offline italiano; misure end-to-end e test con WAV.
- M3: file, cartelle note, ricerca Download e risultati di Chrome History con selezione prima dell'apertura multipla.
- M4: diagnostica rapida CPU/RAM/dischi/GPU con stato e fonte per ogni metrica.
- M5: integrazione Chrome per snapshot/restauro sessioni tramite estensione locale opzionale.
- M6: logging prestazioni e diagnostica gaming, con metriche non disponibili segnalate onestamente.
- M7: portabile e installer per utente, test su account Windows standard, documentazione e release ZIP.

Non saltare le milestone. Ogni fase deve avere criteri di accettazione, build e test.

## Comandi e azioni sicure

Per la prima versione le azioni devono essere esplicite e registrate: avvio app, apertura cartelle note, apertura URL HTTP/HTTPS convalidati e diagnostica read-only. Escludi eliminazioni, modifiche registro pericolose, script arbitrari e riparazioni automatiche.

Il testo vocale non deve mai essere interpretato come codice PowerShell o prompt di shell. Usa mapping a ID di azione e parametri tipizzati.

## Definizione di successo per M0

M0 è completa solo quando esiste un rapporto leggibile che contiene:
- Ambiente rilevato e limiti di accesso.
- Versioni e licenze verificate, citando le fonti attuali.
- Architettura raccomandata e alternative scartate.
- Test che sono stati davvero eseguiti e relativi risultati.
- Test non eseguibili e motivo.
- Target prestazionali e procedura di misurazione.
- Roadmap definitiva e rischi residui.

Al termine, presenta un riepilogo breve e preciso. Non dichiarare di aver testato la voce se non hai usato davvero il microfono sul computer di destinazione.
