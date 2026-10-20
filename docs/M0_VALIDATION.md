# M0 — Piano di validazione tecnica

## Scopo

Verificare le scelte tecniche prima di implementare l'applicazione completa. Non presentare stime come risultati misurati.

## Inventario ambiente

Rilevare senza elevazione, quando disponibile:
- Versione Windows e architettura.
- CPU e RAM.
- GPU e versione driver.
- Dischi e spazio libero.
- Microfoni e dispositivo audio predefinito.
- Versioni di .NET SDK, Git e strumenti di build.
- Disponibilità degli strumenti locali necessari alle prove.

Non acquisire né pubblicare identificativi personali non necessari.

## Verifica dipendenze

Per ogni dipendenza proposta, registrare:
- Nome e versione corrente verificata.
- Fonte ufficiale.
- Licenza del codice.
- Licenza del modello, se differente.
- Requisiti runtime e dimensioni.
- Attività/manutenzione osservabile.
- Compatibilità Windows e C#.
- Eventuali costi o servizi online.
- Decisione: adottare, confrontare ancora, oppure scartare.

## Riconoscimento vocale

Preparare un corpus di almeno 30 comandi reali, con 3–5 ripetizioni ciascuno in condizioni diverse. Non salvare registrazioni senza consenso esplicito.

Misurare:
- Percentuale di testo riconosciuto correttamente.
- Percentuale di intenti risolti correttamente.
- Falsi positivi su silenzio e frasi non pertinenti.
- Latenza finale del riconoscimento.
- RAM utilizzata a motore caricato.
- Dimensione totale dei file necessari.

Valutare Vosk con grammatica ristretta e un'alternativa locale; scegliere con dati misurati sul PC reale.

## Latenza

Separare:
- Fine comando (rilascio push-to-talk o fine parlato rilevata).
- Fine ASR.
- Risoluzione intento.
- Dispatch handler.
- Ritorno API/process start.
- Comparsa finestra visibile, quando misurabile.

Eseguire test ripetibili con WAV e azioni di prova innocue. Riportare p50, p95, massimo e numero campioni. Il target di 2 secondi riguarda il dispatch delle azioni semplici; non garantisce il tempo di avvio della finestra esterna.

## Chrome

Per la cronologia:
- Verificare posizione del profilo e gestione dei profili multipli.
- Copiare il database e gli eventuali file ausiliari necessari.
- Aprire la copia in sola lettura.
- Verificare che l'originale non sia modificato.
- Convertire correttamente i timestamp UTC/Chrome in data locale.

Per il ripristino di sessione:
- Valutare un'estensione locale opzionale con permessi minimi.
- Documentare permessi, installazione manuale e limiti.
- Non tentare installazione silenziosa o policy amministrativa.

## Diagnostica

Per ciascuna metrica definire fonte, unità, intervallo, disponibilità da utente standard e affidabilità. Le metriche non accessibili devono risultare non disponibili, mai stimate arbitrariamente.

FPS/frame time e temperature dipendono da strumenti e hardware: verificarne compatibilità e privilegi separatamente.

## Rapporto richiesto

Creare docs/M0_REPORT.md con:
1. Data e ambiente delle prove.
2. Fonti verificate e data della consultazione.
3. Test eseguiti e comandi usati.
4. Risultati misurati e campione.
5. Stime separate dai risultati reali.
6. Dipendenze raccomandate e motivazione.
7. Rischi e limiti.
8. Architettura raccomandata.
9. Milestone aggiornate e criteri di accettazione.

Se una prova richiede un componente non disponibile, segnalarlo come non eseguito e spiegare come svolgerla sul PC di destinazione.
