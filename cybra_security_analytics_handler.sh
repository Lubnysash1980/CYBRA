#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"

bin/cybra-security-analytics cycle >/dev/null 2>&1 || true
