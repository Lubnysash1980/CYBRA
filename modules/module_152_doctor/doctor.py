#!/usr/bin/env python3
"""Doctor — повна діагностика CYBRA з автофіксом."""
import os, sys, json, subprocess, time, shutil
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
sys.path.insert(0, str(M/"module_121_parlament"))

C_G='\033[32m'; C_Y='\033[33m'; C_R='\033[31m'; C_B='\033[36m'
C_D='\033[2m'; C_BOLD='\033[1m'; C_N='\033[0m'

class Check:
    def __init__(self, name, ok, detail="", fix=None, level="warn"):
        self.name=name; self.ok=ok; self.detail=detail
        self.fix=fix; self.level=level
    def __repr__(self):
        mark = f"{C_G}✓{C_N}" if self.ok else (
            f"{C_R}✗{C_N}" if self.level=="critical" else f"{C_Y}!{C_N}")
        fix_str = f" {C_D}→ {self.fix}{C_N}" if (self.fix and not self.ok) else ""
        return f"  {mark} {self.name:38s} {self.detail}{fix_str}"

def run(cmd, timeout=30):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except Exception: return 1, ""

# ═══════════════════════════════════════════════════════════════
# CHECKS
# ═══════════════════════════════════════════════════════════════
def check_env():
    out = []
    for tool, lvl in [("python3","critical"),("curl","critical"),
                      ("cloudflared","warn"),("git","warn"),
                      ("qrencode","warn"),("termux-open-url","warn")]:
        p = shutil.which(tool)
        out.append(Check(f"Утиліта {tool}", bool(p),
                        p or "не знайдено", f"pkg install {tool}", lvl))
    for mod in ["eth_account","qrcode","nacl","web3","solcx"]:
        rc, _ = run(f"python3 -c 'import {mod}'")
        pkg = {"eth_account":"eth-account","qrcode":"qrcode pillow",
               "nacl":"pynacl","web3":"web3","solcx":"py-solc-x"}[mod]
        out.append(Check(f"Python · {mod}", rc==0,
                        "встановлено" if rc==0 else "відсутній",
                        f"pip install {pkg}" if rc else "", "warn"))
    return out

def check_config():
    out = []
    cfg = H/"config/metamask.env"
    if cfg.exists():
        txt = cfg.read_text()
        import re
        m = re.search(r'BUYER_ADDR="?(0x[a-fA-F0-9]{40})', txt)
        out.append(Check("BUYER_ADDR", bool(m),
                        m.group(1)[:14]+"…" if m else "не вказано",
                        "cybra → 151", "critical"))
    else:
        out.append(Check("config/metamask.env", False, "не існує",
                        "cybra → 151", "critical"))

    # network
    net_cfg = H/"config/networks.json"
    if net_cfg.exists():
        try:
            d = json.loads(net_cfg.read_text())
            cur = d["current"]
            n = d["networks"][cur]
            out.append(Check("Мережа", True,
                            f"{n['name']} (chain_id {n['chain_id']})"))
        except Exception as e:
            out.append(Check("Мережа", False, str(e), "cybra → 200"))
    else:
        out.append(Check("Мережа", False, "networks.json відсутній",
                        "cybra → 200", "critical"))
    return out

def check_services():
    out = []
    for name, pattern in [("AutoNode","autonode/daemon.py"),
                          ("Parliament watchdog","parlament/watchdog"),
                          ("Orchestrator","orchestrator.py daemon")]:
        rc, _ = run(f"pgrep -f {pattern}")
        out.append(Check(name, rc==0,
                        "працює" if rc==0 else "не запущено",
                        "cybra → 121 → 44"))
    return out

def check_modules():
    out = []
    mods = list(M.glob("module_*"))
    stubs = 0; ok_count = 0
    for d in mods:
        main = d/"main.sh"
        if not main.exists(): continue
        try:
            if "TODO: реалізувати" in main.read_text(): stubs += 1
            else: ok_count += 1
        except Exception: pass
    out.append(Check("Модулів реалізовано", stubs==0,
                    f"{ok_count} реальних, {stubs} заглушок",
                    "видалити заглушки" if stubs else ""))
    # TUI syntax
    tui = M/"module_19_contract_tui_menu/bin/cybra_menu.sh"
    rc, _ = run(f"bash -n {tui}")
    out.append(Check("TUI синтаксис", rc==0, "ok" if rc==0 else "зламано",
                    "відкотити з .bak", "critical"))
    return out

def check_integrity():
    out = []
    # parliament chain
    try:
        import parliament as P
        rep = P.verify_chain()
        broken = sum(r["broken"] for r in rep.values())
        out.append(Check("Парламент·hash-chain", broken==0,
                        f"{broken} порушень" if broken else "цілісно",
                        "перевір data/*.jsonl", "critical" if broken else "warn"))
    except Exception as e:
        out.append(Check("Парламент·hash-chain", False, str(e)[:60]))

    # signatures
    ev = M/"module_19_contract_tui_menu/evidence"
    if ev.exists():
        sigs = list(ev.glob("*.sig"))
        try:
            from eth_account import Account
            from eth_account.messages import encode_defunct
            bad = 0
            for s in sorted(sigs, key=lambda p: p.stat().st_mtime, reverse=True)[:10]:
                try:
                    d = json.loads(s.read_text())
                    rec = Account.recover_message(
                        encode_defunct(text=d["message"]), signature=d["signature"])
                    if rec.lower() != d["address"].lower(): bad += 1
                except Exception: bad += 1
            out.append(Check("Підписи·валідність", bad==0,
                            f"{len(sigs)} всього, {bad} невалідних",
                            "completion engine" if bad else ""))
        except ImportError:
            out.append(Check("Підписи·валідність", True, "eth_account відсутній", level="warn"))
    return out

def check_disk():
    out = []
    total, used, free = shutil.disk_usage(str(H))
    free_mb = free // (1024*1024)
    out.append(Check("Диск", free_mb > 200,
                    f"{free_mb} MB вільно",
                    "cleanup" if free_mb <= 200 else "",
                    "critical" if free_mb < 100 else "warn"))

    # sizes
    for sub, limit_mb in [("logs",100),("backups",500)]:
        p = H/sub
        if not p.exists(): continue
        rc, out_s = run(f"du -sm {p}")
        try: mb = int(out_s.split()[0])
        except Exception: mb = 0
        out.append(Check(f"Розмір {sub}", mb < limit_mb,
                        f"{mb} MB",
                        f"cleanup {sub}" if mb >= limit_mb else ""))
    return out

def check_crypto():
    out = []
    # ed25519 keys для 119
    kd = M/"module_119_qr_sign/keys"
    if kd.exists():
        for k in ["hmac.key","ed25519.priv"]:
            f = kd/k
            if f.exists():
                m = f.stat().st_mode & 0o777
                out.append(Check(f"Ключ {k}", m==0o600,
                                f"0o{m:o}",
                                f"chmod 600 {f}",
                                "critical" if m != 0o600 else "warn"))
    return out

def check_deployed():
    out = []
    dep = H/"config/deployed.json"
    if dep.exists():
        try:
            d = json.loads(dep.read_text())
            out.append(Check("Deployed контракти", True,
                            f"{len(d)} шт ({', '.join(d.keys())})"))
        except Exception:
            out.append(Check("Deployed контракти", False, "битий JSON"))
    else:
        out.append(Check("Deployed контракти", True,
                        "не задеплоєно (нормально)",
                        "cybra → 121 → 66", "warn"))
    return out

# ═══════════════════════════════════════════════════════════════
# AUTO FIX
# ═══════════════════════════════════════════════════════════════
def auto_fix(checks):
    fixed = []
    for c in checks:
        if c.ok or not c.fix: continue
        # безпечні автодії
        if c.fix.startswith("pkg install"):
            pkg = c.fix.split()[-1]
            rc, _ = run(f"pkg install -y {pkg}", timeout=300)
            if rc==0: fixed.append(f"installed {pkg}")
        elif c.fix.startswith("pip install"):
            pkgs = c.fix.replace("pip install","").strip()
            rc, _ = run(f"pip install --quiet {pkgs}", timeout=300)
            if rc==0: fixed.append(f"pip {pkgs}")
        elif c.fix.startswith("chmod 600"):
            path = c.fix.split()[-1]
            try: os.chmod(path, 0o600); fixed.append(f"chmod {path}")
            except Exception: pass
        elif c.fix == "cybra → 121 → 44":
            rc, _ = run(f"bash {M}/module_121_parlament/watchdog.sh start", timeout=30)
            if rc==0: fixed.append("watchdog started")
    return fixed

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════
def main():
    print(f"\n{C_B}{C_BOLD}═══════════════════════════════════════════════════════════{C_N}")
    print(f"{C_B}{C_BOLD}  CYBRA · Doctor{C_N}")
    print(f"{C_B}{C_BOLD}═══════════════════════════════════════════════════════════{C_N}")

    groups = {
        "Середовище": check_env(),
        "Конфігурація": check_config(),
        "Сервіси": check_services(),
        "Модулі": check_modules(),
        "Цілісність": check_integrity(),
        "Ресурси": check_disk(),
        "Крипто ключі": check_crypto(),
        "Deployed": check_deployed(),
    }

    total = ok_n = fail_n = crit_n = 0
    for group, checks in groups.items():
        print(f"\n{C_B}▸ {group}{C_N}")
        for c in checks:
            print(f"  {c}")
            total += 1
            if c.ok: ok_n += 1
            else:
                fail_n += 1
                if c.level == "critical": crit_n += 1

    print(f"\n{C_B}═══════════════════════════════════════════════════════════{C_N}")
    if crit_n:
        print(f"  {C_R}🚨 {crit_n} critical, {fail_n} всього проблем{C_N}")
    elif fail_n:
        print(f"  {C_Y}🟡 {fail_n} warn (не критично){C_N}")
    else:
        print(f"  {C_G}✅ {ok_n}/{total} — все гаразд{C_N}")
    print(f"{C_B}═══════════════════════════════════════════════════════════{C_N}\n")

    # автолікування
    if fail_n and "--fix" in sys.argv:
        print(f"{C_B}▸ Auto-fix{C_N}")
        fixed = auto_fix([c for g in groups.values() for c in g])
        if fixed:
            for f in fixed: print(f"  {C_G}✓{C_N} {f}")
            print(f"\n  Запусти doctor знову щоб перевірити\n")
        else:
            print(f"  {C_Y}нічого автоматично не виправлено{C_N}\n")

    return 0 if crit_n == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
