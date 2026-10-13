#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_143_email"; CFG="$HOME/CYBRA/config/email.json"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Email Notifications ═══${N}"; echo
  if [ -f "$CFG" ] && grep -q '"enabled": true' "$CFG"; then echo "  ${G}✓${N} активовано"; else echo "  вимкнено"; fi
  echo
  echo "  1) Налаштувати SMTP"
  echo "  2) Тестовий лист"
  echo "  3) Відправити лист"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  SMTP host [smtp.gmail.com]: " h; h="${h:-smtp.gmail.com}"
       read -rp "  Port [587]: " p; p="${p:-587}"
       read -rp "  Email: " u
       read -rsp "  App password: " pw; echo
       python3 "$D/mail.py" setup "$h" "$p" "$u" "$pw"
       read -rp "Enter…" _ ;;
    2) python3 "$D/mail.py" test; read -rp "Enter…" _ ;;
    3) read -rp "  Кому: " t; read -rp "  Тема: " s; read -rp "  Тіло: " b
       python3 "$D/mail.py" send "$t" "$s" "$b"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
