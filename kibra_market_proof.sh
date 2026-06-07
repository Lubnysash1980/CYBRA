#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1
python3 kibra_market_proof_engine.py "$@"
