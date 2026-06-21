# Comandi manuali (controllo granulare)

`scripts/audible-convert.sh` copre il caso comune (download + conversione
standard in `.m4b`, naming automatico). Usa questi comandi solo se serve
personalizzare il naming scheme, la struttura di output, o eseguire i
passaggi singolarmente per debug.

## Installazione di audible-cli

Riferimento ufficiale: https://github.com/mkb79/audible-cli

```bash
uv tool install audible-cli
```

Se `uv` non è installato:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env
```

## Esportare/elencare la libreria

```bash
audible library export --output library.tsv   # .tsv con tutta la libreria (metadati serie/genere)
audible library list                           # elenco rapido ASIN + titolo
```

## Download di un singolo audiobook

```bash
audible download \
  --aaxc \
  --cover \
  --cover-size 1215 \
  --chapter \
  --filename-mode asin_only \
  --no-confirm \
  -a <ASIN>
```

| Flag | Descrizione |
|---|---|
| `--aaxc` | Scarica il file audio criptato `.aaxc` **e il `.voucher`** con chiave/iv di decrittazione (non esiste un flag `--voucher` separato: è incluso automaticamente da `--aaxc`) |
| `--cover` | Scarica la copertina `.jpg` |
| `--cover-size 1215` | Risoluzione copertina (1215x1215 px, la più alta) |
| `--chapter` | Scarica il `.json` con i metadati dei capitoli |
| `--filename-mode asin_only` | Usa l'ASIN (senza titolo) come prefisso del nome file, es. `<ASIN>-AAX_44_128.aaxc`. Il suffisso di qualità/codec **non è eliminabile** e può variare: non assumere mai il nome file esatto, usa sempre un glob `<ASIN>*.aaxc` |
| `--no-confirm` (`-y`) | Salta il prompt di conferma interattivo, necessario per esecuzione autonoma |
| `-a <ASIN>` | ASIN del libro (es. `B08G9PRS1K`), si trova nell'URL della pagina Audible dopo `/pd/`, o con `audible library list` |

Output nella directory corrente (il suffisso `-AAX_44_128` dipende dalla
qualità scaricata e può variare):

```
.
├── B08G9PRS1K-AAX_44_128.aaxc     # Audio criptato
├── B08G9PRS1K-AAX_44_128.voucher  # Chiave di decrittazione (JSON), incluso da --aaxc
├── B08G9PRS1K_(1215).jpg          # Copertina alta risoluzione
└── B08G9PRS1K-chapters.json       # Metadati capitoli
```

## Installazione di AAXtoMP3

Usa sempre il fork `Samuel88/AAXtoMP3` (non l'originale): rimuove la
dipendenza da `mp4art`/`mp4chaps` (deprecati, non più disponibili via apt) ed
embedda capitoli e copertina in un unico passaggio `ffmpeg`, con un parser
robusto per `.chapters.txt` e supporto completo a `--use-audible-cli-data`.

```bash
git clone https://github.com/Samuel88/AAXtoMP3.git
chmod +x AAXtoMP3/AAXtoMP3
```

## Conversione in .m4b

Comando base (verifica sempre il nome esatto del file con
`ls <ASIN>*.aaxc` prima, non assumerlo):

```bash
./AAXtoMP3/AAXtoMP3 \
  --use-audible-cli-data \
  -e:m4b \
  --single \
  B08G9PRS1K-AAX_44_128.aaxc
```

| Flag | Descrizione |
|---|---|
| `--use-audible-cli-data` | Usa il `.json` dei capitoli e il `.jpg` scaricati da audible-cli |
| `-e:m4b` | Output in formato `.m4b` (compatibile con Apple/Infuse/Jellyfin) |
| `--single` | Produce un file unico (non divide per capitolo) |

Con directory di output personalizzata:

```bash
./AAXtoMP3/AAXtoMP3 \
  --use-audible-cli-data \
  -e:m4b \
  --single \
  --target_dir ~/Musica/Audiobook \
  B08G9PRS1K-AAX_44_128.aaxc
```

Con naming scheme personalizzato:

```bash
./AAXtoMP3/AAXtoMP3 \
  --use-audible-cli-data \
  -e:m4b \
  --single \
  --dir-naming-scheme '$artist/$title' \
  --file-naming-scheme '$title' \
  B08G9PRS1K-AAX_44_128.aaxc
```

Struttura di output predefinita (relativa alla directory corrente o a
`--target_dir`):

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

> Nota: se non viene rilevato un genere nei metadati, AAXtoMP3 usa
> "Audiobook" come valore di default — se anche la directory di output di
> partenza si chiama "Audiobook" (come nel default dello script), il
> risultato è un'innocua doppia cartella `Audiobook/Audiobook/...`.

## Prerequisiti di sistema

```bash
sudo apt install -y jq mediainfo ffmpeg x264 x265 bc
sudo apt install -y python3-pip
```

| Tool | Uso |
|---|---|
| `ffmpeg` | Decodifica `.aaxc` e mux audio, capitoli e copertina |
| `ffprobe` | Legge metadati e durata dei file audio |
| `mediainfo` | Estrae narrator, descrizione e publisher |
| `jq` | Parsing del JSON dei capitoli scaricato da audible-cli |
| `bc` | Calcoli aritmetici in bash (durate capitoli) |
| `x264/x265` | Codec video (richiesti da alcune build di ffmpeg) |
