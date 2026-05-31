#!/data/data/com.termux/files/usr/bin/bash
set -e

PATCH_FLAG=".cybra_bridge_patch_installed"

mkdir -p bridge/termux bridge/codespaces remote_queue posts proofs feeds

if [ -f "$PATCH_FLAG" ]; then
  echo "✅ Bridge patch already installed"
else
  cat > bridge/termux/push_to_codespaces.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
git add bridge remote_queue posts/codespace_termux_bridge_status.md feeds/codespace_termux_bridge.json proofs/codespace_termux_bridge.sha256 cybra_codespace_termux_bridge_patch.sh .cybra_bridge_patch_installed 2>/dev/null || true
git commit -m "sync Termux bridge patch" || true
git push
echo "✅ Termux bridge pushed"
BASH

  cat > bridge/termux/pull_from_codespaces.sh <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$HOME/CYBRA"
git pull --rebase || git pull
echo "✅ Termux pulled latest CYBRA"
BASH

  cat > bridge/codespaces/pull_from_termux.sh <<'BASH'
#!/usr/bin/env bash
set -e
cd /workspaces/CYBRA 2>/dev/null || cd ~/CYBRA
git pull --rebase || git pull
echo "✅ Codespaces pulled latest CYBRA"
BASH

  cat > bridge/codespaces/push_to_termux.sh <<'BASH'
#!/usr/bin/env bash
set -e
cd /workspaces/CYBRA 2>/dev/null || cd ~/CYBRA
git add token posts proofs feeds remote_queue bridge 2>/dev/null || true
git commit -m "sync Codespaces results to Termux" || true
git push
echo "✅ Codespaces pushed results"
BASH

  chmod +x bridge/termux/*.sh bridge/codespaces/*.sh
  date -Iseconds > "$PATCH_FLAG"
fi

cat > remote_queue/codespaces_startup.task <<'TASK'
cd /workspaces/CYBRA 2>/dev/null || cd ~/CYBRA
bash bridge/codespaces/pull_from_termux.sh
bash token/devnet/devnet_preflight_check.sh || true
cat token/registry/token_registry.json 2>/dev/null || true
cat posts/cybra_devnet_mint_status.md 2>/dev/null || true
TASK

cat > posts/codespace_termux_bridge_status.md <<'MD'
# CYBRA Codespaces-Termux Bridge

Status: installed

Commands:
- bridge/termux/push_to_codespaces.sh
- bridge/termux/pull_from_codespaces.sh
- bridge/codespaces/pull_from_termux.sh
- bridge/codespaces/push_to_termux.sh

Startup:
bash remote_queue/codespaces_startup.task
MD

cat > feeds/codespace_termux_bridge.json <<'JSON'
{
  "status": "installed",
  "bridge": "termux_codespaces",
  "sync": "github",
  "autopatch": true
}
JSON

sha256sum \
  bridge/termux/*.sh \
  bridge/codespaces/*.sh \
  remote_queue/codespaces_startup.task \
  posts/codespace_termux_bridge_status.md \
  feeds/codespace_termux_bridge.json \
  > proofs/codespace_termux_bridge.sha256

echo "✅ CYBRA Codespaces-Termux bridge patch installed"
