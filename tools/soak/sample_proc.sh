#!/bin/bash
# soak_metrics.sh
# Logs Date, RSS(KB), and CPU% of a target process every 1 second.
# Usage: ./soak_metrics.sh <ProcessName> <OutputFile>

PROCESS_NAME=$1
OUTPUT_FILE=$2

if [ -z "$PROCESS_NAME" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: ./soak_metrics.sh <ProcessName> <OutputFile.csv>"
    exit 1
fi

echo "Timestamp(Epoch),RSS(MB),CPU(%)" > "$OUTPUT_FILE"

while true; do
    # Get PID of the process. Break if it exits.
    PID=$(pgrep -x "$PROCESS_NAME" | head -n 1)
    if [ -z "$PID" ]; then
        echo "[$(date)] Process '$PROCESS_NAME' not found or exited."
        break
    fi

    # ps -o rss,pcpu format outputs headers, so we parse it out
    # RSS is in KB. Let's convert to MB for easier reading.
    STATS=$(ps -p "$PID" -o rss=,pcpu=)
    if [ -n "$STATS" ]; then
        RSS_KB=$(echo "$STATS" | awk '{print $1}')
        CPU_PCT=$(echo "$STATS" | awk '{print $2}')
        RSS_MB=$(echo "scale=2; $RSS_KB / 1024" | bc)
        TS=$(date +%s)
        
        echo "$TS,$RSS_MB,$CPU_PCT" >> "$OUTPUT_FILE"
    fi
    sleep 1
done
