#!/data/data/com.termux/files/usr/bin/bash
set -e

redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes
sleep 1

mkdir -p modules/{research,knowledge,parliament,executor,security,infrastructure,chain} posts proofs registry logs/v7

cat > registry/cybra_v7_architecture.json <<'JSON'
{
  "version": "CYBRA V7",
  "layers": [
    "research",
    "knowledge",
    "parliament",
    "executor",
    "security",
    "infrastructure",
    "chain"
  ],
  "rules": [
    "no hallucination",
    "proof required",
    "audit every task",
    "retry failed",
    "safe execution",
    "evolution only"
  ],
  "status": "initialized"
}
JSON

cat > posts/cybra_v7_status.md <<'MD'
# CYBRA V7 Evolution Core

Initialized layers:
- Research
- Knowledge
- Parliament
- Executor
- Security
- Infrastructure
- Chain

Status: ready for modular evolution.
MD

find modules registry posts -type f -exec sha256sum {} \; > proofs/cybra_v7_hashes.txt

git add modules registry posts proofs install_cybra_v7_evolution_core.sh
git commit -m "initialize CYBRA V7 evolution core" || true

echo "✅ CYBRA V7 Evolution Core installed"
echo "Next:"
echo "  cat posts/cybra_v7_status.md"
echo "  cat registry/cybra_v7_architecture.json"
