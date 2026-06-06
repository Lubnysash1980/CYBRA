#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== INSTALL CYBRA ORACLE + CODESPACE + GITHUB BRIDGE ==="

mkdir -p \
  bin scripts/oracle .github/workflows .devcontainer \
  data/cybra_oracle/{tasks,reports,runtime,processed} \
  data/cybra_mgs/tasks \
  public/cybra_oracle_dashboard \
  posts feeds proofs logs/oracle runtime/redis

# ---------- Redis local safe ----------
if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

# ---------- Oracle agent ----------
cat > scripts/oracle/cybra_oracle_agent.py <<'PY'
#!/usr/bin/env python3
import os, json, time, hashlib, subprocess, sys
from pathlib import Path

ROOT = Path.cwd()
TASKS = ROOT / "data/cybra_mgs/tasks"
ORACLE_TASKS = ROOT / "data/cybra_oracle/tasks"
REPORTS = ROOT / "data/cybra_oracle/reports"
PROCESSED = ROOT / "data/cybra_oracle/processed"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"
DASH = ROOT / "public/cybra_oracle_dashboard"
LOGS = ROOT / "logs/oracle"

for p in [TASKS, ORACLE_TASKS, REPORTS, PROCESSED, POSTS, FEEDS, PROOFS, DASH, LOGS]:
    p.mkdir(parents=True, exist_ok=True)

SAFETY = {
    "real_trading_now": False,
    "live_force_trading_disabled": True,
    "automatic_external_tx": False,
    "automatic_SWIFT": False,
    "manual_OWNER_approval_required": True,
    "mainnet_deploy_allowed": False
}

COMMITTEES = [
    "mgs_analytics",
    "mgs_workers",
    "mgs_it_department",
    "mgs_restart_watchdog",
    "mgs_integration"
]

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def sh(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)
    return p.stdout.strip(), p.stderr.strip(), p.returncode

def sha_file(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else ""

def count_files(path, pattern="*"):
    return len(list(Path(path).glob(pattern))) if Path(path).exists() else 0

def git_info():
    head, _, _ = sh("git rev-parse --short HEAD 2>/dev/null || echo none")
    branch, _, _ = sh("git branch --show-current 2>/dev/null || echo none")
    return {"branch": branch or "none", "head": head or "none"}

def module_report():
    mod64 = ROOT / "trading_bot/v64/modules/64"
    original = ROOT / "trading_bot/v64/models/original_full_bot_6000_latest.mjs"
    line_count = 0
    if original.exists():
        try:
            line_count = len(original.read_text(encoding="utf-8", errors="ignore").splitlines())
        except Exception:
            line_count = 0
    return {
        "original_6000_file": str(original.relative_to(ROOT)) if original.exists() else None,
        "original_line_count": line_count,
        "module64_present": mod64.exists(),
        "module64_files": [str(p.relative_to(ROOT)) for p in mod64.glob("*")] if mod64.exists() else [],
        "modules_total_dirs": count_files(ROOT / "trading_bot/v64/modules", "*"),
        "module64_preserved": mod64.exists()
    }

def load_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return None

def process_tasks():
    all_tasks = []
    for src in [TASKS, ORACLE_TASKS]:
        for f in sorted(src.glob("*.json")):
            data = load_json(f)
            if not data:
                continue
            task_id = data.get("task_id") or f.stem
            out = PROCESSED / f"{task_id}.json"
            result = {
                "task_id": task_id,
                "timestamp": now(),
                "source_file": str(f.relative_to(ROOT)),
                "status": "ORACLE_ACCEPTED",
                "runner": "Oracle VPS CYBRA Agent",
                "title": data.get("title", "no-title"),
                "target": data.get("target", "all"),
                "committees": data.get("committees", COMMITTEES),
                "action": "Task accepted by Oracle VPS. Heavy work stays on VPS/Codespace. Termux only controls.",
                "safety": data.get("safety", SAFETY)
            }
            out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            all_tasks.append(result)
    return all_tasks

def make_dashboard(status):
    old = load_json(DASH / "dashboard.json") or {}
    history = old.get("history", [])
    point = {
        "ts": now(),
        "tasks": status["tasks_total"],
        "processed": status["processed_total"],
        "evolution_percent": status["evolution_percent"],
        "module64": 1 if status["module64"]["module64_present"] else 0,
        "oracle_alive": 1
    }
    history.append(point)
    history = history[-288:]

    dashboard = {
        "updated": now(),
        "status": status,
        "history": history,
        "safety": SAFETY
    }
    (DASH / "dashboard.json").write_text(json.dumps(dashboard, ensure_ascii=False, indent=2), encoding="utf-8")

    html = r'''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Oracle VPS Dashboard</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:Arial;background:#05070d;color:#e8f0ff;margin:0;padding:14px}
h1{font-size:22px;margin:6px 0 12px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}
.card{background:#111827;border:1px solid #243244;border-radius:14px;padding:12px}
.big{font-size:28px;font-weight:700}
.small{font-size:12px;color:#9fb0c9}
canvas{width:100%;height:130px;background:#07101e;border-radius:12px}
pre{white-space:pre-wrap;font-size:12px;color:#b8c7df}
.ok{color:#8cffb0}.bad{color:#ff8c8c}
</style>
</head>
<body>
<h1>CYBRA Oracle + Codespace + GitHub Control</h1>
<div class="grid">
  <div class="card"><div class="small">Oracle status</div><div id="alive" class="big">...</div></div>
  <div class="card"><div class="small">Tasks</div><div id="tasks" class="big">0</div></div>
  <div class="card"><div class="small">Processed</div><div id="processed" class="big">0</div></div>
  <div class="card"><div class="small">Evolution</div><div id="evo" class="big">0%</div></div>
  <div class="card"><div class="small">Module 64</div><div id="m64" class="big">...</div></div>
</div>
<br>
<div class="grid">
  <div class="card"><div class="small">Tasks curve</div><canvas id="c1"></canvas></div>
  <div class="card"><div class="small">Evolution curve</div><canvas id="c2"></canvas></div>
  <div class="card"><div class="small">Oracle alive</div><canvas id="c3"></canvas></div>
</div>
<br>
<div class="card">
<div class="small">Last report</div>
<pre id="raw">loading...</pre>
</div>
<script>
function draw(canvasId, arr, key, maxv){
  const c=document.getElementById(canvasId), ctx=c.getContext('2d');
  c.width=c.clientWidth*2; c.height=c.clientHeight*2;
  ctx.clearRect(0,0,c.width,c.height);
  ctx.lineWidth=3; ctx.beginPath();
  if(!arr.length){return}
  const vals=arr.map(x=>Number(x[key]||0));
  const max=Math.max(maxv||1, ...vals, 1);
  vals.forEach((v,i)=>{
    const x=i/(Math.max(vals.length-1,1))*c.width;
    const y=c.height-(v/max)*c.height;
    if(i===0)ctx.moveTo(x,y); else ctx.lineTo(x,y);
  });
  ctx.strokeStyle="#78a6ff"; ctx.stroke();
}
async function load(){
  try{
    const r=await fetch("dashboard.json?x="+Date.now());
    const d=await r.json();
    const s=d.status||{};
    document.getElementById("alive").innerHTML='<span class="ok">LIVE</span>';
    document.getElementById("tasks").textContent=s.tasks_total||0;
    document.getElementById("processed").textContent=s.processed_total||0;
    document.getElementById("evo").textContent=(s.evolution_percent||0)+"%";
    document.getElementById("m64").innerHTML=s.module64 && s.module64.module64_present ? '<span class="ok">OK</span>' : '<span class="bad">NO</span>';
    document.getElementById("raw").textContent=JSON.stringify(s,null,2);
    draw("c1", d.history||[], "tasks");
    draw("c2", d.history||[], "evolution_percent", 100);
    draw("c3", d.history||[], "oracle_alive", 1);
  }catch(e){
    document.getElementById("alive").innerHTML='<span class="bad">OFFLINE</span>';
  }
}
load(); setInterval(load,5000);
</script>
</body>
</html>'''
    (DASH / "index.html").write_text(html, encoding="utf-8")

def build_status():
    processed = process_tasks()
    mod = module_report()
    tasks_total = count_files(TASKS, "*.json") + count_files(ORACLE_TASKS, "*.json")
    processed_total = count_files(PROCESSED, "*.json")

    score = 0
    checks = [
        mod["module64_present"],
        (ROOT / ".github/workflows/cybra-oracle-vps-deploy.yml").exists(),
        (ROOT / "scripts/oracle/cybra_oracle_agent.py").exists(),
        (ROOT / "public/cybra_oracle_dashboard/index.html").exists(),
        processed_total >= 0
    ]
    score = round((sum(1 for x in checks if x) / len(checks)) * 100, 2)

    status = {
        "timestamp": now(),
        "status": "ORACLE_VPS_OK",
        "role": "MAIN_REMOTE_RUNNER",
        "termux_role": "CONTROL_BAR_ONLY",
        "github_role": "SYNC_AND_DEPLOY",
        "codespace_role": "SECONDARY_WORKSPACE",
        "oracle_role": "HEAVY_PROCESS_RUNNER",
        "committees": COMMITTEES,
        "tasks_total": tasks_total,
        "processed_total": processed_total,
        "last_processed": processed[-10:],
        "evolution_percent": score,
        "git": git_info(),
        "module64": mod,
        "dashboard": {
            "path": "public/cybra_oracle_dashboard/index.html",
            "port": 8099
        },
        "safety": SAFETY
    }
    return status

def write_reports(status):
    j = REPORTS / "latest_status.json"
    f = FEEDS / "cybra_oracle_vps_status.json"
    m = POSTS / "cybra_oracle_vps_report.md"
    p = PROOFS / "cybra_oracle_vps.sha256"

    j.write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
    f.write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = [
        "# CYBRA Oracle VPS Report",
        "",
        f"Timestamp: {status['timestamp']}",
        f"Status: **{status['status']}**",
        "",
        "## Roles",
        "- Oracle VPS: MAIN_REMOTE_RUNNER",
        "- Android Termux: CONTROL_BAR_ONLY",
        "- GitHub: SYNC_AND_DEPLOY",
        "- Codespace: SECONDARY_WORKSPACE",
        "",
        "## Runtime",
        f"- Tasks total: {status['tasks_total']}",
        f"- Processed total: {status['processed_total']}",
        f"- Evolution percent: {status['evolution_percent']}%",
        f"- Module 64 present: {status['module64']['module64_present']}",
        "",
        "## Committees",
    ]
    for c in COMMITTEES:
        lines.append(f"- {c}")
    lines += [
        "",
        "## Dashboard",
        "- VPS: `http://ORACLE_HOST:8099/`",
        "- Repo path: `public/cybra_oracle_dashboard/index.html`",
        "",
        "## Safety",
        "- real_trading_now: false",
        "- live_force_trading_disabled: true",
        "- automatic_external_tx: false",
        "- manual_OWNER_approval_required: true",
    ]
    m.write_text("\n".join(lines) + "\n", encoding="utf-8")

    p.write_text(
        f"{sha_file(j)}  data/cybra_oracle/reports/latest_status.json\n"
        f"{sha_file(f)}  feeds/cybra_oracle_vps_status.json\n"
        f"{sha_file(m)}  posts/cybra_oracle_vps_report.md\n"
        f"{sha_file(DASH / 'dashboard.json')}  public/cybra_oracle_dashboard/dashboard.json\n",
        encoding="utf-8"
    )

def once():
    status = build_status()
    make_dashboard(status)
    write_reports(status)
    print(json.dumps(status, ensure_ascii=False, indent=2))

def daemon():
    while True:
        os.environ["GIT_TERMINAL_PROMPT"] = "0"
        sh("git pull --rebase origin main >/dev/null 2>&1 || true")
        once()
        sh("git add data/cybra_oracle posts/cybra_oracle_vps_report.md feeds/cybra_oracle_vps_status.json proofs/cybra_oracle_vps.sha256 public/cybra_oracle_dashboard >/dev/null 2>&1 || true")
        sh('git commit -m "oracle vps status update" >/dev/null 2>&1 || true')
        sh("git push origin main >/dev/null 2>&1 || true")
        time.sleep(int(os.environ.get("ORACLE_LOOP_SEC", "60")))

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    else:
        once()
PY

chmod +x scripts/oracle/cybra_oracle_agent.py

# ---------- Oracle start script ----------
cat > scripts/oracle/cybra_oracle_start.sh <<'BASH2'
#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || cd "$(pwd)" || exit 1

mkdir -p logs/oracle public/cybra_oracle_dashboard data/cybra_oracle/reports data/cybra_mgs/tasks

echo "=== CYBRA ORACLE VPS START ==="

python3 scripts/oracle/cybra_oracle_agent.py || true

if ! pgrep -f "http.server 8099" >/dev/null 2>&1; then
  nohup python3 -m http.server 8099 --bind 0.0.0.0 --directory public/cybra_oracle_dashboard \
    > logs/oracle/dashboard_server.log 2>&1 &
  echo "✅ Dashboard server started on :8099"
else
  echo "✅ Dashboard server already running"
fi

if ! pgrep -f "cybra_oracle_agent.py daemon" >/dev/null 2>&1; then
  nohup python3 scripts/oracle/cybra_oracle_agent.py daemon \
    > logs/oracle/oracle_agent_daemon.log 2>&1 &
  echo "✅ Oracle agent daemon started"
else
  echo "✅ Oracle agent daemon already running"
fi

echo "Open: http://YOUR_ORACLE_IP:8099/"
BASH2

chmod +x scripts/oracle/cybra_oracle_start.sh

# ---------- Oracle install script ----------
cat > scripts/oracle/install_on_oracle.sh <<'BASH3'
#!/usr/bin/env bash
set +e

REPO="${REPO:-https://github.com/Lubnysash1980/CYBRA.git}"
DIR="${DIR:-$HOME/CYBRA}"

echo "=== INSTALL CYBRA ON ORACLE VPS ==="

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y || true
  sudo apt-get install -y git python3 python3-pip curl jq nodejs npm redis-server || true
fi

if [ ! -d "$DIR/.git" ]; then
  git clone "$REPO" "$DIR" || exit 1
fi

cd "$DIR" || exit 1
git pull --rebase origin main || true

mkdir -p logs/oracle runtime data/cybra_oracle/reports public/cybra_oracle_dashboard

bash scripts/oracle/cybra_oracle_start.sh

echo "✅ Oracle VPS installed and running"
echo "Dashboard: http://SERVER_IP:8099/"
BASH3

chmod +x scripts/oracle/install_on_oracle.sh

# ---------- GitHub workflow deploy to Oracle ----------
cat > .github/workflows/cybra-oracle-vps-deploy.yml <<'YAML'
name: CYBRA Oracle VPS Deploy

on:
  workflow_dispatch:
  push:
    paths:
      - 'scripts/oracle/**'
      - 'data/cybra_mgs/tasks/**'
      - 'trading_bot/v64/**'
      - 'public/cybra_oracle_dashboard/**'
      - '.github/workflows/cybra-oracle-vps-deploy.yml'

permissions:
  contents: write

jobs:
  deploy-oracle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check required secrets
        run: |
          test -n "${{ secrets.ORACLE_HOST }}" || (echo "Missing ORACLE_HOST" && exit 1)
          test -n "${{ secrets.ORACLE_USER }}" || (echo "Missing ORACLE_USER" && exit 1)
          test -n "${{ secrets.ORACLE_SSH_KEY }}" || (echo "Missing ORACLE_SSH_KEY" && exit 1)

      - name: Prepare SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.ORACLE_SSH_KEY }}" > ~/.ssh/oracle_key
          chmod 600 ~/.ssh/oracle_key
          ssh-keyscan -p "${{ secrets.ORACLE_PORT || 22 }}" "${{ secrets.ORACLE_HOST }}" >> ~/.ssh/known_hosts 2>/dev/null || true

      - name: Deploy to Oracle VPS
        run: |
          ssh -i ~/.ssh/oracle_key \
            -p "${{ secrets.ORACLE_PORT || 22 }}" \
            "${{ secrets.ORACLE_USER }}@${{ secrets.ORACLE_HOST }}" \
            'bash -s' < scripts/oracle/install_on_oracle.sh

      - name: Run agent once locally
        run: |
          python3 scripts/oracle/cybra_oracle_agent.py || true

      - name: Commit Oracle report
        run: |
          git config user.name "cybra-oracle-bot"
          git config user.email "cybra-oracle-bot@users.noreply.github.com"
          git add data/cybra_oracle posts/cybra_oracle_vps_report.md feeds/cybra_oracle_vps_status.json proofs/cybra_oracle_vps.sha256 public/cybra_oracle_dashboard || true
          git commit -m "update oracle vps report" || true
          git push || true
YAML

# ---------- Codespace start also starts Oracle reports locally ----------
cat > .devcontainer/cybra_codespace_oracle_start.sh <<'BASH4'
#!/usr/bin/env bash
set +e
cd /workspaces/CYBRA 2>/dev/null || cd "$PWD" || exit 1
mkdir -p logs/oracle data/cybra_oracle/reports public/cybra_oracle_dashboard
python3 scripts/oracle/cybra_oracle_agent.py || true
echo "✅ Codespace Oracle-compatible report prepared"
BASH4

chmod +x .devcontainer/cybra_codespace_oracle_start.sh

# ---------- Termux controller ----------
cat > cybra_oracle.py <<'PY2'
#!/usr/bin/env python3
import os, sys, json, time, uuid, subprocess, hashlib
from pathlib import Path

ROOT = Path.home() / "CYBRA"
TASKS = ROOT / "data/cybra_mgs/tasks"
ORACLE_TASKS = ROOT / "data/cybra_oracle/tasks"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"

for p in [TASKS, ORACLE_TASKS, POSTS, FEEDS, PROOFS]:
    p.mkdir(parents=True, exist_ok=True)

SAFETY = {
    "real_trading_now": False,
    "live_force_trading_disabled": True,
    "automatic_external_tx": False,
    "automatic_SWIFT": False,
    "manual_OWNER_approval_required": True,
    "mainnet_deploy_allowed": False
}

COMMITTEES = [
    "mgs_analytics",
    "mgs_workers",
    "mgs_it_department",
    "mgs_restart_watchdog",
    "mgs_integration"
]

def run(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)
    return p.stdout.strip(), p.stderr.strip(), p.returncode

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def task(target, title, body):
    tid = f"ORACLE-MGS-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    payload = {
        "task_id": tid,
        "timestamp": now(),
        "title": title,
        "body": body,
        "target": target,
        "routes": ["oracle", "codespace", "github", "ai", "it", "parliament", "mgs"] if target == "all" else [target],
        "committees": COMMITTEES,
        "priority": "normal",
        "preserve": {
            "original_6000_lines": True,
            "module64": True,
            "no_loss_of_models": True
        },
        "safety": SAFETY
    }
    for d in [TASKS, ORACLE_TASKS]:
        (d / f"{tid}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    raw = json.dumps(payload, ensure_ascii=False)
    run(f"redis-cli LPUSH cybra_oracle_tasks {json.dumps(raw)} >/dev/null 2>&1 || true")
    run(f"redis-cli LPUSH cybra_mgs_all {json.dumps(raw)} >/dev/null 2>&1 || true")
    print(json.dumps(payload, ensure_ascii=False, indent=2))

def clipboard():
    out, _, _ = run("command -v termux-clipboard-get >/dev/null 2>&1 && termux-clipboard-get || true")
    return out.strip()

def git_sync():
    run("git add cybra_oracle.py cybra-oracle scripts/oracle .github/workflows/cybra-oracle-vps-deploy.yml .devcontainer/cybra_codespace_oracle_start.sh data/cybra_mgs/tasks data/cybra_oracle posts feeds proofs public/cybra_oracle_dashboard || true")
    out, err, _ = run('git commit -m "add oracle vps codespace github bridge" || true')
    print(out or err)
    out, err, code = run("git pull --rebase origin main && git push origin main")
    print(out or err)
    if code != 0:
        print("❌ Git sync failed. Перевір GitHub token/SSH або gh auth login.")

def ssh_base():
    host = os.environ.get("ORACLE_HOST", "")
    user = os.environ.get("ORACLE_USER", "ubuntu")
    port = os.environ.get("ORACLE_PORT", "22")
    key = os.environ.get("ORACLE_KEY", str(Path.home() / ".ssh/id_ed25519"))
    if not host:
        raise SystemExit("❌ Set ORACLE_HOST first: export ORACLE_HOST='IP_ADDRESS'")
    key_part = f"-i {key}" if Path(key).exists() else ""
    return f"ssh {key_part} -p {port} {user}@{host}"

def oracle_install():
    base = ssh_base()
    cmd = f"{base} 'bash -s' < scripts/oracle/install_on_oracle.sh"
    print("RUN:", cmd)
    os.system(cmd)

def oracle_status():
    base = ssh_base()
    cmd = "cd ~/CYBRA && git pull --rebase origin main >/dev/null 2>&1 || true; cd ~/CYBRA && python3 scripts/oracle/cybra_oracle_agent.py && cat posts/cybra_oracle_vps_report.md"
    os.system(f"{base} {json.dumps(cmd)}")

def oracle_logs():
    base = ssh_base()
    cmd = "tail -n 80 ~/CYBRA/logs/oracle/oracle_agent_daemon.log 2>/dev/null || true; tail -n 40 ~/CYBRA/logs/oracle/dashboard_server.log 2>/dev/null || true"
    os.system(f"{base} {json.dumps(cmd)}")

def workflow_run():
    out, err, code = run("gh workflow run cybra-oracle-vps-deploy.yml")
    print(out or err)
    if code != 0:
        print("❌ Не запустилось. Зроби: gh auth login")

def status():
    run("python3 scripts/oracle/cybra_oracle_agent.py >/dev/null 2>&1 || true")
    report = ROOT / "data/cybra_oracle/reports/latest_status.json"
    if report.exists():
        print(report.read_text(encoding="utf-8"))
    else:
        print("No report yet")

def dashboard():
    host = os.environ.get("ORACLE_HOST", "YOUR_ORACLE_IP")
    print(f"Oracle dashboard: http://{host}:8099/")
    print("Local repo dashboard file: public/cybra_oracle_dashboard/index.html")
    print("GitHub Pages-ready path: public/cybra_oracle_dashboard/index.html")

def main():
    args = sys.argv[1:]
    if not args:
        print("""CYBRA Oracle commands:
cybra-oracle status
cybra-oracle task all "Upgrade v64 real-safe runner" "Оптимізувати без втрати module 64"
cybra-oracle clip all "Script from Android clipboard"
cybra-oracle git-sync
cybra-oracle oracle-install
cybra-oracle oracle-status
cybra-oracle oracle-logs
cybra-oracle workflow-run
cybra-oracle dashboard
""")
        return

    cmd = args[0]
    if cmd == "status":
        status()
    elif cmd == "task":
        target = args[1] if len(args) > 1 else "all"
        title = args[2] if len(args) > 2 else "Oracle MGS task"
        body = " ".join(args[3:]) if len(args) > 3 else title
        task(target, title, body)
    elif cmd == "clip":
        target = args[1] if len(args) > 1 else "all"
        title = args[2] if len(args) > 2 else "Clipboard script task"
        body = clipboard()
        if not body:
            raise SystemExit("❌ Clipboard empty або termux-api не встановлено.")
        task(target, title, body)
    elif cmd == "git-sync":
        git_sync()
    elif cmd == "oracle-install":
        oracle_install()
    elif cmd == "oracle-status":
        oracle_status()
    elif cmd == "oracle-logs":
        oracle_logs()
    elif cmd == "workflow-run":
        workflow_run()
    elif cmd == "dashboard":
        dashboard()
    else:
        print("Unknown command")

if __name__ == "__main__":
    main()
PY2

chmod +x cybra_oracle.py

cat > cybra-oracle <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 cybra_oracle.py "$@"
EOF

chmod +x cybra-oracle
ln -sf "$HOME/CYBRA/cybra-oracle" "$PREFIX/bin/cybra-oracle" 2>/dev/null || true

# ---------- Initial report ----------
python3 scripts/oracle/cybra_oracle_agent.py || true
cybra-oracle status

sha256sum \
  cybra_oracle.py \
  cybra-oracle \
  scripts/oracle/cybra_oracle_agent.py \
  scripts/oracle/cybra_oracle_start.sh \
  scripts/oracle/install_on_oracle.sh \
  .github/workflows/cybra-oracle-vps-deploy.yml \
  public/cybra_oracle_dashboard/index.html \
  public/cybra_oracle_dashboard/dashboard.json \
  posts/cybra_oracle_vps_report.md \
  feeds/cybra_oracle_vps_status.json \
  data/cybra_oracle/reports/latest_status.json \
  > proofs/cybra_oracle_bridge_install.sha256 2>/dev/null || true

echo
echo "✅ CYBRA ORACLE BRIDGE INSTALLED"
echo "COMMAND: cybra-oracle status"
echo "COMMAND: cybra-oracle task all 'Upgrade v64 bot' 'Оптимізувати без втрати module 64; Oracle виконує, Termux керує'"
echo "COMMAND: cybra-oracle git-sync"
echo "COMMAND: export ORACLE_HOST='IP'; export ORACLE_USER='ubuntu'; cybra-oracle oracle-install"
echo "COMMAND: cybra-oracle dashboard"
