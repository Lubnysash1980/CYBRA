#!/usr/bin/env bash
set -e
cd /workspaces/CYBRA 2>/dev/null || cd ~/CYBRA
git pull --rebase || git pull
echo "✅ Codespaces pulled latest CYBRA"
