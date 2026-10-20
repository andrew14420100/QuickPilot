# M0 — Piano di misura della voce di risposta (JARVIS / CosyVoice 3)

Stato: **proposta tecnica, nessun codice e nessuna misura ancora eseguita.** Fa parte di M0 e non avvia M1.

## Decisione già presa dall'utente

- La **voce personalizzata di JARVIS** è la voce di risposta ufficiale di Quick Pilot. È generata localmente con CosyVoice 3 `Fun-CosyVoice3-0.5B`, il servizio già usato da JARVIS.
- Priorità: naturalezza e riconoscibilità della voce, con latenza ottimizzata.
- Nessuna API cloud e nessun servizio a pagamento obbligatorio.
- **ASR e TTS sono due cose distinte.** ASR (Parakeet/Whisper, benchmark B4) serve a capire i comandi; TTS (questa voce) serve a pronunciare le risposte. La scelta dell'ASR non cambia la voce.
- La configurazione funzionante di JARVIS e il file della voce personalizzata **non vanno modificati**. La voce non va ri-clonata né sostituita senza l'approvazione dell'utente.

Questa decisione aggiorna l'ipotesi iniziale del report M0 (voci OneCore come TTS principale). Le voci OneCore Cosimo ed Elsa, verificate in B2, restano utili come **riserva** e per generare i campioni sintetici B4.

## Cosa dicono le fonti (da verificare con misure)

- Il README ufficiale di CosyVoice dichiara il **bi-streaming** (testo in ingresso e audio in uscita a flusso) e una latenza «fino a 150 ms». Il dato non è accompagnato da hardware o metodo di misura, quindi **non è una promessa per questo PC**. [FunAudioLLM/CosyVoice](https://github.com/FunAudioLLM/CosyVoice)
- Il progetto offre esempi di server FastAPI e gRPC (in Docker) e il supporto vLLM e TensorRT-LLM. La documentazione ufficiale non tratta Windows. La licenza del codice è Apache-2.0; la licenza dei pesi va verificata sul model card prima di ogni redistribuzione (qui l'uso è solo personale e locale).

## Proposta: come ottimizzare senza cambiare la voce

1. **Riutilizzare JARVIS così com'è.**
   - Prima si legge, in sola lettura, come JARVIS carica oggi il modello e il riferimento vocale: percorso, formato (audio di riferimento più testo, oppure speaker embedding salvato), parametri.
   - Quick Pilot userà la stessa configurazione senza ri-clonare la voce.
   - Se JARVIS espone già un servizio locale, lo si interroga invece di caricare un secondo modello. Due istanze in VRAM sarebbero uno spreco, soprattutto durante il gioco.
2. **Servizio persistente.** Il modello resta caricato in un processo locale (solo `127.0.0.1`), così ogni risposta non paga il caricamento. Il tempo di caricamento si misura una volta sola, separato da quello di risposta.
3. **Streaming e riproduzione a blocchi.**
   - Il primo blocco audio va riprodotto appena è pronto.
   - La metrica principale è il **tempo al primo audio udibile**, non il tempo del WAV completo.
   - Per i riepiloghi R2, che sono lunghi, si possono usare frasi brevi in sequenza, così la prima parte parte subito.
4. **Cache solo per frasi fisse e non sensibili.**
   - Si possono pre-generare con la voce JARVIS brevi conferme standard, per esempio «Fatto», «Annullato», «Non ho capito, puoi ripetere?».
   - Non vanno in cache testi con importi, destinatari, nomi di file o altri dati personali: i riepiloghi R2 si generano sempre al momento.
   - La cache resta su D:, fuori da Git.
5. **Riserva.** Se il servizio CosyVoice non è disponibile o supera un timeout, una conferma breve può usare la voce OneCore. La scelta resta da confermare con l'utente, perché cambia la voce percepita.
6. **Altri motori solo se necessario.** Una voce CosyVoice non si trasferisce a motori diversi: un clone con un altro TTS non sarebbe identico. Si valuta solo se le misure mostrano limiti inaccettabili, e con l'approvazione dell'utente.

## Misure proposte (benchmark T1–T4, da preparare dopo il confronto ASR)

| # | Misura | Come | Note |
|---|---|---|---|
| T1 | Caricamento del modello (una tantum) | Avvio del servizio fino a «pronto» | Separato dalla latenza di risposta |
| T2 | **Latenza al primo blocco**, latenza totale, RTF | 10 frasi fisse non personali (corte, medie, riepilogo R2 di prova) × 5 ripetizioni, servizio già caldo, streaming acceso e spento | p50/p95; si misura anche il primo audio udibile in riproduzione |
| T3 | RAM, VRAM, CPU, GPU | Strumento B9 con `-ProcessName` sul processo del servizio, a riposo e durante la sintesi | Anche con il servizio caricato ma inattivo |
| T4 | Impatto in gioco | Prova B6 (PresentMon) con il servizio spento, caricato inattivo e attivo | Decide se scaricare il modello o tenerlo in modalità gioco |

Regole delle misure: niente testi personali, audio generato salvato solo su D:, nessuna modifica a JARVIS, nessun download o installazione senza consenso.

## Prerequisiti da chiarire con l'utente prima di T1–T4

1. Come gira oggi CosyVoice per JARVIS su questo PC. Già noto dall'utente: servizio locale sulla **porta 8765**. Da chiarire: Windows nativo o WSL/Docker, versione, GPU o CPU, protocollo ed endpoint del servizio, e se supporta già lo streaming.
2. Dove si trovano modello e riferimento vocale, così da leggerli senza spostarli.
3. Se Quick Pilot può interrogare il servizio di JARVIS (stessa istanza) o se serve un'istanza dedicata.

## Rischi

- **VRAM in gioco:** un modello TTS da 0,5B parametri su GPU compete con il gioco. Le misure T3/T4 decidono la politica (scaricare in modalità gioco, oppure CPU per le frasi brevi).
- **Supporto Windows di CosyVoice** non documentato ufficialmente: va verificato su come JARVIS lo esegue oggi.
- **Latenza:** nessun miglioramento viene promesso prima delle misure.
