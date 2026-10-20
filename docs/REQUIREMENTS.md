# Quick Pilot — Specifica dei requisiti (D1)

Stato: **bozza da approvare**. Raccolta requisiti D0 svolta il 2026-10-20 tramite selezioni interattive.
L'approvazione di questo documento riguarda la specifica di progetto: **non autorizza** acquisti, invii, prenotazioni o altre azioni reali eseguite dal software.

Legenda delle origini: **[U]** scelta dell'utente · **[C]** default consigliato accettato dall'utente («consigliami») · **[P]** default prudente applicato perché la domanda è rimasta senza risposta (modificabile in revisione).

---

## 1. Visione e ambito

Quick Pilot è un programma Windows 11 **installato, sempre attivo in background**, controllato **a voce** tramite la parola di attivazione «Quick Pilot». Coordina applicazioni, giochi, file, browser/siti, diagnostica e workflow multi-step, con conferma vocale specifica per ogni azione con conseguenze esterne.

Vincoli già noti (non ridiscussi): Windows 11 Pro, uso personale, RTX 5070 Ti 16 GB, microfono Sound Blaster Katana V2X, zero servizi a pagamento obbligatori, installer per utente + versione portable, dispatch dei comandi semplici < 2 s (misurato), nessun LLM nel percorso critico.

### Crescita del prodotto [U]
Architettura generale fin dall'inizio, capacità aggiunte **gradualmente**. Prima versione **piccola e affidabile** [U].

| Ordine | Gruppo | Origine |
|---|---|---|
| 1 | Motore + voce + **App/giochi + File** | [U] |
| 2 | **Browser + siti** (estensione Chrome, profilo dedicato) | [U] |
| 3 | Diagnostica PC/gaming | [P] |
| 4 | Email/messaggi + prenotazioni | [P] |
| 5 | Acquisti online (clic finale su connettori verificati) | [P] |

Motivazione dell'ordine [P]: rischio crescente; gli acquisti, a più alto impatto, arrivano per ultimi e dopo che la base browser e il meccanismo di conferma sono stati provati su azioni meno rischiose.

### Fuori dalla prima release
Documenti e fogli di calcolo (Word/Excel/PDF), app di produttività/Office, automazioni pianificate o su eventi (da decidere in seguito [U]), editor visuale e file di configurazione per workflow (fasi successive [U]), qualsiasi servizio cloud.

---

## 2. Interazione

| Requisito | Dettaglio | Origine |
|---|---|---|
| IN-1 Input | **Solo voce.** Nessuna barra di testo né push-to-talk per l'utente. | [U] |
| IN-2 Attivazione | Parola **«Quick Pilot»** all'inizio di ogni comando, riconosciuta in locale. | [U] |
| IN-3 Sessione continua | Su richiesta («Quick Pilot, resta in ascolto») apre una sessione in cui ogni frase è un comando; si chiude con «basta» o dopo un timeout di silenzio configurabile. | [C] |
| IN-4 Lingua | Italiano, con nomi di giochi, app e prodotti spesso in inglese. | [P] |
| IN-5 Ambiguità | Mostra (e legge se necessario) 2–3 interpretazioni; scelta a voce («la seconda»). | [C] |
| IN-6 Proattività | Può **suggerire** il passo successivo; lo esegue solo se accetti. Nessuna osservazione delle abitudini per generare routine. | [U] |
| IN-7 Hotkey | Solo per controlli (pausa/ripresa microfono), configurabile; nessun default che collida con i giochi. | [U] |
| IN-8 Microfono | Icona tray colorata (in ascolto parola / sessione attiva / in pausa), pausa rapida (hotkey o «Quick Pilot, smetti di ascoltare»), pausa automatica in chiamata o nelle app scelte. | [U] |
| IN-9 Audio | Mai salvato su disco; solo corpus di test **opt-in**. | [U] |
| IN-10 Feedback | Bolla di stato (avanzamento, esito, errore). | [U] |
| IN-11 Lettura vocale | Sintesi vocale locale **sempre** per i riepiloghi R2 e quando servono le scelte di disambiguazione. | [U] |

Test e sviluppo possono iniettare testo nel motore tramite un'interfaccia interna di test; non è una funzione esposta all'utente.

### Modalità gioco [C]
- Attivata automaticamente quando un gioco è in primo piano / a schermo intero.
- Nessun hook globale su tastiera/mouse, nessuna iniezione nei processi di gioco (compatibilità anti-cheat).
- Accetta **solo** frasi che iniziano con «Quick Pilot» (la sessione continua è sospesa) per evitare che il parlato in voice chat diventi un comando.
- Esiti tramite **bolla minima** [U]; nei giochi a schermo intero esclusivo potrebbe non essere visibile: in quel caso valgono la sintesi vocale per R2 e il riepilogo al rientro.
- Le conferme R2 vengono chieste **subito** anche in gioco [U], con riepilogo letto ad alta voce.
- Da studiare in M0, senza promesse: silenziare in modo lecito il microfono su Discord durante il comando, così i compagni non sentono le richieste [U].
- Uso della VRAM da parte di ASR/LLM durante il gioco: **decisione dopo le misure M0** [U].

---

## 3. Requisiti funzionali

### 3.1 Motore (base di tutto)
- **ENG-1** Registro tipizzato di capacità: ogni azione ha schema dei parametri, precondizioni, livello di rischio R0–R3, timeout, verifica dell'esito, test.
- **ENG-2** Intent parser deterministico per i comandi comuni; nessun testo riconosciuto diventa comando shell/PowerShell.
- **ENG-3** Motore di workflow con stati espliciti (pending, running, waiting-for-user, completed, failed, cancelled), cancellazione a voce («Quick Pilot, annulla»).
- **ENG-4** Policy e consenso centralizzati: nessun connettore può eseguire un'azione R2 senza un token di conferma valido emesso dal livello di policy.
- **ENG-5** In caso di errore il workflow **si ferma e chiede** [C]: ripete in automatico solo passi R0; gli R2 non vengono mai ripetuti in automatico; nessun doppio invio/ordine.
- **ENG-6** Metriche separate: ASR, interpretazione, pianificazione, attesa conferma, dispatch, completamento, verifica.

### 3.2 App e giochi (gruppo 1)
- **APP-1** Rilevamento **automatico** di app installate (menu Start, Microsoft Store) e giochi delle librerie dei launcher [U]. Nessun alias manuale [U]; il riconoscimento usa corrispondenza approssimata sui nomi e, se incerto, propone 2–3 candidati.
- **APP-2** Aprire, chiudere, portare in primo piano, comandi multipli («apri Steam e Discord»).
- **APP-3** Azioni interne dove esiste un'interfaccia supportata [U], verificate app per app (vedi matrice §5): avvio di un gioco specifico, Discord su server/canale, controllo della riproduzione multimediale.
- **APP-4** Chiusura di un'app con lavoro non salvato o di un gioco in corso: richiede conferma (rischio di perdita dati).
- **APP-5** Setup multi-app (es. «modalità gaming»: apri Steam + Discord, chiudi app pesanti) come routine.

### 3.3 File (gruppo 1)
- **FILE-1** Ambito: cartelle utente (Download, Documenti, Desktop, Immagini, Video, Musica) + cartelle aggiunte dall'utente [C]; mai cartelle di sistema né cartelle escluse.
- **FILE-2** Ricerca per nome, tipo, data («il PDF scaricato ieri»), apertura, mostra in Esplora file.
- **FILE-3** Riordino (es. Download per tipo/data), spostamento, rinomina: **R1**, eseguiti con riepilogo e **Annulla** [C].
- **FILE-4** Eliminazione e sovrascrittura: **R2**, anteprima + conferma vocale specifica («Quick Pilot, confermo eliminazione di 12 file»), **sempre tramite Cestino**, mai definitive.
- **FILE-5** Analisi file su richiesta (anche in background durante il gioco): elenchi, dimensioni, duplicati; riassunti di contenuto solo con LLM locale opzionale (§3.8).

### 3.4 Routine create a voce (gruppo 1) [U]
- **WF-1** «Quick Pilot, crea la routine *serata*: apri X, chiudi Y» compone **solo azioni già registrate**; riepilogo letto prima del salvataggio.
- **WF-2** Le routine possono contenere passi R2, ma ogni esecuzione si ferma e chiede la conferma specifica a quel passo [P].
- **WF-3** Le routine sono modificabili/eliminabili dalla dashboard; salvate in locale.
- File di configurazione YAML/JSON ed editor visuale: release successive [U]. Nessun sistema di plugin arbitrario.

### 3.5 Browser e siti (gruppo 2)
- **WEB-1** Browser: **Chrome** [U].
- **WEB-2** Programma desktop + **estensione Chrome locale come ponte** (installazione manuale una tantum, nessun server esterno) [U].
- **WEB-3** Automazioni sui siti in un **profilo Chrome dedicato** a Quick Pilot [C]; login fatto dall'utente una volta, uso delle sessioni, **mai** memorizzazione di password [U].
- **WEB-4** Dal profilo principale, in sola lettura: schede aperte, cronologia (copia locale), «riapri le pagine di ieri» [U].
- **WEB-5** Ricerca e raccolta informazioni, apertura dei risultati migliori, compilazione moduli.
- **WEB-6** Strategia **ibrida** [C]: connettori dedicati e testati per i siti principali + modalità generica marcata **«sperimentale»** per gli altri.
- **WEB-7** Si ferma su login, MFA, CAPTCHA, verifiche antifrode, SPID/CIE e passa il controllo all'utente; nessun bypass.

### 3.6 Diagnostica PC/gaming (gruppo 3)
- **DIAG-1** Stato del PC: CPU, RAM, dischi, spazio, processi pesanti, avvio lento [U].
- **DIAG-2** Cali di FPS/stuttering: registrazione di una sessione con strumenti compatibili (FPS/frametime) e ricerca di correlazioni [U].
- **DIAG-3** Temperature dove leggibili da utente standard, versioni dei driver GPU/chipset [U].
- **DIAG-4** Rete: ping, perdita pacchetti, tipo di connessione durante il gioco [U].
- **DIAG-5** Ogni valore con fonte, unità e timestamp; metriche non disponibili dichiarate tali; nessuna causa presentata come certa senza evidenze.

### 3.7 Email, messaggi e prenotazioni (gruppo 4)
- **MSG-1** Servizi: Gmail, WhatsApp, Telegram, Discord [U].
- **MSG-2** **Bozza + conferma** [C]: destinatario e testo letti ad alta voce, invio solo dopo frase specifica («Quick Pilot, confermo invio a Marco»).
- **MSG-3** Lettura dei contenuti **su richiesta** («cosa mi ha scritto Marco?»), senza archiviarli [U]; riassunti tramite LLM locale opzionale.
- **BOOK-1** Prenotazioni: treni, voli/hotel, ristoranti, servizi pubblici/sanità [U]; preparazione fino al riepilogo, conferma specifica; SPID/CIE/pagamenti PA sempre manuali.

### 3.8 AI locale opzionale [C]
- **AI-1** LLM locale (GPU) per comprensione di richieste complesse, riassunti (email, file), confronto prodotti.
- **AI-2** Fuori dal percorso rapido: i comandi semplici non lo attendono.
- **AI-3** Può solo **proporre** piani composti da azioni registrate; non emette conferme, non cambia il livello di rischio, non autorizza R2.
- **AI-4** Nessun modello o servizio cloud.

### 3.9 Acquisti online (gruppo 5)
- **BUY-1** Ricerca, confronto, selezione variante, carrello, checkout.
- **BUY-2** **Clic finale eseguito da Quick Pilot** dopo la conferma [U], **solo su connettori verificati**; altrimenti si ferma al riepilogo del sito e il clic lo fa l'utente.
- **BUY-3** Riepilogo (mostrato **e** letto): negozio, articolo e variante, quantità, prezzo unitario, spedizione, imposte se note, totale, indirizzo parziale, consegna prevista, metodo di pagamento mascherato, **venditore terzo e rating, politica di reso e garanzia, 2–3 alternative scartate con motivo** [U].
- **BUY-4** Conferma con **frase vocale contenente il totale** («Quick Pilot, confermo ordine da 89 euro»), valida una sola volta e per quella transazione.
- **BUY-5** Se prezzo, quantità, variante, indirizzo, metodo o totale cambiano tra conferma e clic, la conferma è invalidata e il riepilogo ripresentato.
- **BUY-6** Nessun limite di spesa [U].
- **BUY-7** Negozi specifici: **da decidere** (vedi §9).
- **BUY-8** Nessuna transazione reale durante i test automatici.

---

## 4. Rischio e consenso

| Livello | Esempi | Comportamento |
|---|---|---|
| **R0** | Aprire app/file/siti, leggere schede, cronologia, stato PC, cercare | Automatico se il target è certo; altrimenti 2–3 opzioni |
| **R1** | Spostare/rinominare file, chiudere app senza lavoro non salvato, creare routine | Eseguito con riepilogo nella bolla e **Annulla** dove possibile |
| **R2** | Eliminare/sovrascrivere file, inviare messaggi/email, prenotare, acquistare, chiudere con lavoro non salvato | Riepilogo **mostrato e letto** + **frase vocale specifica** subito prima dell'atto finale |
| **R3** | Privilegi amministrativi, UAC, impostazioni di sicurezza | Mai aggirati; esclusi o passaggio manuale |

Regole della conferma vocale R2:
1. Deve iniziare con «Quick Pilot» e contenere l'elemento chiave del riepilogo (totale, destinatario o numero di file).
2. Monouso, legata a un'unica operazione, con scadenza (proposta: 60 s, da definire in M1).
3. Invalidata da qualsiasi cambiamento dei dati rilevanti.
4. Una conferma generica («sì», «ok», «procedi») non è mai sufficiente.

Aree escluse [U]: **banca e finanza**, **sanità e documenti d'identità**, più una **lista configurabile** di cartelle/siti. Su queste Quick Pilot può al massimo aprire il sito o la cartella, senza leggerne il contenuto né agire.

---

## 5. Matrice iniziale delle capacità (ipotesi da verificare in M0)

Stato: ✅ previsto supportato · 🟡 parziale/con limiti · ⛔ non supportato · ❓ da verificare.

| Target | Capacità | Via prevista | Stato atteso | Limiti / prerequisiti |
|---|---|---|---|---|
| App Win32/Store | Apri, chiudi, primo piano | API Windows, shell, UI Automation | ✅ | App non accessibili via UIA: solo apri/chiudi |
| Steam | Avvio gioco specifico, libreria | Protocollo `steam://`, file di libreria locali | ✅/❓ | Steam installato e loggato |
| Altri launcher (Epic, Battle.net, Riot, EA, Ubisoft) | Rilevamento e avvio giochi | Collegamenti, protocolli, manifest locali | 🟡 | Varia per launcher |
| Discord (app) | Apri server/canale | Deep link `discord://` | 🟡❓ | Nessun selfbot né automazione dell'account contraria ai termini |
| Spotify / media | Play, pausa, avanti | Controlli multimediali di Windows | ✅ | Playlist specifiche: via app/URI, ❓ |
| File (cartelle utente) | Cerca, apri, riordina, rinomina, Cestino | API file system, Windows Search | ✅ | Esclusioni e Cestino obbligatori |
| Chrome (profilo principale) | Schede, cronologia, sessioni | Estensione + copia locale della cronologia | ✅❓ | Estensione installata manualmente |
| Chrome (profilo dedicato) | Navigazione, moduli, ricerca | Estensione/automazione browser | 🟡 | Sito per sito; CAPTCHA/MFA manuali |
| Siti generici | Ricerca, lettura, moduli semplici | Modalità «sperimentale» | 🟡 | Nessuna garanzia, segnalata come tale |
| Gmail | Leggere, preparare, inviare | API ufficiale gratuita (OAuth) o web | 🟡❓ | Configurazione OAuth locale da verificare |
| WhatsApp | Preparare, inviare | WhatsApp Desktop/Web via UI | 🟡❓ | Nessuna API personale ufficiale; fragile |
| Telegram | Preparare, inviare | App desktop/UI o API ufficiale client | ❓ | Termini e fattibilità da verificare |
| Discord messaggi | Preparare, inviare | Solo UI dell'app ufficiale | ❓ | Automazione dell'account utente potenzialmente contraria ai termini → forse solo bozza |
| Treni / voli / hotel / ristoranti | Ricerca, preparazione prenotazione | Browser (profilo dedicato) | 🟡❓ | Termini del sito, pagamento con conferma |
| Servizi pubblici / sanità | Apertura pagina giusta, moduli | Browser | 🟡 | SPID/CIE sempre manuali; area sanità soggetta a esclusione |
| Negozi online | Cerca, confronta, carrello, checkout, clic finale | Connettori dedicati | ❓ | Negozi da scegliere; termini d'uso (es. Amazon) possono limitarlo a ricerca/carrello |
| Diagnostica | Stato, FPS/frametime, temperature, rete | Contatori Windows, strumenti FPS compatibili, sensori accessibili | 🟡 | Temperature e FPS dipendono da hardware/strumenti |
| Banca/finanza, sanità | — | — | ⛔ (solo apertura) | Esclusione esplicita dell'utente |
| Azioni con UAC/admin | — | — | ⛔ | Passaggio manuale |

---

## 6. Privacy e dati

- **PRIV-1** Dati leggibili [U]: schede e cronologia di Chrome (sola lettura), file nelle cartelle consentite, finestra attiva/screenshot solo quando servono al comando e **mai salvati**, appunti.
- **PRIV-2** Nulla esce dal PC oltre ai siti/servizi che l'utente chiede esplicitamente di usare; **nessuna telemetria** [C].
- **PRIV-3** Registro locale delle azioni **mai eliminato automaticamente** [U]: archivi compressi per mese, pulizia solo manuale dalla dashboard; contenuti redatti (niente password, carte, testi completi di messaggi, dati superflui). Il volume occupato viene mostrato nella dashboard.
- **PRIV-4** Nessuna password, CVV o numero completo di carta memorizzato; nessun dato personale, cronologia o segreto in Git.
- **PRIV-5** Funzionamento offline per tutto ciò che non richiede un sito: voce, intenti, app, file, routine, diagnostica, LLM locale.

---

## 7. Interfaccia, avvio, distribuzione

- **UI-1** Icona nella tray (stato microfono, menu, pausa) [U].
- **UI-2** Bolla di stato discreta [U].
- **UI-3** **Dashboard completa** [U]: registro, routine, app rilevate, esclusioni, impostazioni (timeout, hotkey, pausa automatica), diagnostica, riepiloghi R2 dettagliati.
- **UI-4** **Avvio con Windows in modalità reattiva** [U]: riconoscimento vocale già caricato per minima latenza; consumo RAM/VRAM a riposo da misurare in M0 e mostrare nella dashboard.
- **UI-5** Installer per utente senza privilegi amministrativi + versione portable (noto).
- **UI-6** **Aggiornamenti** [U]: controllo automatico gratuito (proposta: GitHub Releases), avviso nella bolla/dashboard; l'aggiornamento parte quando l'utente lo chiede a voce («Quick Pilot, aggiornati»), con riepilogo della versione e conferma. Verifica di integrità del pacchetto prima dell'installazione.
- **UI-7** Uso personale (noto); nessuna distribuzione prevista.

---

## 8. Prestazioni

| Metrica | Obiettivo | Nota |
|---|---|---|
| Fine frase → dispatch azione semplice | **< 2 s p95** (obiettivo stretto da definire in M0) | Misurato sul PC reale |
| Fine frase → finestra visibile | Misurato e riportato per app | Dipende dall'app esterna |
| Rilevamento della parola «Quick Pilot» | Falsi positivi e falsi negativi misurati, anche con voice chat e audio del gioco | Requisito di precisione [U] |
| Workflow lunghi | Avanzamento visibile, UI mai bloccata | |
| Impatto in gioco | Impatto su FPS/frametime misurato con Quick Pilot attivo | Decide l'uso di VRAM |

---

## 9. Criteri di accettazione della prima release (gruppo 1)

Bloccanti, perché l'utente li ha indicati come errori inaccettabili [U]:
1. **Nessuna azione R2 senza conferma valida**: test che provano conferme generiche, scadute, riferite a un'altra operazione e a dati cambiati, che devono tutte essere rifiutate.
2. **Nessuna app o destinatario sbagliati**: in caso di incertezza, disambiguazione obbligatoria; test con nomi simili.
3. **Nessuna perdita di file**: eliminazioni solo nel Cestino, rinomine e spostamenti annullabili, test su cartelle temporanee.
4. **Nessun microfono nascosto o falso trigger**: indicatore sempre coerente, test di falsi positivi con parlato, voice chat e audio di gioco; in modalità gioco accettate solo frasi con la parola di attivazione.

Funzionali:
5. «Quick Pilot, apri Steam e Discord» apre entrambe le app, con latenza registrata.
6. «Quick Pilot, avvia *nome gioco*» avvia il gioco corretto o propone 2–3 candidati.
7. «Quick Pilot, sistema i download di oggi» mostra il piano, lo esegue come R1 e «annulla» ripristina lo stato.
8. «Quick Pilot, elimina i file temporanei nei download» presenta un'anteprima letta ad alta voce e procede solo con la frase specifica.
9. «Quick Pilot, crea la routine *gaming*…» salva una routine eseguibile e modificabile.
10. Modalità gioco attivata automaticamente, senza hook su tastiera o mouse.
11. Avvio con Windows, installer per utente e versione portable funzionanti come utente standard.
12. Registro consultabile in dashboard, senza dati sensibili.
13. Nessun testo riconosciuto eseguito come shell; test con input ostili.

I gruppi successivi avranno criteri propri, definiti all'inizio di ciascuna milestone.

---

## 10. Decisioni aperte

| # | Decisione | Quando |
|---|---|---|
| 1 | Negozi online da supportare | Prima del gruppo 5 |
| 2 | Uso della VRAM (ASR/LLM) durante il gioco | Dopo le misure M0 |
| 3 | Silenziamento lecito di Discord durante i comandi | Fattibilità in M0 |
| 4 | Automazioni pianificate o su eventi | Dopo la prima release |
| 5 | Motore della parola di attivazione: «Quick Pilot» fissa o personalizzabile | M0 |
| 6 | Modello LLM locale e quantizzazione | M0 |
| 7 | Gmail via API ufficiale o via web; fattibilità di Telegram e Discord | Prima del gruppo 4 |
| 8 | Scadenza esatta della conferma R2 e timeout della sessione continua | M1 |
| 9 | Ordine dei gruppi 3–5, lingua e regola R2 nelle routine (default [P] applicati) | Revisione di questa specifica |

## 11. Rischi principali

- **Solo voce**: con il riconoscimento degradato (rumore, nomi stranieri) non esiste un input alternativo; mitigazione con disambiguazione vocale, ma resta un rischio di usabilità.
- **Conferme solo vocali**: un audio esterno (altoparlanti, compagni in chiamata) potrebbe pronunciare una frase valida; mitigazioni: frase con importo o destinatario, monouso, scadenza breve, uso consigliato delle cuffie. La verifica dell'identità del parlante non è prevista perché poco affidabile.
- **Clic finale automatico negli acquisti**: limitato ai connettori verificati e soggetto ai termini dei siti.
- **Parola di attivazione personalizzata in italiano**: i motori open source potrebbero richiedere un addestramento specifico; da verificare in M0.
- **Messaggistica senza API ufficiali** (WhatsApp, Discord): l'automazione è fragile e potrebbe essere limitata alla sola bozza.
- **Log mai eliminati**: crescita dello spazio su disco; mitigazione con compressione e indicatore nella dashboard.

## 12. Prossimo passo

Dopo l'approvazione di questa specifica: **M0**, cioè inventario del PC, benchmark ASR e parola di attivazione in italiano sul microfono reale, prova dell'estensione Chrome, latenze, impatto in gioco e packaging. Il risultato sarà `docs/M0_REPORT.md`. Nessun codice di prodotto prima di M0.
