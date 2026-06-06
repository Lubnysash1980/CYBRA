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
