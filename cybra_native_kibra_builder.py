#!/usr/bin/env python3
import json, time, hashlib, struct, zlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def latest_status():
    p = ROOT / "feeds/kibra_token_chain_status.json"
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text())
    except Exception:
        return {}

def write_png(path, w=512, h=512):
    # Pure Python PNG: coin circle gradient-like, no external packages.
    rows = []
    cx, cy = w // 2, h // 2
    r = min(w, h) // 2 - 28

    for y in range(h):
        row = bytearray()
        for x in range(w):
            dx, dy = x - cx, y - cy
            dist2 = dx*dx + dy*dy
            if dist2 <= r*r:
                shade = max(0, min(255, 220 - int((abs(dx)+abs(dy)) / 5)))
                rr = 220
                gg = 170 + shade // 6
                bb = 40
                if abs(dx) < 18 and abs(dy) < 120:
                    rr, gg, bb = 40, 40, 40
                if abs(dy) < 18 and -110 < dx < 110:
                    rr, gg, bb = 40, 40, 40
                if r*r - dist2 < 3000:
                    rr, gg, bb = 255, 220, 90
            else:
                rr, gg, bb = 12, 18, 28
            row.extend([rr, gg, bb])
        rows.append(b"\x00" + bytes(row))

    raw = b"".join(rows)

    def chunk(t, data):
        return struct.pack(">I", len(data)) + t + data + struct.pack(">I", zlib.crc32(t + data) & 0xffffffff)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")

    Path(path).write_bytes(png)

def build():
    for d in [
        "token/kibra/native/assets",
        "website/kibra",
        "docs/kibra",
        "posts",
        "feeds",
        "proofs",
        "parliament/native_kibra/tasks"
    ]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    write_png(ROOT / "token/kibra/native/assets/kibra_token.png")
    write_png(ROOT / "token/kibra/native/assets/logo.png")

    policy = json.loads((ROOT / "parliament/native_kibra/policy/native_kibra_policy.json").read_text())
    kstatus = latest_status()

    ai_task = {
        "topic": "Native KIBRA Coin Evolution Package",
        "type": "native_kibra_evolution_task",
        "priority": "critical",
        "payload": {
            "no_external_mint": True,
            "native_coin": True,
            "own_blockchain": True,
            "create_pool_model": True,
            "create_blocks": True,
            "create_difficulty_stream": True,
            "confirm_local_blockchain_by_external_anchor_package": True,
            "auto_create_token_png": True,
            "auto_create_website": True,
            "auto_create_explorer": True,
            "manual_owner_approval_required_for_real_launch": True,
            "real_execution_now": False,
            "departments_required": [
                "finance_department",
                "monetization_department",
                "evolution_deployment",
                "hash_module",
                "revision_organ",
                "analytics_committee",
                "exchange_department",
                "blockchain_confirmation_department"
            ]
        }
    }

    (ROOT / "parliament/native_kibra/tasks/native_kibra_evolution_task.json").write_text(
        json.dumps(ai_task, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    whitepaper = f"""# Native KIBRA Coin

Status: draft / proof package

## Main decision

KIBRA is not SPL/ERC token here.  
KIBRA is planned as native coin of own blockchain.

## Chain

- Local chain: KIBRA_LOCAL_PROOF_CHAIN
- Latest hash: `{latest_hash()}`
- Existing height: `{kstatus.get("chain", {}).get("height")}`
- Difficulty stream: required
- Mining shares: required
- External anchor: manual proof anchor only

## Pool

Pool is created as architecture/proposal.  
Real launch is not executed now.

## Assets

- `token/kibra/native/assets/kibra_token.png`
- `token/kibra/native/assets/logo.png`

## Website

- `website/kibra/index.html`
- `website/kibra/explorer.html`
- `website/kibra/stats.html`
"""

    (ROOT / "docs/kibra/native_kibra_whitepaper.md").write_text(whitepaper, encoding="utf-8")

    index = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Native KIBRA</title>
</head>
<body>
<h1>Native KIBRA Coin</h1>
<img src="../../token/kibra/native/assets/kibra_token.png" width="180">
<p>KIBRA is planned as native coin of CYBRA own blockchain.</p>
<p>Latest chain hash: <code>{latest_hash()}</code></p>
<p>Real launch: manual OWNER approval only.</p>
<ul>
<li><a href="explorer.html">Explorer</a></li>
<li><a href="stats.html">Stats</a></li>
</ul>
</body>
</html>
"""
    explorer = f"""<!doctype html>
<html>
<head><meta charset="utf-8"><title>KIBRA Explorer</title></head>
<body>
<h1>KIBRA Explorer</h1>
<p>Latest hash: <code>{latest_hash()}</code></p>
<p>Height: <code>{kstatus.get("chain", {}).get("height")}</code></p>
<p>Difficulty: <code>{kstatus.get("chain", {}).get("latest_difficulty")}</code></p>
</body>
</html>
"""
    stats = f"""<!doctype html>
<html>
<head><meta charset="utf-8"><title>KIBRA Stats</title></head>
<body>
<h1>KIBRA Stats</h1>
<p>Native coin mode: true</p>
<p>External mint: false</p>
<p>Manual real launch: true</p>
</body>
</html>
"""
    (ROOT / "website/kibra/index.html").write_text(index, encoding="utf-8")
    (ROOT / "website/kibra/explorer.html").write_text(explorer, encoding="utf-8")
    (ROOT / "website/kibra/stats.html").write_text(stats, encoding="utf-8")

    report = {
        "status": "native_kibra_ai_task_package_created",
        "time": time.time(),
        "time_iso": now_iso(),
        "policy": policy,
        "ai_task": ai_task,
        "latest_kibra_hash": latest_hash(),
        "assets": {
            "kibra_token_png": "token/kibra/native/assets/kibra_token.png",
            "logo_png": "token/kibra/native/assets/logo.png"
        },
        "website": {
            "index": "website/kibra/index.html",
            "explorer": "website/kibra/explorer.html",
            "stats": "website/kibra/stats.html"
        },
        "proof_inputs": {
            "policy": file_sha("parliament/native_kibra/policy/native_kibra_policy.json"),
            "ai_task": file_sha("parliament/native_kibra/tasks/native_kibra_evolution_task.json"),
            "png": file_sha("token/kibra/native/assets/kibra_token.png"),
            "logo": file_sha("token/kibra/native/assets/logo.png"),
            "whitepaper": file_sha("docs/kibra/native_kibra_whitepaper.md"),
            "site_index": file_sha("website/kibra/index.html")
        }
    }

    report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/native_kibra_ai_task_package.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    md = f"""# Native KIBRA AI Task Package

Status: created

## Decision

- External SPL/ERC mint: **false**
- Native coin: **true**
- Own blockchain: **true**
- Pool model: **created as proposal**
- Blocks: **existing / growing**
- Difficulty stream: **required**
- Token PNG: **created**
- Website: **created**
- Real launch now: **false**
- Manual OWNER approval required: **true**

## Latest chain

Latest KIBRA hash:

`{latest_hash()}`

## AI task

`parliament/native_kibra/tasks/native_kibra_evolution_task.json`

## Assets

- `token/kibra/native/assets/kibra_token.png`
- `token/kibra/native/assets/logo.png`

## Website

- `website/kibra/index.html`
- `website/kibra/explorer.html`
- `website/kibra/stats.html`

## Proof

Double SHA:

`{report["double_sha"]}`
"""
    (ROOT / "posts/native_kibra_ai_task_package.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/native_kibra_ai_task_package.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/native_kibra/policy/native_kibra_policy.json",
            "parliament/native_kibra/tasks/native_kibra_evolution_task.json",
            "token/kibra/native/assets/kibra_token.png",
            "token/kibra/native/assets/logo.png",
            "docs/kibra/native_kibra_whitepaper.md",
            "website/kibra/index.html",
            "website/kibra/explorer.html",
            "website/kibra/stats.html",
            "feeds/native_kibra_ai_task_package.json",
            "posts/native_kibra_ai_task_package.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    print("✅ Native KIBRA AI task package created")
    print("Report: posts/native_kibra_ai_task_package.md")
    print("Feed: feeds/native_kibra_ai_task_package.json")
    print("Proof: proofs/native_kibra_ai_task_package.sha256")
    print("PNG: token/kibra/native/assets/kibra_token.png")
    print("Website: website/kibra/index.html")

def submit():
    task_file = ROOT / "parliament/native_kibra/tasks/native_kibra_evolution_task.json"
    task = json.loads(task_file.read_text())
    subprocess.run(
        ["redis-cli", "LPUSH", "cybra:ai:tasks:native_kibra", json.dumps(task, ensure_ascii=False)],
        cwd=ROOT,
        stdout=subprocess.DEVNULL
    )
    print("✅ AI task added to cybra:ai:tasks:native_kibra")
    print("ℹ Not submitted to execution queue. Nothing launched.")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    if cmd == "build":
        build()
    elif cmd == "submit":
        submit()
    else:
        raise SystemExit("Usage: build|submit")

if __name__ == "__main__":
    main()
