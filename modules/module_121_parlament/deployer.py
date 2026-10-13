#!/usr/bin/env python3
"""Парламент як deployer:
  1. Знаходить усі *.sol у modules/module_*/contracts/
  2. Компілює через solcx
  3. Визначає target network (з options)
  4. Testnet → деплоїть сам (ephemeral key)
  5. Mainnet → створює пропозицію
  6. Після deploy — верифікує, оновлює module artifacts
  7. Integration — модуль дізнається адресу через config/deployed.json
"""
import json, os, sys, time, subprocess, hashlib, secrets
from pathlib import Path

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
M = H / "modules"
CONFIG = H / "config"
DEPLOYED = CONFIG / "deployed.json"          # глобальний реєстр
TESTNET_KEY = CONFIG / "testnet_deployer.key"  # ephemeral (парламент генерує сам)
MAINNET_KEY = CONFIG / "mainnet_deployer.key"  # тільки через vote

sys.path.insert(0, str(M/"module_200_network"))
sys.path.insert(0, str(D))

C_G='\033[32m'; C_Y='\033[33m'; C_R='\033[31m'; C_B='\033[36m'
C_D='\033[2m'; C_N='\033[0m'

def _opt(key, default=None):
    try:
        import options
        return options.get(key, default)
    except Exception:
        return default

def _load_deployed():
    if not DEPLOYED.exists(): return {}
    try: return json.loads(DEPLOYED.read_text())
    except Exception: return {}

def _save_deployed(d):
    tmp = str(DEPLOYED)+".tmp"
    Path(tmp).write_text(json.dumps(d, indent=2, ensure_ascii=False))
    os.replace(tmp, DEPLOYED)

# ─── знайти контракти ─────────────────────────────────────
def discover_contracts():
    """Повертає [{name, sol_path, module_id, bytecode_ready, deployed}]."""
    out = []
    for sol in M.glob("module_*/contracts/*.sol"):
        name = sol.stem
        mod = sol.parent.parent.name
        mid = None
        import re
        m = re.match(r'module_(\d+)_', mod)
        if m: mid = m.group(1)
        # artifact?
        art = sol.parent.parent / "artifacts" / f"{name}.json"
        # deployed?
        dep = _load_deployed().get(name, {})
        out.append({
            "name": name, "sol": str(sol), "module_id": mid,
            "module_dir": str(sol.parent.parent),
            "artifact": str(art) if art.exists() else None,
            "deployed": dep, "has_artifact": art.exists(),
        })
    return out

# ─── компіляція ──────────────────────────────────────────
def compile_contract(sol_path, name=None, verbose=False):
    sol = Path(sol_path); name = name or sol.stem
    try:
        import solcx
    except ImportError:
        return False, "pip install py-solc-x", None
    try: solcx.install_solc("0.8.20")
    except Exception: pass
    try: solcx.set_solc_version("0.8.20")
    except Exception as e: return False, f"solc: {e}", None

    try:
        compiled = solcx.compile_standard({
            "language": "Solidity",
            "sources": {f"{name}.sol": {"content": sol.read_text()}},
            "settings": {
                "optimizer": {"enabled": True, "runs": 200},
                "outputSelection": {"*": {"*": ["abi", "evm.bytecode"]}},
            }
        }, allow_paths=str(sol.parent))
    except Exception as e:
        return False, f"compile: {str(e)[:200]}", None

    c = compiled["contracts"][f"{name}.sol"][name]
    out = {
        "name": name, "compiler": "0.8.20",
        "abi": c["abi"], "bytecode": "0x" + c["evm"]["bytecode"]["object"],
        "compiled_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "sol_hash": hashlib.sha256(sol.read_bytes()).hexdigest()[:16],
    }
    art_dir = sol.parent.parent / "artifacts"
    art_dir.mkdir(exist_ok=True)
    art = art_dir / f"{name}.json"
    art.write_text(json.dumps(out, indent=2))
    return True, str(art), out

# ─── deployer key ────────────────────────────────────────
def _get_testnet_key():
    """Ephemeral key для testnet. Парламент створює сам якщо немає."""
    try:
        from eth_account import Account
    except ImportError:
        return None, "pip install eth-account"
    if TESTNET_KEY.exists():
        try:
            k = TESTNET_KEY.read_text().strip()
            if not k.startswith("0x"): k = "0x" + k
            return k, Account.from_key(k).address
        except Exception: pass
    # generate
    acct = Account.create()
    TESTNET_KEY.parent.mkdir(exist_ok=True)
    TESTNET_KEY.write_text(acct.key.hex())
    os.chmod(TESTNET_KEY, 0o600)
    return acct.key.hex(), acct.address

def _get_mainnet_key():
    if not MAINNET_KEY.exists(): return None, None
    try:
        from eth_account import Account
        k = MAINNET_KEY.read_text().strip()
        if not k.startswith("0x"): k = "0x" + k
        return k, Account.from_key(k).address
    except Exception: return None, None

# ─── deploy ──────────────────────────────────────────────
def deploy_testnet(name, artifact, target_net="bsc_testnet"):
    """Деплоїть у testnet з ephemeral key. Auto — без голосування."""
    try:
        import net
        from web3 import Web3
        from eth_account import Account
    except ImportError:
        return False, "pip install web3 eth-account"

    k, addr = _get_testnet_key()
    if not k:
        return False, "не вдалось отримати ключ"

    net.set_current(target_net)
    rpc = net.rpc(); chain_id = net.chain_id()
    w3 = Web3(Web3.HTTPProvider(rpc, request_kwargs={"timeout": 15}))
    if not w3.is_connected():
        return False, f"RPC down: {rpc}"

    acct = Account.from_key(k)
    bal = w3.eth.get_balance(acct.address)
    if bal == 0:
        return {"ok": False, "reason": "no_balance", "address": acct.address,
                "faucet": net.faucet()}

    Contract = w3.eth.contract(abi=artifact["abi"], bytecode=artifact["bytecode"])
    try:
        est = Contract.constructor().estimate_gas({"from": acct.address})
    except Exception as e:
        return False, f"estimate: {e}"

    gp = w3.eth.gas_price
    cost = est * gp
    if cost > bal:
        return False, f"gas {w3.from_wei(cost,'ether')} > balance {w3.from_wei(bal,'ether')}"

    nonce = w3.eth.get_transaction_count(acct.address)
    tx = Contract.constructor().build_transaction({
        "from": acct.address, "nonce": nonce, "gas": int(est*1.2),
        "gasPrice": gp, "chainId": chain_id,
    })
    signed = acct.sign_transaction(tx)
    h = w3.eth.send_raw_transaction(signed.raw_transaction)
    tx_hash = h.hex()
    if not tx_hash.startswith("0x"): tx_hash = "0x" + tx_hash
    r = w3.eth.wait_for_transaction_receipt(h, timeout=180)
    if r.status != 1: return False, f"tx failed: {tx_hash}"

    return {"ok": True, "address": r.contractAddress, "tx": tx_hash,
            "deployer": acct.address, "chain_id": chain_id,
            "network": target_net, "gas_used": r.gasUsed}

def deploy_mainnet(name, artifact):
    """Mainnet — тільки через пропозицію парламенту."""
    k, addr = _get_mainnet_key()
    if not k:
        return {"ok": False, "reason": "no_mainnet_key",
                "note": "додай mainnet_deployer.key"}

    # створити пропозицію
    import parliament as P
    founder = None
    for m in P.members()["members"]:
        if m.get("active") and m["role"] == "founder":
            founder = m["addr"]; break
    if not founder:
        return {"ok": False, "reason": "no_founder"}

    ok, why, pid = P.create_proposal(
        "upgrade",
        f"Deploy {name} → BSC Mainnet",
        {"action": "deploy", "contract": name, "artifact": artifact,
         "deployer": addr, "chain_id": 56},
        founder
    )
    if not ok:
        return {"ok": False, "reason": why}
    return {"ok": True, "pid": pid, "note": "пропозиція створена, потрібне голосування",
            "deployer": addr}

# ─── verify + integration ────────────────────────────────
def verify_deployed(name, rec):
    """Перевірити чи контракт живий на мережі."""
    try:
        import net
        from web3 import Web3
    except ImportError: return False, "no web3"
    orig = net.current().get("name", "")
    try:
        net.set_current(rec["network"])
        w3 = Web3(Web3.HTTPProvider(net.rpc(), request_kwargs={"timeout": 10}))
        code = w3.eth.get_code(rec["address"])
        if len(code) == 0:
            return False, "no bytecode at address"
        # перевірка chain_id
        if w3.eth.chain_id != rec["chain_id"]:
            return False, "chain_id mismatch"
        return True, f"code size {len(code)}B"
    except Exception as e:
        return False, str(e)[:100]

def register_deployed(name, rec, art=None):
    d = _load_deployed()
    d[name] = rec
    if art:
        d[name]["abi_hash"] = hashlib.sha256(
            json.dumps(art["abi"], sort_keys=True).encode()).hexdigest()[:16]
    _save_deployed(d)

    # integration: оновити deployed.json у модулі
    if art:
        mod_dir = Path(art.get("_module_dir", "")) if art.get("_module_dir") else None
        if mod_dir and mod_dir.exists():
            (mod_dir / "data" / "deployed.json").write_text(json.dumps(rec, indent=2))

def module_can_use(name, chain_id):
    """Модуль питає: чи є задеплоєний контракт для моєї мережі?"""
    d = _load_deployed().get(name, {})
    if not d: return None
    if d.get("chain_id") == chain_id:
        return d.get("address")
    return None

# ═══════════════════════════════════════════════════════════════
# AUTO-CYCLE — викликається з orchestrator
# ═══════════════════════════════════════════════════════════════
def auto_cycle(verbose=True):
    """Парламент сам: compile → deploy (testnet) → register → verify.
    Для mainnet — тільки створює пропозиції (не деплоїть без vote)."""
    auto_testnet = _opt("deploy.auto_testnet", True)
    do_compile   = _opt("deploy.auto_compile", True)

    result = {"compiled": [], "deployed": [], "proposed": [],
              "skipped": [], "errors": []}

    for c in discover_contracts():
        name = c["name"]
        # вже задеплоєно?
        dep = c["deployed"]
        if dep and dep.get("address"):
            result["skipped"].append({"name": name, "reason": "already deployed"})
            continue

        # компіляція
        if do_compile and not c["has_artifact"]:
            if verbose:
                print(f"  {C_D}▸ compile {name}{C_N}")
            ok, msg, art = compile_contract(c["sol"], name)
            if not ok:
                result["errors"].append({"name": name, "phase": "compile", "msg": msg})
                continue
            result["compiled"].append(name)
            c["has_artifact"] = True
            c["artifact"] = msg

        if not c["has_artifact"]:
            result["skipped"].append({"name": name, "reason": "no artifact"})
            continue

        # load artifact
        try:
            art = json.loads(Path(c["artifact"]).read_text())
            art["_module_dir"] = c["module_dir"]
        except Exception as e:
            result["errors"].append({"name": name, "phase": "load_artifact", "msg": str(e)})
            continue

        # деплой у testnet автоматично
        if auto_testnet:
            if verbose:
                print(f"  {C_D}▸ deploy {name} → testnet{C_N}")
            r = deploy_testnet(name, art)
            if isinstance(r, dict) and r.get("ok"):
                rec = {"name": name, "address": r["address"], "tx": r["tx"],
                       "deployer": r["deployer"], "chain_id": r["chain_id"],
                       "network": r["network"],
                       "deployed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                       "auto": True}
                register_deployed(name, rec, art)
                result["deployed"].append(rec)
                if verbose:
                    print(f"    {C_G}✓{C_N} {r['address']}")
            elif isinstance(r, dict) and r.get("reason") == "no_balance":
                result["errors"].append({
                    "name": name, "phase": "deploy",
                    "msg": f"no balance. faucet: {r.get('faucet')}",
                    "address": r.get("address")
                })
                if verbose:
                    print(f"    {C_Y}!{C_N} need tBNB → {r.get('address')}")
                    print(f"    faucet: {r.get('faucet')}")
            else:
                result["errors"].append({
                    "name": name, "phase": "deploy", "msg": str(r)
                })
                if verbose: print(f"    {C_R}✗{C_N} {r}")

    return result

def list_status():
    contracts = discover_contracts()
    G='\033[32m'; Y='\033[33m'; R='\033[31m'; D_='\033[2m'; B='\033[36m'; N='\033[0m'
    if not contracts:
        print(f"\n  {Y}немає контрактів у modules/module_*/contracts/{N}\n"); return
    print(f"\n  {B}Контракти{C_N}\n")
    for c in contracts:
        comp = f"{G}✓{C_N}" if c["has_artifact"] else f"{R}✗{C_N}"
        dep = c["deployed"]
        if dep.get("address"):
            net_name = dep.get("network","?")
            col = G if "testnet" not in net_name else Y
            dep_s = f"{col}{dep['address'][:10]}…{dep['address'][-6:]}{C_N} ({net_name})"
        else:
            dep_s = f"{D_}не задеплоєно{C_N}"
        print(f"  {comp} {c['name']:14s} [{c['module_id'] or '?'}] {dep_s}")
    print()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        list_status()
    elif cmd == "auto":
        r = auto_cycle(verbose=True)
        print(f"\n  compiled={len(r['compiled'])} deployed={len(r['deployed'])} "
              f"errors={len(r['errors'])}")
    elif cmd == "discover":
        print(json.dumps(discover_contracts(), indent=2, default=str))
    elif cmd == "testnet-key":
        k, addr = _get_testnet_key()
        print(f"  address: {addr}")
        print(f"  balance check: y")
        try:
            import net
            from web3 import Web3
            net.set_current("bsc_testnet")
            w3 = Web3(Web3.HTTPProvider(net.rpc(), request_kwargs={"timeout": 10}))
            bal = w3.eth.get_balance(addr)
            print(f"  balance: {w3.from_wei(bal, 'ether')} tBNB")
            print(f"  faucet:  {net.faucet()}")
        except Exception as e: print(f"  err: {e}")
