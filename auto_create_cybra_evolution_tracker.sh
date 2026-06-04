#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CREATE CYBRA EVOLUTION TRACKER ==="

mkdir -p \
  data/cybra_evolution/daily \
  data/cybra_evolution/reports \
  posts feeds proofs logs/cybra_evolution runtime/redis \
  parliament/committees/evolution_tracker_committee \
  .github/workflows

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

cat > parliament/committees/evolution_tracker_committee/committee.json <<'JSON'
{
  "committee_id": "evolution_tracker_committee",
  "name": "CYBRA Evolution Tracker Committee",
  "status": "active",
  "parent": "cybra_parliament",
  "mission": "Щоденно вимірювати еволюцію CYBRA/KYBRA системи: прогрес у відсотках, приріст блоків, готовність модулів, помилки, фінансові блокери, recovery, dashboard, GitHub/Codespace readiness.",
  "metrics": [
    "module_readiness",
    "report_readiness",
    "recovery_readiness",
    "dashboard_readiness",
    "codespace_github_readiness",
    "kibra_growth",
    "parliament_health",
    "finance_readiness",
    "market_proof_readiness",
    "security_health"
  ],
  "safety": {
    "real_payment_now": false,
    "automatic_SWIFT": false,
    "automatic_external_tx": false,
    "manual_OWNER_approval_required": true
  }
}
JSON

cat > cybra_evolution_tracker.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timedelta

ROOT = Path.home() / "CYBRA"
AUDIT_KEY = "cybra:evolution:audit"

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))
def today(): return datetime.now().strftime("%Y-%m-%d")
def now_iso(): return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd, timeout=90):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def exists(p): return (ROOT / p).exists()
def count(pattern): return len(list(ROOT.glob(pattern)))

def rlen(key):
    code, out, _ = run(["redis-cli", "LLEN", key], timeout=20)
    return int(out) if code == 0 and out.strip().isdigit() else 0

def rpush(key, obj):
    run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)], timeout=20)

def load_json(path, default=None):
    p = ROOT / path
    if not p.exists():
        return default if default is not None else {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def save_json(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def ensure_redis():
    code, out, _ = run(["redis-cli", "ping"], timeout=20)
    if code == 0 and out == "PONG":
        return True
    (ROOT / "runtime/redis").mkdir(parents=True, exist_ok=True)
    run(["redis-server", "--daemonize", "yes", "--bind", "127.0.0.1", "--port", "6379", "--dir", str(ROOT / "runtime/redis"), "--save", "", "--appendonly", "no"], timeout=30)
    time.sleep(1)
    code, out, _ = run(["redis-cli", "ping"], timeout=20)
    return code == 0 and out == "PONG"

def metric_ratio(items):
    if not items:
        return 0
    return round(sum(1 for x in items if x) / len(items) * 100, 2)

def snapshot():
    ensure_redis()

    modules = {
        "menubar": exists("cybra_menubar.sh"),
        "recovery": exists("cybra_recovery.sh") and exists("cybra_termux_restore.sh"),
        "autoheal": exists("cybra_autoheal.sh"),
        "security": exists("cybra_security_analytics.sh"),
        "conformation8": exists("cybra_conformation8.sh"),
        "dashboard": exists("cybra_dashboard.sh"),
        "codespace_runtime": exists("cybra_codespace_runtime.sh"),
        "github_workflow": exists(".github/workflows/cybra-codespace-runtime.yml"),
        "parliament_executor": exists("parliament_executor_v6.py"),
        "kibra_stats": exists("cybra_kibra_stats.sh"),
        "payment": exists("cybra_payment_requisites.sh"),
        "market_gate": exists("cybra_real_market_price_gate.sh"),
        "frozen_committee": exists("cybra_frozen_committee.sh"),
        "hash_license_guard": exists("hash_license_guard.sh")
    }

    reports = {
        "menubar": exists("posts/cybra_menubar_report.md"),
        "recovery": exists("posts/cybra_autorecovery_report.md"),
        "recovery_test": exists("posts/cybra_menubar_recovery_test_report.md"),
        "autoheal": exists("posts/cybra_autoheal_7lvl_report.md"),
        "security": exists("posts/cybra_security_analytics_report.md"),
        "conformation8": exists("posts/cybra_conformation8_report.md"),
        "dashboard": exists("posts/cybra_dashboard_report.md"),
        "codespace_runtime": exists("posts/cybra_codespace_runtime_report.md"),
        "kibra_stats": exists("posts/kibra_stats_recommendations_report.md"),
        "mint_promo": exists("posts/cybra_mint_promo_report.md"),
        "ai_blocks": exists("posts/cybra_ai_blocks_report.md")
    }

    payment = load_json("feeds/cybra_payment_requisites_package.json", {})
    market = load_json("feeds/kibra_real_market_price_gate.json", {})
    validation = payment.get("validation", {})

    main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
    task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")
    estimated_kibra = (main_blocks + task_blocks) * 100

    queues = {
        "ai_block_inbox": rlen("cybra:ai:tasks:block_inbox"),
        "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
        "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
        "parliament_queue": rlen("cybra:parliament:queue"),
        "parliament_results": rlen("cybra:parliament:results"),
        "parliament_failed": rlen("cybra:parliament:failed")
    }

    score_parts = {
        "module_readiness": metric_ratio(modules.values()),
        "report_readiness": metric_ratio(reports.values()),
        "recovery_readiness": metric_ratio([
            modules["recovery"],
            reports["recovery"],
            reports["recovery_test"],
            exists("data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz")
        ]),
        "github_codespace_readiness": metric_ratio([
            modules["codespace_runtime"],
            modules["github_workflow"],
            exists(".devcontainer/devcontainer.json"),
            reports["codespace_runtime"]
        ]),
        "parliament_health": 100 if queues["parliament_failed"] == 0 else 40,
        "kibra_growth": min(100, round((task_blocks / 300) * 100, 2)),
        "finance_readiness": metric_ratio([
            validation.get("ready", False),
            validation.get("bank_ready", False) or validation.get("psp_ready", False)
        ]),
        "market_readiness": 100 if market.get("real_market_confirmed", False) else 0,
        "security_health": 100 if reports["security"] and reports["autoheal"] and reports["conformation8"] else 50
    }

    weights = {
        "module_readiness": 0.18,
        "report_readiness": 0.14,
        "recovery_readiness": 0.12,
        "github_codespace_readiness": 0.10,
        "parliament_health": 0.10,
        "kibra_growth": 0.12,
        "finance_readiness": 0.08,
        "market_readiness": 0.06,
        "security_health": 0.10
    }

    score = round(sum(score_parts[k] * weights[k] for k in weights), 2)

    obj = {
        "status": "evolution_snapshot",
        "date": today(),
        "time": time.time(),
        "time_iso": now_iso(),
        "score_percent": score,
        "score_parts": score_parts,
        "modules": modules,
        "reports": reports,
        "blocks": {
            "main_blocks": main_blocks,
            "task_blocks": task_blocks,
            "estimated_kibra_default_reward_100": estimated_kibra
        },
        "queues": queues,
        "finance": {
            "payment_ready": bool(validation.get("ready", False)),
            "bank_ready": bool(validation.get("bank_ready", False)),
            "psp_ready": bool(validation.get("psp_ready", False)),
            "real_market_confirmed": bool(market.get("real_market_confirmed", False)),
            "price_usd_per_kibra": market.get("price_usd_per_kibra", 0),
            "real_payment_now": False
        },
        "blockers": [],
        "safety": {
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    if not obj["finance"]["payment_ready"]:
        obj["blockers"].append("Payment requisites not ready: add IBAN or PSP provider.")
    if not obj["finance"]["real_market_confirmed"]:
        obj["blockers"].append("Real KIBRA market price not confirmed: add real pool/orderbook/provider proof.")
    if queues["parliament_failed"] > 0:
        obj["blockers"].append("Parliament failed queue is not empty.")
    if not reports["recovery_test"]:
        obj["blockers"].append("Menu-Bar recovery test report missing.")

    obj["double_sha"] = dsha(obj)
    return obj

def previous_snapshot(date_str):
    d = datetime.strptime(date_str, "%Y-%m-%d")
    for i in range(1, 31):
        prev = (d - timedelta(days=i)).strftime("%Y-%m-%d")
        p = ROOT / f"data/cybra_evolution/daily/{prev}.json"
        if p.exists():
            return load_json(f"data/cybra_evolution/daily/{prev}.json", {})
    return {}

def make_report():
    snap = snapshot()
    date = snap["date"]
    prev = previous_snapshot(date)

    delta = None
    movement = "baseline"
    if prev:
        delta = round(snap["score_percent"] - float(prev.get("score_percent", 0)), 2)
        if delta > 0.2:
            movement = "evolved"
        elif delta < -0.2:
            movement = "regressed"
        else:
            same_blocks = snap["blocks"]["task_blocks"] == prev.get("blocks", {}).get("task_blocks")
            movement = "standing_still" if same_blocks else "stable_but_blocks_changed"

    snap["previous_score_percent"] = prev.get("score_percent") if prev else None
    snap["daily_delta_percent"] = delta
    snap["movement"] = movement

    save_json(f"data/cybra_evolution/daily/{date}.json", snap)
    save_json("data/cybra_evolution/reports/latest_report.json", snap)
    save_json("feeds/cybra_evolution_today.json", snap)

    lines = []
    lines.append("# CYBRA Daily Evolution Report")
    lines.append("")
    lines.append(f"Date: {date}")
    lines.append(f"Evolution score: {snap['score_percent']}%")
    lines.append(f"Previous score: {snap['previous_score_percent']}")
    lines.append(f"Daily delta: {snap['daily_delta_percent']}")
    lines.append(f"Movement: {snap['movement']}")
    lines.append("")
    lines.append("## Score parts")
    for k, v in snap["score_parts"].items():
        lines.append(f"{k}: {v}%")
    lines.append("")
    lines.append("## Blocks / KIBRA")
    for k, v in snap["blocks"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Queues")
    for k, v in snap["queues"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Finance")
    for k, v in snap["finance"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Blockers")
    if snap["blockers"]:
        for b in snap["blockers"]:
            lines.append("- " + b)
    else:
        lines.append("None")
    lines.append("")
    lines.append("## Recommendation for tomorrow")
    if snap["movement"] == "standing_still":
        lines.append("- Система стоїть на місці: додати нові task-blocks або закрити один блокер.")
    elif snap["movement"] == "evolved":
        lines.append("- Є прогрес: закріпити звіти, прогнати safe cycle, додати наступні задачі в mining blocks.")
    elif snap["movement"] == "regressed":
        lines.append("- Є відкат: запустити AutoHeal, Recovery, Security, Conformation8.")
    else:
        lines.append("- Це базова точка. Завтра буде порівняння.")
    lines.append("")
    lines.append("## Safety")
    for k, v in snap["safety"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(snap["double_sha"])

    (ROOT / "posts/cybra_evolution_today.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/cybra_evolution_today.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/cybra_evolution_today.json",
            "posts/cybra_evolution_today.md",
            "data/cybra_evolution/reports/latest_report.json",
            f"data/cybra_evolution/daily/{date}.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    rpush(AUDIT_KEY, {
        "status": "daily_evolution_report",
        "date": date,
        "score_percent": snap["score_percent"],
        "movement": snap["movement"],
        "double_sha": snap["double_sha"],
        "time": snap["time"]
    })

    print("✅ CYBRA Evolution report generated")
    print("DATE:", date)
    print("SCORE:", str(snap["score_percent"]) + "%")
    print("MOVEMENT:", snap["movement"])
    print("DELTA:", snap["daily_delta_percent"])
    print("REPORT: posts/cybra_evolution_today.md")
    print("PROOF: proofs/cybra_evolution_today.sha256")

def status():
    rep = load_json("data/cybra_evolution/reports/latest_report.json", {})
    if not rep:
        make_report()
        rep = load_json("data/cybra_evolution/reports/latest_report.json", {})
    print("CYBRA_EVOLUTION_TRACKER: active")
    print("DATE:", rep.get("date"))
    print("SCORE:", str(rep.get("score_percent")) + "%")
    print("PREVIOUS:", rep.get("previous_score_percent"))
    print("DELTA:", rep.get("daily_delta_percent"))
    print("MOVEMENT:", rep.get("movement"))
    print("TASK_BLOCKS:", rep.get("blocks", {}).get("task_blocks"))
    print("EST_KIBRA:", rep.get("blocks", {}).get("estimated_kibra_default_reward_100"))
    print("PAYMENT_READY:", rep.get("finance", {}).get("payment_ready"))
    print("MARKET_CONFIRMED:", rep.get("finance", {}).get("real_market_confirmed"))

def history():
    files = sorted((ROOT / "data/cybra_evolution/daily").glob("*.json"))
    if not files:
        print("No history yet.")
        return
    print("DATE | SCORE | DELTA | MOVEMENT | TASK_BLOCKS | KIBRA")
    for p in files[-30:]:
        x = load_json(str(p.relative_to(ROOT)), {})
        print(f"{x.get('date')} | {x.get('score_percent')}% | {x.get('daily_delta_percent')} | {x.get('movement')} | {x.get('blocks',{}).get('task_blocks')} | {x.get('blocks',{}).get('estimated_kibra_default_reward_100')}")

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "today"
    if cmd in ["today", "report"]:
        make_report()
    elif cmd == "status":
        status()
    elif cmd == "history":
        history()
    else:
        print("Usage: today|report|status|history")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_evolution_tracker.py

cat > cybra_evolution.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

case "${1:-today}" in
  today|report|status|history)
    python3 cybra_evolution_tracker.py "$1"
    ;;
  start-daily)
    mkdir -p logs/cybra_evolution runtime
    INTERVAL="${2:-86400}"
    nohup bash -c "while true; do cd '$HOME/CYBRA'; python3 cybra_evolution_tracker.py today; sleep $INTERVAL; done" > logs/cybra_evolution/daily.log 2>&1 &
    echo $! > runtime/cybra_evolution_daily.pid
    echo "✅ CYBRA daily evolution tracker started"
    echo "PID: $(cat runtime/cybra_evolution_daily.pid)"
    ;;
  stop-daily)
    if [ -f runtime/cybra_evolution_daily.pid ]; then
      kill "$(cat runtime/cybra_evolution_daily.pid)" 2>/dev/null || true
      rm -f runtime/cybra_evolution_daily.pid
    fi
    echo "✅ stopped"
    ;;
  log)
    tail -f logs/cybra_evolution/daily.log
    ;;
  proof)
    cat proofs/cybra_evolution_today.sha256
    ;;
  *)
    echo "Usage: bash cybra_evolution.sh today|status|history|start-daily|stop-daily|log|proof"
    ;;
esac
EOF

chmod +x cybra_evolution.sh

ln -sf "$HOME/CYBRA/cybra_evolution.sh" "$PREFIX/bin/cybra-evolution" 2>/dev/null || true

echo
echo "=== PATCH MENU-BAR WITH EVOLUTION COMMAND ==="

if [ -f cybra_menubar.sh ]; then
python3 - <<'PY'
from pathlib import Path
p = Path("cybra_menubar.sh")
s = p.read_text(encoding="utf-8", errors="ignore")

if "evolution)" not in s:
    s = s.replace(
        "  proof)\n    cat proofs/cybra_menubar.sha256",
        '''  evolution)
    shift
    bash cybra_evolution.sh "${1:-status}" "$@"
    ;;
  proof)
    cat proofs/cybra_menubar.sha256'''
    )

p.write_text(s, encoding="utf-8")
print("✅ cybra_menubar.sh patched")
PY
fi

cat > .github/workflows/cybra-daily-evolution.yml <<'YAML'
name: CYBRA Daily Evolution

on:
  workflow_dispatch:
  schedule:
    - cron: "33 6 * * *"

permissions:
  contents: write

jobs:
  daily-evolution:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - name: Prepare
        run: |
          sudo apt-get update
          sudo apt-get install -y redis-server redis-tools jq
          mkdir -p "$HOME/CYBRA"
          rm -rf "$HOME/CYBRA"
          ln -s "$GITHUB_WORKSPACE" "$HOME/CYBRA"
          mkdir -p runtime/redis posts feeds proofs data
          redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$GITHUB_WORKSPACE/runtime/redis" --save "" --appendonly no
          sleep 1
          redis-cli ping
          chmod +x cybra_evolution.sh cybra_evolution_tracker.py 2>/dev/null || true

      - name: Run daily evolution
        run: |
          bash cybra_evolution.sh today

      - name: Commit evolution report
        run: |
          set +e
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add \
            data/cybra_evolution \
            posts/cybra_evolution_today.md \
            feeds/cybra_evolution_today.json \
            proofs/cybra_evolution_today.sha256
          if git diff --cached --quiet; then
            echo "No evolution changes"
          else
            git commit -m "CYBRA daily evolution report [skip ci]"
            git push
          fi
YAML

python3 -m py_compile cybra_evolution_tracker.py
rm -rf __pycache__ 2>/dev/null || true

bash cybra_evolution.sh today
sha256sum -c proofs/cybra_evolution_today.sha256 || true

echo
echo "✅ CYBRA EVOLUTION TRACKER CREATED"
echo "Run:"
echo "  cybra-evolution status"
echo "  cybra-evolution history"
echo "  cybra-menu evolution status"
