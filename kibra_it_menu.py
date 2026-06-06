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
