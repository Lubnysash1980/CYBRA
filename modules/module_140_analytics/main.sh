#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_140_analytics"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Analytics Dashboard ═══${N}"; echo
  echo "  1) Загальний огляд"
  echo "  2) Підписи (30 днів)"
  echo "  3) Парламент"
  echo "  4) Виконання"
  echo "  5) Дії"
  echo "  6) JSON"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/analytics.py" text; read -rp "Enter…" _ ;;
    2) python3 -c "
import sys; sys.path.insert(0,'$D'); import analytics
s = analytics.signatures_trend()
G='\033[32m';N='\033[0m'
for d,n in s.items(): print(f'  {d}  '+G+('█'*n)+N+f'  {n}')
"; read -rp "Enter…" _ ;;
    3) python3 -c "import sys,json;sys.path.insert(0,'$D');import analytics;print(json.dumps(analytics.parliament_stats(),indent=2,ensure_ascii=False))"; read -rp "Enter…" _ ;;
    4) python3 -c "import sys,json;sys.path.insert(0,'$D');import analytics;print(json.dumps(analytics.execution_stats(),indent=2))"; read -rp "Enter…" _ ;;
    5) python3 -c "import sys,json;sys.path.insert(0,'$D');import analytics;print(json.dumps(analytics.actions_stats(),indent=2,ensure_ascii=False))"; read -rp "Enter…" _ ;;
    6) python3 "$D/analytics.py" overview; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
