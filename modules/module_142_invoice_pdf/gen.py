#!/usr/bin/env python3
"""Генерація HTML/PDF з INVOICE. HTML → браузер → Ctrl+P → PDF."""
import json, sys, os, time
from pathlib import Path
H = Path.home() / "CYBRA"
D = Path(__file__).resolve().parent

def load_invoice(cid):
    for p in [H/f"modules/module_111_invoice/data/{cid}.json",
              H/f"modules/module_19_contract_tui_menu/evidence/{cid}.json"]:
        if p.exists():
            try: return json.loads(p.read_text())
            except Exception: pass
    return None

def build_html(inv):
    items = inv.get("invoice", {}).get("items", [])
    rows = ""
    for it in items:
        rows += (f"<tr><td>{it.get('no','')}</td><td>{it.get('code','')}</td>"
                 f"<td>{it.get('name','')}</td>"
                 f"<td style='text-align:center'>{it.get('qty',1)}</td>"
                 f"<td style='text-align:right'>{it.get('price_uah',0):,.2f}</td>"
                 f"<td style='text-align:right'>{it.get('sum_uah',0):,.2f}</td></tr>")

    sup = inv.get("invoice", {}).get("supplier", {})
    inv_info = inv.get("invoice", {})

    html = f"""<!doctype html>
<html><head><meta charset="utf-8">
<title>Рахунок {inv_info.get('no','')}</title>
<style>
body {{ font-family: 'DejaVu Sans', Arial, sans-serif; max-width: 800px; margin: 30px auto; padding: 20px; color: #111; }}
h1 {{ font-size: 20px; margin: 0; }}
.sub {{ color: #666; font-size: 13px; margin: 4px 0 24px; }}
table {{ width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 13px; }}
th, td {{ border: 1px solid #333; padding: 6px 8px; }}
th {{ background: #f0f0f0; text-align: left; }}
.totals {{ margin-top: 12px; text-align: right; font-size: 14px; }}
.totals b {{ font-size: 16px; }}
.hash {{ font-family: monospace; font-size: 10px; color: #666; margin-top: 24px; }}
.supplier {{ margin-bottom: 20px; }}
@media print {{ body {{ margin: 0; }} .no-print {{ display: none; }} }}
.no-print {{ text-align: center; margin: 20px 0; }}
.no-print button {{ padding: 12px 24px; font-size: 16px; background: #2ea043; color: white; border: 0; border-radius: 8px; cursor: pointer; }}
</style></head><body>
<div class="no-print"><button onclick="window.print()">🖨 Друк → PDF</button></div>
<h1>Рахунок-фактура {inv_info.get('no','')}</h1>
<div class="sub">від {inv_info.get('date','')} · CID: {inv.get('cid','')}</div>

<div class="supplier">
<b>Постачальник:</b> {sup.get('name','')}<br>
ЄДРПОУ: {sup.get('edrpou','')} · ІПН: {sup.get('ipn','')}<br>
IBAN: {sup.get('iban','')} · МФО: {sup.get('mfo','')}
</div>

<div><b>Покупець:</b> {inv.get('buyer_name', inv.get('buyer',''))}</div>

<table>
<tr><th>#</th><th>Код</th><th>Найменування</th><th>К-сть</th><th>Ціна</th><th>Сума</th></tr>
{rows}
</table>

<div class="totals">
Сума без ПДВ: <b>{inv_info.get('subtotal_uah', inv.get('total_uah',0) - inv_info.get('vat_uah',0)):,.2f} UAH</b><br>
ПДВ: {inv_info.get('vat_uah',0):,.2f} UAH<br>
<b>Всього: {inv.get('total_uah',0):,.2f} UAH</b>
</div>

<div class="hash">
Content hash: {inv_info.get('content_hash','')}<br>
Generated: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}<br>
Pay to: {inv.get('pay_to','')}
</div>
</body></html>"""
    return html

def generate(cid, open_browser=True):
    inv = load_invoice(cid)
    if not inv: return False, f"не знайдено invoice: {cid}", None
    html = build_html(inv)
    out = D / "data" / f"invoice_{cid}_{int(time.time())}.html"
    out.write_text(html, encoding="utf-8")
    if open_browser:
        import subprocess
        try: subprocess.Popen(["termux-open-url", f"file://{out}"])
        except Exception: pass
    return True, str(out), html

if __name__ == "__main__":
    if len(sys.argv) < 2: print("usage: gen.py <cid>"); sys.exit(1)
    ok, path, html = generate(sys.argv[1])
    print(("✓ " if ok else "✗ ") + path)
