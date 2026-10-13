#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/CYBRA/modules/module_413_migrator"
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
while :; do
  clear
  echo "${B}═══ Process Migrator (modes) ═══${N}"
  echo
  python3 - <<'PY'
import json
from pathlib import Path
cfg = json.loads((Path.home()/"CYBRA/config/pm_processes.json").read_text())
G='\033[32m'; Y='\033[33m'; D='\033[2m'; B='\033[36m'; N='\033[0m'
from collections import defaultdict
by_mode = defaultdict(list)
for name, p in cfg["processes"].items():
    by_mode[p.get("mode", "daemon")].append((name, p))
for mode in ["daemon", "interval", "ondemand"]:
    if not by_mode[mode]: continue
    col = {"daemon":G, "interval":Y, "ondemand":D}[mode]
    print(f"  {col}{mode.upper()}{N} ({len(by_mode[mode])}):")
    for name, p in sorted(by_mode[mode]):
        extra = ""
        if mode == "interval":
            extra = f"  кожні {p.get('interval_sec',0)}s"
        print(f"    {name:35s} {p.get('desc','')[:40]}{extra}")
    print()
PY
  echo "  1) ${G}Re-check modes${N}  2) Стан scheduler  0) Назад"
  read -rp "  Вибір: " c
  case "$c" in
    1) continue ;;
    2) python3 "$D/migrator.py" status 2>/dev/null | head -20; read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
