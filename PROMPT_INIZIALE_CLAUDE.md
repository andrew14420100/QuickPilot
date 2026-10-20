# Prima attività di Claude Code — Quick Pilot

## Istruzione iniziale obbligatoria

Leggi integralmente:
- CLAUDE.md
- docs/PRODUCT_DISCOVERY.md
- docs/ROADMAP.md
- docs/ARCHITECTURE.md
- docs/M0_VALIDATION.md

**Non scrivere ancora codice. Non fare la sola analisi M0 prima di avermi chiesto quali automazioni desidero.**

## Obiettivo del progetto

Quick Pilot deve diventare una piattaforma di automazione generale locale per Windows 11, molto veloce per le azioni semplici, controllabile tramite voce o testo e capace di coordinare workflow tra applicazioni desktop, browser, siti web, file e strumenti diagnostici.

Non limitarlo a un launcher o a un piccolo set fisso di comandi. Voglio un'architettura estensibile che possa imparare nuovi workflow supportati, senza fingere che ogni programma o sito sia automaticamente compatibile.

Esempio importante: posso chiedere di cercare un prodotto online, confrontare opzioni, scegliere una variante, preparare il carrello e compilare il checkout; Quick Pilot deve presentare il riepilogo completo e attendere la mia conferma esplicita prima di effettuare l'ordine o il pagamento.

Altri esempi da discutere con me:
- avviare, coordinare e controllare applicazioni;
- lavorare con browser, schede e siti web;
- cercare, spostare, organizzare o rinominare file;
- preparare email, messaggi, moduli e prenotazioni;
- fare diagnostiche del PC e indagare sui problemi gaming;
- concatenare più azioni in un unico workflow;
- segnalare problemi, chiedere chiarimenti e verificare l'esito delle azioni.

## D0 — Fammi un questionario ampio

Apri la conversazione con circa 20–30 domande organizzate per sezioni, seguendo docs/PRODUCT_DISCOVERY.md. Chiedimi almeno:
1. quali attività vorrei automatizzare davvero;
2. quali applicazioni e browser uso;
3. quali siti e servizi vorrei supportare;
4. che grado di autonomia desidero;
5. come devono funzionare le conferme prima di acquisti, pagamenti, invii, prenotazioni, pubblicazioni e cancellazioni;
6. se voglio voce, testo, hotkey, pulsante oppure tutte queste modalità;
7. se accetto un'estensione browser locale per alcune funzioni;
8. quali dati posso consentire di leggere e quali devono restare esclusi;
9. quali funzioni devono essere offline;
10. come desidero l'interfaccia e il comportamento in background;
11. quale comportamento usare per errori, ambiguità, retry e annullamento;
12. cosa significa per me «velocissimo» e quali azioni sono prioritarie.

Fai anche domande aggiuntive utili, senza ripetere risposte già presenti nel contesto o che puoi rilevare dal PC in sicurezza. Consenti risposte parziali e «non so, consigliami».

Non fare domande generiche soltanto per riempire spazio: ogni domanda deve cambiare l'architettura, le funzionalità, la sicurezza o le priorità.

## D1 — Specifica da concordare

Dopo le mie risposte:
1. produci docs/REQUIREMENTS.md;
2. riassumi i requisiti funzionali e non funzionali;
3. definisci livelli di rischio e policy di conferma;
4. definisci una matrice iniziale di app, siti e capacità supportate;
5. proponi le milestone ordinate per valore e rischio;
6. evidenzia le decisioni ancora aperte;
7. chiedimi di verificare la specifica.

Non considerare la mia conferma della specifica come autorizzazione per eseguire transazioni reali.

## M0 — Solo dopo D1

Dopo aver raccolto le risposte e concordato la specifica, conduci l'analisi tecnica:
- rileva il PC e la toolchain senza chiedermi dati che il sistema può fornire;
- verifica versioni e licenze correnti da fonti ufficiali;
- confronta i motori vocali offline italiani;
- verifica fattibilità di browser automation e automazione Windows;
- misura le latenze possibili;
- valuta packaging per utente e modalità portable;
- crea docs/M0_REPORT.md con prove realmente eseguite, stime separate e rischi residui.

## Vincoli di progetto già noti

- Windows 11 Pro.
- GPU NVIDIA RTX 5070 Ti da 16 GB.
- Microfono Sound Blaster Katana V2X.
- Uso personale.
- Zero euro di servizi obbligatori a pagamento.
- Preferenza per installer per utente e versione portable.
- Target inferiore a 2 secondi per il dispatch di comandi semplici, da misurare.
- LLM non necessari nel percorso critico delle azioni rapide; l'eventuale supporto AI opzionale va discusso con me e non può bypassare le policy di sicurezza.

## Regole essenziali

- Nessun acquisto, pagamento, invio di messaggi/email, pubblicazione, prenotazione o cancellazione irreversibile senza conferma esplicita specifica immediatamente prima dell'azione.
- Per ordini online, riepilogare prodotto/variante, quantità, prezzo, spedizione, totale e destinazione; invalidare la conferma se i dettagli cambiano.
- Non memorizzare password, CVV o numeri completi di carte.
- Non bypassare CAPTCHA, MFA, anti-frode, UAC o restrizioni dei siti.
- Non eseguire input vocale come codice arbitrario.
- Non dichiarare supporto universale: verifica le integrazioni e indica i limiti.
- Tutte le funzioni devono avere test e stati espliciti di completamento.

**La tua prima risposta deve essere il questionario D0, non codice, non un installer e non una decisione tecnica già presa.**
