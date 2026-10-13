#!/data/data/com.termux/files/usr/bin/bash
# Auto-migrate + heavy tiers — щодня
LOG="$HOME/CYBRA/logs/cron_migrate.log"
{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] cron migrate"
  python3 "$HOME/CYBRA/modules/module_413_migrator/migrator.py" auto
  cybra-pm start heavy_tiers 2>/dev/null
} >> "$LOG" 2>&1
