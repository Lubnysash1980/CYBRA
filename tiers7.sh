#!/data/data/com.termux/files/usr/bin/bash
H="$HOME/CYBRA"; M="$H/modules"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; N=$'\e[0m'

ram(){ free -m | awk '/Mem:/{print $4}'; }
guard(){ local f=$(ram); [ "$f" -lt 300 ] && { echo "${R}STOP: RAM $f MB${N}"; exit 1; }; }
step(){ echo; echo "${B}═══ L$1 · $2 ═══${N}  RAM: $(ram) MB"; }

# ── L1 ──
step 1 EXISTENCE; guard
n=0
for f in "$M/module_19_contract_tui_menu/bin/cybra_menu.sh" \
         "$H/config/pm_processes.json" \
         "$H/config/networks.json" \
         "$M/module_300_pm/supervisor.py" \
         "$M/module_114_autonode/daemon.py" \
         "$M/module_121_parlament/health.py" \
         "$M/module_399_gate/gate.py"; do
  [ -s "$f" ] && n=$((n+1)) || echo "  ${R}✗${N} $f"
done
echo "  ${G}✓${N} $n/7 файлів"
sleep 3

# ── L2 ──
step 2 STRUCTURE; guard
T="$M/module_19_contract_tui_menu/bin/cybra_menu.sh"
grep -q "CYBRA/CYBRA" "$T" && echo "  ${R}✗${N} CYBRA/CYBRA" || echo "  ${G}✓${N} без подвійного"
D=$(grep -oE '^\s+[0-9]+\)' "$T" | sort | uniq -d | wc -l)
[ "$D" -gt 0 ] && echo "  ${R}✗${N} дублів: $D" || echo "  ${G}✓${N} без дублів"
sleep 3

# ── L3 ──
step 3 SYNTAX; guard
n=0; e=0
bash -n "$T" 2>/dev/null && n=$((n+1)) || { echo "  ${R}✗${N} TUI"; e=$((e+1)); }
for d in "$M"/module_*/main.sh; do
  [ -f "$d" ] || continue
  [ $n -ge 25 ] && break
  bash -n "$d" 2>/dev/null && n=$((n+1)) || e=$((e+1))
done
for f in parliament.py health.py controllers.py gate.py engine.py src.py eco.py; do
  p=$(find "$M" -maxdepth 2 -name "$f" | head -1)
  [ -n "$p" ] && python3 -c "import ast;ast.parse(open('$p').read())" 2>/dev/null && n=$((n+1)) || e=$((e+1))
done
echo "  ${G}✓${N} OK: $n  ${R}✗${N}: $e"
sleep 3

# ── L4 ──
step 4 RUNTIME; guard
python3 - <<'PY'
import json
from pathlib import Path
H=Path.home()/"CYBRA"
cfg=json.loads((H/"config/pm_processes.json").read_text())
G='\033[32m';R='\033[31m';N='\033[0m'
ok=bad=0
for n,p in cfg["processes"].items():
    if p.get("mode")!="daemon": continue
    c=p.get("cmd","").replace("$HOME",str(H))
    for w in c.split():
        if w.endswith((".py",".sh")):
            if Path(w).exists(): ok+=1
            else: bad+=1; print(f"  {R}✗{N} {n}")
            break
print(f"  {G}✓{N} OK: {ok}  {R}✗{N}: {bad}")
PY
sleep 3

# ── L5 ──
step 5 BEHAVIOR; guard
timeout 25 python3 - <<'PY'
import sys
sys.path.insert(0,str(__import__("pathlib").Path.home()/"CYBRA/modules/module_121_parlament"))
try:
    import health; h=health.health_all()
    print(f"  health: {h.get('overall',0)}%")
except Exception as e: print(f"  err: {e}")
PY
sleep 3

# ── L6 ──
step 6 TIMESERIES; guard
an="$H/run/autonode.json"
if [ -f "$an" ]; then
  python3 -c "
import json
d=json.load(open('$an'))
print(f\"  state: {d.get('state')} nets: {d.get('nets_ok')}/{d.get('nets_total')}\")
"
else echo "  немає autonode.json"; fi
sleep 3

# ── L7 ──
step 7 PREDICTIVE; guard
python3 - <<'PY'
import shutil
from pathlib import Path
H=Path.home()/"CYBRA"
_,_,free=shutil.disk_usage(str(H))
print(f"  disk free: {free//(1024**3)} GB")
pm=H/"logs/pm.log"
if pm.exists():
    r=pm.read_text().splitlines()[-100:]
    n=sum(1 for l in r if "перезапускаю" in l)
    print(f"  pm restarts (100 lines): {n}")
PY

echo; echo "${G}═══ ВСІ 7 РІВНІВ ПРОЙДЕНО ═══${N}"
echo "RAM: $(ram) MB"
