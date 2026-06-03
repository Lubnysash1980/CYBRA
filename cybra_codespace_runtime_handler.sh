#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 0

bash cybra_codespace_runtime.sh cycle parliament-handler >/dev/null 2>&1 || true
