#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p token/runtime token/health token/autofix token/hash_backend posts proofs

MODE="${1:-devnet}"

case "$MODE" in
  test|devnet|mainnet) ;;
  *)
    echo "Usage: bash cybra_chain_environment_autofix.sh test|devnet|mainnet"
    exit 1
    ;;
esac

cat > token/runtime/chain_env.json <<JSON
{
  "active_mode": "$MODE",
  "allowed_modes": ["test", "devnet", "mainnet"],
  "mainnet_requires_owner_approval": true,
  "mainnet_requires_double_sha": true,
  "mainnet_requires_health_ok": true
}
JSON

cat > token/hash_backend/double_sha_backend.py <<'PY'
#!/usr/bin/env python3
import hashlib, json, sys
from pathlib import Path

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def double_sha(data: bytes) -> str:
    return hashlib.sha256(hashlib.sha256(data).digest()).hexdigest()

files = sys.argv[1:]
result = {}

for f in files:
    p = Path(f)
    if p.exists() and p.is_file():
        data = p.read_bytes()
        result[str(p)] = {
            "sha256": sha256(data),
            "double_sha256": double_sha(data),
            "size": len(data)
        }

Path("token/hash_backend/double_sha_report.json").write_text(
    json.dumps(result, indent=2, ensure_ascii=False),
    encoding="utf-8"
)

print(json.dumps(result, indent=2, ensure_ascii=False))
PY

chmod +x token/hash_backend/double_sha_backend.py

python3 token/hash_backend/double_sha_backend.py \
  token/coin/cybra_metadata.json \
  token/assets/cybra.png \
  token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh \
  token/runtime/chain_env.json \
  > token/hash_backend/latest_double_sha.json

HEALTH_OK=true

[ -f token/coin/cybra_metadata.json ] || HEALTH_OK=false
[ -f token/assets/cybra.png ] || HEALTH_OK=false
[ -s token/assets/cybra.png ] || HEALTH_OK=false
[ -f token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh ] || HEALTH_OK=false
[ -f token/hash_backend/latest_double_sha.json ] || HEALTH_OK=false

MAINNET_READY=false
FINAL_APPROVAL=false

if [ -f token/runtime/FINAL_MAINNET_APPROVAL.flag ]; then
  FINAL_APPROVAL=true
fi

if [ "$MODE" = "mainnet" ]; then
  if [ "$HEALTH_OK" = "true" ] && [ "$FINAL_APPROVAL" = "true" ] && grep -q '"owner_approval": true' token/runtime/mainnet_gate.json 2>/dev/null && grep -q '"double_sha_valid": true' token/runtime/mainnet_gate.json 2>/dev/null; then
    MAINNET_READY=true
  fi
fi

cat > token/health/token_health.json <<JSON
{
  "mode": "$MODE",
  "health_ok": $HEALTH_OK,
  "mainnet_ready": $MAINNET_READY,
  "final_mainnet_approval": $FINAL_APPROVAL,
  "checks": {
    "metadata": "$(test -f token/coin/cybra_metadata.json && echo ok || echo missing)",
    "logo": "$(test -s token/assets/cybra.png && echo ok || echo missing_or_empty)",
    "devnet_script": "$(test -f token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh && echo ok || echo missing)",
    "double_sha_backend": "$(test -f token/hash_backend/latest_double_sha.json && echo ok || echo missing)"
  }
}
JSON

cat > token/autofix/token_autofix.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/CYBRA"

mkdir -p token/assets token/coin token/deploy/solana_devnet posts proofs

[ -f token/coin/cybra_metadata.json ] || cat > token/coin/cybra_metadata
cat >> cybra_chain_environment_autofix.sh <<'EOF'
.json <<'JSON'
{
  "name": "CYBRA Coin",
  "symbol": "CYBRA",
  "description": "CYBRA SPL-ready coin metadata. Devnet first. Mainnet only after owner approval.",
  "image": "token/assets/cybra.png",
  "chain": "solana_devnet_first",
  "decimals": 9,
  "status": "wallet_visible_prepare"
}
JSON

if [ ! -s token/assets/cybra.png ]; then
  printf 'CYBRA PNG PLACEHOLDER\n' > token/assets/cybra.png
fi

[ -f token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh ] || cat > token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
echo "CYBRA Devnet deploy placeholder"
echo "Requires: solana CLI + spl-token"
echo "Devnet only. No private keys in logs."
SH

chmod +x token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh

echo "✅ token autofix completed"
BASH

chmod +x token/autofix/token_autofix.sh

cat > posts/cybra_chain_environment_status.md <<MD
# CYBRA Chain Environment

Mode: $MODE

Health:
$HEALTH_OK

Mainnet ready:
$MAINNET_READY

Layers:
- AutoFix
- AutoHealth
- Double-SHA Backend
- Mode switcher: test/devnet/mainnet

Mainnet:
locked unless owner approval + double SHA + health OK.
MD

sha256sum \
  token/runtime/chain_env.json \
  token/health/token_health.json \
  token/hash_backend/double_sha_backend.py \
  token/hash_backend/latest_double_sha.json \
  token/autofix/token_autofix.sh \
  posts/cybra_chain_environment_status.md \
  > proofs/cybra_chain_environment.sha256

echo "✅ CYBRA chain environment prepared: $MODE"
