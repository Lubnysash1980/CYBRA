#!/usr/bin/env python3
import json, time, uuid, hashlib, subprocess, urllib.request
from pathlib import Path

ROOT = Path.home() / "CYBRA"
BASE = ROOT / "data/cybra_mgs"
TASKS = BASE / "tasks"
REPORTS = BASE / "reports"
METRICS = BASE / "metrics"
EVOLUTION = BASE / "evolution"
POSTS = ROOT / "posts"
FEEDS = ROOT / "feeds"
PROOFS = ROOT / "proofs"
DASH = ROOT / "dashboard/mgs"

for p in [TASKS, REPORTS, METRICS, EVOLUTION, POSTS, FEEDS, PROOFS, DASH]:
    p.mkdir(parents=True, exist_ok=True)

COMMITTEES = [
    "mgs_analytics",
    "mgs_workers",
    "mgs_it_department",
    "mgs_restart_watchdog",
    "mgs_integration"
]

QUEUES = {
    "ai": "ai_block_inbox",
    "parliament": "parliament_inbox",
    "it": "it_department",
    "codespace": "cybra_codespace_inbox",
    "mgs": "cybra_mgs_all"
}

SAFETY = {
    "real_trading_now": False,
    "live_force_trading_disabled": True,
    "binance_real_orders": False,
    "bybit_real_orders": False,
    "automatic_external_tx": False,
    "manual_OWNER_approval_required": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def sh(cmd):
    return subprocess.run(cmd, shell=True, cwd=ROOT, text=True, capture_output=True)

def read_json(path, default):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default

def write_json(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def redis_len(q):
    r = sh(f"redis-cli LLEN {q} 2>/dev/null || echo 0")
    v = r.stdout.strip()
    return int(v) if v.isdigit() else 0

def redis_push(q, payload):
    raw = json.dumps(payload, ensure_ascii=False)
    sh(f"redis-cli LPUSH {q} {json.dumps(raw)} >/dev/null 2>&1 || true")

def public_price(url, key_path):
    try:
        with urllib.request.urlopen(url, timeout=4) as r:
            data = json.loads(r.read().decode())
        x = data
        for k in key_path:
            x = x[k] if isinstance(k, int) else x.get(k)
        return float(x)
    except Exception:
        return None

def market_prices():
    binance = public_price(
        "https://fapi.binance.com/fapi/v1/ticker/price?symbol=DOGEUSDT",
        ["price"]
    )
    bybit = public_price(
        "https://api.bybit.com/v5/market/tickers?category=linear&symbol=DOGEUSDT",
        ["result", "list", 0, "lastPrice"]
    )
    return {
        "timestamp": now(),
        "symbol": "DOGEUSDT",
        "binance_public_price": binance,
        "bybit_public_price": bybit,
        "mode": "PUBLIC_DATA_ONLY_NO_REAL_ORDERS"
    }

def task(target, title, body):
    task_id = f"MGS-{int(time.time())}-{uuid.uuid4().hex[:8]}"
    routes = list(QUEUES.keys()) if target == "all" else [target]
    payload = {
        "task_id": task_id,
        "timestamp": now(),
        "title": title,
        "body": body,
        "target": target,
        "routes": routes,
        "committees": COMMITTEES,
        "evolution_rule": "do_not_break_existing_system; patch_as_layer; preserve_module64; preserve_original_6000_lines",
        "status": "QUEUED_FOR_TERMUX_GITHUB_CODESPACE",
        "safety": SAFETY
    }

    write_json(TASKS / f"{task_id}.json", payload)

    for c in COMMITTEES:
        d = BASE / "committees" / c
        d.mkdir(parents=True, exist_ok=True)
        write_json(d / f"{task_id}.json", payload)

    for r in routes:
        q = QUEUES.get(r)
        if q:
            redis_push(q, payload)

    update()
    print(json.dumps(payload, ensure_ascii=False, indent=2))

def compute_evolution(module64_ok, codespace_reports, task_count):
    hist_file = EVOLUTION / "history.json"
    hist = read_json(hist_file, [])
    base = 84.73
    score = base
    if module64_ok:
        score += 3.0
    if codespace_reports > 0:
        score += 2.0
    if task_count > 0:
        score += min(5.0, task_count * 0.25)
    score = round(min(100.0, score), 2)

    point = {
        "timestamp": now(),
        "score": score,
        "module64_ok": module64_ok,
        "codespace_reports": codespace_reports,
        "task_count": task_count
    }
    hist.append(point)
    hist = hist[-120:]
    write_json(hist_file, hist)
    return score, hist

def update():
    module64_ok = (ROOT / "trading_bot/v64/modules/64").exists()
    original_ok = (ROOT / "trading_bot/v64/models/original_full_bot_6000_latest.mjs").exists()
    codespace_reports = len(list((BASE / "codespace").glob("*_result.json")))
    task_count = len(list(TASKS.glob("*.json")))
    queues = {q: redis_len(q) for q in QUEUES.values()}
    prices = market_prices()
    score, history = compute_evolution(module64_ok, codespace_reports, task_count)

    metrics = {
        "timestamp": now(),
        "status": "LIVE_CONTROL_CENTER_OK",
        "ecosystem": "MGS_SCRIPT_ECOSYSTEM",
        "termux_role": "CONTROL_BAR_ONLY",
        "codespace_role": "EXECUTOR_WORKER",
        "github_role": "SYNC_AND_AUDIT",
        "committees": COMMITTEES,
        "queues": queues,
        "tasks_total": task_count,
        "codespace_reports": codespace_reports,
        "module64_ok": module64_ok,
        "original_6000_lines_ok": original_ok,
        "evolution_score_percent": score,
        "market": prices,
        "safety": SAFETY
    }

    write_json(METRICS / "live_metrics.json", metrics)
    write_json(FEEDS / "cybra_mgs_live_metrics.json", metrics)
    write_json(FEEDS / "cybra_mgs_evolution_history.json", history)

    md = POSTS / "cybra_mgs_live_status.md"
    md.write_text(
        "# CYBRA MGS Live Control Center\n\n"
        f"Timestamp: {metrics['timestamp']}\n\n"
        f"Status: **{metrics['status']}**\n\n"
        f"Evolution: **{score}%**\n\n"
        f"Module 64 OK: `{module64_ok}`\n\n"
        f"Original 6000-line bot OK: `{original_ok}`\n\n"
        f"Tasks total: `{task_count}`\n\n"
        f"Codespace reports: `{codespace_reports}`\n\n"
        "## Safety\n"
        "- real_trading_now: false\n"
        "- binance_real_orders: false\n"
        "- bybit_real_orders: false\n"
        "- automatic_external_tx: false\n"
        "- manual_OWNER_approval_required: true\n",
        encoding="utf-8"
    )

    proof = PROOFS / "cybra_mgs_live.sha256"
    proof.write_text(
        f"{sha(METRICS / 'live_metrics.json')}  data/cybra_mgs/metrics/live_metrics.json\n"
        f"{sha(FEEDS / 'cybra_mgs_live_metrics.json')}  feeds/cybra_mgs_live_metrics.json\n"
        f"{sha(md)}  posts/cybra_mgs_live_status.md\n",
        encoding="utf-8"
    )

    build_dashboard(metrics, history)
    return metrics

def build_dashboard(metrics, history):
    html = DASH / "index.html"
    h_scores = [p.get("score", 0) for p in history[-30:]]
    h_labels = [p.get("timestamp", "")[-8:] for p in history[-30:]]

    html.write_text(f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CYBRA MGS Live</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
body {{ font-family: Arial, sans-serif; background:#080b12; color:#e8f0ff; margin:0; }}
header {{ padding:14px; background:#111827; position:sticky; top:0; z-index:2; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:12px; padding:12px; }}
.card {{ background:#111827; border:1px solid #263247; border-radius:14px; padding:14px; }}
.big {{ font-size:32px; font-weight:bold; }}
.ok {{ color:#6ee7b7; }}
.warn {{ color:#fbbf24; }}
.bad {{ color:#fb7185; }}
button {{ background:#1f6feb; color:white; border:0; padding:10px 12px; border-radius:10px; margin:4px; }}
pre {{ white-space:pre-wrap; font-size:12px; }}
</style>
</head>
<body>
<header>
  <b>CYBRA MGS Live Control Center</b><br>
  Termux Control → GitHub Sync → Codespace Executor → AI + IT + Cyber Parliament
</header>

<div class="grid">
  <div class="card">
    <div>Evolution</div>
    <div class="big ok">{metrics['evolution_score_percent']}%</div>
    <small>daily evolution score</small>
  </div>
  <div class="card">
    <div>Tasks</div>
    <div class="big">{metrics['tasks_total']}</div>
    <small>MGS queued tasks</small>
  </div>
  <div class="card">
    <div>Codespace reports</div>
    <div class="big">{metrics['codespace_reports']}</div>
    <small>executor output</small>
  </div>
  <div class="card">
    <div>Module 64</div>
    <div class="big {'ok' if metrics['module64_ok'] else 'bad'}">{'OK' if metrics['module64_ok'] else 'MISSING'}</div>
    <small>v64 preserved</small>
  </div>
  <div class="card">
    <div>Binance DOGEUSDT</div>
    <div class="big">{metrics['market'].get('binance_public_price')}</div>
    <small>public data only</small>
  </div>
  <div class="card">
    <div>Bybit DOGEUSDT</div>
    <div class="big">{metrics['market'].get('bybit_public_price')}</div>
    <small>public data only</small>
  </div>
</div>

<div class="grid">
  <div class="card">
    <h3>Evolution curve</h3>
    <canvas id="evo"></canvas>
  </div>
  <div class="card">
    <h3>Queues</h3>
    <canvas id="queues"></canvas>
  </div>
</div>

<div class="grid">
  <div class="card">
    <h3>5 Committees</h3>
    <ol>
      <li>MGS Analytics</li>
      <li>MGS Workers</li>
      <li>MGS IT Department</li>
      <li>MGS Restart Watchdog</li>
      <li>MGS Integration</li>
    </ol>
  </div>
  <div class="card">
    <h3>Safety</h3>
    <pre>{json.dumps(metrics['safety'], ensure_ascii=False, indent=2)}</pre>
  </div>
</div>

<script>
new Chart(document.getElementById('evo'), {{
  type: 'line',
  data: {{
    labels: {json.dumps(h_labels, ensure_ascii=False)},
    datasets: [{{ label: 'Evolution %', data: {json.dumps(h_scores)}, tension: 0.25 }}]
  }},
  options: {{ responsive:true, scales: {{ y: {{ min:80, max:100 }} }} }}
}});

new Chart(document.getElementById('queues'), {{
  type: 'bar',
  data: {{
    labels: {json.dumps(list(metrics['queues'].keys()), ensure_ascii=False)},
    datasets: [{{ label: 'Queue length', data: {json.dumps(list(metrics['queues'].values()))} }}]
  }},
  options: {{ responsive:true }}
}});

setTimeout(() => location.reload(), 15000);
</script>
</body>
</html>
""", encoding="utf-8")

def serve():
    update()
    print("Open in Android browser: http://127.0.0.1:8765/dashboard/mgs/")
    subprocess.call("python3 -m http.server 8765", shell=True, cwd=ROOT)

def clip(title):
    r = sh("termux-clipboard-get 2>/dev/null || true")
    body = r.stdout.strip()
    if not body:
        print("Clipboard empty або termux-api не встановлено")
        return
    task("all", title, body)

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "status":
        print(json.dumps(update(), ensure_ascii=False, indent=2))
    elif cmd == "task":
        target = sys.argv[2] if len(sys.argv) > 2 else "all"
        title = sys.argv[3] if len(sys.argv) > 3 else "MGS task"
        body = " ".join(sys.argv[4:]) if len(sys.argv) > 4 else title
        task(target, title, body)
    elif cmd == "clip":
        title = sys.argv[2] if len(sys.argv) > 2 else "Clipboard task"
        clip(title)
    elif cmd == "serve":
        serve()
    else:
        print("commands: status | task all 'title' 'body' | clip 'title' | serve")
