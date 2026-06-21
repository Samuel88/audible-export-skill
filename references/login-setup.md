# Setup del login Audible (unico passaggio non automatizzabile)

Questo è l'unico passaggio dell'intera pipeline che richiede un umano reale:
serve un login Amazon con credenziali vere e la risoluzione di un captcha.
Nessun agente AI può completarlo in autonomia — può solo guidare l'utente
attraverso i passi manuali. Una volta fatto, resta valido per tutte le
esecuzioni successive (download singoli o batch), quindi è un costo one-time.

## 1. Verifica se serve davvero

Prima di iniziare, controlla se esiste già un profilo autenticato e
funzionante:

```bash
if [ -f ~/.audible/config.toml ] && audible library list >/dev/null 2>&1; then
  echo "LOGIN_OK: profilo già autenticato e funzionante."
else
  echo "LOGIN_MANCANTE: serve eseguire 'audible quickstart' (vedi sotto)."
fi
```

Se `LOGIN_OK`, fermati qui: non serve altro.

## 2. Esegui il wizard

```bash
audible quickstart
```

Il wizard è interattivo e pone i prompt esattamente in questo ordine. Segui
la tabella per rispondere senza errori (i valori tra `< >` sono di esempio,
vanno adattati al caso reale):

| # | Prompt (testo esatto) | Risposta da dare | Note |
|---|---|---|---|
| 1 | `Please enter a name for your primary profile [audible]:` | `<nome_profilo>` (es. `samuel`) | Premere solo Enter per usare il default `audible` |
| 2 | `Enter a country code for the profile:` | `<country_code>` (es. `it`, `us`) | Nessun default, va sempre digitato |
| 3 | `Please enter a name for the auth file [<nome_profilo>.json]:` | Enter (vuoto) | Accetta il default `<nome_profilo>.json` |
| 4 | `Do you want to encrypt the auth file? [y/N]:` | `n` (o Enter) | `N` è il default, basta Enter |
| 5 | `Do you want to login with external browser? [y/N]:` | `y` | **Obbligatorio `y`**: è il metodo di login richiesto |
| 6 | `Do you want to login with a pre-amazon Audible account? [y/N]:` | `n` (o Enter) | `N` è il default, basta Enter |
| 7 | `Do you want to continue? [y/N]:` (dopo il riepilogo in tabella) | `y` | Conferma definitiva di profilo/auth-file/country |
| 8 | `Please insert the copied url (after login):` | URL completo copiato dalla barra del browser dopo il login | Vedi procedura manuale sotto, **non automatizzabile** |

Sequenza sintetica di risposte y/n (escludendo i prompt di testo libero come
nome profilo, country code e URL): `y` (browser esterno), `n` (pre-amazon),
`y` (continua).

## 3. Procedura di login con browser esterno (passi 5-8, manuale)

Dopo aver risposto `y` al passo 5 e confermato il riepilogo al passo 7, il
wizard stampa un lungo URL Amazon (`https://www.amazon.<tld>/ap/signin?...`).
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

Se tutto va a buon fine, l'output finale è:

```
Successfully registered <Nome>'s <N>th Audible for iPhone.
Profile <nome_profilo> added to config
Config written to config.toml
```

Vengono creati i file in `~/.audible/`:

```
~/.audible/
├── <nome_profilo>.json   # Credenziali e token del dispositivo registrato
└── config.toml           # Configurazione profilo audible-cli
```

## 4. Test finale del login

```bash
audible library list
```

- **Successo:** viene stampata una tabella/elenco di audiobook posseduti
  (titolo, ASIN, autore...). Il login è confermato e funzionante.
- **Fallimento:** viene restituito un errore (es. `Profile not found`,
  errore di autenticazione/HTTP). In questo caso ripetere il wizard oppure
  verificare il contenuto di `~/.audible/config.toml`.
