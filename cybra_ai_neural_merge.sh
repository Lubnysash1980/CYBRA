#!/data/data/com.termux/files/usr/bin/bash
set -e

OWNER="Lubnysash1980"
BASE="$HOME/CYBRA"
NET="$BASE/ai_network"

mkdir -p "$NET/repos" "$NET/index" "$NET/graph" posts proofs

cat > "$NET/repos/repo_list.txt" <<'EOF'
Alfapay
bolt-unreal-engine-sdk
c
cyber-parliament-core
cybr
CYBRA
cybra-ai-network
cybra-live-runtime
cybra-self-writing
CYBRA_TERMUX_BACKUP
cybra_ultra_backup
cybro
double-sha-watcher
my-project
Repozitirytopmaxi
termux_evolution
EOF

while read -r REPO; do
  [ -z "$REPO" ] && continue
  DIR="$NET/repos/$REPO"

  if [ -d "$DIR/.git" ]; then
    echo "Updating $REPO"
    git -C "$DIR" pull || true
  else
    echo "Cloning $REPO"
    git clone "https://github.com/$OWNER/$REPO.git" "$DIR" || true
  fi
done < "$NET/repos/repo_list.txt"

find "$NET/repos" -type f \( -name "*.py" -o -name "*.sh" -o -name "*.js" -o -name "*.json" -o -name "*.md" \) \
  > "$NET/index/all_files.txt"

grep -Ei "ai|agent|worker|parliament|cybra|token|watchdog|autofix|self|executor|redis|github|pages" \
  "$NET/index/all_files.txt" > "$NET/index/ai_files.txt" || true

cat > "$NET/graph/ai_neural_network.json" <<'JSON'
{
  "system": "CYBRA AI Neural Network",
  "mode": "multi_repo_import_graph",
  "roles": {
    "CYBRA": "main orchestrator",
    "cyber-parliament-core": "parliament core",
    "cybra-ai-network": "AI network layer",
    "cybra-live-runtime": "runtime layer",
    "cybra-self-writing": "self writing layer",
    "double-sha-watcher": "proof/watchdog layer",
    "termux_evolution": "Termux evolution layer",
    "Alfapay": "payment/business module",
    "CYBRA_TERMUX_BACKUP": "backup source",
    "cybra_ultra_backup": "backup source"
  },
  "rules": [
    "no secrets imported",
    "no private keys committed",
    "all imports indexed",
    "all modules proof-hashed",
    "CYBRA remains main orchestrator"
  ]
}
JSON

sha256sum "$NET/index/"*.txt "$NET/graph/ai_neural_network.json" > proofs/ai_neural_network.sha256

cat > posts/ai_neural_network_status.md <<'MD'
# CYBRA AI Neural Network

Status: initialized

Created:
- multi-repo clone/update layer
- AI file index
- neural graph
- proof hashes

Main orchestrator:
CYBRA

Mode:
GitHub import network
MD

git add ai_network posts/ai_neural_network_status.md proofs/ai_neural_network.sha256 cybra_ai_neural_merge.sh
git commit -m "merge GitHub AI repos into CYBRA neural network" || true

echo "✅ CYBRA AI Neural Network created"
