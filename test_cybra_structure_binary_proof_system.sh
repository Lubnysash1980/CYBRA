#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== CYBRA SMOKE TEST FIX/RUN ==="

mkdir -p data/cybra_structure_autocollector/tests posts feeds proofs logs/structure

# 1. Якщо є головна команда структури — запускаємо збірку
if command -v cybra-structure-fix >/dev/null 2>&1; then
  cybra-structure-fix all >/tmp/cybra_structure_fix.log 2>&1 || true
elif [ -x ./cybra-structure-fix ]; then
  ./cybra-structure-fix all >/tmp/cybra_structure_fix.log 2>&1 || true
fi

# 2. Якщо є token-check — запускаємо
if [ -x ./check_kibra_token.sh ]; then
  bash ./check_kibra_token.sh >/tmp/cybra_token_check.log 2>&1 || true
fi

python3 - <<'PY'
import json, time, hashlib, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

def exists(p):
    return (ROOT / p).exists()

def read_json(p):
    try:
        return json.loads((ROOT / p).read_text(encoding="utf-8"))
    except Exception:
        return {}

def write_json(p, data):
    path = ROOT / p
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(p, text):
    path = ROOT / p
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")

def sha(p):
    return hashlib.sha256((ROOT / p).read_bytes()).hexdigest()

def proof_ok(p):
    if not exists(p):
        return False
    r = subprocess.run(f"sha256sum -c {p}", shell=True, cwd=ROOT, text=True, capture_output=True)
    return r.returncode == 0

structure = read_json("data/cybra_structure_autocollector/structure_scan_latest.json")
binary = read_json("data/cybra_binary_safe/binary_rewrite_report_latest.json")
token = read_json("data/cybra_token/checks/kibra_token_check_latest.json")
state = read_json("blockchain/kibra_chain/mainnet/state/latest_state.json")
ai = read_json("data/cybra_usha_tunnel/reports/ai_block_usha_route_latest.json")

checks = {
    "cybra_structure_fix_command_exists": exists("cybra-structure-fix"),
    "structure_department_exists": exists("data/cybra_it_department/structure_department/department.json"),
    "binary_department_exists": exists("data/cybra_it_department/binary_rewrite_subdepartment/department.json"),
    "proof_department_exists": exists("data/cybra_it_department/proof_department/department.json"),

    "structure_scan_exists": exists("data/cybra_structure_autocollector/structure_scan_latest.json"),
    "structure_has_files": int(structure.get("files_count", 0) or 0) > 0,

    "binary_report_exists": exists("data/cybra_binary_safe/binary_rewrite_report_latest.json"),
    "binary_blobs_created": int(binary.get("binary_blob_count", 0) or 0) > 0,

    "ai_block_route_exists": exists("data/cybra_usha_tunnel/reports/ai_block_usha_route_latest.json"),
    "ai_block_has_task_id": bool(ai.get("task_id")),

    "usha_outbox_exists": exists("data/cybra_usha_tunnel/outbox"),
    "proof_department_report_exists": exists("data/cybra_proof_department/reports/proof_department_latest.json"),
    "multicurrency_proof_exists": exists("data/cybra_proof_department/multicurrency/proof_account_latest.json"),
    "token_proof_exists": exists("data/cybra_proof_department/tokens/kibra_token_proof_latest.json"),

    "token_check_exists": exists("data/cybra_token/checks/kibra_token_check_latest.json"),
    "token_wallet_in_state": token.get("checks", {}).get("wallet_in_state") is True,
    "token_wallet_claim_ok": token.get("checks", {}).get("wallet_claim_ok") is True,

    "kibra_state_exists": exists("blockchain/kibra_chain/mainnet/state/latest_state.json"),
    "kibra_external_live_false": state.get("external_live") is False,
    "kibra_no_withdrawals": state.get("safety", {}).get("automatic_withdrawals") is False,
    "kibra_no_swift": state.get("safety", {}).get("automatic_SWIFT") is False,

    "final_structure_proof_ok": proof_ok("proofs/cybra_structure_binary_proof_system.sha256") if exists("proofs/cybra_structure_binary_proof_system.sha256") else False,
    "token_check_proof_ok": proof_ok("proofs/kibra_token_check.sha256") if exists("proofs/kibra_token_check.sha256") else False,
}

passed = sum(1 for v in checks.values() if v is True)
total = len(checks)
score = round((passed / total) * 100, 2) if total else 0
status = "CYBRA_STRUCTURE_BINARY_PROOF_SMOKE_TEST_PASS" if score == 100 else "CYBRA_STRUCTURE_BINARY_PROOF_SMOKE_TEST_PARTIAL"

report = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "status": status,
    "score_percent": score,
    "passed": passed,
    "total": total,
    "checks": checks,
    "structure_files_count": structure.get("files_count"),
    "binary_blob_count": binary.get("binary_blob_count"),
    "ai_task_id": ai.get("task_id"),
    "token_status": token.get("status"),
    "kibra_height": state.get("latest_height"),
    "safety": {
        "real_payment_now": False,
        "automatic_external_tx": False,
        "automatic_withdrawals": False,
        "automatic_SWIFT": False,
        "automatic_real_rewards": False
    }
}

write_json("data/cybra_structure_autocollector/tests/structure_binary_proof_smoke_test_latest.json", report)
write_json("feeds/cybra_structure_binary_proof_smoke_test.json", report)

lines = [
    "# CYBRA Structure Binary Proof Smoke Test",
    "",
    f"Status: **{status}**",
    f"Score: **{score}%**",
    f"Passed: `{passed}/{total}`",
    "",
    "## Checks"
]
for k, v in checks.items():
    lines.append(f"- {k}: `{v}`")

lines += [
    "",
    "## Safety",
    "- real_payment_now: false",
    "- automatic_external_tx: false",
    "- automatic_withdrawals: false",
    "- automatic_SWIFT: false",
    "- automatic_real_rewards: false",
    ""
]

write_text("posts/cybra_structure_binary_proof_smoke_test.md", "\n".join(lines))

targets = [
    "data/cybra_structure_autocollector/tests/structure_binary_proof_smoke_test_latest.json",
    "feeds/cybra_structure_binary_proof_smoke_test.json",
    "posts/cybra_structure_binary_proof_smoke_test.md",
]

write_text("proofs/cybra_structure_binary_proof_smoke_test.sha256", "".join(
    f"{sha(p)}  {p}\n" for p in targets
))

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

echo
echo "=== REPORT ==="
cat posts/cybra_structure_binary_proof_smoke_test.md

echo
echo "=== PROOF ==="
sha256sum -c proofs/cybra_structure_binary_proof_smoke_test.sha256
