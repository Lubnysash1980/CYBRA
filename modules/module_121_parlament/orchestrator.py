#!/usr/bin/env python3
"""CYBRA Orchestrator — парламент керує всім:
  - авто-інсталяція модулів з каталогу
  - авто-тести
  - авто-фікси
  - авто-інтеграція (TUI, case, hooks)
  - моніторинг роботи та виконання
"""
import json, os, sys, time, subprocess, shutil, hashlib, tempfile, re
from pathlib import Path
from collections import Counter, defaultdict

D = Path(__file__).resolve().parent
H = Path.home() / "CYBRA"
M = H / "modules"
sys.path.insert(0, str(D))

C_G='\033[32m'; C_Y='\033[33m'; C_R='\033[31m'; C_B='\033[36m'
C_D='\033[2m'; C_BOLD='\033[1m'; C_N='\033[0m'

def log(msg, level="info"):
    try:
        import stream
        stream.system("orchestrator", {"msg": msg[:200]}, level=level)
    except Exception: pass

# ═══════════════════════════════════════════════════════════════
# CATALOG — реєстр відомих модулів
# ═══════════════════════════════════════════════════════════════
class Catalog:
    def __init__(self):
        self.dir = D / "catalog"
        self.user_dir = H / "catalog"
        self.dir.mkdir(exist_ok=True)
        self.user_dir.mkdir(exist_ok=True)
        self._default()

    def _default(self):
        """Створює базовий catalog.json якщо немає."""
        p = self.dir / "default.json"
        if p.exists(): return
        entries = []
        # Всі модулі які ми вже маємо — щоб знати про них
        for mod_dir in sorted(M.glob("module_*")):
            m = re.match(r'module_(\d+)_(.+)', mod_dir.name)
            if not m: continue
            mid, slug = m.group(1), m.group(2)
            entries.append({
                "id": mid, "slug": slug,
                "name": slug.replace("_", " ").title(),
                "category": "core",
                "source": f"local://{mod_dir.name}",
                "tui_section": self._section_of(mid),
                "tui_menu": f"[{mid}] {slug.replace('_',' ')[:40]}",
                "install": "skip",  # вже встановлено локально
                "verify": f"test -d modules/{mod_dir.name}",
                "requires": [],
            })
        # Шаблони для нових модулів
        for mid, name, cat in [
            ("141", "Portfolio Tracker", "finance"),
            ("142", "Invoice PDF Export", "docs"),
            ("143", "Email Notifications", "integrations"),
            ("144", "Bitcoin Lightning", "chain"),
            ("145", "IPFS Pinning", "storage"),
            ("146", "Merkle Batching", "crypto"),
            ("147", "On-chain Reputation v2", "chain"),
            ("148", "Multisig UI", "ui"),
            ("149", "Advanced Analytics", "ui"),
            ("150", "Custom Scripts", "tools"),
        ]:
            entries.append({
                "id": mid, "slug": name.lower().replace(" ", "_"),
                "name": name, "category": cat,
                "source": "template://basic",
                "tui_section": self._section_of(mid),
                "tui_menu": f"[{mid}] {name}",
                "install": "template",
                "verify": f"test -d modules/module_{mid}_*",
                "requires": [],
            })
        p.write_text(json.dumps(entries, indent=2, ensure_ascii=False))

    def _section_of(self, mid):
        n = int(mid)
        if n < 30: return "MAIN"
        if n < 45: return "SYSTEM"
        if n < 60: return "INTEGRATIONS"
        if n < 75: return "DISPUTE/AUDIT"
        if n < 100: return "GUARDIAN"
        if n < 122: return "NODE/HASH"
        if n < 125: return "METAMASK"
        if n < 141: return "ADVANCED"
        return "ORCHESTRATOR"

    def load(self):
        out = []
        seen = set()
        for d in [self.dir, self.user_dir]:
            for f in sorted(d.glob("*.json")):
                try: data = json.loads(f.read_text())
                except Exception: continue
                if isinstance(data, list):
                    for e in data:
                        if e.get("id") and e["id"] not in seen:
                            seen.add(e["id"]); out.append(e)
        return out

    def get(self, mid):
        for e in self.load():
            if e["id"] == str(mid): return e
        return None

# ═══════════════════════════════════════════════════════════════
# INSTALLER — авто-інсталяція
# ═══════════════════════════════════════════════════════════════
class Installer:
    def __init__(self, catalog):
        self.catalog = catalog

    def installed_ids(self):
        return {re.match(r'module_(\d+)_', d.name).group(1)
                for d in M.glob("module_*") if re.match(r'module_(\d+)_', d.name)}

    def missing(self):
        """Повертає модулі каталогу які ще не встановлені."""
        have = self.installed_ids()
        return [e for e in self.catalog.load() if e["id"] not in have]

    def install(self, entry, dry_run=False):
        """Встановлює модуль згідно з source."""
        src = entry.get("source", "")
        mid = entry["id"]; slug = entry.get("slug","mod")

        if src.startswith("local://"):
            return True, f"локальний, не потребує інсталяції"
        if src.startswith("template://"):
            return self._install_template(entry, dry_run)
        if src.startswith("git://") or src.startswith("https://"):
            return self._install_remote(entry, dry_run)
        return False, f"невідоме source: {src}"

    def _install_template(self, entry, dry_run):
        """Створює базовий модуль з шаблону."""
        mid = entry["id"]; slug = entry["slug"]
        target = M / f"module_{mid}_{slug}"
        if dry_run:
            return True, f"[dry] створив би {target.name}"
        if target.exists():
            return True, f"вже існує"
        target.mkdir(parents=True, exist_ok=True)
        (target / "data").mkdir(exist_ok=True)
        (target / "main.sh").write_text(self._template_main(mid, entry["name"]))
        os.chmod(target / "main.sh", 0o755)
        (target / "README.md").write_text(
            f"# {entry['name']}\n\nМодуль {mid} · категорія {entry['category']}\n\n"
            f"Автоматично створено оркестратором.\n")
        log(f"install template: {mid} {entry['name']}")
        return True, f"створено {target.name}"

    def _template_main(self, mid, name):
        return f'''#!/data/data/com.termux/files/usr/bin/bash
# module_{mid} — {name}
B=$'\\e[36m'; G=$'\\e[32m'; N=$'\\e[0m'
while :; do
  clear
  echo "${{B}}═══ {name} ═══${{N}}"
  echo
  echo "  ${{G}}1${{N}}) Дія 1 (не реалізовано)"
  echo "  ${{G}}2${{N}}) Статус"
  echo "  ${{G}}0${{N}}) Назад"
  echo
  read -rp "  Вибір: " c
  case "$c" in
    1) echo "TODO: реалізувати"; read -rp "Enter…" _ ;;
    2) echo "Модуль встановлено, чекає реалізації"
       read -rp "Enter…" _ ;;
    0) return ;;
  esac
done
'''

    def _install_remote(self, entry, dry_run):
        """Клонує git-repo або качає tar, запускає install.sh."""
        src = entry["source"]
        mid = entry["id"]; slug = entry["slug"]
        target = M / f"module_{mid}_{slug}"
        if dry_run:
            return True, f"[dry] клонував би {src} → {target.name}"
        tmp = Path(tempfile.mkdtemp(prefix="cybra_inst_"))
        try:
            if src.startswith("git://") or src.endswith(".git"):
                rc = subprocess.run(["git","clone","--depth=1",src,str(tmp/"src")],
                                    capture_output=True, timeout=120)
                if rc.returncode != 0:
                    return False, f"git clone: {rc.stderr.decode()[:200]}"
                src_dir = tmp / "src"
            else:
                # tar/zip URL
                import urllib.request
                tf = tmp / "src.tar.gz"
                urllib.request.urlretrieve(src, tf)
                extract = tmp / "src"; extract.mkdir()
                subprocess.run(["tar","-xzf",str(tf),"-C",str(extract)], timeout=60)
                src_dir = extract

            # шукаємо install.sh або module_<mid>_*
            install_sh = src_dir / "install.sh"
            payload = src_dir
            for d in src_dir.rglob(f"module_{mid}_*"):
                if d.is_dir(): payload = d; break

            if install_sh.exists():
                rc = subprocess.run(["bash", str(install.sh)],
                                    cwd=str(src_dir), capture_output=True, timeout=300)
                if rc.returncode != 0:
                    return False, f"install.sh: {rc.stderr.decode()[:200]}"

            # копіюємо payload у target
            if payload != src_dir and payload.exists():
                if target.exists(): shutil.rmtree(target)
                shutil.copytree(payload, target)
            log(f"install remote: {mid} ← {src}")
            return True, f"встановлено {target.name}"
        except Exception as e:
            return False, f"install error: {e}"
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

# ═══════════════════════════════════════════════════════════════
# INTEGRATOR — авто-інтеграція у TUI
# ═══════════════════════════════════════════════════════════════
class Integrator:
    def __init__(self, catalog):
        self.catalog = catalog
        self.tui = M / "module_19_contract_tui_menu/bin/cybra_menu.sh"
        self.pub_tui = H / "public/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

    def _has_case(self, txt, mid):
        return bool(re.search(rf'^\s*{mid}\)', txt, re.M))

    def _has_menu(self, txt, mid):
        return f"[{mid}]" in txt

    def verify(self):
        """Повертає list: id | status (ok/missing_case/missing_menu/missing_module)."""
        out = []
        if not self.tui.exists(): return out
        txt = self.tui.read_text()
        installed = {re.match(r'module_(\d+)_', d.name).group(1)
                     for d in M.glob("module_*") if re.match(r'module_(\d+)_', d.name)}
        for mid in sorted(installed):
            e = self.catalog.get(mid)
            if not e: continue
            if not self._has_case(txt, mid):
                out.append({"id": mid, "status": "missing_case", "name": e["name"]})
            elif not self._has_menu(txt, mid):
                out.append({"id": mid, "status": "missing_menu", "name": e["name"]})
            else:
                out.append({"id": mid, "status": "ok", "name": e["name"]})
        return out

    def integrate(self, mid, dry_run=False):
        """Додає case-обробник + рядок меню для модуля."""
        e = self.catalog.get(mid)
        if not e: return False, f"модуль {mid} не в каталозі"
        if not self.tui.exists(): return False, "TUI не знайдено"

        target_dir = None
        for d in M.glob(f"module_{mid}_*"):
            target_dir = d; break
        if not target_dir:
            return False, f"модуль {mid} не встановлено"

        entry_script = f"bash \"$HOME/CYBRA/modules/{target_dir.name}/main.sh\""
        section = e.get("tui_section", "ADVANCED")
        menu_line = e.get("tui_menu", f"[{mid}] {e['name']}")

        if dry_run:
            return True, f"[dry] case + menu для {mid}"

        # backup
        ts = int(time.time())
        shutil.copy2(self.tui, f"{self.tui}.bak.orch.{ts}")
        if self.pub_tui.exists():
            shutil.copy2(self.pub_tui, f"{self.pub_tui}.bak.orch.{ts}")

        added_case = added_menu = False
        for tui_file in [self.tui, self.pub_tui]:
            if not tui_file.exists(): continue
            txt = tui_file.read_text()
            lines = txt.split("\n")

            # case-обробник
            if not self._has_case(txt, mid):
                for i, line in enumerate(lines):
                    if re.match(r'^\s*0\s*\|\s*q\s*\|\s*Q\s*\|\s*exit\s*\|\s*quit\s*\)', line):
                        ind = re.match(r'^(\s*)', line).group(1)
                        lines[i:i] = [f'{ind}{mid}) {entry_script} ;;']
                        added_case = True
                        break

            # меню
            txt2 = "\n".join(lines)
            if not self._has_menu(txt2, mid):
                # шукаємо секцію з такою назвою або вставляємо перед легендою
                section_marker = f"─── {section} ───"
                inserted = False
                for i, line in enumerate(lines):
                    if section_marker in line:
                        # вставляємо після цього рядка
                        lines.insert(i+1, f'    printf \'%s\\n\' "  ${{C_GREY}}🟢${{C_RESET}} ${{C_BOLD}}{menu_line}${{C_RESET}}"')
                        inserted = True
                        break
                if not inserted:
                    # немає секції — вставляємо нову перед легендою
                    for i, line in enumerate(lines):
                        if "🟢" in line and "ready" in line and "warning" in line:
                            lines[i:i] = [
                                f'    printf \'%s\\n\' "  ${{C_BOLD}}─── {section} ───${{C_RESET}}"',
                                f'    printf \'%s\\n\' "  ${{C_GREY}}🟢${{C_RESET}} ${{C_BOLD}}{menu_line}${{C_RESET}}"',
                                '    printf \'%s\\n\' ""',
                            ]
                            inserted = True
                            break
                if inserted: added_menu = True

            tui_file.write_text("\n".join(lines))

        # перевірка синтаксису
        rc = subprocess.run(["bash","-n",str(self.tui)], capture_output=True)
        if rc.returncode != 0:
            # відкат
            shutil.copy2(f"{self.tui}.bak.orch.{ts}", self.tui)
            if self.pub_tui.exists():
                shutil.copy2(f"{self.pub_tui}.bak.orch.{ts}", self.pub_tui)
            return False, f"syntax fail, відкочено: {rc.stderr.decode()[:100]}"

        log(f"integrate: {mid} case={added_case} menu={added_menu}")
        return True, f"case={added_case} menu={added_menu}"

# ═══════════════════════════════════════════════════════════════
# MONITOR — моніторинг роботи та виконання
# ═══════════════════════════════════════════════════════════════
class Monitor:
    def __init__(self):
        self.file = D / "data" / "monitor.jsonl"

    def snapshot(self):
        """Один знімок стану системи."""
        s = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
             "ts_unix": int(time.time())}
        # модулі
        installed = list(M.glob("module_*"))
        s["modules_count"] = len(installed)
        # підписи
        ev = M / "module_19_contract_tui_menu/evidence"
        s["signatures"] = len(list(ev.glob("*.sig"))) if ev.exists() else 0
        # парламент
        try:
            import parliament as P
            props = P.proposals()
            s["proposals"] = len(props)
            s["proposals_open"] = len([p for p in props if p.get("status")=="open"])
            chain = P.verify_chain()
            s["chain_broken"] = sum(r["broken"] for r in chain.values())
        except Exception: pass
        # виконання
        try:
            import verify_7
            ex_dir = D / "data/executions"
            if ex_dir.exists():
                execs = []
                for f in ex_dir.glob("C-*.json"):
                    st = verify_7.status(f.stem)
                    if st: execs.append(st)
                s["executions_total"] = len(execs)
                s["executions_done"] = len([e for e in execs if e["progress"] == 100])
                s["executions_avg_progress"] = round(
                    sum(e["progress"] for e in execs) / max(1, len(execs)), 1)
        except Exception: pass
        # процеси
        s["autonode_running"] = bool(subprocess.run(
            ["pgrep","-f","autonode/daemon.py"], capture_output=True).returncode == 0)
        s["watchdog_running"] = bool(subprocess.run(
            ["pgrep","-f","parlament/watchdog"], capture_output=True).returncode == 0)
        # диска
        try:
            total, used, free = shutil.disk_usage(str(H))
            s["disk_free_mb"] = free // (1024*1024)
        except Exception: pass
        return s

    def save(self, s):
        self.file.parent.mkdir(exist_ok=True)
        with open(self.file, "a") as f:
            f.write(json.dumps(s) + "\n")
        # ротація
        try:
            if self.file.stat().st_size > 500_000:
                lines = self.file.read_text().splitlines()
                self.file.write_text("\n".join(lines[-500:]) + "\n")
        except Exception: pass

    def trend(self, hours=24):
        if not self.file.exists(): return []
        cutoff = time.time() - hours*3600
        return [json.loads(l) for l in self.file.read_text().splitlines()
                if l.strip() and json.loads(l).get("ts_unix",0) > cutoff]

    def alerts(self):
        """Перевіряє чи щось погано."""
        last = None
        if self.file.exists():
            lines = self.file.read_text().splitlines()
            if lines:
                try: last = json.loads(lines[-1])
                except Exception: pass
        if not last: return []
        out = []
        if last.get("chain_broken", 0) > 0:
            out.append({"level":"critical", "msg":f"hash-chain порушено: {last['chain_broken']}"})
        if not last.get("autonode_running"):
            out.append({"level":"warn", "msg":"AutoNode daemon не працює"})
        if not last.get("watchdog_running"):
            out.append({"level":"warn", "msg":"Parliament watchdog не працює"})
        if last.get("disk_free_mb", 9999) < 200:
            out.append({"level":"warn", "msg":f"мало місця: {last['disk_free_mb']} MB"})
        return out

# ═══════════════════════════════════════════════════════════════
# SCHEDULER — черга завдань
# ═══════════════════════════════════════════════════════════════
class Scheduler:
    def __init__(self):
        self.file = D / "data" / "scheduler.json"
        if not self.file.exists():
            self._default()

    def _default(self):
        tasks = [
            {"name":"fix_auto",        "every_sec": 900,  "last": 0, "action":"fix_auto"},
            {"name":"monitor",         "every_sec": 300,  "last": 0, "action":"monitor"},
            {"name":"install_missing", "every_sec": 3600, "last": 0, "action":"install_missing"},
            {"name":"verify_integration","every_sec": 1800, "last": 0, "action":"verify_integration"},
            {"name":"run_tests",       "every_sec": 3600, "last": 0, "action":"run_tests"},
            {"name":"advance_exec",    "every_sec": 600,  "last": 0, "action":"advance_exec"},
            {"name":"deploy_contracts","every_sec": 1800, "last": 0, "action":"deploy_contracts"},
        ]
        self.file.write_text(json.dumps({"tasks": tasks}, indent=2))

    def _load(self):
        try: return json.loads(self.file.read_text())
        except Exception: return {"tasks": []}
    def _save(self, d):
        tmp = str(self.file)+".tmp"
        Path(tmp).write_text(json.dumps(d, indent=2))
        os.replace(tmp, self.file)

    def add(self, name, every_sec, action):
        d = self._load()
        d["tasks"] = [t for t in d["tasks"] if t["name"] != name]
        d["tasks"].append({"name": name, "every_sec": every_sec,
                           "last": 0, "action": action})
        self._save(d); return True, "додано"

    def remove(self, name):
        d = self._load()
        d["tasks"] = [t for t in d["tasks"] if t["name"] != name]
        self._save(d); return True, "видалено"

    def due(self):
        d = self._load()
        now = int(time.time())
        out = []
        for t in d["tasks"]:
            if now - t.get("last",0) >= t.get("every_sec", 3600):
                out.append(t)
        return out

    def mark(self, name):
        d = self._load()
        for t in d["tasks"]:
            if t["name"] == name:
                t["last"] = int(time.time())
        self._save(d)

    def list_tasks(self):
        d = self._load()
        now = int(time.time())
        for t in d["tasks"]:
            remaining = max(0, t.get("every_sec",0) - (now - t.get("last",0)))
            print(f"  {t['name']:20s} кожні {t['every_sec']:>6}s  "
                  f"через {remaining:>5}s  → {t['action']}")

# ═══════════════════════════════════════════════════════════════
# ORCHESTRATOR — головний цикл
# ═══════════════════════════════════════════════════════════════
class Orchestrator:
    def __init__(self, verbose=True):
        self.verbose = verbose
        self.cat = Catalog()
        self.inst = Installer(self.cat)
        self.integ = Integrator(self.cat)
        self.mon = Monitor()
        self.sched = Scheduler()
        self.results = {}

    def _p(self, *args):
        if self.verbose: print(*args)

    def fix_auto(self):
        """Auto-фікси через 120."""
        try:
            sys.path.insert(0, str(D))
            import executor
            items = __import__("todo").plan()
            done, failed = executor.auto_execute(items, verbose=False)
            self.results["auto_fixed"] = len(done)
            return {"ok": True, "fixed": len(done), "failed": len(failed)}
        except Exception as e:
            return {"ok": False, "err": str(e)[:120]}

    def install_missing(self, dry_run=False):
        """Встановлює модулі з каталогу яких немає."""
        missing = self.inst.missing()
        # тільки ті що мають source != skip
        missing = [m for m in missing if m.get("install") != "skip"]
        if not missing:
            self.results["install"] = 0
            return {"ok": True, "installed": 0, "total_missing": 0}

        self._p(f"\n{C_B}▸ Авто-інсталяція ({len(missing)} нових){C_N}")
        installed = 0
        for e in missing[:5]:  # максимум 5 за цикл
            self._p(f"  → {e['id']} {e['name']}")
            ok, msg = self.inst.install(e, dry_run=dry_run)
            mark = f"{C_G}✓{C_N}" if ok else f"{C_R}✗{C_N}"
            self._p(f"    {mark} {msg}")
            if ok and not dry_run:
                installed += 1
                # одразу інтегруємо
                iok, imsg = self.integ.integrate(e["id"], dry_run=dry_run)
                self._p(f"    {f'{C_G}✓{C_N}' if iok else f'{C_R}✗{C_N}'} integrate: {imsg}")
        self.results["install"] = installed
        return {"ok": True, "installed": installed, "total_missing": len(missing)}

    def verify_integration(self):
        """Перевіряє чи всі модулі в TUI."""
        report = self.integ.verify()
        bad = [r for r in report if r["status"] != "ok"]
        fixed = 0
        for r in bad:
            ok, msg = self.integ.integrate(r["id"])
            if ok: fixed += 1
        self.results["integration_fixed"] = fixed
        self.results["integration_bad"] = len(bad)
        return {"ok": True, "checked": len(report), "bad": len(bad), "fixed": fixed}

    def run_tests(self):
        """Запускає 130 Test Suite."""
        ts = M / "module_130_test_suite/run_tests.sh"
        if not ts.exists(): return {"ok": False, "err": "test suite відсутній"}
        try:
            r = subprocess.run(["bash", str(ts)], capture_output=True,
                               text=True, timeout=300)
            # парсимо результат
            out = r.stdout + r.stderr
            m = re.search(r'PASS:\s*(\d+)\s*FAIL:\s*(\d+)\s*SKIP:\s*(\d+)', out)
            if m:
                self.results["tests"] = {"pass": int(m.group(1)),
                                        "fail": int(m.group(2)),
                                        "skip": int(m.group(3))}
                return {"ok": True, "pass": int(m.group(1)),
                        "fail": int(m.group(2)), "skip": int(m.group(3))}
            return {"ok": False, "err": "не розпізнано формат"}
        except Exception as e:
            return {"ok": False, "err": str(e)[:120]}

    def advance_exec(self):
        """Прогоняє auto-advance по всіх контрактах."""
        try:
            sys.path.insert(0, str(D))
            import progress
            moved = progress.tick_all()
            self.results["exec_moved"] = len(moved)
            return {"ok": True, "advanced": len(moved)}
        except Exception as e:
            return {"ok": False, "err": str(e)[:120]}

    def deploy_contracts(self):
        """Парламент сам компілює і деплоїть контракти (testnet auto)."""
        try:
            import deployer
            r = deployer.auto_cycle(verbose=False)
            self.results["deploy"] = {
                "compiled": len(r["compiled"]),
                "deployed": len(r["deployed"]),
                "errors": len(r["errors"]),
            }
            return {"ok": True, **self.results["deploy"]}
        except Exception as e:
            return {"ok": False, "err": str(e)[:120]}

    def monitor(self):
        s = self.mon.snapshot()
        self.mon.save(s)
        alerts = self.mon.alerts()
        self.results["alerts"] = len(alerts)
        for a in alerts:
            lvl = "critical" if a["level"]=="critical" else "warn"
            log(f"alert: {a['msg']}", level=lvl)
        return {"ok": True, "alerts": len(alerts), "snapshot": s}

    def tick_scheduler(self):
        """Прогоняє прострочені задачі."""
        due = self.sched.due()
        executed = []
        for t in due:
            action = t["action"]
            fn = getattr(self, action, None)
            if fn and callable(fn):
                try:
                    r = fn()
                    executed.append({"task": t["name"], "ok": r.get("ok", False)})
                except Exception as e:
                    executed.append({"task": t["name"], "ok": False, "err": str(e)[:80]})
            self.sched.mark(t["name"])
        self.results["scheduled_run"] = len(executed)
        return {"ok": True, "executed": executed}

    def full_cycle(self, include=None):
        """Повний цикл. include — список кроків, або None (всі)."""
        t0 = time.time()
        self._p(f"\n{C_B}{C_BOLD}═══ ORCHESTRATOR CYCLE ═══{C_N}")
        steps = include or ["fix_auto", "monitor", "verify_integration",
                            "install_missing", "deploy_contracts",
                            "run_tests", "advance_exec"]
        for step in steps:
            fn = getattr(self, step, None)
            if not fn: continue
            self._p(f"\n{C_B}▸ {step}{C_N}")
            try:
                r = fn()
                if isinstance(r, dict):
                    self._p(f"  {C_D}{json.dumps(r, ensure_ascii=False)[:200]}{C_N}")
            except Exception as e:
                self._p(f"  {C_R}exception: {e}{C_N}")
        dur = int((time.time()-t0)*1000)
        self.results["duration_ms"] = dur
        self._p(f"\n{C_G}═══ CYCLE DONE ({dur}ms) ═══{C_N}")

        # зберегти звіт
        report_dir = D / "data" / "orch_reports"
        report_dir.mkdir(exist_ok=True)
        ts = time.strftime("%Y%m%d_%H%M%S")
        (report_dir / f"{ts}.json").write_text(
            json.dumps(self.results, indent=2, ensure_ascii=False))
        # ротація
        reps = sorted(report_dir.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
        for old in reps[50:]: old.unlink()

        log(f"cycle: {json.dumps(self.results, ensure_ascii=False)[:200]}")
        return self.results

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
def cmd_run(a):
    o = Orchestrator(verbose=True)
    r = o.full_cycle()
    return 0 if not any(k.endswith("_fail") or v is False for k,v in r.items()) else 1

def cmd_daemon(a):
    interval = getattr(a, "interval", 600)
    o = Orchestrator(verbose=False)
    log(f"daemon start interval={interval}")
    while True:
        try:
            o.full_cycle(include=["tick_scheduler"])
        except Exception as e:
            log(f"daemon err: {e}", level="warn")
        time.sleep(interval)

def cmd_install(a):
    o = Orchestrator(verbose=True)
    if a.mid:
        r = o.inst.install(o.cat.get(a.mid), dry_run=a.dry)
        print(r)
    else:
        r = o.install_missing(dry_run=a.dry)
        print(json.dumps(r, indent=2, ensure_ascii=False))

def cmd_verify(a):
    o = Orchestrator(verbose=True)
    r = o.verify_integration()
    print(json.dumps(r, indent=2, ensure_ascii=False))

def cmd_monitor(a):
    o = Orchestrator(verbose=True)
    r = o.monitor()
    print(json.dumps(r, indent=2, ensure_ascii=False))

def cmd_trend(a):
    o = Orchestrator(verbose=False)
    t = o.mon.trend(a.hours)
    if not t:
        print("  (порожньо)"); return
    print(f"\n{C_B}Тренд ({len(t)} знімків за {a.hours}г){C_N}\n")
    for k in ["modules_count","signatures","proposals","executions_total",
              "disk_free_mb"]:
        vals = [s.get(k,0) for s in t if k in s]
        if vals:
            print(f"  {k:22s} min={min(vals):>8} max={max(vals):>8} now={vals[-1]:>8}")

def cmd_alerts(a):
    o = Orchestrator(verbose=False)
    al = o.mon.alerts()
    if not al:
        print(f"  {C_G}✓ немає алертів{C_N}"); return
    for x in al:
        col = C_R if x["level"]=="critical" else C_Y
        print(f"  {col}[{x['level']}]{C_N} {x['msg']}")

def cmd_catalog(a):
    c = Catalog()
    for e in c.load():
        src = e.get("source","?")[:40]
        print(f"  {e['id']:>4} {e['name'][:30]:32s} {e.get('category','?'):12s} {src}")

def cmd_missing(a):
    o = Orchestrator(verbose=False)
    m = o.inst.missing()
    if not m: print(f"  {C_G}✓ усі модулі встановлено{C_N}"); return
    for e in m:
        print(f"  {e['id']:>4} {e['name'][:40]:42s} source={e.get('source','?')[:40]}")

def cmd_tasks(a):
    o = Orchestrator(verbose=False)
    o.sched.list_tasks()

def cmd_add_task(a):
    o = Orchestrator(verbose=False)
    ok, m = o.sched.add(a.name, a.every, a.action)
    print(("✓ " if ok else "✗ ")+m)

def main():
    import argparse
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd")

    s = sub.add_parser("run"); s.set_defaults(fn=cmd_run)

    s = sub.add_parser("daemon")
    s.add_argument("--interval", type=int, default=600)
    s.set_defaults(fn=cmd_daemon)

    s = sub.add_parser("install")
    s.add_argument("mid", nargs="?")
    s.add_argument("--dry", action="store_true")
    s.set_defaults(fn=cmd_install)

    s = sub.add_parser("verify"); s.set_defaults(fn=cmd_verify)
    s = sub.add_parser("monitor"); s.set_defaults(fn=cmd_monitor)

    s = sub.add_parser("trend")
    s.add_argument("--hours", type=int, default=24)
    s.set_defaults(fn=cmd_trend)

    s = sub.add_parser("alerts"); s.set_defaults(fn=cmd_alerts)
    s = sub.add_parser("catalog"); s.set_defaults(fn=cmd_catalog)
    s = sub.add_parser("missing"); s.set_defaults(fn=cmd_missing)
    s = sub.add_parser("tasks"); s.set_defaults(fn=cmd_tasks)

    s = sub.add_parser("add-task")
    s.add_argument("name"); s.add_argument("every", type=int); s.add_argument("action")
    s.set_defaults(fn=cmd_add_task)

    a = ap.parse_args()
    if not a.cmd: cmd_run(a); return
    a.fn(a)

if __name__ == "__main__":
    main()
