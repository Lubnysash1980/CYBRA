#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_150_scripts"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Custom Scripts ═══${N}"; echo
  echo "  Скрипти у $D/data/scripts/"
  python3 "$D/run.py" list
  echo
  echo "  1) Запустити  2) Створити  3) Останні запуски  0) Назад"
  echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  Назва: " n; read -rp "  Аргументи [Enter=нема]: " a
       python3 "$D/run.py" run "$n" $a; read -rp "Enter…" _ ;;
    2) read -rp "  Назва (без .sh): " n
       cat > "$D/data/scripts/$n.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "custom script"
EOF
       chmod +x "$D/data/scripts/$n.sh"
       echo "✓ створено $D/data/scripts/$n.sh"; read -rp "Enter…" _ ;;
    3) python3 -c "
import sys; sys.path.insert(0,'$D'); import run
for r in run.recent(10):
    mark = '✓' if r.get('rc')==0 else '✗'
    print(f\"  {mark} {r['name']:20s} {r['dur']}s  {r['at']}\")
"
       read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
