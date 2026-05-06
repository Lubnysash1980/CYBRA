import sys
import os

def add_project_roots():
    """
    Автоматично додає всі root директорії Cybra в sys.path
    """

    base_dir = os.path.abspath(os.path.dirname(__file__))

    # можливі корені (Termux / VPS / Git clone)
    candidates = [
        base_dir,
        os.path.join(base_dir, "cybra"),
        os.path.join(base_dir, "cybra_core"),
        os.path.join(base_dir, "cybra_cluster_v4"),
        os.path.join(base_dir, "cybra_project"),
    ]

    # також піднімаємося вгору (git root detection)
    current = base_dir
    for _ in range(5):
        candidates.append(current)
        current = os.path.dirname(current)

    for path in candidates:
        if path and path not in sys.path and os.path.exists(path):
            sys.path.insert(0, path)

    print("[BOOTSTRAP] sys.path patched")
