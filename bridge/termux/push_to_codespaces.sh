#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
git add bridge remote_queue posts/codespace_termux_bridge_status.md feeds/codespace_termux_bridge.json proofs/codespace_termux_bridge.sha256 cybra_codespace_termux_bridge_patch.sh .cybra_bridge_patch_installed 2>/dev/null || true
git commit -m "sync Termux bridge patch" || true
git push
echo "✅ Termux bridge pushed"
