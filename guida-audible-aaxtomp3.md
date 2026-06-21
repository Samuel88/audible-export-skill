# Guida: Scaricare e Convertire Audiobook da Audible su Linux

Guida completa per scaricare audiobook da Audible in formato `.aaxc` e convertirli in `.m4b` con capitoli e copertina embedded, usando `audible-cli` e `AAXtoMP3`.

---

## 1. Prerequisiti di sistema

Installa le dipendenze necessarie:

```bash
sudo apt install jq mediainfo ffmpeg x264 x265 bc
sudo apt install python3-pip
```

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

### 2a. Autenticazione con Audible

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

---

## 3. Download dell'audiobook

### 3a. Esporta la libreria (consigliato)

Genera un `.tsv` con tutta la libreria. AAXtoMP3 lo usa per i metadati di serie e genere:

```bash
audible library export --output ~/Scaricati/library.tsv
```

### 3b. Elenca gli audiobook disponibili

```bash
audible library list
```

### 3c. Scarica il file audio con tutti i metadati

```bash
cd ~/Scaricati

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

Dopo il download avrai:

```
~/Scaricati/
├── B08G9PRS1K.aaxc            # Audio criptato
├── B08G9PRS1K.voucher          # Chiave di decrittazione (JSON)
├── B08G9PRS1K_1215.jpg         # Copertina alta risoluzione
└── B08G9PRS1K-chapters.json    # Metadati capitoli
```

---

## 4. Installazione di AAXtoMP3

Clona il fork `Samuel88/AAXtoMP3`, che include il fix per embedding di capitoli
e copertina in un singolo passaggio `ffmpeg` senza dipendenze da `mp4v2-utils`:

```bash
cd ~/Scaricati
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

```bash
cd ~/Scaricati

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

```
~/Scaricati/
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

Salva questo script come `~/Scaricati/audible-convert.sh` per scaricare e convertire
in un solo comando:

```bash
#!/usr/bin/env bash
# Uso:     ./audible-convert.sh <ASIN> [directory-output]
# Esempio: ./audible-convert.sh B08G9PRS1K ~/Musica/Audiobook

set -euo pipefail

ASIN="${1:?Errore: fornisci l'ASIN come primo argomento}"
OUTPUT_DIR="${2:-$HOME/Scaricati/Audiobook}"
WORK_DIR="$HOME/Scaricati"
SCRIPT_DIR="$HOME/Scaricati/AAXtoMP3"

mkdir -p "$OUTPUT_DIR"
cd "$WORK_DIR"

echo ">>> [1/2] Download da Audible: $ASIN"
audible download \
  --aaxc \
  --voucher \
  --cover \
  --cover-size 1215 \
  --chapter \
  --filename-mode asin_ascii \
  -a "$ASIN"

echo ">>> [2/2] Conversione in .m4b"
"$SCRIPT_DIR/AAXtoMP3" \
  --use-audible-cli-data \
  -e:m4b \
  --single \
  --target_dir "$OUTPUT_DIR" \
  "${ASIN}.aaxc"

echo ">>> Fatto! File salvato in: $OUTPUT_DIR"
```

```bash
chmod +x ~/Scaricati/audible-convert.sh

# Uso
~/Scaricati/audible-convert.sh B08G9PRS1K ~/Musica/Audiobook
```
