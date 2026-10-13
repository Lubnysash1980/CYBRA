#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_370_runtime"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Runtime Worker ═══${N}"
  python3 "$D/runtime.py" stats
  echo "  Daemon: $(pgrep -f 'module_370_runtime/runtime.py daemon' >/dev/null && echo "${G}● online${N}" || echo "○ offline")"
  echo
  echo "  1) Submit job   2) Run one   3) List jobs   4) Log  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  Name: " n; read -rp "  Command: " cmd; read -rp "  Priority [3]: " p; p="${p:-3}"
       python3 "$D/runtime.py" submit "$n" "$cmd" "$p"; read -rp "Enter…" _ ;;
    2) python3 "$D/runtime.py" run-one; read -rp "Enter…" _ ;;
    3) python3 "$D/runtime.py" list; read -rp "Enter…" _ ;;
    4) tail -30 "$D/data/runtime.log"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
