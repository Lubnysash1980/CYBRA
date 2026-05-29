#!/usr/bin/env bash
set -e

mkdir -p token/registry posts proofs logs/devnet remote_queue

if ! command -v solana >/dev/null 2>&1 || ! command -v spl-token >/dev/null 2>&1; then
  cat > remote_queue/devnet_mint_auto_capture_codespaces.task <<'TASK'
cd /workspaces/CYBRA
git pull
bash token/deploy/solana_devnet/devnet_mint_auto_capture.sh
TASK

  echo "⚠️ Solana CLI або SPL Token CLI не знайдено тут."
  echo "✅ Створено задачу для Codespaces:"
  echo "remote_queue/devnet_mint_auto_capture_codespaces.task"
  exit 0
fi

LOG="logs/devnet/mint_$(date +%Y%m%d_%H%M%S).log"

bash token/deploy/solana_devnet/deploy_cybra_spl_devnet.sh | tee "$LOG"

MINT=$(grep -Eo '[1-9A-HJ-NP-Za-km-z]{32,44}' "$LOG" | head -1)

if [ -z "$MINT" ]; then
  echo "❌ Mint address not found in deploy log"
  exit 1
fi

python3 - "$MINT" <<'PY'
import json, sys
from pathlib import Path

mint = sys.argv[1]
p = Path("token/registry/token_registry.json")
data = json.loads(p.read_text())
data["mint_address"] = mint
data["status"] = "devnet_minted"
data["network"] = "devnet"
p.write_text(json.dumps(data, indent=2), encoding="utf-8")
PY

cat > posts/cybra_devnet_mint_status.md <<MD
# CYBRA Devnet Mint

Status: deployed

Mint address:
$MINT

Network:
Solana Devnet
MD

sha256sum token/registry/token_registry.json posts/cybra_devnet_mint_status.md > proofs/cybra_devnet_mint.sha256

echo "✅ Mint captured: $MINT"
