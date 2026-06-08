#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== INSTALL CYBRA OPS BAR / STRUCTURE MENU ==="

mkdir -p \
  scripts/ops \
  data/cybra_ops_bar/reports \
  data/cybra_ops_bar/snapshots \
  posts feeds proofs dashboard/cybra_ops_bar logs/ops runtime/redis

cat > scripts/ops/cybra_ops_bar.py <<'PY'
#!/usr/bin/env python3
import os, sys, json, time, hashlib, subprocess
from pathlib import Path
from datetime import datetime

ROOT = Path.home() / "CYBRA"

QUEUES = [
    "cybra:meta:evolution:pool",
    "cybra:kibra:pool:mining_blocks",
    "cybra:ai:tasks:block_inbox",
    "cybra:finance:evolution:pool",
    "cybra:completed:ai_tasks",
    "cybra:return:ai_tasks",
    "ai_block_inbox",
    "cybra_mgs_all",
    "cybra_oracle_tasks",
    "it_department",
    "parliament_inbox",
    "cybra_coin_approval",
    "cybra_mainnet_approval"
]

PROCESS_KEYWORDS = [
    "cybra",
    "kibra",
    "redis",
    "uvicorn",
    "python",
    "node",
    "pm2"
]

SAFETY = {
    "real_payment_now": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def run(cmd, timeout=12):
    try:
        r = subprocess.run(
            cmd,
            shell=True,
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=timeout
        )
        return {
            "ok": r.returncode == 0,
            "returncode": r.returncode,
            "stdout": r.stdout.strip(),
            "stderr": r.stderr.strip()
        }
    except Exception as e:
        return {
            "ok": False,
            "returncode": 999,
            "stdout": "",
            "stderr": str(e)
        }

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")

def sha_file(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def exists(path):
    return (ROOT / path).exists()

def count_files(path, pattern="*"):
    p = ROOT / path
    if not p.exists():
        return 0
    return len(list(p.rglob(pattern)))

def count_direct(path):
    p = ROOT / path
    if not p.exists():
        return 0
    return len([x for x in p.iterdir()])

def mtime_age_seconds(path):
    p = ROOT / path
    if not p.exists():
        return None
    return int(time.time() - p.stat().st_mtime)

def bool_icon(v):
    return "✅" if v else "❌"

def redis_status():
    ping = run("redis-cli ping", timeout=3)
    online = ping["ok"] and "PONG" in ping["stdout"]

    queues = {}
    for q in QUEUES:
        if online:
            r = run(f"redis-cli LLEN '{q}'", timeout=3)
            try:
                n = int(r["stdout"].strip())
            except Exception:
                n = 0
        else:
            n = None
        queues[q] = n

    return {
        "online": online,
        "queues": queues
    }

def git_status():
    branch = run("git branch --show-current")
    last = run("git log --oneline -1")
    status = run("git status --porcelain")
    remote = run("git remote -v")

    changed = [x for x in status["stdout"].splitlines() if x.strip()]
    untracked = [x for x in changed if x.startswith("??")]
    modified = [x for x in changed if not x.startswith("??")]

    return {
        "branch": branch["stdout"] or "UNKNOWN",
        "last_commit": last["stdout"] or "NO_COMMIT",
        "changed_count": len(changed),
        "untracked_count": len(untracked),
        "modified_count": len(modified),
        "remote": remote["stdout"].splitlines()[:3],
        "clean": len(changed) == 0
    }

def process_status():
    ps = run("ps -ef", timeout=5)
    if not ps["ok"] or not ps["stdout"]:
        ps = run("ps -A", timeout=5)

    lines = ps["stdout"].splitlines()
    matched = []
    for line in lines:
        low = line.lower()
        if any(k in low for k in PROCESS_KEYWORDS):
            if "cybra_ops_bar.py" not in low:
                matched.append(line)

    return {
        "process_lines_count": len(lines),
        "matched_processes_count": len(matched),
        "matched_processes": matched[:80]
    }

def proof_status():
    proof_dir = ROOT / "proofs"
    proofs = []
    ok_count = 0
    fail_count = 0

    if proof_dir.exists():
        for p in sorted(proof_dir.glob("*.sha256")):
            r = run(f"sha256sum -c '{p.relative_to(ROOT)}'", timeout=8)
            ok = r["ok"]
            if ok:
                ok_count += 1
            else:
                fail_count += 1
            proofs.append({
                "file": str(p.relative_to(ROOT)),
                "ok": ok,
                "stdout_tail": r["stdout"][-500:],
                "stderr_tail": r["stderr"][-500:]
            })

    return {
        "proofs_count": len(proofs),
        "ok_count": ok_count,
        "fail_count": fail_count,
        "proofs": proofs
    }

def committee_status():
    dirs = []

    for base in [
        ROOT / "data/cybra_it_department",
        ROOT / "parliament/committees",
        ROOT / "data/cybra_meta_evolution/tasks",
        ROOT / "data/cybra_meta_evolution/handlers",
        ROOT / "data/cybra_meta_evolution/schedules"
    ]:
        if base.exists():
            for d in sorted(base.iterdir()):
                if d.is_dir():
                    dirs.append(str(d.relative_to(ROOT)))

    return {
        "committees_count": len(dirs),
        "committees": dirs
    }

def structure_status():
    return {
        "files_total_rough": count_files(".", "*"),
        "scripts_py": count_files("scripts", "*.py"),
        "scripts_sh": count_files(".", "*.sh"),
        "json_files": count_files(".", "*.json"),
        "proof_files": count_files("proofs", "*.sha256"),
        "dashboard_files": count_files("dashboard", "*.html"),

        "meta_tasks": count_files("data/cybra_meta_evolution/tasks", "*.json"),
        "meta_modules": count_files("data/cybra_meta_evolution/modules", "*.json"),
        "meta_blocks": count_files("data/cybra_meta_evolution/blocks", "*.json"),
        "meta_routes": count_files("data/cybra_meta_evolution/queues", "*.json"),
        "meta_repairs": count_files("data/cybra_meta_evolution/repair", "*.json"),
        "meta_completed": count_files("data/cybra_meta_evolution/completed", "*.json"),
        "meta_returned": count_files("data/cybra_meta_evolution/returned", "*.json"),

        "kibra_blocks": count_files("blockchain/kibra_chain/mainnet/blocks", "*.json"),
        "kibra_task_blocks": count_files("blockchain/kibra_chain/task_blocks", "*.json"),
        "kibra_meta_blocks": count_files("blockchain/kibra_chain/meta_evolution_blocks", "*.json"),

        "binary_blobs": count_files("build/cybra_binary_safe/blobs", "*.gz"),
        "python_bytecode": count_files("build/cybra_binary_safe/python_bytecode", "*.pyc"),
        "library_manifests": count_files("build/cybra_binary_safe/library_manifests", "*.json")
    }

def latest_reports():
    return {
        "meta_evolution": read_json(ROOT / "data/cybra_meta_evolution/reports/meta_evolution_cycle_latest.json", {}),
        "token_check": read_json(ROOT / "data/cybra_token/checks/kibra_token_check_latest.json", {}),
        "kibra_state": read_json(ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json", {}),
        "structure_fix": read_json(ROOT / "data/cybra_structure_autocollector/final_system_fix_latest.json", {}),
        "smoke_test": read_json(ROOT / "data/cybra_structure_autocollector/tests/structure_binary_proof_smoke_test_latest.json", {}),
        "proof_department": read_json(ROOT / "data/cybra_proof_department/reports/proof_department_latest.json", {}),
        "binary_report": read_json(ROOT / "data/cybra_binary_safe/binary_rewrite_report_latest.json", {})
    }

def analytics_find_stuck(report):
    problems = []
    fixes = []

    redis = report["redis"]
    proofs = report["proofs"]
    git = report["git"]
    proc = report["processes"]
    structure = report["structure"]
    latest = report["latest"]

    if not redis["online"]:
        problems.append("Redis offline")
        fixes.append("Start Redis: redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no")

    if proofs["fail_count"] > 0:
        problems.append(f"Proof failures: {proofs['fail_count']}")
        fixes.append("Rebuild stale proofs: cybra-structure-fix all && cybra-structure-fix proof")

    if git["changed_count"] > 0:
        problems.append(f"Git has uncommitted changes: {git['changed_count']}")
        fixes.append("Review: git status --short")

    if proc["matched_processes_count"] == 0:
        problems.append("No CYBRA/KIBRA background processes detected")
        fixes.append("Run needed services manually: cybra-meta-evo cycle / cybra-kibra-real api / cybra-structure-fix all")

    if structure["meta_blocks"] == 0:
        problems.append("No meta evolution blocks")
        fixes.append("Run: cybra-meta-evo cycle")

    if structure["binary_blobs"] == 0:
        problems.append("No binary-safe blobs")
        fixes.append("Run: cybra-structure-fix binary")

    if structure["kibra_blocks"] == 0:
        problems.append("No KIBRA mainnet blocks")
        fixes.append("Run: cybra-kibra-real mine && cybra-kibra-real validate")

    if latest["token_check"].get("status") not in ("KIBRA_TOKEN_CHECK_PASS", None):
        problems.append("Token check is partial or failing")
        fixes.append("Run: bash check_kibra_token.sh")

    queues = redis["queues"]
    if redis["online"]:
        for q, n in queues.items():
            if isinstance(n, int) and n > 100:
                problems.append(f"Queue too large: {q}={n}")
                fixes.append(f"Process queue or scale workers for: {q}")

    ages = {
        "meta_evolution_report_age_sec": mtime_age_seconds("data/cybra_meta_evolution/reports/meta_evolution_cycle_latest.json"),
        "structure_report_age_sec": mtime_age_seconds("data/cybra_structure_autocollector/final_system_fix_latest.json"),
        "token_check_age_sec": mtime_age_seconds("data/cybra_token/checks/kibra_token_check_latest.json")
    }

    for k, age in ages.items():
        if age is not None and age > 86400:
            problems.append(f"Old report: {k}={age}s")
            fixes.append("Refresh reports: cybra-ops-bar repair")

    return {
        "problems_count": len(problems),
        "problems": problems,
        "fixes": fixes,
        "ages": ages
    }

def full_report():
    report = {
        "timestamp": now(),
        "status": "CYBRA_OPS_BAR_REPORT",
        "structure": structure_status(),
        "redis": redis_status(),
        "git": git_status(),
        "processes": process_status(),
        "proofs": proof_status(),
        "committees": committee_status(),
        "latest": latest_reports(),
        "safety": SAFETY
    }
    report["analytics"] = analytics_find_stuck(report)

    write_json(ROOT / "data/cybra_ops_bar/reports/ops_bar_latest.json", report)
    write_json(ROOT / "feeds/cybra_ops_bar.json", report)

    md = make_markdown(report)
    write_text(ROOT / "posts/cybra_ops_bar.md", md)

    html = make_html(report)
    write_text(ROOT / "dashboard/cybra_ops_bar/index.html", html)

    targets = [
        ROOT / "data/cybra_ops_bar/reports/ops_bar_latest.json",
        ROOT / "feeds/cybra_ops_bar.json",
        ROOT / "posts/cybra_ops_bar.md",
        ROOT / "dashboard/cybra_ops_bar/index.html",
        ROOT / "scripts/ops/cybra_ops_bar.py"
    ]

    lines = []
    for p in targets:
        if p.exists():
            lines.append(f"{sha_file(p)}  {p.relative_to(ROOT)}\n")
    write_text(ROOT / "proofs/cybra_ops_bar.sha256", "".join(lines))

    return report

def make_markdown(r):
    s = r["structure"]
    redis = r["redis"]
    git = r["git"]
    proofs = r["proofs"]
    committees = r["committees"]
    a = r["analytics"]
    latest = r["latest"]

    lines = [
        "# CYBRA Ops Bar",
        "",
        f"Timestamp: `{r['timestamp']}`",
        "",
        "## Main numbers",
        "",
        f"- Meta tasks: `{s['meta_tasks']}`",
        f"- Meta modules: `{s['meta_modules']}`",
        f"- Meta AI blocks: `{s['meta_blocks']}`",
        f"- Meta routes: `{s['meta_routes']}`",
        f"- Broken repairs: `{s['meta_repairs']}`",
        f"- Completed tasks: `{s['meta_completed']}`",
        f"- Returned tasks: `{s['meta_returned']}`",
        f"- KIBRA mainnet blocks: `{s['kibra_blocks']}`",
        f"- KIBRA task blocks: `{s['kibra_task_blocks']}`",
        f"- Binary blobs: `{s['binary_blobs']}`",
        f"- Python bytecode: `{s['python_bytecode']}`",
        f"- Library manifests: `{s['library_manifests']}`",
        f"- Committees/branches: `{committees['committees_count']}`",
        "",
        "## Redis queues",
        "",
        f"- Redis online: `{redis['online']}`"
    ]

    for q, n in redis["queues"].items():
        lines.append(f"- {q}: `{n}`")

    lines += [
        "",
        "## Git",
        "",
        f"- Branch: `{git['branch']}`",
        f"- Last commit: `{git['last_commit']}`",
        f"- Clean: `{git['clean']}`",
        f"- Changed: `{git['changed_count']}`",
        f"- Untracked: `{git['untracked_count']}`",
        "",
        "## Proofs",
        "",
        f"- Proofs: `{proofs['proofs_count']}`",
        f"- OK: `{proofs['ok_count']}`",
        f"- FAIL: `{proofs['fail_count']}`",
        "",
        "## KIBRA",
        "",
        f"- Network: `{latest['kibra_state'].get('network')}`",
        f"- Chain ID: `{latest['kibra_state'].get('chain_id')}`",
        f"- Latest height: `{latest['kibra_state'].get('latest_height')}`",
        f"- External live: `{latest['kibra_state'].get('external_live')}`",
        "",
        "## Token",
        "",
        f"- Token check: `{latest['token_check'].get('status')}`",
        f"- Token score: `{latest['token_check'].get('score_percent')}`",
        f"- Wallet: `{latest['token_check'].get('wallet')}`",
        "",
        "## Meta evolution",
        "",
        f"- Status: `{latest['meta_evolution'].get('status')}`",
        f"- Finance tasks discovered: `{latest['meta_evolution'].get('tasks_discovered')}`",
        f"- Ecosystems created: `{latest['meta_evolution'].get('ecosystems_created')}`",
        f"- Layers created: `{latest['meta_evolution'].get('layers_created')}`",
        f"- AI blocks routed: `{latest['meta_evolution'].get('ai_blocks_routed')}`",
        "",
        "## Analytics / what to fix",
        "",
        f"- Problems count: `{a['problems_count']}`"
    ]

    for p in a["problems"]:
        lines.append(f"- Problem: `{p}`")

    for f in a["fixes"]:
        lines.append(f"- Fix: `{f}`")

    lines += [
        "",
        "## Committees / branches",
        ""
    ]

    for c in committees["committees"][:120]:
        lines.append(f"- `{c}`")

    lines += [
        "",
        "## Safety",
        "",
        "- real_payment_now: false",
        "- automatic_external_tx: false",
        "-automatic_withdrawals: false",
        "- automatic_SWIFT: false",
        "- automatic_real_rewards: false",
        "- external_bridge_enabled: false",
        ""
    ]

    return "\n".join(lines)

def make_html(r):
    s = r["structure"]
    a = r["analytics"]
    latest = r["latest"]
    git = r["git"]
    proofs = r["proofs"]
    redis = r["redis"]

    problems_html = "".join(f"<li><code>{p}</code></li>" for p in a["problems"])
    fixes_html = "".join(f"<li><code>{f}</code></li>" for f in a["fixes"])

    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CYBRA Ops Bar</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 1100px; margin: 35px auto; padding: 20px; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 14px; }}
.card {{ border: 1px solid #ddd; border-radius: 16px; padding: 16px; }}
code {{ word-break: break-all; }}
.ok {{ font-weight: 700; }}
</style>
</head>
<body>
<h1>CYBRA Ops Bar</h1>
<p>Timestamp: <code>{r["timestamp"]}</code></p>

<div class="grid">
<div class="card"><b>Meta tasks</b><br><code>{s["meta_tasks"]}</code></div>
<div class="card"><b>Meta modules</b><br><code>{s["meta_modules"]}</code></div>
<div class="card"><b>AI blocks</b><br><code>{s["meta_blocks"]}</code></div>
<div class="card"><b>Routes</b><br><code>{s["meta_routes"]}</code></div>
<div class="card"><b>Repairs</b><br><code>{s["meta_repairs"]}</code></div>
<div class="card"><b>Completed</b><br><code>{s["meta_completed"]}</code></div>
<div class="card"><b>Returned</b><br><code>{s["meta_returned"]}</code></div>
<div class="card"><b>KIBRA blocks</b><br><code>{s["kibra_blocks"]}</code></div>
<div class="card"><b>Binary blobs</b><br><code>{s["binary_blobs"]}</code></div>
<div class="card"><b>Proof OK / FAIL</b><br><code>{proofs["ok_count"]} / {proofs["fail_count"]}</code></div>
<div class="card"><b>Problems</b><br><code>{a["problems_count"]}</code></div>
<div class="card"><b>Redis</b><br><code>{redis["online"]}</code></div>
</div>

<h2>Git</h2>
<p>Branch: <code>{git["branch"]}</code></p>
<p>Last commit: <code>{git["last_commit"]}</code></p>
<p>Changed: <code>{git["changed_count"]}</code></p>

<h2>KIBRA</h2>
<p>Network: <code>{latest["kibra_state"].get("network")}</code></p>
<p>Chain ID: <code>{latest["kibra_state"].get("chain_id")}</code></p>
<p>Height: <code>{latest["kibra_state"].get("latest_height")}</code></p>
<p>External live: <code>{latest["kibra_state"].get("external_live")}</code></p>

<h2>Meta evolution</h2>
<p>Status: <code>{latest["meta_evolution"].get("status")}</code></p>
<p>Tasks discovered: <code>{latest["meta_evolution"].get("tasks_discovered")}</code></p>
<p>Ecosystems: <code>{latest["meta_evolution"].get("ecosystems_created")}</code></p>
<p>Layers: <code>{latest["meta_evolution"].get("layers_created")}</code></p>
<p>AI blocks routed: <code>{latest["meta_evolution"].get("ai_blocks_routed")}</code></p>

<h2>Analytics / what to fix</h2>
<ul>{problems_html}</ul>

<h2>Fix commands</h2>
<ul>{fixes_html}</ul>

<h2>Safety</h2>
<p>No withdrawals. No SWIFT. No automatic external transactions. No automatic real rewards.</p>
</body>
</html>
"""

def print_overview(r):
    s = r["structure"]
    a = r["analytics"]
    latest = r["latest"]
    redis = r["redis"]
    git = r["git"]
    proofs = r["proofs"]

    print("")
    print("===== CYBRA OPS BAR =====")
    print(f"Meta tasks:        {s['meta_tasks']}")
    print(f"Meta modules:      {s['meta_modules']}")
    print(f"AI blocks:         {s['meta_blocks']}")
    print(f"Routes:            {s['meta_routes']}")
    print(f"Repairs:           {s['meta_repairs']}")
    print(f"Completed:         {s['meta_completed']}")
    print(f"Returned:          {s['meta_returned']}")
    print(f"KIBRA blocks:      {s['kibra_blocks']}")
    print(f"Task blocks:       {s['kibra_task_blocks']}")
    print(f"Binary blobs:      {s['binary_blobs']}")
    print(f"Python bytecode:   {s['python_bytecode']}")
    print(f"Committees:        {r['committees']['committees_count']}")
    print(f"Redis online:      {redis['online']}")
    print(f"Git branch:        {git['branch']}")
    print(f"Git changed:       {git['changed_count']}")
    print(f"Proof OK/FAIL:     {proofs['ok_count']}/{proofs['fail_count']}")
    print(f"KIBRA height:      {latest['kibra_state'].get('latest_height')}")
    print(f"Token status:      {latest['token_check'].get('status')}")
    print(f"Meta status:       {latest['meta_evolution'].get('status')}")
    print(f"Problems:          {a['problems_count']}")
    print("=========================")
    print("")

    if a["problems"]:
        print("ЩО ПОПРАВИТИ:")
        for x in a["problems"]:
            print(f" - {x}")
        print("")
        print("КОМАНДИ FIX:")
        for x in a["fixes"]:
            print(f" - {x}")
        print("")

def menu():
    while True:
        r = full_report()
        print_overview(r)
        print("Меню:")
        print("  1) Overview / цифри")
        print("  2) Redis черги")
        print("  3) Процеси")
        print("  4) Комітети / гілки")
        print("  5) Proof status")
        print("  6) Meta evolution status")
        print("  7) Запустити meta evolution cycle")
        print("  8) Повернути задачу на доопрацювання")
        print("  9) Позначити задачу виконаною")
        print(" 10) Запустити token check")
        print(" 11) Запустити structure smoke-test")
        print(" 12) Показати що поправити")
        print(" 13) Dashboard локально")
        print("  q) Вихід")
        ch = input("cybra> ").strip()

        if ch == "1":
            print_overview(full_report())
        elif ch == "2":
            print(json.dumps(full_report()["redis"], ensure_ascii=False, indent=2))
        elif ch == "3":
            print(json.dumps(full_report()["processes"], ensure_ascii=False, indent=2))
        elif ch == "4":
            print(json.dumps(full_report()["committees"], ensure_ascii=False, indent=2))
        elif ch == "5":
            print(json.dumps(full_report()["proofs"], ensure_ascii=False, indent=2))
        elif ch == "6":
            p = ROOT / "posts/cybra_meta_evolution_cycle.md"
            print(p.read_text(encoding="utf-8") if p.exists() else "No meta report")
        elif ch == "7":
            os.system("cybra-meta-evo cycle")
        elif ch == "8":
            os.system("cybra-meta-evo return")
        elif ch == "9":
            os.system("cybra-meta-evo done")
        elif ch == "10":
            os.system("bash check_kibra_token.sh")
        elif ch == "11":
            os.system("bash test_cybra_structure_binary_proof_system.sh")
        elif ch == "12":
            print(json.dumps(full_report()["analytics"], ensure_ascii=False, indent=2))
        elif ch == "13":
            print("Open: http://127.0.0.1:8795/")
            os.system("python3 -m http.server 8795 --bind 127.0.0.1 --directory dashboard/cybra_ops_bar")
        elif ch.lower() == "q":
            break
        else:
            print("Unknown")

def status():
    full_report()
    p = ROOT / "posts/cybra_ops_bar.md"
    print(p.read_text(encoding="utf-8"))

def proof():
    full_report()
    os.system("sha256sum -c proofs/cybra_ops_bar.sha256")

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "menu"

    if cmd == "menu":
        menu()
    elif cmd == "report":
        r = full_report()
        print(json.dumps(r, ensure_ascii=False, indent=2))
    elif cmd == "status":
        status()
    elif cmd == "json":
        full_report()
        print((ROOT / "data/cybra_ops_bar/reports/ops_bar_latest.json").read_text(encoding="utf-8"))
    elif cmd == "proof":
        proof()
    elif cmd == "serve":
        full_report()
        print("Open: http://127.0.0.1:8795/")
        os.system("python3 -m http.server 8795 --bind 127.0.0.1 --directory dashboard/cybra_ops_bar")
    elif cmd == "repair":
        os.system("cybra-meta-evo cycle")
        os.system("bash check_kibra_token.sh")
        os.system("bash test_cybra_structure_binary_proof_system.sh")
        full_report()
        status()
    else:
        print("Commands: menu | report | status | json | proof | serve | repair")

if __name__ == "__main__":
    main()
PY

cat > cybra-ops-bar <<'SH'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1
python3 scripts/ops/cybra_ops_bar.py "${1:-menu}"
SH

chmod +x scripts/ops/cybra_ops_bar.py cybra-ops-bar
ln -sf "$HOME/CYBRA/cybra-ops-bar" "$PREFIX/bin/cybra-ops-bar" 2>/dev/null || true

echo "=== RUN FIRST REPORT ==="
cybra-ops-bar report
cybra-ops-bar proof

echo
echo "✅ CYBRA OPS BAR INSTALLED"
echo "Run:"
echo "  cybra-ops-bar"
echo "  cybra-ops-bar status"
echo "  cybra-ops-bar serve"
