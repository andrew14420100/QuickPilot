# Quick Pilot

Quick Pilot è un motore di automazione locale per Windows 11. L'obiettivo è eseguire comandi pratici il più velocemente possibile senza usare un modello linguistico generativo per ogni richiesta.

Il principio centrale è: **voce o testo → intento deterministico → azione registrata → risultato misurato**.

## Obiettivi

- Aprire applicazioni, cartelle e URL con comandi brevi.
- Riconoscere comandi vocali in italiano, inizialmente tramite push-to-talk.
- Consultare in sola lettura la cronologia locale di Chrome.
- Salvare e ripristinare snapshot di sessioni Chrome tramite un'estensione locale opzionale.
- Raccogliere diagnostiche del PC senza elevazione amministrativa dove Windows lo consente.
- Misurare latenza, accuratezza e affidabilità invece di dichiararle senza prove.
- Distribuire una versione portable e un installer per utente, senza UAC per le normali funzioni.

## Stato

Repository di specifiche e pianificazione. La prima attività è M0: verifica tecnica, versioni e licenze correnti, prova vocale sul PC reale e misurazioni iniziali. Non dichiarare prodotto implementato finché non esistono codice e test verificati.

## Come iniziare con Claude Code

1. Clona questa repository o apri la cartella locale collegata a questa repository.
2. Avvia Claude Code dalla radice del progetto.
3. Chiedigli di leggere per intero CLAUDE.md, PROMPT_INIZIALE_CLAUDE.md e i documenti in docs.
4. Claude deve iniziare con l'analisi e M0, non con la creazione frettolosa dell'intera applicazione.
5. Dopo il rapporto M0, procedere per milestone, mantenendo test e documentazione aggiornati.

## Documenti

- **CLAUDE.md** — istruzioni permanenti per Claude Code.
- **PROMPT_INIZIALE_CLAUDE.md** — prima attività da eseguire.
- **docs/ROADMAP.md** — fasi e criteri di completamento.
- **docs/ARCHITECTURE.md** — architettura di riferimento.
- **docs/M0_VALIDATION.md** — piano di prove tecniche e misurazioni.

## Principi

- Nessun servizio cloud o API a pagamento obbligatori.
- Nessun LLM nel percorso standard di esecuzione dei comandi.
- Nessuna esecuzione del testo riconosciuto come codice arbitrario.
- Nessun bypass dei controlli di sicurezza di Windows.
- Nessun privilegio amministrativo per apertura applicazioni e diagnostiche standard.
- Ogni metrica non disponibile deve essere dichiarata come non disponibile.
- Operazioni lunghe devono essere asincrone e non bloccare l'interfaccia.

## Licenze e costi

Prima di adottare una dipendenza, verificare la licenza corrente, l'attività del progetto, le versioni supportate e gli eventuali costi. Non aggiungere chiavi API o segreti al repository. La licenza del prodotto va decisa dopo la revisione delle dipendenze e dei requisiti di distribuzione.
