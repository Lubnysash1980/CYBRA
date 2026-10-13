#!/usr/bin/env python3
"""Завантажує офіційні списки санкцій:
  - US OFAC SDN (XML, treasury.gov)
  - EU Consolidated (XML, europa.eu)
Витягує крипто-адреси (Digital Currency Address) у локальний JSON."""
import json, os, sys, urllib.request, re, time, xml.etree.ElementTree as ET
from pathlib import Path

D = Path(__file__).resolve().parent
LISTS = D / "data/lists"; LISTS.mkdir(parents=True, exist_ok=True)
OUT = LISTS / "crypto_addresses.json"

SOURCES = {
    "ofac_sdn": "https://www.treasury.gov/ofac/downloads/sdn.xml",
    "ofac_alt": "https://www.treasury.gov/ofac/downloads/alt.xml",
    "ofac_add": "https://www.treasury.gov/ofac/downloads/add.xml",
    "eu_consolidated": "https://webgate.ec.europa.eu/fsd/fsf/public/files/xmlFullSanctionsList_1_1/content?token=free",
}

# Регекси для різних крипто-адрес
ADDR_PATTERNS = {
    "ETH":  re.compile(r'\b0x[a-fA-F0-9]{40}\b'),
    "BTC":  re.compile(r'\b(bc1[a-z0-9]{25,90}|[13][a-km-zA-HJ-NP-Z1-9]{25,34})\b'),
    "XMR":  re.compile(r'\b[48][0-9AB][1-9A-HJ-NP-Za-km-z]{93}\b'),
    "TRX":  re.compile(r'\bT[a-zA-Z0-9]{33}\b'),
    "XRP":  re.compile(r'\br[a-zA-Z0-9]{24,34}\b'),
    "LTC":  re.compile(r'\b(L[a-km-zA-HJ-NP-Z1-9]{26,33}|ltc1[a-z0-9]{25,90})\b'),
    "BCH":  re.compile(r'\b(q[a-z0-9]{41}|p[a-z0-9]{41})\b'),
}

def _download(url, timeout=30):
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (CYBRA-KYC/1.0)",
            "Accept": "application/xml,text/xml,*/*",
        })
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read()
    except Exception as e:
        print(f"  ! {url}: {e}", file=sys.stderr)
        return None

def _extract_from_text(text):
    """Шукає всі крипто-адреси в довільному тексті."""
    found = {}
    for sym, pat in ADDR_PATTERNS.items():
        for m in pat.findall(text):
            found.setdefault(sym, set()).add(m if isinstance(m, str) else m)
    return found

def parse_ofac(xml_bytes):
    """OFAC SDN XML → адреси. Шукає поля Digital Currency Address."""
    out = {"ETH": set(), "BTC": set(), "XMR": set(), "TRX": set(),
           "XRP": set(), "LTC": set(), "BCH": set()}
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as e:
        print(f"  ! OFAC parse: {e}", file=sys.stderr)
        return out

    # Проходимо всі елементи, шукаємо текст і атрибути
    for elem in root.iter():
        # Текст
        if elem.text:
            f = _extract_from_text(elem.text)
            for k, v in f.items():
                out.setdefault(k, set()).update(v)
        # Атрибути (ID, DigitalCurrencyAddress, etc.)
        for attr_val in elem.attrib.values():
            f = _extract_from_text(attr_val)
            for k, v in f.items():
                out.setdefault(k, set()).update(v)

    # Специфічно OFAC має <idList><id ID="...">1234... де ID це HEX або addr
    for id_elem in root.iter("id"):
        id_type = id_elem.get("idType", "").lower()
        val = (id_elem.text or "").strip()
        if not val: continue
        if "digital currency address" in id_type or "crypto" in id_type:
            # визначити тип за префіксом
            if val.startswith("0x") and len(val) == 42:
                out["ETH"].add(val.lower())
            elif val.startswith(("1", "3", "bc1")):
                out["BTC"].add(val)
            elif val.startswith("T"):
                out["TRX"].add(val)
            elif val.startswith("r"):
                out["XRP"].add(val)
            elif val.startswith("L"):
                out["LTC"].add(val)
            elif val.startswith(("q", "p")):
                out["BCH"].add(val)
            elif val.startswith(("4", "8")):
                out["XMR"].add(val)
    return out

def parse_eu(xml_bytes):
    """EU consolidated XML — адреси трапляються в remark полях."""
    out = {}
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as e:
        print(f"  ! EU parse: {e}", file=sys.stderr)
        return out
    for elem in root.iter():
        if elem.text:
            f = _extract_from_text(elem.text)
            for k, v in f.items():
                out.setdefault(k, set()).update(v)
    return out

def fetch_all():
    """Завантажує все і зберігає консолідований список."""
    print(f"▸ Fetching sanctions lists · {time.strftime('%Y-%m-%d %H:%M')}")
    all_addr = {"ETH": set(), "BTC": set(), "XMR": set(), "TRX": set(),
                "XRP": set(), "LTC": set(), "BCH": set()}
    meta = {"fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "sources": {}}

    # OFAC
    for name in ("ofac_sdn", "ofac_alt", "ofac_add"):
        url = SOURCES[name]
        data = _download(url)
        if data:
            print(f"  ✓ {name}: {len(data)//1024} KB")
            parsed = parse_ofac(data)
            for k, v in parsed.items():
                all_addr.setdefault(k, set()).update(v)
            meta["sources"][name] = {"size": len(data),
                                     "fetched": meta["fetched_at"]}

    # EU
    data = _download(SOURCES["eu_consolidated"])
    if data:
        print(f"  ✓ eu_consolidated: {len(data)//1024} KB")
        parsed = parse_eu(data)
        for k, v in parsed.items():
            all_addr.setdefault(k, set()).update(v)
        meta["sources"]["eu_consolidated"] = {"size": len(data),
                                              "fetched": meta["fetched_at"]}

    # Зберігаємо як плоский set (lowercase для ETH/TRX)
    flat = {}
    for sym, s in all_addr.items():
        normalized = set()
        for a in s:
            normalized.add(a.lower() if sym in ("ETH", "TRX") else a)
        if normalized:
            flat[sym] = sorted(normalized)
    flat["_meta"] = meta
    OUT.write_text(json.dumps(flat, indent=2))
    total = sum(len(v) for k, v in flat.items() if k != "_meta")
    print(f"\n✓ Збережено {total} адрес у {OUT}")
    for sym in ADDR_PATTERNS:
        n = len(flat.get(sym, []))
        if n: print(f"    {sym}: {n}")
    return flat

if __name__ == "__main__":
    fetch_all()
