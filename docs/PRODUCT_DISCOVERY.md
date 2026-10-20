# D0 — Questionario di raccolta requisiti

## Istruzioni per Claude Code

Prima di fare analisi tecnica o scrivere codice, poni all'utente le domande sotto. Sono intenzionalmente numerose perché Quick Pilot dovrà essere una piattaforma di automazione generale, non soltanto un launcher.

- Mostra le domande raggruppate in sezioni brevi e numerate.
- Non chiedere dati hardware o dettagli tecnici che si possono rilevare in modo non invasivo durante M0.
- Accetta risposte parziali; per le decisioni sconosciute proponi un valore predefinito sicuro.
- Non ripetere informazioni già note: Windows 11 Pro, uso personale, costo-obiettivo zero euro di servizi obbligatori, RTX 5070 Ti 16 GB, microfono Sound Blaster Katana V2X, preferenza per installer per utente e versione portable, desiderio di automazioni veloci, possibilità di operazioni online con conferma.
- Se le risposte aprono ulteriori scelte veramente importanti, chiedi un secondo giro conciso.
- Non programmare dopo il questionario finché non hai prodotto una specifica e l'utente non l'ha verificata.

## A. Obiettivo e ampiezza

1. Quali sono le 5 azioni che vuoi poter chiedere più spesso? Descrivile con frasi realistiche che diresti a voce.
2. Vuoi che Quick Pilot possa coordinare quasi tutte le attività del PC oppure preferisci partire da categorie precise e ampliare gradualmente?
3. Quali priorità hanno queste categorie: applicazioni Windows, browser/siti, file/cartelle, acquisti online, email/messaggi, calendario/prenotazioni, diagnostica PC/gaming, documenti e fogli di calcolo, sviluppo software?
4. Quick Pilot deve solo eseguire comandi espliciti oppure anche proporre automaticamente il prossimo passo quando capisce l'obiettivo?
5. Quando non capisce una richiesta, preferisci che chieda chiarimenti, mostri due o tre interpretazioni possibili, oppure faccia un piano che tu possa modificare?

## B. Modalità d'interazione e velocità

6. Quali modalità vuoi al lancio: voce push-to-talk, un tasto per iniziare e fine parlato automatica, testo, scorciatoia globale, pulsante flottante? Puoi sceglierne più di una.
7. Vuoi che il programma ascolti sempre una parola di attivazione, oppure preferisci che il microfono si attivi soltanto quando lo chiedi?
8. Vuoi una risposta vocale, un suono discreto, una notifica, oppure soltanto l'esecuzione silenziosa con un breve stato?
9. Per i comandi semplici, quale metrica rappresenta davvero la velocità: tempo dalla fine della frase al dispatch, tempo all'apertura visibile della finestra, o entrambi?
10. Durante i giochi o le chiamate, come vuoi attivarlo e ricevere notifiche senza interferire con mouse, tastiera, anti-cheat o microfono?

## C. Applicazioni, browser e siti

11. Quali browser vuoi supportare inizialmente (Chrome, Edge, Firefox o altro) e quale usi come principale?
12. Elenca le 10–20 applicazioni più importanti da controllare (ad esempio Steam, Discord, browser, programmi di lavoro). Le applicazioni devono essere rilevate automaticamente e poi personalizzate con alias?
13. Quali siti web vuoi automatizzare per primi? Indica esempi reali: negozi online, email, strumenti di produttività, servizi pubblici, prenotazioni, social o altri.
14. Preferisci integrazioni specifiche per i siti più importanti, oppure un'automazione browser più generica che può essere meno affidabile e va testata sito per sito?
15. Accetti una piccola estensione locale del browser per gestire schede, sessioni e alcune automazioni? L'installazione iniziale manuale va bene?

## D. Acquisti, pagamenti e azioni esterne

16. Per un acquisto online, quale livello di autonomia vuoi? A) cerca e confronta soltanto; B) seleziona e prepara il carrello; C) compila il checkout e si ferma al riepilogo; D) esegue tutti i passaggi tecnici e si ferma prima del pulsante finale di ordine/pagamento. Puoi scegliere più di una in base al sito.
17. Quali dettagli devono comparire obbligatoriamente prima della conferma dell'ordine? Proposta: negozio, prodotto e variante, quantità, prezzo, spedizione, imposte note, totale, destinazione, consegna prevista e metodo di pagamento.
18. La parola «confermo» o «procedi» deve valere solo per l'operazione mostrata in quel momento, e deve essere richiesta di nuovo se prezzo, indirizzo, quantità o totale cambiano? Il progetto propone di sì per sicurezza.
19. Per email, messaggi, post, moduli e prenotazioni: vuoi che Quick Pilot prepari tutto e chieda conferma prima dell'invio finale? Ci sono eccezioni?
20. Per cancellare, sovrascrivere, spostare molti file o modificare impostazioni, preferisci sempre una anteprima e una conferma, oppure autorizzazioni configurabili in base al rischio?
21. Se un sito richiede login, password, passkey, MFA, CAPTCHA o verifica antifrode, accetti che Quick Pilot si fermi e lasci a te il completamento manuale? Il progetto non deve aggirare tali controlli.

## E. Privacy, dati e sicurezza

22. Quali dati può leggere: schede e cronologia browser, file selezionati, download, contenuto della finestra attiva, clipboard, email, documenti, dati di sistema? Segna anche quelli che vuoi escludere sempre.
23. Vuoi che cronologia e registro azioni restino esclusivamente sul PC? Per quanto tempo conservare i log e le sessioni?
24. Vuoi vietare del tutto l'invio di audio, schermate, testo o file a servizi online? Il requisito iniziale è privilegiare il locale e non avere servizi a pagamento obbligatori.
25. Vuoi che ogni azione compaia nel registro e abbia un pulsante Annulla quando tecnicamente possibile? Come preferisci gestire gli errori e i tentativi automatici?

## F. Intelligenza, autonomia ed estensibilità

26. Vuoi vietare sempre gli LLM, oppure accetti eventualmente un modello locale opzionale per capire richieste complesse, mantenendo tutte le azioni vincolate a un registro sicuro? I comandi veloci non devono attendere un LLM.
27. Vuoi poter creare tu nuove automazioni con un editor visuale a blocchi, oppure per la prima versione basta che Claude Code aggiunga nuove azioni e connettori tramite sviluppo?
28. Se un workflow fallisce a metà, preferisci che tenti automaticamente solo ripetizioni sicure, che torni allo stato precedente dove possibile, oppure che si fermi e ti chieda cosa fare?

## G. Interfaccia, installazione e aggiornamenti

29. Quale interfaccia preferisci: solo icona nella tray, piccolo pannello flottante, bolla discreta, dashboard completa o combinazione?
30. Quick Pilot deve avviarsi automaticamente con Windows e restare leggero in background? Vuoi modalità silenziosa e modalità gioco?
31. Vuoi soltanto la versione portable, un installer per utente senza privilegi amministrativi, oppure entrambe?
32. Vuoi aggiornamenti completamente manuali, oppure controlli di aggiornamento opzionali senza costi obbligatori?
33. Il software resta esclusivamente per te o vuoi prevedere in futuro la distribuzione ad altri utenti?

## H. Priorità della prima versione

34. Scegli le 5 capacità senza cui la prima versione non ti sarebbe utile.
35. Quale capacità può essere rimandata anche se sarebbe interessante?
36. Preferisci una prima versione piccola e davvero affidabile oppure un MVP più ampio con alcune integrazioni ancora limitate?
37. Quali errori sarebbero inaccettabili? Esempi: acquisto senza conferma, apertura del programma sbagliato, file eliminato, messaggio inviato alla persona errata, microfono sempre attivo senza indicazione.

## Dopo le risposte

Creare docs/REQUIREMENTS.md, con:
- requisiti funzionali e non funzionali;
- casi d'uso e priorità;
- modalità di interazione;
- matrice di app, siti e connettori;
- policy di rischio e consenso;
- vincoli di privacy e offline;
- target prestazionali;
- criteri di accettazione MVP;
- esclusioni, limiti e decisioni aperte.

Poi presentare una sintesi leggibile e chiedere all'utente di verificare la specifica. Soltanto dopo la verifica passare a M0.