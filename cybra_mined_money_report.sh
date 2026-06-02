#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs data/kibra_mined_money

python3 - <<'PY'
import json, time, hashlib, subprocess
from decimal import Decimal, getcontext
from pathlib import Path
import redis

getcontext().prec = 50

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def sha(x):
    return hashlib.sha256(x.encode()).hexdigest()

def dsha(x):
    return sha(sha(x))

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def count(pattern):
    return len(list(ROOT.glob(pattern)))

def redis_len(k):
    try:
        return r.llen(k)
    except Exception:
        return 0

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

reward_policy = load_json("data/kibra_mint_finance/reward_policy.json")
block_reward = Decimal(str(reward_policy.get("block_reward_kibra", "100")))
task_block_reward = Decimal(str(reward_policy.get("task_block_reward_kibra", "100")))

main_blocks = Decimal(count("blockchain/kibra_chain/blocks/block_*.json"))
task_blocks = Decimal(count("blockchain/kibra_chain/task_blocks/*.json"))

main_kibra = main_blocks * block_reward
task_kibra = task_blocks * task_block_reward
total_kibra = main_kibra + task_kibra

pool_confirm = load_json("feeds/kibra_pool_confirm_report.json")
shares_total = pool_confirm.get("shares_total", 210)

pool_reserves = load_json("data/kibra_market/pool_reserves.json")
real_price = Decimal("0")
real_price_status = "no_real_market_price_yet"

if pool_reserves:
    try:
        quote = Decimal(str(pool_reserves.get("quote_reserve_usd", "0")))
        kibra_reserve = Decimal(str(pool_reserves.get("kibra_reserve", "0")))
        if quote > 0 and kibra_reserve > 0:
            real_price = quote / kibra_reserve
            real_price_status = "reference_price_from_pool_reserves"
    except Exception:
        pass

scenarios = {}
for p in ["0", "0.0001", "0.001", "0.01", "0.10", "1", "10"]:
    price = Decimal(p)
    scenarios[p] = str(total_kibra * price)

report = {
    "status": "kibra_mined_money_report_generated",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "latest_kibra_hash": latest_hash(),
    "mined": {
        "main_blocks": int(main_blocks),
        "task_blocks": int(task_blocks),
        "total_mined_blocks": int(main_blocks + task_blocks),
        "block_reward_kibra": str(block_reward),
        "task_block_reward_kibra": str(task_block_reward),
        "main_kibra": str(main_kibra),
        "task_kibra": str(task_kibra),
        "total_mined_kibra": str(total_kibra),
        "shares_total": shares_total
    },
    "market": {
        "confirmed_market_usd": str(total_kibra * real_price),
        "price_usd_per_kibra": str(real_price),
        "price_status": real_price_status,
        "real_sell_now": False,
        "manual_OWNER_approval_required": True
    },
    "scenarios_usd": scenarios,
    "queues": {
        "parliament_queue": redis_len("cybra:parliament:queue"),
        "parliament_failed": redis_len("cybra:parliament:failed"),
        "task_block_mempool": redis_len("cybra:kibra:task_blocks:mempool"),
        "task_blocks_mined": redis_len("cybra:kibra:task_blocks:mined"),
        "pool_mining_blocks": redis_len("cybra:kibra:pool:mining_blocks")
    },
    "safety": {
        "real_sell_now": False,
        "real_payment_now": False,
        "fake_price": False,
        "fake_volume": False,
        "manual_OWNER_approval_required": True
    }
}

report["double_sha"] = dsha(json.dumps(report, ensure_ascii=False, sort_keys=True))

(ROOT / "feeds/kibra_mined_money_report.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

md = f"""# KIBRA Mined Money Report

Status: **generated**

## Намайнено

- Main blocks: **{int(main_blocks)}**
- AI task-blocks: **{int(task_blocks)}**
- Total mined blocks: **{int(main_blocks + task_blocks)}**
- Reward per main block: **{block_reward} KIBRA**
- Reward per task-block: **{task_block_reward} KIBRA**
- Main KIBRA: **{main_kibra}**
- Task-block KIBRA: **{task_kibra}**
- Total mined KIBRA: **{total_kibra}**
- Shares total: **{shares_total}**

## Кошти

- Confirmed market price: **{real_price} USD / KIBRA**
- Confirmed market value: **{total_kibra * real_price} USD**
- Price status: **{real_price_status}**

## Теоретичні сценарії

- 1 KIBRA = $0.0001 → **${scenarios["0.0001"]}**
- 1 KIBRA = $0.001 → **${scenarios["0.001"]}**
- 1 KIBRA = $0.01 → **${scenarios["0.01"]}**
- 1 KIBRA = $0.10 → **${scenarios["0.10"]}**
- 1 KIBRA = $1 → **${scenarios["1"]}**
- 1 KIBRA = $10 → **${scenarios["10"]}**

## Черги

- Parliament queue: **{report["queues"]["parliament_queue"]}**
- Parliament failed: **{report["queues"]["parliament_failed"]}**
- Task-block mempool: **{report["queues"]["task_block_mempool"]}**
- Task-blocks mined: **{report["queues"]["task_blocks_mined"]}**
- Pool mining blocks: **{report["queues"]["pool_mining_blocks"]}**

## Правило

Намайнені KIBRA рахуються в обліку.  
Реальна ціна зʼявляється тільки після liquidity/orderbook/buyers.  
Реальний продаж — тільки після manual OWNER approval.

## Double SHA

`{report["double_sha"]}`
"""

(ROOT / "posts/kibra_mined_money_report.md").write_text(md, encoding="utf-8")

with (ROOT / "proofs/kibra_mined_money.sha256").open("w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/kibra_mined_money_report.json",
        "posts/kibra_mined_money_report.md"
    ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

ai_task = {
    "topic": "KIBRA mined money accounting and realization plan",
    "type": "kibra_mint_management_task",
    "priority": "critical",
    "payload": {
        "source": "kibra_mined_money_report",
        "total_mined_kibra": str(total_kibra),
        "confirmed_market_usd": str(total_kibra * real_price),
        "price_usd_per_kibra": str(real_price),
        "goal": "Підготувати вигідну реалізацію намайнених KIBRA через utility, liquidity plan, sell-plan і OWNER approval.",
        "convert_to_mining_block_first": True,
        "real_sell_now": False,
        "real_payment_now": False,
        "fake_price": False,
        "fake_volume": False,
        "manual_OWNER_approval_required": True
    }
}

r.lpush("cybra:ai:tasks:block_inbox", json.dumps(ai_task, ensure_ascii=False))
r.lpush("cybra:kibra:mined_money:audit", json.dumps({
    "status": "mined_money_report_generated",
    "total_mined_kibra": str(total_kibra),
    "confirmed_market_usd": str(total_kibra * real_price),
    "double_sha": report["double_sha"],
    "time": report["time"]
}, ensure_ascii=False))

print("✅ KIBRA mined money report created")
print("MAIN_BLOCKS:", int(main_blocks))
print("TASK_BLOCKS:", int(task_blocks))
print("TOTAL_MINED_BLOCKS:", int(main_blocks + task_blocks))
print("TOTAL_MINED_KIBRA:", total_kibra)
print("CONFIRMED_MARKET_USD:", total_kibra * real_price)
print("AI_TASK_ADDED_TO_BLOCK_INBOX: yes")
print("REPORT: posts/kibra_mined_money_report.md")
print("PROOF: proofs/kibra_mined_money.sha256")
PY

sha256sum -c proofs/kibra_mined_money.sha256

echo
echo "=== ENFORCE AI TASK INTO MINING BLOCK ==="
bash cybra_ai_block_enforcer.sh enforce 3 || true

echo
echo "=== UPDATE MANAGEMENT / STATS ==="
bash cybra_mint_manage.sh report || true
bash cybra_kibra_stats.sh report || true
