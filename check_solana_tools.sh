#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p posts proofs

{
echo "# Solana Tools Check"
echo
echo "solana:"
command -v solana || echo "missing"
echo
echo "spl-token:"
command -v spl-token || echo "missing"
echo
echo "node:"
command -v node || echo "missing"
echo
echo "npm:"
command -v npm || echo "missing"
} > posts/solana_tools_check.md

sha256sum posts/solana_tools_check.md > proofs/solana_tools_check.sha256

cat posts/solana_tools_check.md
