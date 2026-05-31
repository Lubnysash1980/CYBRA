#!/usr/bin/env bash
set -e
cd /workspaces/CYBRA 2>/dev/null || cd ~/CYBRA
git add token posts proofs feeds remote_queue bridge 2>/dev/null || true
git commit -m "sync Codespaces results to Termux" || true
git push
echo "✅ Codespaces pushed results"
