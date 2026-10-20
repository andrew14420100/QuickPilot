# Architettura proposta

Questa architettura è una base da validare con l'utente durante D0/D1 e con prove tecniche in M0. Non è una decisione finale già approvata.

## Principio

Quick Pilot deve coordinare azioni tra Windows, applicazioni desktop e browser. Non va ridotto a un elenco statico di comandi, ma nemmeno deve ricevere accesso illimitato al sistema. Ogni funzionalità deve essere esposta come capacità dichiarata e testata attraverso un connettore con parametri tipizzati e policy di rischio.

## Stack da valutare

- C# e versione .NET supportata a lungo termine.
- WPF per una UI minimale, tray e pannello di conferma.
- NAudio/WASAPI per audio, se adatto e compatibile.
- Motore ASR locale con italiano e grammatica adatta a comandi, selezionato dopo benchmark.
- Windows UI Automation e API di sistema per app desktop.
- API ufficiali browser/siti quando disponibili; altrimenti DOM/accessibility/browser extension o UI automation secondo il caso.
- SQLite o JSON per stato e preferenze locali.
- Packaging per utente e portable, scelto dopo verifica licenze e supporto.

## Componenti logici

### Host
Gestisce tray, lifecycle, hotkey, UI, configurazioni e avvio in background.

### Input
Riceve voce, testo e scorciatoie. Modalità always-listening, push-to-talk e hotkey si decidono con l'utente in D0.

### Speech
Traduce voce in testo in locale, se la modalità vocale viene attivata. Nessuna registrazione audio predefinita.

### Intent and Planner
Converte la richiesta in intenti tipizzati e in una sequenza di step autorizzati. Per i comandi comuni usa mapping diretto deterministico. Workflow ambigui devono chiedere chiarimenti; l'eventuale uso di modelli deve essere deciso e restare entro i vincoli di sicurezza.

### Capability Registry
Catalogo di azioni disponibili, schemi input/output, precondizioni, livello di rischio, autorizzazioni e test.

### Workflow Engine
Esegue sequenze con stato esplicito: pending, running, waiting-for-user, completed, failed, cancelled. Supporta timeout, cancellazione, retry solo sicuri, recupero e verifica degli esiti.

### Policy and Consent
Applicazione centrale delle conferme e dei livelli di rischio. I connettori non possono saltare questo livello.

### Windows Connector
Apertura app, cartelle, finestre e integrazioni native attraverso API sicure.

### Browser Connector
Automazioni sito/browser, gestione schede e sessioni, moduli e raccolta dati. Capacità e limiti documentati per browser e sito.

### Transaction Connector
Gestisce workflow che hanno un commit esterno, come ordini, prenotazioni, invii o pubblicazioni. Prepara i dati ma non esegue l'atto finale senza consenso valido.

### File Connector
Ricerca, apertura, organizzazione, rinomina, spostamento e altre operazioni autorizzate. Operazioni distruttive o estese richiedono anteprima e consenso.

### Diagnostics
Raccoglie dati locali e li presenta con unità, fonte, timestamp e affidabilità.

### Audit and Telemetry
Log locale con rotazione e redazione; niente telemetria remota automatica.

## Livelli di rischio

- **R0 — Lettura/apertura:** esecuzione diretta se il target è certo.
- **R1 — Reversibile:** esecuzione entro preferenze autorizzate, con possibilità di annullare quando supportato.
- **R2 — Effetti esterni o irreversibili:** conferma specifica subito prima di inviare, acquistare, pagare, prenotare, pubblicare, condividere o cancellare.
- **R3 — Privilegi elevati/autenticazione:** niente bypass; l'utente completa manualmente i passaggi richiesti.

Il motore deve far rispettare la policy indipendentemente da come l'intento è stato ottenuto, sia con parser deterministico sia con un eventuale supporto AI.

## Flusso generico

1. Ricevere comando.
2. Identificare richiesta e parametri.
3. Se ambiguo, chiedere chiarimenti.
4. Costruire il piano di workflow e mostrarlo quando necessario.
5. Verificare che tutte le azioni siano nel registry e rispettino i prerequisiti.
6. Per transazioni, raccogliere stato e dati effettivi.
7. Presentare una conferma legata ai dettagli correnti dell'operazione.
8. Ricevere conferma esplicita.
9. Validare che i dettagli non siano cambiati.
10. Eseguire l'azione finale, quando supportata e consentita.
11. Verificare l'esito e registrarne un riepilogo.
12. Non dichiarare successo se il sito o l'app non l'hanno confermato.

## Acquisti online

Il flusso può automatizzare ricerca, confronto, selezione e compilazione del checkout dove il sito lo permette. Prima dell'ordine mostra prodotto/variante, quantità, prezzi, spedizione, tasse se note, totale, destinazione e metodo di pagamento senza rivelare dati sensibili.

La conferma deve essere aggiornata e riferita a quell'operazione esatta. Qualsiasi variazione rilevante invalida il consenso precedente. Non memorizzare password, CVV o numeri completi di carta. CAPTCHA, MFA e controlli antifrode sono passaggi manuali, non ostacoli da aggirare.

## Performance e affidabilità

Separare il tempo di ASR, parsing, pianificazione, eventuale attesa di conferma, dispatch, completamento e verifica. L'obiettivo dei due secondi vale per il dispatch di azioni semplici e va misurato; i siti web e gli altri processi possono richiedere più tempo.

Ogni workflow deve avere timeout, error handling, cancellazione dove possibile, stato osservabile e log.

## Sicurezza

- Il testo libero non deve diventare codice di shell o PowerShell.
- Parametri passati in forme tipizzate e validate.
- Nessun bypass UAC, CAPTCHA, MFA, controlli antifrode o restrizioni applicabili.
- Esecuzione per utente standard.
- Segreti e dati sensibili non vanno mai in Git o log.
- Nessuna transazione reale durante i test automatici; usare sandbox, mock o flussi di prova.
