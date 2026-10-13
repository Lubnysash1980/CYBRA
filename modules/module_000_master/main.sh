#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
H="$HOME/CYBRA"; M="$H/modules"
D="$M/module_121_parlament"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; BOLD=$'\e[1m'; N=$'\e[0m'

refresh(){
  clear
  echo "${B}${BOLD}════════════════════════════════════════════════════════════${N}"
  echo "${B}${BOLD}  CYBRA MASTER DASHBOARD${N}      $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
  echo "${B}${BOLD}════════════════════════════════════════════════════════════${N}"
  echo

  # 1. Модулі
  MODS=$(ls -d "$M"/module_* 2>/dev/null | wc -l)
  REAL=0
  for d in "$M"/module_*; do
    [ -f "$d/main.sh" ] || continue
    grep -q "TODO: реалізувати" "$d/main.sh" 2>/dev/null || REAL=$((REAL+1))
  done
  echo "  ${B}▸ Система${N}"
  echo "  Модулів:        $MODS  (реальних: ${G}$REAL${N})"

  # 2. Мережа
  if [ -f "$H/config/networks.json" ]; then
    NET=$(python3 -c "
import json
d = json.load(open('$H/config/networks.json'))
n = d['networks'][d['current']]
col = '\033[33m' if n.get('type')=='testnet' else '\033[32m'
print(f\"{col}{n['name']}\033[0m (chain_id {n['chain_id']})\")
" 2>/dev/null)
    echo "  Мережа:         $NET"
  fi

  # 3. AutoNode
  if pgrep -f "autonode/daemon.py" >/dev/null; then
    AN=$(python3 -c "
import json, os
try:
    d = json.load(open('$H/run/autonode.json'))
    nets = d.get('networks', {})
    ok = sum(1 for v in nets.values() if v.get('state')=='ok')
    print(f'\033[32m● running\033[0m ({ok}/{len(nets)} online)')
except: print('\033[32m● running\033[0m')
" 2>/dev/null)
  else
    AN="${R}○ stopped${N}"
  fi
  echo "  AutoNode:       $AN"

  # 4. Watchdog / Orchestrator
  if pgrep -f "parlament/watchdog" >/dev/null; then
    WD="${G}● running${N}"
  else
    WD="${R}○ stopped${N}"
  fi
  echo "  Watchdog:       $WD"

  if pgrep -f "orchestrator.py daemon" >/dev/null; then
    OC="${G}● running${N}"
  else
    OC="${R}○ stopped${N}"
  fi
  echo "  Orchestrator:   $OC"

  # 5. Completion score
  if [ -f "$D/completion.py" ]; then
    SCORE=$(python3 "$D/completion.py" score 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('overall','?'))" 2>/dev/null)
    [ -n "$SCORE" ] && echo "  Completion:     ${G}${SCORE}%${N}"
  fi

  # 6. Парламент
  if [ -f "$D/parliament.py" ]; then
    PARL=$(python3 -c "
import sys, os
sys.path.insert(0, '$D')
import parliament as P
props = P.proposals()
op = len([p for p in props if p.get('status')=='open'])
ap = len([p for p in props if p.get('status')=='approved'])
print(f'{len(props)} всього · {op} open · {ap} approved')
" 2>/dev/null)
    echo "  Парламент:      $PARL"
  fi

  # 7. Мережі (AutoNode)
  echo
  echo "  ${B}▸ Мережі${N}"
  python3 -c "
import json, os
p = '$H/run/autonode.json'
if not os.path.exists(p): print('    (немає даних)'); exit()
d = json.load(open(p))
for name, v in d.get('networks', {}).items():
    col = '\033[32m' if v.get('state')=='ok' else '\033[31m'
    blk = v.get('block') or '-'
    lat = v.get('latency_ms') or '-'
    print(f\"    {col}{v.get('name','?'):10s}\033[0m  block {blk}  {lat} ms\")
" 2>/dev/null

  # 8. Останні події
  echo
  echo "  ${B}▸ Останні дії${N}"
  if [ -f "$D/data/exec_log.jsonl" ]; then
    tail -5 "$D/data/exec_log.jsonl" | python3 -c "
import sys, json
for line in sys.stdin:
    try: e=json.loads(line)
    except: continue
    mark = '\033[32m✓\033[0m' if e.get('ok') else '\033[31m✗\033[0m'
    print(f\"    {mark} {e.get('action','?'):24s} {e.get('msg','')[:45]}\")
" 2>/dev/null
  else
    echo "    (немає)"
  fi

  # 9. Диск
  echo
  echo "  ${B}▸ Ресурси${N}"
  FREE=$(df -m "$H" 2>/dev/null | tail -1 | awk '{print $4}')
  [ -n "$FREE" ] && echo "  Диск:           ${FREE} MB вільно"
  echo "  Time:           $(date -u +'%Y-%m-%d %H:%M:%S')"

  echo
  echo "  ${DIM}[r] оновити   [q] вихід${N}"
}

refresh
while :; do
  read -n 1 -s -t 30 c || { refresh; continue; }
  case "$c" in
    r|R) refresh ;;
    q|Q) exit 0 ;;
  esac
done
