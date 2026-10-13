#!/data/data/com.termux/files/usr/bin/bash
# Викликати з cron або watchdog: бекап + sync
D="$HOME/CYBRA/modules/module_121_parlament"
LOG="$HOME/CYBRA/logs/parlament_backup.log"
mkdir -p "$(dirname "$LOG")"
{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] backup"
  python3 "$D/git_sync.py" sync 2>&1 | tail -5
  python3 "$D/webdav.py" backup 2>&1 | tail -5
} >> "$LOG" 2>&1
# ротація
[ -f "$LOG" ] && [ $(wc -c < "$LOG") -gt 500000 ] && tail -500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
