#!/bin/bash
# Cleanup Meetily recordings older than 24 hours
# Installed via: crontab -e
# Cron: 0 * * * * /Users/hd/Projects/hack/claude_calls/scripts/cleanup-recordings.sh

RECORDINGS_DIR="$HOME/Movies/meetily-recordings"
LOG_FILE="$HOME/.local/log/meetily-cleanup.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Find and delete directories older than 24 hours
find "$RECORDINGS_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +0 | while read -r dir; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') Deleting: $dir" >> "$LOG_FILE"
    rm -rf "$dir"
done
