#!/usr/bin/env python3
"""Деплой TimeLock у BSC testnet/mainnet.
Потрібен deployer key (у config/deployer.key, chmod 600).
Попередження: приватний ключ на телефоні — ризиковано."""
import json, os, sys, time
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
CONFIG = H / "config"
KEY_FILE = CONFIG / "deployer.key"
DEPLOYED = D / "data" / "deployed.json"
ARTIFACT = D / "artifacts" / "TimeLock.json"

sys.path.insert(0, str(H/"modules/module_200_network"))
import net

def _key():
    if not KEY_FILE.exists(): return None
    try:
        k = KEY_FILE.read_text().strip()
        if not k.startswith("0x"): k = "0x" + k
        return k
    except Exception: return None

def _save_key(k):
    CONFIG.mkdir(exist_ok=True)
    if not k.startswith("0x"): k = "0x" + k
    KEY_FILE.write_text(k)
    os.chmod(KEY_FILE, 0o600)
    return True

def _deployed():
    if not DEPLOYED.exists(): return {}
    try: return json.loads(DEPLOYED.read_text())
    except Exception: return {}
def _save_deployed(d): DEPLOYED.write_text(json.dumps(d, indent=2))

def deploy(network=None, constructor_args=None):
    try:
        from web3 import Web3
        from eth_account import Account
    except ImportError:
        return False, "pip install web3 eth-account"

    k = _key()
    if not k:
        return False, f"немає {KEY_FILE}. Додай приватний ключ через TUI."

    if network:
        net.set_current(network)
    rpc = net.rpc(); chain_id = net.chain_id()
    if not rpc: return False, "немає RPC"

    w3 = Web3(Web3.HTTPProvider(rpc, request_kwargs={"timeout": 15}))
    if not w3.is_connected():
        return False, f"RPC не відповідає: {rpc}"

    acct = Account.from_key(k)
    balance = w3.eth.get_balance(acct.address)
    bal_eth = w3.from_wei(balance, "ether")
    print(f"  ▸ Deployer: {acct.address}")
    print(f"  ▸ Network:  {net.current()['name']} (chain_id {chain_id})")
    print(f"  ▸ Balance:  {bal_eth} {net.symbol()}")

    if balance == 0:
        return False, f"нульовий баланс. Faucet: {net.faucet() or 'N/A'}"

    if not ARTIFACT.exists():
        return False, f"немає {ARTIFACT}. Спочатку build.py"

    art = json.loads(ARTIFACT.read_text())
    Contract = w3.eth.contract(abi=art["abi"], bytecode=art["bytecode"])

    try:
        # estimate gas
        est = Contract.constructor(*(constructor_args or [])).estimate_gas({"from": acct.address})
        print(f"  ▸ Gas estimate: {est}")
    except Exception as e:
        return False, f"estimate failed: {e}"

    gp = w3.eth.gas_price
    cost = est * gp
    print(f"  ▸ Gas price:    {w3.from_wei(gp, 'gwei')} gwei")
    print(f"  ▸ Max cost:     {w3.from_wei(cost, 'ether')} {net.symbol()}")

    if cost > balance:
        return False, "недостатньо коштів на газ"

    # build tx
    nonce = w3.eth.get_transaction_count(acct.address)
    tx = Contract.constructor(*(constructor_args or [])).build_transaction({
        "from": acct.address, "nonce": nonce, "gas": int(est * 1.2),
        "gasPrice": gp, "chainId": chain_id,
    })
    signed = acct.sign_transaction(tx)
    print(f"  ▸ Sending TX...")
    h = w3.eth.send_raw_transaction(signed.raw_transaction)
    tx_hash = h.hex()
    if not tx_hash.startswith("0x"): tx_hash = "0x" + tx_hash
    print(f"  ▸ TX: {net.explorer_tx(tx_hash)}")

    print(f"  ▸ Waiting for receipt...")
    r = w3.eth.wait_for_transaction_receipt(h, timeout=180)
    if r.status != 1:
        return False, f"TX failed: {tx_hash}"

    addr = r.contractAddress
    rec = {"name":"TimeLock", "address": addr, "tx": tx_hash,
           "chain_id": chain_id, "network": net.current()["name"],
           "deployed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "deployer": acct.address}
    d = _deployed()
    d[f"{chain_id}"] = rec
    _save_deployed(d)
    print(f"  {chr(27)}[32m✓{chr(27)}[0m Deployed at {addr}")
    print(f"  Explorer: {net.explorer_addr(addr)}")
    return True, addr

def info():
    d = _deployed()
    if not d: print("  (не задеплоєно)"); return
    G='\033[32m'; B='\033[36m'; N='\033[0m'
    for cid, rec in d.items():
        print(f"\n  {B}{rec['name']}{N} · chain_id={cid}")
        print(f"    addr:     {rec['address']}")
        print(f"    tx:       {rec['tx']}")
        print(f"    deployer: {rec['deployer']}")
        print(f"    at:       {rec['deployed_at']}")
    print()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "deploy"
    if cmd == "deploy":
        ok, m = deploy(sys.argv[2] if len(sys.argv) > 2 else None)
        print(("✓ " if ok else "✗ ") + m)
        sys.exit(0 if ok else 1)
    elif cmd == "info":
        info()
    elif cmd == "key":
        k = sys.argv[2] if len(sys.argv) > 2 else ""
        if not k: print("usage: deploy.py key <0x...>"); sys.exit(1)
        _save_key(k); print("✓ ключ збережено (chmod 600)")
    elif cmd == "address":
        k = _key()
        if not k: print("  немає ключа"); sys.exit(1)
        from eth_account import Account
        print(Account.from_key(k).address)
