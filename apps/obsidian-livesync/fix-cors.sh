#!/usr/bin/env bash
# Updates CouchDB's CORS allowed headers to include Cloudflare Access service token
# headers. Run this once if the LiveSync plugin reports CORS errors.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

curl -sf -X PUT "http://192.168.0.20:5984/_node/_local/_config/cors/headers" \
  -u "$DB_USER:$DB_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '"accept, authorization, content-type, origin, referer, CF-Access-Client-Id, CF-Access-Client-Secret"'

echo "CORS headers updated."