#!/bin/bash
cd ~/CYBRA

export CYBRA_LIVE_MODE=true
export CYBRA_PAPER_MODE=false
export CYBRA_TESTNET=false
export CYBRA_REAL_TRADING=true

# Запуск нового бота напряму
node trading_bot/v64/modules/64/module_64_live_ready.mjs > logs/live_bot.log 2>&1 &

echo $! > pids/live_bot.pid
echo "✅ Live бот запущено з PID: $(cat pids/live_bot.pid)"
echo "📋 Логи: tail -f logs/live_bot.log"
