#!/data/data/com.termux/files/usr/bin/bash
LOG="$HOME/CYBRA/logs/pipeline.log"
mkdir -p "$(dirname "$LOG")"
{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] pipeline START"
  python3 "$HOME/CYBRA/modules/module_409_pipeline/pipeline.py" run 30 2>&1
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] pipeline END"
} >> "$LOG" 2>&1
