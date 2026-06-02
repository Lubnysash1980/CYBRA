#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== CYBRA TOKEN POOL AI ORCHESTRATOR INSTALL ==="

mkdir -p \
  parliament/token_pool_ai \
  token/pool_ai \
  data/finance \
  blocks/token_pool_ai \
  posts feeds proofs logs/token_pool_ai

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY' >/dev/null 2>&1 || python3 -m pip install redis
import redis
PY

cat > parliament/token_pool_ai/token_pool_ai_policy.json <<'JSON'
{
  "name": "CYBRA Token Pool AI Finance Policy",
  "status": "active",
  "mode": "proposal_and_proof_only",
  "purpose": "Координувати фінансовий, ревізійний, аналітичний і hash-модуль для токен-пулу, AI-завдань, share-блоків і proof-chain.",
  "distribution": {
    "owner_share_percent": 60,
    "pool_reward_percent": 40,
    "rule": "60% owner allocation / 40% pool reward allocation",
    "real_execution": "manual approval required"
  },
  "pool_rules": {
    "all_tokens_require_pool_plan": true,
    "real_liquidity_pool_creation": "manual_wallet_approval_required",
    "no_automatic_payments": true,
    "no_private_keys": true,
    "no_seed_phrase": true,
    "no_unverified_contracts": true,
    "finance_department_review_required": true,
    "revision_review_required": true,
    "analytics_review_required": true,
    "hash_proof_required": true
  },
  "ai_block_rules": {
    "ai_tasks_are_grouped_into_blocks": true,
    "shares_are_local_hash_proofs": true,
    "shares_do_not_guarantee_real_income": true,
    "blockchain_anchor_status": "proof_queue_only_until_manual_onchain_anchor"
  }
}
JSON

cat > cybra_token_pool_ai_orchestrator.py <<'PY'
#!/usr/bin/env python3
import json
import time
import hashlib
import subprocess
from pathlib import Path

import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

POLICY_FILE = ROOT / "parliament/token_pool_ai/token_pool_ai_policy.json"
BLOCK_DIR = ROOT / "blocks/token_pool_ai"

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def dsha(text: str) -> str:
    return sha(sha(text))

def sha_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def load_policy():
    return json.loads(POLICY_FILE.read_text())

def latest_previous_block_hash():
    latest = ROOT / "blocks/token_pool_ai/latest.block.hash"
    if latest.exists():
        return latest.read_text().strip()
    return "GENESIS"

def mine_local_shares(block_seed: str, count=12, difficulty_prefix="000"):
    shares = []
    nonce = 0

    while len(shares) < count:
        raw = f"{block_seed}:{nonce}"
        h = sha(raw)
        if h.startswith(difficulty_prefix):
            shares.append({
                "nonce": nonce,
                "share_hash": h,
                "seed_sha": sha(block_seed),
                "difficulty_prefix": difficulty_prefix
            })
        nonce += 1

        if nonce > 300000:
            break

    return shares

def build_ai_tasks():
    return [
        {
            "task_id": "AI-FIN-001",
            "department": "finance_department",
            "goal": "Перевірити 60/40 token pool allocation без виконання реальних платежів.",
            "output": "finance ledger proposal + risk report"
        },
        {
            "task_id": "AI-REV-001",
            "department": "revision_organ",
            "goal": "Перевірити, чи token pool plan має audit, proof, no private keys, no auto payments.",
            "output": "revision status"
        },
        {
            "task_id": "AI-ANA-001",
            "department": "analytics_committee",
            "goal": "Оцінити статистику задач, pool-share proof і вплив на розвиток Кіберапарламенту.",
            "output": "analytics summary"
        },
        {
            "task_id": "AI-HASH-001",
            "department": "hash_module",
            "goal": "Зібрати AI tasks + pool policy + shares у double-SHA block.",
            "output": "root hash + block proof"
        },
        {
            "task_id": "AI-EVO-001",
            "department": "evolution_guard",
            "goal": "Перевірити, що модель token pool веде до розвитку, а не до деградації.",
            "output": "evolution pass/hold decision"
        }
    ]

def create_block():
    r.ping()

    policy = load_policy()
    ai_tasks = build_ai_tasks()
    previous_hash = latest_previous_block_hash()

    block_base = {
        "module": "CYBRA Token Pool AI Finance Orchestrator",
        "status": "block_building",
        "time": time.time(),
        "time_iso": now_iso(),
        "previous_block_hash": previous_hash,
        "distribution": policy["distribution"],
        "real_execution": {
            "real_pool_creation": False,
            "real_payment_execution": False,
            "manual_owner_approval_required": True,
            "legal_and_tax_review_required": True,
            "blockchain_anchor": "queued_as_proof_only"
        },
        "ai_tasks": ai_tasks,
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    block_seed = json.dumps(block_base, ensure_ascii=False, sort_keys=True)
    shares = mine_local_shares(block_seed)

    block = dict(block_base)
    block["local_mined_shares"] = shares
    block["shares_count"] = len(shares)

    block_canon = json.dumps(block, ensure_ascii=False, sort_keys=True)
    block["block_double_sha"] = dsha(block_canon)

    block_id = "pool_ai_block_" + str(int(block["time"])) + "_" + block["block_double_sha"][:12]
    block["block_id"] = block_id

    BLOCK_DIR.mkdir(parents=True, exist_ok=True)

    block_file = BLOCK_DIR / f"{block_id}.json"
    block_file.write_text(json.dumps(block, ensure_ascii=False, indent=2))

    (BLOCK_DIR / "latest.block.json").write_text(json.dumps(block, ensure_ascii=False, indent=2))
    (BLOCK_DIR / "latest.block.hash").write_text(block["block_double_sha"] + "\n")

    feed = {
        "status": "token_pool_ai_block_generated",
        "block_id": block_id,
        "block_double_sha": block["block_double_sha"],
        "previous_block_hash": previous_hash,
        "owner_share_percent": 60,
        "pool_reward_percent": 40,
        "shares_count": len(shares),
        "real_pool_created": False,
        "real_payments_executed": False,
        "manual_approval_required": True,
        "blockchain_anchor_queue": "cybra:blockchain:anchor:queue",
        "block_file": str(block_file.relative_to(ROOT)),
        "time": block["time"]
    }

    (ROOT / "feeds/token_pool_ai_status.json").write_text(
        json.dumps(feed, ensure_ascii=False, indent=2)
    )

    finance_proposal = {
        "status": "proposal_only",
        "topic": "CYBRA token pool 60/40 allocation",
        "owner_share_percent": 60,
        "pool_reward_percent": 40,
        "payment_execution_allowed": False,
        "manual_owner_approval_required": True,
        "block_id": block_id,
        "block_double_sha": block["block_double_sha"],
        "time": block["time"]
    }

    r.lpush("cybra:finance:ledger", json.dumps(finance_proposal, ensure_ascii=False))
    r.lpush("cybra:token_pool_ai:audit", json.dumps(feed, ensure_ascii=False))
    r.lpush("cybra:blockchain:anchor:queue", json.dumps({
        "status": "queued_for_manual_onchain_anchor",
        "block_id": block_id,
        "block_double_sha": block["block_double_sha"],
        "real_onchain_tx": None,
        "manual_anchor_required": True,
        "time": block["time"]
    }, ensure_ascii=False))

    md_shares = ""
    for s in shares[:12]:
        md_shares += f"- nonce `{s['nonce']}` → `{s['share_hash']}`\n"

    md_tasks = ""
    for t in ai_tasks:
        md_tasks += f"- `{t['task_id']}` / {t['department']} — {t['goal']}\n"

    md = f"""# CYBRA Token Pool AI Finance Orchestrator

Status: token_pool_ai_block_generated

Block ID:
`{block_id}`

Block Double SHA:
`{block["block_double_sha"]}`

Previous Block:
`{previous_hash}`

## Distribution

- OWNER share: **60%**
- Pool reward: **40%**
- Real pool creation: **false**
- Real payment execution: **false**
- Manual approval required: **true**

## AI tasks inside block

{md_tasks}

## Local proof shares

{md_shares}

## Meaning

Цей модуль створює proof-блок для AI-завдань, фінансової логіки 60/40, ревізії, аналітики і hash-перевірки.

Це не є автоматичним створенням реального liquidity pool і не виконує платежі.  
Реальний пул або on-chain anchor можливий тільки після ручного OWNER approval, правової/податкової перевірки і окремої транзакції.

## Files

- `blocks/token_pool_ai/latest.block.json`
- `blocks/token_pool_ai/latest.block.hash`
- `feeds/token_pool_ai_status.json`
- `posts/token_pool_ai_status.md`
- `proofs/token_pool_ai.sha256`
"""

    (ROOT / "posts/token_pool_ai_status.md").write_text(md)

    with (ROOT / "proofs/token_pool_ai.sha256").open("w") as f:
        subprocess.run(
            [
                "sha256sum",
                str(block_file.relative_to(ROOT)),
                "blocks/token_pool_ai/latest.block.json",
                "blocks/token_pool_ai/latest.block.hash",
                "feeds/token_pool_ai_status.json",
                "posts/token_pool_ai_status.md",
                "parliament/token_pool_ai/token_pool_ai_policy.json"
            ],
            cwd=ROOT,
            stdout=f,
            stderr=subprocess.DEVNULL
        )

    print("✅ CYBRA token pool AI block generated")
    print("Block ID:", block_id)
    print("Block Double SHA:", block["block_double_sha"])
    print("Shares:", len(shares))
    print("Report: posts/token_pool_ai_status.md")
    print("Feed: feeds/token_pool_ai_status.json")
    print("Proof: proofs/token_pool_ai.sha256")

def report():
    create_block()

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"

    if cmd in ("run", "report", "block"):
        report()
    else:
        raise SystemExit("Usage: run|report|block")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_token_pool_ai_orchestrator.py

cat > token_pool_ai_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
python3 cybra_token_pool_ai_orchestrator.py run
EOF2

chmod +x token_pool_ai_handler.sh

cat > cybra_token_pool_ai.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

CMD="${1:-status}"

case "$CMD" in
  run)
    python3 cybra_token_pool_ai_orchestrator.py run
    ;;
  task)
    cybra parliament '{"topic":"CYBRA Token Pool AI Finance Orchestrator","type":"token_pool_ai_task","priority":"high","payload":{"mode":"60_40_pool_ai_block_proof","owner_share_percent":60,"pool_reward_percent":40,"real_execution":false,"manual_approval_required":true}}'
    ;;
  status)
    redis-cli ping
    echo "TOKEN_POOL_AI_AUDIT: $(redis-cli LLEN cybra:token_pool_ai:audit)"
    echo "FINANCE_LEDGER: $(redis-cli LLEN cybra:finance:ledger)"
    echo "BLOCKCHAIN_ANCHOR_QUEUE: $(redis-cli LLEN cybra:blockchain:anchor:queue)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_RESULTS: $(redis-cli LLEN cybra:parliament:results)"
    test -f posts/token_pool_ai_status.md && echo "REPORT: exists" || echo "REPORT: missing"
    test -f blocks/token_pool_ai/latest.block.hash && echo "BLOCK_HASH: $(cat blocks/token_pool_ai/latest.block.hash)" || echo "BLOCK_HASH: missing"
    ;;
  report)
    cat posts/token_pool_ai_status.md
    ;;
  feed)
    cat feeds/token_pool_ai_status.json
    ;;
  proof)
    cat proofs/token_pool_ai.sha256
    ;;
  block)
    cat blocks/token_pool_ai/latest.block.json
    ;;
  hash)
    cat blocks/token_pool_ai/latest.block.hash
    ;;
  anchor-queue)
    redis-cli LRANGE cybra:blockchain:anchor:queue 0 20
    ;;
  *)
    echo "Usage: bash cybra_token_pool_ai.sh run|task|status|report|feed|proof|block|hash|anchor-queue"
    ;;
esac
EOF2

chmod +x cybra_token_pool_ai.sh

redis-cli HSET cybra:executor:mapping token_pool_ai_task token_pool_ai_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"token_pool_ai_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "token_pool_ai_task": "token_pool_ai_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ token_pool_ai_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== RUN DIRECT TOKEN POOL AI BLOCK ==="
bash cybra_token_pool_ai.sh run

echo
echo "=== TEST VIA CYBRA PARLIAMENT ==="
bash cybra_token_pool_ai.sh task
cybra worker-start || true
sleep 8

echo
echo "=== STATUS ==="
bash cybra_token_pool_ai.sh status
cybra status
cybra results | head -5

echo
echo "=== VERIFY PROOF ==="
sha256sum -c proofs/token_pool_ai.sha256 || true

echo
echo "=== REPORT PREVIEW ==="
head -120 posts/token_pool_ai_status.md

echo
echo "=== DONE ==="
