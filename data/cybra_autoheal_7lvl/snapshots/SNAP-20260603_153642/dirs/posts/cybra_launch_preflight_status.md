# CYBRA Launch Preflight AutoFix

Mode: mainnet

Created:
- token/runtime/rpc.env.template
- token/runtime/rpc.env
- token/wallet/wallet_visibility.json
- token/registry/token_registry.json
- token/devnet/devnet_preflight_check.sh
- docs/index.html
- feeds/launch_preflight_status.json

Status:
preflight_ready

Next:
1. Insert API/RPC key into token/runtime/rpc.env
2. Insert Phantom/owner wallet address
3. Run devnet preflight
4. Deploy devnet mint
5. Write mint address into token registry
