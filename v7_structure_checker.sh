#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p modules/{research,knowledge,parliament,executor,security,infrastructure,chain}
mkdir -p posts proofs registry logs remote_queue remote_results remote_logs native_tokens

find modules posts proofs registry logs native_tokens -maxdepth 3 -type d > proofs/v7_structure_dirs.txt
sha256sum proofs/v7_structure_dirs.txt > proofs/v7_structure_dirs.sha256

cat > posts/v7_structure_status.md <<'MD'
# CYBRA V7 Structure Status

Status: structure checked and repaired.

Core:
- research
- knowledge
- parliament
- executor
- security
- infrastructure
- chain
MD

echo "✅ V7 structure checked"
