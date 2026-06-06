#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p legal/auth posts proofs

ACTION="${1:-legal_approval}"

if command -v termux-fingerprint >/dev/null 2>&1; then
  echo "🔐 Touch fingerprint для: $ACTION"
  termux-fingerprint
else
  echo "⚠️ termux-fingerprint не знайдено"
  echo "Встанови Termux:API:"
  echo "pkg install termux-api"
  echo "і додаток Termux:API з F-Droid"
  echo
  read -p "Підтвердити вручну? type YES: " OK
  [ "$OK" = "YES" ] || exit 1
fi

echo "approved_by_fingerprint_or_manual $(date -Iseconds) action=$ACTION" > legal/auth/fingerprint_approval.txt

sha256sum legal/auth/fingerprint_approval.txt > proofs/fingerprint_approval.sha256

cat > posts/fingerprint_approval_status.md <<MD
# Fingerprint Approval

Action: $ACTION  
Status: approved  
Time: $(date -Iseconds)

Proof:
proofs/fingerprint_approval.sha256
MD

echo "✅ Approved: $ACTION"
