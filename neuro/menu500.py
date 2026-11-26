#!/usr/bin/env python3
"""CYBRA NEURO BAR MENU 500 — isolated catalog, task auto-discovery and evolution audit.
All generated tasks are proposals. This tool never applies patches, runs PM2, or edits CYBRA.
"""
from __future__ import annotations
import argparse, hashlib, json, os, re, sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve()
ROOT = HERE.parents[1]
NEURO = ROOT / "neuro"
STATE = NEURO / "state"
CATALOG_FILE = NEURO / "menu500_catalog.json"
GENERATED = STATE / "generated_tasks"
REPORT = STATE / "evolution_report.json"

DOMAINS = [
 ("01","Стан і діагностика","health status metrics diagnostics"),
 ("02","Модулі та реєстр","module registry entrypoint inventory"),
 ("03","Автостворення задач","task discovery task queue proposals"),
 ("04","Еволюція та baseline","evolution approved baseline hashes"),
 ("05","Тести та якість","syntax tests validation reports"),
 ("06","Git та версії","git branches commits diffs"),
 ("07","Резервування","backup snapshots manifests"),
 ("08","Журнали та аудит","logs audit history"),
 ("09","Мережа та RPC","network rpc connectivity configuration"),
 ("10","Документація","readme docs metadata")
]
VERBS = [
 ("scan","Просканувати"),
 ("verify","Перевірити"),
 ("report","Сформувати звіт"),
 ("index","Оновити індекс"),
 ("compare","Порівняти стан"),
]
OBJECTS = [
 "структуру","реєстр","конфігурацію","метадані","залежності",
 "наявність файлів","контрольні суми","історію","чергу задач","документацію"
]

def now():
    return datetime.now(timezone.utc).isoformat()

def ensure():
    STATE.mkdir(parents=True, exist_ok=True)
    GENERATED.mkdir(parents=True, exist_ok=True)

def catalog():
    rows=[]
    for code, name, tags in DOMAINS:
        for i in range(1,51):
            verb, v = VERBS[(i-1)%len(VERBS)]
            obj = OBJECTS[(i-1)%len(OBJECTS)]
            num = int(code)*100+i
            rows.append({
                "id": f"N{num:04d}", "number": len(rows)+1,
                "category": name, "title": f"{v} {obj} — {i:02d}",
                "description": f"Безпечна read-only перевірка: {tags}. Результат записується у звіт.",
                "mode": "READ_ONLY", "status": "CATALOG",
                "action": verb
            })
    return rows

def save_catalog():
    ensure()
    rows=catalog()
    CATALOG_FILE.write_text(json.dumps({"generated_at":now(),"total":len(rows),"items":rows},ensure_ascii=False,indent=2)+"\n")
    return rows

def load_catalog():
    if CATALOG_FILE.exists():
        try:
            d=json.loads(CATALOG_FILE.read_text())
            if len(d.get("items",[]))==500: return d["items"]
        except Exception: pass
    return save_catalog()

def scan_sources():
    modules=ROOT/"modules"
    tasks=ROOT/"parliament_core"/"tasks"
    evo=ROOT/"evolution"
    found=[]
    if modules.exists():
        for p in sorted(modules.glob("module_*")):
            if p.is_dir():
                mains=[x for x in (p/"main.sh",p/"bin"/"main.sh") if x.is_file()]
                found.append({"kind":"module","id":p.name,"path":str(p.relative_to(ROOT)),"entrypoint":bool(mains)})
    if tasks.exists():
        for p in sorted(tasks.glob("*.json")):
            try:
                data=json.loads(p.read_text())
                found.append({"kind":"existing_task","id":str(data.get("id",p.stem)),"path":str(p.relative_to(ROOT)),"status":str(data.get("status","unknown"))})
            except Exception:
                found.append({"kind":"invalid_task","id":p.name,"path":str(p.relative_to(ROOT))})
    if evo.exists():
        for p in sorted(evo.glob("*.approved")):
            found.append({"kind":"evolution_approval","id":p.stem,"path":str(p.relative_to(ROOT)),"hash":p.read_text().strip()[:128]})
    return found

def auto_create():
    """Create reviewable proposals from repository facts; never execute them."""
    ensure()
    src=scan_sources()
    proposals=[]
    for item in src:
        if item["kind"]=="module" and not item["entrypoint"]:
            proposals.append(("MODULE_ENTRYPOINT_REVIEW",item,"Module has no detected main.sh entrypoint"))
        elif item["kind"]=="invalid_task":
            proposals.append(("TASK_JSON_REVIEW",item,"Task JSON is invalid and needs manual review"))
        elif item["kind"]=="existing_task" and item.get("status","").lower() in ("failed","error","blocked"):
            proposals.append(("TASK_STATUS_REVIEW",item,"Existing task is failed, error or blocked"))
    for kind, item, reason in proposals:
        raw=f'{kind}|{item.get("id")}|{item.get("path")}'
        tid="NEURO-"+hashlib.sha256(raw.encode()).hexdigest()[:12].upper()
        target=GENERATED/(tid+".json")
        if target.exists(): continue
        data={"id":tid,"created_at":now(),"source":"neuro-500-menu","type":kind,
              "status":"PROPOSED","reason":reason,"evidence":item,
              "safety":{"execution":"DISABLED","apply":"DISABLED","requires_review":True}}
        target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    return {"scanned":len(src),"proposals_found":len(proposals),
            "new_tasks":len(list(GENERATED.glob("NEURO-*.json"))),"created_now":len(proposals)}

def evolution_audit():
    """Evidence-based score; 100% is earned only when every check passes."""
    ensure()
    items=load_catalog()
    src=scan_sources()
    checks=[]
    def add(name, ok, detail): checks.append({"check":name,"ok":bool(ok),"detail":str(detail)})
    add("catalog_exactly_500",len(items)==500,f"items={len(items)}")
    ids=[x.get("id") for x in items]
    add("catalog_ids_unique",len(ids)==len(set(ids)),f"unique={len(set(ids))}")
    add("catalog_numbers_unique",len({x.get("number") for x in items})==500,"number range 1..500")
    add("catalog_read_only",all(x.get("mode")=="READ_ONLY" for x in items),"all menu entries are read-only descriptors")
    add("module_inventory_available",(ROOT/"modules").is_dir(),str(ROOT/"modules"))
    add("task_queue_available",(ROOT/"parliament_core"/"tasks").is_dir(),str(ROOT/"parliament_core"/"tasks"))
    add("evolution_dir_available",(ROOT/"evolution").is_dir(),str(ROOT/"evolution"))
    approvals=[x for x in src if x["kind"]=="evolution_approval"]
    add("evolution_approvals_present",len(approvals)>0,f"approvals={len(approvals)}")
    generated=list(GENERATED.glob("NEURO-*.json"))
    valid=True
    for p in generated:
        try:
            d=json.loads(p.read_text())
            if d.get("status")!="PROPOSED" or d.get("safety",{}).get("apply")!="DISABLED": valid=False
        except Exception: valid=False
    add("generated_tasks_safe",valid,f"proposals={len(generated)}; apply disabled")
    add("unit_tests_passed",os.environ.get("NEURO_UNIT_TESTS_PASSED")=="1",
        "set by evo_loop only after unittest exits successfully")
    add("python_compile_passed",os.environ.get("NEURO_PYTHON_COMPILE_PASSED")=="1",
        "set by evo_loop only after py_compile exits successfully")
    add("bash_syntax_passed",os.environ.get("NEURO_BASH_SYNTAX_PASSED")=="1",
        "set by evo_loop only after both bash -n checks pass")
    passed=sum(1 for x in checks if x["ok"])
    score=round(100*passed/len(checks),1) if checks else 0
    report={"at":now(),"root":str(ROOT),"score_percent":score,"passed":passed,"total":len(checks),
            "status":"100% VERIFIED" if score==100 else "IN PROGRESS","checks":checks,
            "inventory":{"modules":sum(x["kind"]=="module" for x in src),
                         "existing_tasks":sum(x["kind"]=="existing_task" for x in src),
                         "approvals":len(approvals),"generated_proposals":len(generated)},
            "note":"Score measures these explicit repository checks only; it is not a claim that the whole CYBRA node is 100% healthy."}
    REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    return report

def show_page(rows,page=1,size=20):
    start=max(0,(page-1)*size)
    print(f"\nCYBRA NEURO BAR MENU 500 | сторінка {page}/{(len(rows)+size-1)//size}")
    print("-"*72)
    for x in rows[start:start+size]:
        print(f'{x["number"]:03d}. [{x["id"]}] {x["category"]}: {x["title"]}')
    print("-"*72)

def interactive():
    rows=load_catalog()
    page=1
    while True:
        show_page(rows,page)
        print("n — далі | p — назад | s — пошук | a — автостворення задач")
        print("e — аудит EVO | r — звіт | q — вихід")
        cmd=input("NEURO> ").strip()
        if cmd=="n": page=min((len(rows)-1)//20+1,page+1)
        elif cmd=="p": page=max(1,page-1)
        elif cmd=="a": print(json.dumps(auto_create(),ensure_ascii=False,indent=2)); input("Enter…")
        elif cmd=="e": print(json.dumps(evolution_audit(),ensure_ascii=False,indent=2)); input("Enter…")
        elif cmd=="r":
            print(REPORT.read_text() if REPORT.exists() else "Звіту ще немає"); input("Enter…")
        elif cmd=="s":
            q=input("Пошук: ").strip().lower()
            hits=[x for x in rows if q in (x["category"]+" "+x["title"]+" "+x["description"]).lower()]
            show_page(hits or [],1,50); input("Enter…")
        elif cmd in ("q","0","exit"): break

def main():
    ap=argparse.ArgumentParser(description="CYBRA NEURO menu500 — safe isolated task catalog")
    ap.add_argument("command",nargs="?",choices=["menu","catalog","auto-create","evo","status"],default="menu")
    args=ap.parse_args()
    if args.command=="catalog":
        rows=save_catalog(); print(f"CATALOG_OK={len(rows)}")
    elif args.command=="auto-create":
        print(json.dumps(auto_create(),ensure_ascii=False,indent=2))
    elif args.command=="evo":
        print(json.dumps(evolution_audit(),ensure_ascii=False,indent=2))
    elif args.command=="status":
        print(json.dumps(evolution_audit(),ensure_ascii=False,indent=2))
    else: interactive()

if __name__=="__main__": main()
