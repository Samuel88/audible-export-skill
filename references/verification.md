# Verifica del risultato (.m4b)

Comandi `ffprobe` per controllare che capitoli, metadati e copertina siano
stati embedded correttamente nel file `.m4b` prodotto.

## Controlla capitoli e titoli

```bash
ffprobe -i "Audiobook/<Autore>/<Titolo>/<Titolo>.m4b" \
  -print_format json \
  -show_chapters \
  2>/dev/null | jq '.chapters[] | {id, start_time, end_time, title: .tags.title}'
```

Output atteso (un oggetto per capitolo):

```json
{ "id": 0, "start_time": "0.000",   "end_time": "133.072", "title": "Capitolo 1" }
{ "id": 1, "start_time": "133.072", "end_time": "717.169", "title": "Capitolo 2" }
```

## Controlla metadati generali

```bash
ffprobe -i "Audiobook/<Autore>/<Titolo>/<Titolo>.m4b" \
  -print_format json -show_format \
  2>/dev/null | jq '.format.tags'
```

## Controlla copertina embedded

```bash
ffprobe -i "Audiobook/<Autore>/<Titolo>/<Titolo>.m4b" \
  -show_streams 2>/dev/null | grep codec_type
```

Output atteso: `codec_type=audio` e `codec_type=video` (la copertina). Su un
audiobook con un solo capitolo, è normale vedere un solo oggetto in
`-show_chapters`.
