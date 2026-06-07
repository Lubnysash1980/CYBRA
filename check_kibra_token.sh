#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1
python3 scripts/kibra/check_kibra_token_v2.py "$@"
