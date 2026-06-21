# Guida: Scaricare e Convertire Audiobook da Audible su Linux

Guida completa per scaricare audiobook da Audible in formato `.aaxc` e convertirli in `.m4b` con capitoli e copertina embedded, usando `audible-cli` e `AAXtoMP3`.

> **Nota per agenti AI (es. OpenClaw) che eseguono questa guida in autonomia:**
> tutti i passaggi sono scriptabili e idempotenti **tranne** l'autenticazione
> Audible iniziale (sezione 2b), che richiede una volta tanto credenziali
> Amazon reali e la risoluzione di un captcha da parte di un umano — nessun
> agente può completarla autonomamente. Verifica sempre prima lo stato del
> login con il comando della sezione 2a: se è già configurato, salta
> direttamente alla sezione 7, che contiene uno script unico, idempotente e
> con riepilogo finale parsabile in grado di scaricare e convertire uno o
> tutti gli audiolibri della libreria senza ulteriore intervento umano.

---

## 1. Prerequisiti di sistema

Installa le dipendenze necessarie:

```bash
sudo apt install -y jq mediainfo ffmpeg x264 x265 bc
sudo apt install -y python3-pip
```

> Il flag `-y` evita il prompt di conferma interattivo, necessario per
> eseguire questo comando in autonomia (es. da un agente AI).

| Tool        | Uso                                                          |
|-------------|--------------------------------------------------------------|
| `ffmpeg`    | Decodifica `.aaxc` e mux audio, capitoli e copertina         |
| `ffprobe`   | Legge metadati e durata dei file audio                       |
| `mediainfo` | Estrae narrator, descrizione e publisher                     |
| `jq`        | Parsing del JSON dei capitoli scaricato da audible-cli       |
| `bc`        | Calcoli aritmetici in bash (durate capitoli)                 |
| `x264/x265` | Codec video (richiesti da alcune build di ffmpeg)            |

---

## 2. Installazione di audible-cli

Riferimento ufficiale: https://github.com/mkb79/audible-cli

```bash
uv tool install audible-cli
```

> **Se non hai `uv` installato:**
> ```bash
> curl -LsSf https://astral.sh/uv/install.sh | sh
> source ~/.local/bin/env
> ```

### 2a. Verifica se il login è già stato effettuato

Prima di eseguire `audible quickstart`, controlla se esiste già un profilo
autenticato e funzionante, per evitare di ripetere l'autenticazione
inutilmente:

```bash
if [ -f ~/.audible/config.toml ] && audible library list >/dev/null 2>&1; then
  echo "LOGIN_OK: profilo già autenticato e funzionante."
else
  echo "LOGIN_MANCANTE: eseguire 'audible quickstart' (vedi sezione 2b)."
fi
```

- Se l'output è `LOGIN_OK`, salta la sezione 2b e procedi direttamente al
  punto 3 (download dell'audiobook).
- Se l'output è `LOGIN_MANCANTE`, esegui la procedura di autenticazione
  descritta nella sezione 2b.

### 2b. Autenticazione con Audible

```bash
audible quickstart
```

Il wizard è interattivo e pone i prompt esattamente in questo ordine. Segui la
tabella per rispondere senza errori (i valori tra `< >` sono di esempio, vanno
adattati al caso reale):

| # | Prompt (testo esatto)                                              | Risposta da dare                          | Note |
|---|----------------------------------------------------------------------|--------------------------------------------|------|
| 1 | `Please enter a name for your primary profile [audible]:`            | `<nome_profilo>` (es. `samuel`)            | Premere solo Enter per usare il default `audible` |
| 2 | `Enter a country code for the profile:`                               | `<country_code>` (es. `it`, `us`)          | Nessun default, va sempre digitato |
| 3 | `Please enter a name for the auth file [<nome_profilo>.json]:`       | Enter (vuoto)                              | Accetta il default `<nome_profilo>.json` |
| 4 | `Do you want to encrypt the auth file? [y/N]:`                        | `n` (o Enter)                              | `N` è il default, basta Enter |
| 5 | `Do you want to login with external browser? [y/N]:`                  | `y`                                        | **Obbligatorio `y`**: è il metodo di login richiesto da questa guida |
| 6 | `Do you want to login with a pre-amazon Audible account? [y/N]:`      | `n` (o Enter)                              | `N` è il default, basta Enter |
| 7 | `Do you want to continue? [y/N]:` (dopo il riepilogo in tabella)       | `y`                                        | Conferma definitiva di profilo/auth-file/country |
| 8 | `Please insert the copied url (after login):`                         | URL completo copiato dalla barra del browser dopo il login | Vedi procedura manuale sotto, **non automatizzabile** |

> **Sequenza di risposte sintetica per script/expect**, nell'ordine in cui
> compaiono i prompt y/n (escludendo i prompt che richiedono testo libero
> come nome profilo, country code e URL): `y` (browser esterno), `n` (pre-amazon),
> `y` (continua).

#### Procedura di login con browser esterno (passi 5-8, manuale)

Dopo aver risposto `y` al passo 5 e confermato il riepilogo al passo 7,
il wizard stampa un lungo URL Amazon (`https://www.amazon.<tld>/ap/signin?...`).
La procedura da seguire è:

1. Copiare l'URL stampato e aprirlo in un browser (anche su un altro dispositivo).
2. Effettuare il login con le credenziali Amazon associate all'account Audible.
3. Inserire username e password una seconda volta e risolvere il captcha richiesto.
4. Dopo il login il browser mostrerà una pagina di errore "Page not found":
   è il comportamento atteso, **non è un fallimento**.
5. Copiare l'URL completo dalla barra degli indirizzi di quella pagina di errore
   (inizia con `https://www.amazon.<tld>/ap/maplanding?...`).
6. Incollare quell'URL al prompt `Please insert the copied url (after login):`
   e premere Enter.

Questo passo richiede un'interazione umana reale (credenziali + captcha) e
**non può essere automatizzato end-to-end**; un agente AI può guidare l'utente
attraverso i passi 1-6 ma non può completarli autonomamente.

Se tutto va a buon fine, l'output finale è:

```
Successfully registered <Nome>'s <N>th Audible for iPhone.
Profile <nome_profilo> added to config
Config written to config.toml
```

Al termine vengono creati i file in `~/.audible/`:

```
~/.audible/
├── <nome_profilo>.json   # Credenziali e token del dispositivo registrato
└── config.toml           # Configurazione profilo audible-cli
```

### 2c. Test del login

Verifica che l'autenticazione sia andata a buon fine elencando la libreria:

```bash
audible library list
```

- **Successo:** viene stampata una tabella/elenco di audiobook posseduti
  (titolo, ASIN, autore...). Il login è confermato e funzionante.
- **Fallimento:** viene restituito un errore (es. `Profile not found`,
  errore di autenticazione/HTTP). In questo caso ripetere la sezione 2b
  oppure verificare il contenuto di `~/.audible/config.toml`.

---

## 3. Download dell'audiobook

### 3a. Esporta la libreria (consigliato)

Genera un `.tsv` con tutta la libreria. AAXtoMP3 lo usa per i metadati di serie e genere.
Esegui il comando nella directory di lavoro che preferisci (funziona in qualsiasi directory):

```bash
audible library export --output library.tsv
```

### 3b. Elenca gli audiobook disponibili

```bash
audible library list
```

### 3c. Scarica il file audio con tutti i metadati

Esegui il comando nella directory di lavoro scelta (i file vengono scaricati
nella directory corrente):

```bash
audible download \
  --aaxc \
  --voucher \
  --cover \
  --cover-size 1215 \
  --chapter \
  --filename-mode asin_ascii \
  -a <ASIN>
```

| Flag                         | Descrizione                                              |
|------------------------------|----------------------------------------------------------|
| `--aaxc`                     | Scarica il file audio criptato `.aaxc`                   |
| `--voucher`                  | Scarica il `.voucher` con chiave/iv di decrittazione     |
| `--cover`                    | Scarica la copertina `.jpg`                              |
| `--cover-size 1215`          | Risoluzione copertina (1215x1215 px, la più alta)        |
| `--chapter`                  | Scarica il `.json` con i metadati dei capitoli           |
| `--filename-mode asin_ascii` | Usa ASIN come nome file (più stabile del titolo)         |
| `-a <ASIN>`                  | ASIN del libro (es. `B08G9PRS1K`)                        |

> **Come trovare l'ASIN:** è il codice nell'URL della pagina Audible dopo `/pd/`,
> oppure lo si legge con `audible library list`.

Dopo il download avrai, nella directory corrente:

```
.
├── B08G9PRS1K.aaxc            # Audio criptato
├── B08G9PRS1K.voucher          # Chiave di decrittazione (JSON)
├── B08G9PRS1K_1215.jpg         # Copertina alta risoluzione
└── B08G9PRS1K-chapters.json    # Metadati capitoli
```

---

## 4. Installazione di AAXtoMP3

Clona il fork `Samuel88/AAXtoMP3`, che include il fix per embedding di capitoli
e copertina in un singolo passaggio `ffmpeg` senza dipendenze da `mp4v2-utils`.
Esegui il clone nella stessa directory di lavoro usata per il download
(o in qualsiasi altra directory, basta poi riferirsi al percorso corretto):

```bash
git clone https://github.com/Samuel88/AAXtoMP3.git
chmod +x AAXtoMP3/AAXtoMP3
```

> **Cosa include il fork rispetto all'originale:**
> - Rimossi `mp4art` e `mp4chaps` (deprecati, non più disponibili via apt)
> - Capitoli e copertina embedded in un unico passaggio `ffmpeg`
> - Parser robusto per `.chapters.txt` in formato OGM
> - Supporto completo a `--use-audible-cli-data`

---

## 5. Conversione in .m4b

### Comando base

Esegui il comando dalla directory in cui si trovano i file scaricati al
punto 3 (il file `.aaxc` va indicato con il percorso corretto se ti trovi
in una directory diversa):

```bash
./AAXtoMP3/AAXtoMP3 \
  --use-audible-cli-data \
  -e:m4b \
  --single \
  B08G9PRS1K.aaxc
```

| Flag                     | Descrizione                                                        |
|--------------------------|--------------------------------------------------------------------|
| `--use-audible-cli-data` | Usa il `.json` dei capitoli e il `.jpg` scaricati da audible-cli   |
| `-e:m4b`                 | Output in formato `.m4b` (compatibile con Apple/Infuse/Jellyfin)   |
| `--single`               | Produce un file unico (non divide per capitolo)                    |

### Con directory di output personalizzata

```bash
./AAXtoMP3/AAXtoMP3 \
  --use-audible-cli-data \
  -e:m4b \
  --single \
  --target_dir ~/Musica/Audiobook \
  B08G9PRS1K.aaxc
```

### Con naming scheme personalizzato

```bash
./AAXtoMP3/AAXtoMP3 \
  --use-audible-cli-data \
  -e:m4b \
  --single \
  --dir-naming-scheme '$artist/$title' \
  --file-naming-scheme '$title' \
  B08G9PRS1K.aaxc
```

### Struttura dell'output

Relativa alla directory corrente (o a `--target_dir` se specificata):

```
.
└── Audiobook/
    └── <Genere>/
        └── <Autore>/
            └── <Titolo>/
                ├── <Titolo>.m4b           # Audiobook finale con capitoli e cover
                ├── <Titolo>.jpg           # Copertina (copia)
                └── <Titolo>.chapters.txt  # File capitoli OGM (di servizio)
```

---

## 6. Verifica del risultato

### Controlla capitoli e titoli

```bash
ffprobe -i "Audiobook/<Autore>/<Titolo>/<Titolo>.m4b" \
  -print_format json \
  -show_chapters \
  2>/dev/null | jq '.chapters[] | {id, start_time, end_time, title: .tags.title}'
```

Output atteso:

```json
{ "id": 0, "start_time": "0.000",   "end_time": "133.072", "title": "Capitolo 1" }
{ "id": 1, "start_time": "133.072", "end_time": "717.169", "title": "Capitolo 2" }
```

### Controlla metadati generali

```bash
ffprobe -i "Audiobook/<Autore>/<Titolo>/<Titolo>.m4b" \
  -print_format json -show_format \
  2>/dev/null | jq '.format.tags'
```

### Controlla copertina embedded

```bash
ffprobe -i "Audiobook/<Autore>/<Titolo>/<Titolo>.m4b" \
  -show_streams 2>/dev/null | grep codec_type
```

Output atteso: `codec_type=audio` e `codec_type=video` (la copertina).

---

## 7. Script di automazione

Salva questo script come `audible-convert.sh` nella directory di lavoro che
contiene (o conterrà) la cartella `AAXtoMP3` clonata al punto 4. Lo script
funziona indipendentemente da dove si trova questa directory: usa sempre la
propria posizione come riferimento, non un percorso fisso.

Caratteristiche pensate per l'esecuzione autonoma da parte di un agente AI:

- **Preflight check**: verifica che `audible`, `ffmpeg`, `jq` esistano e che
  il login Audible sia configurato e funzionante *prima* di fare qualsiasi
  cosa. Se il login manca, esce immediatamente con `exit 1` e un messaggio
  che indica di eseguire `audible quickstart` (sezione 2b, unico passaggio
  che richiede un umano) — non tenta in alcun modo di automatizzarlo.
- **Auto-setup di AAXtoMP3**: se la cartella `AAXtoMP3` non esiste, la clona
  automaticamente (sezione 4 inclusa, non serve eseguirla a parte).
- **Idempotenza**: ogni ASIN completato con successo viene marcato in
  `.audible-convert-state/<ASIN>.done`. Rilanciare lo script (anche più
  volte, anche in batch) salta i libri già fatti senza riscaricare o
  riconvertire nulla.
- **Due modalità**: un singolo ASIN, oppure `--all` per scaricare e
  convertire automaticamente tutta la libreria Audible non ancora
  processata (usa `audible library export` per ottenere la lista di ASIN).
- **Isolamento errori in batch**: se un libro fallisce (download o
  conversione), viene segnato come errore e lo script continua con i
  successivi, invece di interrompersi.
- **Riepilogo finale parsabile**: l'ultima riga è sempre nel formato
  `SUMMARY completed=<N> failed=<M>`, seguita da una riga `FAILED_ASIN=<asin>`
  per ogni libro fallito. Il codice di uscita è `0` solo se `failed=0`.

```bash
#!/usr/bin/env bash
# Uso:
#   ./audible-convert.sh <ASIN> [directory-output]   # un singolo libro
#   ./audible-convert.sh --all [directory-output]     # tutta la libreria non ancora completata
#
# Esempi:
#   ./audible-convert.sh B08G9PRS1K ~/Musica/Audiobook
#   ./audible-convert.sh --all ~/Musica/Audiobook
#
# Nota: niente "set -e" globale. Ogni comando critico viene controllato
# esplicitamente in modo da poter isolare il fallimento di un singolo
# libro in modalità --all senza interrompere l'intero batch.
set -uo pipefail

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$WORK_DIR/AAXtoMP3"
STATE_DIR="$WORK_DIR/.audible-convert-state"

log()  { printf '[%s] %s\n' "$1" "$2"; }
fail() { log "ERROR" "$1"; exit 1; }

# --- Preflight: dipendenze e login --------------------------------------

command -v audible >/dev/null 2>&1 || fail "audible-cli non trovato. Esegui: uv tool install audible-cli"
command -v ffmpeg  >/dev/null 2>&1 || fail "ffmpeg non trovato. Esegui: sudo apt install -y ffmpeg"
command -v jq      >/dev/null 2>&1 || fail "jq non trovato. Esegui: sudo apt install -y jq"

if [ ! -f ~/.audible/config.toml ] || ! audible library list >/dev/null 2>&1; then
  fail "Login Audible non configurato o non funzionante. Esegui 'audible quickstart' (richiede credenziali Amazon + captcha, intervento umano obbligatorio, vedi sezione 2b della guida), poi rilancia questo script."
fi

if [ ! -x "$SCRIPT_DIR/AAXtoMP3" ]; then
  log "INFO" "AAXtoMP3 non trovato in $SCRIPT_DIR, clono il fork"
  git clone https://github.com/Samuel88/AAXtoMP3.git "$SCRIPT_DIR" || fail "clone di AAXtoMP3 fallito"
  chmod +x "$SCRIPT_DIR/AAXtoMP3"
fi

mkdir -p "$STATE_DIR"

# --- Argomenti -----------------------------------------------------------

MODE="${1:?Errore: fornisci un ASIN oppure --all come primo argomento}"
OUTPUT_DIR="${2:-$WORK_DIR/Audiobook}"
mkdir -p "$OUTPUT_DIR"

# --- Elabora un singolo ASIN (idempotente) --------------------------------

process_asin() {
  local asin="$1"
  local marker="$STATE_DIR/${asin}.done"

  if [ -f "$marker" ]; then
    log "SKIP" "$asin: già completato in precedenza"
    return 0
  fi

  cd "$WORK_DIR"

  if [ ! -f "${asin}.aaxc" ]; then
    log "INFO" "$asin: download in corso"
    if ! audible download \
        --aaxc --voucher --cover --cover-size 1215 --chapter \
        --filename-mode asin_ascii -a "$asin"; then
      log "ERROR" "$asin: download fallito"
      return 1
    fi
  else
    log "INFO" "$asin: file .aaxc già presente, salto il download"
  fi

  log "INFO" "$asin: conversione in .m4b"
  if ! "$SCRIPT_DIR/AAXtoMP3" \
      --use-audible-cli-data -e:m4b --single \
      --target_dir "$OUTPUT_DIR" "${asin}.aaxc"; then
    log "ERROR" "$asin: conversione fallita"
    return 1
  fi

  touch "$marker"
  log "OK" "$asin: completato -> $OUTPUT_DIR"
}

# --- Esecuzione: singolo ASIN o intera libreria ---------------------------

FAILED=()
DONE=0

if [ "$MODE" = "--all" ]; then
  TSV="$WORK_DIR/library.tsv"
  audible library export --output "$TSV" || fail "esportazione libreria fallita"

  ASIN_COL=$(head -1 "$TSV" | awk -F'\t' '{for(i=1;i<=NF;i++) if($i=="asin") print i}')
  [ -n "$ASIN_COL" ] || fail "colonna 'asin' non trovata in $TSV"

  while IFS=$'\t' read -r -a row; do
    asin="${row[$((ASIN_COL-1))]}"
    [ -n "$asin" ] || continue
    if process_asin "$asin"; then
      DONE=$((DONE+1))
    else
      FAILED+=("$asin")
    fi
  done < <(tail -n +2 "$TSV")
else
  if process_asin "$MODE"; then
    DONE=$((DONE+1))
  else
    FAILED+=("$MODE")
  fi
fi

# --- Riepilogo finale (formato fisso, parsabile da un agente) -------------

echo "SUMMARY completed=$DONE failed=${#FAILED[@]}"
for asin in "${FAILED[@]:-}"; do
  [ -n "$asin" ] && echo "FAILED_ASIN=$asin"
done

[ "${#FAILED[@]}" -eq 0 ]
```

```bash
chmod +x ./audible-convert.sh

# Uso (eseguito dalla directory in cui si trova lo script)
./audible-convert.sh B08G9PRS1K ~/Musica/Audiobook   # un solo libro
./audible-convert.sh --all ~/Musica/Audiobook         # tutta la libreria
```
