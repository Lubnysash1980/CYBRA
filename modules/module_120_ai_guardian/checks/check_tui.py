"""TUI: чи всі заявлені пункти існують, чи не зламаний case."""
import subprocess, re
from pathlib import Path

H = Path.home() / "CYBRA"
TUI = H / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

def run():
    out = []
    if not TUI.exists():
        return [{"id":"tui","name":"TUI","status":"critical",
                 "detail":"не знайдено","fix_hint":""}]
    r = subprocess.run(["bash","-n",str(TUI)], capture_output=True, text=True)
    if r.returncode != 0:
        return [{"id":"tui.syntax","name":"TUI синтаксис","status":"critical",
                 "detail":r.stderr[:120],"fix_hint":"відкоти останній .bak"}]
    out.append({"id":"tui.syntax","name":"TUI синтаксис","status":"ok",
                "detail":"ok","fix_hint":""})

    src = TUI.read_text()
    # Очікуємо обробники
    expected = ["108","109","110","111","112","113","114","115","116","117","118","119","120"]
    missing = [n for n in expected if not re.search(rf'^\s*{n}\)', src, re.M)]
    if missing:
        out.append({"id":"tui.handlers","name":"TUI case-обробники","status":"warn",
                    "detail":f"відсутні: {','.join(missing)}","fix_hint":""})
    else:
        out.append({"id":"tui.handlers","name":"TUI case-обробники","status":"ok",
                    "detail":f"{len(expected)} шт","fix_hint":""})
    return out
