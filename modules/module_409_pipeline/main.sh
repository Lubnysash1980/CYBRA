#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_409_pipeline"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Full Pipeline ═══${N}"
  echo
  echo "  8 кроків:"
  echo "    1. TEST    — перевірка всіх пунктів меню"
  echo "    2. FIX     — 8-stage autofix"
  echo "    3. RESTART — перезапуск PM процесів"
  echo "    4. GITHUB  — pull/commit/push"
  echo "    5. HEALTH  — health + gate"
  echo "    6. WAIT    — чекати N сек"
  echo "    7. RETEST  — повторний тест"
  echo "    8. REPORT  — фінальний звіт"
  echo
  echo "  1) ${G}Запустити повний цикл${N} (30s wait)"
  echo "  2) Запустити (60s wait)"
  echo "  3) Запустити (10s wait)"
  echo "  4) Останній стан"
  echo "  5) Лог"
  echo "  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) python3 "$D/pipeline.py" run 30; read -rp "Enter…" _ ;;
    2) python3 "$D/pipeline.py" run 60; read -rp "Enter…" _ ;;
    3) python3 "$D/pipeline.py" run 10; read -rp "Enter…" _ ;;
    4) python3 "$D/pipeline.py" state; read -rp "Enter…" _ ;;
    5) python3 "$D/pipeline.py" log 50; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
