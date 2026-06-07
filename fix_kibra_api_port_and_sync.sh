#!/usr/bin/env bash
set +e
cd "$HOME/CYBRA" || exit 1

echo "=== FIX KIBRA API PORT + SYNC ==="

cat > cybra-kibra-real <<'EOF'
#!/usr/bin/env bash
cd "$HOME/CYBRA" || exit 1

WALLET="${KIBRA_WALLET:-FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y}"

case "$1" in
  init)
    python3 scripts/kibra/cybra_kibra_real_node.py init --wallet "$WALLET"
    ;;
  submit)
    TO="${2:-$WALLET}"
    AMOUNT="${3:-0}"
    NOTE="${4:-internal node tx}"
    python3 scripts/kibra/cybra_kibra_real_node.py submit --from-wallet "$WALLET" --to-wallet "$TO" --amount "$AMOUNT" --note "$NOTE"
    ;;
  mine)
    python3 scripts/kibra/cybra_kibra_real_node.py mine --miner "$WALLET"
    ;;
  validate)
    python3 scripts/kibra/cybra_kibra_real_node.py validate
    ;;
  status)
    python3 scripts/kibra/cybra_kibra_real_node.py status
    ;;
  proof)
    python3 scripts/kibra/cybra_kibra_real_node.py proof
    ;;
  api)
    PORT="${2:-8792}"
    echo "Starting KIBRA API on http://127.0.0.1:${PORT}/"
    python3 scripts/kibra/cybra_kibra_real_node.py api --host 127.0.0.1 --port "$PORT"
    ;;
  api-auto)
    PORT="$(python3 - <<'PY'
import socket
for port in range(8792, 8810):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", port))
        s.close()
        print(port)
        break
    except OSError:
        s.close()
PY
)"
    if [ -z "$PORT" ]; then
      echo "No free port found in 8792..8809"
      exit 1
    fi
    echo "Starting KIBRA API on http://127.0.0.1:${PORT}/"
    python3 scripts/kibra/cybra_kibra_real_node.py api --host 127.0.0.1 --port "$PORT"
    ;;
  test)
    python3 scripts/kibra/cybra_kibra_real_node.py init --wallet "$WALLET"
    python3 scripts/kibra/cybra_kibra_real_node.py submit --from-wallet "$WALLET" --to-wallet "$WALLET" --amount 0 --note "internal real node heartbeat test"
    python3 scripts/kibra/cybra_kibra_real_node.py mine --miner "$WALLET"
    python3 scripts/kibra/cybra_kibra_real_node.py validate
    python3 scripts/kibra/cybra_kibra_real_node.py proof
    ;;
  *)
    echo "Commands:"
    echo "  cybra-kibra-real init"
    echo "  cybra-kibra-real submit [to_wallet] [amount] [note]"
    echo "  cybra-kibra-real mine"
    echo "  cybra-kibra-real validate"
    echo "  cybra-kibra-real status"
    echo "  cybra-kibra-real proof"
    echo "  cybra-kibra-real api [port]"
    echo "  cybra-kibra-real api-auto"
    echo "  cybra-kibra-real test"
    ;;
esac
EOF

chmod +x cybra-kibra-real
ln -sf "$HOME/CYBRA/cybra-kibra-real" "$PREFIX/bin/cybra-kibra-real" 2>/dev/null || true

echo
echo "=== VALIDATE ==="
cybra-kibra-real validate

echo
echo "=== PROOF ==="
cybra-kibra-real proof

echo
echo "=== GIT STATUS ==="
git status --short

echo
echo "✅ FIX DONE"
echo
echo "API start:"
echo "  cybra-kibra-real api-auto"
echo "or:"
echo "  cybra-kibra-real api 8794"
