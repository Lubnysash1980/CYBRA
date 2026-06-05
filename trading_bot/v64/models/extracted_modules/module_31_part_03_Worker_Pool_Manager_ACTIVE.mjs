// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 31
// part: 3
// original_header: console.log("🧩 MODULE 31: Worker Pool Manager ACTIVE");
// original_line_start: 2055
// original_line_end: 2217
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🧩 MODULE 31: Worker Pool Manager ACTIVE");

const fs = require('fs');
const { fork } = require('child_process');
const path = require('path');

const NUM_WORKERS = parseInt(process.env.NUM_WORKERS || 7);
const CONSENSUS_THRESHOLD = parseFloat(process.env.CONSENSUS_THRESHOLD || 0.7);
const DECISION_TIMEOUT = parseInt(process.env.DECISION_TIMEOUT || 5000);
const WORKER_HEARTBEAT_INTERVAL = 5000;
const WORKER_FAILURE_THRESHOLD = 3; // 3 пропущених heartbeat = dead
const PERFORMANCE_WINDOW = 50;      // останні N трейдів для оцінки

let workers = new Map(); // id -> { worker, heartbeatMisses, stats }
let pendingDecision = null;
let orchestratorInterval = null;

// ---------- Реальне виконання ордера ----------
async function executeRealOrder(symbol, side, quantity, price) {
console.log(🚀 REAL ORDER: ${side.toUpperCase()} ${quantity} ${symbol} @ ${price});
// Тут ваш код Binance API (скопіюйте з placeOrder, але з REAL_MODE=true)
const BASE_URL = process.env.BINANCE_TESTNET === "true"
? "https://testnet.binancefuture.com"
: "https://fapi.binance.com";
const timestamp = Date.now();
const orderSide = side === "long" ? "BUY" : "SELL";
const queryParams = {
symbol: symbol.toUpperCase(),
side: orderSide,
type: "MARKET",
quantity: Number(quantity.toFixed(3)),
timestamp
};
const queryString = new URLSearchParams(queryParams).toString();
const signature = crypto.createHmac("sha256", process.env.BINANCE_API_SECRET).update(queryString).digest("hex");
const url = ${BASE_URL}/fapi/v1/order?${queryString}&signature=${signature};
try {
const res = await fetch(url, { method: "POST", headers: { "X-MBX-APIKEY": process.env.BINANCE_API_KEY } });
const data = await res.json();
if (data.code && data.code !== 200) throw new Error(data.msg);
console.log("✅ ORDER EXECUTED:", data);
} catch (err) {
console.error("❌ ORDER FAILED:", err.message);
}
}

// ---------- Голосування ----------
function handleWorkerSignal(msg, workerId) {
if (msg.type !== 'signal') return;
const { symbol, side, price, quantity } = msg;
const key = ${symbol}_${side};
const now = Date.now();

if (!pendingDecision || pendingDecision.key !== key || (now - pendingDecision.startTime) > DECISION_TIMEOUT) {    
  if (pendingDecision?.timeoutId) clearTimeout(pendingDecision.timeoutId);    
  pendingDecision = {    
    key, symbol, side, price, quantity,    
    votes: new Set(),    
    startTime: now,    
    timeoutId: setTimeout(() => finalizeDecision(false), DECISION_TIMEOUT)    
  };    
}    
pendingDecision.votes.add(workerId);    
const totalVotes = pendingDecision.votes.size;    
const consensus = totalVotes / NUM_WORKERS;    
console.log(`🗳️ Worker ${workerId} votes ${side} (${totalVotes}/${NUM_WORKERS} = ${(consensus*100).toFixed(0)}%)`);    
if (consensus >= CONSENSUS_THRESHOLD) {    
  if (pendingDecision.timeoutId) clearTimeout(pendingDecision.timeoutId);    
  finalizeDecision(true);    
}

}

function finalizeDecision(consensusReached) {
if (!pendingDecision) return;
const { symbol, side, price, quantity, votes, startTime } = pendingDecision;
const consensus = votes.size / NUM_WORKERS;
if (consensusReached && consensus >= CONSENSUS_THRESHOLD) {
console.log(✅ CONSENSUS ${(consensus*100).toFixed(0)}% ≥ ${CONSENSUS_THRESHOLD*100}% → EXECUTING ${side} ${symbol});
executeRealOrder(symbol, side, quantity, price);
} else {
console.log(❌ NO CONSENSUS (${(consensus*100).toFixed(0)}% < ${CONSENSUS_THRESHOLD*100}%) for ${side} ${symbol});
}
pendingDecision = null;
}

// ---------- Статистика воркерів ----------
function updateWorkerStats(workerId, result) {
const worker = workers.get(workerId);
if (!worker) return;
if (!worker.stats) worker.stats = { trades: [], wins: 0, losses: 0, lastUpdate: Date.now() };
worker.stats.trades.push(result); // result: 'win' or 'loss'
if (worker.stats.trades.length > PERFORMANCE_WINDOW) worker.stats.trades.shift();
worker.stats.wins = worker.stats.trades.filter(r => r === 'win').length;
worker.stats.losses = worker.stats.trades.filter(r => r === 'loss').length;
worker.stats.winrate = worker.stats.trades.length ? (worker.stats.wins / worker.stats.trades.length) : 0;
}

function getWorkerPerformance(workerId) {
const worker = workers.get(workerId);
if (!worker || !worker.stats || worker.stats.trades.length < 5) return 0.5;
return worker.stats.winrate;
}

// ---------- Heartbeat та заміна поганих воркерів ----------
function checkWorkerHealth() {
const now = Date.now();
for (let [id, data] of workers.entries()) {
// Перевірка heartbeat
if (now - data.lastHeartbeat > WORKER_HEARTBEAT_INTERVAL * (WORKER_FAILURE_THRESHOLD + 1)) {
console.log(💀 Worker ${id} dead (no heartbeat). Restarting...);
restartWorker(id);
continue;
}
// Перевірка продуктивності (падіння >3% відносно середнього)
const perf = getWorkerPerformance(id);
const allPerfs = Array.from(workers.values()).map(w => getWorkerPerformance(w.id)).filter(p => p > 0);
const avgPerf = allPerfs.length ? allPerfs.reduce((a,b)=>a+b,0)/allPerfs.length : 0.5;
if (perf < avgPerf - 0.03 && workers.size >= 3) {
console.log(⚠️ Worker ${id} performance drop: ${(perf*100).toFixed(1)}% (avg ${(avgPerf*100).toFixed(1)}%). Replacing...);
restartWorker(id, true); // mutate parameters
}
}
}

function restartWorker(workerId, mutate = false) {
const old = workers.get(workerId);
if (old) {
try { old.worker.kill(); } catch(e) {}
workers.delete(workerId);
}
startWorker(workerId, mutate);
}

function startWorker(workerId, mutate = false) {
const workerEnv = {
...process.env,
WORKER_ID: workerId,
WORKER_MODE: 'orchestrated',
MUTATE_PARAMS: mutate ? 'true' : 'false'
};
const worker = fork('./bot_worker.js', [workerId], { env: workerEnv });
const stats = { trades: [], wins: 0, losses: 0, winrate: 0.5 };
workers.set(workerId, { worker, lastHeartbeat: Date.now(), stats, id: workerId });
worker.on('message', (msg) => {
if (msg.type === 'heartbeat') {
workers.get(workerId).lastHeartbeat = Date.now();
} else if (msg.type === 'trade_result') {
updateWorkerStats(workerId, msg.result);
} else {
handleWorkerSignal(msg, workerId);
}
});
worker.on('exit', (code) => {
console.log(🔁 Worker ${workerId} exited (code ${code}), restarting...);
restartWorker(workerId);
});
console.log(🟢 Worker ${workerId} started (mutate=${mutate}));
}

// Запуск всіх воркерів
for (let i = 1; i <= NUM_WORKERS; i++) startWorker(i);
orchestratorInterval = setInterval(checkWorkerHealth, WORKER_HEARTBEAT_INTERVAL);
