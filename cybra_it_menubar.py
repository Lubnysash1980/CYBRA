#!/usr/bin/env python3
import json, time, hashlib, subprocess, sys, shutil
from pathlib import Path

ROOT = Path.home() / "CYBRA"

ROUTES = {
    "ai": "cybra:ai:tasks:block_inbox",
    "parliament": "cybra:parliament:queue",
    "mining": "cybra:kibra:task_blocks:mempool",
    "pool": "cybra:kibra:pool:mining_blocks",
    "it": "cybra:it_department:queue",
    "evolution": "cybra:evolution:queue",
    "security": "cybra:security:queue"
}

PATTERNS = [
    "data/cybra_it_menu/tasks/*.json",
    "data/cybra_it_evolution/tasks/*.json",
    "data/auto_cases/tasks/*.json",
    "data/mainnet_prepare/*task*.json"
]

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def dsha(o):
    return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))

def run(cmd):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=90)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def redis(args):
    return run(["redis-cli"] + args)

def rlen(key):
    c,o,e = redis(["LLEN", key])
    return int(o) if c == 0 and o.isdigit() else 0

def rpush(key, obj):
    redis(["LPUSH", key, json.dumps(obj, ensure_ascii=False)])

def save(path, obj):
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def load(p):
    try:
        return json.loads(p.read_text(encoding="utf-8", errors="ignore"))
    except Exception:
        return None

def title(o):
    return str(o.get("topic") or o.get("title") or o.get("payload", {}).get("text") or o.get("payload", {}).get("summary", {}).get("known_issue") or "IT task")[:120]

def typ(o):
    return str(o.get("type") or o.get("case_type") or "it_task")

def status(o):
    return str(o.get("status") or o.get("payload", {}).get("status") or "OPEN")

def tid(o, p):
    return o.get("double_sha") or sha(str(p) + json.dumps(o, ensure_ascii=False, sort_keys=True))

def tasks():
    out, seen = [], set()
    for pat in PATTERNS:
        for p in ROOT.glob(pat):
            if "private" in str(p):
                continue
            o = load(p)
            if not isinstance(o, dict):
                continue
            i = tid(o, p)
            if i in seen:
                continue
            seen.add(i)
            out.append({
                "id": i,
                "short": i[:12],
                "path": str(p.relative_to(ROOT)),
                "title": title(o),
                "type": typ(o),
                "status": status(o),
                "obj": o,
                "mtime": p.stat().st_mtime
            })
    return sorted(out, key=lambda x: x["mtime"], reverse=True)

def find(x):
    ts = tasks()
    if not x:
        return None
    if x.isdigit():
        n = int(x) - 1
        if 0 <= n < len(ts):
            return ts[n]
    for t in ts:
        if t["id"].startswith(x) or t["short"] == x or x in t["path"]:
            return t
    return None

def counts():
    ts = tasks()
    print("=== CYBRA IT MENU COUNTS ===")
    print("tasks:", len(ts))
    print("completed:", len(list((ROOT / "data/cybra_it_menu/completed").glob("*.json"))))
    print("queues:")
    for k,v in ROUTES.items():
        print(f"  {k}: {rlen(v)}")

def list_tasks():
    print("=== IT TASKS ===")
    ts = tasks()
    if not ts:
        print("No tasks.")
        return
    for n,t in enumerate(ts[:50], 1):
        print(f"{n}. [{t['status']}] {t['short']} | {t['type']} | {t['title']}")
        print(f"   {t['path']}")

def view(x):
    t = find(x)
    if not t:
        print("Task not found")
        return
    print("ID:", t["id"])
    print("PATH:", t["path"])
    print("STATUS:", t["status"])
    print("TYPE:", t["type"])
    print("TITLE:", t["title"])
    print(json.dumps(t["obj"], ensure_ascii=False, indent=2)[:5000])

def add(text):
    if not text:
        text = input("Task text: ").strip()
    if not text:
        print("Empty")
        return
    o = {
        "topic": text[:160],
        "type": "it_department_task",
        "status": "OPEN",
        "source": "cybra_it_menu",
        "payload": {
            "text": text,
            "workflow": "task -> script -> test -> report -> proof -> task-block",
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False,
            "manual_OWNER_approval_required": True
        },
        "time": time.time()
    }
    o["double_sha"] = dsha(o)
    path = f"data/cybra_it_menu/tasks/it_task_{o['double_sha'][:16]}.json"
    save(path, o)
    print("✅ added")
    print(path)
    print(o["double_sha"])

def send(x, route):
    if route not in ROUTES:
        print("Route not found. Available:", ", ".join(ROUTES))
        return
    t = find(x)
    if not t:
        print("Task not found")
        return
    o = {
        "status": "SENT_INTERNAL",
        "route": route,
        "redis_key": ROUTES[route],
        "task_id": t["id"],
        "task_path": t["path"],
        "task": t["obj"],
        "time": time.time(),
        "safety": {
            "real_payment_now": False,
            "automatic_external_tx": False
        }
    }
    o["double_sha"] = dsha(o)
    rpush(ROUTES[route], o)
    save(f"data/cybra_it_menu/sent/sent_{route}_{o['double_sha'][:16]}.json", o)
    print("✅ sent")
    print("route:", route)
    print("redis:", ROUTES[route])

def rewrite(x, text):
    t = find(x)
    if not t:
        print("Task not found")
        return
    if not text:
        text = input("New text: ").strip()
    o = {
        "status": "REWRITTEN",
        "original_task_id": t["id"],
        "original_path": t["path"],
        "rewritten_text": text,
        "time": time.time()
    }
    o["double_sha"] = dsha(o)
    save(f"data/cybra_it_menu/tasks/rewrite_{o['double_sha'][:16]}.json", o)
    print("✅ rewritten")

def expand(x, text):
    t = find(x)
    if not t:
        print("Task not found")
        return
    if not text:
        text = input("Expansion: ").strip()
    o = {
        "status": "EXPANDED",
        "original_task_id": t["id"],
        "original_path": t["path"],
        "expansion": text,
        "time": time.time()
    }
    o["double_sha"] = dsha(o)
    save(f"data/cybra_it_menu/tasks/expanded_{o['double_sha'][:16]}.json", o)
    print("✅ expanded")

def complete(x):
    t = find(x)
    if not t:
        print("Task not found")
        return
    o = {
        "status": "COMPLETED",
        "original_task_id": t["id"],
        "original_path": t["path"],
        "task": t["obj"],
        "time": time.time()
    }
    o["double_sha"] = dsha(o)
    save(f"data/cybra_it_menu/completed/completed_{o['double_sha'][:16]}.json", o)
    print("✅ completed")

def clean():
    removed = 0
    for p in ROOT.glob("**/__pycache__"):
        try:
            shutil.rmtree(p)
            removed += 1
        except Exception:
            pass
    print("✅ cache cleaned:", removed)

def report():
    ts = tasks()
    obj = {
        "status": "IT_MENU_OK",
        "time": time.time(),
        "tasks": len(ts),
        "queues": {k:rlen(v) for k,v in ROUTES.items()},
        "latest": [{k:t[k] for k in ["short","path","title","type","status"]} for t in ts[:30]],
        "safety": {
            "real_payment_now": False,
            "automatic_SWIFT": False,
            "automatic_external_tx": False
        }
    }
    obj["double_sha"] = dsha(obj)
    save("feeds/cybra_it_menubar_report.json", obj)
    save("data/cybra_it_menu/reports/latest_report.json", obj)

    md = ["# CYBRA IT Menu-Bar Report", "", "Status: IT_MENU_OK", "", f"Tasks: {len(ts)}", "", "## Queues"]
    for k,v in obj["queues"].items():
        md.append(f"{k}: {v}")
    md.append("")
    md.append("## Latest")
    for t in obj["latest"]:
        md.append(f"- {t['short']} | {t['status']} | {t['type']} | {t['title']}")
    md.append("")
    md.append("## Double SHA")
    md.append(obj["double_sha"])
    (ROOT / "posts/cybra_it_menubar_report.md").write_text("\n".join(md), encoding="utf-8")

    with (ROOT / "proofs/cybra_it_menubar.sha256").open("w") as f:
        subprocess.run(["sha256sum", "feeds/cybra_it_menubar_report.json", "posts/cybra_it_menubar_report.md", "data/cybra_it_menu/reports/latest_report.json"], cwd=ROOT, stdout=f)

    print("✅ report generated")
    print("posts/cybra_it_menubar_report.md")

def tester():
    if (ROOT / "cybra_task_test.sh").exists():
        c,o,e = run(["bash", "cybra_task_test.sh", "run"])
        print(o)
        if e: print(e)
    else:
        print("cybra_task_test.sh missing")

def routes():
    print("=== ROUTES ===")
    for k,v in ROUTES.items():
        print(f"{k}: {v}")

def menu():
    while True:
        print("")
        print("╔════════════════════════════════════╗")
        print("║      CYBRA IT DEPARTMENT MENU     ║")
        print("╚════════════════════════════════════╝")
        print("1) Статус / кількість")
        print("2) Список тасків")
        print("3) Відкрити таск")
        print("4) Додати таск")
        print("5) Відправити таск")
        print("6) Переписати таск")
        print("7) Розширити таск")
        print("8) Позначити виконаним")
        print("9) Очистити кеш")
        print("10) Task tester")
        print("11) Report")
        print("12) Routes")
        print("0) Вихід")
        c = input("> ").strip()
        if c == "1": counts()
        elif c == "2": list_tasks()
        elif c == "3": view(input("ID/№: ").strip())
        elif c == "4": add(input("Text: ").strip())
        elif c == "5":
            x = input("ID/№: ").strip()
            routes()
            send(x, input("Route: ").strip())
        elif c == "6": rewrite(input("ID/№: ").strip(), input("New text: ").strip())
        elif c == "7": expand(input("ID/№: ").strip(), input("Expansion: ").strip())
        elif c == "8": complete(input("ID/№: ").strip())
        elif c == "9": clean()
        elif c == "10": tester()
        elif c == "11": report()
        elif c == "12": routes()
        elif c == "0": break
        else: print("Unknown")

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "menu"
    if cmd == "menu": menu()
    elif cmd == "counts": counts()
    elif cmd == "list": list_tasks()
    elif cmd == "view": view(sys.argv[2] if len(sys.argv)>2 else "")
    elif cmd == "add": add(" ".join(sys.argv[2:]))
    elif cmd == "send": send(sys.argv[2] if len(sys.argv)>2 else "", sys.argv[3] if len(sys.argv)>3 else "")
    elif cmd == "rewrite": rewrite(sys.argv[2] if len(sys.argv)>2 else "", " ".join(sys.argv[3:]))
    elif cmd == "expand": expand(sys.argv[2] if len(sys.argv)>2 else "", " ".join(sys.argv[3:]))
    elif cmd == "complete": complete(sys.argv[2] if len(sys.argv)>2 else "")
    elif cmd == "clean": clean()
    elif cmd == "tester": tester()
    elif cmd == "routes": routes()
    elif cmd == "report": report()
    else:
        print("Commands: menu counts list view add send rewrite expand complete clean tester routes report")

if __name__ == "__main__":
    main()
