#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_126_zk"
G=$'\e[32m'; B=$'\e[36m'; D_=$'\e[2m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ ZK · Schnorr proof of knowledge ═══${N}"
  echo "  ${D_}secp256k1 · non-interactive Fiat-Shamir${N}"
  echo
  echo "  ${G}1${N}) Commit (cid → C = s*G)"
  echo "  ${G}2${N}) Prove (генерує Schnorr proof)"
  echo "  ${G}3${N}) Verify (перевірка proof)"
  echo "  ${G}4${N}) Reveal (розкриття cid+salt)"
  echo "  ${G}5${N}) Список commitments/proofs"
  echo "  ${G}6${N}) Self-test"
  echo
  echo "  ${G}0${N}) Назад"
  echo
  read -rp "  Вибір: " c
  case "$c" in
    1) read -rp "CID: " cid
       python3 "$D/zk.py" commit "$cid"; read -rp "Enter…" _ ;;
    2) read -rp "CID: " cid; read -rp "Salt: " s
       python3 "$D/zk.py" prove "$cid" "$s"; read -rp "Enter…" _ ;;
    3) read -rp "Proof файл: " f
       python3 "$D/zk.py" verify "$f"; read -rp "Enter…" _ ;;
    4) read -rp "Proof файл: " f; read -rp "CID: " cid; read -rp "Salt: " s
       python3 "$D/zk.py" reveal "$f" "$cid" "$s"; read -rp "Enter…" _ ;;
    5) python3 "$D/zk.py" list; read -rp "Enter…" _ ;;
    6) python3 "$D/zk.py" selftest; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
