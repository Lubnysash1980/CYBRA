#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_350_controller_worker"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Controller Worker ═══${N}"
  echo
  # стан
  if [ -f "$D/data/worker_state.json" ]; then
    python3 -c "
import json
d = json.load(open('$D/data/worker_state.json'))
G='\033[32m'; R='\033[31m'; B='\033[36m'; N='\033[0m'
print(f\"  Останній цикл: {d['at']}\")
print(f\"  Контролери:    {G if d['controllers_ok']==d['controllers_total'] else R}{d['controllers_ok']}/{d['controllers_total']}{N}\")
print(f\"  Health:        {G if d['health']==100 else R}{d['health']}%{N}\")
print(f\"  Completion:    {G if d['completion']==100 else R}{d['completion']}%{N}\")
print(f\"  Час циклу:     {d['duration_ms']}ms\")
"
  else
    echo "  ще не запускався"
  fi
  echo
  # чи працює
  if pgrep -f "module_350_controller_worker/worker.py daemon" >/dev/null; then
    echo "  ${G}●${N} daemon працює"
  else
    echo "  ○ daemon не запущено"
  fi
  echo
  echo "  1) Запустити цикл зараз"
  echo "  2) Останні логи"
  echo "  3) Стан (JSON)"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/worker.py" cycle; read -rp "Enter…" _ ;;
    2) python3 "$D/worker.py" log 40; read -rp "Enter…" _ ;;
    3) python3 "$D/worker.py" status; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
