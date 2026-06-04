#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

PID_DIR="runtime/cybra_bg/pids"
LOG_DIR="logs/background"
LOCK_DIR="runtime/cybra_bg/locks"

mkdir -p "$PID_DIR" "$LOG_DIR" "$LOCK_DIR" runtime/redis posts feeds proofs data/cybra_background/reports

export CYBRA_BACKGROUND=1
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

start_redis(){
  if redis-cli ping >/dev/null 2>&1; then
    echo "✅ Redis already running"
  else
    redis-server --daemonize yes \
      --bind 127.0.0.1 \
      --port 6379 \
      --dir "$HOME/CYBRA/runtime/redis" \
      --save "" \
      --appendonly no >/dev/null 2>&1 || true
    sleep 1

    if redis-cli ping >/dev/null 2>&1; then
      echo "✅ Redis started"
    else
      echo "⚠ Redis not started"
    fi
  fi
}

start_worker(){
  local name="$1"
  local interval="$2"
  shift 2
  local cmd="$*"

  local oldpid
  oldpid="$(pidof_worker "$name")"

  if alive "$oldpid"; then
    echo "✅ $name already running pid=$oldpid"
    return
  fi

  rm -f "$PID_DIR/$name.pid" "$LOCK_DIR/$name.lock" 2>/dev/null || true

  nohup bash cybra_bg_worker_runner.sh "$name" "$interval" "$cmd" > "$LOG_DIR/$name.log" 2>&1 &
  echo $! > "$PID_DIR/$name.pid"

  sleep 1

  local newpid
  newpid="$(pidof_worker "$name")"

  if alive "$newpid"; then
    echo "✅ started $name pid=$newpid"
  else
    echo "⚠ failed $name"
  fi
}

start_dashboard(){
  local name="dashboard"
  local oldpid
  oldpid="$(pidof_worker "$name")"

  if alive "$oldpid"; then
    echo "✅ dashboard already running pid=$oldpid"
    return
  fi

  rm -f "$PID_DIR/$name.pid" 2>/dev/null || true

  if [ -f cybra_dashboard.sh ]; then
    nohup bash cybra_dashboard.sh start > "$LOG_DIR/dashboard.log" 2>&1 &
    echo $! > "$PID_DIR/$name.pid"
  elif [ -f cybra_dashboard.py ]; then
    nohup python3 -m uvicorn cybra_dashboard:app --host 127.0.0.1 --port 8099 > "$LOG_DIR/dashboard.log" 2>&1 &
    echo $! > "$PID_DIR/$name.pid"
  else
    echo "⚠ dashboard files missing"
    return
  fi

  sleep 2
  echo "✅ dashboard background requested"
}

start_all(){
  echo "=== START CYBRA BACKGROUND PLATFORM ==="

  command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock || true

  start_redis

  start_worker redis_guard 60 '
    mkdir -p runtime/redis
    redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  '

  start_worker task_processor 240 '
    [ -f cybra_ai_blocks.sh ] && bash cybra_ai_blocks.sh until-done || true
    [ -f cybra_task_test.sh ] && bash cybra_task_test.sh run || true
  '

  start_worker it_department 600 '
    [ -f cybra_it_evolution.sh ] && bash cybra_it_evolution.sh report || true
    [ -f cybra_it_menu.sh ] && bash cybra_it_menu.sh report || true
  '

  start_worker evolution_tracker 3600 '
    [ -f cybra_evolution.sh ] && bash cybra_evolution.sh today || true
  '

  start_worker health_security 900 '
    [ -f cybra_autoheal.sh ] && bash cybra_autoheal.sh cycle || true
    [ -f cybra_security_analytics.sh ] && bash cybra_security_analytics.sh cycle || true
    [ -f cybra_conformation8.sh ] && bash cybra_conformation8.sh cycle || true
  '

  start_worker recovery_watch 1800 '
    [ -f cybra_what_missing.sh ] && bash cybra_what_missing.sh || true
    [ -f cybra_recovery.sh ] && bash cybra_recovery.sh report || true
  '

  start_worker codespace_runtime 1800 '
    [ -f cybra_codespace_runtime.sh ] && bash cybra_codespace_runtime.sh cycle background || true
  '

  start_worker git_status_watch 1800 '
    git status --short > logs/background/git_status_latest.log 2>&1 || true
  '

  start_worker mainnet_safety_watch 3600 '
    mkdir -p token/deploy/solana_mainnet/proofs
    echo "CYBRA mainnet safety watch: no automatic external tx" > logs/background/mainnet_safety_latest.log
    grep -R "real_mainnet_tx_executed" token/deploy/solana_mainnet 2>/dev/null >> logs/background/mainnet_safety_latest.log || true
  '

  start_dashboard

  bash cybra_bg.sh report

  echo
  echo "✅ CYBRA BACKGROUND PLATFORM STARTED"
}

stop_one(){
  local name="$1"
  local pid
  pid="$(pidof_worker "$name")"

  if alive "$pid"; then
    kill "$pid" 2>/dev/null || true
    sleep 1
    kill -9 "$pid" 2>/dev/null || true
    echo "✅ stopped $name"
  else
    echo "already stopped: $name"
  fi

  rm -f "$PID_DIR/$name.pid" "$LOCK_DIR/$name.lock" 2>/dev/null || true
}

stop_all(){
  echo "=== STOP CYBRA BACKGROUND PLATFORM ==="

  for f in "$PID_DIR"/*.pid; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .pid)"
    stop_one "$name"
  done

  command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock || true

  echo "✅ stopped all background workers"
}

status_all(){
  echo "=== CYBRA BACKGROUND STATUS ==="

  for name in redis_guard task_processor it_department evolution_tracker health_security recovery_watch codespace_runtime git_status_watch mainnet_safety_watch dashboard; do
    pid="$(pidof_worker "$name")"
    if alive "$pid"; then
      echo "✅ $name pid=$pid"
    else
      echo "❌ $name stopped"
    fi
  done

  echo
  if redis-cli ping >/dev/null 2>&1; then
    echo "✅ Redis PONG"
  else
    echo "❌ Redis stopped"
  fi

  echo
  echo "Logs:"
  ls -1 "$LOG_DIR" 2>/dev/null || true
}

report_all(){
  python3 - <<'PY'
import json, time, hashlib, subprocess, os
from pathlib import Path

ROOT = Path.home() / "CYBRA"
PID = ROOT / "runtime/cybra_bg/pids"

workers = [
    "redis_guard",
    "task_processor",
    "it_department",
    "evolution_tracker",
    "health_security",
    "recovery_watch",
    "codespace_runtime",
    "git_status_watch",
    "mainnet_safety_watch",
    "dashboard"
]

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(o):
    return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

def alive(pid):
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
        return True
    except Exception:
        return False

def r(cmd):
    p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)
    return p.stdout.strip()

def rlen(key):
    out = r(["redis-cli", "LLEN", key])
    return int(out) if out.isdigit() else 0

status = {}
for w in workers:
    pf = PID / f"{w}.pid"
    pid = pf.read_text().strip() if pf.exists() else ""
    status[w] = {
        "pid": pid,
        "running": alive(pid)
    }

obj = {
    "status": "CYBRA_BACKGROUND_PLATFORM_REPORT",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "workers": status,
    "queues": {
        "ai_block_inbox": rlen("cybra:ai:tasks:block_inbox"),
        "parliament_queue": rlen("cybra:parliament:queue"),
        "parliament_failed": rlen("cybra:parliament:failed"),
        "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
        "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
        "it_department": rlen("cybra:it_department:queue"),
        "evolution": rlen("cybra:evolution:queue"),
        "security": rlen("cybra:security:queue")
    },
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_external_tx": False,
        "mainnet_deploy_allowed": False,
        "manual_OWNER_approval_required": True
    }
}

obj["running_count"] = sum(1 for x in status.values() if x["running"])
obj["overall_status"] = "OK" if obj["running_count"] >= 8 else "NEEDS_ATTENTION"
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_background/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_background_platform_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_background/reports/latest_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = []
md.append("# CYBRA Background Platform Report")
md.append("")
md.append(f"Overall status: {obj['overall_status']}")
md.append(f"Running workers: {obj['running_count']} / {len(workers)}")
md.append("")
md.append("## Workers")
for k, v in obj["workers"].items():
    md.append(f"{k}: running={v['running']} pid={v['pid']}")
md.append("")
md.append("## Queues")
for k, v in obj["queues"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Safety")
for k, v in obj["safety"].items():
    md.append(f"{k}: {v}")
md.append("")
md.append("## Double SHA")
md.append(obj["double_sha"])

(ROOT / "posts/cybra_background_platform_report.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_background_platform.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_background_platform_report.json",
        "posts/cybra_background_platform_report.md",
        "data/cybra_background/reports/latest_report.json"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ background report generated")
print("OVERALL:", obj["overall_status"])
print("RUNNING:", obj["running_count"])
print("REPORT: posts/cybra_background_platform_report.md")
print("DOUBLE_SHA:", obj["double_sha"])
PY
}

logs_one(){
  local name="${1:-task_processor}"
  tail -n 80 "$LOG_DIR/$name.log" 2>/dev/null || echo "No log for $name"
}

enable_boot(){
  mkdir -p "$HOME/.termux/boot"

  cat > "$HOME/.termux/boot/start-cybra-bg.sh" <<BOOT
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 0
bash cybra_bg.sh start >> "$HOME/CYBRA/logs/background/termux_boot.log" 2>&1
BOOT

  chmod +x "$HOME/.termux/boot/start-cybra-bg.sh"

  echo "✅ boot script created:"
  echo "$HOME/.termux/boot/start-cybra-bg.sh"
  echo "Працює, якщо встановлений Termux:Boot і Android дозволяє автозапуск."
}

disable_boot(){
  rm -f "$HOME/.termux/boot/start-cybra-bg.sh"
  echo "✅ boot disabled"
}

case "${1:-status}" in
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
    logs_one "${2:-task_processor}"
    ;;
  enable-boot)
    enable_boot
    ;;
  disable-boot)
    disable_boot
    ;;
  *)
    echo "Usage:"
    echo "  cybra-bg start"
    echo "  cybra-bg stop"
    echo "  cybra-bg restart"
    echo "  cybra-bg status"
    echo "  cybra-bg report"
    echo "  cybra-bg logs task_processor"
    echo "  cybra-bg enable-boot"
    echo "  cybra-bg disable-boot"
    ;;
esac
