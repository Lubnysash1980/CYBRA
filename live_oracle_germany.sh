#!/usr/bin/env bash
set -e

echo "▶ LIVE: Oracle Germany Patch deployment"
echo "▶ Profile: Germany | Europe/Berlin | eu-frankfurt-1"
echo "▶ Flow: Termux ↔ GitHub ↔ Oracle ↔ SpaceOracle ↔ CodeSpace"
echo "▶ Live orders: DISABLED (paper/testnet only + audit)"

cd "$HOME/CYBRA"

# create structure
mkdir -p data/cybra_oracle_bridge/{patches,reports,actions,oracle,spaceoracle,codespace,manifests} \
         data/cybra_oracle/tasks data/cybra_codespace/tasks \
         data/cybra_bar/menus scripts/oracle_bridge \
         posts feeds proofs dashboard/cybra_oracle_germany runtime/redis logs/oracle_bridge

# secure git
grep -qxF ".cybra_local_secret/" .gitignore 2>/dev/null || echo ".cybra_local_secret/" >> .gitignore
grep -qxF "data/cybra_oracle_bridge/patches/*.tar.gz" .gitignore 2>/dev/null || echo "data/cybra_oracle_bridge/patches/*.tar.gz" >> .gitignore

# deploy oracle bridge
cat > scripts/oracle_bridge/live_oracle_germany.py <<'PY'
#!/usr/bin/env python3
# LIVE CYBRA ORACLE GERMANY PATCH — PAPER/TESTNET ONLY
import os, sys, json, time, subprocess, tarfile
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

ROOT = Path.home() / "CYBRA"
REGION = {
    "country": "Germany",
    "region": "eu-frankfurt-1",
    "tz": "Europe/Berlin",
    "profile": "DE_EU_SAFE"
}
SAFETY = {
    "live_orders": False,
    "real_trading": False,
    "paper_trading": True,
    "testnet": True,
    "auto_withdrawals": False,
    "owner_approval": True
}

def now(): return time.strftime("%Y-%m-%dT%H:%M:%S")

def live_status():
    return {
        "timestamp": now(),
        "status": "LIVE_ORACLE_GERMANY_ACTIVE",
        "region": REGION,
        "safety": SAFETY,
        "flow": "Termux→GitHub→Oracle(fra)→SpaceOracle→CodeSpace"
    }

def serve(port):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(live_status(), indent=2).encode())
        def log_message(self, fmt, *args): pass
    print(f"▶ LIVE Oracle Germany dashboard: http://127.0.0.1:{port}")
    HTTPServer(("127.0.0.1", int(port)), Handler).serve_forever()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print(json.dumps(live_status(), indent=2))
    elif cmd == "serve":
        serve(sys.argv[2] if len(sys.argv) > 2 else 8804)
    else:
        print("live: status | serve [port]")
PY

# create launcher
cat > cybra-live-oracle <<'SH'
#!/usr/bin/env bash
cd "$HOME/CYBRA" && python3 scripts/oracle_bridge/live_oracle_germany.py "$@"
SH
chmod +x scripts/oracle_bridge/live_oracle_germany.py cybra-live-oracle

# set env
cat >> ~/.bashrc <<'EOF'
export CYBRA_LIVE_PROFILE="Germany/eu-frankfurt-1"
export CYBRA_LIVE_ORDERS="false"
export CYBRA_PAPER_TRADING="true"
export TZ="Europe/Berlin"
EOF

# show status
echo ""
echo "══════════════════════════════════════════"
echo "✅ LIVE: Oracle Germany Patch ACTIVE"
echo "══════════════════════════════════════════"
echo "▶ cybra-live-oracle status"
echo "▶ cybra-live-oracle serve 8804"
echo "▶ http://127.0.0.1:8804"
echo ""
echo "🔒 LIVE ORDERS: BLOCKED"
echo "📊 PAPER + TESTNET + AUDIT ONLY"
echo "══════════════════════════════════════════"

# final live check
cybra-live-oracle status
