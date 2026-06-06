#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1
mkdir -p dist scripts/mihailka patches/mihailka proofs

cat > dist/mihailka_cybra_launcher.sh <<'MIH'
#!/data/data/com.termux/files/usr/bin/bash
set +e

echo "=== MIHAILKA CYBRA LAUNCHER ==="

pkg update -y || true
pkg install -y git python redis openssh jq curl gh termux-api || true

cd "$HOME" || exit 1

if [ ! -d "$HOME/CYBRA/.git" ]; then
  git clone https://github.com/Lubnysash1980/CYBRA.git "$HOME/CYBRA" || exit 1
fi

cd "$HOME/CYBRA" || exit 1
git pull --rebase origin main || true

mkdir -p runtime/redis logs/mihailka

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes \
    --bind 127.0.0.1 \
    --port 6379 \
    --dir "$HOME/CYBRA/runtime/redis" \
    --save "" \
    --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

chmod +x cybra-bar 2>/dev/null || true
ln -sf "$HOME/CYBRA/cybra-bar" "$PREFIX/bin/cybra-bar" 2>/dev/null || true

bash scripts/termux/cybra_termux_patch_runner.sh > logs/mihailka/start_patch.log 2>&1 || true

echo
echo "✅ MIHAILKA READY"
echo "Run:"
echo "  cd ~/CYBRA"
echo "  cybra-bar"
echo
MIH

chmod +x dist/mihailka_cybra_launcher.sh

sha256sum dist/mihailka_cybra_launcher.sh > proofs/mihailka_cybra_launcher.sha256

python3 scripts/cybra_patch_signer.py \
  "MIHAILKA_LAUNCHER_PATCH" \
  "Mihailka extra launcher patch" \
  "patches/mihailka/MIHAILKA_LAUNCHER_PATCH.json" \
  "Standalone launcher для іншого Android Termux/додатку: clone CYBRA, install deps, start Redis, activate cybra-bar."

echo "✅ Built dist/mihailka_cybra_launcher.sh"
