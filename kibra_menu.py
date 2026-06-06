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
