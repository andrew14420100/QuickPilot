# M0 — Piano di validazione tecnica

## Prerequisito

M0 si avvia **solo dopo D0 (questionario) e D1 (specifica confermata)**. Non sostituisce la raccolta requisiti con una decisione tecnica prematura.

## Scopo

Verificare architettura, stack, dipendenze, capacità cross-app e rischi prima dello sviluppo esteso. Non presentare stime come misure.

## Inventario ambiente

Rilevare senza elevazione, quando disponibile:
- Versione Windows e architettura.
- CPU e RAM.
- GPU e versione driver.
- Dischi e spazio libero.
- Microfoni e dispositivo audio predefinito.
- Versioni di .NET SDK, Git e strumenti di build.
- Browser e strumenti disponibili.
- Disponibilità degli strumenti locali per le prove.

Non raccogliere né pubblicare identificativi personali non necessari.

## Verifica dipendenze

Per ogni dipendenza proposta, registrare:
- Nome e versione corrente verificata.
- Fonte ufficiale.
- Licenza codice e licenza modello se differente.
- Requisiti runtime e dimensioni.
- Stato di manutenzione osservabile.
- Compatibilità Windows/C#.
- Eventuali costi o servizi online.
- Decisione e motivazione.

## Comandi veloci e riconoscimento vocale

Preparare almeno 30 comandi con 3–5 ripetizioni in condizioni diverse, se possibile. Non salvare registrazioni senza consenso esplicito.

Misurare:
- accuratezza trascrizione;
- accuratezza intenti;
- falsi positivi;
- latenza ASR;
- memoria e spazio;
- tempo intent-to-dispatch.

Confrontare motori offline e grammatica ristretta sul PC reale. Non dichiarare un test vocale completato senza aver usato davvero il microfono del PC di destinazione.

## Browser e automazioni multi-step

Selezionare inizialmente browser e siti in base alle risposte D0/D1. Per ogni integrazione:
- documentare interfacce disponibili e termini/restrizioni pertinenti;
- verificare accessibilità, DOM/API e stabilità;
- definire autenticazione e interventi manuali;
- definire timeout, verifica dell'esito e recovery;
- usare ambienti di test o dati innocui dove possibile;
- non automatizzare transazioni reali durante benchmark.

Non assumere che un sito sia stabile o automatizzabile solo perché si può aprire nel browser.

## Transazioni e acquisti

Definire e testare un modello di conferma:
- riepilogo dei dati correnti;
- conferma legata a singola transazione;
- invalidazione del consenso se i dettagli cambiano;
- prevenzione dei doppi invii in retry;
- log senza credenziali o dati di pagamento sensibili;
- passaggio manuale per CAPTCHA, MFA e antifrode;
- nessun click finale reale in test automatizzati.

## Diagnostica

Per ogni metrica definire fonte, unità, disponibilità come utente standard e affidabilità. Metriche non accessibili devono risultare indisponibili e mai inventate. FPS, frame time e temperature vanno verificati separatamente per hardware e strumenti.

## Packaging

Verificare modalità portable e installer per utente senza elevazione per le funzioni ordinarie. Documentare requisiti, dimensioni, SmartScreen e componenti da scaricare. Non promettere che SmartScreen non avvisi un eseguibile non firmato.

## Rapporto richiesto

Creare docs/M0_REPORT.md con:
1. Data e ambiente delle prove.
2. Fonti aggiornate e versioni verificate.
3. Test realmente eseguiti e risultati.
4. Stime separate da misure.
5. Capacità e connettori raccomandati.
6. Limiti, rischi, costi e prerequisiti.
7. Architettura motivata.
8. Roadmap e criteri di accettazione aggiornati.
9. Prove ancora da eseguire sul PC reale.

Se una prova non è possibile, dichiarare il motivo e la procedura per completarla in modo riproducibile.
