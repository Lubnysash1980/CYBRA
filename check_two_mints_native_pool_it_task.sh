#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CHECK TWO SOLANA MINTS + NATIVE TOKEN + POOL IT TASK ==="

if [ ! -f feeds/solana_two_mints_native_pool_it_task.json ]; then
  echo "❌ Task file not found."
  echo "Run first:"
  echo "bash create_it_tasks_solana_two_mints_native_pool.sh"
  exit 1
fi

python3 - <<'PY'
import json, subprocess, hashlib, time
from pathlib import Path

ROOT = Path.home() / "CYBRA"

EXPECTED = {
    "owner": "EPEhVVhY7AXzWqcJeidWNuBqNbGDjJF35JzPVFXEbYxv",
    "alex": "BNhNw6waDiEobccELrZ483aYEqFRzYGwwHB6DLk5VnFr",
    "efi": "EfiCgx3svRwZ1voPXsnYdZo35kzyt5Ct7UHLuvnm6fcR",
    "kibra": "F5zxQyxq8qWdyauN8ArPofkKKVFxbeTAWSd1oeyazfeU",
    "usdc": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
    "base_tokens": 32000,
    "target_usdc": 2000000,
    "price": 62.5,
    "base_raw": "32000000000000",
    "usdc_raw": "2000000000000"
}

def read_json(path):
    p = ROOT / path
    if not p.exists():
        return None
    return json.loads(p.read_text(encoding="utf-8"))

def shell(cmd):
    r = subprocess.run(cmd, shell=True, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return r.returncode, r.stdout.strip()

def test(name, ok, detail=""):
    return {
        "name": name,
        "status": "PASS" if ok else "FAIL",
        "ok": bool(ok),
        "detail": detail
    }

task = read_json("feeds/solana_two_mints_native_pool_it_task.json")
tests = []

tests.append(test("task_exists", task is not None, "feeds/solana_two_mints_native_pool_it_task.json"))

if task:
    tests.append(test("status_ok", task.get("status") == "IT_TASK_TWO_SOLANA_MINTS_NATIVE_TOKEN_POOL_CREATED", task.get("status")))
    tests.append(test("owner_ok", task.get("owner_wallet") == EXPECTED["owner"], task.get("owner_wallet")))

    mints = task.get("solana_mints", {})
    native = task.get("native_token", {})
    pool = task.get("pool_target", {})
    safety = task.get("safety", {})

    tests.append(test("alex_mint_ok", mints.get("mint_1", {}).get("mint") == EXPECTED["alex"], mints.get("mint_1", {})))
    tests.append(test("efi_mint_ok", mints.get("mint_2", {}).get("mint") == EXPECTED["efi"], mints.get("mint_2", {})))
    tests.append(test("usdc_mint_ok", mints.get("quote", {}).get("mint") == EXPECTED["usdc"], mints.get("quote", {})))
    tests.append(test("native_kibra_ok", native.get("mint") == EXPECTED["kibra"], native))
    tests.append(test("native_proof_type_ok", native.get("proof_type") == "NFT_PROOF_OF_NATIVE_TOKEN", native))

    tests.append(test("pool_base_tokens_ok", pool.get("base_tokens_ui") == EXPECTED["base_tokens"], pool))
    tests.append(test("pool_target_usdc_ok", pool.get("quote_usdc_ui") == EXPECTED["target_usdc"], pool))
    tests.append(test("pool_price_ok", float(pool.get("target_price_usd_per_token", 0)) == EXPECTED["price"], pool))
    tests.append(test("base_raw_ok", str(pool.get("base_amount_raw")) == EXPECTED["base_raw"], pool.get("base_amount_raw")))
    tests.append(test("usdc_raw_ok", str(pool.get("quote_amount_raw")) == EXPECTED["usdc_raw"], pool.get("quote_amount_raw")))

    tests.append(test("alex_usdc_pair_ok", "ALEX/USDC" in pool.get("pairs_to_prepare", []), pool.get("pairs_to_prepare")))
    tests.append(test("efi_usdc_pair_ok", "EFI/USDC" in pool.get("pairs_to_prepare", []), pool.get("pairs_to_prepare")))

    tests.append(test("live_dex_false", safety.get("live_dex_create") is False, safety))
    tests.append(test("mainnet_tx_false", safety.get("real_mainnet_tx_executed") is False, safety))
    tests.append(test("market_confirmed_false", safety.get("real_market_confirmed") is False, safety))
    tests.append(test("external_tx_false", safety.get("automatic_external_tx") is False, safety))
    tests.append(test("owner_approval_required", safety.get("manual_OWNER_approval_required") is True, safety))

files = [
    "data/it_department/tasks/solana_two_mints_native_pool_task.json",
    "data/finance_department/tasks/solana_two_mints_native_pool_task.json",
    "data/kibra_dex_pool/tasks/solana_two_mints_native_pool_task.json",
    "data/native_token_nft_proof/tasks/native_token_pool_proof_task.json",
    "data/solana_two_mints_native_pool/reports/latest_report.json",
    "posts/solana_two_mints_native_pool_it_task.md",
    "proofs/solana_two_mints_native_pool_it_task.sha256"
]

for f in files:
    tests.append(test("file_exists_" + f.replace("/", "_"), (ROOT / f).exists(), f))

rc, out = shell("sha256sum -c proofs/solana_two_mints_native_pool_it_task.sha256")
tests.append(test("sha256_verify_ok", rc == 0, out[-800:]))

queues = [
    "cybra:it_department:queue",
    "cybra:finance_department:queue",
    "cybra:dex_pool:queue",
    "cybra:nft_proof:queue",
    "cybra:native_token:proof_queue",
    "cybra:parliament:queue",
    "cybra:audit:queue",
    "cybra:ai:tasks:block_inbox",
    "cybra:market_activation:queue"
]

queue_status = {}
for q in queues:
    rc, out = shell(f"redis-cli LLEN {q}")
    try:
        n = int(out.splitlines()[-1].replace("(integer)", "").strip())
    except Exception:
        n = -1
    queue_status[q] = n
    tests.append(test("queue_has_" + q.replace(":", "_"), n >= 1, f"{q}={n}"))

passed = sum(1 for t in tests if t["status"] == "PASS")
failed = sum(1 for t in tests if t["status"] == "FAIL")

report = {
    "status": "TWO_SOLANA_MINTS_NATIVE_POOL_IT_TASK_CHECK",
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "summary": {
        "pass": passed,
        "fail": failed
    },
    "queue_status": queue_status,
    "tests": tests,
    "safety": {
        "real_payment_now": False,
        "automatic_external_tx": False,
        "real_mainnet_tx_executed": False,
        "real_market_confirmed": False,
        "live_dex_create": False
    }
}

raw = json.dumps(report, ensure_ascii=False, sort_keys=True)
report["double_sha"] = hashlib.sha256(hashlib.sha256(raw.encode()).hexdigest().encode()).hexdigest()

for path in [
    "feeds/two_mints_native_pool_it_task_check.json",
    "data/solana_two_mints_native_pool/reports/latest_check.json"
]:
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

md = "# Two Solana Mints + Native Token + Pool IT Task Check\n\n"
md += f"Status: {report['status']}\n\n"
md += f"PASS: {passed}\n"
md += f"FAIL: {failed}\n\n"
md += "## Tests\n\n"
for t in tests:
    md += f"- {t['status']} — {t['name']}: {t['detail']}\n"
md += "\n## Safety\n\n"
md += "real_payment_now: false\n"
md += "automatic_external_tx: false\n"
md += "real_mainnet_tx_executed: false\n"
md += "real_market_confirmed: false\n"
md += "live_dex_create: false\n\n"
md += "## Double SHA\n\n"
md += report["double_sha"] + "\n"

(ROOT / "posts/two_mints_native_pool_it_task_check.md").write_text(md, encoding="utf-8")

with open(ROOT / "proofs/two_mints_native_pool_it_task_check.sha256", "w") as f:
    subprocess.run([
        "sha256sum",
        "feeds/two_mints_native_pool_it_task_check.json",
        "data/solana_two_mints_native_pool/reports/latest_check.json",
        "posts/two_mints_native_pool_it_task_check.md"
    ], cwd=ROOT, stdout=f)

print("=== CHECK SUMMARY ===")
print("PASS:", passed)
print("FAIL:", failed)
print("DOUBLE_SHA:", report["double_sha"])
print("REPORT: posts/two_mints_native_pool_it_task_check.md")

if failed:
    raise SystemExit(2)
PY

echo
echo "=== VERIFY CHECK REPORT ==="
sha256sum -c proofs/two_mints_native_pool_it_task_check.sha256

echo
echo "=== REPORT ==="
cat posts/two_mints_native_pool_it_task_check.md

echo
echo "✅ CHECK DONE"
