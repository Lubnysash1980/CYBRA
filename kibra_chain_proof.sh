#!/data/data/com.termux/files/usr/bin/bash
set +e
cd "$HOME/CYBRA" || exit 1

case "${1:-status}" in
  init|status|verify|prepare-anchor|add-pool)
    python3 kibra_blockchain_market_proof.py "$@"
    ;;

  proof)
    sha256sum -c proofs/kibra_blockchain_market_proof.sha256
    ;;

  send-anchor)
    KEYPAIR="$2"
    CLUSTER="${3:-mainnet-beta}"
    MEMO_FILE="data/kibra_blockchain_market_proof/anchor_memo.txt"

    if [ ! -f "$KEYPAIR" ]; then
      echo "❌ keypair json not found: $KEYPAIR"
      exit 1
    fi

    if [ ! -f "$MEMO_FILE" ]; then
      python3 kibra_blockchain_market_proof.py prepare-anchor
    fi

    echo "This sends a real Solana transaction with memo proof."
    echo "It costs SOL network fee."
    echo "Type exactly: I_ACCEPT_BLOCKCHAIN_TX_COST"
    read PHRASE

    if [ "$PHRASE" != "I_ACCEPT_BLOCKCHAIN_TX_COST" ]; then
      echo "❌ cancelled"
      exit 1
    fi

    npm install @solana/web3.js >/dev/null 2>&1 || true
    node solana_memo_anchor.mjs "$KEYPAIR" "$CLUSTER" "$(cat "$MEMO_FILE")"
    ;;

  *)
    echo "Usage:"
    echo "  kibra-chain-proof init"
    echo "  kibra-chain-proof status"
    echo "  kibra-chain-proof verify"
    echo "  kibra-chain-proof prepare-anchor"
    echo "  kibra-chain-proof proof"
    echo "  kibra-chain-proof add-pool --name NAME --base-mint KIBRA_MINT --base-vault KIBRA_VAULT --quote-mint USDC_MINT --quote-vault USDC_VAULT --pool-address POOL --source-url URL"
    echo "  kibra-chain-proof send-anchor data/kibra_blockchain_market_proof/private/keypair.json mainnet-beta"
    ;;
esac
