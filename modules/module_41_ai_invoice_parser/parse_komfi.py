#!/usr/bin/env python3
"""Парсер рахунків Комфі."""
import json, re, sys, hashlib, time

def parse(text):
    out = {"source": "komfi", "parsed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    m = re.search(r'Рахунок-фактура\s+№\s+([А-ЯІЇЄA-Z]{2}\d{4}-\d{5})', text)
    if not m: m = re.search(r'№\s*([А-ЯІЇЄA-Z]{2}\d{4}-\d{5})', text)
    out["invoice_no"] = m.group(1) if m else None

    m = re.search(r'від\s+(\d{2}\.\d{2}\.\d{4})', text)
    out["date"] = m.group(1) if m else None

    m = re.search(r'до сплати до\s+(\d{2}\.\d{2}\.\d{4})', text)
    out["valid_until"] = m.group(1) if m else None

    m = re.search(r'ТОВАРИСТВО З ОБМЕЖЕНОЮ ВІДПОВІДАЛЬНІСТЮ\s+"([^"]+)"', text)
    supplier = m.group(1) if m else None
    m = re.search(r'ЄДРПОУ\s+(\d{8})', text)
    edrpou = m.group(1) if m else None
    m = re.search(r'ІПН\s+(\d{12})', text)
    ipn = m.group(1) if m else None
    m = re.search(r'(р/р\s+UA\d+)', text)
    iban = m.group(1).replace("р/р ", "") if m else None
    m = re.search(r'МФО\s+(\d{6})', text)
    mfo = m.group(1) if m else None
    out["supplier"] = {"name": supplier, "edrpou": edrpou, "ipn": ipn, "iban": iban, "mfo": mfo}

    m = re.search(r'([А-ЯІЇЄ][а-яіїє]+)\s+([А-ЯІЇЄ][а-яіїє]+)\s+([А-ЯІЇЄ][а-яіїє]+)', text)
    out["buyer_name"] = " ".join(m.groups()) if m else None

    m = re.search(r'Сума з ПДВ:\s*([\d\s,\.]+)', text)
    out["total_uah"] = float(m.group(1).replace(" ", "").replace(",", ".")) if m else None
    m = re.search(r'ПДВ:\s*([\d\s,\.]+)', text)
    out["vat_uah"] = float(m.group(1).replace(" ", "").replace(",", ".")) if m else None

    items = []
    for line in text.split("\n"):
        m = re.match(r'^\s*(\d+)\s+(\d{7,})\s+(.+?)\s+(шт\.|компл\.)\s+(\d+)%\s+(\d+)\s+([\d\s,\.]+)\s+([\d\s,\.]+)\s*$', line)
        if m:
            items.append({
                "no": int(m.group(1)), "code": m.group(2),
                "name": m.group(3).strip(), "unit": m.group(4),
                "vat_pct": int(m.group(5)), "qty": int(m.group(6)),
                "price_uah": float(m.group(7).replace(" ", "").replace(",", ".")),
                "sum_uah": float(m.group(8).replace(" ", "").replace(",", ".")),
            })
    out["items"] = items
    out["items_count"] = len(items)
    canon = json.dumps(out, sort_keys=True, ensure_ascii=False).encode()
    out["content_hash"] = hashlib.sha256(canon).hexdigest()
    return out

if __name__ == "__main__":
    if len(sys.argv) < 2: print("usage: parse_komfi.py <file.txt>"); sys.exit(1)
    txt = open(sys.argv[1], encoding="utf-8").read()
    print(json.dumps(parse(txt), indent=2, ensure_ascii=False))
