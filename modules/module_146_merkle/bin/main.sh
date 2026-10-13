#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_146_merkle"
E="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
while :; do
  clear; echo "${B}═══ Merkle Batching ═══${N}"; echo
  echo "  1) Побудувати tree з файлів"
  echo "  2) Batch усіх останніх CID"
  echo "  3) List trees"
  echo "  0) Назад"; echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "  Шляхи (через пробіл): " -a files
       python3 "$D/merkle.py" build "${files[@]}"; read -rp "Enter…" _ ;;
    2) CIDS=$(ls -t "$E"/*.sig 2>/dev/null | head -20 | xargs -r -n1 basename | sed 's/_buyer.sig//')
       JSON=$(python3 -c "import json,sys;print(json.dumps(sys.argv[1:]))" $CIDS)
       python3 "$D/merkle.py" batch-cids "$JSON"; read -rp "Enter…" _ ;;
    3) python3 "$D/merkle.py" list; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
