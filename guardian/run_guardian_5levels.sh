#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
python3 guardian/guardian_5levels.py
git add guardian proofs posts backup_levels quarantine 2>/dev/null || true
git commit -m "guardian 5-level double-sha recovery snapshot" || true
