---
name: audible-export
description: Scarica audiobook posseduti su Audible e li converte in file .m4b con capitoli, copertina e metadati embedded, usando audible-cli e il fork AAXtoMP3. Usa SEMPRE questa skill quando l'utente chiede di scaricare audiolibri/audiobook da Audible, automatizzare o scriptare il download della propria libreria Audible, convertire file .aaxc/.aax in .m4b/.mp3, configurare il login o l'autenticazione di audible-cli, lavorare con un ASIN Audible, o menziona AAXtoMP3 — anche se non usa esplicitamente la parola "Audible" ma descrive di voler scaricare, sincronizzare o convertire in autonomia i propri audiolibri posseduti.
---

# Audible Export

Scarica audiobook posseduti su Audible (formato `.aaxc` criptato) e li
converte in `.m4b` con capitoli, copertina e metadati embedded, usando
`audible-cli` per download/autenticazione e il fork
[`Samuel88/AAXtoMP3`](https://github.com/Samuel88/AAXtoMP3) per la
conversione. Tutta la pipeline è scriptabile e idempotente, tranne un
singolo passaggio iniziale che richiede un umano (vedi sotto).

## Percorso rapido

1. **Verifica se il login Audible è già configurato:**

   ```bash
   if [ -f ~/.audible/config.toml ] && audible library list >/dev/null 2>&1; then
     echo "LOGIN_OK"
   else
     echo "LOGIN_MANCANTE"
   fi
   ```

   Se `LOGIN_MANCANTE`, segui **`references/login-setup.md`** — è l'**unico
   passaggio di tutta la pipeline che richiede un umano reale** (credenziali
   Amazon + risoluzione di un captcha). Nessun agente può completarlo in
   autonomia: può solo guidare l'utente attraverso i passi manuali. È un
   costo one-time: una volta fatto, resta valido per tutti i download
   successivi, singoli o batch.

2. **Installa le dipendenze di sistema** (se non già presenti):

   ```bash
   sudo apt install -y jq mediainfo ffmpeg x264 x265 bc python3-pip
   uv tool install audible-cli   # se uv manca: curl -LsSf https://astral.sh/uv/install.sh | sh && source ~/.local/bin/env
   ```

3. **Una volta confermato `LOGIN_OK`, usa lo script incluso per fare tutto
   il resto in un solo comando:**

   ```bash
   chmod +x scripts/audible-convert.sh
   ./scripts/audible-convert.sh <ASIN> [directory-output]   # un singolo libro
   ./scripts/audible-convert.sh --all [directory-output]     # tutta la libreria non ancora scaricata
   ```

   Lo script (già testato end-to-end su un download reale):
   - controlla da solo dipendenze e login prima di fare qualsiasi cosa;
   - clona automaticamente AAXtoMP3 se manca;
   - è **idempotente**: marca ogni ASIN completato in
     `.audible-convert-state/<ASIN>.done` e salta i libri già fatti se
     rilanciato;
   - in modalità `--all` **isola gli errori per libro**: un libro fallito
     non blocca gli altri;
   - termina sempre con un riepilogo parsabile su una riga finale,
     `SUMMARY completed=<N> failed=<M>`, seguito da una riga
     `FAILED_ASIN=<asin>` per ogni libro fallito — l'exit code è `0` solo se
     `failed=0`.

   Eseguilo dalla cartella di questa skill (usa sempre la propria posizione
   come riferimento per trovare/creare `AAXtoMP3/`, non un percorso fisso).

## Cose non ovvie su `audible-cli`, verificate con un download reale

Senza queste correzioni il download o la conversione falliscono in modo
silenzioso o confuso — lo script le applica già, ma sono fondamentali da
sapere se devi eseguire comandi manuali (vedi sotto):

- **`--voucher` non esiste** come flag separato di `audible download`:
  `--aaxc` lo include già automaticamente.
- **`--filename-mode asin_ascii` non produce `<ASIN>.aaxc`**: include anche
  il titolo ASCII nel nome file. Usa `asin_only`.
- **Anche `asin_only` non garantisce un nome file esatto**: aggiunge sempre
  un suffisso di qualità/codec imprevedibile (es. `-AAX_44_128`). Non
  assumere mai il nome del file `.aaxc`/`.voucher`: cercalo sempre con un
  glob `<ASIN>*.aaxc`.
- **`--no-confirm` (`-y`)** è necessario per evitare il prompt di conferma
  interattivo quando il download viene eseguito da uno script o un agente
  non interattivo.

## Quando serve controllo manuale più fine

Lo script copre il caso comune (download + conversione standard in
`.m4b`). Se serve personalizzare il naming scheme, la struttura di
output, o eseguire i passaggi singolarmente per debug, vedi
`references/manual-commands.md` (include anche installazione manuale di
audible-cli e AAXtoMP3, ed export/elenco della libreria).

## Verifica del risultato

Per controllare che capitoli, metadati e copertina siano stati embedded
correttamente nel `.m4b` prodotto, vedi `references/verification.md`
(comandi `ffprobe`).
