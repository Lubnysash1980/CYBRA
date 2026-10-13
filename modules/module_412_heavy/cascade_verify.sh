#!/data/data/com.termux/files/usr/bin/bash
LOG="$HOME/CYBRA/logs/cascade_verify.log"
mkdir -p "$(dirname "$LOG")"
{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] cascade_verify START"
  python3 "$HOME/CYBRA/modules/module_401_cascade_verify/verify.py" test 2>&1
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] cascade_verify END"
} >> "$LOG" 2>&1
