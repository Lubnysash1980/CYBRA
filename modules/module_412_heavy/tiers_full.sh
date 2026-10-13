#!/data/data/com.termux/files/usr/bin/bash
# Запускається у фоні через PM
LOG="$HOME/CYBRA/logs/tiers_full.log"
mkdir -p "$(dirname "$LOG")"
{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] tiers_full START"
  python3 "$HOME/CYBRA/modules/module_411_tiers/tiers.py" run 7 2>&1
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] tiers_full END"
} >> "$LOG" 2>&1
