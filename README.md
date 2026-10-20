# Quick Pilot

Quick Pilot è una piattaforma locale di automazione generale per Windows 11. L'obiettivo è permettere all'utente di chiedere azioni concrete nel linguaggio naturale, tramite voce o testo, e farle eseguire rapidamente attraverso integrazioni controllate con applicazioni, browser e sistema operativo.

Non è soltanto un launcher di programmi o uno strumento diagnostico. Deve essere estensibile per workflow multi-step, ad esempio aprire applicazioni, gestire file, navigare siti, compilare moduli, raccogliere informazioni, preparare acquisti online e fermarsi per una conferma esplicita prima di effettuare un ordine o un pagamento.

## Principio di funzionamento

**Comando → interpretazione → piano visibile/validato → azioni registrate → controlli di sicurezza → esecuzione → verifica del risultato.**

Non deve usare un LLM generativo nel percorso critico delle azioni rapide. L'eventuale supporto opzionale a modelli locali o online è una decisione da chiarire nella fase di raccolta requisiti, e non deve mai poter aggirare il registro delle azioni, i limiti di sicurezza o le conferme richieste.

## Esempi di workflow

- «Aprimi Chrome, Steam e Discord».
- «Riapri le pagine che avevo visitato ieri».
- «Fammi una diagnosi del PC e mostrami cosa non va».
- «Cerca un prodotto che soddisfi queste caratteristiche, confronta le alternative e preparalo nel carrello».
- «Compila l'ordine e fammi controllare prodotto, indirizzo, spedizione e totale; non acquistare finché non confermo».
- «Trova i file che ho scaricato ieri e raggruppali in una cartella, mostrando prima le modifiche proposte».
- «Apri il programma giusto, esegui la procedura e dimmi se è riuscita».

Sono esempi di obiettivo, non una promessa che qualunque applicazione o sito sia automaticamente compatibile. Le capacità devono essere organizzate in connettori e azioni verificabili.

## Sicurezza per livelli

- **Livello 1 — Lettura e apertura:** eseguibile automaticamente quando l'intento è chiaro.
- **Livello 2 — Modifiche reversibili:** seguire le preferenze di autorizzazione configurate e mostrare ciò che sarà cambiato.
- **Livello 3 — Azioni esterne o ad alto impatto:** richiedere una conferma esplicita, specifica e aggiornata prima di inviare, acquistare, pagare, prenotare, eliminare o pubblicare.
- **Livello 4 — Operazioni amministrative o sensibili:** non aggirare UAC, autenticazione, CAPTCHA, MFA, controlli antifrode o autorizzazioni del sito. L'utente completa manualmente i passaggi richiesti.

Prima di un acquisto, mostrare almeno articolo/variante, quantità, prezzo, spedizione, totale, destinazione e metodo di pagamento (senza esporre dati sensibili). Il pulsante finale deve essere collegato all'esatta transazione mostrata e scadere se i dettagli cambiano. Non memorizzare numeri di carte o password.

## Obiettivi

- Comandi vocali e testuali in italiano.
- Motore di esecuzione rapido, deterministico e misurabile.
- Integrazioni per applicazioni Windows, browser, file e diagnostica.
- Workflow multi-step con stato, recupero errori e possibilità di annullare dove supportato.
- Browser automation con interfacce supportate e rispetto dei controlli di autenticazione e dei termini applicabili.
- Diagnostica PC e, dove supportata, diagnostica gaming.
- Installazione per utente e versione portable, senza privilegi amministrativi per le normali funzioni.
- Nessun servizio cloud o API a pagamento obbligatori.

## Fase obbligatoria prima del codice

Claude Code deve iniziare con **D0 — Raccolta requisiti** e farti un questionario ampio, diviso in sezioni. Deve chiarire cosa significa “può fare tutto” per te: app, siti, browser, acquisti, file, messaggi, prenotazioni, conferme, modalità vocale, privacy, autonomia e limiti. Non deve iniziare a costruire l'applicazione né saltare direttamente alla M0 finché non ha raccolto le risposte e prodotto una specifica riassuntiva da farti verificare.

## Documenti

- **CLAUDE.md** — istruzioni permanenti.
- **PROMPT_INIZIALE_CLAUDE.md** — attività iniziale e blocco fino alla raccolta requisiti.
- **docs/PRODUCT_DISCOVERY.md** — questionario e ambiti da chiarire.
- **docs/ROADMAP.md** — fasi e criteri di completamento.
- **docs/ARCHITECTURE.md** — architettura di riferimento da validare.
- **docs/M0_VALIDATION.md** — piano delle prove tecniche.

## Costi e licenze

Preferire tecnologie gratuite/open source e modalità locali. Verificare le licenze aggiornate. Alcuni siti richiedono login, verifiche dell'utente, estensioni o hanno limitazioni proprie. Non presumere che ogni servizio sia automatizzabile né aggirarne i controlli. Non aggiungere segreti, cronologie o dati personali al repository.

## Stato

Repository di specifiche e pianificazione. Prima attività: completare D0 e confermare la specifica; poi condurre M0. Non dichiarare prodotto implementato finché non esistono codice, test e verifiche reali.
