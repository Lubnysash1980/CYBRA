#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_136_templates"
G=$'\e[32m'; B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Contract Templates ═══${N}"; echo
  python3 "$D/templates.py" list
  echo
  echo "  ${G}1${N}) Показати шаблон   ${G}2${N}) Створити контракт з шаблону"
  echo "  ${G}0${N}) Назад"
  echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "Назва (sale/service/rent/nda): " n
       python3 "$D/templates.py" show "$n"; read -rp "Enter…" _ ;;
    2)
       read -rp "Шаблон: " t
       echo "Введи поля (Enter для пропуску необов'язкових):"
       VALS="{}"
       for f in $(python3 -c "import json;print(' '.join(x['id'] for x in json.load(open('$D/templates/$t.json'))['fields']))" 2>/dev/null); do
         read -rp "  $f: " v
         [ -n "$v" ] && VALS=$(python3 -c "import json,sys;d=json.loads(sys.argv[1]);d['$f']=sys.argv[2];print(json.dumps(d))" "$VALS" "$v")
       done
       python3 "$D/templates.py" fill "$t" "$VALS"
       read -rp "Enter…" _
       ;;
    0) return ;;
  esac
done
