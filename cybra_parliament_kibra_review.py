#!/usr/bin/env python3
import json, subprocess, time, hashlib
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def sh(cmd):
    try:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def redis_len(key):
    out = sh(["redis-cli", "LLEN", key])
    try:
        return int(out)
    except Exception:
        return 0

def redis_lrange(key, n=50):
    out = sh(["redis-cli", "LRANGE", key, "0", str(n)])
    return [x for x in out.splitlines() if x.strip()]

def load_json(path):
    p = ROOT / path
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return None

def exists(path):
    return (ROOT / path).exists()

def dsha(text):
    h1 = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

def proof_check(path):
    if not exists(path):
        return "missing"
    out = sh(["sha256sum", "-c", path])
    if "OK" in out and "FAILED" not in out:
        return "ok"
    if out:
        return "check_output"
    return "unknown"

def parse_results_for_kibra():
    rows = []
    for raw in redis_lrange("cybra:parliament:results", 120):
        try:
            obj = json.loads(raw)
        except Exception:
            continue
        text = json.dumps(obj, ensure_ascii=False).lower()
        if "kibra" in text or "token_pool_ai" in text or "finance_department" in text:
            rows.append(obj)
    return rows[:30]

def file_count(path):
    p = ROOT / path
    if not p.exists():
        return 0
    return sum(1 for x in p.rglob("*") if x.is_file())

kibra = load_json("feeds/kibra_token_chain_status.json") or {}
institution = load_json("feeds/institution_audit_report.json") or {}
finance = load_json("feeds/finance_department_report.json") or {}
hash_test = load_json("feeds/hash_module_test.json") or {}
task_diag = load_json("feeds/task_diagnostics_report.json") or {}
evolution = load_json("feeds/evolution_guard_report.json") or {}

created_files = {
    "kibra_policy": exists("parliament/token_kibra/kibra_token_policy.json"),
    "kibra_image_meta": exists("token/kibra/image/token_image_meta.json"),
    "kibra_latest_block": exists("blockchain/kibra_chain/latest.block.json"),
    "kibra_latest_hash": exists("blockchain/kibra_chain/latest.block.hash"),
    "kibra_difficulty_stream": exists("blockchain/kibra_chain/difficulty_stream.jsonl"),
    "kibra_report": exists("posts/kibra_token_chain_status.md"),
    "kibra_feed": exists("feeds/kibra_token_chain_status.json"),
    "kibra_proof": exists("proofs/kibra_token_chain.sha256"),
    "finance_report": exists("posts/finance_department_report.md"),
    "institution_report": exists("posts/institution_audit_report.md"),
    "hash_report": exists("posts/hash_module_test.md"),
    "evolution_report": exists("posts/evolution_guard_report.md")
}

redis_state = {
    "parliament_queue": redis_len("cybra:parliament:queue"),
    "parliament_results": redis_len("cybra:parliament:results"),
    "parliament_failed": redis_len("cybra:parliament:failed"),
    "kibra_audit": redis_len("cybra:kibra_chain:audit"),
    "finance_ledger": redis_len("cybra:finance:ledger"),
    "finance_audit": redis_len("cybra:finance:audit"),
    "anchor_queue": redis_len("cybra:blockchain:anchor:queue"),
    "hash_audit": redis_len("cybra:hash:audit"),
    "institution_audit": redis_len("cybra:institution:audit"),
    "evolution_approved": redis_len("cybra:evolution:approved"),
    "evolution_hold": redis_len("cybra:evolution:hold"),
    "evolution_rejected": redis_len("cybra:evolution:rejected"),
    "review_approved": redis_len("cybra:review:approved"),
    "review_rejected": redis_len("cybra:review:rejected")
}

kibra_chain = kibra.get("chain", {})
kibra_token = kibra.get("token", {})
kibra_allocation = kibra.get("allocation", {})
institution_summary = institution.get("summary", {})
finance_summary = finance.get("summary", {})

recommendations = []

for rec in institution.get("recommendations", []):
    recommendations.append({
        "source": "institution",
        "level": rec.get("level"),
        "message": rec.get("message"),
        "action": rec.get("action")
    })

for rec in task_diag.get("recommendations", []):
    if isinstance(rec, dict):
        recommendations.append({
            "source": "task_diagnostics",
            "level": rec.get("level"),
            "message": rec.get("message"),
            "action": rec.get("action")
        })

if finance_summary.get("risk_items", 0):
    recommendations.append({
        "source": "finance",
        "level": "warning",
        "message": f"Finance department found {finance_summary.get('risk_items')} risk items.",
        "action": "Перевірити bash cybra_finance.sh report"
    })
else:
    recommendations.append({
        "source": "finance",
        "level": "ok",
        "message": "Finance module works in proposal-only mode: no automatic payments.",
        "action": "Для реального пулу потрібен manual OWNER approval."
    })

if redis_state["anchor_queue"] > 0:
    recommendations.append({
        "source": "blockchain_anchor",
        "level": "manual_action",
        "message": "Proof-и поставлені в чергу зовнішнього blockchain anchor.",
        "action": "Переглянути: bash cybra_kibra_chain.sh anchor-queue"
    })

if redis_state["parliament_queue"] > 0:
    recommendations.append({
        "source": "executor",
        "level": "important",
        "message": "У парламентській черзі ще є задачі.",
        "action": "Запусти: cybra worker-start && sleep 8 && cybra status"
    })

if kibra_chain.get("height", 0) > 0:
    recommendations.append({
        "source": "kibra_chain",
        "level": "ok",
        "message": "KIBRA local proof blockchain created blocks and difficulty stream.",
        "action": "Перевірити: bash cybra_kibra_chain.sh verify && bash cybra_kibra_chain.sh difficulty"
    })

results = parse_results_for_kibra()

review = {
    "status": "generated",
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "question": "Як Кіберапарламент справляється з KIBRA token chain / pool / finance / hash task?",
    "verdict": {
        "parliament_created_required_structures": all([
            created_files["kibra_policy"],
            created_files["kibra_latest_block"],
            created_files["kibra_difficulty_stream"],
            created_files["finance_report"],
            created_files["hash_report"]
        ]),
        "real_payments_executed": False,
        "real_pool_created": False,
        "manual_owner_approval_required": True
    },
    "created_files": created_files,
    "created_file_counts": {
        "parliament_token_kibra": file_count("parliament/token_kibra"),
        "token_kibra_image": file_count("token/kibra/image"),
        "blockchain_kibra_chain": file_count("blockchain/kibra_chain"),
        "kibra_blocks": file_count("blockchain/kibra_chain/blocks"),
        "posts": file_count("posts"),
        "feeds": file_count("feeds"),
        "proofs": file_count("proofs")
    },
    "redis_state": redis_state,
    "kibra": {
        "token": kibra_token,
        "allocation": kibra_allocation,
        "chain": kibra_chain,
        "latest_difficulty_stream": kibra.get("difficulty_stream_latest", [])[-10:]
    },
    "institution_summary": institution_summary,
    "finance_summary": finance_summary,
    "hash_module": hash_test,
    "evolution_summary": {
        "approved": evolution.get("approved"),
        "hold": evolution.get("hold"),
        "rejected": evolution.get("rejected"),
        "audit_records": evolution.get("audit_records")
    },
    "proof_checks": {
        "kibra_token_chain": proof_check("proofs/kibra_token_chain.sha256"),
        "finance_department": proof_check("proofs/finance_department.sha256"),
        "hash_module": proof_check("proofs/hash_module_test.sha256"),
        "institution_audit": proof_check("proofs/institution_audit_report.sha256")
    },
    "kibra_related_results": results,
    "recommendations": recommendations
}

review["double_sha"] = dsha(json.dumps(review, ensure_ascii=False, sort_keys=True))

(ROOT / "feeds/parliament_kibra_response_review.json").write_text(
    json.dumps(review, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

rec_md = ""
for r in recommendations:
    rec_md += f"- **{r.get('level')}** / `{r.get('source')}`: {r.get('message')} Action: `{r.get('action')}`\n"

created_md = ""
for k, v in created_files.items():
    created_md += f"- `{k}`: {v}\n"

proof_md = ""
for k, v in review["proof_checks"].items():
    proof_md += f"- `{k}`: {v}\n"

diff_md = ""
for x in review["kibra"]["latest_difficulty_stream"]:
    diff_md += f"- block `{x.get('index')}` difficulty `{x.get('difficulty')}` shares `{x.get('shares_count')}` pow_ok `{x.get('pow_ok')}` hash `{str(x.get('block_hash'))[:24]}...`\n"
if not diff_md:
    diff_md = "- none\n"

res_md = ""
for x in results[:10]:
    res_md += f"- `{x.get('status')}` / `{x.get('type')}` — {x.get('topic')} script=`{x.get('script')}`\n"
if not res_md:
    res_md = "- none found in latest results\n"

md = f"""# CYBRA Parliament Review: KIBRA Token Chain Response

Status: generated  
Double SHA: `{review["double_sha"]}`

## Verdict

- Parliament created required structures: **{review["verdict"]["parliament_created_required_structures"]}**
- Real payments executed: **false**
- Real pool created: **false**
- Manual OWNER approval required: **true**

## What Parliament Created

{created_md}

## Redis / Runtime State

- Parliament queue: {redis_state["parliament_queue"]}
- Parliament results: {redis_state["parliament_results"]}
- Parliament failed: {redis_state["parliament_failed"]}
- KIBRA audit: {redis_state["kibra_audit"]}
- Finance ledger: {redis_state["finance_ledger"]}
- Anchor queue: {redis_state["anchor_queue"]}
- Hash audit: {redis_state["hash_audit"]}
- Evolution approved/hold/rejected: {redis_state["evolution_approved"]}/{redis_state["evolution_hold"]}/{redis_state["evolution_rejected"]}

## KIBRA Chain

- Token: **{kibra_token.get("name")}**
- Symbol: **{kibra_token.get("symbol")}**
- Total supply: **{kibra_token.get("total_supply_raw")}**
- Owner allocation: **{kibra_allocation.get("owner_amount_raw")}**
- Pool allocation: **{kibra_allocation.get("pool_amount_raw")}**
- Chain height: **{kibra_chain.get("height")}**
- Latest hash: `{kibra_chain.get("latest_hash")}`
- Latest difficulty: **{kibra_chain.get("latest_difficulty")}**

## Difficulty Stream

{diff_md}

## Proof Checks

{proof_md}

## KIBRA-related Parliament Results

{res_md}

## Recommendations

{rec_md}

## Main conclusion

Кіберапарламент створив proof-chain, difficulty stream, finance ledger proposal, anchor queue, hash proof і звіти.  
Реальний token mint, liquidity pool або зовнішній blockchain anchor ще не виконуються автоматично — вони поставлені як manual approval stage.
"""

(ROOT / "posts/parliament_kibra_response_review.md").write_text(md, encoding="utf-8")

with (ROOT / "proofs/parliament_kibra_response_review.sha256").open("w") as f:
    subprocess.run(
        [
            "sha256sum",
            "feeds/parliament_kibra_response_review.json",
            "posts/parliament_kibra_response_review.md"
        ],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

print("✅ Parliament KIBRA response review generated")
print("Report: posts/parliament_kibra_response_review.md")
print("Feed: feeds/parliament_kibra_response_review.json")
print("Proof: proofs/parliament_kibra_response_review.sha256")
print()
print(md)
