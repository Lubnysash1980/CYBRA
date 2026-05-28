#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "CYBRA SPL Devnet deploy script"
echo "Requires: solana cli + spl-token"
echo "Devnet only. No private keys in logs."

solana config set --url devnet
spl-token create-token
