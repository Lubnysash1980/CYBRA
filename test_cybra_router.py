from cybra_core.router import route_task

tests = [
    {"topic": "робота з законами", "type": "law_task"},
    {"topic": "пошук нерухомості", "type": "real_estate_task"},
    {"topic": "оплата за авто", "type": "payments_task"},
    {"topic": "native token", "type": "token_task"},
    {"topic": "GitHub Pages не відкривається", "type": "github_pages_task"}
]

for t in tests:
    print(route_task(t))
