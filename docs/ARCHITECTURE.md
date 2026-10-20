# Architettura proposta

Questa architettura è un punto di partenza da convalidare in M0, non una decisione irrevocabile prima dei test.

## Stack da valutare

- C# e .NET supportato a lungo termine.
- WPF per una UI desktop essenziale.
- NAudio/WASAPI per acquisizione audio, previa verifica compatibilità e licenza.
- Vosk italiano con grammatica ristretta come candidato iniziale; confrontare con alternative locali supportate e licenze correnti.
- SQLite per dati strutturati, se utile; JSON per preferenze semplici.
- Velopack o una distribuzione portable, dopo verifica di licenza e installazione per utente.
- API Windows per lancio applicazioni, directory conosciute e finestre.

La scelta definitiva dipende da prove reali su Windows e dai requisiti di packaging.

## Componenti logici

### Host
Gestisce avvio, area di notifica, lifetime dell'applicazione, impostazioni, hotkey e shutdown.

### Audio
Cattura audio solo quando autorizzato. L'audio non viene registrato su disco per impostazione predefinita.

### Speech
Traduce audio in testo usando un motore locale. Deve consentire di sostituire il motore senza riscrivere il resto.

### Intent
Normalizza frasi, riconosce modelli supportati e produce un oggetto tipizzato. Se la corrispondenza è ambigua, non esegue azioni.

### Command Registry
Mappa ID stabili a descrizioni, parametri consentiti, regole di sicurezza, handler e metadati di misurazione.

### Actions
Esegue solo azioni registrate: avviare app, aprire cartelle note, aprire URL convalidati e avviare diagnostiche read-only.

### Integrations
Contiene integrazioni isolate per Chrome, Windows Search e strumenti hardware. Le integrazioni non devono bloccare il thread UI.

### Diagnostics
Raccoglie metriche con fonte, timestamp, unità, disponibilità ed eventuale motivazione del dato mancante.

### Telemetry
Registra tempi e risultati locali. Niente telemetria remota automatica.

## Flusso comando

1. Il push-to-talk o l'input testuale raccoglie il comando.
2. Il riconoscimento vocale produce un testo locale.
3. Il parser risolve un intento e parametri tipizzati.
4. Il registro valida l'azione e i parametri.
5. L'handler esegue l'azione con API appropriate.
6. Il sistema registra durata ed esito e mostra una conferma discreta.

Il testo riconosciuto non diventa mai codice o shell command.

## Principi Windows

- Esecuzione come utente standard.
- Nessun bypass UAC.
- API e permessi minimi.
- Argomenti di processo passati separatamente, mai concatenati da input libero.
- Accesso ai dati browser attraverso copie temporanee e query in sola lettura.
- Le funzioni che richiedono privilegi speciali rimangono opzionali.
- Distinguere il tempo di dispatch dall'apertura visibile dell'app esterna.

## Dati locali

Conservare preferenze, alias, snapshot richiesti e log di diagnostica in cartelle utente appropriate. Prevedere limiti e rotazione per i log. Non conservare audio per impostazione predefinita.

## Sicurezza dei comandi

Ogni azione deve dichiarare:
- ID e descrizione.
- Schema dei parametri.
- Validatore.
- Classe di rischio.
- Handler tipizzato.
- Timeout e cancellazione, dove applicabili.
- Risultato e codice errore.

Non implementare esecuzione generica di script o shell come funzionalità della prima versione.
