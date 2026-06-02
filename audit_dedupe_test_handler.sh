#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

mkdir -p posts feeds proofs logs/audit

TS="$(date -Iseconds)"

cat > feeds/audit_dedupe_test.json <<JSON
{
  "status": "executed",
  "handler": "audit_dedupe_test_handler.sh",
  "time": "$TS"
}
JSON

cat > posts/audit_dedupe_test.md <<MD
# CYBRA Audit Dedupe Test

Status: executed  
Time: $TS
MD

sha256sum feeds/audit_dedupe_test.json posts/audit_dedupe_test.md > proofs/audit_dedupe_test.sha256

echo "✅ AUDIT DEDUPE TEST EXECUTED"
