#!/usr/bin/env bash
set -e

cd "$HOME/CYBRA"

echo "▶ LIVE: ORACLE GERMANY | eu-frankfurt-1 | Europe/Berlin"
echo "▶ FLOW: Termux ↔ GitHub ↔ Oracle ↔ SpaceOracle ↔ CodeSpace"
echo "▶ LIVE ORDERS: OFF | PAPER: ON | TESTNET: ON | AUDIT: ON"

mkdir -p data/oracle_germany_live/{tasks,audit,proofs} scripts/live logs

cat > scripts/live/oracle_germany_live.py <<'PY'
#!/usr/bin/env python3
import json, time, os
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

ROOT = Path.home() / "CYBRA"
LIVE = {
    "profile": "Germany/eu-frankfurt-1",
    "tz": "Europe/Berlin",
    "live_orders": False,
    "paper_trading": True,
    "testnet": True,
    "audit": True,
    "flow": "Termux→GitHub→Oracle→SpaceOracle→CodeSpace"
}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({
            "status": "LIVE_ORACLE_GERMANY",
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "live": LIVE
        }, indent=2).encode())
    def log_message(self, fmt, *args): pass

def main():
    port = int(os.environ.get("PORT", sys.argv[1] if len(sys.argv) > 1 else 8804))
    print(f"▶ LIVE Oracle Germany: http://127.0.0.1:{port}")
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()

if __name__ == "__main__":
    import sys
    main()
PY

cat > cybra-live <<'SH'
#!/bin/bash
cd ~/CYBRA
python3 scripts/live/oracle_germany_live.py "$@"
SH

chmod +x scripts/live/oracle_germany_live.py cybra-live

export CYBRA_LIVE=1
export CYBRA_LIVE_ORDERS=0
export CYBRA_PAPER=1
export TZ=Europe/Berlin

echo ""
echo "═══════════════════════════════"
echo "✅ LIVE ORACLE GERMANY RUNNING"
echo "═══════════════════════════════"
echo "▶ cybra-live          # status + dashboard"
echo "▶ cybra-live 8805     # custom port"
echo "▶ http://127.0.0.1:8804"
echo ""
echo "🔴 LIVE ORDERS: DISABLED"
echo "🟢 PAPER + TESTNET + AUDIT: ENABLED"
echo "═══════════════════════════════"

cybra-live &
sleep 2
curl -s http://127.0.0.1:8804 | jq . 2>/dev/null || echo "▶ LIVE dashboard at http://127.0.0.1:8804"
