#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_398_webui"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Web UI ═══${N}"
  if pgrep -f "module_398_webui/server.py" >/dev/null; then
    echo "${G}● онлайн${N} → http://127.0.0.1:8791"
  else
    echo "○ офлайн"
  fi
  echo
  echo "  1) Start   2) Stop   3) Статус   0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) cybra-pm start webui; read -rp "Enter…" _ ;;
    2) cybra-pm stop webui; read -rp "Enter…" _ ;;
    3) curl -s http://127.0.0.1:8791/api/state | head -20; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
