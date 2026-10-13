#!/usr/bin/env python3
"""WalletConnect-style deep links (без SDK — простий редирект)."""
import sys, urllib.parse, os, json, time
from pathlib import Path

# Стандартні deep-link схеми для популярних гаманців
WALLETS = {
    "metamask":     "https://metamask.app.link/dapp/{url}",
    "trust":        "https://link.trustwallet.com/open_url?coin_id=60&url={url}",
    "rainbow":      "https://rnbwapp.com/dapp?url={url}",
    "coinbase":     "https://go.cb-w.com/dapp?cb_url={url}",
    "imtoken":      "imtokenv2://navigate/DappView?url={url}",
    "argent":       "argent://app?dappUrl={url}",
    "gnosis":       "https://app.safe.global/dapps?url={url}",
}

def link(wallet, url):
    tpl = WALLETS.get(wallet.lower())
    if not tpl: return None
    return tpl.format(url=urllib.parse.quote(url, safe=""))

def all_links(url):
    return {w: link(w, url) for w in WALLETS}

def open_wallet(wallet, url):
    l = link(wallet, url)
    if not l: return False, "unknown wallet"
    import subprocess
    try:
        subprocess.run(["termux-open-url", l], timeout=5, check=False)
        return True, l
    except Exception as e:
        return False, str(e)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for w in WALLETS: print(f"  {w}")
    elif cmd == "link":
        print(link(sys.argv[2], sys.argv[3]))
    elif cmd == "all":
        for w, l in all_links(sys.argv[2]).items():
            print(f"  {w:12s} {l}")
    elif cmd == "open":
        ok, m = open_wallet(sys.argv[2], sys.argv[3])
        print(("✓ " if ok else "✗ ") + m)
