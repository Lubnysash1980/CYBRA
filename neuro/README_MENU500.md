# CYBRA NEURO BAR MENU 500

Ізольований інструмент для гілки `neuro-500-menu`.

## Запуск у клоні CYBRA_NEURO
```bash
bash neuro/menu500.sh
```

## Команди
- `python3 neuro/menu500.py catalog` — створити каталог рівно з 500 пунктів.
- `python3 neuro/menu500.py auto-create` — просканувати модулі, парламентські задачі та EVO approvals; створити JSON-пропозиції у `neuro/state/generated_tasks/`.
- `python3 neuro/menu500.py evo` — перевірити критерії та записати `neuro/state/evolution_report.json`.
- `python3 neuro/menu500.py menu` — інтерактивне меню з пошуком і сторінками.

## Межі безпеки
- Не запускає Task Engine 405.
- Не редагує `$HOME/CYBRA`, не запускає PM2 і не виконує APPLY.
- Автостворені задачі мають статус `PROPOSED`; виконання та APPLY вимкнені.
- EVO-відсоток рахується лише за перевірками, переліченими у звіті. 100% цього аудиту не означає 100% здоров'я всієї ноди.
