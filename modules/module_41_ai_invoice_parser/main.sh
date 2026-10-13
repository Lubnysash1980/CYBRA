#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_41_ai_invoice_parser"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ AI Invoice Parser ═══${N}"; echo
  echo "  1) Розібрати текст рахунку"
  echo "  2) Розібрати файл"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) echo "  Вставте текст (EOF):"; cat > /tmp/inv.txt
       python3 "$D/parse_komfi.py" /tmp/inv.txt; read -rp "Enter…" _ ;;
    2) read -rp "  Файл: " f
       [ -f "$f" ] && python3 "$D/parse_komfi.py" "$f"
       read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
