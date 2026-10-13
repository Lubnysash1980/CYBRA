#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_320_controllers"
B=$'\e[36m'; G=$'\e[32m'; R=$'\e[31m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Controllers ═══${N}"
  echo
  python3 "$D/controllers.py" check
  echo
  echo "  1) Auto-fix  2) Лог  3) JSON  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/controllers.py" fix; read -rp "Enter…" _ ;;
    2) tail -20 "$D/data/log.jsonl" 2>/dev/null | python3 -c "
import sys,json
for l in sys.stdin:
    try: e=json.loads(l)
    except: continue
    m='✓' if e.get('ok') else '✗'
    print(f\"  {m} {e.get('controller','?'):14s} {e.get('msg','')[:50]}\")
"; read -rp "Enter…" _ ;;
    3) python3 "$D/controllers.py" json; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
