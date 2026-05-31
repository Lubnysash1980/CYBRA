#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p hash_storage posts proofs tools ai_network/index

cat > gitcybrahash_double_backend.mjs <<'MJS'
import crypto from "crypto";
import fs from "fs/promises";
import path from "path";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);
const HASH_FOLDER = "hash_storage";
const OWNER_ID = "OWNER_ONLY";
const MAX_HASH_MEMORY = 202;
const SAFE_PATHS = [
  "token",
  "posts",
  "proofs",
  "feeds",
  "bridge",
  "remote_queue",
  "sha",
  "patches",
  "cybra_codespace_termux_bridge_patch.sh",
  "cybra_mainnet_mint_gatekeeper.sh"
];

const BLOCKED = [
  "ai_network/repos",
  "node_modules",
  "logs",
  "recovery",
  ".git"
];

async function exists(p) {
  try { await fs.access(p); return true; } catch { return false; }
}

function doubleSha(data) {
  const b = Buffer.isBuffer(data) ? data : Buffer.from(String(data));
  const first = crypto.createHash("sha256").update(b).digest();
  return crypto.createHash("sha256").update(first).digest("hex");
}

async function run(cmd) {
  try {
    const { stdout, stderr } = await execAsync(cmd, { maxBuffer: 1024 * 1024 * 10 });
    return { ok: true, stdout, stderr };
  } catch (e) {
    return { ok: false, stdout: e.stdout || "", stderr: e.stderr || e.message };
  }
}

class GitCybraHashBackend {
  constructor(ownerId = OWNER_ID) {
    this.ownerId = ownerId;
    this.menu = new Map();
  }

  authorize(ownerId) {
    return ownerId === this.ownerId;
  }

  addEntry(file, hash, meta = {}) {
    if (this.menu.size >= MAX_HASH_MEMORY) {
      const oldest = this.menu.keys().next().value;
      this.menu.delete(oldest);
    }
    this.menu.set(hash, {
      file,
      meta,
      time: Date.now()
    });
  }

  async hashFile(file) {
    const data = await fs.readFile(file);
    const h = doubleSha(data);
    this.addEntry(file, h, { size: data.length });
    return { file, double_sha256: h, size: data.length };
  }

  async scanSafePaths() {
    const files = [];
    for (const p of SAFE_PATHS) {
      if (!(await exists(p))) continue;
      const r = await run(`find ${JSON.stringify(p)} -type f 2>/dev/null | head -500`);
      if (!r.ok) continue;
      for (const line of r.stdout.split("\n").filter(Boolean)) {
        if (BLOCKED.some(b => line === b || line.startsWith(b + "/"))) continue;
        files.push(line);
      }
    }
    return files;
  }

  async buildIndex() {
    await fs.mkdir(HASH_FOLDER, { recursive: true });
    const files = await this.scanSafePaths();
    const out = [];
    for (const f of files) {
      try { out.push(await this.hashFile(f)); } catch {}
    }

    const rootRaw = JSON.stringify(out, null, 2);
    const rootHash = doubleSha(rootRaw);

    const index = {
      system: "CYBRA Git Double Backend",
      mode: "kilobyte_index_not_repo_clone",
      files_indexed: out.length,
      root_double_sha256: rootHash,
      blocked: BLOCKED,
      safe_paths: SAFE_PATHS,
      files: out
    };

    await fs.writeFile(path.join(HASH_FOLDER, "gitcybra_index.json"), JSON.stringify(index, null, 2));
    await fs.writeFile(path.join(HASH_FOLDER, "gitcybra_root.sha256"), `${rootHash}  hash_storage/gitcybra_index.json\n`);

    return index;
  }

  async safeGitSync(message = "update CYBRA git double backend index") {
    await run("git add hash_storage/gitcybra_index.json hash_storage/gitcybra_root.sha256 gitcybrahash_double_backend.mjs posts/gitcybrahash_status.md proofs/gitcybrahash_double_backend.sha256");
    await run(`git commit -m ${JSON.stringify(message)} || true`);
    return await run("git push || true");
  }
}

async function main() {
  const backend = new GitCybraHashBackend();
  const index = await backend.buildIndex();

  await fs.mkdir("posts", { recursive: true });
  await fs.mkdir("proofs", { recursive: true });

  await fs.writeFile("posts/gitcybrahash_status.md", `# CYBRA Git Double Backend

Status: active

Mode:
kilobyte index, no heavy repo clone

Files indexed:
${index.files_indexed}

Root Double SHA:
${index.root_double_sha256}

Blocked:
- ai_network/repos
- node_modules
- logs
- recovery
- .git
`);

  const proof = await run("sha256sum gitcybrahash_double_backend.mjs hash_storage/gitcybra_index.json hash_storage/gitcybra_root.sha256 posts/gitcybrahash_status.md");
  await fs.writeFile("proofs/gitcybrahash_double_backend.sha256", proof.stdout);

  console.log(JSON.stringify({
    ok: true,
    files_indexed: index.files_indexed,
    root_double_sha256: index.root_double_sha256
  }, null, 2));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(e => {
    console.error(e);
    process.exit(1);
  });
}
MJS

node gitcybrahash_double_backend.mjs

cat > posts/gitcybrahash_install_status.md <<'MD'
# GitCybraHash Double Backend

Status: installed

Purpose:
Заміна важких repo clones на маленький Double SHA index.

Heavy repos should not be stored inside ai_network/repos.
MD

sha256sum gitcybrahash_double_backend.mjs posts/gitcybrahash_install_status.md proofs/gitcybrahash_double_backend.sha256 > proofs/gitcybrahash_install.sha256

echo "✅ GitCybraHash backend installed"
