// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 32
// part: 3
// original_header: console.log("🧠 MODULE 32: Evolutionary Learner ACTIVE");
// original_line_start: 2244
// original_line_end: 2355
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🧠 MODULE 32: Evolutionary Learner ACTIVE");

const fs = require('fs');
const path = require('path');
const LOG_DIR = './worker_logs';
const BEST_PARAMS_FILE = './best_params.json';

if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });

// Параметри, які будемо мутувати
const PARAM_RANGES = {
'CONFIG.signal.DEVIATION_THRESHOLD': [0.0003, 0.003],
'CONFIG.signal.VOLATILITY_THRESHOLD': [0.0001, 0.001],
'CONFIG.signal.VOLUME_THRESHOLD': [1.1, 2.0],
'CONFIG.risk.TAKE_PROFIT': [0.1, 0.5],
'CONFIG.risk.STOP_LOSS': [0.2, 0.8],
'adaptiveState.state.deviation': [0.0005, 0.002],
'adaptiveState.state.volatility': [0.0002, 0.001]
};

// Завантаження найкращих параметрів
let bestParams = {};
if (fs.existsSync(BEST_PARAMS_FILE)) {
try {
bestParams = JSON.parse(fs.readFileSync(BEST_PARAMS_FILE));
console.log("📥 Завантажено найкращі параметри:", bestParams);
} catch(e) {}
}

// Функція мутації параметрів для нового воркера
function mutateParams(workerId, previousParams = null) {
let newParams = previousParams ? { ...previousParams } : { ...bestParams };
// Якщо немає попередніх параметрів, генеруємо випадкові
if (Object.keys(newParams).length === 0) {
for (let [key, range] of Object.entries(PARAM_RANGES)) {
newParams[key] = range[0] + Math.random() * (range[1] - range[0]);
}
} else {
// Мутація: випадковий параметр змінюється на ±20%
const keys = Object.keys(newParams);
const paramToMutate = keys[Math.floor(Math.random() * keys.length)];
const range = PARAM_RANGES[paramToMutate] || [newParams[paramToMutate]*0.8, newParams[paramToMutate]*1.2];
let newVal = newParams[paramToMutate] * (0.8 + Math.random() * 0.4);
newVal = Math.max(range[0], Math.min(range[1], newVal));
newParams[paramToMutate] = newVal;
console.log(🧬 Worker ${workerId} mutated: ${paramToMutate} = ${newVal.toFixed(6)} (was ${previousParams[paramToMutate].toFixed(6)}));
}
return newParams;
}

// Збереження параметрів воркера у файл (для передачі при запуску)
function saveWorkerParams(workerId, params) {
const file = path.join(LOG_DIR, worker_${workerId}_params.json);
fs.writeFileSync(file, JSON.stringify(params, null, 2));
}

// Аналіз логів воркера (читаємо його файл trades.log)
function analyzeWorkerLogs(workerId) {
const logFile = path.join(LOG_DIR, worker_${workerId}_trades.log);
if (!fs.existsSync(logFile)) return null;
const content = fs.readFileSync(logFile, 'utf8');
const lines = content.trim().split('\n').filter(l => l.trim());
let wins = 0, losses = 0, totalPnL = 0;
for (let line of lines) {
try {
const entry = JSON.parse(line);
if (entry.result === 'win') wins++;
if (entry.result === 'loss') losses++;
totalPnL += entry.pnl || 0;
} catch(e) {}
}
const total = wins + losses;
if (total === 0) return null;
return { wins, losses, winrate: wins/total, totalPnL, trades: total };
}

// Оновлення найкращих параметрів на основі успішних воркерів
function updateBestParams() {
let bestWorker = null;
let bestScore = -Infinity;
for (let i = 1; i <= parseInt(process.env.NUM_WORKERS || 7); i++) {
const stats = analyzeWorkerLogs(i);
if (stats && stats.trades >= 10) {
const score = stats.winrate * stats.totalPnL; // комбінована оцінка
if (score > bestScore) {
bestScore = score;
bestWorker = i;
}
}
}
if (bestWorker) {
const paramsFile = path.join(LOG_DIR, worker_${bestWorker}_params.json);
if (fs.existsSync(paramsFile)) {
const bestNewParams = JSON.parse(fs.readFileSync(paramsFile));
bestParams = bestNewParams;
fs.writeFileSync(BEST_PARAMS_FILE, JSON.stringify(bestParams, null, 2));
console.log(🏆 НОВІ НАЙКРАЩІ ПАРАМЕТРИ від worker ${bestWorker} (score ${bestScore.toFixed(4)}));
}
}
}

// Періодичне навчання (кожні 5 хвилин)
setInterval(() => {
console.log("🧠 Evolutionary Learner: analyzing logs and updating best params...");
updateBestParams();
}, 5 * 60 * 1000);

// Експортуємо функції для використання модулем 31
global.getMutatedParams = (workerId, oldParams) => mutateParams(workerId, oldParams);
global.saveWorkerParams = saveWorkerParams;
global.updateBestParams = updateBestParams;
