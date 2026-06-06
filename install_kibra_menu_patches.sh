#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== INSTALL KIBRA MENU + KIBRA IT MENU PATCHES ==="

TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p \
  scripts/menus \
  patches/kibra_menu \
  patches/kibra_it_menu \
  data/kibra_menu/{tasks,reports,status} \
  data/kibra_it_menu/{tasks,reports,status} \
  posts feeds proofs logs/kibra_menu logs/kibra_it_menu \
  .termux/boot runtime/redis

# Redis
if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

# ---------- KIBRA MAIN MENU ----------
cat > kibra_menu.py <<'PY'
#!/usr/bin/env python3
import os, subprocess, json, time, uuid
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sh(cmd):
    return subprocess.run(cmd, shell=True, cwd=ROOT, text=True)

def out(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)
    return (p.stdout or p.stderr or "").strip()

def pause():
    input("\nENTER...")

def task(title, body):
    tid = f"KIBRA-MENU-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    payload = {
        "task_id": tid,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "source": "kibra-menu",
        "title": title,
        "body": body,
        "routes": ["ai", "it", "parliament", "oracle", "codespace", "mgs"],
        "safety": {
            "real_trading_now": False,
            "live_force_trading_disabled": True,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    for d in [
        ROOT / "data/kibra_menu/tasks",
        ROOT / "data/cybra_mgs/tasks",
        ROOT / "data/cybra_oracle/tasks"
    ]:
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{tid}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    raw = json.dumps(payload, ensure_ascii=False)
    safe = json.dumps(raw)
    for q in ["cybra_mgs_all", "cybra_oracle_tasks", "ai_block_inbox", "it_department", "parliament_inbox"]:
        sh(f"redis-cli LPUSH {q} {safe} >/dev/null 2>&1 || true")

    print(json.dumps(payload, ensure_ascii=False, indent=2))

def status():
    print("\n=== KIBRA MENU STATUS ===\n")
    for q in ["cybra_mgs_all", "cybra_oracle_tasks", "ai_block_inbox", "it_department", "parliament_inbox"]:
        print(q + ":", out(f"redis-cli LLEN {q} 2>/dev/null || echo 0"))

    print("\n--- Module 64 ---")
    sh("ls -la trading_bot/v64/modules/64 2>/dev/null || true")

    print("\n--- Oracle report ---")
    sh("tail -n 30 posts/cybra_oracle_vps_report.md 2>/dev/null || true")

def menu():
    while True:
        print("""
╔════════════════════════════════════╗
║            KIBRA MENU              ║
╠════════════════════════════════════╣
║ 1  Status                          ║
║ 2  Open CYBRA main bar             ║
║ 3  Open KIBRA IT menu              ║
║ 4  New task to AI+IT+Parliament    ║
║ 5  Git sync                        ║
║ 6  Oracle patch                    ║
║ 7  Codespace patch                 ║
║ 8  Dashboard link                  ║
║ 9  Evolution task                  ║
║ 0  Exit                            ║
╚════════════════════════════════════╝
""")
        c = input("KIBRA> ").strip()

        if c == "1":
            status(); pause()
        elif c == "2":
            sh("cybra-bar || python3 cybra_bar.py"); pause()
        elif c == "3":
            sh("kibra-it-menu"); pause()
        elif c == "4":
            title = input("Title: ").strip() or "KIBRA task"
            body = input("Body: ").strip() or title
            task(title, body); pause()
        elif c == "5":
            sh("git add . && git commit -m 'kibra menu sync' || true && git pull --rebase origin main && git push origin main"); pause()
        elif c == "6":
            sh("bash scripts/oracle/cybra_oracle_patch_runner.sh"); pause()
        elif c == "7":
            sh("bash scripts/codespace/cybra_codespace_patch_runner.sh"); pause()
        elif c == "8":
            host = os.environ.get("ORACLE_HOST", "ORACLE_IP")
            print(f"Oracle dashboard: http://{host}:8099/")
            pause()
        elif c == "9":
            task("KIBRA daily evolution", "AI + IT + Cyber Parliament + Oracle + Codespace: safe evolutionary upgrade, preserve 6000-line bot and module64.")
            pause()
        elif c == "0":
            break

if __name__ == "__main__":
    menu()
PY

chmod +x kibra_menu.py

cat > kibra-menu <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 kibra_menu.py "$@"
EOF

chmod +x kibra-menu
ln -sf "$HOME/CYBRA/kibra-menu" "$PREFIX/bin/kibra-menu" 2>/dev/null || true
ln -sf "$HOME/CYBRA/kibra-menu" "$PREFIX/bin/kibra" 2>/dev/null || true

# ---------- KIBRA IT MENU ----------
cat > kibra_it_menu.py <<'PY'
#!/usr/bin/env python3
import subprocess, json, time, uuid
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sh(cmd):
    return subprocess.run(cmd, shell=True, cwd=ROOT, text=True)

def out(cmd):
    p = subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)
    return (p.stdout or p.stderr or "").strip()

def pause():
    input("\nENTER...")

def it_task(title, body, priority="normal"):
    tid = f"KIBRA-IT-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    payload = {
        "task_id": tid,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "source": "kibra-it-menu",
        "department": "KIBRA_IT_DEPARTMENT",
        "title": title,
        "body": body,
        "priority": priority,
        "routes": ["it_department", "mgs_restart_watchdog", "oracle", "codespace"],
        "evolution_rule": "patch_as_layer; do_not_break_existing; preserve_module64; preserve_original_6000_lines",
        "safety": {
            "real_trading_now": False,
            "live_force_trading_disabled": True,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    for d in [
        ROOT / "data/kibra_it_menu/tasks",
        ROOT / "data/cybra_mgs/tasks",
        ROOT / "data/cybra_oracle/tasks"
    ]:
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{tid}.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    raw = json.dumps(payload, ensure_ascii=False)
    safe = json.dumps(raw)
    for q in ["it_department", "cybra_mgs_all", "cybra_oracle_tasks", "cybra_codespace_inbox"]:
        sh(f"redis-cli LPUSH {q} {safe} >/dev/null 2>&1 || true")

    print(json.dumps(payload, ensure_ascii=False, indent=2))

def status():
    print("\n=== KIBRA IT MENU STATUS ===\n")
    for q in ["it_department", "cybra_mgs_all", "cybra_oracle_tasks", "cybra_codespace_inbox"]:
        print(q + ":", out(f"redis-cli LLEN {q} 2>/dev/null || echo 0"))

    print("\n--- latest IT tasks ---")
    sh("ls -lt data/kibra_it_menu/tasks 2>/dev/null | head -10 || true")

    print("\n--- module64 ---")
    sh("cat trading_bot/v64/modules/64/INDEX.md 2>/dev/null || true")

def repair_module64():
    it_task(
        "Repair v64 module64 runner",
        "IT: перевірити 6000-line bot syntax, зробити safe runner для module64, не ламати original source, не включати live trading без OWNER approval.",
        "high"
    )

def restart_watchdog():
    it_task(
        "Restart watchdog patch",
        "Watchdog: перевірити падіння модулів, сформувати restart patch, віддати IT department, Oracle runner має працювати навіть якщо Termux offline.",
        "high"
    )

def oracle_runner_task():
    it_task(
        "Oracle runner upgrade",
        "IT + Integration: основні процеси перенести на Oracle VPS, Termux тільки control bar, GitHub/Codespace sync, dashboard live.",
        "high"
    )

def codespace_task():
    it_task(
        "Codespace worker upgrade",
        "IT: перевірити Codespace worker, tasks, reports, proofs, dashboard feeds. Не втрачати module64 і original 6000 lines.",
        "normal"
    )

def menu():
    while True:
        print("""
╔════════════════════════════════════════════╗
║             KIBRA IT MENU                  ║
╠════════════════════════════════════════════╣
║ 1  IT status / queues                      ║
║ 2  New IT task                             ║
║ 3  Repair module64 safe runner             ║
║ 4  Restart watchdog task                   ║
║ 5  Oracle runner upgrade task              ║
║ 6  Codespace worker upgrade task           ║
║ 7  Run Oracle patch locally                ║
║ 8  Run Codespace patch locally             ║
║ 9  Git sync                                ║
║ 10 Open main KIBRA menu                    ║
║ 0  Exit                                    ║
╚════════════════════════════════════════════╝
""")
        c = input("KIBRA-IT> ").strip()

        if c == "1":
            status(); pause()
        elif c == "2":
            title = input("IT Title: ").strip() or "KIBRA IT task"
            body = input("IT Body: ").strip() or title
            it_task(title, body); pause()
        elif c == "3":
            repair_module64(); pause()
        elif c == "4":
            restart_watchdog(); pause()
        elif c == "5":
            oracle_runner_task(); pause()
        elif c == "6":
            codespace_task(); pause()
        elif c == "7":
            sh("bash scripts/oracle/cybra_oracle_patch_runner.sh"); pause()
        elif c == "8":
            sh("bash scripts/codespace/cybra_codespace_patch_runner.sh"); pause()
        elif c == "9":
            sh("git add . && git commit -m 'kibra it menu sync' || true && git pull --rebase origin main && git push origin main"); pause()
        elif c == "10":
            sh("kibra-menu"); pause()
        elif c == "0":
            break

if __name__ == "__main__":
    menu()
PY

chmod +x kibra_it_menu.py

cat > kibra-it-menu <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 kibra_it_menu.py "$@"
EOF

chmod +x kibra-it-menu
ln -sf "$HOME/CYBRA/kibra-it-menu" "$PREFIX/bin/kibra-it-menu" 2>/dev/null || true
ln -sf "$HOME/CYBRA/kibra-it-menu" "$PREFIX/bin/cybra-it-menu" 2>/dev/null || true
ln -sf "$HOME/CYBRA/kibra-it-menu" "$PREFIX/bin/kibra-it" 2>/dev/null || true

# ---------- signed patches ----------
cat > patches/kibra_menu/KIBRA_MENU_PATCH_${TS}.json <<EOF
{
  "patch": "KIBRA_MENU_PATCH",
  "timestamp": "$TS",
  "commands": ["kibra-menu", "kibra"],
  "files": ["kibra_menu.py", "kibra-menu"],
  "purpose": "Main KIBRA menu-bar for Android Termux control of Oracle, Codespace, GitHub, AI, IT, Cyber Parliament.",
  "safety": {
    "real_trading_now": false,
    "live_force_trading_disabled": true,
    "automatic_external_tx": false,
    "manual_OWNER_approval_required": true
  }
}
EOF

cat > patches/kibra_it_menu/KIBRA_IT_MENU_PATCH_${TS}.json <<EOF
{
  "patch": "KIBRA_IT_MENU_PATCH",
  "timestamp": "$TS",
  "commands": ["kibra-it-menu", "cybra-it-menu", "kibra-it"],
  "files": ["kibra_it_menu.py", "kibra-it-menu"],
  "purpose": "Separate KIBRA IT department menu for module64 repair, Oracle runner, Codespace worker, restart watchdog and evolutionary patches.",
  "safety": {
    "real_trading_now": false,
    "live_force_trading_disabled": true,
    "automatic_external_tx": false,
    "manual_OWNER_approval_required": true
  }
}
EOF

# ---------- boot helper ----------
cat > .termux/boot/start-kibra-menus.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 0
mkdir -p logs/kibra_menu runtime/redis

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

echo "$(date -Iseconds) KIBRA menus boot OK" >> logs/kibra_menu/boot.log
EOF

chmod +x .termux/boot/start-kibra-menus.sh

# ---------- reports ----------
cat > posts/kibra_menu_patches_report.md <<EOF
# KIBRA Menu Patches Report

Status: INSTALLED  
Timestamp: $TS

## Patch 1: KIBRA MENU

Command:

\`\`\`bash
kibra-menu
\`\`\`

Alias:

\`\`\`bash
kibra
\`\`\`

Patch:

\`\`\`
patches/kibra_menu/KIBRA_MENU_PATCH_${TS}.json
\`\`\`

## Patch 2: KIBRA IT MENU

Command:

\`\`\`bash
kibra-it-menu
\`\`\`

Aliases:

\`\`\`bash
cybra-it-menu
kibra-it
\`\`\`

Patch:

\`\`\`
patches/kibra_it_menu/KIBRA_IT_MENU_PATCH_${TS}.json
\`\`\`

## Safety

real_trading_now: false  
live_force_trading_disabled: true  
automatic_external_tx: false  
manual_OWNER_approval_required: true
EOF

cat > feeds/kibra_menu_patches_report.json <<EOF
{
  "status": "INSTALLED",
  "timestamp": "$TS",
  "kibra_menu": "kibra-menu",
  "kibra_it_menu": "kibra-it-menu",
  "patches": {
    "kibra_menu": "patches/kibra_menu/KIBRA_MENU_PATCH_${TS}.json",
    "kibra_it_menu": "patches/kibra_it_menu/KIBRA_IT_MENU_PATCH_${TS}.json"
  },
  "safety": {
    "real_trading_now": false,
    "live_force_trading_disabled": true,
    "automatic_external_tx": false,
    "manual_OWNER_approval_required": true
  }
}
EOF

sha256sum \
  kibra_menu.py \
  kibra-menu \
  kibra_it_menu.py \
  kibra-it-menu \
  patches/kibra_menu/KIBRA_MENU_PATCH_${TS}.json \
  patches/kibra_it_menu/KIBRA_IT_MENU_PATCH_${TS}.json \
  posts/kibra_menu_patches_report.md \
  feeds/kibra_menu_patches_report.json \
  .termux/boot/start-kibra-menus.sh \
  > proofs/kibra_menu_patches.sha256

echo
echo "✅ KIBRA MENU PATCHES INSTALLED"
echo
echo "Commands:"
echo "  kibra-menu"
echo "  kibra-it-menu"
echo "  cybra-it-menu"
echo
