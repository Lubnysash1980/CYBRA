#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
D="$HOME/CYBRA/modules/module_121_parlament"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

# знайти всі контракти
mapfile -t CIDS < <(python3 "$D/dossier.py" list 2>/dev/null)

if [ ${#CIDS[@]} -eq 0 ]; then
  echo
  echo "  ${Y}немає контрактів${N}"
  echo "  Спочатку підпиши через 108 або створи у 121"
  echo
  read -rp "  Enter…" _
  exit 0
fi

# декоратор рядка з коротким статусом
short_status(){
  local cid="$1"
  python3 - "$D" "$cid" <<'PY'
import sys, os, json
from pathlib import Path
D = Path(sys.argv[1]); cid = sys.argv[2]
parts = []
try:
    sys.path.insert(0, str(D))
    import verify_7
    s = verify_7.status(cid)
    if s:
        parts.append(f"{s['progress']:5.1f}% L{s['blocked_at'] or 7}")
except Exception: pass
try:
    sys.path.insert(0, str(D))
    import parliament as P
    props = [p for p in P.proposals()
             if (p.get("payload") or {}).get("cid") == cid]
    if props:
        st = props[-1].get("status","?")
        parts.append(f"PRL:{st}")
except Exception: pass
# підпис?
sig = Path.home() / f"CYBRA/modules/module_19_contract_tui_menu/evidence/{cid}_buyer.sig"
if sig.exists(): parts.append("SIG")
print("  ".join(parts) if parts else "—")
PY
}

while :; do
  clear
  echo "${B}═══ Dossier · вибір контракту ═══${N}"
  echo
  i=0
  for cid in "${CIDS[@]}"; do
    i=$((i+1))
    st=$(short_status "$cid")
    printf "  ${G}%2d${N}) %-36s  ${DIM}%s${N}\n" "$i" "${cid:0:34}" "$st"
  done
  echo
  echo "  ${G}l${N}) список файлів  ·  ${G}j${N}) JSON дос'є  ·  ${G}q${N}) вихід"
  echo
  read -rp "  Вибір: " c

  case "$c" in
    q|Q) exit 0 ;;
    l|L) python3 "$D/dossier.py" list; read -rp "Enter…" _ ;;
    j|J)
      read -rp "  CID (номер або повний): " jc
      [[ "$jc" =~ ^[0-9]+$ ]] && jc="${CIDS[$((jc-1))]}"
      [ -n "$jc" ] && python3 "$D/dossier.py" json "$jc" | head -80
      read -rp "Enter…" _ ;;
    *)
      if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#CIDS[@]}" ]; then
        cid="${CIDS[$((c-1))]}"
        clear
        python3 "$D/dossier.py" "$cid"
        echo
        echo "  ${DIM}d — dossier JSON  ·  e — execute рівень  ·  b — back to list${N}"
        read -rp "  Дія: " act
        case "$act" in
          d) python3 "$D/dossier.py" json "$cid" ;;
          e) python3 "$D/progress.py" exec "$cid" ;;
        esac
        read -rp "Enter…" _ 2>/dev/null || true
      fi
      ;;
  esac
done
