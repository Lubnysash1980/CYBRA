#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 modules/answer_engine/answer_engine.py
git add modules/answer_engine generated_scripts posts proofs 2>/dev/null || true
git commit -m "run self expanding answer engine" || true
