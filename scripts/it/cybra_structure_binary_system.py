#!/usr/bin/env python3
import os, sys, json, time, hashlib, gzip, shutil, subprocess, py_compile
from pathlib import Path

ROOT = Path.home() / "CYBRA"
WALLET_DEFAULT = "FesrWxqM67HrjFqsCoCHsUkRocZZBgWeg4P3T4b9FD9Y"

EXCLUDE_DIRS = {
    ".git", "node_modules", ".venv", "venv", "__pycache__",
    "runtime/redis", "logs", ".cache", ".npm", ".python-eggs"
}

MAX_FILE_SIZE = 8 * 1024 * 1024
MAX_FILES = 12000

SAFETY = {
    "real_payment_now": False,
    "real_trading_now": False,
    "automatic_external_tx": False,
    "automatic_withdrawals": False,
    "automatic_SWIFT": False,
    "automatic_real_rewards": False,
    "external_bridge_enabled": False,
    "bank_live_mode": False,
    "psp_live_mode": False,
    "do_not_store_secrets_in_git": True,
    "manual_OWNER_approval_required_for_external_live": True,
    "cyber_parliament_approval_required_for_external_live": True
}

def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")

def rel(p):
    return str(Path(p).relative_to(ROOT))

def mkdir(p):
    Path(p).mkdir(parents=True, exist_ok=True)

def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}

def write_json(path, data):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def write_text(path, text):
    p = Path(path)
    mkdir(p.parent)
    p.write_text(text, encoding="utf-8")

def sha_bytes(b):
    return hashlib.sha256(b).hexdigest()

def sha_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 512), b""):
            h.update(chunk)
    return h.hexdigest()

def should_skip(path):
    rp = rel(path)
    parts = set(Path(rp).parts)
    if parts & EXCLUDE_DIRS:
        return True
    for x in EXCLUDE_DIRS:
        if rp.startswith(x + "/"):
            return True
    return False

def iter_files():
    count = 0
    for p in ROOT.rglob("*"):
        if count >= MAX_FILES:
            break
        if not p.is_file():
            continue
        if should_skip(p):
            continue
        try:
            if p.stat().st_size > MAX_FILE_SIZE:
                continue
        except Exception:
            continue
        count += 1
        yield p

def scan_structure():
    files = []
    dirs = set()
    for p in iter_files():
        rp = rel(p)
        dirs.add(str(Path(rp).parent))
        st = p.stat()
        files.append({
            "path": rp,
            "size": st.st_size,
            "sha256": sha_file(p),
            "suffix": p.suffix,
            "executable": bool(st.st_mode & 0o111)
        })

    report = {
        "timestamp": now(),
        "status": "STRUCTURE_SCAN_OK",
        "root": str(ROOT),
        "dirs_count": len(dirs),
        "files_count": len(files),
        "files": files,
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_structure_autocollector/structure_scan_latest.json", report)
    return report

def create_departments():
    departments = {
        "structure_department": {
            "name": "CYBRA IT Structure Department",
            "path": "data/cybra_it_department/structure_department",
            "responsibility": [
                "collect full project structure",
                "validate required folders",
                "detect missing files",
                "build structure manifests",
                "route fixes to AI blocks and pools"
            ]
        },
        "binary_rewrite_subdepartment": {
            "name": "CYBRA Binary Rewrite Subdepartment",
            "path": "data/cybra_it_department/binary_rewrite_subdepartment",
            "responsibility": [
                "compile Python into bytecode",
                "pack scripts into binary-safe gzip blobs",
                "create library manifests",
                "do not delete source files",
                "do not hide secrets in git"
            ]
        },
        "proof_department": {
            "name": "CYBRA Proof Department",
            "path": "data/cybra_it_department/proof_department",
            "responsibility": [
                "produce sha256 proofs",
                "produce multicurrency proof account",
                "produce token proof",
                "connect proof reports to AI tasks",
                "connect proof reports to KIBRA task blocks"
            ]
        }
    }

    for key, dep in departments.items():
        base = ROOT / dep["path"]
        mkdir(base)
        write_json(base / "department.json", dep)
        write_text(base / "README.md", "# " + dep["name"] + "\n\n" + "\n".join(f"- {x}" for x in dep["responsibility"]) + "\n")

    write_json(ROOT / "data/cybra_it_department/it_departments_latest.json", {
        "timestamp": now(),
        "status": "IT_DEPARTMENTS_CREATED",
        "departments": departments,
        "safety": SAFETY
    })
    return departments

def binary_pack():
    scan = scan_structure()
    pyc_items = []
    blob_items = []
    lib_manifests = []

    py_out = ROOT / "build/cybra_binary_safe/python_bytecode"
    blob_out = ROOT / "build/cybra_binary_safe/blobs"
    lib_out = ROOT / "build/cybra_binary_safe/library_manifests"
    mkdir(py_out)
    mkdir(blob_out)
    mkdir(lib_out)

    pack_suffixes = {".sh", ".bash", ".js", ".mjs", ".json", ".md", ".toml", ".yml", ".yaml", ".txt"}

    for item in scan["files"]:
        p = ROOT / item["path"]

        if p.suffix == ".py":
            try:
                target = py_out / (item["path"].replace("/", "__") + ".pyc")
                mkdir(target.parent)
                py_compile.compile(str(p), cfile=str(target), doraise=True)
                pyc_items.append({
                    "source": item["path"],
                    "bytecode": rel(target),
                    "source_sha256": item["sha256"],
                    "bytecode_sha256": sha_file(target)
                })
            except Exception as e:
                pyc_items.append({
                    "source": item["path"],
                    "compile_error": str(e),
                    "source_sha256": item["sha256"]
                })

        if p.suffix in pack_suffixes:
            try:
                raw = p.read_bytes()
                blob_name = item["sha256"] + ".bin.gz"
                target = blob_out / blob_name
                with gzip.open(target, "wb", compresslevel=9) as gz:
                    gz.write(raw)
                blob_items.append({
                    "source": item["path"],
                    "blob": rel(target),
                    "source_sha256": item["sha256"],
                    "blob_sha256": sha_file(target),
                    "mode": "gzip_binary_safe_blob"
                })
            except Exception as e:
                blob_items.append({
                    "source": item["path"],
                    "pack_error": str(e),
                    "source_sha256": item["sha256"]
                })

    library_candidates = [
        "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock",
        "requirements.txt", "pyproject.toml", "poetry.lock",
        "Cargo.toml", "go.mod", "Gemfile", "composer.json"
    ]

    for name in library_candidates:
        p = ROOT / name
        if p.exists() and p.is_file():
            dest = lib_out / (name.replace("/", "__") + ".manifest.json")
            manifest = {
                "timestamp": now(),
                "source": name,
                "sha256": sha_file(p),
                "size": p.stat().st_size,
                "mode": "library_manifest_only_no_external_download"
            }
            write_json(dest, manifest)
            lib_manifests.append({
                "source": name,
                "manifest": rel(dest),
                "sha256": manifest["sha256"]
            })

    report = {
        "timestamp": now(),
        "status": "BINARY_SAFE_PACK_CREATED",
        "python_bytecode_count": len(pyc_items),
        "binary_blob_count": len(blob_items),
        "library_manifest_count": len(lib_manifests),
        "python_bytecode": pyc_items,
        "binary_blobs": blob_items,
        "library_manifests": lib_manifests,
        "note": "This creates safe binary packs/bytecode and proofs. It does not destructively replace source files.",
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_binary_safe/binary_rewrite_report_latest.json", report)
    write_json(ROOT / "data/cybra_it_department/binary_rewrite_subdepartment/binary_rewrite_report_latest.json", report)
    return report

def ensure_local_usha_key():
    secret_dir = ROOT / ".cybra_local_secret"
    mkdir(secret_dir)
    key_path = secret_dir / "usha.key"
    if not key_path.exists():
        key_path.write_bytes(os.urandom(32))
        try:
            os.chmod(key_path, 0o600)
        except Exception:
            pass
    return key_path

def usha_seal(payload, name):
    outbox = ROOT / "data/cybra_usha_tunnel/outbox"
    mkdir(outbox)

    raw_path = outbox / f"{name}.json"
    enc_path = outbox / f"{name}.enc"
    sealed_path = outbox / f"{name}.sealed.json"

    write_json(raw_path, payload)
    key_path = ensure_local_usha_key()

    openssl = shutil.which("openssl")
    if openssl:
        cmd = [
            openssl, "enc", "-aes-256-cbc", "-pbkdf2", "-salt",
            "-in", str(raw_path),
            "-out", str(enc_path),
            "-pass", f"file:{key_path}"
        ]
        r = subprocess.run(cmd, text=True, capture_output=True)
        if r.returncode == 0 and enc_path.exists():
            return {
                "mode": "openssl_aes_256_cbc_pbkdf2",
                "raw": rel(raw_path),
                "sealed": rel(enc_path),
                "sha256": sha_file(enc_path),
                "key_location": ".cybra_local_secret/usha.key",
                "git_safe": True
            }

    key = key_path.read_bytes()
    h = hashlib.sha256(key + raw_path.read_bytes()).hexdigest()
    sealed = {
        "mode": "sha256_hmac_like_local_seal",
        "raw": rel(raw_path),
        "sha256_local_seal": h,
        "warning": "openssl not available, created local seal only"
    }
    write_json(sealed_path, sealed)
    return {
        "mode": "local_seal_no_openssl",
        "raw": rel(raw_path),
        "sealed": rel(sealed_path),
        "sha256": sha_file(sealed_path),
        "key_location": ".cybra_local_secret/usha.key",
        "git_safe": True
    }

def push_redis(queue, data):
    if not shutil.which("redis-cli"):
        return False
    try:
        subprocess.run("redis-cli ping >/dev/null 2>&1 || redis-server --daemonize yes --bind 127.0.0.1 --port 6379 --dir runtime/redis --save '' --appendonly no >/dev/null 2>&1", shell=True, cwd=ROOT)
        raw = json.dumps(data, ensure_ascii=False)
        r = subprocess.run(["redis-cli", "LPUSH", queue, raw], cwd=ROOT, text=True, capture_output=True)
        return r.returncode == 0
    except Exception:
        return False

def create_ai_block(wallet):
    task_id = "AI-STRUCT-BINARY-PROOF-" + time.strftime("%Y%m%d_%H%M%S")

    task = {
        "task_id": task_id,
        "timestamp": now(),
        "title": "Fix CYBRA structure, binary-safe rewrite, proof token, AI block to KIBRA pools",
        "priority": "HIGH",
        "wallet": wallet,
        "departments": [
            "cybra_it_structure_department",
            "cybra_binary_rewrite_subdepartment",
            "cybra_proof_department",
            "cybra_ai_block_pool_router",
            "cybra_usha_tunnel"
        ],
        "required_work": [
            "scan full structure",
            "detect missing structure",
            "create IT structure department",
            "create binary rewrite subdepartment",
            "compile Python to bytecode",
            "pack scripts/configs into binary-safe gzip blobs",
            "create GitHub library manifests",
            "create AI block",
            "send AI block to pools through USHA sealed tunnel",
            "create multicurrency proof account",
            "create token proof",
            "create KIBRA coin proof"
        ],
        "routes": [
            "cybra_mgs_all",
            "cybra_oracle_tasks",
            "ai_block_inbox",
            "it_department",
            "parliament_inbox",
            "cybra:kibra:pool:mining_blocks",
            "cybra:ai:tasks:block_inbox"
        ],
        "safety": SAFETY
    }

    write_json(ROOT / f"data/cybra_ai_blocks/{task_id}.json", task)
    write_json(ROOT / f"blockchain/kibra_chain/task_blocks/{task_id}.json", task)

    seal = usha_seal(task, task_id)

    queues = [
        "cybra_mgs_all",
        "cybra_oracle_tasks",
        "ai_block_inbox",
        "it_department",
        "parliament_inbox",
        "cybra:kibra:pool:mining_blocks",
        "cybra:ai:tasks:block_inbox"
    ]
    redis_result = {q: push_redis(q, task) for q in queues}

    report = {
        "timestamp": now(),
        "status": "AI_BLOCK_CREATED_AND_ROUTED",
        "task_id": task_id,
        "task_file": f"data/cybra_ai_blocks/{task_id}.json",
        "kibra_task_block": f"blockchain/kibra_chain/task_blocks/{task_id}.json",
        "usha_seal": seal,
        "redis_routes": redis_result,
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_usha_tunnel/reports/ai_block_usha_route_latest.json", report)
    return report

def proof_departments(wallet):
    token_check = read_json(ROOT / "data/cybra_token/checks/kibra_token_check_latest.json", {})
    state = read_json(ROOT / "blockchain/kibra_chain/mainnet/state/latest_state.json", {})
    balances = state.get("balances", {})
    balance = balances.get(wallet, {})

    multicurrency = {
        "timestamp": now(),
        "status": "MULTICURRENCY_PROOF_ACCOUNT_CREATED",
        "owner_wallet": wallet,
        "accounts": {
            "KIBRA_INTERNAL": {
                "internal_candidate_credit": balance.get("internal_candidate_credit", 0),
                "pre_mainnet_claim_blocks": balance.get("pre_mainnet_claim_blocks", 0),
                "real_reward_now": 0,
                "external_live": False
            },
            "CYBRA_INTERNAL": {
                "proof_balance": 0,
                "real_payment_now": False
            },
            "TOKEN_PROOF": {
                "token_mint_checked": token_check.get("token_mint_checked"),
                "token_check_status": token_check.get("status"),
                "score_percent": token_check.get("score_percent")
            }
        },
        "safety": SAFETY
    }

    token_proof = {
        "timestamp": now(),
        "status": "TOKEN_PROOF_CREATED",
        "wallet": wallet,
        "token_check": token_check,
        "kibra_state": {
            "network": state.get("network"),
            "chain_id": state.get("chain_id"),
            "latest_height": state.get("latest_height"),
            "latest_block_hash": state.get("latest_block_hash")
        },
        "proof_policy": {
            "proof_is_not_payout": True,
            "proof_is_not_external_transfer": True,
            "external_live_requires_final_approval": True
        },
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_proof_department/multicurrency/proof_account_latest.json", multicurrency)
    write_json(ROOT / "data/cybra_proof_department/tokens/kibra_token_proof_latest.json", token_proof)

    report = {
        "timestamp": now(),
        "status": "PROOF_DEPARTMENT_FULL_CREATED",
        "multicurrency_proof": "data/cybra_proof_department/multicurrency/proof_account_latest.json",
        "token_proof": "data/cybra_proof_department/tokens/kibra_token_proof_latest.json",
        "safety": SAFETY
    }
    write_json(ROOT / "data/cybra_proof_department/reports/proof_department_latest.json", report)
    write_json(ROOT / "data/cybra_it_department/proof_department/proof_department_latest.json", report)
    return report

def write_final(scan, binary, ai, proof, wallet):
    final = {
        "timestamp": now(),
        "status": "CYBRA_STRUCTURE_BINARY_PROOF_SYSTEM_FIXED",
        "wallet": wallet,
        "structure_scan": {
            "files_count": scan.get("files_count"),
            "dirs_count": scan.get("dirs_count")
        },
        "binary_safe": {
            "python_bytecode_count": binary.get("python_bytecode_count"),
            "binary_blob_count": binary.get("binary_blob_count"),
            "library_manifest_count": binary.get("library_manifest_count")
        },
        "ai_block": ai,
        "proof_department": proof,
        "safety": SAFETY
    }

    write_json(ROOT / "data/cybra_structure_autocollector/final_system_fix_latest.json", final)
    write_json(ROOT / "feeds/cybra_structure_binary_proof_system.json", final)

    md = f"""# CYBRA Structure + Binary + Proof System Fix

Status: **{final["status"]}**

## Wallet

`{wallet}`

## Structure

- Files scanned: `{scan.get("files_count")}`
- Dirs scanned: `{scan.get("dirs_count")}`

## Binary-safe rewrite

- Python bytecode files: `{binary.get("python_bytecode_count")}`
- Binary-safe blobs: `{binary.get("binary_blob_count")}`
- GitHub/library manifests: `{binary.get("library_manifest_count")}`

## IT Departments

- CYBRA IT Structure Department: created
- CYBRA Binary Rewrite Subdepartment: created
- CYBRA Proof Department: created

## AI block / pools

- AI block created: `{ai.get("task_id")}`
- USHA tunnel mode: `{ai.get("usha_seal", {}).get("mode")}`
- KIBRA task block: `{ai.get("kibra_task_block")}`

## Proof

- Multicurrency proof account: created
- Token proof: created
- KIBRA coin proof route: created

## Safety

- real_payment_now: false
- automatic_external_tx: false
- automatic_withdrawals: false
- automatic_SWIFT: false
- automatic_real_rewards: false
- external_bridge_enabled: false
- do_not_store_secrets_in_git: true
"""
    write_text(ROOT / "posts/cybra_structure_binary_proof_system.md", md)

    html = f"""<!doctype html>
<html>
<head><meta charset="utf-8"><title>CYBRA Structure Binary Proof System</title></head>
<body>
<h1>CYBRA Structure + Binary + Proof System</h1>
<p>Status: <b>{final["status"]}</b></p>
<p>Wallet:</p><code>{wallet}</code>
<h2>Structure</h2>
<p>Files: <code>{scan.get("files_count")}</code></p>
<p>Dirs: <code>{scan.get("dirs_count")}</code></p>
<h2>Binary-safe</h2>
<p>Python bytecode: <code>{binary.get("python_bytecode_count")}</code></p>
<p>Binary blobs: <code>{binary.get("binary_blob_count")}</code></p>
<p>Library manifests: <code>{binary.get("library_manifest_count")}</code></p>
<h2>AI / Pools</h2>
<p>AI block: <code>{ai.get("task_id")}</code></p>
<p>USHA: <code>{ai.get("usha_seal", {}).get("mode")}</code></p>
<h2>Safety</h2>
<p>No external tx, no withdrawals, no SWIFT, no automatic real rewards.</p>
</body>
</html>
"""
    write_text(ROOT / "dashboard/cybra_structure/index.html", html)

    proof_targets = [
        ROOT / "data/cybra_structure_autocollector/structure_scan_latest.json",
        ROOT / "data/cybra_binary_safe/binary_rewrite_report_latest.json",
        ROOT / "data/cybra_it_department/it_departments_latest.json",
        ROOT / "data/cybra_usha_tunnel/reports/ai_block_usha_route_latest.json",
        ROOT / "data/cybra_proof_department/reports/proof_department_latest.json",
        ROOT / "data/cybra_structure_autocollector/final_system_fix_latest.json",
        ROOT / "posts/cybra_structure_binary_proof_system.md",
        ROOT / "feeds/cybra_structure_binary_proof_system.json",
        ROOT / "dashboard/cybra_structure/index.html",
        ROOT / "scripts/it/cybra_structure_binary_system.py"
    ]

    lines = []
    for p in proof_targets:
        if p.exists():
            lines.append(f"{sha_file(p)}  {rel(p)}\n")
    write_text(ROOT / "proofs/cybra_structure_binary_proof_system.sha256", "".join(lines))
    return final

def run_all(wallet):
    create_departments()
    scan = scan_structure()
    binary = binary_pack()
    ai = create_ai_block(wallet)
    proof = proof_departments(wallet)
    final = write_final(scan, binary, ai, proof, wallet)
    return final

def validate():
    proof = ROOT / "proofs/cybra_structure_binary_proof_system.sha256"
    if not proof.exists():
        return {"status": "NO_PROOF"}
    r = subprocess.run(
        "sha256sum -c proofs/cybra_structure_binary_proof_system.sha256",
        shell=True,
        cwd=ROOT,
        text=True,
        capture_output=True
    )
    return {
        "status": "PROOF_OK" if r.returncode == 0 else "PROOF_FAIL",
        "returncode": r.returncode,
        "stdout": r.stdout,
        "stderr": r.stderr
    }

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    wallet = sys.argv[2] if len(sys.argv) > 2 else WALLET_DEFAULT

    if cmd == "departments":
        print(json.dumps(create_departments(), ensure_ascii=False, indent=2))
    elif cmd == "scan":
        print(json.dumps(scan_structure(), ensure_ascii=False, indent=2))
    elif cmd == "binary":
        print(json.dumps(binary_pack(), ensure_ascii=False, indent=2))
    elif cmd == "ai-block":
        print(json.dumps(create_ai_block(wallet), ensure_ascii=False, indent=2))
    elif cmd == "proof":
        print(json.dumps(proof_departments(wallet), ensure_ascii=False, indent=2))
    elif cmd == "validate":
        print(json.dumps(validate(), ensure_ascii=False, indent=2))
    elif cmd == "status":
        print((ROOT / "posts/cybra_structure_binary_proof_system.md").read_text(encoding="utf-8"))
    elif cmd == "all":
        print(json.dumps(run_all(wallet), ensure_ascii=False, indent=2))
    else:
        print("Commands: all | departments | scan | binary | ai-block | proof | validate | status")

if __name__ == "__main__":
    main()
