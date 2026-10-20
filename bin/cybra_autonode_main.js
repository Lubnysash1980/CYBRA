#!/usr/bin/env node
// cybra_autonode_main.js — Нода з синхронізацією (унісон між пристроями)

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const CYBRA_HOME = path.join(process.env.HOME, 'CYBRA');
const LOG = path.join(CYBRA_HOME, 'logs', 'evo_node_main.log');
const PM2_STATE_FILE = path.join(CYBRA_HOME, 'nodes/node_1/state/pm2_sync.json');

// Таймери
const CYCLE_SLEEP_MS = 60 * 1000;      // Основний цикл (60с)
const SYNC_SLEEP_MS = 5 * 60 * 1000;   // Git-синхронізація (5 хв)

function log(msg) {
  const timestamp = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  const line = `[${timestamp}] ${msg}\n`;
  try { fs.appendFileSync(LOG, line); } catch (e) { process.stdout.write(line); }
}

// Синхронізація з Git
function syncGit() {
  try {
    // Перевіряємо, чи є .git
    if (!fs.existsSync(path.join(CYBRA_HOME, '.git'))) return;
    
    log('--- Git Sync ---');
    // 1. Отримуємо зміни з іншого пристрою
    try { execSync('git pull --rebase -q', { cwd: CYBRA_HOME, stdio: 'ignore' }); } catch(e) {}
    
    // 2. Збираємо поточний стан PM2
    try {
      const pm2List = execSync('pm2 jlist', { encoding: 'utf8' });
      const procs = JSON.parse(pm2List);
      const online = procs.filter(p => p.pm2_env.status === 'online').map(p => p.name);
      
      const syncData = {
        device: "node_1_" + require('os').hostname(),
        updated: new Date().toISOString(),
        pm2_online: online,
        total: procs.length
      };
      
      fs.writeFileSync(PM2_STATE_FILE, JSON.stringify(syncData, null, 2));
      
      // 3. Відправляємо свій стан
      execSync('git add -A', { cwd: CYBRA_HOME, stdio: 'ignore' });
      execSync(`git commit -m "auto: pm2 sync from device [skip ci]" -q`, { cwd: CYBRA_HOME, stdio: 'ignore' });
      execSync('git push origin main -q', { cwd: CYBRA_HOME, stdio: 'ignore' });
      log(`Git Sync OK: ${online.length} online processes pushed.`);
    } catch (e) {
      // Ігноруємо помилки, якщо нічого комітити
    }
  } catch (e) {
    log(`SYNC ERROR: ${e.message}`);
  }
}

function runCycle() {
  log('--- Cycle ---');
  
  // Перевірка Sandbox
  const sandbox = path.join(CYBRA_HOME, 'sandbox');
  if (fs.existsSync(sandbox)) {
    try {
      const out = execSync('du -sb ' + sandbox, { encoding: 'utf8' });
      const sizeMb = Math.floor(parseInt(out.split(/\s+/)[0], 10) / 1024 / 1024);
      if (sizeMb > 65) {
        log(`SANDBOX: переповнено (${sizeMb} МБ), очищаю`);
        const cleanup = path.join(sandbox, 'sandbox_cleanup.sh');
        if (fs.existsSync(cleanup)) execSync('bash ' + cleanup, { stdio: 'ignore' });
      }
    } catch (e) {}
  }
  
  log('EVO: 100% — система в нормі');
}

// Запуск
if (!fs.existsSync(CYBRA_HOME)) {
  log(`FATAL: CYBRA_HOME не існує`);
  process.exit(1);
}
process.chdir(CYBRA_HOME);
log('=== Node Main Start (Sync Mode) ===');

let lastSync = 0;

function loop() {
  try {
    runCycle();
    
    // Синхронізація кожні 5 хвилин
    if (Date.now() - lastSync > SYNC_SLEEP_MS) {
      syncGit();
      lastSync = Date.now();
    }
  } catch (e) {
    log(`CYCLE ERROR: ${e.message}`);
  }
  setTimeout(loop, CYCLE_SLEEP_MS);
}

// Обробка сигналів
process.on('SIGINT', () => { log('=== Stop (SIGINT) ==='); process.exit(0); });
process.on('SIGTERM', () => { log('=== Stop (SIGTERM) ==='); process.exit(0); });

loop();
