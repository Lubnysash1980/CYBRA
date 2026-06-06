#!/usr/bin/env python3
import os, sys, json, time, uuid, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"
TASKS = ROOT / "data/cybra_mgs/tasks"
OTASKS = ROOT / "data/cybra_oracle/tasks"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"

for p in [TASKS, OTASKS, POSTS, FEEDS, PROOFS]:
    p.mkdir(parents=True, exist_ok=True)

COMMITTEES = [
    "MGS Analytics",
    "MGS Workers",
    "MGS IT Department",
    "MGS Restart Watchdog",
    "MGS Integration"
]

SAFETY = {
    "real_trading_now": False,
    "live_force_trading_disabled": True,
    "automatic_external_tx": False,
    "automatic_SWIFT": False,
    "mainnet_deploy_allowed": False,
    "manual_OWNER_approval_required": True
}

def sh(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, text=True)
    return p.returncode

def out(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)
    return (p.stdout or p.stderr or "").strip(), p.returncode

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def pause():
    input("\nENTER...")

def make_task(title, body, target="all"):
    tid = f"BAR-MGS-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    payload = {
        "task_id": tid,
        "timestamp": now(),
        "title": title,
        "body": body,
        "target": target,
        "routes": ["oracle", "codespace", "github", "ai", "it", "parliament", "mgs"],
        "committees": COMMITTEES,
        "preserve": {
            "original_6000_lines": True,
            "module64": True,
            "do_not_break_existing_system": True,
            "evolutionary_upgrade_only": True
        },
        "safety": SAFETY
    }

    for d in [TASKS, OTASKS]:
        (d / f"{tid}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    raw = json.dumps(payload, ensure_ascii=False)
    safe = json.dumps(raw)
    sh(f"redis-cli LPUSH cybra_mgs_all {safe} >/dev/null 2>&1 || true")
    sh(f"redis-cli LPUSH cybra_oracle_tasks {safe} >/dev/null 2>&1 || true")
    sh(f"redis-cli LPUSH ai_block_inbox {safe} >/dev/null 2>&1 || true")
    sh(f"redis-cli LPUSH parliament_inbox {safe} >/dev/null 2>&1 || true")
    sh(f"redis-cli LPUSH it_department {safe} >/dev/null 2>&1 || true")

    print(json.dumps(payload, ensure_ascii=False, indent=2))

def clipboard_task():
    text, _ = out("command -v termux-clipboard-get >/dev/null 2>&1 && termux-clipboard-get || true")
    if not text:
        print("❌ Буфер порожній або termux-api не встановлено.")
        return
    title = input("Назва задачі з буфера: ").strip() or "Android clipboard script"
    make_task(title, text, "all")

def status():
    print("\n=== CYBRA CONTROL BAR STATUS ===\n")
    for q in ["cybra_mgs_all", "cybra_oracle_tasks", "ai_block_inbox", "parliament_inbox", "it_department"]:
        r, _ = out(f"redis-cli LLEN {q} 2>/dev/null || echo 0")
        print(f"{q}: {r}")

    print("\n--- Git ---")
    sh("git status --short")
    print("\n--- Oracle local report ---")
    if (ROOT / "posts/cybra_oracle_vps_report.md").exists():
        sh("tail -n 40 posts/cybra_oracle_vps_report.md")
    else:
        print("No oracle report yet")

    print("\n--- Module 64 ---")
    sh("ls -la trading_bot/v64/modules/64 2>/dev/null || true")

def git_sync():
    print("=== Git sync ===")
    sh("git add cybra_bar.py cybra-bar scripts patches data/cybra_mgs/tasks data/cybra_oracle/tasks posts feeds proofs public/cybra_oracle_dashboard .github/workflows .devcontainer dist || true")
    sh('git commit -m "add signed 3-patch control bar and mihailka launcher" || true')
    sh("git pull --rebase origin main")
    sh("git push origin main")

def oracle_install():
    host = os.environ.get("ORACLE_HOST", "")
    user = os.environ.get("ORACLE_USER", "ubuntu")
    port = os.environ.get("ORACLE_PORT", "22")
    key = os.environ.get("ORACLE_KEY", str(Path.home() / ".ssh/id_ed25519"))

    if not host:
        host = input("Oracle IP: ").strip()
    if not host:
        print("❌ Нема ORACLE_HOST")
        return

    keypart = f"-i {key}" if Path(key).exists() else ""
    cmd = f"ssh {keypart} -p {port} {user}@{host} 'bash -s' < scripts/oracle/install_on_oracle.sh"
    print(cmd)
    os.system(cmd)

def oracle_patch():
    host = os.environ.get("ORACLE_HOST", "")
    user = os.environ.get("ORACLE_USER", "ubuntu")
    port = os.environ.get("ORACLE_PORT", "22")
    key = os.environ.get("ORACLE_KEY", str(Path.home() / ".ssh/id_ed25519"))

    if not host:
        host = input("Oracle IP: ").strip()
    if not host:
        print("❌ Нема ORACLE_HOST")
        return

    keypart = f"-i {key}" if Path(key).exists() else ""
    cmd = "cd ~/CYBRA && git pull --rebase origin main || true; cd ~/CYBRA && bash scripts/oracle/cybra_oracle_patch_runner.sh"
    os.system(f"ssh {keypart} -p {port} {user}@{host} {json.dumps(cmd)}")

def oracle_logs():
    host = os.environ.get("ORACLE_HOST", "")
    user = os.environ.get("ORACLE_USER", "ubuntu")
    port = os.environ.get("ORACLE_PORT", "22")
    key = os.environ.get("ORACLE_KEY", str(Path.home() / ".ssh/id_ed25519"))

    if not host:
        host = input("Oracle IP: ").strip()
    if not host:
        print("❌ Нема ORACLE_HOST")
        return

    keypart = f"-i {key}" if Path(key).exists() else ""
    cmd = "tail -n 100 ~/CYBRA/logs/oracle/oracle_agent_daemon.log 2>/dev/null || true; tail -n 60 ~/CYBRA/logs/oracle/dashboard_server.log 2>/dev/null || true"
    os.system(f"ssh {keypart} -p {port} {user}@{host} {json.dumps(cmd)}")

def workflow():
    sh("gh workflow run cybra-oracle-vps-deploy.yml")

def dashboard():
    host = os.environ.get("ORACLE_HOST", "ORACLE_IP")
    print(f"\nDashboard Oracle: http://{host}:8099/")
    print("Local dashboard file: public/cybra_oracle_dashboard/index.html")
    print("Report: posts/cybra_oracle_vps_report.md")

def codespace_patch():
    sh("bash scripts/codespace/cybra_codespace_patch_runner.sh")

def termux_patch():
    sh("bash scripts/termux/cybra_termux_patch_runner.sh")

def mihailka_build():
    sh("bash scripts/mihailka/build_mihailka_launcher.sh")
    print("✅ Mihailka launcher: dist/mihailka_cybra_launcher.sh")

def mihailka_start_local():
    sh("bash scripts/mihailka/mihailka_autostart.sh")

def evolution_task():
    make_task(
        "Daily evolution safe upgrade",
        "AI + IT + Cyber Parliament + Oracle + Codespace: перевірити еволюційний прогрес бота, не ламати 6000-line source, зберегти module 64, зробити safe patch, dashboard metrics, Binance/Bybit тільки safe-mode без live trading.",
        "all"
    )

def menu():
    while True:
        print("""
╔══════════════════════════════════════════════╗
║        CYBRA ANDROID CONTROL MENU-BAR        ║
╠══════════════════════════════════════════════╣
║ 1  Status / queues / module64                ║
║ 2  New task to AI + IT + CyberParliament     ║
║ 3  Send Android clipboard as task            ║
║ 4  Git sync / push patches                   ║
║ 5  Run CodeSpace signed patch locally        ║
║ 6  Install CYBRA on Oracle VPS               ║
║ 7  Run Oracle VPS signed patch               ║
║ 8  Oracle logs                               ║
║ 9  GitHub workflow deploy to Oracle          ║
║ 10 Dashboard link                            ║
║ 11 Run Termux Android signed patch           ║
║ 12 Daily evolution task                      ║
║ 13 Build Mihailka launcher                   ║
║ 14 Start Mihailka local autostart            ║
║ 0  Exit                                      ║
╚══════════════════════════════════════════════╝
""")
        c = input("CYBRA> ").strip()

        if c == "1":
            status(); pause()
        elif c == "2":
            title = input("Title: ").strip() or "CYBRA task"
            body = input("Task body: ").strip() or title
            make_task(title, body, "all"); pause()
        elif c == "3":
            clipboard_task(); pause()
        elif c == "4":
            git_sync(); pause()
        elif c == "5":
            codespace_patch(); pause()
        elif c == "6":
            oracle_install(); pause()
        elif c == "7":
            oracle_patch(); pause()
        elif c == "8":
            oracle_logs(); pause()
        elif c == "9":
            workflow(); pause()
        elif c == "10":
            dashboard(); pause()
        elif c == "11":
            termux_patch(); pause()
        elif c == "12":
            evolution_task(); pause()
        elif c == "13":
            mihailka_build(); pause()
        elif c == "14":
            mihailka_start_local(); pause()
        elif c == "0":
            break
        else:
            print("Unknown")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "status": status()
        elif cmd == "task": make_task(sys.argv[2] if len(sys.argv)>2 else "Task", " ".join(sys.argv[3:]) if len(sys.argv)>3 else "Task", "all")
        elif cmd == "git-sync": git_sync()
        elif cmd == "oracle-patch": oracle_patch()
        elif cmd == "dashboard": dashboard()
        elif cmd == "mihailka-build": mihailka_build()
        else: menu()
    else:
        menu()
