#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
H="$HOME/CYBRA"
G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[36m'; D=$'\e[2m'; BOLD=$'\e[1m'; N=$'\e[0m'

step(){ echo; echo "${B}${BOLD}▶ Крок $1/$TOTAL: $2${N}"; }

ask(){ local p="$1"; local d="${2:-}"; local v
  if [ -n "$d" ]; then read -rp "  $p [$d]: " v; echo "${v:-$d}"
  else read -rp "  $p: " v; echo "$v"; fi; }

TOTAL=8
clear
echo "${B}${BOLD}═══════════════════════════════════════════════════════════${N}"
echo "${B}${BOLD}  CYBRA · Setup Wizard${N}"
echo "${B}${BOLD}═══════════════════════════════════════════════════════════${N}"
echo
echo "  Цей майстер налаштує CYBRA за 5 хвилин:"
echo "    1. BUYER_ADDR (MetaMask)"
echo "    2. Мережа (testnet/mainnet)"
echo "    3. AutoNode (multi-chain)"
echo "    4. Парламент (founder)"
echo "    5. KYC списки санкцій"
echo "    6. Telegram/Discord (опційно)"
echo "    7. Git remote для sync (опційно)"
echo "    8. Deployer key для Solidity (опційно)"
echo
read -rp "  Продовжити? (yes/no): " ans
[ "$ans" != "yes" ] && exit 0

mkdir -p "$H/config"

# ─── 1. BUYER_ADDR ─────────────────────────────────────
step 1 "MetaMask адреса"
CFG="$H/config/metamask.env"
CUR=$(grep BUYER_ADDR "$CFG" 2>/dev/null | head -1 | cut -d'"' -f2)
echo "  ${D}Це адреса з якої ти підписуєш контракти${N}"
echo "  ${D}Знайти: MetaMask → ваш акаунт → копіювати адресу${N}"
ADDR=$(ask "0x..." "$CUR")
if [[ "$ADDR" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
  if [ -f "$CFG" ]; then
    # оновити або додати
    if grep -q BUYER_ADDR "$CFG"; then
      sed -i "s|^BUYER_ADDR=.*|BUYER_ADDR=\"$ADDR\"|" "$CFG"
    else
      echo "BUYER_ADDR=\"$ADDR\"" >> "$CFG"
    fi
  else
    cat > "$CFG" <<EOF
# CYBRA MetaMask config
BUYER_ADDR="$ADDR"
EOF
  fi
  echo "  ${G}✓${N} збережено"
else
  echo "  ${R}✗${N} невалідна адреса — пропускаю"
fi

# ─── 2. МЕРЕЖА ─────────────────────────────────────────
step 2 "Мережа за замовчуванням"
CUR_NET=$(python3 "$H/modules/module_200_network/net.py" 2>/dev/null | grep -oE 'bsc_(testnet|mainnet)|eth_(sepolia|mainnet)' | head -1)
echo "  1) BSC Testnet ${G}(рекомендовано — безкоштовно)${N}"
echo "  2) BSC Mainnet ${Y}(реальні гроші)${N}"
echo "  3) Ethereum Sepolia (testnet)"
echo "  4) Ethereum Mainnet"
read -rp "  Вибір [1]: " net_choice
net_choice="${net_choice:-1}"
case "$net_choice" in
  1) NET=bsc_testnet ;;
  2) NET=bsc_mainnet ;;
  3) NET=eth_sepolia ;;
  4) NET=eth_mainnet ;;
  *) NET=bsc_testnet ;;
esac
python3 "$H/modules/module_200_network/net.py" set "$NET" 2>&1 | sed 's/^/  /'

# ─── 3. AUTONODE ───────────────────────────────────────
step 3 "AutoNode daemon"
echo "  ${D}Запустить AutoNode зараз? Він моніторить мережі${N}"
read -rp "  (yes/no) [yes]: " ans; ans="${ans:-yes}"
if [ "$ans" = "yes" ]; then
  bash "$H/modules/module_114_autonode/main.sh" start 2>&1 | sed 's/^/  /'
else
  echo "  ${Y}пропущено${N}"
fi

# ─── 4. ПАРЛАМЕНТ ──────────────────────────────────────
step 4 "Парламент — founder"
python3 - <<PY
import sys, os
sys.path.insert(0, "$H/modules/module_121_parlament")
import parliament as P
members = P.members()["members"]
addr = "$ADDR"
if not any(m["addr"].lower() == addr.lower() for m in members if m.get("active")):
    ok, why = P.add_member(addr, "Founder", "founder", 1)
    print(f"  ✓ додано: {addr[:14]}…")
else:
    print(f"  · вже у парламенті")
print(f"  Всього членів: {len([m for m in members if m.get('active',True)])}")
PY

# ─── 5. KYC ────────────────────────────────────────────
step 5 "KYC — списки санкцій"
if [ -f "$H/modules/module_131_kyc/data/lists/crypto_addresses.json" ]; then
  AGE=$(stat -c %Y "$H/modules/module_131_kyc/data/lists/crypto_addresses.json" 2>/dev/null)
  NOW=$(date +%s)
  if [ -n "$AGE" ] && [ $((NOW - AGE)) -lt 604800 ]; then
    echo "  ${G}✓${N} списки свіжі (менше 7 днів)"
  else
    read -rp "  Оновити списки (OFAC+EU ~50 MB)? (yes/no) [no]: " ans
    [ "$ans" = "yes" ] && python3 "$H/modules/module_131_kyc/fetch.py" 2>&1 | tail -8
  fi
else
  read -rp "  Завантажити списки (OFAC+EU ~50 MB)? (yes/no) [yes]: " ans; ans="${ans:-yes}"
  [ "$ans" = "yes" ] && python3 "$H/modules/module_131_kyc/fetch.py" 2>&1 | tail -8
fi

# ─── 6. NOTIFY ─────────────────────────────────────────
step 6 "Сповіщення (опційно)"
echo "  1) Telegram  2) Discord  3) Пропустити"
read -rp "  Вибір [3]: " n; n="${n:-3}"
case "$n" in
  1)
    read -rp "  TG_TOKEN: " tok
    read -rp "  TG_CHAT: " chat
    cat > "$H/config/telegram.env" <<EOF
TG_TOKEN="$tok"
TG_CHAT="$chat"
EOF
    echo "  ${G}✓${N} збережено → config/telegram.env"
    ;;
  2)
    read -rp "  Discord Webhook URL: " wh
    echo "DISCORD_WEBHOOK=\"$wh\"" > "$H/config/discord.env"
    echo "  ${G}✓${N} збережено → config/discord.env"
    ;;
  *) echo "  ${D}пропущено — можна налаштувати пізніше (121 → 19)${N}" ;;
esac

# ─── 7. GIT REMOTE ─────────────────────────────────────
step 7 "Git sync (опційно)"
echo "  ${D}Приватний репо для синхронізації між пристроями${N}"
read -rp "  Git remote URL (Enter=пропустити): " remote
if [ -n "$remote" ]; then
  python3 "$H/modules/module_121_parlament/sync.py" setup "$remote" sync 2>&1 | sed 's/^/  /'
else
  echo "  ${D}пропущено — можна пізніше (121 → 76)${N}"
fi

# ─── 8. DEPLOYER KEY ───────────────────────────────────
step 8 "Solidity deployer key (опційно)"
echo "  ${D}Окремий гаманець ТІЛЬКИ для деплою контрактів${N}"
echo "  ${D}НЕ використовуй свій основний MetaMask!${N}"
read -rp "  Приватний ключ 0x... (Enter=пропустити): " pk
if [ -n "$pk" ]; then
  if [ "$NET" = "bsc_testnet" ]; then
    echo "$pk" > "$H/config/testnet_deployer.key"
  else
    echo "$pk" > "$H/config/mainnet_deployer.key"
  fi
  chmod 600 "$H/config/"*deployer.key 2>/dev/null
  echo "  ${G}✓${N} ключ збережено"
else
  echo "  ${D}парламент згенерує ephemeral для testnet сам (121 → 68)${N}"
fi

# ─── ФІНАЛ ─────────────────────────────────────────────
echo
echo "${G}═══════════════════════════════════════════════════════════${N}"
echo "${G}  ✅ SETUP ЗАВЕРШЕНО${N}"
echo "${G}═══════════════════════════════════════════════════════════${N}"
echo
echo "  Запусти для перевірки:"
echo "    cybra → 152   (Doctor — повна діагностика)"
echo "    cybra → 000   (Master Dashboard)"
echo
