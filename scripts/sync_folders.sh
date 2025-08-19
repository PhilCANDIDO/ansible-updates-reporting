#!/bin/bash
#
# Name: sync_folders.sh
# Purpose: Synchronize two folders (GitHub -> GitLab style), excluding .git and paths listed in .sync_exclude.
#
# Changelog:
# - 1.0.0: Initial version (basic rsync with .git and .sync_exclude support).
# - 1.1.0: Added --src-folder and --dst-folder parameters.
# - 1.2.0: Removed default SRC_DIR/DST_DIR; both are now mandatory.
# - 1.3.0: Added --no-log to print to stdout only (no log file creation).
# - 1.4.0: Check rsync is installed; explicit check/report of rsync exit status.
#

# Script version
VERSION="1.4.0"

# Log file (same basename as script, .log extension)
LOG_FILE="$(basename "$0" .sh).log"
NO_LOG=false

# Mandatory parameters (filled by CLI)
SRC_DIR=""
DST_DIR=""

# --- Helpers ---------------------------------------------------------------

# Print help text
show_help() {
    cat <<EOF
Usage: $0 --src-folder <path> --dst-folder <path> [OPTIONS]

Synchronize files from a source project folder to a destination project folder.
Excludes the '.git' directory and all relative paths listed in the file '.sync_exclude' at the root of the source folder.

Options:
  -h, --help                 Show this help message
      --src-folder <path>    Source folder (mandatory)
      --dst-folder <path>    Destination folder (mandatory)
      --no-log               Do not write a log file; print to stdout only

Notes:
- Entries in '.sync_exclude' are relative to the source root.
- The '.git' directory is always excluded from synchronization.

Version: ${VERSION}
EOF
}

# Timestamped logger: [YYYYMMDD-hh:mm:sss] (sss = milliseconds)
log() {
    # GNU date supports %3N for milliseconds
    local ts="[$(date +'%Y%m%d-%H:%M:%S%3N')]"
    local msg="${ts} $*"
    if $NO_LOG; then
        echo "$msg"
    else
        echo "$msg" | tee -a "$LOG_FILE"
    fi
}

# --- Argument parsing ------------------------------------------------------

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

# --- Validation ------------------------------------------------------------

if [[ -z "$SRC_DIR" || -z "$DST_DIR" ]]; then
    echo "ERROR: Both --src-folder and --dst-folder must be specified."
    show_help
    exit 1
fi

# Check rsync presence before doing anything else
if ! command -v rsync >/dev/null 2>&1; then
    echo "ERROR: 'rsync' is not installed or not in PATH."
    exit 127
fi

log "Starting synchronization (version ${VERSION})"
log "Source folder: ${SRC_DIR}"
log "Destination folder: ${DST_DIR}"

EXCLUDE_FILE="${SRC_DIR}/.sync_exclude"
if [[ ! -f "$EXCLUDE_FILE" ]]; then
    log "ERROR: Exclude file '${EXCLUDE_FILE}' not found."
    exit 1
fi

# --- Build exclude options -------------------------------------------------

EXCLUDE_OPTS=( "--exclude=.git" )
while IFS= read -r line; do
    # Skip empty lines and simple comments
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue
    EXCLUDE_OPTS+=( "--exclude=${line}" )
done < "$EXCLUDE_FILE"

# --- Run rsync -------------------------------------------------------------

# Common rsync flags:
# -a archive mode, -v verbose, --delete to mirror, -rltgoD implied by -a
# Compression (-z) is harmless locally; keep for consistency.
RSYNC_FLAGS=( -avz --delete )

log "Running: rsync ${RSYNC_FLAGS[*]} ${EXCLUDE_OPTS[*]} '${SRC_DIR}/' '${DST_DIR}/'"

if $NO_LOG; then
    rsync "${RSYNC_FLAGS[@]}" "${EXCLUDE_OPTS[@]}" "${SRC_DIR}/" "${DST_DIR}/"
else
    rsync "${RSYNC_FLAGS[@]}" "${EXCLUDE_OPTS[@]}" "${SRC_DIR}/" "${DST_DIR}/" >> "$LOG_FILE" 2>&1
fi

RSYNC_RC=$?

# --- Result handling -------------------------------------------------------

case "$RSYNC_RC" in
    0)
        log "Synchronization completed successfully (rc=${RSYNC_RC})."
        ;;
    *)
        log "ERROR: rsync terminated with a non-zero exit code (rc=${RSYNC_RC})."
        log "Refer to rsync exit codes for details (e.g., 23=partial transfer, 24=some files vanished)."
        ;;
esac

exit "$RSYNC_RC"
