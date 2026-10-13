#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_148_multisig_ui"
B=$'\e[36m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Multi-Sig UI ═══${N}"
  python3 "$D/ui.py"
  echo
  echo "  1) Показати сесію  2) Оновити  3) Запустити 123  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  SID: " sid; python3 "$D/ui.py" "$sid"; read -rp "Enter…" _ ;;
    2) continue ;;
    3) bash "$HOME/CYBRA/modules/module_123_multisig/main.sh" ;;
    0) return ;;
  esac
done
