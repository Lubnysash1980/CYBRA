#!/data/data/com.termux/files/usr/bin/bash
CFG="$HOME/CYBRA/config/metamask.env"
mkdir -p "$(dirname "$CFG")"
[ -f "$CFG" ] && . "$CFG"
B=$'\e[36m'; G=$'\e[32m'; N=$'\e[0m'
echo "${B}═══ Налаштування MetaMask ═══${N}"; echo
echo "  Поточні:"
echo "    BUYER_ADDR   = ${BUYER_ADDR:-<не задано>}"
echo "    CYBRA_PORT   = ${CYBRA_PORT:-8765}"
echo "    WAIT_TIMEOUT = ${WAIT_TIMEOUT:-900} с"; echo
read -rp "  BUYER_ADDR [Enter=без змін]: " v; [ -n "$v" ] && BUYER_ADDR="$v"
read -rp "  CYBRA_PORT [Enter=без змін]: " v; [ -n "$v" ] && CYBRA_PORT="$v"
read -rp "  WAIT_TIMEOUT [Enter=без змін]: " v; [ -n "$v" ] && WAIT_TIMEOUT="$v"
cat > "$CFG" <<EOF
BUYER_ADDR="${BUYER_ADDR:-0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F}"
CYBRA_PORT="${CYBRA_PORT:-8765}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-900}"
EOF
echo; echo "${G}✓${N} збережено: $CFG"
