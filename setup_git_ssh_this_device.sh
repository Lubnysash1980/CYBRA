#!/usr/bin/env bash
set +e

echo "=== SETUP GIT SSH FOR THIS DEVICE ==="

GITHUB_USER="${GITHUB_USER:-Lubnysash1980}"
REPO_NAME="${REPO_NAME:-CYBRA}"
KEY_NAME="${KEY_NAME:-id_ed25519_cybra_termux}"
KEY_PATH="$HOME/.ssh/$KEY_NAME"
PUB_PATH="$KEY_PATH.pub"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Install only if missing. No pkg update/upgrade.
if ! command -v git >/dev/null 2>&1; then
  pkg install -y git || true
fi

if ! command -v ssh >/dev/null 2>&1; then
  pkg install -y openssh || true
fi

# Generate SSH key if absent
if [ ! -f "$KEY_PATH" ]; then
  echo "Creating new SSH key: $KEY_PATH"
  ssh-keygen -t ed25519 -C "$GITHUB_USER-termux-cybra-$(date +%Y%m%d)" -f "$KEY_PATH"
else
  echo "SSH key already exists: $KEY_PATH"
fi

chmod 600 "$KEY_PATH"
chmod 644 "$PUB_PATH" 2>/dev/null || true

# SSH config
cat > "$HOME/.ssh/config" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
  AddKeysToAgent yes
  StrictHostKeyChecking accept-new
EOF

chmod 600 "$HOME/.ssh/config"

# Start ssh-agent if available
eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
ssh-add "$KEY_PATH" >/dev/null 2>&1 || true

echo
echo "=== PUBLIC SSH KEY ==="
cat "$PUB_PATH"
echo
echo "=== IMPORTANT ==="
echo "Додай цей PUBLIC key у GitHub:"
echo "GitHub → Settings → SSH and GPG keys → New SSH key"
echo
echo "НЕ копіюй приватний файл:"
echo "$KEY_PATH"
echo

# If gh exists and is logged in, optionally add key automatically
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI logged in. Trying to add SSH key automatically..."
    gh ssh-key add "$PUB_PATH" -t "Termux CYBRA $(date +%Y-%m-%d)" >/dev/null 2>&1 \
      && echo "✅ SSH key added to GitHub via gh" \
      || echo "⚠️ Could not add key via gh, add it manually."
  else
    echo "gh exists but not logged in. Manual GitHub key add required."
  fi
fi

# Set CYBRA repo remote to SSH if repo exists
if [ -d "$HOME/CYBRA/.git" ]; then
  cd "$HOME/CYBRA" || exit 0
  git remote set-url origin "git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
  echo
  echo "Remote changed to:"
  git remote -v
fi

echo
echo "=== TEST SSH ==="
ssh -T git@github.com || true

echo
echo "✅ SSH Git setup done"
echo
echo "Next checks:"
echo "  cd ~/CYBRA"
echo "  git remote -v"
echo "  ssh -T git@github.com"
echo "  git status"
