#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p owner/protection posts proofs sha/protection

cat > owner/protection/owner_profile.json <<'JSON'
{
  "owner": "Грабовський Олександр Миколайович",
  "role": "CYBRA owner / protected person",
  "protection_mode": "legal_digital_watchdog",
  "rules": [
    "no private data in public logs",
    "no unauthorized actions",
    "legal response only",
    "audit every critical event",
    "double_sha_proof_required"
  ],
  "modules": [
    "watchdog",
    "autoheal",
    "autofix",
    "sha_core",
    "legal_watchdog",
    "emergency_alert",
    "proof_archive"
  ]
}
JSON

cat > posts/owner_protection_status.md <<'MD'
# Owner Protection Profile

Owner:
Грабовський Олександр Миколайович

Status:
active

Mode:
legal / digital / watchdog protection

Rules:
- no private data in public logs
- legal response only
- audit critical events
- double SHA proof required
MD

sha256sum owner/protection/owner_profile.json posts/owner_protection_status.md > proofs/owner_protection.sha256
cp owner/protection/owner_profile.json sha/protection/owner_profile.json

echo "✅ Owner protection profile activated"
