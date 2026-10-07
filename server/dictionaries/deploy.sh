#!/usr/bin/env bash
# Copies the dictionary server to the home server and rebuilds its container.
# Run from Git Bash or any POSIX shell:  bash server/dictionaries/deploy.sh
#
# The server keeps its own ~/jdj-dictionaries/.env (tokens) and data/; neither
# is ever sent from here.
set -euo pipefail

HOST="${DICT_HOST:-ninh@100.67.210.114}"
DIR="jdj-dictionaries"
URL="${DICT_URL:-https://dict.health-journal.duckdns.org}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

# The app's strings files go along, so the strings page edits what the app
# was built with.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/strings"
cp "$repo"/yuuna/lib/i18n/strings*.i18n.json "$stage/strings/"
tar -C "$here" --exclude='__pycache__' -cf "$stage/upload.tar" \
  Dockerfile docker-compose.yml requirements.txt dictserver
tar -C "$stage" -rf "$stage/upload.tar" strings

gzip -c "$stage/upload.tar" \
  | ssh "$HOST" "set -e
      mkdir -p ~/$DIR/data
      rm -rf ~/$DIR/strings
      tar -xzf - -C ~/$DIR
      cd ~/$DIR
      if [ ! -f .env ]; then echo 'Missing ~/$DIR/.env with DICT_ADMIN_TOKENS' >&2; exit 1; fi
      docker compose up -d --build --remove-orphans
      docker compose ps"

for _ in $(seq 1 30); do
  if curl -fsS --max-time 5 "$URL/api/health" >/dev/null 2>&1; then
    echo "Up: $URL"
    exit 0
  fi
  sleep 2
done
echo "Deployed, but $URL/api/health did not answer within a minute." >&2
exit 1
