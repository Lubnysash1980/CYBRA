#!/usr/bin/env python3
import os, sys, json, time
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
FIDIC_DIR = CYBRA / "data" / "fidic"
FIDIC_DIR.mkdir(parents=True, exist_ok=True)

# 1. Структура FIDIC Контракту (Спрощена, але робоча)
def create_fidic_draft(cid):
    """Створює чернетку FIDIC контракту з базовими блоками"""
    contract = {
        "fidic_cid": cid,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "state": "DRAFT", # Етапи: DRAFT -> BOQ_READY -> VALIDATED -> SIGNED -> ACTIVE
        "general_conditions": {
            "type": "Red Book", # Або Yellow/Silver
            "engineer": "TBD",
            "employer": "TBD",
            "contractor": "TBD"
        },
        "particular_conditions": {},
        "boq": [], # Bill of Quantities
        "payment_terms": {
            "currency": "UAH",
            "advance_percent": 10,
            "retention_percent": 5
        }
    }
    file_path = FIDIC_DIR / f"{cid}.json"
    file_path.write_text(json.dumps(contract, indent=2, ensure_ascii=False))
    print(f"✅ Створено чернетку FIDIC контракту: {cid}")
    print(f"📍 Шлях: {file_path}")
    return contract

# 2. Валідатор (Перевірка на "дурні" помилки)
def validate_contract(cid):
    file_path = FIDIC_DIR / f"{cid}.json"
    if not file_path.exists():
        print("❌ Контракт не знайдено"); return
    
    contract = json.loads(file_path.read_text())
    errors = []
    
    # Перевірка заповнення сторін
    if contract["general_conditions"]["employer"] == "TBD":
        errors.append("Не вказано Замовника (Employer)")
    if contract["general_conditions"]["contractor"] == "TBD":
        errors.append("Не вказано Підрядника (Contractor)")
        
    # Перевірка BOQ
    if len(contract["boq"]) == 0:
        errors.append("Кошторис (BOQ) порожній")
    else:
        for i, item in enumerate(contract["boq"]):
            if item.get("qty", 0) <= 0:
                errors.append(f"Позиція {i+1}: Кількість має бути > 0")
            if item.get("rate", 0) <= 0:
                errors.append(f"Позиція {i+1}: Ставка має бути > 0")

    if errors:
        print("🚨 ЗНАЙДЕНО ПОМИЛКИ (Система не пропускає далі):")
        for e in errors: print(f"  - {e}")
        contract["state"] = "BOQ_READY" # Все ще не валідний
    else:
        print("✅ Всі перевірки пройдено! Контракт валідний.")
        contract["state"] = "VALIDATED"
        
    file_path.write_text(json.dumps(contract, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Використання: fidic-engine.py [create|validate] [CID]")
        sys.exit(1)
        
    action = sys.argv[1]
    cid = sys.argv[2]
    
    if action == "create":
        create_fidic_draft(cid)
    elif action == "validate":
        validate_contract(cid)
