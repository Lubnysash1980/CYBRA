#!/data/data/com.termux/files/usr/bin/bash

# ─── HARD GUARD: не запускатись якщо disabled ───
if [ -f "$HOME/CYBRA/config/pm_processes.json" ]; then
  if python3 -c "
import json
from pathlib import Path
d = json.loads(Path('$HOME/CYBRA/config/pm_processes.json').read_text())
i = d.get('processes', {}).get('orchestrator', {})
exit(0 if (not i.get('enabled', True)) or i.get('_phone_disabled', False) else 1)
" 2>/dev/null; then
    echo "  [phone-mode] orchestrator вимкнено — exit"
    exit 0
  fi
fi



_is_disabled() {
    local name="$1"
    python3 -c "
import json
from pathlib import Path
cfg = Path('$HOME/CYBRA/config/pm_processes.json')
d = json.loads(cfg.read_text()).get('processes', {})
info = d.get('$name', {})
disabled = (not info.get('enabled', True)) or info.get('_phone_disabled', False)
exit(0 if disabled else 1)
"
}

D="$HOME/CYBRA/modules/module_121_parlament"
PID="$HOME/CYBRA/run/orch.pid"
LOG="$HOME/CYBRA/logs/orch.log"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'

running(){ [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; }

case "${1:-status}" in
  start)
    running && { echo "${Y}вже працює (PID $(cat $PID))${N}"; exit 0; }
    mkdir -p "$HOME/CYBRA/run" "$HOME/CYBRA/logs"
    INTERVAL="${ORCH_INTERVAL:-600}"
    nohup python3 "$D/orchestrator.py" daemon --interval "$INTERVAL" \
      >>"$LOG" 2>&1 &
    echo $! > "$PID"
    sleep 1
    if running; then
      echo "${G}✓ Orchestrator PID $(cat $PID), цикл кожні ${INTERVAL}s${N}"
    else
      echo "${R}✗ не стартував — див. $LOG${N}"; tail -10 "$LOG"
    fi
    ;;
  stop)
    running && kill "$(cat $PID)" 2>/dev/null
    rm -f "$PID"; echo "${G}зупинено${N}"
    ;;
  status)
    if running; then echo "${G}● працює PID $(cat $PID)${N}"
    else echo "${R}○ зупинено${N}"; fi
    ;;
  log) tail -${2:-40} "$LOG" ;;
  once) python3 "$D/orchestrator.py" run ;;
esac
