#!/usr/bin/env bash
set +e

ROOT="${CYBRA_ROOT:-$PWD}"
cd "$ROOT" || exit 1

mkdir -p posts feeds proofs logs/hybrid data/cybra_cloud_background/reports runtime/redis

export REAL_PAYMENT_NOW=false
export AUTOMATIC_SWIFT=false
export AUTOMATIC_EXTERNAL_TX=false
export CYBRA_MAINNET_DEPLOY_ALLOWED=false
export CYBRA_SAFE_MODE=true

IS_TERMUX=false
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then
  IS_TERMUX=true
fi

echo "=== CYBRA CLOUD HEAVY CYCLE ==="
echo "ROOT=$ROOT"
echo "TERMUX=$IS_TERMUX"
echo "TIME=$(date -Is)"

# У Termux важкий цикл НЕ запускаємо, тільки створюємо звіт.
if [ "$IS_TERMUX" = "true" ] && [ "${FORCE_LOCAL_HEAVY:-false}" != "true" ]; then
  python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.cwd()

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

def exists(p): return (ROOT / p).exists()

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=15)
        return p.stdout.strip()
    except Exception:
        return ""

def rlen(key):
    out = run(["redis-cli", "LLEN", key])
    return int(out) if out.isdigit() else 0

obj = {
    "status": "TERMUX_SKIPPED_HEAVY_CLOUD_CYCLE",
    "reason": "Heavy cloud cycle is offloaded to GitHub Actions / Codespace to avoid Termux crash.",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "environment": {
        "termux": True,
        "github_actions": False,
        "codespaces": False
    },
    "offload": {
        "github_workflow": ".github/workflows/cybra-hybrid-cloud.yml",
        "codespace_script": "scripts/cybra_codespace_limited_bg.sh",
        "local_termux_script": "cybra_hybrid_bg.sh"
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
        "mainnet_deploy_allowed": False,
        "manual_OWNER_approval_required": True
    }
}
obj["overall_status"] = "OK"
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_cloud_background/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_cloud_background_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_cloud_background/reports/latest_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = [
    "# CYBRA Cloud Background Report",
    "",
    "Overall status: OK",
    "",
    "Status: TERMUX_SKIPPED_HEAVY_CLOUD_CYCLE",
    "",
    "Reason: Heavy cloud cycle is offloaded to GitHub Actions / Codespace to avoid Termux crash.",
    "",
    "## Queues"
]
for k,v in obj["queues"].items():
    md.append(f"{k}: {v}")
md += ["", "## Safety"]
for k,v in obj["safety"].items():
    md.append(f"{k}: {v}")
md += ["", "## Double SHA", obj["double_sha"]]

(ROOT / "posts/cybra_cloud_background_report.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_cloud_background.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_cloud_background_report.json",
        "posts/cybra_cloud_background_report.md",
        "data/cybra_cloud_background/reports/latest_report.json"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ Termux heavy cycle skipped safely")
print("REPORT: posts/cybra_cloud_background_report.md")
print("DOUBLE_SHA:", obj["double_sha"])
PY
  exit 0
fi

if command -v redis-cli >/dev/null 2>&1; then
  if ! redis-cli ping >/dev/null 2>&1; then
    command -v redis-server >/dev/null 2>&1 && \
      redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$ROOT/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
    sleep 1
  fi
fi

run_safe(){
  NAME="$1"
  shift
  echo
  echo "=== RUN $NAME ==="
  timeout 150 "$@" > "logs/hybrid/cloud_${NAME}.log" 2>&1 || true
  tail -n 20 "logs/hybrid/cloud_${NAME}.log" 2>/dev/null || true
}

[ -f cybra_ai_blocks.sh ] && run_safe ai_blocks bash cybra_ai_blocks.sh until-done
[ -f cybra_task_test.sh ] && run_safe task_test bash cybra_task_test.sh run
[ -f cybra_it_evolution.sh ] && run_safe it_evolution bash cybra_it_evolution.sh report
[ -f cybra_it_menu.sh ] && run_safe it_menu bash cybra_it_menu.sh report
[ -f cybra_evolution.sh ] && run_safe evolution bash cybra_evolution.sh today
[ -f cybra_autoheal.sh ] && run_safe autoheal bash cybra_autoheal.sh cycle
[ -f cybra_security_analytics.sh ] && run_safe security bash cybra_security_analytics.sh cycle
[ -f cybra_conformation8.sh ] && run_safe conformation8 bash cybra_conformation8.sh cycle
[ -f cybra_what_missing.sh ] && run_safe what_missing bash cybra_what_missing.sh

python3 - <<'PY'
import json, time, hashlib, subprocess, os
from pathlib import Path

ROOT = Path.cwd()

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))
def exists(p): return (ROOT / p).exists()

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=15)
        return p.stdout.strip()
    except Exception:
        return ""

def rlen(key):
    out = run(["redis-cli", "LLEN", key])
    return int(out) if out.isdigit() else 0

obj = {
    "status": "CYBRA_CLOUD_HEAVY_CYCLE_COMPLETED",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "environment": {
        "github_actions": bool(os.environ.get("GITHUB_ACTIONS")),
        "codespaces": bool(os.environ.get("CODESPACES")),
        "repo": os.environ.get("GITHUB_REPOSITORY", "")
    },
    "modules": {
        "task_test": exists("cybra_task_test.sh"),
        "it_menu": exists("cybra_it_menu.sh"),
        "it_department": exists("cybra_it_evolution.sh"),
        "evolution": exists("cybra_evolution.sh"),
        "autoheal": exists("cybra_autoheal.sh"),
        "security": exists("cybra_security_analytics.sh"),
        "conformation8": exists("cybra_conformation8.sh")
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
        "mainnet_deploy_allowed": False,
        "manual_OWNER_approval_required": True
    }
}
obj["overall_status"] = "OK" if obj["queues"]["parliament_failed"] == 0 else "NEEDS_ATTENTION"
obj["double_sha"] = dsha(obj)

(ROOT / "feeds").mkdir(exist_ok=True)
(ROOT / "posts").mkdir(exist_ok=True)
(ROOT / "proofs").mkdir(exist_ok=True)
(ROOT / "data/cybra_cloud_background/reports").mkdir(parents=True, exist_ok=True)

(ROOT / "feeds/cybra_cloud_background_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
(ROOT / "data/cybra_cloud_background/reports/latest_report.json").write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

md = ["# CYBRA Cloud Background Report", "", f"Overall status: {obj['overall_status']}", "", "## Environment"]
for k,v in obj["environment"].items():
    md.append(f"{k}: {v}")
md += ["", "## Modules"]
for k,v in obj["modules"].items():
    md.append(f"{k}: {v}")
md += ["", "## Queues"]
for k,v in obj["queues"].items():
    md.append(f"{k}: {v}")
md += ["", "## Safety"]
for k,v in obj["safety"].items():
    md.append(f"{k}: {v}")
md += ["", "## Double SHA", obj["double_sha"]]

(ROOT / "posts/cybra_cloud_background_report.md").write_text("\n".join(md), encoding="utf-8")

with (ROOT / "proofs/cybra_cloud_background.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/cybra_cloud_background_report.json",
        "posts/cybra_cloud_background_report.md",
        "data/cybra_cloud_background/reports/latest_report.json"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

print("✅ cloud heavy report generated")
print("DOUBLE_SHA:", obj["double_sha"])
PY
