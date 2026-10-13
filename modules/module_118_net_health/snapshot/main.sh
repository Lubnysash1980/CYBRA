#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
ST="$HOME/CYBRA/run/autonode.json"
EV="$HOME/CYBRA/run/autonode_events.jsonl"
B=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'

while :; do
  clear
  echo "${B}════════════════════════════════════════════════════════════${N}"
  echo "${B}  CYBRA · Network Health Dashboard${N}"
  echo "${B}════════════════════════════════════════════════════════════${N}"
  echo "  $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
  echo

  if [ ! -f "$ST" ]; then
    echo "  ${R}нема статусу — AutoNode не запущено${N}"
    echo "  Запусти: ~/CYBRA/modules/module_114_autonode/main.sh start"
    sleep 2; continue
  fi

  python3 -c "
import json, os, time
d=json.load(open('$ST'))
up=d.get('uptime_sec',0)
h=up//3600; m=(up%3600)//60; s=up%60
print(f'  Uptime: {h:02d}:{m:02d}:{s:02d}  ·  Watch addresses: {d.get(\"watch_count\",0)}')
print()
print(f'  {\"Мережа\":12s} {\"Стан\":16s} {\"Блок\":>13s} {\"Latency\":>9s}')
print('  ' + '-'*60)
for k,v in d.get('networks',{}).items():
    if v['state']=='ok':
        st='\033[32m🟢 online\033[0m'
    else:
        st='\033[31m🔴 '+v['state']+'\033[0m'
    blk=str(v.get('block') or '-')
    lat=f\"{v.get('latency_ms','-')}ms\" if v.get('latency_ms') else '-'
    print(f'  {v[\"name\"]:12s} {st:24s} {blk:>13s} {lat:>9s}')
"
  echo
  echo "  ${D}Останні події:${N}"
  if [ -f "$EV" ]; then
    tail -5 "$EV" | python3 -c "
import sys, json
for line in sys.stdin:
    try: d=json.loads(line)
    except: continue
    print(f\"    {d.get('ts','?')}  {d.get('type','?')}\")
"
  else echo "    (нема)"
  fi
  echo
  echo "  ${D}Ctrl+C щоб вийти · оновлення кожні 3 с${N}"
  sleep 3
done
