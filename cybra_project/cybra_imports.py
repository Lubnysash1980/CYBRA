import sys
import os

def bootstrap():
    """
    Cybra system-wide import resolver
    - додає всі потрібні root шляхи
    - фіксить ModuleNotFoundError
    """

    base = os.path.abspath(os.path.dirname(__file__))

    roots = [
        base,

        # локальні проєкти
        os.path.join(base, "cybra"),
        os.path.join(base, "cybra_v4"),
        os.path.join(base, "cybra_project"),

        # cluster версії
        os.path.join(base, "cybra_cluster_v2"),
        os.path.join(base, "cybra_cluster_v3"),
        os.path.join(base, "cybra_cluster_v4"),

        # fallback (якщо запускаєш з іншої папки)
        os.path.abspath(os.path.join(base, "..")),
        os.path.abspath(os.path.join(base, "../..")),
    ]

    # додаємо тільки існуючі директорії
    for r in roots:
        if os.path.exists(r) and r not in sys.path:
            sys.path.insert(0, r)

    # дебаг (можеш прибрати потім)
    print("[CybraBootstrap] paths loaded:", len(sys.path))


# AUTO-RUN при імпорті
bootstrap()
