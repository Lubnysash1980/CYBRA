#!/usr/bin/env bash
set +e
cd /workspaces/CYBRA 2>/dev/null || cd "$PWD" || exit 1
bash scripts/codespace/cybra_codespace_patch_runner.sh
