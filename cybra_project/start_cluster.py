import os
import sys
import asyncio
import subprocess

BASE = os.path.dirname(os.path.abspath(__file__))
NODE_PATH = os.path.join(BASE, "node.py")  # або повний шлях

def spawn_node(node_id, port, peers):
    env = os.environ.copy()
    env["NODE_ID"] = node_id
    env["PORT"] = str(port)
    env["PEERS"] = peers

    return subprocess.Popen(
        [sys.executable, NODE_PATH],
        env=env
    )

async def main():
    print("[CLUSTER] starting")

    peers = "127.0.0.1:8001,127.0.0.1:8002,127.0.0.1:8003"

    subprocess.Popen([sys.executable, NODE_PATH],
        env={**os.environ, "NODE_ID":"node-a","PORT":"8001","PEERS":peers})

    subprocess.Popen([sys.executable, NODE_PATH],
        env={**os.environ, "NODE_ID":"node-b","PORT":"8002","PEERS":peers})

    subprocess.Popen([sys.executable, NODE_PATH],
        env={**os.environ, "NODE_ID":"node-c","PORT":"8003","PEERS":peers})

if __name__ == "__main__":
    asyncio.run(main())
