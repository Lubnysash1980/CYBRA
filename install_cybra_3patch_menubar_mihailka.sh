#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA 3-PATCH MENUBAR + MIHAILKA LAUNCHER ==="

TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p \
  bin scripts/oracle scripts/codespace scripts/termux scripts/mihailka \
  patches/codespace patches/oracle patches/termux patches/mihailka \
  data/cybra_control_bar/{tasks,reports,patches,status} \
  data/cybra_mgs/tasks \
  posts feeds proofs logs/control_bar logs/oracle logs/codespace logs/mihailka \
  public/cybra_oracle_dashboard \
  runtime/redis .termux/boot .devcontainer .github/workflows dist

# ---------- Redis safe ----------
if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

# ---------- Common patch signer ----------
cat > scripts/cybra_patch_signer.py <<'PY'
#!/usr/bin/env python3
import json, time, hashlib, sys
from pathlib import Path

ROOT = Path.home() / "CYBRA"
PROOFS = ROOT / "proofs"
PROOFS.mkdir(parents=True, exist_ok=True)

SAFETY = {
    "real_trading_now": False,
    "live_force_trading_disabled": True,
    "automatic_external_tx": False,
    "automatic_SWIFT": False,
    "mainnet_deploy_allowed": False,
    "manual_OWNER_approval_required": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def sha_text(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def sign_patch(kind, title, target_file, body):
    payload = {
        "kind": kind,
        "title": title,
        "timestamp": now(),
        "target_file": target_file,
        "body": body,
        "safety": SAFETY
    }

    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2)
    first = sha_text(raw)
    double = sha_text(first)

    payload["sha256"] = first
    payload["double_sha256"] = double
    payload["signature_type"] = "CYBRA_DOUBLE_SHA256_LOCAL_SIGNATURE"

    path = ROOT / target_file
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    proof = PROOFS / f"{Path(target_file).stem}.sha256"
    proof.write_text(f"{first}  {target_file}\nDOUBLE_SHA256 {double}\n", encoding="utf-8")

    print(json.dumps(payload, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    kind = sys.argv[1]
    title = sys.argv[2]
    target = sys.argv[3]
    body = " ".join(sys.argv[4:])
    sign_patch(kind, title, target, body)
PY

chmod +x scripts/cybra_patch_signer.py

# ---------- CodeSpace signed patch ----------
cat > scripts/codespace/cybra_codespace_patch_runner.sh <<'BASH2'
#!/usr/bin/env bash
set +e
cd /workspaces/CYBRA 2>/dev/null || cd "$HOME/CYBRA" 2>/dev/null || cd "$(pwd)" || exit 1

echo "=== CYBRA CODESPACE PATCH RUNNER ==="

mkdir -p data/cybra_mgs/tasks data/cybra_oracle/reports posts feeds proofs logs/codespace public/cybra_oracle_dashboard

python3 scripts/oracle/cybra_oracle_agent.py 2>/dev/null || true

cat > posts/cybra_codespace_patch_status.md <<EOF
# CYBRA CodeSpace Patch Status

Status: CODESPACE_PATCH_ACTIVE  
Role: secondary workspace / report builder / task processor

Safety:
- real_trading_now: false
- live_force_trading_disabled: true
- automatic_external_tx: false
- manual_OWNER_approval_required: true
EOF

sha256sum posts/cybra_codespace_patch_status.md > proofs/cybra_codespace_patch_status.sha256 2>/dev/null || true

echo "✅ CodeSpace patch executed"
BASH2

chmod +x scripts/codespace/cybra_codespace_patch_runner.sh

cat > .devcontainer/cybra_codespace_autostart.sh <<'BASH2'
#!/usr/bin/env bash
set +e
cd /workspaces/CYBRA 2>/dev/null || cd "$PWD" || exit 1
bash scripts/codespace/cybra_codespace_patch_runner.sh
BASH2

chmod +x .devcontainer/cybra_codespace_autostart.sh

if [ ! -f .devcontainer/devcontainer.json ]; then
cat > .devcontainer/devcontainer.json <<'JSON'
{
  "name": "CYBRA Codespace",
  "image": "mcr.microsoft.com/devcontainers/python:3.12",
  "postCreateCommand": "bash .devcontainer/cybra_codespace_autostart.sh"
}
JSON
else
  cp .devcontainer/devcontainer.json ".devcontainer/devcontainer.backup.$TS.json" 2>/dev/null || true
fi

python3 scripts/cybra_patch_signer.py \
  "CODESPACE_PATCH" \
  "CYBRA CodeSpace signed patch" \
  "patches/codespace/CODESPACE_PATCH_${TS}.json" \
  "CodeSpace виконує окремий runner, приймає задачі з GitHub, формує reports/proofs, не запускає live trading без OWNER approval."

# ---------- Oracle VPS signed patch ----------
cat > scripts/oracle/cybra_oracle_patch_runner.sh <<'BASH3'
#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || cd "$(pwd)" || exit 1

echo "=== CYBRA ORACLE VPS PATCH RUNNER ==="

mkdir -p data/cybra_oracle/{tasks,reports,processed} data/cybra_mgs/tasks posts feeds proofs logs/oracle public/cybra_oracle_dashboard

python3 scripts/oracle/cybra_oracle_agent.py 2>/dev/null || true

if ! pgrep -f "cybra_oracle_agent.py daemon" >/dev/null 2>&1; then
  nohup python3 scripts/oracle/cybra_oracle_agent.py daemon \
    > logs/oracle/oracle_agent_daemon.log 2>&1 &
fi

if ! pgrep -f "http.server 8099" >/dev/null 2>&1; then
  nohup python3 -m http.server 8099 --bind 0.0.0.0 --directory public/cybra_oracle_dashboard \
    > logs/oracle/dashboard_server.log 2>&1 &
fi

cat > posts/cybra_oracle_patch_status.md <<EOF
# CYBRA Oracle VPS Patch Status

Status: ORACLE_VPS_PATCH_ACTIVE  
Role: main remote runner / heavy process / dashboard host

Dashboard:
http://ORACLE_IP:8099/

Safety:
- real_trading_now: false
- live_force_trading_disabled: true
- automatic_external_tx: false
- manual_OWNER_approval_required: true
EOF

sha256sum posts/cybra_oracle_patch_status.md > proofs/cybra_oracle_patch_status.sha256 2>/dev/null || true

echo "✅ Oracle VPS patch executed"
echo "Dashboard: http://ORACLE_IP:8099/"
BASH3

chmod +x scripts/oracle/cybra_oracle_patch_runner.sh

python3 scripts/cybra_patch_signer.py \
  "ORACLE_VPS_PATCH" \
  "CYBRA Oracle VPS signed patch" \
  "patches/oracle/ORACLE_VPS_PATCH_${TS}.json" \
  "Oracle VPS є головний runner. Він тягне GitHub, приймає MGS задачі, тримає dashboard, обробляє 6000-line bot reports, module 64 зберігається."

# ---------- Android Termux signed patch ----------
cat > scripts/termux/cybra_termux_patch_runner.sh <<'BASH4'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

mkdir -p logs/control_bar data/cybra_control_bar/status posts feeds proofs runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

python3 scripts/oracle/cybra_oracle_agent.py 2>/dev/null || true

cat > posts/cybra_termux_patch_status.md <<EOF
# CYBRA Android Termux Patch Status

Status: TERMUX_CONTROL_BAR_ACTIVE  
Role: Android menu-bar / task sender / Oracle-GitHub-CodeSpace controller

Safety:
- real_trading_now: false
- live_force_trading_disabled: true
- automatic_external_tx: false
- manual_OWNER_approval_required: true
EOF

sha256sum posts/cybra_termux_patch_status.md > proofs/cybra_termux_patch_status.sha256 2>/dev/null || true

echo "✅ Termux patch active"
BASH4

chmod +x scripts/termux/cybra_termux_patch_runner.sh

python3 scripts/cybra_patch_signer.py \
  "TERMUX_ANDROID_PATCH" \
  "CYBRA Android Termux menu-bar signed patch" \
  "patches/termux/TERMUX_ANDROID_PATCH_${TS}.json" \
  "Android Termux не виконує важкі процеси. Він керує Oracle VPS, CodeSpace, GitHub, AI, IT, Cyber Parliament і 5 MGS committees через menu-bar."

# ---------- Android menu-bar ----------
cat > cybra_bar.py <<'PY'
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
PY

chmod +x cybra_bar.py

cat > cybra-bar <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 cybra_bar.py "$@"
EOF

chmod +x cybra-bar
ln -sf "$HOME/CYBRA/cybra-bar" "$PREFIX/bin/cybra-bar" 2>/dev/null || true
ln -sf "$HOME/CYBRA/cybra-bar" "$PREFIX/bin/cybra-menu-bar" 2>/dev/null || true

# ---------- Termux autostart ----------
cat > .termux/boot/start-cybra-control-bar.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 0
mkdir -p logs/control_bar runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

bash scripts/termux/cybra_termux_patch_runner.sh > logs/control_bar/termux_boot_patch.log 2>&1 || true
python3 scripts/oracle/cybra_oracle_agent.py > logs/control_bar/termux_boot_status.log 2>&1 || true
EOF

chmod +x .termux/boot/start-cybra-control-bar.sh

# ---------- Mihailka launcher ----------
cat > scripts/mihailka/build_mihailka_launcher.sh <<'BASH5'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1
mkdir -p dist scripts/mihailka patches/mihailka proofs

cat > dist/mihailka_cybra_launcher.sh <<'MIH'
#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=== MIHAILKA CYBRA LAUNCHER ==="

pkg update -y || true
pkg install -y git python redis openssh jq curl gh termux-api || true

cd "$HOME" || exit 1

if [ ! -d "$HOME/CYBRA/.git" ]; then
  git clone https://github.com/Lubnysash1980/CYBRA.git "$HOME/CYBRA" || exit 1
fi

cd "$HOME/CYBRA" || exit 1
git pull --rebase origin main || true

mkdir -p runtime/redis logs/mihailka

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

chmod +x cybra-bar 2>/dev/null || true
ln -sf "$HOME/CYBRA/cybra-bar" "$PREFIX/bin/cybra-bar" 2>/dev/null || true

bash scripts/termux/cybra_termux_patch_runner.sh > logs/mihailka/start_patch.log 2>&1 || true

echo
echo "✅ MIHAILKA READY"
echo "Run:"
echo "  cd ~/CYBRA"
echo "  cybra-bar"
echo
MIH

chmod +x dist/mihailka_cybra_launcher.sh

sha256sum dist/mihailka_cybra_launcher.sh > proofs/mihailka_cybra_launcher.sha256

python3 scripts/cybra_patch_signer.py \
  "MIHAILKA_LAUNCHER_PATCH" \
  "Mihailka extra launcher patch" \
  "patches/mihailka/MIHAILKA_LAUNCHER_PATCH.json" \
  "Standalone launcher для іншого Android Termux/додатку: clone CYBRA, install deps, start Redis, activate cybra-bar."

echo "✅ Built dist/mihailka_cybra_launcher.sh"
BASH5

chmod +x scripts/mihailka/build_mihailka_launcher.sh
bash scripts/mihailka/build_mihailka_launcher.sh

cat > scripts/mihailka/mihailka_autostart.sh <<'BASH6'
#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1
mkdir -p logs/mihailka runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
fi

bash scripts/termux/cybra_termux_patch_runner.sh > logs/mihailka/mihailka_patch.log 2>&1 || true
python3 scripts/oracle/cybra_oracle_agent.py > logs/mihailka/mihailka_status.log 2>&1 || true

echo "✅ Mihailka local autostart done"
echo "Run menu: cybra-bar"
BASH6

chmod +x scripts/mihailka/mihailka_autostart.sh

# ---------- reports ----------
cat > posts/cybra_3patch_menubar_report.md <<EOF
# CYBRA 3-Patch Menu-Bar Report

Status: INSTALLED

## Signed patches

### CodeSpace
- patches/codespace/CODESPACE_PATCH_${TS}.json
- scripts/codespace/cybra_codespace_patch_runner.sh
- .devcontainer/cybra_codespace_autostart.sh

### Oracle VPS
- patches/oracle/ORACLE_VPS_PATCH_${TS}.json
- scripts/oracle/cybra_oracle_patch_runner.sh

### Android Termux
- patches/termux/TERMUX_ANDROID_PATCH_${TS}.json
- scripts/termux/cybra_termux_patch_runner.sh
- cybra-bar
- cybra-menu-bar

### Mihailka
- dist/mihailka_cybra_launcher.sh
- patches/mihailka/MIHAILKA_LAUNCHER_PATCH.json

## Menu command

\`\`\`bash
cybra-bar
\`\`\`

## Safety

real_trading_now: false  
live_force_trading_disabled: true  
automatic_external_tx: false  
automatic_SWIFT: false  
mainnet_deploy_allowed: false  
manual_OWNER_approval_required: true
EOF

cat > feeds/cybra_3patch_menubar_report.json <<EOF
{
  "status": "INSTALLED",
  "timestamp": "$TS",
  "commands": {
    "menu": "cybra-bar",
    "menu_alias": "cybra-menu-bar",
    "mihailka_launcher": "dist/mihailka_cybra_launcher.sh"
  },
  "patches": {
    "codespace": "patches/codespace/CODESPACE_PATCH_${TS}.json",
    "oracle": "patches/oracle/ORACLE_VPS_PATCH_${TS}.json",
    "termux": "patches/termux/TERMUX_ANDROID_PATCH_${TS}.json",
    "mihailka": "patches/mihailka/MIHAILKA_LAUNCHER_PATCH.json"
  },
  "safety": {
    "real_trading_now": false,
    "live_force_trading_disabled": true,
    "automatic_external_tx": false,
    "automatic_SWIFT": false,
    "mainnet_deploy_allowed": false,
    "manual_OWNER_approval_required": true
  }
}
EOF

sha256sum \
  cybra_bar.py \
  cybra-bar \
  scripts/cybra_patch_signer.py \
  scripts/codespace/cybra_codespace_patch_runner.sh \
  scripts/oracle/cybra_oracle_patch_runner.sh \
  scripts/termux/cybra_termux_patch_runner.sh \
  scripts/mihailka/build_mihailka_launcher.sh \
  scripts/mihailka/mihailka_autostart.sh \
  dist/mihailka_cybra_launcher.sh \
  posts/cybra_3patch_menubar_report.md \
  feeds/cybra_3patch_menubar_report.json \
  > proofs/cybra_3patch_menubar.sha256 2>/dev/null || true

bash scripts/termux/cybra_termux_patch_runner.sh

echo
echo "✅ CYBRA 3-PATCH MENUBAR INSTALLED"
echo
echo "Run menu:"
echo "  cybra-bar"
echo
echo "Mihailka launcher:"
echo "  bash dist/mihailka_cybra_launcher.sh"
echo
echo "Commit:"
echo "  git add cybra_bar.py cybra-bar scripts patches .termux/boot dist posts feeds proofs .devcontainer .github/workflows"
echo "  git commit -m 'add CYBRA 3-patch menubar and mihailka launcher'"
echo "  git pull --rebase origin main"
echo "  git push origin main"
