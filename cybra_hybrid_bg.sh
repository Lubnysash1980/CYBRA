#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

PID_DIR="runtime/cybra_hybrid/pids"
LOG_DIR="logs/hybrid"
MAX_WORKERS=3

mkdir -p "$PID_DIR" "$LOG_DIR" runtime/redis posts feeds proofs data/cybra_hybrid/reports

export REAL_PAYMENT_NOW=false
export AUTOMATIC_SWIFT=false
export AUTOMATIC_EXTERNAL_TX=false
export CYBRA_MAINNET_DEPLOY_ALLOWED=false
export CYBRA_SAFE_MODE=true

alive(){
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

pidof_worker(){
  local name="$1"
  [ -f "$PID_DIR/$name.pid" ] && cat "$PID_DIR/$name.pid"
}

running_count(){
  local n=0
  for f in "$PID_DIR"/*.pid; do
    [ -f "$f" ] || continue
    pid="$(cat "$f")"
    alive "$pid" && n=$((n+1))
  done
  echo "$n"
}

start_redis(){
  if ! redis-cli ping >/dev/null 2>&1; then
    redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
    sleep 1
  fi
}

worker_loop(){
  local name="$1"
  local interval="$2"
  echo $$ > "$PID_DIR/$name.pid"

  while true; do
    echo "[$(date -Is)] $name cycle start"

    case "$name" in
      redis_guard)
        start_redis
        ;;

      termux_bridge)
        start_redis
        [ -f cybra_task_test.sh ] && bash cybra_task_test.sh run >/dev/null 2>&1 || true
        [ -f cybra_it_menu.sh ] && bash cybra_it_menu.sh report >/dev/null 2>&1 || true

        python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=10)
        return p.stdout.strip()
    except Exception:
        return ""

def rlen(key):
    out = run(["redis-cli", "LLEN", key])
    return int(out) if out.isdigit() else 0

obj = {
    "status": "TERMUX_LIGHT_BRIDGE_HEARTBEAT",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "queues": {
        "ai_block_inbox": rlen("cybra:ai:tasks:block_inbox"),
        "parliament_failed": rlen("cybra:parliament:failed"),
        "it_department": rlen("cybra:it_department:queue"),
        "evolution": rlen("cybra:evolution:queue")
    },
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False
    }
}
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "data/cybra_hybrid/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_termux_heartbeat.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_hybrid/reports/termux_heartbeat_latest.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "posts/cybra_termux_heartbeat.md").write_text("# CYBRA Termux Heartbeat\n\nStatus: TERMUX_LIGHT_BRIDGE_HEARTBEAT\n\nDouble SHA:\n" + obj["double_sha"] + "\n", encoding="utf-8")
PY
        ;;

      cloud_trigger)
        if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
          gh workflow run cybra-hybrid-cloud.yml > logs/hybrid/gh_trigger_latest.log 2>&1 || true
          gh run list --workflow cybra-hybrid-cloud.yml --limit 5 > logs/hybrid/gh_runs_latest.log 2>&1 || true
        else
          echo "$(date -Is) gh not authenticated; GitHub schedule will run after push" > logs/hybrid/gh_trigger_latest.log
        fi
        ;;
    esac

    echo "[$(date -Is)] $name cycle end"
    sleep "$interval"
  done
}

start_worker(){
  local name="$1"
  local interval="$2"

  oldpid="$(pidof_worker "$name")"
  if alive "$oldpid"; then
    echo "✅ $name already running pid=$oldpid"
    return
  fi

  cnt="$(running_count)"
  if [ "$cnt" -ge "$MAX_WORKERS" ]; then
    echo "⚠ max workers reached $cnt/$MAX_WORKERS"
    return
  fi

  nohup bash cybra_hybrid_bg.sh _worker "$name" "$interval" > "$LOG_DIR/$name.log" 2>&1 &
  echo $! > "$PID_DIR/$name.pid"
  sleep 1
  echo "✅ started $name pid=$(cat "$PID_DIR/$name.pid")"
}

start_all(){
  echo "=== START CYBRA HYBRID LIMITED BG V2 ==="
  start_redis
  start_worker redis_guard 60
  start_worker termux_bridge 300
  start_worker cloud_trigger 1800
  bash cybra_hybrid_bg.sh report
}

stop_all(){
  for f in "$PID_DIR"/*.pid; do
    [ -f "$f" ] || continue
    pid="$(cat "$f")"
    name="$(basename "$f" .pid)"
    kill "$pid" 2>/dev/null || true
    sleep 1
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$f"
    echo "✅ stopped $name"
  done
}

status_all(){
  echo "=== CYBRA HYBRID LIMITED BG V2 STATUS ==="
  echo "Running: $(running_count)/$MAX_WORKERS"
  for name in redis_guard termux_bridge cloud_trigger; do
    pid="$(pidof_worker "$name")"
    if alive "$pid"; then
      echo "✅ $name pid=$pid"
    else
      echo "❌ $name stopped"
    fi
  done
  redis-cli ping >/dev/null 2>&1 && echo "✅ Redis PONG" || echo "❌ Redis stopped"
  echo
  tail -n 10 logs/hybrid/gh_trigger_latest.log 2>/dev/null || true
}

report_all(){
  python3 - <<'PY'
import json, time, hashlib, subprocess, os
from pathlib import Path

ROOT = Path.home() / "CYBRA"
PID = ROOT / "runtime/cybra_hybrid/pids"
workers = ["redis_guard", "termux_bridge", "cloud_trigger"]

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

def alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except Exception:
        return False

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=10)
        return p.stdout.strip()
    except Exception:
        return ""

def rlen(key):
    out = run(["redis-cli", "LLEN", key])
    return int(out) if out.isdigit() else 0

status = {}
for w in workers:
    pf = PID / f"{w}.pid"
    pid = pf.read_text().strip() if pf.exists() else ""
    status[w] = {"pid": pid, "running": alive(pid) if pid else False}

obj = {
    "status": "CYBRA_HYBRID_LIMITED_BACKGROUND_V2_REPORT",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "termux_policy": {
        "max_workers": 3,
        "local_workers": workers,
        "heavy_work_offloaded_to": ["GitHub Actions", "Codespace"]
    },
    "workers": status,
    "github_codespace": {
        "workflow": (ROOT / ".github/workflows/cybra-hybrid-cloud.yml").exists(),
        "cloud_script": (ROOT / "scripts/cybra_cloud_heavy_cycle.sh").exists(),
        "codespace_script": (ROOT / "scripts/cybra_codespace_limited_bg.sh").exists(),
        "devcontainer": (ROOT / ".devcontainer/devcontainer.json").exists()
    },
    "queues": {
        "ai_block_inbox": rlen("cybra:ai:tasks:block_inbox"),
        "parliament_failed": rlen("cybra:parliament:failed"),
        "it_department": rlen("cybra:it_department:queue"),
        "evolution": rlen("cybra:evolution:queue")
    },
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "mainnet_deploy_allowed": False
    }
}
obj["running_count"] = sum(1 for x in status.values() if x["running"])
obj["overall_status"] = "OK" if obj["running_count"] >= 2 and obj["queues"]["parliament_failed"] == 0 else "NEEDS_ATTENTION"
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_hybrid/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_hybrid_background_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_hybrid/reports/latest_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = ["# CYBRA Hybrid Limited Background V2 Report", "", f"Overall status: {obj['overall_status']}", "", "## Workers"]
for k,v in obj["workers"].items():
    md.append(f"{k}: running={v['running']} pid={v['pid']}")
md += ["", "## GitHub / Codespace"]
for k,v in obj["github_codespace"].items():
    md.append(f"{k}: {v}")
md += ["", "## Queues"]
for k,v in obj["queues"].items():
    md.append(f"{k}: {v}")
md += ["", "## Double SHA", obj["double_sha"]]

(ROOT / "posts/cybra_hybrid_background_report.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_hybrid_background.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_hybrid_background_report.json",
        "posts/cybra_hybrid_background_report.md",
        "data/cybra_hybrid/reports/latest_report.json"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ hybrid report generated")
print("OVERALL:", obj["overall_status"])
print("RUNNING:", obj["running_count"])
print("DOUBLE_SHA:", obj["double_sha"])
PY
}

case "${1:-status}" in
  _worker)
    worker_loop "$2" "$3"
    ;;
  start)
    start_all
    ;;
  stop)
    stop_all
    ;;
  restart)
    stop_all
    sleep 2
    start_all
    ;;
  status)
    status_all
    ;;
  report)
    report_all
    ;;
  logs)
    tail -n 120 "$LOG_DIR/${2:-termux_bridge}.log" 2>/dev/null || true
    ;;
  cloud-now)
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      gh workflow run cybra-hybrid-cloud.yml
      gh run list --workflow cybra-hybrid-cloud.yml --limit 5
    else
      echo "gh not authenticated. Use: gh auth login"
    fi
    ;;
  *)
    echo "Usage: cybra-hybrid start|stop|restart|status|report|logs NAME|cloud-now"
    ;;
esac
