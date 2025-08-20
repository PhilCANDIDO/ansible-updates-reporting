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
# - 1.5.0: Added --dry-run to preview changes without applying them.
# - 1.6.0: If .sync_exclude does not exist, continue sync without error.
# - 1.7.0: Added --delete-extra to remove files in destination not present in source (default: no deletion).
#

# Script version
VERSION="1.7.0"

# Log file (same basename as script, .log extension)
LOG_FILE="$(basename "$0" .sh).log"
NO_LOG=false
DRY_RUN=false
DELETE_EXTRA=false

# Mandatory parameters (filled by CLI)
SRC_DIR=""
DST_DIR=""

# --- Helpers ---------------------------------------------------------------

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
      --dry-run              Show what would be done without making changes
      --delete-extra         Delete files in destination that are not present in source

Notes:
- Entries in '.sync_exclude' are relative to the source root.
- The '.git' directory is always excluded from synchronization.
- If '.sync_exclude' does not exist, sync continues normally (only '.git' excluded).
- Default behavior is NON-destructive: no deletions in destination unless --delete-extra is set.

Version: ${VERSION}
EOF
}

log() {
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --delete-extra)
            DELETE_EXTRA=true
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

if ! command -v rsync >/dev/null 2>&1; then
    echo "ERROR: 'rsync' is not installed or not in PATH."
    exit 127
fi

log "Starting synchronization (version ${VERSION})"
log "Source folder: ${SRC_DIR}"
log "Destination folder: ${DST_DIR}"
$DRY_RUN && log "Dry-run mode enabled: no changes will be made."
$DELETE_EXTRA && log "Deletion enabled: destination-only files will be removed."

# --- Exclusions ------------------------------------------------------------

EXCLUDE_FILE="${SRC_DIR}/.sync_exclude"
EXCLUDE_OPTS=( "--exclude=.git" )

if [[ -f "$EXCLUDE_FILE" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "${line:0:1}" == "#" ]] && continue
        EXCLUDE_OPTS+=( "--exclude=${line}" )
    done < "$EXCLUDE_FILE"
    log "Using exclude file: ${EXCLUDE_FILE}"
else
    log "Exclude file '${EXCLUDE_FILE}' not found, continuing without it."
fi

# --- Run rsync -------------------------------------------------------------

RSYNC_FLAGS=( -avz )
$DRY_RUN && RSYNC_FLAGS+=( --dry-run )
$DELETE_EXTRA && RSYNC_FLAGS+=( --delete )

log "Running: rsync ${RSYNC_FLAGS[*]} ${EXCLUDE_OPTS[*]} '${SRC_DIR}/' '${DST_DIR}/'"

if $NO_LOG; then
    rsync "${RSYNC_FLAGS[@]}" "${EXCLUDE_OPTS[@]}" "${SRC_DIR}/" "${DST_DIR}/"
else
    rsync "${RSYNC_FLAGS[@]}" "${EXCLUDE_OPTS[@]}" "${SRC_DIR}/" "${DST_DIR}/" >> "$LOG_FILE" 2>&1
fi

RSYNC_RC=$?

case "$RSYNC_RC" in
    0)
        log "Synchronization completed successfully (rc=${RSYNC_RC})."
        ;;
    *)
        log "ERROR: rsync terminated with a non-zero exit code (rc=${RSYNC_RC})."
        ;;
esac

exit "$RSYNC_RC"
