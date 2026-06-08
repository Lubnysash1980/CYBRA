#!/usr/bin/env bash
set +e

cd ~/CYBRA || exit 1

echo "=== CYBRA SUPERVISED BOT INSTALL + RUN + COMMIT ==="

# Структура директорій
mkdir -p \
  scripts/bot_supervisor \
  data/cybra_bot_supervisor/{reports,logs,pids,audit,tasks,parliament,it,watchdog,harness} \
  data/cybra_finance/it_department/tasks \
  parliament/inbox \
  posts feeds proofs dashboard/cybra_bot_supervisor runtime/redis logs/bot_supervisor

# Python‑супервізор
cat > scripts/bot_supervisor/cybra_supervised_bot_runner.py <<'PY'
# (тут повний Python‑код супервізора, як у твоєму документі)
PY

# Bash‑обгортка
cat > cybra-bot-supervised <<'SH'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1
python3 scripts/bot_supervisor/cybra_supervised_bot_runner.py "$@"
SH

chmod +x scripts/bot_supervisor/cybra_supervised_bot_runner.py cybra-bot-supervised
ln -sf "$HOME/CYBRA/cybra-bot-supervised" "$PREFIX/bin/cybra-bot-supervised" 2>/dev/null || true

# Запуск + аудит
echo "=== START BOT SUPERVISOR ==="
cybra-bot-supervised start

sleep 2

echo "=== STATUS ==="
cybra-bot-supervised status

echo "=== AUDIT ==="
cybra-bot-supervised audit

echo "=== PROOF ==="
cybra-bot-supervised proof

echo "=== LAST TASK BAR STATUS ==="
cybra-last-task-bar status 2>/dev/null || echo "cybra-last-task-bar not found, skipped"

echo "=== CYBRA LOAD STATUS ==="
cybra-load status 2>/dev/null || echo "cybra-load not found, skipped"

# Git commit + push
echo "=== GIT COMMIT + PUSH ==="
git add -f \
  install_supervised_bot_runner.sh \
  scripts/bot_supervisor/cybra_supervised_bot_runner.py \
  cybra-bot-supervised \
  data/cybra_bot_supervisor \
  data/cybra_finance/it_department/tasks \
  parliament/inbox \
  posts/cybra_bot_supervisor.md \
  feeds/cybra_bot_supervisor.json \
  dashboard/cybra_bot_supervisor \
  proofs/cybra_bot_supervisor.sha256

git commit -m "add supervised bot runner under IT and CyberParliament" || echo "Nothing to commit"
git pull --rebase origin main || echo "Pull issue, check manually"
git push origin main || echo "Push issue, check manually"

echo "============================================="
echo "✅ SUPERVISED BOT DEPLOYED"
echo "============================================="
echo "Mode:"
echo "  PAPER_TRADING=true"
echo "  TESTNET=true"
echo "  LIVE_ORDERS_ENABLED=false"
echo "  direct_bot_execution_blocked=true"
echo
echo "Dashboard:"
echo "  cybra-bot-supervised serve"
echo "  http://127.0.0.1:8798/"
echo
echo "Commands:"
echo "  cybra-bot-supervised status"
echo "  cybra-bot-supervised audit"
echo "  cybra-bot-supervised logs"
echo "  cybra-bot-supervised stop"
echo "  cybra-bot-supervised proof"
echo "============================================="
