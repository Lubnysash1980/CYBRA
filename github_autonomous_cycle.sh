#!/data/data/com.termux/files/usr/bin/bash
set +e

if [ -n "$CYBRA_WORKDIR" ]; then
  cd "$CYBRA_WORKDIR" || exit 1
else
  cd "$HOME/CYBRA" || exit 1
fi

ENV_NAME="${1:-local}"

mkdir -p runtime/redis logs/github_autonomy posts feeds proofs data/cybra_github_autonomy

if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$(pwd)/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

python3 cybra_github_autonomy.py cycle "$ENV_NAME"
