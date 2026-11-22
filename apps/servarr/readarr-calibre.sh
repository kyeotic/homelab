#!/bin/bash

# Readarr Custom Script: copy imported ebooks into Calibre-Web-Automated's ingest folder.
#
# Deployed on the docker host as /mnt/app_config/readarr/books-ingest (Readarr sees it as
# /config/books-ingest). Readarr > Settings > Connect > "calibre-ingest", with
# "On Release Import" and "On Upgrade" enabled.
#
# Readarr passes the imported files in readarr_addedbookpaths (absolute paths separated
# by "|"). Those paths are used as-is: rebuilding the folder from the book title breaks
# whenever Readarr's folder naming differs from the title (e.g. ":" becomes " -").

# ===== CONFIGURATION =====
# CWA's ingest folder. CWA deletes files from it after processing, so files are copied.
DESTINATION="/data/books-ingest"

# File extensions to copy (without dots). Audio files are never copied.
EXTENSIONS=("epub" "azw" "mobi" "pdf" "azw3" "azw4" "cbz" "cbr" "cb7" "lit" "odt" "pdb" "rtf")

LOG_FILE="/tmp/readarr-copy.log"

# ===== SCRIPT LOGIC =====
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>&1
}

# Readarr lowercases variable names on Linux; accept the documented casing too.
event_type="${readarr_eventtype:-$Readarr_EventType}"
book_title="${readarr_book_title:-$Readarr_Book_Title}"
added_paths="${readarr_addedbookpaths:-$Readarr_AddedBookPaths}"

log_message "========================================="
log_message "Event Type: ${event_type}"
log_message "Book: ${book_title}"

if [ "$event_type" = "Test" ]; then
    mkdir -p "$DESTINATION"
    log_message "Test event - script is working!"
    exit 0
fi

if [ "$event_type" != "Download" ]; then
    log_message "Not a Download event, skipping"
    exit 0
fi

if [ -z "$added_paths" ]; then
    log_message "ERROR: readarr_addedbookpaths is empty"
    exit 1
fi

mkdir -p "$DESTINATION"

is_ebook() {
    local ext="${1##*.}"
    ext="${ext,,}"
    local e
    for e in "${EXTENSIONS[@]}"; do
        [ "$ext" = "$e" ] && return 0
    done
    return 1
}

copied=0
failed=0
IFS='|' read -ra paths <<< "$added_paths"
for file in "${paths[@]}"; do
    [ -z "$file" ] && continue
    if ! is_ebook "$file"; then
        log_message "Skipping non-ebook file: $file"
        continue
    fi
    if [ ! -f "$file" ]; then
        log_message "ERROR: File not found: $file"
        ((failed++))
        continue
    fi
    if cp "$file" "$DESTINATION/" >> "$LOG_FILE" 2>&1; then
        log_message "SUCCESS: Copied $(basename "$file")"
        ((copied++))
    else
        log_message "ERROR: Failed to copy $file"
        ((failed++))
    fi
done

log_message "Copied $copied file(s), $failed failure(s)"
[ "$failed" -eq 0 ]
