#!/usr/bin/env python3
import json
import time
import os
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"

POLICY_FILE = ROOT / "parliament/token_kibra/kibra_token_policy.json"
IMAGE_META_FILE = ROOT / "token/kibra/image/token_image_meta.json"

CHAIN_DIR = ROOT / "blockchain/kibra_chain"
BLOCKS_DIR = CHAIN_DIR / "blocks"
STREAM_FILE = CHAIN_DIR / "difficulty_stream.jsonl"
LATEST_BLOCK = CHAIN_DIR / "latest.block.json"
LATEST_HASH = CHAIN_DIR / "latest.block.hash"

TARGET_INTERVAL_SEC = int(os.getenv("CYBRA_KIBRA_TARGET_INTERVAL", "30"))
MIN_DIFFICULTY = int(os.getenv("CYBRA_KIBRA_MIN_DIFFICULTY", "2"))
MAX_DIFFICULTY = int(os.getenv("CYBRA_KIBRA_MAX_DIFFICULTY", "4"))
MAX_NONCE = int(os.getenv("CYBRA_KIBRA_MAX_NONCE", "2500000"))

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text: str) -> str:
    return sha(sha(text))

def sha_file(path: Path) -> str:
    if not path.exists():
        return None
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def ensure_dirs():
    for p in [
        CHAIN_DIR,
        BLOCKS_DIR,
        ROOT / "posts",
        ROOT / "feeds",
        ROOT / "proofs",
        ROOT / "logs/kibra",
        ROOT / "blocks/kibra_chain"
    ]:
        p.mkdir(parents=True, exist_ok=True)

def load_policy():
    return json.loads(POLICY_FILE.read_text(encoding="utf-8"))

def load_image_meta():
    meta = json.loads(IMAGE_META_FILE.read_text(encoding="utf-8"))
    logo = ROOT / "token/kibra/image/logo.png"
    meta["logo_exists"] = logo.exists()
    meta["logo_sha256"] = sha_file(logo)
    return meta

def canonical(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

def merkle_root(items):
    hashes = [dsha(canonical(x)) for x in items]
    if not hashes:
        return dsha("EMPTY")
    while len(hashes) > 1:
        nxt = []
        for i in range(0, len(hashes), 2):
            a = hashes[i]
            b = hashes[i + 1] if i + 1 < len(hashes) else a
            nxt.append(dsha(a + b))
        hashes = nxt
    return hashes[0]

def block_hash(block_without_hash):
    return sha(canonical(block_without_hash))

def latest_block():
    if LATEST_BLOCK.exists():
        return json.loads(LATEST_BLOCK.read_text(encoding="utf-8"))
    return None

def choose_difficulty(prev):
    if not prev:
        return MIN_DIFFICULTY

    prev_diff = int(prev.get("difficulty", MIN_DIFFICULTY))
    prev_ts = float(prev.get("timestamp", time.time()))
    interval = max(1.0, time.time() - prev_ts)

    if interval < TARGET_INTERVAL_SEC / 2:
        diff = prev_diff + 1
    elif interval > TARGET_INTERVAL_SEC * 2:
        diff = prev_diff - 1
    else:
        diff = prev_diff

    if diff < MIN_DIFFICULTY:
        diff = MIN_DIFFICULTY
    if diff > MAX_DIFFICULTY:
        diff = MAX_DIFFICULTY

    return diff

def mine_pow(base_block, difficulty):
    prefix = "0" * difficulty
    share_prefix = "0" * max(1, difficulty - 1)

    shares = []
    best_hash = None
    best_nonce = 0

    for nonce in range(MAX_NONCE + 1):
        candidate = dict(base_block)
        candidate["nonce"] = nonce
        h = block_hash(candidate)

        if best_hash is None or h < best_hash:
            best_hash = h
            best_nonce = nonce

        if h.startswith(share_prefix) and len(shares) < 40:
            shares.append({
                "nonce": nonce,
                "share_hash": h,
                "share_difficulty_prefix": share_prefix,
                "timestamp": time.time()
            })

        if h.startswith(prefix):
            return {
                "ok": True,
                "nonce": nonce,
                "hash": h,
                "shares": shares,
                "difficulty_prefix": prefix,
                "best_hash": best_hash,
                "best_nonce": best_nonce
            }

    return {
        "ok": False,
        "nonce": best_nonce,
        "hash": best_hash,
        "shares": shares,
        "difficulty_prefix": prefix,
        "best_hash": best_hash,
        "best_nonce": best_nonce
    }

def build_ai_tasks(block_kind):
    return [
        {
            "task_id": "KIBRA-FIN-001",
            "department": "finance_department",
            "goal": "Підтвердити 60/40 allocation: 60% owner, 40% pool, без автоматичних оплат.",
            "block_kind": block_kind
        },
        {
            "task_id": "KIBRA-REV-001",
            "department": "revision_organ",
            "goal": "Перевірити supply, difficulty stream, timestamp, proof, anchor queue.",
            "block_kind": block_kind
        },
        {
            "task_id": "KIBRA-ANA-001",
            "department": "analytics_committee",
            "goal": "Оцінити графік складності, кількість shares і якість proof-chain.",
            "block_kind": block_kind
        },
        {
            "task_id": "KIBRA-HASH-001",
            "department": "hash_module",
            "goal": "Зібрати token policy + AI tasks + shares + timestamp у root double SHA.",
            "block_kind": block_kind
        },
        {
            "task_id": "KIBRA-ANCHOR-001",
            "department": "blockchain_anchor_queue",
            "goal": "Поставити proof у чергу для ручного зовнішнього blockchain anchor.",
            "block_kind": block_kind
        }
    ]

def save_block(block):
    idx = int(block["index"])
    h = block["block_hash"]

    file = BLOCKS_DIR / f"block_{idx:09d}_{h[:16]}.json"
    file.write_text(json.dumps(block, ensure_ascii=False, indent=2), encoding="utf-8")

    LATEST_BLOCK.write_text(json.dumps(block, ensure_ascii=False, indent=2), encoding="utf-8")
    LATEST_HASH.write_text(block["block_hash"] + "\n", encoding="utf-8")

    stream = {
        "index": block["index"],
        "time": block["timestamp"],
        "time_iso": block["time_iso"],
        "difficulty": block["difficulty"],
        "difficulty_prefix": block["difficulty_prefix"],
        "target_interval_sec": TARGET_INTERVAL_SEC,
        "actual_interval_sec": block.get("actual_interval_sec"),
        "block_hash": block["block_hash"],
        "pow_ok": block["pow_ok"],
        "shares_count": len(block.get("shares", []))
    }

    with STREAM_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(stream, ensure_ascii=False) + "\n")

    return file

def anchor_and_audit(block, block_file):
    feed = {
        "status": "kibra_block_generated",
        "token": "Кібра",
        "symbol": "KIBRA",
        "block_index": block["index"],
        "block_hash": block["block_hash"],
        "block_double_sha": block["block_double_sha"],
        "difficulty": block["difficulty"],
        "shares_count": len(block["shares"]),
        "block_file": str(block_file.relative_to(ROOT)),
        "manual_external_anchor_required": True,
        "time": block["timestamp"]
    }

    r.lpush("cybra:kibra_chain:audit", json.dumps(feed, ensure_ascii=False))
    r.lpush("cybra:blockchain:anchor:queue", json.dumps({
        "status": "queued_for_manual_external_blockchain_anchor",
        "chain": "KIBRA_LOCAL_PROOF_CHAIN",
        "token": "Кібра",
        "symbol": "KIBRA",
        "block_index": block["index"],
        "block_hash": block["block_hash"],
        "block_double_sha": block["block_double_sha"],
        "external_tx": None,
        "manual_anchor_required": True,
        "time": block["timestamp"]
    }, ensure_ascii=False))

    r.lpush("cybra:finance:ledger", json.dumps({
        "status": "proposal_only",
        "topic": "KIBRA token 60/40 pool allocation",
        "token": "Кібра",
        "symbol": "KIBRA",
        "total_supply_raw": block["token"]["total_supply_raw"],
        "owner_percent": 60,
        "pool_percent": 40,
        "owner_amount_raw": block["allocation"]["owner_amount_raw"],
        "pool_amount_raw": block["allocation"]["pool_amount_raw"],
        "payment_execution_allowed": False,
        "manual_owner_approval_required": True,
        "block_hash": block["block_hash"],
        "time": block["timestamp"]
    }, ensure_ascii=False))

def create_block(block_kind="regular"):
    ensure_dirs()
    r.ping()

    policy = load_policy()
    image_meta = load_image_meta()
    prev = latest_block()

    index = 0 if prev is None else int(prev["index"]) + 1
    previous_hash = "GENESIS" if prev is None else prev["block_hash"]
    actual_interval = None if prev is None else max(1.0, time.time() - float(prev["timestamp"]))

    difficulty = MIN_DIFFICULTY if prev is None else choose_difficulty(prev)
    ai_tasks = build_ai_tasks(block_kind)

    block_time = time.time()

    base_block = {
        "chain": "KIBRA_LOCAL_PROOF_CHAIN",
        "block_kind": block_kind,
        "index": index,
        "timestamp": block_time,
        "time_iso": now_iso(),
        "previous_block_hash": previous_hash,
        "actual_interval_sec": actual_interval,
        "target_interval_sec": TARGET_INTERVAL_SEC,
        "difficulty": difficulty,
        "difficulty_prefix": "0" * difficulty,
        "difficulty_model": "timestamp_adjusted_bitcoin_like_local_pow",
        "token": policy["token"],
        "allocation": policy["allocation"],
        "image": image_meta,
        "ai_tasks": ai_tasks,
        "ai_tasks_merkle_root": merkle_root(ai_tasks),
        "policy_sha256": sha_file(POLICY_FILE),
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        },
        "external_blockchain_anchor": {
            "status": "queued_only",
            "external_tx": None,
            "manual_owner_approval_required": True
        }
    }

    pow_result = mine_pow(base_block, difficulty)

    block = dict(base_block)
    block["nonce"] = pow_result["nonce"]
    block["block_hash"] = pow_result["hash"]
    block["pow_ok"] = pow_result["ok"]
    block["best_hash"] = pow_result["best_hash"]
    block["best_nonce"] = pow_result["best_nonce"]
    block["shares"] = pow_result["shares"]
    block["shares_merkle_root"] = merkle_root(pow_result["shares"])
    block["block_double_sha"] = dsha(block["block_hash"] + block["ai_tasks_merkle_root"] + block["shares_merkle_root"])

    block_file = save_block(block)
    anchor_and_audit(block, block_file)
    report()

    print("✅ KIBRA block generated")
    print("Index:", block["index"])
    print("Hash:", block["block_hash"])
    print("Double SHA:", block["block_double_sha"])
    print("Difficulty:", block["difficulty"])
    print("POW OK:", block["pow_ok"])
    print("Shares:", len(block["shares"]))
    print("File:", str(block_file.relative_to(ROOT)))

def verify():
    ensure_dirs()

    files = sorted(BLOCKS_DIR.glob("block_*.json"))
    ok = True
    errors = []
    prev_hash = "GENESIS"

    for file in files:
        b = json.loads(file.read_text(encoding="utf-8"))

        calc_obj = dict(b)
        stored_hash = calc_obj.pop("block_hash", None)
        calc_obj.pop("block_double_sha", None)
        calc_obj.pop("best_hash", None)
        calc_obj.pop("best_nonce", None)
        calc_obj.pop("shares", None)
        calc_obj.pop("shares_merkle_root", None)

        # Rebuild object exactly as mining base + nonce.
        base = dict(b)
        remove_keys = ["block_hash", "block_double_sha", "best_hash", "best_nonce", "shares", "shares_merkle_root"]
        for k in remove_keys:
            base.pop(k, None)

        calc_hash = block_hash(base)

        if calc_hash != stored_hash:
            ok = False
            errors.append(f"{file.name}: hash mismatch")

        if not stored_hash.startswith("0" * int(b["difficulty"])):
            ok = False
            errors.append(f"{file.name}: difficulty proof failed")

        if b["previous_block_hash"] != prev_hash:
            ok = False
            errors.append(f"{file.name}: previous hash mismatch")

        prev_hash = stored_hash

    result = {
        "status": "verified" if ok else "failed",
        "blocks": len(files),
        "errors": errors,
        "time": time.time()
    }

    (ROOT / "feeds/kibra_chain_verify.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))

    if not ok:
        raise SystemExit(1)

def report():
    ensure_dirs()

    policy = load_policy()
    image_meta = load_image_meta()
    files = sorted(BLOCKS_DIR.glob("block_*.json"))
    latest = latest_block()

    stream_lines = []
    if STREAM_FILE.exists():
        for line in STREAM_FILE.read_text(encoding="utf-8").splitlines()[-50:]:
            try:
                stream_lines.append(json.loads(line))
            except Exception:
                pass

    feed = {
        "status": "kibra_token_chain_report_generated",
        "token": policy["token"],
        "allocation": policy["allocation"],
        "image": image_meta,
        "chain": {
            "height": len(files),
            "latest_hash": latest["block_hash"] if latest else None,
            "latest_double_sha": latest["block_double_sha"] if latest else None,
            "latest_difficulty": latest["difficulty"] if latest else None,
            "target_interval_sec": TARGET_INTERVAL_SEC,
            "min_difficulty": MIN_DIFFICULTY,
            "max_difficulty": MAX_DIFFICULTY
        },
        "difficulty_stream_latest": stream_lines,
        "redis": {
            "kibra_audit": r.llen("cybra:kibra_chain:audit"),
            "finance_ledger": r.llen("cybra:finance:ledger"),
            "anchor_queue": r.llen("cybra:blockchain:anchor:queue")
        },
        "time": time.time()
    }

    feed["double_sha"] = dsha(canonical(feed))

    (ROOT / "feeds/kibra_token_chain_status.json").write_text(json.dumps(feed, ensure_ascii=False, indent=2), encoding="utf-8")

    diff_md = ""
    for x in stream_lines[-20:]:
        diff_md += f"- block `{x['index']}` difficulty `{x['difficulty']}` hash `{x['block_hash'][:24]}...` shares `{x['shares_count']}` pow_ok `{x['pow_ok']}`\n"
    if not diff_md:
        diff_md = "- none\n"

    latest_md = "none"
    if latest:
        latest_md = f"""
- Latest index: `{latest["index"]}`
- Latest hash: `{latest["block_hash"]}`
- Latest double SHA: `{latest["block_double_sha"]}`
- Latest difficulty: `{latest["difficulty"]}`
- POW OK: `{latest["pow_ok"]}`
- Shares: `{len(latest["shares"])}`
"""

    md = f"""# KIBRA Image Token Chain

Status: active proof-chain

## Token

- Type: **Image**
- Name: **Кібра**
- Symbol: **KIBRA**
- Total Supply: **49 000 000 000 000 000**
- OWNER allocation 60%: **29 400 000 000 000 000**
- Pool allocation 40%: **19 600 000 000 000 000**

## Chain

- Height: {feed["chain"]["height"]}
- Target interval: {TARGET_INTERVAL_SEC} sec
- Difficulty min: {MIN_DIFFICULTY}
- Difficulty max safe/mobile: {MAX_DIFFICULTY}
- External blockchain anchor: queued manually, not automatic

## Latest block

{latest_md}

## Difficulty stream

{diff_md}

## Proof meaning

Кожен блок містить:

- timestamp;
- previous block hash;
- token policy hash;
- AI tasks merkle root;
- local mined shares;
- difficulty;
- proof-of-work hash;
- block double SHA;
- manual external blockchain anchor queue.

Це створює доказову локальну мережу Кібри.  
Для публічного зовнішнього блокчейну потрібен окремий ручний on-chain anchor.

## Files

- `parliament/token_kibra/kibra_token_policy.json`
- `blockchain/kibra_chain/latest.block.json`
- `blockchain/kibra_chain/latest.block.hash`
- `blockchain/kibra_chain/difficulty_stream.jsonl`
- `feeds/kibra_token_chain_status.json`
- `posts/kibra_token_chain_status.md`
- `proofs/kibra_token_chain.sha256`
"""

    (ROOT / "posts/kibra_token_chain_status.md").write_text(md, encoding="utf-8")

    proof_files = [
        "parliament/token_kibra/kibra_token_policy.json",
        "token/kibra/image/token_image_meta.json",
        "feeds/kibra_token_chain_status.json",
        "posts/kibra_token_chain_status.md"
    ]

    if LATEST_BLOCK.exists():
        proof_files.append("blockchain/kibra_chain/latest.block.json")
    if LATEST_HASH.exists():
        proof_files.append("blockchain/kibra_chain/latest.block.hash")
    if STREAM_FILE.exists():
        proof_files.append("blockchain/kibra_chain/difficulty_stream.jsonl")

    with (ROOT / "proofs/kibra_token_chain.sha256").open("w") as f:
        subprocess.run(["sha256sum"] + proof_files, cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

def status():
    ensure_dirs()
    report()
    print((ROOT / "posts/kibra_token_chain_status.md").read_text(encoding="utf-8"))

def submit_ai_task():
    task = {
        "topic": "Build KIBRA Image Token Chain",
        "type": "kibra_token_chain_task",
        "priority": "critical",
        "payload": {
            "token_type": "Image",
            "name": "Кібра",
            "symbol": "KIBRA",
            "total_supply_raw": "49000000000000000",
            "owner_share_percent": 60,
            "pool_share_percent": 40,
            "build": [
                "local_proof_blockchain",
                "timestamp_difficulty_stream",
                "proof_of_work_shares",
                "finance_ledger_proposal",
                "revision_check",
                "analytics_check",
                "hash_module_check",
                "manual_external_blockchain_anchor_queue"
            ],
            "real_execution": False,
            "manual_owner_approval_required": True
        }
    }
    r.lpush("cybra:parliament:queue", json.dumps(task, ensure_ascii=False))
    r.lpush("cybra:kibra_chain:audit", json.dumps({
        "status": "kibra_ai_task_submitted",
        "task": task,
        "time": time.time()
    }, ensure_ascii=False))
    print("✅ KIBRA AI task submitted to cybra:parliament:queue")

def main():
    import sys

    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    if cmd == "init":
        if latest_block() is None:
            create_block("genesis")
        else:
            print("KIBRA chain already initialized")
        report()
    elif cmd == "mine":
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 1
        for _ in range(n):
            create_block("regular")
    elif cmd == "verify":
        verify()
    elif cmd == "report":
        report()
        print("✅ report generated")
    elif cmd == "status":
        status()
    elif cmd == "task":
        submit_ai_task()
    else:
        raise SystemExit("Usage: init|mine [n]|verify|report|status|task")

if __name__ == "__main__":
    main()
