#!/usr/bin/env bash
# Run after first deploy to initialize CouchDB for Obsidian LiveSync.
# Reads DB_USER and DB_PASSWORD from .env in the same directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

curl -s https://raw.githubusercontent.com/vrtmrz/obsidian-livesync/main/utils/couchdb/couchdb-init.sh | \
  hostname="http://192.168.0.20:5984" username="$DB_USER" password="$DB_PASSWORD" bash