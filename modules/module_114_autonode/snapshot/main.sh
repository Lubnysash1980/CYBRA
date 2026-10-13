#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
H="$HOME/CYBRA"
D="$H/modules/module_114_autonode"
PID="$H/run/autonode.pid"
ST="$H/run/autonode.json"
LOG="$H/logs/autonode.log"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; DIM=$'\e[2m'; N=$'\e[0m'

running(){ [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; }

start(){
  running && { echo "${Y}!${N} вже працює (PID $(cat $PID))"; return; }
  mkdir -p "$H/run" "$H/logs"
  nohup python3 "$D/daemon.py" >/dev/null 2>&1 &
  echo $! > "$PID"; sleep 1
  running && echo "${G}✓${N} AutoNode v2 (PID $(cat $PID))" \
          || { echo "${R}✗${N} не стартував"; tail -20 "$LOG"; }
}
stop(){
  running || { echo "${Y}!${N} не працює"; return; }
  kill "$(cat $PID)" 2>/dev/null; sleep 1
  kill -9 "$(cat $PID)" 2>/dev/null; rm -f "$PID"
  echo "${G}✓${N} зупинено"
}
status(){
  echo "${B}═══ AutoNode v2 ═══${N}"
  running && echo "  Процес: ${G}● $(cat $PID)${N}" || echo "  Процес: ${R}○ зупинено${N}"
  [ -f "$ST" ] || return
  python3 -c "
import json
d=json.load(open('$ST'))
print(f\"  Uptime: {d.get('uptime_sec',0)}s  ·  Watch: {d.get('watch_count',0)} адрес\")
print()
print(f\"  {'Мережа':10s} {'Стан':14s} {'Блок':>12s} {'Latency':>8s}  Endpoint\")
print('  ' + '-'*78)
for k,v in d.get('networks',{}).items():
    state = '🟢 ok' if v['state']=='ok' else '🔴 '+v['state']
    blk = v.get('block') or '-'
    lat = f\"{v.get('latency_ms','-')}ms\" if v.get('latency_ms') else '-'
    ep = (v.get('endpoint') or '')[:38]
    print(f\"  {v['name']:10s} {state:14s} {blk:>12} {lat:>8s}  {ep}\")
"
}
events(){
  F="$H/run/autonode_events.jsonl"
  [ -f "$F" ] || { echo "нема подій"; return; }
  N="${1:-20}"
  tail -"$N" "$F" | python3 -c "
import sys, json
for line in sys.stdin:
    try: d=json.loads(line)
    except: continue
    t=d.get('ts','?'); ty=d.get('type','?')
    if ty=='balance_change':
        print(f\"{t}  {ty}  {d.get('addr','')[:10]}…  net={d.get('net')}  block={d.get('block')}\")
    else:
        print(f\"{t}  {ty}\")
"
}
add_watch(){
  read -rp "Адреса (0x…): " a
  read -rp "Мітка: " l
  read -rp "Мережі (bsc,eth,polygon) [bsc]: " nets
  nets="${nets:-bsc}"
  python3 - "$a" "$l" "$nets" <<'PY'
import json, sys, os
p = os.path.expanduser("~/CYBRA/modules/module_114_autonode/watch.json")
d = json.load(open(p))
d.setdefault("addresses", []).append({
    "addr": sys.argv[1], "label": sys.argv[2],
    "networks": [x.strip() for x in sys.argv[3].split(",") if x.strip()]
})
json.dump(d, open(p, "w"), indent=2)
print("✓ додано")
PY
  echo "${Y}!${N} перезапусти daemon щоб підхопив: $0 restart"
}
list_watch(){
  python3 -c "
import json, os
p = os.path.expanduser('~/CYBRA/modules/module_114_autonode/watch.json')
d = json.load(open(p))
a = d.get('addresses', [])
if not a: print('  (порожньо)'); exit()
for i, x in enumerate(a, 1):
    print(f\"  {i}. {x['addr']}  [{x['label']}]  nets={','.join(x.get('networks',[]))}\")
"
}
case "${1:-status}" in
  start)   start ;;
  stop)    stop ;;
  restart) stop; sleep 1; start ;;
  status|"") status ;;
  events)  events "${2:-20}" ;;
  watch)   while :; do clear; status; sleep 3; done ;;
  add)     add_watch ;;
  list)    list_watch ;;
  log)     tail -${2:-30} "$LOG" ;;
  *) echo "usage: $0 {start|stop|restart|status|watch|events [n]|add|list|log [n]}" ;;
esac
