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
