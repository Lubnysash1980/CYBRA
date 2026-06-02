#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

echo "=== FIX KIBRA VERIFY + FINANCE FALSE POSITIVE + ANCHOR PACKAGE ==="

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

python3 - <<'PY'
from pathlib import Path

# 1. Fix KIBRA verify hash mismatch: pow_ok was added after mining and must be ignored in verification
p = Path("cybra_kibra_token_chain.py")
s = p.read_text()

old = 'remove_keys = ["block_hash", "block_double_sha", "best_hash", "best_nonce", "shares", "shares_merkle_root"]'
new = 'remove_keys = ["block_hash", "block_double_sha", "best_hash", "best_nonce", "shares", "shares_merkle_root", "pow_ok"]'

if old in s and new not in s:
    s = s.replace(old, new)
    print("✅ patched KIBRA verify remove_keys: added pow_ok")
else:
    print("ℹ KIBRA verify already patched or pattern not found")

p.write_text(s)

# 2. Fix finance false-positive scanner:
# remove broad words that trigger on safety rules like no_secret_dump / no_bank_card_data
fp = Path("cybra_finance_department.py")
if fp.exists():
    fs = fp.read_text()
    fs = fs.replace('"card",', '')
    fs = fs.replace('"секрет",', '')
    fs = fs.replace('"private key",', '"private key value",')
    fs = fs.replace('"пароль",', '"пароль до банку",')
    fp.write_text(fs)
    print("✅ patched finance risk scanner false-positive words")
else:
    print("⚠ cybra_finance_department.py not found")
PY

rm -rf __pycache__
python3 -m py_compile cybra_kibra_token_chain.py
python3 -m py_compile cybra_finance_department.py || true
rm -rf __pycache__

echo
echo "=== 1. VERIFY CURRENT KIBRA CHAIN AFTER PATCH ==="
bash cybra_kibra_chain.sh verify

echo
echo "=== 2. RUN KIBRA TASK THROUGH PARLIAMENT AGAIN ==="
bash cybra_kibra_chain.sh task

for i in $(seq 1 30); do
  echo "round=$i queue=$(redis-cli LLEN cybra:parliament:queue)"
  python3 parliament_executor_v6.py || true
  sleep 1
  [ "$(redis-cli LLEN cybra:parliament:queue)" = "0" ] && break
done

echo
echo "=== 3. VERIFY AGAIN ==="
bash cybra_kibra_chain.sh verify
bash cybra_kibra_chain.sh report >/dev/null 2>&1 || true

echo
echo "=== 4. REFRESH FINANCE REPORT ==="
bash cybra_finance.sh report >/dev/null 2>&1 || true

echo
echo "=== 5. ARCHIVE OLD FIXED FAILED RECORDS ==="
python3 - <<'PY'
import json, time
import redis

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

failed_key = "cybra:parliament:failed"
archive_key = "cybra:parliament:failed:archive"

records = r.lrange(failed_key, 0, -1)
archived = 0

for raw in records:
    try:
        obj = json.loads(raw)
    except Exception:
        continue

    t = obj.get("type")
    status = obj.get("status")
    text = json.dumps(obj, ensure_ascii=False).lower()

    reason = None

    if t == "kibra_token_chain_task" and "hash mismatch" in text:
        reason = "superseded_by_verify_pow_ok_patch"

    if status == "no_executor_mapping":
        current_mapping = r.hget("cybra:executor:mapping", t or "")
        if current_mapping:
            reason = f"old_no_mapping_fixed_now:{current_mapping}"

    if reason:
        archived_obj = {
            "archived_status": "fixed_or_superseded",
            "archive_reason": reason,
            "archived_at": time.time(),
            "original": obj
        }
        r.lpush(archive_key, json.dumps(archived_obj, ensure_ascii=False))
        r.lrem(failed_key, 1, raw)
        archived += 1

print("Archived failed records:", archived)
print("Active failed left:", r.llen(failed_key))
print("Archive:", r.llen(archive_key))
PY

echo
echo "=== 6. BUILD MANUAL EXTERNAL ANCHOR PACKAGE AND CLEAR RAW QUEUE ==="
python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path
import redis

ROOT = Path.home() / "CYBRA"
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def dsha(x):
    h1 = hashlib.sha256(x.encode("utf-8")).hexdigest()
    return hashlib.sha256(h1.encode("utf-8")).hexdigest()

queue_key = "cybra:blockchain:anchor:queue"
archive_key = "cybra:blockchain:anchor:queue:archive"
ready_key = "cybra:blockchain:anchor:manual_ready"

items = []
for raw in r.lrange(queue_key, 0, -1):
    try:
        items.append(json.loads(raw))
    except Exception:
        items.append({"raw": raw})

latest_kibra_hash = None
hfile = ROOT / "blockchain/kibra_chain/latest.block.hash"
if hfile.exists():
    latest_kibra_hash = hfile.read_text().strip()

package = {
    "status": "manual_external_anchor_package_ready",
    "automatic_onchain_tx": False,
    "manual_wallet_signature_required": True,
    "source_queue": queue_key,
    "source_items_count": len(items),
    "latest_kibra_hash": latest_kibra_hash,
    "items": items,
    "time": time.time(),
    "time_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z")
}

package["anchor_package_root"] = dsha(json.dumps(package, ensure_ascii=False, sort_keys=True))

Path("feeds").mkdir(exist_ok=True)
Path("posts").mkdir(exist_ok=True)
Path("proofs").mkdir(exist_ok=True)

Path("feeds/external_anchor_package.json").write_text(
    json.dumps(package, ensure_ascii=False, indent=2),
    encoding="utf-8"
)

md = f"""# CYBRA External Blockchain Anchor Package

Status: **manual_external_anchor_package_ready**

- Automatic on-chain tx: **false**
- Manual wallet signature required: **true**
- Source items packaged: **{len(items)}**
- Latest KIBRA hash: `{latest_kibra_hash}`
- Anchor package root: `{package["anchor_package_root"]}`

## Meaning

Proof-и з Redis anchor queue зібрані в один anchor package.  
Реальна зовнішня blockchain-транзакція не виконувалась.  
Для зовнішнього anchor треба вручну взяти `anchor_package_root` і записати його окремою on-chain транзакцією.

## Files

- `feeds/external_anchor_package.json`
- `posts/external_anchor_package.md`
- `proofs/external_anchor_package.sha256`
"""

Path("posts/external_anchor_package.md").write_text(md, encoding="utf-8")

with Path("proofs/external_anchor_package.sha256").open("w") as f:
    subprocess.run(
        ["sha256sum", "feeds/external_anchor_package.json", "posts/external_anchor_package.md"],
        cwd=ROOT,
        stdout=f,
        stderr=subprocess.DEVNULL
    )

# archive raw items and clear active queue
for raw in r.lrange(queue_key, 0, -1):
    r.lpush(archive_key, raw)

r.delete(queue_key)
r.lpush(ready_key, json.dumps(package, ensure_ascii=False))

print("✅ external anchor package ready")
print("Packaged items:", len(items))
print("Anchor package root:", package["anchor_package_root"])
print("Active anchor queue:", r.llen(queue_key))
print("Manual ready:", r.llen(ready_key))
PY

echo
echo "=== 7. REFRESH FINAL REVIEW ==="
bash review_kibra_parliament_response.sh || true

echo
echo "=== 8. FINAL CHECK ==="
cybra status || true
bash cybra_kibra_chain.sh status || true
bash cybra_finance.sh report | grep -A40 "Risk items" || true
redis-cli LRANGE cybra:parliament:failed 0 10

echo
echo "✅ FIX FINISHED"
