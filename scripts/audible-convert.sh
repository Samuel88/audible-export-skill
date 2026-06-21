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
  fail "Login Audible non configurato o non funzionante. Esegui 'audible quickstart' (richiede credenziali Amazon + captcha, intervento umano obbligatorio, vedi references/login-setup.md), poi rilancia questo script."
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

  # Il nome reale del file .aaxc include un suffisso di qualità/codec
  # imprevedibile (es. "-AAX_44_128") anche con --filename-mode asin_only:
  # non va mai assunto, va sempre cercato con un glob.
  local aaxc_file
  aaxc_file=$(ls "${asin}"*.aaxc 2>/dev/null | head -n1 || true)

  if [ -z "$aaxc_file" ]; then
    log "INFO" "$asin: download in corso"
    if ! audible download \
        --aaxc --cover --cover-size 1215 --chapter \
        --filename-mode asin_only --no-confirm -a "$asin"; then
      log "ERROR" "$asin: download fallito"
      return 1
    fi
    aaxc_file=$(ls "${asin}"*.aaxc 2>/dev/null | head -n1 || true)
    if [ -z "$aaxc_file" ]; then
      log "ERROR" "$asin: nessun file .aaxc trovato dopo il download"
      return 1
    fi
  else
    log "INFO" "$asin: file .aaxc già presente ($aaxc_file), salto il download"
  fi

  log "INFO" "$asin: conversione in .m4b ($aaxc_file)"
  if ! "$SCRIPT_DIR/AAXtoMP3" \
      --use-audible-cli-data -e:m4b --single \
      --target_dir "$OUTPUT_DIR" "$aaxc_file"; then
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
