#!/bin/sh
set -eu

FORCE_OVERWRITE=false
if [ "${1:-}" = "--force" ]; then
    FORCE_OVERWRITE=true
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_FILE="$SCRIPT_DIR/init.lua"
DEST_DIR="$HOME/.hammerspoon"
DEST_FILE="$DEST_DIR/init.lua"
BACKUP_FILE="$DEST_DIR/init_backup.lua"

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Source file not found: $SOURCE_FILE" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"

if [ -f "$DEST_FILE" ]; then
    if [ "$FORCE_OVERWRITE" = true ]; then
        cp "$DEST_FILE" "$BACKUP_FILE"
        echo "Backed up existing config to $BACKUP_FILE"
    else
        echo "A Hammerspoon config already exists at $DEST_FILE"
        printf "Overwrite it? [y/N] "
        read -r answer
        case "$answer" in
            [Yy]|[Yy][Ee][Ss])
                cp "$DEST_FILE" "$BACKUP_FILE"
                echo "Backed up existing config to $BACKUP_FILE"
                ;;
            *)
                echo "Aborted without overwriting the existing config."
                exit 0
                ;;
        esac
    fi
fi

cp "$SOURCE_FILE" "$DEST_FILE"
echo "Installed $SOURCE_FILE -> $DEST_FILE"
