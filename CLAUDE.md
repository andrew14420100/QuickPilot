# Istruzioni permanenti per Claude Code — Quick Pilot

## Missione

Costruire **Quick Pilot**, una piattaforma di automazione generale per Windows 11. Deve poter crescere oltre apertura app e diagnostica: automazioni tra applicazioni, browser, siti web, file e workflow multi-step. Esempio: cercare e confrontare prodotti, compilare un carrello e preparare il checkout, ma richiedere conferma esplicita e specifica prima dell'invio dell'ordine o del pagamento.

Quick Pilot non deve diventare un chatbot che risponde a lungo prima di agire. Il percorso critico delle azioni rapide deve rimanere leggero e misurabile. Un modello generativo non è richiesto per l'esecuzione: se l'utente desidera in seguito funzioni opzionali basate su modelli, vanno decise durante la raccolta requisiti e mantenute fuori dal confine di sicurezza delle azioni.

## REGOLA PIÙ IMPORTANTE: PRIMA FAI DOMANDE

Alla prima interazione sul progetto:
1. Leggi CLAUDE.md, PROMPT_INIZIALE_CLAUDE.md e docs/PRODUCT_DISCOVERY.md.
2. **Non scrivere codice di prodotto e non iniziare M0 subito.**
3. Fai all'utente un questionario sostanzioso e ben strutturato per comprendere esattamente il software desiderato.
4. **Devi usare il tool nativo `AskUserQuestion` di Claude Code per consentire all'utente di selezionare le risposte. Non presentare tutte le domande come testo libero né chiedere di copiare un elenco di risposte in chat.**
5. Poni soltanto 3–4 domande per chiamata a `AskUserQuestion`, con 2–4 opzioni chiare per domanda. Usa selezione singola o multipla in base al caso, descrizioni brevi e l'opzione nativa per risposta personalizzata. Includi, quando utile, «Non lo so, consigliami» o «Decidi più avanti».
6. Procedi per sezioni e per piccoli gruppi interattivi; adatta il gruppo successivo alle risposte precedenti, mostra una sintesi delle scelte alla fine di ogni sezione e consenti correzioni. Le risposte devono essere registrate e non richieste nuovamente.
7. Copri almeno: obiettivi e casi d'uso, controllo vocale/testuale, applicazioni e siti supportati, automazioni browser, acquisti/ordini e conferme, file e operazioni distruttive, email/messaggi/prenotazioni, privacy e credenziali, modalità offline, interfaccia, startup, hotkey, limiti di autonomia, installer, aggiornamenti e costi.
8. Non chiedere informazioni ricavabili direttamente dal PC in modo sicuro (hardware, versione Windows, toolchain); queste si rilevano dopo, in M0. Non ripetere le domande a cui l'utente ha già risposto. Accetta risposte parziali.
9. Dopo le risposte, prepara docs/REQUIREMENTS.md con requisiti funzionali, livelli di rischio/consenso, priorità, esclusioni, casi di accettazione e scelte ancora aperte. Riassumi la specifica e chiedi all'utente di verificarla prima di passare a M0.
10. Solo dopo il consenso/conferma della specifica si passa a M0. La conferma riguarda la specifica di progetto, non autorizza automaticamente acquisti, invii o azioni reali eseguite dal software futuro.

## Cosa significa «automazione generale»

Non ridurre il prodotto a un launcher. Progetta un catalogo estensibile di capacità e connettori per:
- Applicazioni desktop Windows.
- Browser e siti web.
- File e cartelle.
- Diagnostica e monitoraggio.
- Workflow composti da più azioni.
- Compilazione di moduli e raccolta di informazioni.
- Preparazione di acquisti, prenotazioni e altri workflow transazionali, sempre con conferma umana prima dell'atto finale.

Non promettere che qualunque app o sito funzionerà senza integrazione specifica. Crea una matrice delle capacità: supportato, parzialmente supportato, non supportato, prerequisiti e limiti. Preferisci API ufficiali quando disponibili, altrimenti automazione browser/UI accessibile e testata. Non aggirare paywall, CAPTCHA, MFA, anti-frode, controlli accesso o restrizioni del servizio.

## Regole di sicurezza e conferma

Classifica ogni azione con un livello di rischio:
- **R0 — Lettura/apertura:** può essere eseguita automaticamente se il target è certo.
- **R1 — Reversibile:** può essere eseguita secondo le preferenze configurate, con riepilogo e possibilità di annullamento dove esiste.
- **R2 — Esterno o con conseguenze:** inviare messaggi/email, pubblicare, prenotare, acquistare, pagare, eliminare o condividere richiede conferma specifica immediatamente prima dell'azione finale.
- **R3 — Privilegi elevati/sicurezza:** mai aggirare UAC o chiedere privilegi in modo nascosto. Le azioni non supportate da utente standard devono essere escluse o presentate come passaggio manuale opzionale.

Per un acquisto online, prima della conferma mostra: negozio, articolo e variante, quantità, prezzo unitario, spedizione, imposte se note, totale, indirizzo/destinazione in forma non eccessivamente esposta, data di consegna se disponibile e metodo di pagamento non sensibile. La conferma deve riferirsi a quella transazione specifica. Se prezzo, quantità, indirizzo, metodo o totale cambiano, invalidare la conferma e richiederla di nuovo.

Non memorizzare password, CVV o numeri completi di carte. Preferire sessioni e password manager già gestiti dall'utente; fermarsi per CAPTCHA, MFA, autenticazione, verifica antifrode e passaggi che richiedono interazione umana. Non completare un acquisto o inviare denaro senza consenso esplicito e aggiornato.

## Sicurezza esecutiva

- Nessun testo riconosciuto diventa codice shell/PowerShell arbitrario.
- L'intento seleziona azioni tipizzate e registrate con parametri convalidati.
- Non concatenare input libero dentro stringhe di comando.
- Ogni workflow deve avere piano/stato, log locale, timeout, gestione errori e cancellazione quando possibile.
- Chiedere conferma quando il target o il significato sono ambigui.
- Non cancellare, inviare, acquistare o modificare dati senza le conferme previste.
- Nessun bypass dei controlli di Windows o dei siti.
- Nessun segreto, token, password, cronologia browser o dato personale in Git.
- Preferire funzionamento locale e nessun servizio cloud/API a pagamento obbligatori.

## Performance

L'obiettivo sotto i 2 secondi riguarda il dispatch delle azioni semplici una volta terminato il comando; va misurato. Non promettere che siti o applicazioni esterne completino in due secondi le proprie operazioni. Il motore deve mostrare progressi per workflow lunghi e non bloccare la UI.

Misura separatamente riconoscimento voce, interpretazione, pianificazione, conferma, dispatch, completamento e verifica del risultato.

## Processo

Fasi obbligatorie:
- **D0:** questionario approfondito.
- **D1:** specifica dei requisiti, revisione con l'utente.
- **M0:** verifica tecnica di stack, licenze, prestazioni, integrazioni e rischi.
- **M1+ :** implementazione progressiva per capacità prioritarie.

Non saltare D0/D1. L'utente ha chiesto espressamente che Claude faccia molte domande prima di sviluppare.

## Qualità

- Usa .NET/C# e WPF come ipotesi iniziale, non come scelta irrevocabile prima della verifica.
- Moduli isolati per host, audio, intenti, pianificatore workflow, registro azioni, connettori app/browser, file, diagnostica e telemetria.
- Ogni capacità deve avere test, logging, gestione errori e criteri di accettazione.
- Correggere errori e avvisi significativi; non silenziarli indiscriminatamente.
- Commit piccoli e descrittivi; prima di commit/push verificare diff e stato Git.
- Non dichiarare funzioni o test completati senza prove reali.

## Conclusione di ogni fase

Riferire attività, file, test, metriche, problemi aperti e fase successiva. Distinguere sempre tra implementato, testato, parzialmente supportato e non supportato.
