#!/data/data/com.termux/files/usr/bin/bash
# Тихо перевіряє систему кожні INTERVAL секунд, лікує safe-проблеми,
# пише у журнал. При critical — нотифікація.
D="$HOME/CYBRA/modules/module_120_ai_guardian"
PID="$HOME/CYBRA/run/guardian.pid"
INTERVAL="${GUARDIAN_INTERVAL:-900}"   # 15 хв

is_running(){
  [ -f "$PID" ] || return 1
  kill -0 "$(cat "$PID")" 2>/dev/null
}
case "${1:-start}" in
  start)
    is_running && { echo "вже працює"; exit 0; }
    mkdir -p "$HOME/CYBRA/run"
    nohup bash -c "while :; do
      python3 '$D/guardian.py' run --auto --force >/dev/null 2>&1
      sleep $INTERVAL
    done" >/dev/null 2>&1 &
    echo $! > "$PID"
    echo "guardian watchdog PID $(cat $PID), інтервал ${INTERVAL}s"
    ;;
  stop)
    is_running && kill "$(cat $PID)" 2>/dev/null; rm -f "$PID"
    echo "зупинено"
    ;;
  status)
    is_running && echo "● працює PID $(cat $PID)" || echo "○ зупинено"
    ;;
esac
