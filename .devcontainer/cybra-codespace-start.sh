#!/usr/bin/env bash
set +e
cd /workspaces/* 2>/dev/null || cd "$PWD" || exit 0
rm -f "$HOME/CYBRA" 2>/dev/null || true
ln -s "$PWD" "$HOME/CYBRA" 2>/dev/null || true
mkdir -p logs/hybrid
bash scripts/cybra_codespace_limited_bg.sh >> logs/hybrid/codespace_poststart.log 2>&1 || true
