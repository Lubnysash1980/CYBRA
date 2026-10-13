#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_134_discord"; CFG="$HOME/CYBRA/config/discord.env"
G=$'\e[32m'; B=$'\e[36m'; D_=$'\e[2m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Discord Bot ═══${N}"; echo
  if [ -f "$CFG" ]; then echo "  ${G}✓ webhook налаштовано${N}"; else echo "  ${D_}webhook не налаштовано${N}"; fi
  echo
  echo "  1) Тест (ping)"
  echo "  2) Налаштувати webhook"
  echo "  3) Надіслати довільне"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/send.py" "🧪 CYBRA test"; read -rp "Enter…" _ ;;
    2) mkdir -p "$(dirname "$CFG")"; read -rp "Webhook URL: " w
       echo "DISCORD_WEBHOOK=\"$w\"" > "$CFG"; echo "${G}✓ збережено${N}"; read -rp "Enter…" _ ;;
    3) read -rp "Повідомлення: " m; python3 "$D/send.py" "$m"; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
