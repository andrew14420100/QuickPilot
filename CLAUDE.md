# Istruzioni permanenti per Claude Code — Quick Pilot

## Missione

Costruire Quick Pilot, un'applicazione Windows 11 locale per automatizzazioni deterministiche e veloci. Non è un chatbot e non è un assistente basato su LLM. Il percorso ordinario deve essere: comando riconosciuto → intento tipizzato → azione registrata → esito.

## Prima di lavorare

1. Leggi questo file, PROMPT_INIZIALE_CLAUDE.md e tutti i documenti in docs pertinenti alla milestone corrente.
2. Ispeziona lo stato Git, l'albero dei file, le versioni degli strumenti presenti e l'ambiente Windows.
3. Non presumere che una repository contenente specifiche sia già un'applicazione implementata.
4. Per le versioni e licenze che potrebbero essere cambiate, verifica fonti ufficiali aggiornate quando l'accesso web è disponibile. Se non puoi verificarle, dichiaralo chiaramente.
5. Non chiedere informazioni che puoi ricavare in modo sicuro dal PC. Non stampare credenziali, dati personali o contenuti sensibili durante la diagnostica.

## Regole non negoziabili

- Nessun LLM generativo nel percorso standard dei comandi.
- Nessun servizio cloud o API con costo obbligatorio.
- Niente testo riconosciuto eseguito come comando di shell o codice.
- Il testo riconosciuto seleziona esclusivamente azioni predefinite con parametri tipizzati e convalidati.
- Mai combinare input dell'utente in stringhe di comando arbitrarie. Preferire API e argomenti separati.
- L'applicazione deve operare come utente standard. Non aggirare UAC e non elevare privilegi in modo nascosto.
- Le funzioni amministrative o non disponibili senza privilegi devono rimanere opzionali e spiegare i propri limiti.
- Per i dati di Chrome, lavorare su copie temporanee del database e non modificare il profilo originale.
- Non inventare metriche, risultati, compatibilità o esiti dei test.
- Non cancellare, resettare o riscrivere dati esistenti senza necessità e autorizzazione.
- Non introdurre dipendenze senza verificarne compatibilità, manutenzione, licenza e utilità.
- Nessun segreto, token, password, cronologia browser o dati personali in Git.

## Strategia prestazionale

Misura separatamente:
- Tempo di fine cattura audio / rilascio del push-to-talk.
- Tempo del riconoscimento vocale.
- Tempo di risoluzione dell'intento.
- Tempo di dispatch dell'azione.
- Tempo fino alla comparsa visibile della finestra dell'app lanciata, quando misurabile.

L'obiettivo inferiore a 2 secondi riguarda il dispatch dei comandi semplici e deve essere validato con test ripetibili. Non promettere che ogni applicazione mostri la propria finestra entro 2 secondi: il suo avvio a freddo dipende dal programma e dal sistema.

## Lavoro per milestone

Lavora solo sulla milestone corrente:
1. Analisi e M0.
2. Core comandi scritti e lancio applicazioni.
3. Voce offline italiana.
4. File e cartelle.
5. Diagnostica rapida.
6. Cronologia Chrome.
7. Snapshot e ripristino sessioni tramite estensione opzionale.
8. Diagnostica gaming opzionale.
9. Packaging portable e installer per utente.

Ogni milestone deve avere piano, implementazione limitata, test, verifica dei risultati e aggiornamento dei documenti. Evita di costruire tutto contemporaneamente.

## M0 prima del prodotto

Non implementare ancora il prodotto completo. M0 deve produrre un rapporto con:
- Hardware e ambiente rilevati.
- Confronto tecnico delle opzioni pertinenti.
- Verifica corrente di versioni, licenze e requisiti.
- Rischi, limiti e dipendenze.
- Prove vocali e di latenza possibili nell'ambiente.
- Decisione proposta e criteri misurabili.
- Roadmap rivista, se necessaria.

Non inventare misurazioni se il microfono, l'hardware o l'ambiente di esecuzione non sono accessibili. Distingui chiaramente tra prove eseguite, stime e attività ancora da eseguire.

## Qualità

- Usa .NET e C# come ipotesi iniziale da validare in M0; non scegliere framework alternativi senza motivazione.
- Tieni separati host, audio, riconoscimento, intenti, azioni, integrazioni, diagnostica e telemetria.
- Aggiungi test unitari al parser e test d'integrazione alle azioni con effetti controllati.
- Esegui build, test e analisi dopo ogni cambiamento significativo.
- Correggi gli errori rilevati; non silenziarli indiscriminatamente.
- Aggiorna README, roadmap e report di test con i risultati effettivi.
- Usa commit piccoli e descrittivi. Prima dei commit controlla git diff e git status.

## Comportamento quando hai finito una fase

Riporta:
1. Cosa hai ispezionato o modificato.
2. Test eseguiti con comandi e risultati reali.
3. Metriche misurate e metodo usato.
4. Limiti e problemi aperti.
5. Percorsi dei file importanti.
6. Prossima milestone e criteri di completamento.

Non dichiarare completata una funzione non implementata o non verificata.
