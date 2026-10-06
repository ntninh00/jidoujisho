# Dictionary server

A small private catalog of Yomitan dictionaries for jidoujisho. The app lists
what is on it, previews entries with a search before downloading, downloads
and imports, and (with an admin token) uploads, relabels and deletes.

It runs on the home server next to the family dashboard and Cluebook, and
borrows their Caddy for HTTPS at `https://dict.health-journal.duckdns.org`.
Nothing of theirs changes except one site block in the shared Caddyfile
(`caddy-site.caddyfile` here is a copy of it).

## Access

Every route but `/api/health` needs `Authorization: Bearer <token>`. Tokens
live only in `~/jdj-dictionaries/.env` on the server:

```
DICT_ADMIN_TOKENS=<token>[,<token>…]   # list, search, download, upload, relabel, delete
DICT_READ_TOKENS=<token>[,<token>…]    # list, search, download
```

Tokens shorter than 24 characters are ignored. Ten wrong tokens from one
address within ten minutes lock that address out for the rest of the window.
Edit the file and run `docker restart jdj-dictionaries` to change them.

## What an upload must pass

Checked before anything is unpacked, from the zip's directory alone:

- an admin token, a declared size under `DICT_MAX_UPLOAD_MB` (1024), and
  enough disk left afterwards (`DICT_MIN_FREE_MB`, 5120)
- a real zip: no passwords, links, absolute or `..` paths, repeated names or
  unusual compression; at most `DICT_MAX_ENTRIES` files (60000)
- no file inflating more than 200 times, nothing over
  `DICT_MAX_UNCOMPRESSED_MB` (6144) in all, no bank over `DICT_MAX_BANK_MB` (96)
- `index.json` at the top with a title, a revision and format 1–3; packs of
  several dictionaries and folder-wrapped ones get a message saying so
- at least one term, kanji or frequency bank
- not already on the server (same title and revision) unless replacing

Indexing then runs in the background, one dictionary at a time. A bank that
isn't valid JSON, or whose entries mostly can't be read, fails the upload
with that reason. Only pictures listed in the zip are ever served on their
own; everything carries a sandboxing Content-Security-Policy.

## Languages and kinds

`sourceLanguage` and `targetLanguage` come from `index.json` when it has them.
Otherwise they are guessed from samples (headwords for the first, definitions
for the second) and marked `languagesGuessed`, so the app can offer to fix
them. Kinds are `terms`, `kanji`, `frequency`, `pitch` and `ipa`; the app groups
term dictionaries into bilingual and monolingual by comparing the languages.

## Deploying

```bash
bash server/dictionaries/deploy.sh
```

Copies the code to `~/jdj-dictionaries` over Tailscale, rebuilds the container
and waits for `/api/health`. Data and `.env` stay on the server.

## Tests

```bash
pip install -r requirements.txt httpx pytest
python -m pytest tests
```
