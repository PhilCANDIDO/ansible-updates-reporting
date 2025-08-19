#!/bin/bash

# Script version
VERSION="1.3.0"

# Log file
LOG_FILE="$(basename "$0" .sh).log"
NO_LOG=false

# Source and destination directories (must be provided)
SRC_DIR=""
DST_DIR=""

# Help function
show_help() {
    echo "Usage: $0 --src-folder <path> --dst-folder <path> [OPTIONS]"
    echo
    echo "Synchronize files from a GitHub-based project folder to a GitLab-based project folder."
    echo
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "      --src-folder <path>    Source folder (mandatory)"
    echo "      --dst-folder <path>    Destination folder (mandatory)"
    echo "      --no-log               Do not write to log file (stdout only)"
    echo
    echo "The synchronization:"
    echo "- Excludes .git directory and all paths in .sync_exclude file"
    echo
    echo "Version: $VERSION"
}

# Logging function
log() {
    local msg="[$(date +'%Y%m%d-%H:%M:%S')] $1"
    if $NO_LOG; then
        echo "$msg"
    else
        echo "$msg" | tee -a "$LOG_FILE"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --src-folder)
            SRC_DIR="$2"
            shift 2
            ;;
        --dst-folder)
            DST_DIR="$2"
            shift 2
            ;;
        --no-log)
            NO_LOG=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate parameters
if [[ -z "$SRC_DIR" || -z "$DST_DIR" ]]; then
    echo "ERROR: Both --src-folder and --dst-folder must be specified."
    show_help
    exit 1
fi

log "Starting synchronization script (version $VERSION)"
log "Source folder: $SRC_DIR"
log "Destination folder: $DST_DIR"

# Check if .sync_exclude exists
EXCLUDE_FILE="$SRC_DIR/.sync_exclude"
if [[ ! -f "$EXCLUDE_FILE" ]]; then
    log "ERROR: Exclude file $EXCLUDE_FILE not found"
    exit 1
fi

# Build rsync exclude options
EXCLUDE_OPTS="--exclude=.git"
while IFS= read -r line; do
    [[ -n "$line" ]] && EXCLUDE_OPTS+=" --exclude=$line"
done < "$EXCLUDE_FILE"

# Run rsync
if $NO_LOG; then
    rsync -avz --delete $EXCLUDE_OPTS "$SRC_DIR/" "$DST_DIR/"
else
    rsync -avz --delete $EXCLUDE_OPTS "$SRC_DIR/" "$DST_DIR/" >> "$LOG_FILE" 2>&1
fi
RET_CODE=$?

if [[ $RET_CODE -eq 0 ]]; then
    log "Synchronization completed successfully."
else
    log "ERROR: Synchronization failed with exit code $RET_CODE"
fi

exit $RET_CODE
