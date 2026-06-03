#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

echo "=== CREATE CYBRA GITHUB / CODESPACES AUTONOMY ==="

mkdir -p \
  .github/workflows \
  .devcontainer \
  bin \
  parliament/committees/github_autonomy_committee \
  parliament/departments/finance_department/github_autonomy_committee \
  parliament/departments/cybra_finance_department/github_autonomy_committee \
  data/cybra_github_autonomy/reports \
  data/cybra_github_autonomy/tasks \
  posts feeds proofs logs/github_autonomy runtime/redis runtime

echo
echo "=== 1. COMMITTEE ==="

cat > parliament/committees/github_autonomy_committee/committee.json <<'JSON'
{
  "committee_id": "github_autonomy_committee",
  "name": "CYBRA GitHub / Codespaces Autonomy Committee",
  "status": "active",
  "parent": "cybra_parliament",
  "mission": "Make CYBRA/KYBRA work on GitHub Codespaces and GitHub Actions: bootstrap, scheduled safe cycles, reports, proofs, AI tasks to Parliament and mining blocks.",
  "scope": [
    "GitHub Codespaces bootstrap",
    "GitHub Actions scheduled cycles",
    "Redis local runner per cycle",
    "safe test/autofix",
    "dashboard report",
    "parliament AI task submission",
    "closed SHA bridge cycle",
    "proof generation"
  ],
  "limits": [
    "GitHub Actions is scheduled/ephemeral, not a permanent daemon",
    "Codespaces is interactive development environment",
    "No real payment",
    "No SWIFT",
    "No external crypto transaction",
    "No private keys or seed phrases",
    "No private tax ID publication"
  ],
  "manual_OWNER_approval_required": true
}
JSON

cp parliament/committees/github_autonomy_committee/committee.json \
   parliament/departments/finance_department/github_autonomy_committee/committee.json 2>/dev/null || true

cp parliament/committees/github_autonomy_committee/committee.json \
   parliament/departments/cybra_finance_department/github_autonomy_committee/committee.json 2>/dev/null || true

echo
echo "=== 2. DEVCONTAINER FOR CODESPACES ==="

cat > .devcontainer/Dockerfile <<'EOF'
FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    git \
    redis-server \
    redis-tools \
    curl \
    jq \
    openssh-client \
    ca-certificates \
    coreutils \
    findutils \
    bash \
    nano \
 && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip \
 && python -m pip install redis fastapi uvicorn

WORKDIR /workspaces/CYBRA
EOF

cat > .devcontainer/devcontainer.json <<'EOF'
{
  "name": "CYBRA Codespaces",
  "build": {
    "dockerfile": "Dockerfile"
  },
  "workspaceFolder": "/workspaces/CYBRA",
  "postCreateCommand": "bash .devcontainer/post-create.sh",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-azuretools.vscode-docker"
      ]
    }
  }
}
EOF

cat > .devcontainer/post-create.sh <<'EOF'
#!/usr/bin/env bash
set +e

cd /workspaces/CYBRA || exit 0

echo "=== CYBRA Codespaces post-create ==="

mkdir -p "$HOME/CYBRA" runtime/redis logs posts feeds proofs data
rm -rf "$HOME/CYBRA"
ln -s /workspaces/CYBRA "$HOME/CYBRA"

redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no || true
sleep 1
redis-cli ping || true

find . -maxdepth 2 -type f \( -name "*.sh" -o -path "./bin/*" \) -exec chmod +x {} \; 2>/dev/null || true

python3 -m py_compile cybra_github_autonomy.py 2>/dev/null || true

bash github_autonomous_cycle.sh codespaces || true

echo "✅ CYBRA Codespaces ready"
echo "Run dashboard if needed:"
echo "bash cybra_dashboard.sh start 8099 127.0.0.1"
EOF

chmod +x .devcontainer/post-create.sh

echo
echo "=== 3. GITHUB ACTIONS WORKFLOW ==="

cat > .github/workflows/cybra-autonomous-cycle.yml <<'YAML'
name: CYBRA Autonomous Cycle

on:
  workflow_dispatch:
  schedule:
    - cron: "17 */6 * * *"

permissions:
  contents: write

concurrency:
  group: cybra-autonomous-cycle
  cancel-in-progress: false

jobs:
  cybra-cycle:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout CYBRA
        uses: actions/checkout@v4

      - name: Prepare environment
        run: |
          set +e
          sudo apt-get update
          sudo apt-get install -y redis-server redis-tools jq
          python3 -m pip install --upgrade pip
          python3 -m pip install redis fastapi uvicorn
          mkdir -p "$HOME/CYBRA"
          rm -rf "$HOME/CYBRA"
          ln -s "$GITHUB_WORKSPACE" "$HOME/CYBRA"
          mkdir -p runtime/redis logs posts feeds proofs data
          redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$GITHUB_WORKSPACE/runtime/redis" --save "" --appendonly no
          sleep 1
          redis-cli ping
          find . -maxdepth 2 -type f \( -name "*.sh" -o -path "./bin/*" \) -exec chmod +x {} \; 2>/dev/null || true

      - name: Run CYBRA autonomous safe cycle
        env:
          CYBRA_WORKDIR: ${{ github.workspace }}
          CYBRA_ENV: github_actions
        run: |
          set +e
          bash github_autonomous_cycle.sh github-actions

      - name: Upload CYBRA reports
        uses: actions/upload-artifact@v4
        with:
          name: cybra-autonomous-reports
          path: |
            posts/
            feeds/
            proofs/
            data/cybra_github_autonomy/

      - name: Commit safe generated reports
        run: |
          set +e
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          cat >> .gitignore <<'EOF'
          runtime/
          logs/
          *.log
          *.pid
          dump.rdb
          *.rdb
          .env
          *.key
          *.pem
          id_rsa
          id_ed25519
          *private*
          *secret*
          *token*
          data/cybra_payment_requisites/private/
          posts/private/
          feeds/private/
          proofs/private/
          *.local.json
          owner_identity*
          payer_identity*
          data/cybra_dashboard/dashboard_token.local
          EOF

          git rm --cached dump.rdb 2>/dev/null || true

          git add \
            .github/workflows/cybra-autonomous-cycle.yml \
            .devcontainer \
            github_autonomous_cycle.sh \
            cybra_github_autonomy.py \
            parliament/committees/github_autonomy_committee \
            parliament/departments/finance_department/github_autonomy_committee \
            parliament/departments/cybra_finance_department/github_autonomy_committee \
            data/cybra_github_autonomy \
            posts/cybra_github_autonomy_report.md \
            feeds/cybra_github_autonomy_report.json \
            proofs/cybra_github_autonomy.sha256 \
            .gitignore 2>/dev/null || true

          if git diff --cached --quiet; then
            echo "No safe report changes to commit"
          else
            git commit -m "CYBRA autonomous GitHub cycle report [skip ci]"
            git push
          fi
YAML

echo
echo "=== 4. GITHUB AUTONOMY PYTHON CORE ==="

cat > cybra_github_autonomy.py <<'PY'
#!/usr/bin/env python3
import json
import os
import time
import hashlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("CYBRA_WORKDIR", os.getcwd())).resolve()

AUDIT_KEY = "cybra:github_autonomy:audit"
AI_BLOCK_INBOX = "cybra:ai:tasks:block_inbox"

SAFE_COMMANDS = [
    ["bash", "cybra_redis_committee.sh", "ensure"],
    ["bash", "cybra_security_analytics.sh", "cycle"],
    ["bash", "cybra_conformation8.sh", "cycle"],
    ["bash", "cybra_autoheal.sh", "cycle"],
    ["bash", "cybra_recovery.sh", "report"],
    ["bash", "cybra_kibra_stats.sh", "report"],
    ["bash", "cybra_market_proof_collector.sh", "collect"],
    ["bash", "cybra_real_market_price_gate.sh", "status"],
    ["bash", "cybra_closed_sha_bridge.sh", "cycle"],
    ["python3", "parliament_executor_v6.py"]
]

MODULES = [
    "cybra_redis_committee.sh",
    "cybra_security_analytics.sh",
    "cybra_conformation8.sh",
    "cybra_autoheal.sh",
    "cybra_recovery.sh",
    "cybra_kibra_stats.sh",
    "cybra_dashboard.sh",
    "cybra_payment_requisites.sh",
    "kybra_valid.sh",
    "cybra_market_proof_collector.sh",
    "cybra_real_market_price_gate.sh",
    "cybra_closed_sha_bridge.sh",
    "cybra_frozen_committee.sh",
    "hash_license_guard.sh",
    "bin/cybra-finance-bin"
]

def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(obj):
    text = json.dumps(obj, ensure_ascii=False, sort_keys=True)
    return sha(sha(text))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd, timeout=240):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def exists(path):
    return (ROOT / path).exists()

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def rlen(key):
    code, out, err = run(["redis-cli", "LLEN", key], timeout=20)
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

def redis_ping():
    code, out, err = run(["redis-cli", "ping"], timeout=20)
    return code == 0 and out == "PONG"

def ensure_redis():
    if redis_ping():
        return True
    (ROOT / "runtime/redis").mkdir(parents=True, exist_ok=True)
    run([
        "redis-server",
        "--daemonize", "yes",
        "--bind", "127.0.0.1",
        "--port", "6379",
        "--dir", str(ROOT / "runtime/redis"),
        "--save", "",
        "--appendonly", "no"
    ], timeout=30)
    time.sleep(1)
    return redis_ping()

def mask_private_public_files():
    profile = load_json("data/cybra_payment_requisites/payer_profile.json", {})
    tax_id = str(profile.get("payer_tax_id_or_edrpou", "") or "")
    if not tax_id or len(tax_id) < 4:
        return []
    masked = tax_id[:4] + "******"
    changed = []
    for folder in ["posts", "feeds"]:
        d = ROOT / folder
        if not d.exists():
            continue
        for p in list(d.glob("*.md")) + list(d.glob("*.json")):
            text = p.read_text(encoding="utf-8", errors="ignore")
            if tax_id in text:
                p.write_text(text.replace(tax_id, masked), encoding="utf-8")
                changed.append(str(p.relative_to(ROOT)))
    return changed

def create_ai_task(env_name):
    task = {
        "topic": "CYBRA GitHub / Codespaces autonomy verification",
        "type": "github_autonomy_committee_task",
        "priority": "critical",
        "payload": {
            "source": "github_autonomy_committee",
            "environment": env_name,
            "goal": "Ensure CYBRA/KYBRA works autonomously on GitHub Codespaces and GitHub Actions with safe reports, proofs and AI tasks.",
            "convert_to_mining_block_first": True,
            "send_to_pool_mining": True,
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time(),
        "time_iso": now_iso()
    }
    task["double_sha"] = dsha(task)
    save_json("data/cybra_github_autonomy/tasks/latest_ai_task.json", task)
    rpush(AI_BLOCK_INBOX, task)
    return task

def cycle(env_name="unknown"):
    ensure_redis()

    for m in MODULES:
        p = ROOT / m
        if p.exists():
            try:
                p.chmod(p.stat().st_mode | 0o111)
            except Exception:
                pass

    changed_private = mask_private_public_files()

    results = []
    for cmd in SAFE_COMMANDS:
        if cmd[0] == "bash" and not exists(cmd[1]):
            results.append({"cmd": " ".join(cmd), "ok": False, "missing": True})
            continue
        if cmd[0] == "python3" and not exists(cmd[1]):
            results.append({"cmd": " ".join(cmd), "ok": False, "missing": True})
            continue

        code, out, err = run(cmd, timeout=240)
        results.append({
            "cmd": " ".join(cmd),
            "ok": code == 0,
            "code": code,
            "stdout_tail": out[-1200:],
            "stderr_tail": err[-1200:]
        })

    changed_private += mask_private_public_files()
    ai_task = create_ai_task(env_name)

    main_blocks = count("blockchain/kibra_chain/blocks/block_*.json")
    task_blocks = count("blockchain/kibra_chain/task_blocks/*.json")

    payment = load_json("feeds/cybra_payment_requisites_package.json", {})
    market = load_json("feeds/kibra_real_market_price_gate.json", {})
    security = load_json("feeds/cybra_security_analytics_report.json", {})

    report = {
        "status": "github_autonomy_cycle_completed",
        "time": time.time(),
        "time_iso": now_iso(),
        "environment": env_name,
        "github_actions": os.environ.get("GITHUB_ACTIONS", "false"),
        "codespaces": os.environ.get("CODESPACES", "false"),
        "root": str(ROOT),
        "redis": redis_ping(),
        "modules": {m: exists(m) for m in MODULES},
        "blocks": {
            "main_blocks": main_blocks,
            "task_blocks": task_blocks,
            "estimated_kibra_default_reward_100": (main_blocks + task_blocks) * 100
        },
        "queues": {
            "ai_block_inbox": rlen(AI_BLOCK_INBOX),
            "task_block_mempool": rlen("cybra:kibra:task_blocks:mempool"),
            "pool_mining_blocks": rlen("cybra:kibra:pool:mining_blocks"),
            "parliament_queue": rlen("cybra:parliament:queue"),
            "parliament_failed": rlen("cybra:parliament:failed"),
            "parliament_results": rlen("cybra:parliament:results"),
            "github_autonomy_audit": rlen(AUDIT_KEY)
        },
        "finance": {
            "payment_ready": payment.get("validation", {}).get("ready", False),
            "bank_ready": payment.get("validation", {}).get("bank_ready", False),
            "psp_ready": payment.get("validation", {}).get("psp_ready", False),
            "real_market_confirmed": market.get("real_market_confirmed", False),
            "price_usd_per_kibra": market.get("price_usd_per_kibra", 0),
            "real_payment_now": False
        },
        "security": {
            "risk_level": security.get("risk_level", "UNKNOWN"),
            "risk_score": security.get("risk_score"),
            "private_files_masked": list(sorted(set(changed_private))),
            "private_keys_collected": False,
            "seed_phrase_collected": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "commands": results,
        "ai_task_double_sha": ai_task["double_sha"],
        "recommendations": [
            "Run CYBRA in Codespaces for interactive dashboard and development.",
            "Run GitHub Actions scheduled cycle for autonomous safe report/proof refresh.",
            "Keep real payments, SWIFT and external tx disabled until OWNER approval.",
            "Provide real bank IBAN or PSP provider for payment readiness.",
            "Provide real pool/orderbook/provider/reserve proof for KIBRA market price."
        ]
    }

    report["double_sha"] = dsha(report)

    save_json("feeds/cybra_github_autonomy_report.json", report)
    save_json("data/cybra_github_autonomy/reports/latest_report.json", report)

    lines = []
    lines.append("# CYBRA GitHub / Codespaces Autonomy Report")
    lines.append("")
    lines.append("Status: github_autonomy_cycle_completed")
    lines.append(f"Environment: {env_name}")
    lines.append(f"Redis: {report['redis']}")
    lines.append("")
    lines.append("## Modules")
    for k, v in report["modules"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Blocks")
    for k, v in report["blocks"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Queues")
    for k, v in report["queues"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Finance")
    for k, v in report["finance"].items():
        lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Recommendations")
    for x in report["recommendations"]:
        lines.append("- " + x)
    lines.append("")
    lines.append("## Safety")
    for k, v in report["security"].items():
        if k != "private_files_masked":
            lines.append(f"{k}: {v}")
    lines.append("")
    lines.append("## Double SHA")
    lines.append(report["double_sha"])

    (ROOT / "posts").mkdir(exist_ok=True)
    (ROOT / "posts/cybra_github_autonomy_report.md").write_text("\n".join(lines), encoding="utf-8")

    with (ROOT / "proofs/cybra_github_autonomy.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "feeds/cybra_github_autonomy_report.json",
            "posts/cybra_github_autonomy_report.md",
            "data/cybra_github_autonomy/reports/latest_report.json",
            "parliament/committees/github_autonomy_committee/committee.json"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    rpush(AUDIT_KEY, {
        "status": "github_autonomy_cycle_completed",
        "environment": env_name,
        "double_sha": report["double_sha"],
        "time": report["time"]
    })

    print("✅ CYBRA GitHub autonomy cycle completed")
    print("ENV:", env_name)
    print("REDIS:", report["redis"])
    print("MAIN_BLOCKS:", main_blocks)
    print("TASK_BLOCKS:", task_blocks)
    print("PARLIAMENT_FAILED:", report["queues"]["parliament_failed"])
    print("REPORT: posts/cybra_github_autonomy_report.md")
    print("PROOF: proofs/cybra_github_autonomy.sha256")
    print("DOUBLE_SHA:", report["double_sha"])

def status():
    report = load_json("feeds/cybra_github_autonomy_report.json", {})
    print("GITHUB_AUTONOMY_COMMITTEE: active")
    print("REPORT_EXISTS:", exists("posts/cybra_github_autonomy_report.md"))
    print("WORKFLOW_EXISTS:", exists(".github/workflows/cybra-autonomous-cycle.yml"))
    print("DEVCONTAINER_EXISTS:", exists(".devcontainer/devcontainer.json"))
    print("REDIS:", redis_ping())
    print("ENV:", report.get("environment", "none"))
    print("PARLIAMENT_FAILED:", rlen("cybra:parliament:failed"))
    print("AI_BLOCK_INBOX:", rlen(AI_BLOCK_INBOX))
    print("AUDIT:", rlen(AUDIT_KEY))

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "cycle":
        env_name = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("CYBRA_ENV", "local")
        cycle(env_name)
    elif cmd == "status":
        status()
    else:
        raise SystemExit("Usage: status|cycle ENV")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_github_autonomy.py

echo
echo "=== 5. CYCLE WRAPPER ==="

cat > github_autonomous_cycle.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e

if [ -n "$CYBRA_WORKDIR" ]; then
  cd "$CYBRA_WORKDIR" || exit 1
else
  cd "$HOME/CYBRA" || exit 1
fi

ENV_NAME="${1:-local}"

mkdir -p runtime/redis logs/github_autonomy posts feeds proofs data/cybra_github_autonomy

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$(pwd)/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

python3 cybra_github_autonomy.py cycle "$ENV_NAME"
EOF

chmod +x github_autonomous_cycle.sh

echo
echo "=== 6. HANDLER + PARLIAMENT MAPPING ==="

cat > cybra_github_autonomy_handler.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA"

bash github_autonomous_cycle.sh parliament-handler >/dev/null 2>&1 || true
EOF

chmod +x cybra_github_autonomy_handler.sh

redis-cli HSET cybra:executor:mapping github_autonomy_committee_task cybra_github_autonomy_handler.sh >/dev/null 2>&1 || true

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
if p.exists():
    s = p.read_text(encoding="utf-8")

    if 'r.hget("cybra:executor:mapping", task_type)' not in s:
        old = "script_name = SCRIPT_MAP.get(task_type)"
        new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
        if old in s:
            s = s.replace(old, new, 1)

    if '"github_autonomy_committee_task"' not in s:
        i = s.find("SCRIPT_MAP")
        j = s.find("{", i)
        if i >= 0 and j >= 0:
            s = s[:j+1] + '\n    "github_autonomy_committee_task": "cybra_github_autonomy_handler.sh",' + s[j+1:]

    p.write_text(s, encoding="utf-8")
    print("✅ parliament executor patched")
else:
    print("⚠ parliament_executor_v6.py not found")
PY

echo
echo "=== 7. PRIVACY / GITIGNORE ==="

cat >> .gitignore <<'EOF'

# CYBRA GitHub autonomy safety
runtime/
logs/
*.log
*.pid
dump.rdb
*.rdb
.env
*.key
*.pem
id_rsa
id_ed25519
*private*
*secret*
*token*
data/cybra_payment_requisites/private/
posts/private/
feeds/private/
proofs/private/
*.local.json
owner_identity*
payer_identity*
data/cybra_dashboard/dashboard_token.local
EOF

mkdir -p .git/info
cat >> .git/info/exclude <<'EOF'
data/cybra_payment_requisites/private/
posts/private/
feeds/private/
proofs/private/
*.local.json
owner_identity*
payer_identity*
data/cybra_dashboard/dashboard_token.local
dump.rdb
*.rdb
EOF

git rm --cached dump.rdb >/dev/null 2>&1 || true
git update-index --skip-worktree data/cybra_payment_requisites/payer_profile.json 2>/dev/null || true

REMOTE="$(git remote get-url origin 2>/dev/null)"
echo "$REMOTE" | grep -q "ghp_"
if [ "$?" -eq 0 ]; then
  git remote set-url origin https://github.com/Lubnysash1980/CYBRA.git
  echo "⚠ GitHub token removed from remote URL"
fi

echo
echo "=== 8. COMPILE + FIRST LOCAL CYCLE ==="

rm -rf __pycache__ bin/__pycache__
python3 -m py_compile cybra_github_autonomy.py
test -f parliament_executor_v6.py && python3 -m py_compile parliament_executor_v6.py || true
rm -rf __pycache__ bin/__pycache__

bash github_autonomous_cycle.sh local-termux

sha256sum -c proofs/cybra_github_autonomy.sha256 || true

echo
echo "=== 9. STATUS ==="
python3 cybra_github_autonomy.py status
cat posts/cybra_github_autonomy_report.md

echo
echo "✅ CYBRA GITHUB / CODESPACES AUTONOMY CREATED"
