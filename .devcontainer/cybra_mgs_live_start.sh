#!/usr/bin/env bash
set -e
cd /workspaces/CYBRA 2>/dev/null || cd "$PWD"
mkdir -p data/cybra_mgs/{tasks,codespace} posts feeds proofs logs/mgs
python3 scripts/cybra_codespace_mgs_live_worker.py || true
echo "✅ MGS Live Codespace worker executed"
