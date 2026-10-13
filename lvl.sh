#!/data/data/com.termux/files/usr/bin/bash
H="$HOME/CYBRA"; M="$H/modules"
G=$'\e[32m'; R=$'\e[31m'; B=$'\e[36m'; N=$'\e[0m'
L="${1:-1}"

case "$L" in
1)
  echo "${B}L1 · EXISTENCE${N}"
  for f in "$M/module_19_contract_tui_menu/bin/cybra_menu.sh" \
           "$H/config/pm_processes.json" \
           "$H/config/networks.json" \
           "$M/module_300_pm/supervisor.py" \
           "$M/module_114_autonode/daemon.py" \
           "$M/module_121_parlament/health.py" \
           "$M/module_399_gate/gate.py"; do
    [ -s "$f" ] && echo "  ${G}✓${N} $(basename $f)" || echo "  ${R}✗${N} $f"
  done
  ;;
2)
  echo "${B}L2 · STRUCTURE${N}"
  T="$M/module_19_contract_tui_menu/bin/cybra_menu.sh"
  grep -q "CYBRA/CYBRA" "$T" && echo "  ${R}✗${N} CYBRA/CYBRA" || echo "  ${G}✓${N} без подвійного"
  D=$(grep -oE '^\s+[0-9]+\)' "$T" | sort | uniq -d | wc -l)
  [ "$D" -gt 0 ] && echo "  ${R}✗${N} дублів: $D" || echo "  ${G}✓${N} без дублів"
  ;;
3)
  echo "${B}L3 · SYNTAX${N}"
  T="$M/module_19_contract_tui_menu/bin/cybra_menu.sh"
  bash -n "$T" 2>/dev/null && echo "  ${G}✓${N} TUI" || echo "  ${R}✗${N} TUI"
  n=0
  for d in "$M"/module_*/main.sh; do
    [ -f "$d" ] || continue
    [ $n -ge 20 ] && break
    bash -n "$d" 2>/dev/null && n=$((n+1))
  done
  echo "  ${G}✓${N} ще $n .sh OK"
  for f in parliament.py health.py gate.py; do
    p=$(find "$M" -maxdepth 2 -name "$f" | head -1)
    [ -n "$p" ] && python3 -c "import ast;ast.parse(open('$p').read())" 2>/dev/null && echo "  ${G}✓${N} $f"
  done
  ;;
4)
  echo "${B}L4 · RUNTIME${N}"
  python3 - <<'PY'
import json
from pathlib import Path
H=Path.home()/"CYBRA"
cfg=json.loads((H/"config/pm_processes.json").read_text())
for n,p in cfg["processes"].items():
    if p.get("mode")!="daemon": continue
    c=p.get("cmd","").replace("$HOME",str(H))
    for w in c.split():
        if w.endswith((".py",".sh")):
            ok = Path(w).exists()
            print(f"  {'✓' if ok else '✗'} {n}")
            break
PY
  ;;
5)
  echo "${B}L5 · BEHAVIOR${N}"
  timeout 25 python3 -c "
import sys
sys.path.insert(0,'$M/module_121_parlament')
import health; h=health.health_all()
print('  health:', h.get('overall',0), '%')
"
  ;;
6)
  echo "${B}L6 · TIMESERIES${N}"
  [ -f "$H/run/autonode.json" ] && python3 -c "
import json
d=json.load(open('$H/run/autonode.json'))
print('  state:', d.get('state'), 'nets:', d.get('nets_ok'),'/',d.get('nets_total'))
" || echo "  немає autonode.json"
  ;;
7)
  echo "${B}L7 · PREDICTIVE${N}"
  python3 -c "
import shutil
from pathlib import Path
_,_,f=shutil.disk_usage(str(Path.home()/'CYBRA'))
print('  disk free:', f//(1024**3), 'GB')
"
  ;;
esac
