#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p hash_storage device/os ai_engine media_engine posts proofs feeds parliament/tasks bridge/secure

cat > gitcybrahash_double_backend.mjs <<'MJS'
import crypto from "crypto";
import fs from "fs/promises";
import fss from "fs";
import path from "path";
import os from "os";
import { exec } from "child_process";
import { promisify } from "util";
const execAsync = promisify(exec);

const HASH_FOLDER = "hash_storage";
const OWNER_ID = "OWNER_ONLY";
const HASH_GROUP_SIZE = 100;
const BATCH_SIZE = 25;
const CHUNK_SIZE = 1024 * 1024;

const SAFE_PATHS = [
  "token","posts","proofs","feeds","bridge","remote_queue",
  "sha","patches","device","ai_engine","media_engine","parliament"
];

const BLOCKED = ["ai_network/repos","node_modules","logs","recovery",".git"];

async function run(cmd) {
  try {
    const { stdout, stderr } = await execAsync(cmd, { maxBuffer: 1024 * 1024 * 20 });
    return { ok: true, stdout, stderr };
  } catch (e) {
    return { ok: false, stdout: e.stdout || "", stderr: e.stderr || e.message };
  }
}

function doubleShaBuffer(buf) {
  const first = crypto.createHash("sha256").update(buf).digest();
  return crypto.createHash("sha256").update(first).digest("hex");
}

function stableJson(obj) {
  return JSON.stringify(obj, Object.keys(obj).sort());
}

async function doubleHashWorkerAsync(infoDict) {
  const raw = stableJson(infoDict);
  return [doubleShaBuffer(Buffer.from(raw)), infoDict];
}

async function doubleFileHash(file) {
  const first = crypto.createHash("sha256");
  await new Promise((resolve, reject) => {
    const s = fss.createReadStream(file, { highWaterMark: CHUNK_SIZE });
    s.on("data", c => first.update(c));
    s.on("end", resolve);
    s.on("error", reject);
  });
  return crypto.createHash("sha256").update(first.digest()).digest("hex");
}

async function doubleAudioHashWorkerAsync(audioBytes, sampleRate = 44100) {
  const h = doubleShaBuffer(audioBytes);
  return [h, { type: "audio", sample_rate: sampleRate, length_bytes: audioBytes.length }];
}

async function doubleVideoFrameHashAsync(frameBytes, meta = {}) {
  const h = doubleShaBuffer(frameBytes);
  return [h, { type: "video_frame", length_bytes: frameBytes.length, ...meta }];
}

async function pixelOverlayHashAsync(pixelBytes, width = 0, height = 0, channels = 4) {
  const h = doubleShaBuffer(pixelBytes);
  return [h, { type: "pixel_overlay", width, height, channels, length_bytes: pixelBytes.length }];
}

async function bitByteOverlayHashAsync(bytes, meta = {}) {
  const bitView = Buffer.from(bytes).toString("hex");
  const h = doubleShaBuffer(Buffer.from(bitView));
  return [h, { type: "bit_byte_overlay", length_bytes: bytes.length, ...meta }];
}

class RootHash {
  constructor() { this.menuIndex = new Map(); }

  addEntry(level, h, meta) {
    this.menuIndex.set(h, { level, timestamp: Date.now() / 1000, meta });
  }

  buildRootHash() {
    const obj = Object.fromEntries(this.menuIndex);
    return doubleShaBuffer(Buffer.from(JSON.stringify(obj)));
  }

  export() {
    return { menu: Object.fromEntries(this.menuIndex), root_hash: this.buildRootHash() };
  }
}

class RuleEngine {
  constructor(ownerId) { this.ownerId = ownerId; }
  authorize(requesterId) { return requesterId === this.ownerId; }
  biometricProtection(meta) {
    const forbidden = new Set(["fingerprint","face","iris","raw_biometric"]);
    return !Object.keys(meta || {}).some(k => forbidden.has(k));
  }
}

class ITDepartment {
  constructor() {
    this.logs = [];
    this.systemHealth = {};
  }

  logEvent(message) {
    this.logs.push({ time: Date.now() / 1000, message });
    if (this.logs.length > 1000) this.logs = this.logs.slice(-1000);
  }

  audit(levels) {
    let total = 0;
    for (const v of Object.values(levels)) total += Object.keys(v).length;
    this.systemHealth = {
      hash_levels: Object.keys(levels).length,
      total_hashes: total,
      memory: {
        free: os.freemem(),
        total: os.totalmem()
      },
      last_check: Date.now() / 1000
    };
    this.logEvent("System audit completed");
  }

  report() { return { health: this.systemHealth, logs: this.logs.slice(-20) }; }
}

class DeviceIntegration {
  async snapshot() {
    const data = {
      platform: os.platform(),
      arch: os.arch(),
      hostname_hash: doubleShaBuffer(Buffer.from(os.hostname())),
      cpus: os.cpus().length,
      memory_total: os.totalmem(),
      memory_free: os.freemem(),
      uptime: os.uptime(),
      git_branch: (await run("git branch --show-current")).stdout.trim(),
      git_remote_hash: doubleShaBuffer(Buffer.from((await run("git remote -v")).stdout || "")),
      pwd: process.cwd(),
      time: Date.now()
    };
    await fs.mkdir("device/os", { recursive: true });
    await fs.writeFile("device/os/device_snapshot.json", JSON.stringify(data, null, 2));
    return data;
  }
}

class CybraParliament {
  async submit(topic, type, payload = {}) {
    await fs.mkdir("parliament/tasks", { recursive: true });
    const task = { topic, type, payload, source: "gitcybrahash_double_backend", time: Date.now() };
    const id = doubleShaBuffer(Buffer.from(JSON.stringify(task))).slice(0, 16);
    await fs.writeFile(`parliament/tasks/${id}.json`, JSON.stringify(task, null, 2));
    return { id, task };
  }
}

class SecureGitBridge {
  async safeGitCommit(message) {
    const paths = [
      "gitcybrahash_double_backend.mjs",
      "hash_storage",
      "device",
      "ai_engine",
      "media_engine",
      "posts",
      "proofs",
      "feeds",
      "parliament/tasks"
    ].map(x => JSON.stringify(x)).join(" ");

    await run(`git add ${paths} 2>/dev/null || true`);

    const blocked = await run("git diff --cached --name-only | grep -E '(^|/)(ai_network/repos|node_modules|logs|recovery)(/|$)' || true");
    if (blocked.stdout.trim()) {
      await run("git restore --staged -- ai_network/repos node_modules logs recovery 2>/dev/null || true");
      throw new Error("Blocked heavy paths removed from git index");
    }

    await run(`git commit -m ${JSON.stringify(message)} || true`);
    return await run("git push || true");
  }
}

class AutoFix {
  async run() {
    for (const d of ["hash_storage","device/os","ai_engine","media_engine","posts","proofs","feeds","parliament/tasks","bridge/secure"]) {
      await fs.mkdir(d, { recursive: true });
    }
    return true;
  }
}

class AutoMemoryCollector {
  constructor(ownerId = OWNER_ID) {
    this.levels = { 0: {} };
    this.root = new RootHash();
    this.rules = new RuleEngine(ownerId);
    this.itDepartment = new ITDepartment();
    this.device = new DeviceIntegration();
    this.parliament = new CybraParliament();
    this.git = new SecureGitBridge();
    this.autofix = new AutoFix();
    this._ready = this.autofix.run();
  }

  async ready() { await this._ready; }

  _collapseLevel(level) {
    const items = Object.entries(this.levels[level] || {});
    if (items.length < HASH_GROUP_SIZE) return;
    const h = doubleShaBuffer(Buffer.from(JSON.stringify(items)));
    this.levels[level] = {};
    const next = level + 1;
    if (!this.levels[next]) this.levels[next] = {};
    this.levels[next][h] = { count: items.length };
    this.root.addEntry(next, h, { count: items.length, type: "collapsed" });
  }

  async collectBatch(infoList, requesterId = OWNER_ID) {
    await this.ready();
    if (!this.rules.authorize(requesterId)) return null;

    for (let i = 0; i < infoList.length; i += BATCH_SIZE) {
      const batch = infoList.slice(i, i + BATCH_SIZE);
      const results = await Promise.all(batch.map(info => doubleHashWorkerAsync(info)));
      for (const [h, info] of results) {
        this.levels[0][h] = info;
        this.root.addEntry(0, h, { type: "data" });
      }
      this._collapseLevel(0);
    }

    this.itDepartment.audit(this.levels);
    return this.root.buildRootHash();
  }

  async collectFile(file, requesterId = OWNER_ID) {
    await this.ready();
    if (!this.rules.authorize(requesterId)) return null;
    const h = await doubleFileHash(file);
    this.root.addEntry(0, h, { type: "file", file });
    return h;
  }

  async collectAudio(audioBytes, sampleRate = 44100, requesterId = OWNER_ID) {
    await this.ready();
    if (!this.rules.authorize(requesterId)) return null;
    const [h, meta] = await doubleAudioHashWorkerAsync(audioBytes, sampleRate);
    if (!this.rules.biometricProtection(meta)) return null;
    this.root.addEntry(0, h, meta);
    return h;
  }

  async collectVideoFrame(frameBytes, meta = {}, requesterId = OWNER_ID) {
    await this.ready();
    if (!this.rules.authorize(requesterId)) return null;
    const [h, m] = await doubleVideoFrameHashAsync(frameBytes, meta);
    this.root.addEntry(0, h, m);
    return h;
  }

  async collectPixels(pixelBytes, width, height, channels = 4, requesterId = OWNER_ID) {
    await this.ready();
    if (!this.rules.authorize(requesterId)) return null;
    const [h, meta] = await pixelOverlayHashAsync(pixelBytes, width, height, channels);
    this.root.addEntry(0, h, meta);
    return h;
  }

  async collectBitsBytes(bytes, meta = {}, requesterId = OWNER_ID) {
    await this.ready();
    if (!this.rules.authorize(requesterId)) return null;
    const [h, m] = await bitByteOverlayHashAsync(bytes, meta);
    this.root.addEntry(0, h, m);
    return h;
  }

  async exportRoot() {
    await this.ready();
    const device = await this.device.snapshot();
    const data = {
      engine: "CYBRA AI OS Hash Engine",
      device,
      root: this.root.export(),
      it: this.itDepartment.report()
    };

    await fs.writeFile(path.join(HASH_FOLDER, "root_hash.json"), JSON.stringify(data, null, 2));
    const root = doubleShaBuffer(Buffer.from(JSON.stringify(data)));

    await fs.writeFile("feeds/ai_os_engine.json", JSON.stringify({
      status: "active",
      root_double_sha: root,
      modules: ["device","git","audio","video","pixels","bits","bytes","ai_os","parliament","autofix"]
    }, null, 2));

    await fs.writeFile("posts/ai_os_engine_status.md", `# CYBRA AI OS Hash Engine

Status: active

Root Double SHA:
${root}

Modules:
- Device integration
- Secure Git Bridge
- CYBRA Parliament
- AutoFix
- Audio hashing
- Video frame hashing
- Pixel overlay hashing
- Bit/Byte overlay hashing
- AI data processing engine
`);

    await this.parliament.submit("CYBRA AI OS Engine Sync", "ai_os_hash_engine_task", { root_double_sha: root, device });

    const proof = await run("sha256sum gitcybrahash_double_backend.mjs hash_storage/root_hash.json feeds/ai_os_engine.json posts/ai_os_engine_status.md device/os/device_snapshot.json");
    await fs.writeFile("proofs/ai_os_engine.sha256", proof.stdout);

    return data;
  }
}

class MenuBarFromRoot {
  constructor(rootData) { this.menu = rootData.root?.menu || {}; }
  show() {
    console.log("\n=== CYBRA AI OS ROOT MENU ===");
    let i = 1;
    for (const [h, v] of Object.entries(this.menu)) {
      console.log(`${i}. HASH ${h.slice(0,12)} | level=${v.level} | type=${v.meta?.type || "data"}`);
      i++;
    }
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  (async () => {
    const collector = new AutoMemoryCollector();

    await collector.collectBatch(Array.from({ length: 100 }, (_, i) => ({
      frame: i,
      type: "ai_data",
      time: Date.now()
    })));

    await collector.collectAudio(Buffer.from("AUDIO_STREAM_TEST"), 44100);
    await collector.collectVideoFrame(Buffer.from("VIDEO_FRAME_TEST"), { width: 1920, height: 1080 });
    await collector.collectPixels(Buffer.from("PIXEL_OVERLAY_TEST"), 100, 100, 4);
    await collector.collectBitsBytes(Buffer.from("BIT_BYTE_TEST"), { source: "device" });

    const exported = await collector.exportRoot();
    new MenuBarFromRoot(exported).show();
    console.log(JSON.stringify(collector.itDepartment.report(), null, 2));
  })();
}

export {
  AutoMemoryCollector,
  doubleHashWorkerAsync,
  doubleAudioHashWorkerAsync,
  doubleVideoFrameHashAsync,
  pixelOverlayHashAsync,
  bitByteOverlayHashAsync
};
MJS

node gitcybrahash_double_backend.mjs

sha256sum \
gitcybrahash_double_backend.mjs \
hash_storage/root_hash.json \
feeds/ai_os_engine.json \
posts/ai_os_engine_status.md \
proofs/ai_os_engine.sha256 \
> proofs/ai_os_engine_install.sha256

echo "✅ CYBRA AI OS Hash Engine installed"
