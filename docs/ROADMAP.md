# Roadmap strutturata Quick Pilot

Quick Pilot è una piattaforma di automazione generale per Windows 11. La roadmap è intenzionalmente progressiva: prima si chiariscono le esigenze, poi si verifica la fattibilità, quindi si implementano capacità e connettori.

## D0 — Raccolta requisiti approfondita (obbligatoria)

**Obiettivo:** capire come l'utente vuole usare Quick Pilot. Nessun codice di prodotto.

Attività:
- Fare 20–30 domande strutturate per aree tematiche.
- Chiarire app, browser, siti, workflow, modalità d'interazione e livello di autonomia.
- Chiarire acquisti online, pagamenti, invii, prenotazioni, modifiche file e conferme.
- Chiarire privacy, credenziali, dati accessibili, offline, avvio in background e packaging.
- Usare le risposte già note e rilevare dal PC ciò che può essere letto in sicurezza, senza domande superflue.

Criteri di uscita:
- Le domande pertinenti hanno risposta oppure l'utente ha esplicitamente delegato la decisione con una preferenza per valori predefiniti sicuri.
- Le questioni irrisolte sono dichiarate.
- Nessun codice di prodotto scritto.

## D1 — Specifica funzionale da confermare

**Obiettivo:** trasformare le risposte in un piano chiaro.

Deliverable: docs/REQUIREMENTS.md.

Deve contenere:
- casi d'uso prioritari;
- matrice delle app/siti e delle capacità;
- modalità di interazione;
- livelli di rischio e conferme richieste;
- requisiti offline e privacy;
- performance target;
- packaging, aggiornamenti e distribuzione;
- criteri di accettazione per MVP e release successive;
- rischi e limitazioni;
- roadmap ordinata per valore, complessità e costo.

Criteri di uscita: l'utente ha letto e confermato la specifica. Tale conferma non autorizza transazioni reali eseguite dal futuro software.

## M0 — Analisi tecnica e prove

**Obiettivo:** convalidare stack e ipotesi dopo D1.

Attività:
- inventario ambiente e toolchain;
- verifica ufficiale di versioni, licenze e manutenzione;
- confronto ASR offline italiano;
- prove di latenza e accuratezza;
- fattibilità dell'automazione browser e UI Windows;
- analisi delle autorizzazioni;
- packaging per utente e portable;
- rapporto docs/M0_REPORT.md.

Criteri di uscita: report misurabile, distinzione tra test eseguiti e stime, rischi documentati, stack motivato.

## M1 — Motore e host desktop

Obiettivo: fondamenta leggere, indipendenti dai connettori.

- App WPF/tray o alternativa validata.
- Registro tipizzato delle azioni.
- Parser di intenti e parametri.
- Motore di workflow con stato, timeout, cancellazione e gestione errori.
- Policy di rischio e conferma centralizzata.
- Log locale, metriche e interfaccia minima.

Criteri:
- Test unitari del parser e del motore.
- Input ambiguo non lancia azioni.
- Nessuna esecuzione di testo libero come shell.
- Workflow annullabile nei punti supportati.

## M2 — Apertura app, file, cartelle e URL

- Indicizzazione applicazioni desktop e Microsoft Store.
- Alias configurabili.
- Apertura programmi, cartelle note e URL consentiti.
- Comandi singoli e multipli.
- Ricerca file/download con anteprima prima di modifiche estese.

Criteri: test su app disponibili, latenza misurata e assenza di argomenti di comando non convalidati.

## M3 — Voce offline italiana

- Push-to-talk configurabile.
- Motore ASR locale scelto dopo M0.
- Grammatica o intent recognition adatta a comandi supportati.
- Feedback discreto e alternativa testuale.
- Corpus locale opzionale per test, registrazioni disabilitate per impostazione predefinita.

Criteri: accuratezza intenti misurata, falsi positivi controllati e p95 dei comandi semplici valutato sul PC reale.

## M4 — Automazione browser e siti web

Obiettivo: supportare workflow multi-step su siti e browser senza promettere compatibilità universale.

- Browser iniziale definito in D1.
- Connettori separati per ciascuna integrazione.
- Preferire API ufficiali quando disponibili.
- Automazione tramite interfacce accessibili, DOM o UI Automation quando appropriato.
- Gestione dello stato di login senza estrarre o registrare credenziali.
- Screenshot/log tecnici minimizzati, con attenzione alla privacy.
- Verifica dell'esito di ogni step e recupero dagli errori.

Criteri: capacità documentate sito per sito, nessun bypass di CAPTCHA/MFA/anti-frode o restrizioni, timeout e fallback manuale.

## M5 — Workflow transazionali con conferma umana

Esempi: acquisti online, prenotazioni, invio email/messaggi, pubblicazioni e invio moduli.

Per un ordine:
1. Cercare prodotti e confrontare dettagli.
2. Verificare variante, quantità, disponibilità e prezzo.
3. Preparare carrello e checkout se supportato e autorizzato.
4. Raccogliere spedizione, imposte e totale, se visibili.
5. Mostrare un riepilogo specifico e attendere una conferma esplicita.
6. Solo dopo la conferma eseguire il commit finale, se il sito consente l'automazione e non richiede un ulteriore passaggio dell'utente.
7. Se qualsiasi dato cambia, annullare la conferma e mostrare un nuovo riepilogo.
8. Verificare e registrare l'esito senza memorizzare dati di pagamento sensibili.

Criteri:
- Nessuna transazione finale senza conferma fresca, esplicita e legata al riepilogo.
- Nessun acquisto duplicato su retry.
- Idempotenza dove tecnicamente possibile.
- Fermarsi su MFA, CAPTCHA, anti-frode o ambiguità e chiedere intervento umano.
- Log di audit senza password, carte o dettagli inutili.

## M6 — Cronologia e sessioni browser

- Lettura della cronologia in sola lettura tramite copia locale.
- Ricostruzione delle pagine visitate in periodi selezionati.
- Snapshot e ripristino sessioni tramite estensione locale opzionale e permessi minimi.
- Limiti e passaggi d'installazione documentati.

Criteri: non modificare il profilo originale e distinguere cronologia da sessioni.

## M7 — Diagnostica PC

- Sistema operativo, CPU, RAM, dischi, spazio, GPU e driver disponibili.
- Monitoraggio risorse e log.
- Report con fonti, timestamp e unità.
- Nessuna causa dichiarata certa senza evidenze.

Criteri: metriche mancanti dichiarate e funzioni standard eseguibili da utente standard.

## M8 — Diagnostica gaming

- Sessioni misurate e confrontabili.
- CPU/GPU/RAM/disco e metriche disponibili.
- FPS/frametime solo con strumenti compatibili.
- Temperature per hardware/driver che le espongono.
- Ipotesi esplicabili con dati di supporto.

Criteri: distinguere correlazione da causalità e non inventare valori.

## M9 — Estensibilità e personalizzazione

Da definire in D1:
- azioni personalizzate registrate;
- editor di workflow;
- set di connettori;
- regole e preferenze;
- eventuale assistenza AI opzionale, mai autorizzata a bypassare la policy delle azioni.

Nessun sistema di plugin arbitrario finché modello di sicurezza e revisione non sono definiti.

## M10 — Packaging e rilascio

- Versione portable.
- Installer per utente.
- Disinstallazione pulita e avvio automatico opzionale per utente.
- Test su account Windows standard.
- ZIP sorgente, report test e checksum.
- Aggiornamenti solo dopo scelta della strategia e valutazione sicurezza/costi.

Criteri: installazione normale senza UAC quando supportato, limiti SmartScreen dichiarati e nessun dato personale incluso.

## Regole comuni

- Una milestone alla volta.
- Ogni fase ha criteri d'uscita e test ripetibili.
- Prima dei cambiamenti controllare lo stato Git.
- Non dichiarare completamenti non verificati.
- Non pubblicare segreti o dati personali.
