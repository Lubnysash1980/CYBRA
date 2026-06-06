#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA" || exit 1

mkdir -p \
  data/cybra_mgs/{committees,inbox,tasks,reports,codespace} \
  scripts posts feeds proofs logs/mgs runtime/redis .github/workflows .devcontainer

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

cat > cybra_mgs.py <<'PY'
#!/usr/bin/env python3
import json, time, uuid, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"
BASE = ROOT / "data/cybra_mgs"
INBOX = BASE / "inbox"
TASKS = BASE / "tasks"
REPORTS = BASE / "reports"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"

for p in [INBOX, TASKS, REPORTS, POSTS, FEEDS, PROOFS]:
    p.mkdir(parents=True, exist_ok=True)

COMMITTEES = [
    "mgs_analytics",
    "mgs_workers",
    "mgs_it_department",
    "mgs_restart_watchdog",
    "mgs_integration"
]

QUEUES = {
    "ai": "ai_block_inbox",
    "parliament": "parliament_inbox",
    "it": "it_department",
    "codespace": "cybra_codespace_inbox",
    "mgs": "cybra_mgs_all"
}

SAFETY = {
    "real_trading_now": False,
    "live_force_trading_disabled": True,
    "automatic_external_tx": False,
    "manual_OWNER_approval_required": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def sh(cmd):
    return subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)

def redis_push(queue, payload):
    raw = json.dumps(payload, ensure_ascii=False)
    sh(f"redis-cli LPUSH {queue} {json.dumps(raw)} >/dev/null 2>&1 || true")

def task(target, title, body):
    task_id = f"MGS-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    routes = list(QUEUES.keys()) if target == "all" else [target]
    payload = {
        "task_id": task_id,
        "timestamp": now(),
        "title": title,
        "body": body,
        "target": target,
        "routes": routes,
        "committees": COMMITTEES,
        "status": "QUEUED",
        "safety": SAFETY
    }

    (INBOX / f"{task_id}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (TASKS / f"{task_id}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    for c in COMMITTEES:
        d = BASE / "committees" / c
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{task_id}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    for r in routes:
        if r in QUEUES:
            redis_push(QUEUES[r], payload)

    print(json.dumps(payload, ensure_ascii=False, indent=2))

def status():
    qs = {}
    for k, q in QUEUES.items():
        r = sh(f"redis-cli LLEN {q} 2>/dev/null || echo 0")
        v = r.stdout.strip()
        qs[q] = int(v) if v.isdigit() else 0

    data = {
        "timestamp": now(),
        "status": "OK",
        "ecosystem": "MGS_SCRIPT_ECOSYSTEM",
        "committees_count": 5,
        "committees": COMMITTEES,
        "queues": qs,
        "local_tasks": len(list(INBOX.glob("*.json"))),
        "codespace_tasks": len(list(TASKS.glob("*.json"))),
        "safety": SAFETY
    }

    j = REPORTS / "latest_status.json"
    f = FEEDS / "cybra_mgs_status.json"
    m = POSTS / "cybra_mgs_status.md"
    p = PROOFS / "cybra_mgs_status.sha256"

    j.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    f.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    m.write_text(
        "# CYBRA MGS Status\n\n"
        f"Timestamp: {data['timestamp']}\n\n"
        "Status: **OK**\n\n"
        "## Committees\n"
        "1. MGS Analytics\n"
        "2. MGS Workers\n"
        "3. MGS IT Department\n"
        "4. MGS Restart Watchdog\n"
        "5. MGS Integration\n\n"
        "## Safety\n"
        "real_trading_now: false\n"
        "live_force_trading_disabled: true\n"
        "automatic_external_tx: false\n"
        "manual_OWNER_approval_required: true\n",
        encoding="utf-8"
    )

    p.write_text(
        f"{hashlib.sha256(j.read_bytes()).hexdigest()}  data/cybra_mgs/reports/latest_status.json\n"
        f"{hashlib.sha256(m.read_bytes()).hexdigest()}  posts/cybra_mgs_status.md\n",
        encoding="utf-8"
    )

    print(json.dumps(data, ensure_ascii=False, indent=2))

def prepare_codespace():
    worker = ROOT / "scripts/cybra_codespace_mgs_worker.py"
    worker.write_text("""#!/usr/bin/env python3
import json, time
from pathlib import Path

ROOT = Path.cwd()
TASKS = ROOT / "data/cybra_mgs/tasks"
REPORTS = ROOT / "data/cybra_mgs/codespace"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"

for p in [TASKS, REPORTS, POSTS, FEEDS, PROOFS]:
    p.mkdir(parents=True, exist_ok=True)

processed = []
for f in sorted(TASKS.glob("*.json")):
    try:
        data = json.loads(f.read_text(encoding="utf-8"))
    except Exception:
        continue
    data["codespace_status"] = "ACCEPTED"
    data["codespace_timestamp"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    out = REPORTS / (f.stem + "_result.json")
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    processed.append(data.get("task_id", f.stem))

latest = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "status": "OK",
    "processed_count": len(processed),
    "processed": processed[-20:],
    "real_trading_now": False,
    "automatic_external_tx": False
}

(REPORTS / "latest_codespace_mgs_report.json").write_text(json.dumps(latest, ensure_ascii=False, indent=2), encoding="utf-8")
(FEEDS / "cybra_mgs_codespace_report.json").write_text(json.dumps(latest, ensure_ascii=False, indent=2), encoding="utf-8")
(POSTS / "cybra_mgs_codespace_report.md").write_text("# CYBRA MGS Codespace Report\\n\\nProcessed: " + str(len(processed)) + "\\n", encoding="utf-8")
print(json.dumps(latest, ensure_ascii=False, indent=2))
""", encoding="utf-8")
    worker.chmod(0o755)

    wf = ROOT / ".github/workflows/cybra-mgs-codespace-worker.yml"
    wf.write_text("""name: CYBRA MGS Worker

on:
  workflow_dispatch:
  push:
    paths:
      - 'data/cybra_mgs/tasks/**'
      - 'scripts/cybra_codespace_mgs_worker.py'

permissions:
  contents: write

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: python3 scripts/cybra_codespace_mgs_worker.py
      - run: |
          git config user.name "cybra-mgs-bot"
          git config user.email "cybra-mgs-bot@users.noreply.github.com"
          git add data/cybra_mgs/codespace posts/cybra_mgs_codespace_report.md feeds/cybra_mgs_codespace_report.json || true
          git commit -m "update MGS codespace report" || true
          git push || true
""", encoding="utf-8")

    print("✅ Codespace worker prepared")

def clip(title):
    r = sh("termux-clipboard-get 2>/dev/null || true")
    body = r.stdout.strip()
    if not body:
        print("❌ Clipboard empty або нема termux-api")
        return
    task("all", title, body)

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        status()
    elif cmd == "task":
        target = sys.argv[2] if len(sys.argv) > 2 else "all"
        title = sys.argv[3] if len(sys.argv) > 3 else "MGS task"
        body = " ".join(sys.argv[4:]) if len(sys.argv) > 4 else title
        task(target, title, body)
    elif cmd == "clip":
        title = sys.argv[2] if len(sys.argv) > 2 else "Clipboard task"
        clip(title)
    elif cmd == "prepare-codespace":
        prepare_codespace()
    else:
        print("Commands: status | task all 'title' 'body' | clip 'title' | prepare-codespace")
PY

chmod +x cybra_mgs.py

cat > cybra-mgs <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 cybra_mgs.py "$@"
EOF

chmod +x cybra-mgs
ln -sf "$HOME/CYBRA/cybra-mgs" "$PREFIX/bin/cybra-mgs"

cybra-mgs prepare-codespace
cybra-mgs status

sha256sum cybra_mgs.py cybra-mgs scripts/cybra_codespace_mgs_worker.py > proofs/cybra_mgs_quick_install.sha256

echo "✅ MGS QUICK INSTALL DONE"
echo "use: cybra-mgs status"
echo "use: cybra-mgs task all 'Upgrade v64' 'Переписать модуль 64 безопасно'"
echo "use: cybra-mgs clip 'Script from clipboard'"
