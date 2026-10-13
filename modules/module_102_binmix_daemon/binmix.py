#!/usr/bin/env python3
"""BinaryMixer — 5 шарів хешів. Змішує різні джерела ентропії."""
import json, os, hashlib, time
from pathlib import Path
H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent
STATE = D / "data" / "mixer.json"

def _hash(data):
    if isinstance(data, str): data = data.encode()
    return hashlib.sha256(data).hexdigest()

def mix_sources():
    """5 джерел: system, users, chain, time, random."""
    sources = {}
    # 1. system
    sources["system"] = _hash(os.uname().nodename + str(os.getpid()))
    # 2. users (з парламенту)
    try:
        import sys
        sys.path.insert(0, str(H/"modules/module_121_parlament"))
        import parliament as P
        addrs = sorted(m["addr"] for m in P.members()["members"] if m.get("active"))
        sources["users"] = _hash("".join(addrs))
    except Exception:
        sources["users"] = "0" * 64
    # 3. chain (останній блок BSC)
    try:
        an = json.loads((H/"run/autonode.json").read_text())
        bsc = an.get("networks", {}).get("bsc_mainnet", {}).get("block", 0)
        sources["chain"] = _hash(str(bsc))
    except Exception:
        sources["chain"] = "0" * 64
    # 4. time (поточний момент)
    sources["time"] = _hash(str(int(time.time())))
    # 5. random (urandom)
    sources["random"] = _hash(os.urandom(32))

    # Фінальний хеш — XOR всіх джерел
    combined = hashlib.sha256()
    for name in sorted(sources.keys()):
        combined.update(sources[name].encode())

    out = {
        "sources": sources,
        "mix": combined.hexdigest(),
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    STATE.write_text(json.dumps(out, indent=2))
    return out

def is_ok():
    """True якщо є свіжий (< 1 год) mix і всі 5 джерел непорожні."""
    if not STATE.exists(): return False
    try:
        d = json.loads(STATE.read_text())
        srcs = d.get("sources", {})
        if len(srcs) < 5: return False
        if any(v == "0"*64 for v in srcs.values()): return False
        return bool(d.get("mix"))
    except Exception: return False

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        d = {}
        if STATE.exists():
            try: d = json.loads(STATE.read_text())
            except Exception: pass
        G='\033[32m'; Y='\033[33m'; D='\033[2m'; N='\033[0m'
        print(f"\n  BinaryMixer")
        if d.get("mix"):
            print(f"  Mix: {d['mix'][:32]}…")
            print(f"  At:  {d.get('at','?')}")
            print(f"\n  Джерела:")
            for k, v in d.get("sources", {}).items():
                mark = f"{G}✓{N}" if v and v != "0"*64 else f"{Y}!{N}"
                print(f"    {mark} {k:10s} {v[:20]}…")
        else:
            print(f"  {Y}!{N} ще не запускався")
        print()
    elif cmd == "mix":
        d = mix_sources()
        print(f"✓ mix: {d['mix'][:32]}…")
    elif cmd == "check":
        sys.exit(0 if is_ok() else 1)
