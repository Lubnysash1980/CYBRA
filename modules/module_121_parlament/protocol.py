#!/usr/bin/env python3
"""Генерує HTML (і PDF якщо є конвертер) протокол по пропозиції."""
import sys, os, json, time, subprocess, shutil
from pathlib import Path

D = Path(__file__).resolve().parent
PROTO = D / "protocols"; PROTO.mkdir(exist_ok=True)
H = Path.home() / "CYBRA"
sys.path.insert(0, str(D))

STYLE = """
body{font-family:'DejaVu Sans',system-ui,sans-serif;background:#fff;color:#111;
     max-width:780px;margin:0 auto;padding:40px;line-height:1.5}
h1{font-size:22px;margin:0 0 4px}
.sub{color:#666;font-size:13px;margin-bottom:24px}
table{width:100%;border-collapse:collapse;margin:16px 0;font-size:13px}
th,td{border:1px solid #ddd;padding:8px;text-align:left}
th{background:#f5f5f5}
.badge{display:inline-block;padding:3px 10px;border-radius:20px;font-size:12px;font-weight:700}
.ok{background:#d1f7d1;color:#0a5a0a}.veto{background:#ffd1d1;color:#8a0a0a}
.mono{font-family:'DejaVu Sans Mono',monospace;font-size:11px;word-break:break-all}
.sig{background:#f8f8f8;padding:8px;border-radius:4px;font-size:10px;
     font-family:monospace;word-break:break-all}
.footer{margin-top:40px;padding-top:16px;border-top:1px solid #ddd;
        font-size:11px;color:#666}
.hash{font-family:monospace;font-size:10px;color:#444}
"""

def _esc(s):
    return (str(s).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;"))

def build_html(pid):
    import parliament as P
    prop = P.get_proposal(pid)
    if not prop: return None, "пропозиція не знайдена"
    t = P.tally(pid)
    votes = P.votes_of(pid)
    members = {m["addr"]: m for m in P.members()["members"]}

    status_cls = "ok" if prop.get("status") == "approved" else "veto"
    lines = []
    lines.append("<!doctype html><html lang='uk'><head><meta charset='utf-8'>")
    lines.append(f"<title>Протокол {_esc(pid)}</title>")
    lines.append(f"<style>{STYLE}</style></head><body>")
    lines.append("<h1>CYBRA Parliament · Протокол</h1>")
    lines.append(f"<div class='sub'>PID: <b>{_esc(pid)}</b> · "
                 f"{_esc(prop.get('created',''))}</div>")

    lines.append(f"<p><span class='badge {status_cls}'>"
                 f"{_esc(prop.get('status','').upper())}</span></p>")
    lines.append(f"<h2 style='font-size:16px;margin:16px 0 8px'>"
                 f"{_esc(prop.get('title',''))}</h2>")

    # метадані
    lines.append("<table>")
    lines.append("<tr><th>Тип</th><td>" + _esc(prop.get("type","")) + "</td></tr>")
    lines.append("<tr><th>Автор</th><td>" + _esc(prop.get("author_label","")) +
                 " <span class='mono'>(" + _esc(prop.get("author","")) + ")</span></td></tr>")
    lines.append("<tr><th>Створено</th><td>" + _esc(prop.get("created","")) + "</td></tr>")
    lines.append("<tr><th>Закрито</th><td>" + _esc(prop.get("closed","—")) + "</td></tr>")
    pl = prop.get("payload", {})
    if pl:
        lines.append("<tr><th>Payload</th><td class='mono'>" +
                     _esc(json.dumps(pl, ensure_ascii=False)) + "</td></tr>")
    lines.append("</table>")

    # tally
    lines.append("<h3 style='font-size:14px;margin-top:24px'>Результати голосування</h3>")
    lines.append("<table>")
    lines.append("<tr><th>Показник</th><th>Значення</th></tr>")
    lines.append(f"<tr><td>Кворум (потрібно)</td>"
                 f"<td>{t['participated_weight']} / {t['quorum_needed']} "
                 f"{'✅' if t['quorum_ok'] else '⏳'}</td></tr>")
    lines.append(f"<tr><td>Схвалення (потрібно)</td>"
                 f"<td>{t['approval_percent']}% "
                 f"{'✅' if t['approval_ok'] else '⏳'}</td></tr>")
    lines.append(f"<tr><td>За</td><td>{t['yes']['count']} голос(ів) · вага {t['yes']['weight']}</td></tr>")
    lines.append(f"<tr><td>Проти</td><td>{t['no']['count']} · вага {t['no']['weight']}</td></tr>")
    lines.append(f"<tr><td>Утримались</td><td>{t['abstain']['count']} · вага {t['abstain']['weight']}</td></tr>")
    lines.append("</table>")

    # підписи
    if votes:
        lines.append("<h3 style='font-size:14px;margin-top:24px'>Голоси (підписи)</h3>")
        lines.append("<table>")
        lines.append("<tr><th>Член</th><th>Роль</th><th>Вибір</th><th>Час</th></tr>")
        for v in votes:
            mem = members.get(v["voter"], {})
            lines.append(
                f"<tr><td>{_esc(mem.get('label', v['voter'][:10]))}"
                f" <span class='mono'>{_esc(v['voter'][:14])}…</span></td>"
                f"<td>{_esc(mem.get('role','—'))}</td>"
                f"<td><b>{_esc(v['choice'])}</b></td>"
                f"<td>{_esc(v.get('ts',''))}</td></tr>")
        lines.append("</table>")

        lines.append("<h3 style='font-size:14px;margin-top:24px'>Криптографічні підписи</h3>")
        for v in votes:
            lines.append(f"<div><b>{_esc(v['voter'][:14])}…</b> → <b>{_esc(v['choice'])}</b></div>")
            lines.append(f"<div class='sig'>{_esc(v.get('signature',''))}</div>")

    # veto
    if prop.get("veto"):
        v = prop["veto"]
        lines.append("<h3 style='font-size:14px;margin-top:24px;color:#8a0a0a'>VETO</h3>")
        lines.append("<table>")
        lines.append(f"<tr><th>Ким</th><td class='mono'>{_esc(v.get('by',''))}</td></tr>")
        lines.append(f"<tr><th>Причина</th><td>{_esc(v.get('reason','—'))}</td></tr>")
        lines.append(f"<tr><th>Час</th><td>{_esc(v.get('ts',''))}</td></tr>")
        lines.append("</table>")

    # підпис протоколу (hash)
    import parliament as P2
    canon = json.dumps({"pid":pid, "tally":t, "status":prop.get("status"),
                        "closed":prop.get("closed")}, sort_keys=True).encode()
    import hashlib
    h = hashlib.sha256(canon).hexdigest()
    lines.append("<div class='footer'>")
    lines.append(f"Протокол сформовано: {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}<br>")
    lines.append(f"Хеш протоколу (SHA-256): <span class='hash'>{h}</span><br>")
    lines.append("CYBRA Parliament · {pid}")
    lines.append("</div>")
    lines.append("</body></html>")

    return "\n".join(lines), None

def generate(pid, want_pdf=True):
    html, err = build_html(pid)
    if err: return None, err
    stamp = time.strftime("%Y%m%d_%H%M%S")
    html_p = PROTO / f"protocol_{pid}_{stamp}.html"
    html_p.write_text(html, encoding="utf-8")

    pdf_p = None
    if want_pdf:
        # спробувати конвертери
        for cmd in [
            ["wkhtmltopdf", "--quiet", str(html_p), str(html_p.with_suffix(".pdf"))],
        ]:
            if shutil.which(cmd[0]):
                try:
                    subprocess.run(cmd, timeout=60, capture_output=True)
                    if html_p.with_suffix(".pdf").exists():
                        pdf_p = html_p.with_suffix(".pdf"); break
                except Exception: pass
    return {"html": str(html_p), "pdf": str(pdf_p) if pdf_p else None}, None

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: protocol.py <pid>"); sys.exit(1)
    r, err = generate(sys.argv[1])
    if err: print("✗", err); sys.exit(1)
    print("HTML:", r["html"])
    if r["pdf"]: print("PDF: ", r["pdf"])
    else: print("PDF:  (конвертер не знайдено — відкрий HTML у браузері → Друк → PDF)")
