#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1


mkdir -p runtime/redis
if ! redis-cli ping >/dev/null 2>&1; then
  redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir "$HOME/CYBRA/runtime/redis" --save "" --appendonly no >/dev/null 2>&1 || true
  sleep 1
fi

echo "=== CYBRA WHAT IS MISSING TEST ==="
echo

missing=0

check_file(){
  if [ -e "$1" ]; then
    echo "✅ $1"
  else
    echo "❌ MISSING: $1"
    missing=$((missing+1))
  fi
}

check_cmd(){
  if command -v "$1" >/dev/null 2>&1; then
    echo "✅ command: $1"
  else
    echo "❌ MISSING COMMAND: $1"
    missing=$((missing+1))
  fi
}

echo "=== 1. Termux Menu-Bar ==="
check_file cybra_menubar.sh
check_file cybra_menubar.py
check_file cybra_menubar_handler.sh
check_file posts/cybra_menubar_report.md
check_file feeds/cybra_menubar_report.json
check_file proofs/cybra_menubar.sha256
check_cmd cybra-menu

echo
echo "=== 2. Recovery / AutoRecovery ==="
check_file cybra_recovery.sh
check_file bin/cybra-recover
check_file cybra_menu_recovery_bridge.sh
check_file cybra_termux_restore.sh
check_file posts/cybra_autorecovery_report.md
check_file feeds/cybra_autorecovery_report.json
check_file proofs/cybra_autorecovery.sha256
check_file data/cybra_autorecovery/packs/cybra_restore_pack.tar.gz
check_file posts/cybra_menubar_recovery_test_report.md
check_file proofs/cybra_menubar_recovery_test.sha256

echo
echo "=== 3. AutoHeal / Security / Conformation ==="
check_file cybra_autoheal.sh
check_file cybra_security_analytics.sh
check_file cybra_conformation8.sh
check_file posts/cybra_autoheal_7lvl_report.md
check_file posts/cybra_security_analytics_report.md
check_file posts/cybra_conformation8_report.md

echo
echo "=== 4. Dashboard / Codespace / GitHub ==="
check_file cybra_dashboard.sh
check_file cybra_dashboard.py
check_file cybra_codespace_runtime.sh
check_file cybra_codespace_runtime.py
check_file .devcontainer/devcontainer.json
check_file .github/workflows/cybra-codespace-runtime.yml
check_file posts/cybra_codespace_runtime_report.md
check_file proofs/cybra_codespace_runtime.sha256

echo
echo "=== 5. Finance / KIBRA ==="
check_file kybra_valid.sh
check_file cybra_payment_requisites.sh
check_file cybra_market_proof_collector.sh
check_file cybra_real_market_price_gate.sh
check_file cybra_kibra_stats.sh
check_file cybra_mint_promo.sh
check_file cybra_ai_blocks.sh
check_file posts/kibra_stats_recommendations_report.md
check_file posts/cybra_mint_promo_report.md
check_file posts/cybra_ai_blocks_report.md

echo
echo "=== 6. Parliament / Committees ==="
check_file parliament_executor_v6.py
check_file parliament/committees/termux_menubar_committee/committee.json
check_file parliament/committees/codespace_runtime_committee/committee.json
check_file parliament/committees/frozen_license_committee/committee.json

echo
echo "=== 7. Redis ==="
if redis-cli ping >/dev/null 2>&1; then
  echo "✅ Redis PONG"
else
  echo "❌ Redis not running"
  missing=$((missing+1))
fi

echo
echo "=== 8. Live status ==="
cybra-menu status 2>/dev/null || bash cybra_menubar.sh status 2>/dev/null || echo "❌ menu status failed"
echo

echo "=== RESULT ==="
echo "Missing count: $missing"

if [ "$missing" -eq 0 ]; then
  echo "✅ Нічого критичного по файлах не бракує."
  echo "Далі лишаються бізнес-блокери: IBAN/PSP і real market proof."
else
  echo "❌ Є відсутні файли/команди. Дивись MISSING вище."
fi
