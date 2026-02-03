#!/bin/bash

# Readarr Custom Script for "On Import"
# Readarr passes environment variables for different events
# For "On Import" event, these variables are available:
# - readarr_eventtype (should be "Download" for imports)
# - readarr_author_id
# - readarr_author_name
# - readarr_author_path
# - readarr_book_id
# - readarr_book_title
# - readarr_book_releasedate
# - readarr_bookfile_id
# - readarr_bookfile_path (the imported file path)
# - readarr_bookfile_quality
# - readarr_bookfile_qualityversion
# - readarr_bookfile_releasegroup
# - readarr_bookfile_scenename
# - readarr_download_client
# - readarr_download_id

# ===== CONFIGURATION =====
# Destination directory (change this to your desired path)
DESTINATION="/data/books-ingest"

# File extensions to copy (space-separated, without dots)
# Removed to test: "docx" "html" "htmlz"
EXTENSIONS=("epub" "azw" "mobi" "pdf" "azw3" "azw4" "cbz" "cbr" "cb7" "lit" "odt" "pdb" "rtf")

# Log file
LOG_FILE="/tmp/readarr-copy.log"

# ===== SCRIPT LOGIC =====
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>&1
}

# Log that script was called
log_message "========================================="
log_message "Script executed"
log_message "Event Type: ${readarr_eventtype}"
log_message "Author: ${readarr_author_name}"
log_message "Book: ${readarr_book_title}"
log_message "Author Path: ${readarr_author_path}"

# Create destination directory if it doesn't exist
mkdir -p "$DESTINATION" 2>&1 | while read line; do log_message "mkdir: $line"; done

# Skip non-Download events
if [ "$readarr_eventtype" = "Test" ]; then
    log_message "Test event - script is working!"
    exit 0
fi

if [ "$readarr_eventtype" != "Download" ]; then
    log_message "Not a Download event (was: ${readarr_eventtype}), skipping"
    exit 0
fi

# Verify we have the required variables
if [ -z "$readarr_author_path" ]; then
    log_message "ERROR: readarr_author_path is empty"
    exit 1
fi

if [ -z "$readarr_book_title" ]; then
    log_message "ERROR: readarr_book_title is empty"
    exit 1
fi

# Check if author path exists
if [ ! -d "$readarr_author_path" ]; then
    log_message "ERROR: Author path does not exist: $readarr_author_path"
    exit 1
fi

# Look for the book folder (try exact match first, then fuzzy)
BOOK_FOLDER=""

# Try exact match with book title
if [ -d "$readarr_author_path/$readarr_book_title" ]; then
    BOOK_FOLDER="$readarr_author_path/$readarr_book_title"
    log_message "Found book folder (exact match): $BOOK_FOLDER"
else
    # Try case-insensitive search
    log_message "Exact folder not found, searching for book folder..."
    BOOK_FOLDER=$(find "$readarr_author_path" -maxdepth 1 -type d -iname "*${readarr_book_title}*" | head -n 1)
    
    if [ -n "$BOOK_FOLDER" ]; then
        log_message "Found book folder (fuzzy match): $BOOK_FOLDER"
    else
        log_message "ERROR: Could not find book folder for: $readarr_book_title"
        log_message "Searched in: $readarr_author_path"
        log_message "Available folders:"
        ls -1 "$readarr_author_path" >> "$LOG_FILE" 2>&1
        exit 1
    fi
fi

# Build find command for extensions
FIND_PARAMS=()
for i in "${!EXTENSIONS[@]}"; do
    if [ $i -eq 0 ]; then
        FIND_PARAMS+=("-iname" "*.${EXTENSIONS[$i]}")
    else
        FIND_PARAMS+=("-o" "-iname" "*.${EXTENSIONS[$i]}")
    fi
done

# Find and copy all matching files in the book folder
log_message "Searching for files with extensions: ${EXTENSIONS[*]}"
copied_count=0
found_files=0

while IFS= read -r -d '' file; do
    ((found_files++))
    filename=$(basename "$file")
    log_message "Found file: $filename"
    
    # Copy the file
    cp -v "$file" "$DESTINATION/" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "SUCCESS: Copied $filename"
        ((copied_count++))
    else
        log_message "ERROR: Failed to copy $filename"
    fi
done < <(find "$BOOK_FOLDER" -type f \( "${FIND_PARAMS[@]}" \) -print0)

if [ $found_files -eq 0 ]; then
    log_message "WARNING: No files found with extensions: ${EXTENSIONS[*]}"
    log_message "Files in book folder:"
    ls -lah "$BOOK_FOLDER" >> "$LOG_FILE" 2>&1
else
    log_message "Found $found_files file(s), successfully copied $copied_count"
fi

log_message "Processing complete"
log_message "========================================="
exit 0
