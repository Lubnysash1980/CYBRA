#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== FIX FINANCE IT CREATION TEST V2 ==="

mkdir -p data/cybra_finance/reports posts feeds proofs

cat > data/cybra_finance/keys/policy/api_key_vault_policy.md <<'EOF'
# CYBRA API Key / Secret Vault Policy

Status: ACTIVE_POLICY_DRAFT

Rules:
- Never store real API credentials in GitHub
- Never paste seed phrases, signing material, passwords, or live secrets into chat
- Use local `.env.private` or server secret manager
- chmod 600 for secret files
- Sandbox keys first
- Live credentials only after OWNER approval
- Read-only keys preferred for monitoring
- Withdrawal permissions disabled by default
EOF

python3 - <<'PY'
import json, time, hashlib, re, subprocess
from pathlib import Path

ROOT = Path.home() / "CYBRA"

expected = [
    "data/cybra_finance/contracts/drafts/bank_contract_checklist.md",
    "data/cybra_finance/contracts/drafts/psp_contract_checklist.md",
    "data/cybra_finance/contracts/drafts/merchant_onboarding_checklist.md",
    "data/cybra_finance/contracts/drafts/kyc_aml_policy_draft.md",
    "data/cybra_finance/keys/policy/api_key_vault_policy.md",
    "data/cybra_finance/live_gate/withdrawal_limits_draft.json",
    "posts/cybra_finance_it_bank_psp_task.md",
    "feeds/cybra_finance_it_bank_psp_task.json",
    "proofs/cybra_finance_it_bank_psp_task.sha256"
]

task_dir = ROOT / "data/cybra_finance/it_department/tasks"
tasks = sorted(task_dir.glob("FIN-IT-BANK-PSP-*.json")) if task_dir.exists() else []
latest_task = tasks[-1] if tasks else None

checks = {}
checks["finance_it_task_created"] = latest_task is not None

if latest_task:
    task_id = latest_task.stem
    checks["task_copied_to_mgs"] = (ROOT / "data/cybra_mgs/tasks" / f"{task_id}.json").exists()
    checks["task_copied_to_oracle"] = (ROOT / "data/cybra_oracle/tasks" / f"{task_id}.json").exists()
    try:
        data = json.loads(latest_task.read_text(encoding="utf-8"))
    except Exception:
        data = {}
    safety = data.get("safety", {})
    checks["real_payment_disabled"] = safety.get("real_payment_now") is False
    checks["swift_disabled"] = safety.get("automatic_SWIFT") is False
    checks["withdrawals_disabled"] = safety.get("automatic_withdrawals") is False
    checks["owner_approval_required"] = safety.get("manual_OWNER_approval_required") is True
    checks["do_not_store_secrets_in_git"] = safety.get("do_not_store_secrets_in_git") is True
else:
    task_id = None
    for k in ["task_copied_to_mgs","task_copied_to_oracle","real_payment_disabled","swift_disabled","withdrawals_disabled","owner_approval_required","do_not_store_secrets_in_git"]:
        checks[k] = False

for f in expected:
    checks[f"exists:{f}"] = (ROOT / f).exists()

p = subprocess.run(
    "sha256sum -c proofs/cybra_finance_it_bank_psp_task.sha256",
    shell=True, cwd=ROOT, text=True, capture_output=True
)
checks["sha256_proof_ok"] = p.returncode == 0

# V2: шукаємо тільки реальні секретні маркери, не службові слова policy.
secret_patterns = [
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    r"-----END [A-Z ]*PRIVATE KEY-----",
    r"\bAPI_SECRET\s*=",
    r"\bSECRET_KEY\s*=",
    r"\bPRIVATE_KEY\s*=",
    r"\bSEED_PHRASE\s*=",
    r"\bMNEMONIC\s*=",
    r"\bxprv[1-9A-HJ-NP-Za-km-z]+"
]

scan_dirs = [
    ROOT / "data/cybra_finance/contracts/drafts",
    ROOT / "data/cybra_finance/keys/policy",
    ROOT / "data/cybra_finance/live_gate"
]

leaks = []
for d in scan_dirs:
    if not d.exists():
        continue
    for f in d.rglob("*"):
        if not f.is_file():
            continue
        txt = f.read_text(encoding="utf-8", errors="ignore")
        for pat in secret_patterns:
            if re.search(pat, txt, flags=re.IGNORECASE):
                leaks.append(str(f.relative_to(ROOT)) + " :: " + pat)

checks["no_real_secret_markers_in_finance_files"] = len(leaks) == 0

queues = {}
for q in ["cybra_mgs_all", "cybra_oracle_tasks", "ai_block_inbox", "it_department", "parliament_inbox", "cybra_finance_evolution"]:
    r = subprocess.run(f"redis-cli LLEN {q} 2>/dev/null || echo 0", shell=True, cwd=ROOT, text=True, capture_output=True)
    v = (r.stdout or "0").strip()
    queues[q] = int(v) if v.isdigit() else 0

passed = sum(1 for v in checks.values() if v is True)
total = len(checks)
score = round((passed / total) * 100, 2) if total else 0

report = {
    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "status": "FINANCE_IT_CREATION_TEST_PASS" if score == 100 else "FINANCE_IT_CREATION_TEST_PARTIAL",
    "score_percent": score,
    "task_id": task_id,
    "latest_task_file": str(latest_task.relative_to(ROOT)) if latest_task else None,
    "checks": checks,
    "redis_queues": queues,
    "secret_leaks": leaks,
    "test_version": "v2_strict_real_secret_markers_only",
    "safety": {
        "real_payment_now": False,
        "automatic_SWIFT": False,
        "automatic_withdrawals": False,
        "bank_live_mode": False,
        "psp_live_mode": False,
        "manual_OWNER_approval_required": True
    }
}

out_json = ROOT / "data/cybra_finance/reports/finance_it_bank_psp_creation_test_latest.json"
out_feed = ROOT / "feeds/cybra_finance_it_bank_psp_creation_test.json"
out_md = ROOT / "posts/cybra_finance_it_bank_psp_creation_test.md"
proof = ROOT / "proofs/cybra_finance_it_bank_psp_creation_test.sha256"

out_json.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
out_feed.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

lines = [
    "# Finance IT Bank/PSP Creation Test",
    "",
    f"Timestamp: {report['timestamp']}",
    f"Status: **{report['status']}**",
    f"Score: **{score}%**",
    f"Task ID: `{task_id}`",
    f"Test version: `{report['test_version']}`",
    "",
    "## Checks"
]
for k, v in checks.items():
    lines.append(f"- {k}: `{v}`")

lines += ["", "## Redis queues"]
for k, v in queues.items():
    lines.append(f"- {k}: `{v}`")

lines += [
    "",
    "## Secret leaks",
    f"`{leaks}`",
    "",
    "## Safety",
    "- real_payment_now: false",
    "- automatic_SWIFT: false",
    "- automatic_withdrawals: false",
    "- bank_live_mode: false",
    "- psp_live_mode: false",
    "- manual_OWNER_approval_required: true"
]

out_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

proof.write_text(
    f"{sha(out_json)}  data/cybra_finance/reports/finance_it_bank_psp_creation_test_latest.json\n"
    f"{sha(out_feed)}  feeds/cybra_finance_it_bank_psp_creation_test.json\n"
    f"{sha(out_md)}  posts/cybra_finance_it_bank_psp_creation_test.md\n",
    encoding="utf-8"
)

print(json.dumps(report, ensure_ascii=False, indent=2))
PY

echo
cat posts/cybra_finance_it_bank_psp_creation_test.md
echo
sha256sum -c proofs/cybra_finance_it_bank_psp_creation_test.sha256

echo "✅ V2 TEST DONE"
