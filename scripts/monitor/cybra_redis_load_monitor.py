#!/usr/bin/env python3
import json, time, hashlib, subprocess, shutil, os, sys
from pathlib import Path

ROOT = Path.home() / "CYBRA"

QUEUES = {
    "DONE / виконані": [
        "cybra:completed:ai_tasks"
    ],
    "RETURN / невиконані назад": [
        "cybra:return:ai_tasks"
    ],
    "META EVOLUTION": [
        "cybra:meta:evolution:pool"
    ],
    "KIBRA POOLS": [
        "cybra:kibra:pool:mining_blocks",
        "cybra:ai:tasks:block_inbox",
        "ai_block_inbox"
    ],
    "IT / STRUCTURE": [
        "it_department",
        "cybra_mgs_all"
    ],
    "FINANCE": [
        "cybra:finance:evolution:pool",
        "cybra_finance_evolution"
    ],
    "ORACLE / CODESPACE": [
        "cybra_oracle_tasks",
        "cybra_codespace_inbox"
    ],
    "PARLIAMENT": [
        "parliament_inbox"
    ]
}

PROCESS_PATTERNS = [
    "redis-server",
    "python",
    "uvicorn",
    "cybra",
    "kibra",
    "node",
    "pm2",
    "ssh",
    "git"
]

TASK_DIRS = {
    "AI blocks": "data/cybra_ai_blocks",
    "KIBRA task blocks": "blockchain/kibra_chain/task_blocks",
    "Meta evolution blocks": "data/cybra_meta_evolution/blocks",
    "Meta modules": "data/cybra_meta_evolution/modules",
    "Finance IT tasks": "data/cybra_finance/it_department/tasks",
    "Oracle tasks": "data/cybra_oracle/tasks",
    "MGS tasks": "data/cybra_mgs/tasks",
    "Completed": "data/cybra_meta_evolution/completed",
    "Returned": "data/cybra_meta_evolution/returned"
}

RED = "\033[91m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
BLUE = "\033[94m"
BOLD = "\033[1m"
RESET = "\033[0m"

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def mkdir(p):
    Path(p).mkdir(parents=True, exist_ok=True)

def write_json(path, data):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(text, encoding="utf-8")

def sha_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def run(cmd):
    return subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)

def ensure_redis():
    if not shutil.which("redis-cli"):
        return False
    r = run("redis-cli ping")
    if r.returncode == 0 and "PONG" in r.stdout:
        return True
    mkdir(ROOT / "runtime/redis")
    run("redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1")
    time.sleep(1)
    r = run("redis-cli ping")
    return r.returncode == 0 and "PONG" in r.stdout

def redis_llen(q):
    if not shutil.which("redis-cli"):
        return None
    r = run(f"redis-cli LLEN '{q}'")
    try:
        return int((r.stdout or "0").strip())
    except Exception:
        return 0

def color_count(n, done=False):
    if n is None:
        return f"{YELLOW}(no redis){RESET}"
    if done:
        return f"{GREEN}({n}){RESET}"
    if n >= 50:
        return f"{RED}({n}){RESET}"
    if n >= 10:
        return f"{YELLOW}({n}){RESET}"
    if n > 0:
        return f"{RED}({n}){RESET}"
    return f"{GREEN}({n}){RESET}"

def html_color(n, done=False):
    if n is None:
        return "yellow"
    if done:
        return "green"
    if n >= 50:
        return "red"
    if n >= 10:
        return "yellow"
    if n > 0:
        return "red"
    return "green"

def file_count(path):
    p = ROOT / path
    if not p.exists():
        return 0
    return len([x for x in p.rglob("*.json") if x.is_file()])

def process_counts():
    result = {}
    ps = run("ps -A 2>/dev/null || ps 2>/dev/null")
    text = (ps.stdout or "") + "\n" + (ps.stderr or "")
    low = text.lower()

    for pat in PROCESS_PATTERNS:
        result[pat] = low.count(pat.lower())

    result["total_process_lines"] = len([x for x in text.splitlines() if x.strip()])
    return result

def git_status():
    if not (ROOT / ".git").exists():
        return {"repo": False}
    branch = run("git branch --show-current").stdout.strip()
    status = run("git status --porcelain").stdout.splitlines()
    remote = run("git remote -v").stdout.strip().splitlines()
    return {
        "repo": True,
        "branch": branch,
        "dirty_files": len(status),
        "remote": remote[:4]
    }

def recommendations(queue_groups, proc, files):
    rec = []
    for group, items in queue_groups.items():
        total = sum(x["count"] or 0 for x in items)
        if group != "DONE / виконані" and total >= 50:
            rec.append(f"RED overload: {group} має {total} задач. Треба розвантажити через додатковий worker або повернути частину в rework.")
        elif group != "DONE / виконані" and total >= 10:
            rec.append(f"YELLOW load: {group} має {total} задач. Потрібен контроль.")
        elif group != "DONE / виконані" and total > 0:
            rec.append(f"RED pending: {group} має {total} невиконаних задач.")
    if proc.get("redis-server", 0) == 0:
        rec.append("Redis не активний або не видно процесу redis-server.")
    if proc.get("python", 0) > 20:
        rec.append("Багато Python процесів. Перевірити зайві workers.")
    if not rec:
        rec.append("Навантаження нормальне. Критичних черг не видно.")
    return rec

def build():
    redis_ok = ensure_redis()

    queue_groups = {}
    for group, qs in QUEUES.items():
        queue_groups[group] = []
        for q in qs:
            queue_groups[group].append({
                "queue": q,
                "count": redis_llen(q) if redis_ok else None
            })

    files = {name: file_count(path) for name, path in TASK_DIRS.items()}
    proc = process_counts()
    git = git_status()

    total_done = sum(x["count"] or 0 for x in queue_groups.get("DONE / виконані", []))
    total_return = sum(x["count"] or 0 for x in queue_groups.get("RETURN / невиконані назад", []))
    total_pending = 0
    for group, items in queue_groups.items():
        if group not in ("DONE / виконані",):
            total_pending += sum(x["count"] or 0 for x in items)

    rec = recommendations(queue_groups, proc, files)

    report = {
        "timestamp": now(),
        "status": "CYBRA_LOAD_MONITOR_OK",
        "redis_ok": redis_ok,
        "summary": {
            "done_tasks_redis": total_done,
            "returned_unfinished_redis": total_return,
            "pending_all_redis": total_pending,
            "process_lines": proc.get("total_process_lines"),
            "git_branch": git.get("branch"),
            "git_dirty_files": git.get("dirty_files")
        },
        "queue_groups": queue_groups,
        "process_counts": proc,
        "file_task_counts": files,
        "git": git,
        "recommendations": rec,
        "safety": {
            "real_payment_now": False,
            "automatic_external_tx": False,
            "automatic_withdrawals": False,
            "automatic_SWIFT": False,
            "automatic_real_rewards": False
        }
    }

    write_json(ROOT / "data/cybra_load_monitor/reports/load_monitor_latest.json", report)
    write_json(ROOT / "feeds/cybra_load_monitor.json", report)

    terminal = []
    terminal.append(f"{BOLD}=== CYBRA REDIS / TASK / PROCESS LOAD ==={RESET}")
    terminal.append(f"Time: {report['timestamp']}")
    terminal.append(f"Redis: {GREEN + 'OK' + RESET if redis_ok else RED + 'NO' + RESET}")
    terminal.append("")
    terminal.append(f"{BOLD}SUMMARY{RESET}")
    terminal.append(f"Виконані Redis {color_count(total_done, done=True)}")
    terminal.append(f"Невиконані/повернуті Redis {color_count(total_return)}")
    terminal.append(f"Усі pending Redis {color_count(total_pending)}")
    terminal.append(f"Git branch: {BLUE}{git.get('branch')}{RESET} dirty {color_count(git.get('dirty_files') or 0)}")
    terminal.append("")
    terminal.append(f"{BOLD}QUEUES / ГІЛКИ НАВАНТАЖЕННЯ{RESET}")

    for group, items in queue_groups.items():
        total = sum(x["count"] or 0 for x in items)
        done = group == "DONE / виконані"
        terminal.append(f"{group}: {color_count(total, done=done)}")
        for item in items:
            terminal.append(f"  - {item['queue']} {color_count(item['count'], done=done)}")

    terminal.append("")
    terminal.append(f"{BOLD}FILES / TASK STORAGE{RESET}")
    for name, n in files.items():
        terminal.append(f"{name}: {color_count(n)}")

    terminal.append("")
    terminal.append(f"{BOLD}PROCESSES{RESET}")
    for name, n in proc.items():
        terminal.append(f"{name}: {color_count(n)}")

    terminal.append("")
    terminal.append(f"{BOLD}RECOMMENDATIONS{RESET}")
    for x in rec:
        terminal.append(f"- {x}")

    terminal_text = "\n".join(terminal)
    write_text(ROOT / "posts/cybra_load_monitor.md", terminal_text)

    html_rows = []
    for group, items in queue_groups.items():
        total = sum(x["count"] or 0 for x in items)
        done = group == "DONE / виконані"
        html_rows.append(f"<tr><td><b>{group}</b></td><td class='{html_color(total, done)}'>({total})</td><td></td></tr>")
        for item in items:
            c = item["count"]
            html_rows.append(f"<tr><td>{item['queue']}</td><td class='{html_color(c, done)}'>({c})</td><td>queue</td></tr>")

    html = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Load Monitor</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1100px; margin: 35px auto; padding: 20px; }}
table {{ border-collapse: collapse; width: 100%; }}
td, th {{ border: 1px solid #ddd; padding: 8px; }}
.red {{ color: #c40000; font-weight: 800; }}
.yellow {{ color: #a36b00; font-weight: 800; }}
.green {{ color: #007a2f; font-weight: 800; }}
.card {{ border: 1px solid #ddd; border-radius: 14px; padding: 16px; margin: 14px 0; }}
code {{ word-break: break-all; }}
</style>
</head>
<body>
<h1>CYBRA Redis / Task / Process Load</h1>
<div class="card">
<p>Status: <b>{report["status"]}</b></p>
<p>Redis: <b>{redis_ok}</b></p>
<p>Done: <span class="green">({total_done})</span></p>
<p>Returned unfinished: <span class="red">({total_return})</span></p>
<p>Pending all: <span class="{html_color(total_pending)}">({total_pending})</span></p>
<p>Git branch: <code>{git.get("branch")}</code>, dirty: <span class="{html_color(git.get("dirty_files") or 0)}">({git.get("dirty_files")})</span></p>
</div>
<h2>Queues / branches</h2>
<table>
<tr><th>Гілка</th><th>Навантаження</th><th>Тип</th></tr>
{''.join(html_rows)}
</table>
<h2>Recommendations</h2>
<ul>
{''.join('<li>'+x+'</li>' for x in rec)}
</ul>
</body>
</html>
"""
    write_text(ROOT / "dashboard/cybra_load_monitor/index.html", html)

    proof_targets = [
        "data/cybra_load_monitor/reports/load_monitor_latest.json",
        "feeds/cybra_load_monitor.json",
        "posts/cybra_load_monitor.md",
        "dashboard/cybra_load_monitor/index.html",
        "scripts/monitor/cybra_redis_load_monitor.py"
    ]

    proof = ""
    for x in proof_targets:
        p = ROOT / x
        if p.exists():
            proof += f"{sha_file(p)}  {x}\n"
    write_text(ROOT / "proofs/cybra_load_monitor.sha256", proof)

    print(terminal_text)

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd in ("status", "run"):
        build()
    elif cmd == "json":
        print((ROOT / "data/cybra_load_monitor/reports/load_monitor_latest.json").read_text(encoding="utf-8"))
    elif cmd == "proof":
        subprocess.call("sha256sum -c proofs/cybra_load_monitor.sha256", shell=True, cwd=ROOT)
    else:
        print("Commands: status | json | proof")

if __name__ == "__main__":
    main()
