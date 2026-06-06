#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== TERMUX API / FINGERPRINT AUTOFIX ==="

echo
echo "[1] Installing Termux API package..."
pkg install -y termux-api

echo
echo "[2] Checking command..."
if command -v termux-fingerprint >/dev/null 2>&1; then
  echo "✅ termux-fingerprint command exists"
else
  echo "❌ termux-fingerprint command missing"
  exit 1
fi

echo
echo "[3] Opening Termux:API download page..."
echo "Install Android app Termux:API from F-Droid:"
echo "https://f-droid.org/packages/com.termux.api/"

termux-open-url https://f-droid.org/packages/com.termux.api/ 2>/dev/null || true

echo
echo "Після встановлення Termux:API:"
echo "1. Відкрий додаток Termux:API один раз"
echo "2. Дозволь permissions, якщо Android запитає"
echo "3. Повернись у Termux"
echo
read -p "Коли встановив і відкрив Termux:API, напиши YES: " OK

if [ "$OK" != "YES" ]; then
  echo "Зупинено. Запусти скрипт ще раз після встановлення."
  exit 1
fi

echo
echo "[4] Testing fingerprint..."
termux-fingerprint || {
  echo
  echo "❌ Fingerprint не спрацював."
  echo "Перевір:"
  echo "- чи встановлений саме Android-додаток Termux:API"
  echo "- чи Termux і Termux:API з одного джерела, бажано F-Droid"
  echo "- чи на телефоні увімкнено fingerprint/biometric unlock"
  echo "- чи відкривав Termux:API після встановлення"
  exit 1
}

echo
echo "✅ Fingerprint API працює"

echo
echo "[5] Testing CYBRA fingerprint gate..."
if [ -f ./fingerprint_sign_gate.sh ]; then
  bash ./fingerprint_sign_gate.sh test_fingerprint_gate
else
  echo "⚠️ fingerprint_sign_gate.sh не знайдено в цій папці"
fi

echo
echo "✅ DONE"
