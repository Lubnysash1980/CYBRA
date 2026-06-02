#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

CMD="${1:-status}"
ARG="${2:-}"

case "$CMD" in
  pack)
    bash cybra_autoheal_recovery_pack.sh pack
    ;;
  verify)
    bash cybra_autoheal_recovery_pack.sh verify "$ARG"
    ;;
  unpack)
    bash cybra_autoheal_recovery_pack.sh unpack "$ARG"
    ;;
  auto)
    bash cybra_autoheal_recovery_pack.sh start-auto "${ARG:-1800}"
    ;;
  stop)
    bash cybra_autoheal_recovery_pack.sh stop-auto
    ;;
  watchdog)
    pkill -f cybra_recovery_watchdog.sh 2>/dev/null || true
    nohup bash cybra_recovery_watchdog.sh "${ARG:-1800}" > logs/recovery/watchdog_loop.log 2>&1 &
    echo "✅ recovery watchdog started"
    ;;
  serve)
    bash cybra_autoheal_recovery_pack.sh serve "${ARG:-8787}"
    ;;
  status)
    bash cybra_autoheal_recovery_pack.sh status
    ;;
  report)
    cat posts/autoheal_recovery_status.md
    ;;
  web)
    cat docs/recovery/index.html
    ;;
  *)
    echo "Usage: bash cybra_recovery.sh pack|verify|unpack|auto|stop|watchdog|serve|status|report|web"
    ;;
esac
