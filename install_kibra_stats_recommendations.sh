#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

echo "=== INSTALL KIBRA STATS + PARLIAMENT RECOMMENDATIONS ==="

mkdir -p \
  parliament/kibra_stats_recommendations \
  parliament/departments/kibra_stats_recommendations_department \
  data/kibra_stats_recommendations \
  posts feeds proofs logs/kibra_stats_recommendations

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes || true
sleep 1

cat > parliament/departments/kibra_stats_recommendations_department/department.json <<'JSON'
{
  "department_id": "kibra_stats_recommendations_department",
  "name": "KIBRA Statistics and Parliament Recommendations Department",
  "status": "active",
  "mission": "Збирати статистику KIBRA: блоки, пули, shares, AI-task blocks, bridge, mint, finance, audit, promotion, price/sell, repair; формувати рекомендації AI Parliament.",
  "checks": [
    "blocks",
    "difficulty",
    "pool_tagged_blocks",
    "shares",
    "task_blocks",
    "ai_tasks",
    "mint_management",
    "mint_finance",
    "mint_audit",
    "mint_promotion",
    "bridge",
    "price_sell_repair",
    "parliament_queue",
    "failed_tasks",
    "proofs"
  ],
  "safety": [
    "no_real_sell",
    "no_real_payment",
    "no_fake_price",
    "no_fake_volume",
    "manual_OWNER_approval_required"
  ]
}
JSON

cat > parliament/kibra_stats_recommendations/policy.json <<'JSON'
{
  "name": "KIBRA Stats and Recommendations Policy",
  "status": "active",
  "mode": "statistics_recommendations_ai_tasks",
  "native_coin": true,
  "external_mint": false,
  "rule": "Статистика показує стан системи, рекомендації парламенту створюють AI-завдання на доробку. Реальних продажів/платежів немає без OWNER approval.",
  "outputs": [
    "stats_report",
    "recommendations_report",
    "ai_tasks",
    "proof"
  ]
}
JSON

cat > cybra_kibra_stats_recommendations.py <<'PY'
#!/usr/bin/env python3
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

AUDIT = "cybra:kibra:stats_recommendations:audit"
RECS = "cybra:kibra:stats_recommendations:recommendations"
AIQ = "cybra:ai:tasks:kibra_stats_recommendations"

def sha(x):
    return hashlib.sha256(x.encode("utf-8")).hexdigest()

def dsha(x):
    return sha(sha(x))

def now_iso():
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def exists(path):
    return (ROOT / path).exists()

def redis_len(k):
    try:
        return r.llen(k)
    except Exception:
        return 0

def redis_scard(k):
    try:
        return r.scard(k)
    except Exception:
        return 0

def file_sha(path):
    p = ROOT / path
    if not p.exists():
        return None
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1024 * 1024), b""):
            h.update(c)
    return h.hexdigest()

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}

def latest_hash():
    p = ROOT / "blockchain/kibra_chain/latest.block.hash"
    return p.read_text().strip() if p.exists() else None

def git_cmd(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def count_files(pattern):
    return len(list(ROOT.glob(pattern)))

def scan_blocks():
    blocks_dir = ROOT / "blockchain/kibra_chain/blocks"
    blocks = sorted(blocks_dir.glob("block_*.json")) if blocks_dir.exists() else []

    total = len(blocks)
    pool_tagged = 0
    shares_total = 0
    broken = 0

    for f in blocks:
        try:
            obj = json.loads(f.read_text(encoding="utf-8"))
            text = json.dumps(obj, ensure_ascii=False).lower()

            if any(x in text for x in ["pool", "miner", "pool_id", "mining_pool", "pool_reward", "pool_accounting"]):
                pool_tagged += 1

            shares = obj.get("shares_count") or obj.get("shares") or 0
            if isinstance(shares, list):
                shares = len(shares)
            if isinstance(shares, int):
                shares_total += shares
        except Exception:
            broken += 1

    stream = []
    p = ROOT / "blockchain/kibra_chain/difficulty_stream.jsonl"
    if p.exists():
        for line in p.read_text(encoding="utf-8").splitlines():
            if line.strip():
                try:
                    stream.append(json.loads(line))
                except Exception:
                    pass

    difficulties = {}
    for x in stream:
        d = str(x.get("difficulty"))
        difficulties[d] = difficulties.get(d, 0) + 1

    return {
        "total_blocks": total,
        "pool_tagged_blocks": pool_tagged,
        "shares_total": shares_total,
        "average_shares_per_block": shares_total / total if total else 0,
        "broken_block_files": broken,
        "difficulty_distribution": difficulties,
        "latest_hash": latest_hash()
    }

def build_stats():
    blocks = scan_blocks()

    stats = {
        "time": time.time(),
        "time_iso": now_iso(),
        "kibra": blocks,
        "task_blocks": {
            "files": count_files("blockchain/kibra_chain/task_blocks/*.json"),
            "mempool": redis_len("cybra:kibra:task_blocks:mempool"),
            "mined": redis_len("cybra:kibra:task_blocks:mined"),
            "pool_queue": redis_len("cybra:kibra:pool:mining_blocks")
        },
        "ai": {
            "native_kibra_ai": redis_len("cybra:ai:tasks:native_kibra"),
            "finance_gap_ai": redis_len("cybra:ai:tasks:finance_gap_evolution"),
            "finance_profit_ai": redis_len("cybra:ai:tasks:finance_profit_audit"),
            "bridge_pool_ai": redis_len("cybra:ai:tasks:kibra_bridge_pool_until_done"),
            "price_sell_repair_ai": redis_len("cybra:ai:tasks:kibra_price_sell_repair"),
            "block_ai_support": redis_len("cybra:ai:tasks:kibra_block_ai_support"),
            "mint_promotion_ai": redis_len("cybra:ai:tasks:kibra_mint_promotion"),
            "mint_audit_ai": redis_len("cybra:ai:tasks:kibra_mint_audit"),
            "mint_management_ai": redis_len("cybra:ai:tasks:kibra_mint_management")
        },
        "parliament": {
            "queue": redis_len("cybra:parliament:queue"),
            "results": redis_len("cybra:parliament:results"),
            "failed": redis_len("cybra:parliament:failed"),
            "audit": redis_len("cybra:audit")
        },
        "mint": {
            "audit": redis_len("cybra:kibra:mint_audit:audit"),
            "promotion": redis_len("cybra:kibra:mint_promotion:audit"),
            "management": redis_len("cybra:kibra:mint_management:audit"),
            "finance": redis_len("cybra:kibra:mint_finance:audit"),
            "sell_plans": redis_len("cybra:kibra:mint_finance:sell_plans"),
            "repair_queue": redis_len("cybra:kibra:mint_repair:queue"),
            "broken_blocks": redis_len("cybra:kibra:broken_blocks")
        },
        "bridge": {
            "audit": redis_len("cybra:kibra_bridge:audit"),
            "outbox": redis_len("cybra:kibra_bridge:network_outbox"),
            "sealed": redis_len("cybra:kibra_bridge:sealed_packages"),
            "manual_anchor_ready": redis_len("cybra:blockchain:anchor:manual_ready")
        },
        "reports": {
            "native_kibra": exists("feeds/native_kibra_ai_task_package.json"),
            "pool_confirm": exists("feeds/kibra_pool_confirm_report.json"),
            "difficulty_classes": exists("feeds/kibra_difficulty_classes_report.json"),
            "bridge": exists("feeds/kibra_bridge_pool_monetization_report.json"),
            "price_sell_repair": exists("feeds/kibra_price_sell_repair_report.json"),
            "ai_tasks_to_blocks": exists("feeds/ai_tasks_to_mining_blocks_report.json"),
            "block_ai_support": exists("feeds/kibra_block_ai_support_report.json"),
            "mint_promotion": exists("feeds/kibra_mint_promotion_report.json"),
            "mint_audit": exists("feeds/kibra_mint_audit_report.json"),
            "mint_management_finance": exists("feeds/kibra_mint_management_finance_report.json")
        },
        "market": {
            "price_report_exists": exists("feeds/kibra_price_sell_repair_report.json"),
            "pool_reserves_exists": exists("data/kibra_market/pool_reserves.json"),
            "sell_plan_exists": exists("data/kibra_mint_finance/sell_plan.json")
        },
        "git": {
            "branch": git_cmd(["git", "branch", "--show-current"]),
            "commit": git_cmd(["git", "rev-parse", "--short", "HEAD"]),
            "dirty_files": len(git_cmd(["git", "status", "--short"]).splitlines())
        }
    }

    return stats

def recommendations(stats):
    recs = []

    if stats["parliament"]["failed"] > 0:
        recs.append({
            "level": "critical",
            "area": "parliament_failed",
            "recommendation": "Є failed tasks. Спочатку repair/архівація.",
            "task_type": "existing_tasks_activation_task",
            "action": "bash cybra_existing_tasks.sh repair"
        })

    if stats["parliament"]["queue"] > 0:
        recs.append({
            "level": "important",
            "area": "parliament_queue",
            "recommendation": "Черга парламенту не пуста. Запустити until-done worker.",
            "task_type": "ai_until_done_task",
            "action": "bash cybra_ai_until_done.sh run 300"
        })

    if stats["kibra"]["total_blocks"] < 10:
        recs.append({
            "level": "critical",
            "area": "blocks",
            "recommendation": "Блоків менше 10. Домайнити до мінімум 10.",
            "task_type": "kibra_token_chain_task",
            "action": "bash cybra_kibra_chain.sh mine 2"
        })

    if stats["kibra"]["pool_tagged_blocks"] < stats["kibra"]["total_blocks"]:
        recs.append({
            "level": "critical",
            "area": "pool_attribution",
            "recommendation": "Не всі блоки мають pool/miner теги. Оновити pool confirmation.",
            "task_type": "kibra_bridge_pool_task",
            "action": "bash cybra_pool_confirm_report.sh"
        })

    if stats["task_blocks"]["mined"] == 0:
        recs.append({
            "level": "important",
            "area": "ai_task_blocks",
            "recommendation": "Незавершені AI-завдання треба переводити у mining task-blocks.",
            "task_type": "ai_tasks_to_blocks_task",
            "action": "bash cybra_ai_blocks.sh cycle"
        })

    if stats["mint"]["repair_queue"] > 0 or stats["mint"]["broken_blocks"] > 0:
        recs.append({
            "level": "repair",
            "area": "mint_repair",
            "recommendation": "Є repair/broken blocks. Віддати в монетний двір на repair.",
            "task_type": "kibra_price_sell_repair_task",
            "action": "bash cybra_kibra_price.sh report"
        })

    missing_reports = [k for k, v in stats["reports"].items() if not v]
    if missing_reports:
        recs.append({
            "level": "important",
            "area": "missing_reports",
            "recommendation": "Не вистачає звітів: " + ", ".join(missing_reports),
            "task_type": "kibra_mint_audit_task",
            "action": "bash cybra_mint_audit.sh report"
        })

    if not stats["market"]["pool_reserves_exists"]:
        recs.append({
            "level": "market",
            "area": "price",
            "recommendation": "Ринкової ціни нема без liquidity/orderbook. Створити liquidity proof або marketplace demand proof.",
            "task_type": "kibra_market_exchange_task",
            "action": "bash cybra_kibra_market.sh report"
        })

    if not stats["market"]["sell_plan_exists"]:
        recs.append({
            "level": "finance",
            "area": "sell_plan",
            "recommendation": "Створити sell-plan при фінвідділі монетного двору.",
            "task_type": "kibra_mint_management_task",
            "action": "bash cybra_mint_manage.sh report"
        })

    recs.append({
        "level": "growth",
        "area": "promotion",
        "recommendation": "Просувати KIBRA через utility: AI credits, proof services, bridge packages, developer marketplace, pool mining.",
        "task_type": "kibra_mint_promotion_task",
        "action": "bash cybra_mint_promo.sh report"
    })

    recs.append({
        "level": "growth",
        "area": "next_blocks",
        "recommendation": "Наступні AI-завдання не відправляти напряму: переводити у task-blocks і давати пулам на майнинг.",
        "task_type": "ai_tasks_to_blocks_task",
        "action": "bash cybra_ai_blocks.sh until-done"
    })

    return recs

def make_ai_tasks(recs):
    tasks = []
    for i, rec in enumerate(recs, 1):
        tasks.append({
            "topic": f"KIBRA Parliament Recommendation {i}: {rec['area']}",
            "type": rec["task_type"],
            "priority": "high",
            "payload": {
                "source": "kibra_stats_recommendations_department",
                "level": rec["level"],
                "area": rec["area"],
                "recommendation": rec["recommendation"],
                "suggested_action": rec["action"],
                "real_sell": False,
                "real_payment": False,
                "fake_price": False,
                "fake_volume": False,
                "external_tx": False,
                "manual_OWNER_approval_required": True
            }
        })
    return tasks

def report(submit_ai=False):
    for d in ["posts", "feeds", "proofs", "data/kibra_stats_recommendations"]:
        (ROOT / d).mkdir(parents=True, exist_ok=True)

    stats = build_stats()
    recs = recommendations(stats)
    tasks = make_ai_tasks(recs)

    if submit_ai:
        for t in tasks:
            r.lpush(AIQ, json.dumps(t, ensure_ascii=False))

    obj = {
        "status": "kibra_stats_recommendations_report_generated",
        "time": time.time(),
        "time_iso": now_iso(),
        "submit_ai": submit_ai,
        "stats": stats,
        "recommendations": recs,
        "ai_tasks_prepared": len(tasks),
        "ai_tasks_submitted": len(tasks) if submit_ai else 0,
        "safety": {
            "real_sell": False,
            "real_payment": False,
            "fake_price": False,
            "fake_volume": False,
            "external_tx": False,
            "manual_OWNER_approval_required": True
        }
    }

    obj["double_sha"] = dsha(json.dumps(obj, ensure_ascii=False, sort_keys=True))

    (ROOT / "feeds/kibra_stats_recommendations_report.json").write_text(
        json.dumps(obj, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_stats_recommendations/recommendations.json").write_text(
        json.dumps(recs, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    (ROOT / "data/kibra_stats_recommendations/ai_tasks.json").write_text(
        json.dumps(tasks, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )

    rec_md = ""
    for rec in recs:
        rec_md += f"- **{rec['level']}** / `{rec['area']}`: {rec['recommendation']} Action: `{rec['action']}`\n"

    md = f"""# KIBRA Statistics + Parliament Recommendations

Status: **generated**

## Main statistics

- Blocks: **{stats['kibra']['total_blocks']}**
- Pool-tagged blocks: **{stats['kibra']['pool_tagged_blocks']}**
- Shares total: **{stats['kibra']['shares_total']}**
- Average shares/block: **{stats['kibra']['average_shares_per_block']}**
- Latest hash: `{stats['kibra']['latest_hash']}`

## Difficulty

`{stats['kibra']['difficulty_distribution']}`

## Task blocks

- Task block files: **{stats['task_blocks']['files']}**
- Mempool: **{stats['task_blocks']['mempool']}**
- Mined: **{stats['task_blocks']['mined']}**
- Pool queue: **{stats['task_blocks']['pool_queue']}**

## Parliament

- Queue: **{stats['parliament']['queue']}**
- Results: **{stats['parliament']['results']}**
- Failed: **{stats['parliament']['failed']}**

## Mint / Finance

- Mint audit: **{stats['mint']['audit']}**
- Mint promotion: **{stats['mint']['promotion']}**
- Mint management: **{stats['mint']['management']}**
- Mint finance: **{stats['mint']['finance']}**
- Sell plans: **{stats['mint']['sell_plans']}**
- Repair queue: **{stats['mint']['repair_queue']}**
- Broken blocks: **{stats['mint']['broken_blocks']}**

## Bridge

- Bridge outbox: **{stats['bridge']['outbox']}**
- Sealed packages: **{stats['bridge']['sealed']}**
- Manual anchor ready: **{stats['bridge']['manual_anchor_ready']}**

## Parliament recommendations

{rec_md}

## AI tasks

- Prepared: **{len(tasks)}**
- Submitted now: **{len(tasks) if submit_ai else 0}**

## Safety

- Real sell: **false**
- Real payment: **false**
- Fake price: **false**
- Fake volume: **false**
- External tx: **false**
- Manual OWNER approval required: **true**

## Double SHA

`{obj['double_sha']}`
"""

    (ROOT / "posts/kibra_stats_recommendations_report.md").write_text(md, encoding="utf-8")

    with (ROOT / "proofs/kibra_stats_recommendations.sha256").open("w") as f:
        subprocess.run([
            "sha256sum",
            "parliament/departments/kibra_stats_recommendations_department/department.json",
            "parliament/kibra_stats_recommendations/policy.json",
            "feeds/kibra_stats_recommendations_report.json",
            "data/kibra_stats_recommendations/recommendations.json",
            "data/kibra_stats_recommendations/ai_tasks.json",
            "posts/kibra_stats_recommendations_report.md"
        ], cwd=ROOT, stdout=f, stderr=subprocess.DEVNULL)

    r.lpush(AUDIT, json.dumps({
        "status": "kibra_stats_recommendations_report_generated",
        "blocks": stats["kibra"]["total_blocks"],
        "pool_tagged": stats["kibra"]["pool_tagged_blocks"],
        "shares": stats["kibra"]["shares_total"],
        "recommendations": len(recs),
        "submit_ai": submit_ai,
        "double_sha": obj["double_sha"],
        "time": obj["time"]
    }, ensure_ascii=False))

    r.lpush(RECS, json.dumps({
        "status": "recommendations_generated",
        "recommendations": recs,
        "time": obj["time"],
        "double_sha": obj["double_sha"]
    }, ensure_ascii=False))

    print("✅ KIBRA stats + recommendations report generated")
    print("BLOCKS:", stats["kibra"]["total_blocks"])
    print("POOL_TAGGED:", stats["kibra"]["pool_tagged_blocks"])
    print("SHARES:", stats["kibra"]["shares_total"])
    print("RECOMMENDATIONS:", len(recs))
    print("AI_SUBMITTED:", submit_ai)
    print("REPORT: posts/kibra_stats_recommendations_report.md")
    print("PROOF: proofs/kibra_stats_recommendations.sha256")

def main():
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "report":
        report(False)
    elif cmd == "submit-ai":
        report(True)
    else:
        raise SystemExit("Usage: report|submit-ai")

if __name__ == "__main__":
    main()
PY

chmod +x cybra_kibra_stats_recommendations.py

cat > kibra_stats_recommendations_handler.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

python3 cybra_kibra_stats_recommendations.py submit-ai

bash cybra_mint_manage.sh report >/dev/null 2>&1 || true
bash cybra_mint_audit.sh report >/dev/null 2>&1 || true
bash cybra_mint_promo.sh report >/dev/null 2>&1 || true
EOF2

chmod +x kibra_stats_recommendations_handler.sh

cat > cybra_kibra_stats.sh <<'EOF2'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

case "${1:-status}" in
  report)
    python3 cybra_kibra_stats_recommendations.py report
    cat posts/kibra_stats_recommendations_report.md
    ;;
  submit-ai)
    python3 cybra_kibra_stats_recommendations.py submit-ai
    ;;
  task)
    cybra parliament '{"topic":"KIBRA Statistics and Parliament Recommendations","type":"kibra_stats_recommendations_task","priority":"critical","payload":{"statistics":true,"recommendations":true,"ai_tasks":true,"real_sell":false,"real_payment":false,"manual_OWNER_approval_required":true}}'
    ;;
  cycle)
    python3 cybra_kibra_stats_recommendations.py submit-ai
    cybra parliament '{"topic":"KIBRA Statistics and Parliament Recommendations","type":"kibra_stats_recommendations_task","priority":"critical","payload":{"statistics":true,"recommendations":true,"ai_tasks":true,"manual_OWNER_approval_required":true}}'
    python3 parliament_executor_v6.py || true
    python3 cybra_kibra_stats_recommendations.py report
    cat posts/kibra_stats_recommendations_report.md
    ;;
  until-done)
    python3 cybra_kibra_stats_recommendations.py submit-ai
    bash cybra_ai_blocks.sh until-done || true
    bash cybra_ai_until_done.sh run 300 || true
    python3 cybra_kibra_stats_recommendations.py report
    ;;
  status)
    redis-cli ping
    echo "STATS_AUDIT: $(redis-cli LLEN cybra:kibra:stats_recommendations:audit)"
    echo "STATS_RECS: $(redis-cli LLEN cybra:kibra:stats_recommendations:recommendations)"
    echo "STATS_AI_QUEUE: $(redis-cli LLEN cybra:ai:tasks:kibra_stats_recommendations)"
    echo "BLOCKS: $(find blockchain/kibra_chain/blocks -name 'block_*.json' 2>/dev/null | wc -l)"
    echo "TASK_BLOCKS: $(find blockchain/kibra_chain/task_blocks -name '*.json' 2>/dev/null | wc -l)"
    echo "PARLIAMENT_QUEUE: $(redis-cli LLEN cybra:parliament:queue)"
    echo "PARLIAMENT_FAILED: $(redis-cli LLEN cybra:parliament:failed)"
    test -f posts/kibra_stats_recommendations_report.md && echo "REPORT: exists" || echo "REPORT: missing"
    ;;
  recommendations)
    cat data/kibra_stats_recommendations/recommendations.json
    ;;
  ai-tasks)
    cat data/kibra_stats_recommendations/ai_tasks.json
    ;;
  feed)
    cat feeds/kibra_stats_recommendations_report.json
    ;;
  proof)
    cat proofs/kibra_stats_recommendations.sha256
    ;;
  *)
    echo "Usage:"
    echo "  bash cybra_kibra_stats.sh report"
    echo "  bash cybra_kibra_stats.sh submit-ai"
    echo "  bash cybra_kibra_stats.sh task"
    echo "  bash cybra_kibra_stats.sh cycle"
    echo "  bash cybra_kibra_stats.sh until-done"
    echo "  bash cybra_kibra_stats.sh status"
    echo "  bash cybra_kibra_stats.sh recommendations"
    echo "  bash cybra_kibra_stats.sh ai-tasks"
    ;;
esac
EOF2

chmod +x cybra_kibra_stats.sh

redis-cli HSET cybra:executor:mapping kibra_stats_recommendations_task kibra_stats_recommendations_handler.sh >/dev/null

python3 - <<'PY'
from pathlib import Path

p = Path("parliament_executor_v6.py")
s = p.read_text()

if 'r.hget("cybra:executor:mapping", task_type)' not in s:
    old = "script_name = SCRIPT_MAP.get(task_type)"
    new = 'script_name = r.hget("cybra:executor:mapping", task_type) or SCRIPT_MAP.get(task_type)'
    if old in s:
        s = s.replace(old, new, 1)

if '"kibra_stats_recommendations_task"' not in s:
    i = s.find("SCRIPT_MAP")
    j = s.find("{", i)
    if i >= 0 and j >= 0:
        s = s[:j+1] + '\n    "kibra_stats_recommendations_task": "kibra_stats_recommendations_handler.sh",' + s[j+1:]

p.write_text(s)
print("✅ kibra_stats_recommendations_task mapping ready")
PY

rm -rf __pycache__
python3 -m py_compile cybra_kibra_stats_recommendations.py
python3 -m py_compile parliament_executor_v6.py
rm -rf __pycache__

echo
echo "=== CREATE STATS + RECOMMENDATIONS ==="
bash cybra_kibra_stats.sh submit-ai

echo
echo "=== ADD MASTER TASK TO PARLIAMENT ==="
bash cybra_kibra_stats.sh task

echo
echo "=== EXECUTE ONE ROUND ==="
python3 parliament_executor_v6.py || true

echo
echo "=== STATUS ==="
bash cybra_kibra_stats.sh status

echo
echo "=== PROOF CHECK ==="
sha256sum -c proofs/kibra_stats_recommendations.sha256 || true

echo
echo "✅ KIBRA STATS + RECOMMENDATIONS INSTALLED"
