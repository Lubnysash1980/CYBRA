import WebSocket from "ws";
import crypto from "crypto";
import fs from "fs";
import readline from "readline";
import "dotenv/config";
import { exec } from "child_process";
import https from "https";
import path from "path";
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
// Далі ваш оригінальний код...

// ================== RING BUFFER ==================
class RingBuffer {
constructor(size) {
this.size = size;
this.prices = [];
this.volumes = [];
}
push(price, volume) {
this.prices.push(price);
this.volumes.push(volume);
if (this.prices.length > this.size) this.prices.shift();
if (this.volumes.length > this.size) this.volumes.shift();
}
get length() { return this.prices.length; }
getPrices() { return [...this.prices]; }
getVolumes() { return [...this.volumes]; }
}

// ================== ЛОГУВАННЯ З ТАЙМСТАМПОМ ==================
const originalLog = console.log;
const originalError = console.error;
console.log = (...args) => {
const timestamp = new Date().toLocaleTimeString();
originalLog([${timestamp}], ...args);
};
console.error = (...args) => {
const timestamp = new Date().toLocaleTimeString();
originalError([${timestamp}] ❌, ...args);
};

// ================== КОНФІГУРАЦІЯ ==================
const CONFIG = Object.freeze({
ws: {
SYMBOL: process.env.SYMBOL || "dogeusdt",
RECONNECT_MAX_DELAY: 10000
},
signal: {
WINDOW: Number(process.env.WINDOW || 30),
DEVIATION_THRESHOLD: Number(process.env.DEVIATION_THRESHOLD || 0.001),
VOLATILITY_THRESHOLD: Number(process.env.VOLATILITY_THRESHOLD || 0.0005),
VOLUME_THRESHOLD: Number(process.env.VOLUME_THRESHOLD || 1.3),
CONFIRM_TICKS: Number(process.env.CONFIRM_TICKS || 3),
TIME_WINDOW: Number(process.env.TIME_WINDOW || 10000),
AUTO_THRESHOLD: process.env.AUTO_THRESHOLD === "true",
ADAPT_FACTOR: Number(process.env.ADAPT_FACTOR || 1.5)
},
risk: {
TAKE_PROFIT: Number(process.env.TAKE_PROFIT || 0.2),
STOP_LOSS: Number(process.env.STOP_LOSS || 0.35),
MAX_RISK_PER_TRADE: Number(process.env.MAX_RISK_PER_TRADE || 1),
MAX_DAILY_LOSS: Number(process.env.MAX_DAILY_LOSS || 5),
MAX_TRADES_PER_DAY: Number(process.env.MAX_TRADES_PER_DAY || 10)
},
logging: {
LOG_FILE: "bot.log"
},
entry: {
ORDER_TYPE: process.env.ENTRY_ORDER_TYPE || "MARKET",
OFFSET_PERCENT: Number(process.env.ENTRY_OFFSET_PERCENT || 0.1)
},
cooldown: {
ENABLED: process.env.COOLDOWN_ENABLED !== "false",
MIN_MS: Number(process.env.COOLDOWN_MIN_MS || 5000),
MULTIPLIER: Number(process.env.COOLDOWN_MULTIPLIER || 0.5),
SWING_LOOKBACK: Number(process.env.SWING_LOOKBACK || 14),
SWING_THRESHOLD_PERCENT: Number(process.env.SWING_THRESHOLD_PERCENT || 0.3)
},
trading: {
REAL_MODE: false
}
});

// ================== ГЛОБАЛЬНІ ЗМІННІ ==================
let account = { balance: 0, dailyLoss: 0, tradesToday: 0 };
let cooldownUntil = 0;
let state = { status: "IDLE", entry: null, side: null };
let lastSwingLength = 0;
let reconnectAttempts = 0;
let buffers = new RingBuffer(CONFIG.signal.WINDOW);
let tsQueue = [];
let tsHead = 0;
let volStats = { n: 0, mean: 0, M2: 0 };
let cachedVolumesAvg = 0;
let cachedVolumeSpike = 1;

// ================== АДАПТИВНІ ПОРОГИ ==================
class AdaptiveThresholds {
constructor() {
this.base = {
deviation: CONFIG.signal.DEVIATION_THRESHOLD,
volatility: CONFIG.signal.VOLATILITY_THRESHOLD,
volume: CONFIG.signal.VOLUME_THRESHOLD
};
this.state = { ...this.base };
}
validate(input) {
const sanitize = (v, fallback) => {
const n = Number(v);
return Number.isFinite(n) && n > 0 ? n : fallback;
};
return {
deviation: sanitize(input.deviation, this.state.deviation),
volatility: sanitize(input.volatility, this.state.volatility),
volume: sanitize(input.volume, this.state.volume)
};
}
get() { return this.state; }
update(input) {
if (!CONFIG.signal.AUTO_THRESHOLD) return;
const normalized = this.validate(input);
this.state = {
deviation: normalized.deviation * CONFIG.signal.ADAPT_FACTOR,
volatility: normalized.volatility * CONFIG.signal.ADAPT_FACTOR,
volume: normalized.volume
};
}
}
const adaptiveState = new AdaptiveThresholds();

// ================== ДЕДУПЛІКАЦІЯ ==================
class Deduper {
constructor() { this.lastHash = null; }
hash(data) { return crypto.createHash("sha256").update(JSON.stringify(data)).digest("hex"); }
isDuplicate(signal) {
const h = this.hash(signal);
if (h === this.lastHash) return true;
this.lastHash = h;
return false;
}
}
const deduper = new Deduper();

// ================== ДОПОМІЖНІ ФУНКЦІЇ ==================
const avg = arr => arr.length ? arr.reduce((a,b)=>a+b,0)/arr.length : 0;

function addTimestamp(ts) { tsQueue.push(ts); }
function pruneTimestamps(now) {
const limit = now - CONFIG.signal.TIME_WINDOW;
while (tsHead < tsQueue.length && tsQueue[tsHead] < limit) tsHead++;
}
function getRecentCount() { return tsQueue.length - tsHead; }

function updateVolStats(x) {
volStats.n++;
const delta = x - volStats.mean;
volStats.mean += delta / volStats.n;
const delta2 = x - volStats.mean;
volStats.M2 += delta * delta2;
}
function volatility() { return volStats.n < 2 ? 0 : Math.sqrt(volStats.M2 / (volStats.n - 1)); }
function deviation(price) {
if (buffers.length < 5) return 0;
const prices = buffers.getPrices();
const mean = avg(prices);
return mean === 0 ? 0 : (price - mean) / mean;
}
function volumeSpike() { return buffers.length < 5 ? 1 : cachedVolumeSpike; }

function getAverageSwingPercent() {
const prices = buffers.getPrices();
if (prices.length < CONFIG.cooldown.SWING_LOOKBACK) return 0;
const recent = prices.slice(-CONFIG.cooldown.SWING_LOOKBACK);
let swings = [];
for (let i = 1; i < recent.length; i++) {
const change = Math.abs((recent[i] - recent[i-1]) / recent[i-1]) * 100;
if (change >= CONFIG.cooldown.SWING_THRESHOLD_PERCENT) swings.push(change);
}
if (swings.length === 0) return 0;
return swings.reduce((a,b)=>a+b,0) / swings.length;
}

function calculateCooldownDuration() {
if (!CONFIG.cooldown.ENABLED) return 0;
const swing = getAverageSwingPercent();
if (swing === 0) return CONFIG.cooldown.MIN_MS;
const dynamicMs = swing * CONFIG.cooldown.MULTIPLIER * 1000;
return Math.max(CONFIG.cooldown.MIN_MS, dynamicMs);
}

// ================== ОТРИМАННЯ РЕАЛЬНОГО БАЛАНСУ ==================
async function getAccountBalance() {
if (!CONFIG.trading.REAL_MODE) {
account.balance = 1000;
console.log(🧪 PAPER BALANCE: ${account.balance} USDT);
return;
}
const BASE_URL = process.env.BINANCE_TESTNET === "true"
? "https://testnet.binancefuture.com"
: "https://fapi.binance.com";
const timestamp = Date.now();
const queryString = timestamp=${timestamp}&recvWindow=5000;
const signature = crypto.createHmac("sha256", process.env.BINANCE_API_SECRET).update(queryString).digest("hex");
const url = ${BASE_URL}/fapi/v2/account?${queryString}&signature=${signature};
try {
const res = await fetch(url, { headers: { "X-MBX-APIKEY": process.env.BINANCE_API_KEY } });
const data = await res.json();
if (!data.assets) throw new Error(JSON.stringify(data));
const usdtAsset = data.assets.find(a => a.asset === "USDT");
if (usdtAsset) {
account.balance = parseFloat(usdtAsset.walletBalance);
console.log(💰 REAL BALANCE: ${account.balance} USDT);
} else throw new Error("USDT asset not found");
} catch (err) {
console.error("Failed to fetch balance:", err.message);
account.balance = 0;
}
}

// ================== РОЗРАХУНОК КІЛЬКОСТІ ==================
function calcPositionSize(price) {
if (process.env.QUANTITY) {
let qty = parseFloat(process.env.QUANTITY);
if (isNaN(qty)) qty = 1;
return Math.max(1, qty);
}
if (!account.balance || account.balance <= 0) {
console.error("No balance for position sizing");
return 0;
}
const riskAmount = account.balance * (CONFIG.risk.MAX_RISK_PER_TRADE / 100);
const stopLossPercent = CONFIG.risk.STOP_LOSS / 100;
if (stopLossPercent === 0) return 0;
let qty = riskAmount / (price * stopLossPercent);
qty = Math.floor(qty * 1000) / 1000;
return Math.max(1, qty);
}

// ================== РОЗМІЩЕННЯ ОРДЕРУ ==================
async function placeOrder(side, quantity, currentPrice) {
if (!CONFIG.trading.REAL_MODE) {
let fillPrice = currentPrice;
if (CONFIG.entry.ORDER_TYPE === "LIMIT") {
fillPrice = side === "long"
? currentPrice * (1 - CONFIG.entry.OFFSET_PERCENT/100)
: currentPrice * (1 + CONFIG.entry.OFFSET_PERCENT/100);
}
console.log([PAPER] ${side.toUpperCase()} ${quantity} @ ${fillPrice.toFixed(8)});
return { paper: true, side, quantity, price: fillPrice };
}
if (quantity <= 0) {
console.error("Invalid quantity, aborting order");
return null;
}
const requiredMargin = currentPrice * quantity;
if (account.balance < requiredMargin * 0.05) {
console.error(Insufficient margin: balance=${account.balance}, required ~${requiredMargin * 0.05});
return null;
}
const BASE_URL = process.env.BINANCE_TESTNET === "true"
? "https://testnet.binancefuture.com"
: "https://fapi.binance.com";
const symbol = CONFIG.ws.SYMBOL.toUpperCase();
const orderSide = side === "long" ? "BUY" : "SELL";
const timestamp = Date.now();
const queryParams = {
symbol, side: orderSide, type: CONFIG.entry.ORDER_TYPE,
quantity: Number(quantity.toFixed(3)), timestamp
};
if (CONFIG.entry.ORDER_TYPE === "LIMIT") {
let limitPrice = side === "long"
? currentPrice * (1 - CONFIG.entry.OFFSET_PERCENT/100)
: currentPrice * (1 + CONFIG.entry.OFFSET_PERCENT/100);
limitPrice = parseFloat(limitPrice.toFixed(8));
queryParams.price = limitPrice;
queryParams.timeInForce = "GTC";
}
const queryString = new URLSearchParams(queryParams).toString();
const signature = crypto.createHmac("sha256", process.env.BINANCE_API_SECRET).update(queryString).digest("hex");
const url = ${BASE_URL}/fapi/v1/order?${queryString}&signature=${signature};
try {
const res = await fetch(url, { method: "POST", headers: { "X-MBX-APIKEY": process.env.BINANCE_API_KEY, "Content-Type": "application/json" } });
const data = await res.json();
if (data.code && data.code !== 200) throw new Error(data.msg);
console.log("✅ ORDER PLACED:", data);
return data;
} catch (err) {
console.error("ORDER FAILED:", err.message);
return null;
}
}

// ================== ЛОГІКА ВХОДУ / ВИХОДУ (ОСНОВНА) ==================
function checkDeviation(price) {
const dev = deviation(price);
const threshold = adaptiveState.get().deviation;
return Math.abs(dev) > threshold ? dev : null;
}
function checkVolatility() { return volatility() > adaptiveState.get().volatility; }
function checkVolume() { return volumeSpike() > adaptiveState.get().volume; }
function buildSignal(price) {
const dev = checkDeviation(price);
if (!dev) return null;
if (!checkVolatility()) return null;
if (!checkVolume()) return null;
return { side: dev > 0 ? "short" : "long", dev, vol: volatility(), volSpike: volumeSpike(), ts: Date.now() };
}
function tripleCheck() {
const now = Date.now();
addTimestamp(now);
pruneTimestamps(now);
return getRecentCount() >= CONFIG.signal.CONFIRM_TICKS;
}
function detectManipulation() {
if (buffers.length < 10) return false;
const prices = buffers.getPrices();
const recent = prices.slice(-10);
const last = recent[recent.length-1];
const mean = avg(recent);
const variance = avg(recent.map(p => Math.pow(p-mean,2)));
const std = Math.sqrt(variance);
if (std === 0) return false;
const z = (last - mean) / std;
const volSpike = volumeSpike();
if (Math.abs(z) > 2.5 && volSpike > 2.5) {
console.log("\n[MANIPULATION]");
return true;
}
return false;
}
function checkExit(price) {
if (state.status !== "IN_TRADE") return null;
const tpPrice = state.side === "long"
? state.entry * (1 + CONFIG.risk.TAKE_PROFIT / 100)
: state.entry * (1 - CONFIG.risk.TAKE_PROFIT / 100);
const slPrice = state.side === "long"
? state.entry * (1 - CONFIG.risk.STOP_LOSS / 100)
: state.entry * (1 + CONFIG.risk.STOP_LOSS / 100);
let exit = null;
if (state.side === "long") {
if (price >= tpPrice) exit = "TP";
if (price <= slPrice) exit = "SL";
} else {
if (price <= tpPrice) exit = "TP";
if (price >= slPrice) exit = "SL";
}
if (exit) {
const pnl = state.side === "long" ? (price - state.entry) : (state.entry - price);
const pnlPercent = (pnl / state.entry) * 100;
account.balance += account.balance * (pnlPercent / 100);
if (pnlPercent < 0) account.dailyLoss += Math.abs(pnlPercent);
console.log(💰 PnL: ${pnlPercent.toFixed(2)}%);
const cooldownMs = calculateCooldownDuration();
cooldownUntil = Date.now() + cooldownMs;
console.log(🔒 COOLDOWN: пауза ${(cooldownMs/1000).toFixed(1)}с);
return exit;
}
return null;
}
function riskCheck() {
if (account.dailyLoss >= CONFIG.risk.MAX_DAILY_LOSS) {
console.log("⛔ DAILY LOSS LIMIT HIT");
return false;
}
if (account.tradesToday >= CONFIG.risk.MAX_TRADES_PER_DAY) {
console.log("⛔ TRADE LIMIT HIT");
return false;
}
return true;
}

let onTick = async function(price, volume) {
buffers.push(price, volume);
updateVolStats(price);
if (!riskCheck()) return;

const volumes = buffers.getVolumes();
cachedVolumesAvg = avg(volumes);
cachedVolumeSpike = cachedVolumesAvg === 0 ? 1 : volumes.at(-1) / cachedVolumesAvg;
adaptiveState.update({
deviation: Math.abs(deviation(price)),
volatility: volatility(),
volume: volumeSpike()
});

if (detectManipulation()) return;
const exit = checkExit(price);
if (exit) {
state.status = "IDLE";
return;
}
if (state.status !== "IDLE") return;
if (cooldownUntil > Date.now()) return;

const signal = buildSignal(price);
if (!signal) return;
if (deduper.isDuplicate(signal)) return;
if (!tripleCheck()) return;

const qty = calcPositionSize(price);
if (qty === 0) return;
const order = await placeOrder(signal.side, qty, price);
if (!order) return;

state.status = "IN_TRADE";
state.entry = price;
state.side = signal.side;
account.tradesToday++;
};

// ================== АВТОФІКС І САМОПЕРЕВІРКА ==================
async function selfCheck() {
console.log("\n🔍 САМОПЕРЕВІРКА СИСТЕМИ:");
let ok = true;
if (!process.env.BINANCE_API_KEY || !process.env.BINANCE_API_SECRET) {
console.error("  ❌ ВІДСУТНІ API-ключі в .env (BINANCE_API_KEY, BINANCE_API_SECRET)");
ok = false;
} else {
console.log("  ✅ API-ключі присутні");
}
if (CONFIG.trading.REAL_MODE && account.balance === 0) {
console.error("  ❌ Реальний режим, але баланс = 0. Перемикаю в ТЕСТОВИЙ.");
CONFIG.trading.REAL_MODE = false;
account.balance = 1000;
ok = false;
}
if (CONFIG.trading.REAL_MODE && account.balance > 0) {
console.log(  ✅ Баланс: ${account.balance} USDT);
} else {
console.log("  ℹ️  Тестовий режим, баланс симульований = 1000 USDT");
}
if (!process.env.QUANTITY) {
console.warn("  ⚠️ QUANTITY не задано в .env, буде розраховано автоматично");
} else {
console.log(  ✅ Фіксована кількість: ${process.env.QUANTITY} DOGE);
}
console.log("  ✅ WebSocket буде підключено після старту");
if (!ok) console.log("  ⚠️ Деякі проблеми виправлено автоматично.");
else console.log("  ✅ Усі перевірки пройдено.");
console.log("");
}

// ================== МЕНЮ ВИБОРУ РЕЖИМУ ==================
async function tradingModeSelector() {
return new Promise((resolve) => {
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
console.log("\n╔════════════════════════════════════════╗");
console.log("║         ВИБІР РЕЖИМУ ТОРГІВЛІ         ║");
console.log("╠════════════════════════════════════════╣");
console.log("║  1 - Тестовий режим (paper trading)   ║");
console.log("║  2 - Реальна торгівля (API Binance)   ║");
console.log("║  3 - Тест + зберегти параметри        ║");
console.log("╚════════════════════════════════════════╝");
rl.question("Ваш вибір (1/2/3): ", async (answer) => {
if (answer === "2") {
CONFIG.trading.REAL_MODE = true;
console.log("✅ РЕАЛЬНИЙ РЕЖИМ УВІМКНЕНО");
await getAccountBalance();
if (account.balance <= 0) {
console.error("❌ Немає коштів на ф'ючерсному рахунку. Перемикаюсь у ТЕСТОВИЙ режим.");
CONFIG.trading.REAL_MODE = false;
account.balance = 1000;
}
} else if (answer === "3") {
CONFIG.trading.REAL_MODE = false;
console.log("🧪 ТЕСТОВИЙ РЕЖИМ. Через 1 годину параметри можна зберегти.");
setTimeout(() => {
rl.question("🔧 Застосувати поточні параметри до реальної торгівлі? (y/n): ", (save) => {
if (save.toLowerCase() === 'y') {
fs.writeFileSync('optimized_params.json', JSON.stringify(adaptiveState.get(), null, 2));
console.log("✅ Параметри збережено у optimized_params.json");
}
process.exit(0);
});
}, 3600000);
} else {
CONFIG.trading.REAL_MODE = false;
console.log("🧪 ТЕСТОВИЙ РЕЖИМ (paper trading)");
account.balance = 1000;
}
await selfCheck();
rl.close();
resolve();
});
});
}

// ================== WEBSOCKET ПІДКЛЮЧЕННЯ ==================
let ws = null;
function startWebSocket() {
if (ws) ws.close();
ws = new WebSocket(wss://fstream.binance.com/ws/${CONFIG.ws.SYMBOL}@kline_1m);
ws.on("open", () => {
reconnectAttempts = 0;
console.log("🔌 WebSocket підключено до Binance");
});
ws.on("message", async (msg) => {
try {
const raw = typeof msg === "string" ? msg : msg.toString();
const parsed = JSON.parse(raw);
if (!parsed?.k) return;
const price = parseFloat(parsed.k.c);
const volume = parseFloat(parsed.k.v);
if (isNaN(price) || isNaN(volume)) return;
await onTick(price, volume);
} catch (err) {
console.error("Помилка обробки повідомлення:", err.message);
}
});
ws.on("close", () => {
console.log("🔌 WebSocket закрито, перепідключення через 5с...");
setTimeout(startWebSocket, 5000);
});
ws.on("error", (err) => {
console.error("Помилка WebSocket:", err.message);
ws.close();
});
}

// ================== PRO SMART MODULE (FULL AUTO) ==================
(function() {
let lastMode = null;
let entryBlockedUntil = 0;
let lastSwitch = 0;

function getRangePercent() {
const prices = buffers.getPrices();
if (prices.length < 10) return 0;
const max = Math.max(...prices);
const min = Math.min(...prices);
const mean = avg(prices);
return mean === 0 ? 0 : ((max - min) / mean) * 100;
}

function detectMode(range) {
if (range < 0.5) return "COOLDOWN";
if (range < 1.5) return "MODE1";
if (range < 5) return "MODE2";
return "MODE3";
}

function applyMode(mode, range) {
if (mode === lastMode) return;
lastMode = mode;
lastSwitch = Date.now();
if (mode === "COOLDOWN") {
cooldownUntil = Date.now() + 15000;
console.log("🧊 QUIET MARKET → COOLDOWN");
return;
}
if (mode === "MODE1") {
adaptiveState.state.deviation = 0.0007;
adaptiveState.state.volatility = 0.0003;
adaptiveState.state.volume = 1.2;
CONFIG.risk.TAKE_PROFIT = 0.15;
CONFIG.risk.STOP_LOSS = 0.25;
}
if (mode === "MODE2") {
adaptiveState.state.deviation = 0.001;
adaptiveState.state.volatility = 0.0005;
adaptiveState.state.volume = 1.3;
CONFIG.risk.TAKE_PROFIT = 0.2;
CONFIG.risk.STOP_LOSS = 0.35;
}
if (mode === "MODE3") {
adaptiveState.state.deviation = 0.0015;
adaptiveState.state.volatility = 0.0008;
adaptiveState.state.volume = 1.5;
CONFIG.risk.TAKE_PROFIT = 0.3;
CONFIG.risk.STOP_LOSS = 0.5;
}
entryBlockedUntil = Date.now() + 5000;
console.log(⚙️ MODE → ${mode} | range=${range.toFixed(2)}%);
}

function autoAdapt(range) {
if (!adaptiveState?.state) return;
let factor = 1;
if (range > 3) factor = 1.2;
if (range > 5) factor = 1.4;
adaptiveState.state.deviation *= factor;
adaptiveState.state.volatility *= factor;
}

function preventBadEntry(price) {
const now = Date.now();
if (now < entryBlockedUntil) return true;
const prices = buffers.getPrices();
if (prices.length < 3) return false;
const p1 = prices.at(-1);
const p2 = prices.at(-2);
const move = Math.abs((p1 - p2) / p2) * 100;
if (move > 0.2) {
entryBlockedUntil = now + 3000;
return true;
}
return false;
}

function autoFix(price) {
if (!account.balance || account.balance <= 0) {
console.log("⛔ AUTOFIX: NO BALANCE");
return false;
}
if (CONFIG.risk.TAKE_PROFIT <= 0 || CONFIG.risk.STOP_LOSS <= 0) {
console.log("⛔ AUTOFIX: BAD TP/SL");
return false;
}
if (!price || price <= 0) {
console.log("⛔ AUTOFIX: BAD PRICE");
return false;
}
return true;
}

const originalOnTick = onTick;
onTick = async function(price, volume) {
const range = getRangePercent();
const mode = detectMode(range);
applyMode(mode, range);
autoAdapt(range);
if (!autoFix(price)) return;
if (preventBadEntry(price)) return;
return originalOnTick(price, volume);
};
console.log("🚀 PRO MODULE LOADED");
})();

// ================== SMART PRECISION ENGINE ==================
(function() {
let stopLossStreak = 0;
let entryDelayUntil = 0;

function getOrderBookImbalance() {
const vol = buffers.getVolumes();
if (vol.length < 5) return 0;
const last = vol.at(-1);
const avgVol = vol.slice(0, -1).reduce((a,b)=>a+b,0)/(vol.length-1);
return last / avgVol;
}

function predictMove() {
const prices = buffers.getPrices();
if (prices.length < 5) return 0;
const p1 = prices.at(-1);
const p2 = prices.at(-2);
const p3 = prices.at(-3);
const v1 = p1 - p2;
const v2 = p2 - p3;
return v1 - v2;
}

function getBetterEntry(price, side) {
const offset = CONFIG.entry.OFFSET_PERCENT / 100;
if (side === "long") return price * (1 - offset);
else return price * (1 + offset);
}

function smartEntryFilter(price, side) {
const imbalance = getOrderBookImbalance();
const prediction = predictMove();
if (side === "long" && imbalance < 0.9) return false;
if (side === "short" && imbalance > 1.1) return false;
if (Math.abs(prediction) > 0.0005) return false;
return true;
}

const originalCheckExit = checkExit;
checkExit = function(price) {
const result = originalCheckExit(price);
if (result === "SL") {
stopLossStreak++;
console.log(❌ SL STREAK: ${stopLossStreak});
if (stopLossStreak >= 2) {
cooldownUntil = Date.now() + 20000;
console.log("🧠 2x SL → HARD COOLDOWN");
stopLossStreak = 0;
}
}
if (result === "TP") stopLossStreak = 0;
return result;
};

const originalBuildSignal = buildSignal;
buildSignal = function(price) {
const signal = originalBuildSignal(price);
if (!signal) return null;
if (Date.now() < entryDelayUntil) return null;
if (!smartEntryFilter(price, signal.side)) return null;
entryDelayUntil = Date.now() + 1500;
signal.entryPrice = getBetterEntry(price, signal.side);
return signal;
};
console.log("🧠 SMART PRECISION ENGINE LOADED");
})();

// ================== LIGHTNING ENGINE ==================
(function() {
let lastPrice = null;
let lastTime = null;
const IMPULSE_THRESHOLD = 0.5;
const IMPULSE_TIME = 2000;
const EXIT_THRESHOLD = 0.5;

function detectImpulse(price) {
const now = Date.now();
if (!lastPrice || !lastTime) {
lastPrice = price;
lastTime = now;
return null;
}
const timeDiff = now - lastTime;
const move = ((price - lastPrice) / lastPrice) * 100;
lastPrice = price;
lastTime = now;
if (timeDiff > IMPULSE_TIME) return null;
if (Math.abs(move) >= IMPULSE_THRESHOLD) {
return { direction: move > 0 ? "UP" : "DOWN", strength: Math.abs(move), speed: timeDiff };
}
return null;
}

function lightningExit(price) {
if (state.status !== "IN_TRADE") return false;
const move = state.side === "long"
? ((price - state.entry) / state.entry) * 100
: ((state.entry - price) / state.entry) * 100;
if (move <= -EXIT_THRESHOLD) {
console.log("⚡ LIGHTNING EXIT TRIGGERED");
state.status = "IDLE";
cooldownUntil = Date.now() + 10000;
return true;
}
return false;
}

function lightningEntry(impulse, price) {
if (!impulse) return null;
if (cooldownUntil > Date.now()) return null;
if (impulse.speed < 200) return null;
if (impulse.direction === "UP") return { side: "long", reason: "lightning" };
if (impulse.direction === "DOWN") return { side: "short", reason: "lightning" };
return null;
}

const originalOnTick = onTick;
onTick = async function(price, volume) {
if (lightningExit(price)) return;
const impulse = detectImpulse(price);
const entry = lightningEntry(impulse, price);
if (entry && state.status === "IDLE") {
console.log(⚡ LIGHTNING ENTRY ${entry.side});
const qty = calcPositionSize(price);
if (qty > 0) {
await placeOrder(entry.side, qty, price);
state.status = "IN_TRADE";
state.entry = price;
state.side = entry.side;
}
return;
}
return originalOnTick(price, volume);
};
console.log("⚡ LIGHTNING ENGINE LOADED");
})();

// ================== AI GUARD + AUTOFIX ==================
(function() {
let blockedCount = 0;
let allowedCount = 0;

function getRR(price, side) {
const tp = CONFIG.risk.TAKE_PROFIT / 100;
const sl = CONFIG.risk.STOP_LOSS / 100;
if (sl === 0) return 0;
return tp / sl;
}

function microTrend() {
const prices = buffers.getPrices();
if (prices.length < 5) return 0;
const p1 = prices.at(-1);
const p5 = prices.at(-5);
return (p1 - p5) / p5;
}

function isBadAITrade(signal, price) {
if (!signal) return true;
const rr = getRR(price, signal.side);
if (rr < 0.5) return true;
const trend = microTrend();
if (signal.side === "long" && trend < 0) return true;
if (signal.side === "short" && trend > 0) return true;
if (typeof stopLossStreak !== "undefined" && stopLossStreak >= 2) return true;
return false;
}

function autoFixGuard(signal, price) {
if (!account.balance || account.balance <= 0) {
console.log("⛔ AUTOFIX BLOCK: NO BALANCE");
return false;
}
if (!price || price <= 0) {
console.log("⛔ AUTOFIX BLOCK: BAD PRICE");
return false;
}
if (!signal) return false;
if (isBadAITrade(signal, price)) {
blockedCount++;
console.log(🧠 AI BLOCKED BAD TRADE (${blockedCount}));
return false;
}
allowedCount++;
return true;
}

const originalBuildSignal = buildSignal;
buildSignal = function(price) {
const signal = originalBuildSignal(price);
if (!signal) return null;
if (!autoFixGuard(signal, price)) return null;
return signal;
};
console.log("🧠 AI GUARD LOADED");
})();

// ================== LIQUIDITY TRAP ==================
(function() {
function isFakeBreakout() {
const prices = buffers.getPrices();
if (prices.length < 6) return false;
const p1 = prices.at(-1);
const p2 = prices.at(-2);
const p5 = prices.at(-5);
const moveUp = (p2 - p5) / p5;
const revert = (p1 - p2) / p2;
if (moveUp > 0.003 && revert < -0.002) return true;
if (moveUp < -0.003 && revert > 0.002) return true;
return false;
}

const originalBuildSignal = buildSignal;
buildSignal = function(price) {
if (isFakeBreakout()) {
console.log("🪤 TRAP DETECTED → BLOCK");
return null;
}
return originalBuildSignal(price);
};
console.log("🪤 TRAP MODULE LOADED");
})();

// ================== GLOBAL FIXING ENGINE ==================
(function() {
let lastSide = null;
let peakPrice = null;

function shouldBlockSignal(signal, price) {
if (!signal) return true;
if (lastSide === signal.side) {
const trend = buffers.getPrices().at(-1) - buffers.getPrices().at(-5);
if (Math.abs(trend) < 0.001) {
console.log("⚖️ BLOCK SAME SIDE");
return true;
}
}
return false;
}

const originalBuildSignal = buildSignal;
buildSignal = function(price) {
const signal = originalBuildSignal(price);
if (!signal) return null;
if (shouldBlockSignal(signal, price)) return null;
lastSide = signal.side;
return signal;
};

const originalCheckExit = checkExit;
checkExit = function(price) {
if (state.status === "IN_TRADE") {
if (!peakPrice) peakPrice = price;
if (state.side === "long") {
if (price > peakPrice) peakPrice = price;
const drop = (price - peakPrice) / peakPrice;
if (drop < -0.002) {
console.log("💰 TRAILING EXIT LONG");
peakPrice = null;
return "TP";
}
}
if (state.side === "short") {
if (price < peakPrice) peakPrice = price;
const bounce = (peakPrice - price) / peakPrice;
if (bounce < -0.002) {
console.log("💰 TRAILING EXIT SHORT");
peakPrice = null;
return "TP";
}
}
}
const result = originalCheckExit(price);
if (result) peakPrice = null;
return result;
};
console.log("🧠 GLOBAL FIXING LOADED");
})();

// ================== SYSTEM RUNTIME AUTOFIX (PM2) ==================
const BOT_NAME = "pro-bot";
const START_CMD = "pm2 start bot.js --name pro-bot -f";

function runCmd(cmd) {
return new Promise((resolve) => {
exec(cmd, (err, stdout, stderr) => {
if (err) {
console.log(❌ ${cmd} ERROR);
return resolve(false);
}
resolve(stdout);
});
});
}

async function fixNpm() {
if (!fs.existsSync("package.json")) {
console.log("⚠️ package.json not found");
return;
}
console.log("📦 Checking NPM...");
await runCmd("npm install");
console.log("✅ NPM OK");
}

async function isBotRunning() {
const list = await runCmd("pm2 list");
return list && list.includes(BOT_NAME);
}

async function startBot() {
console.log("🚀 Starting bot...");
await runCmd(START_CMD);
}

async function restartBot() {
console.log("🔄 Restarting bot...");
await runCmd(pm2 restart ${BOT_NAME});
}

async function watchdog() {
const running = await isBotRunning();
if (!running) {
console.log("⚠️ BOT DOWN → FIX");
await startBot();
} else {
console.log("✅ BOT RUNNING");
}
}

async function loop() {
console.log("🧠 SYSTEM FIX STARTED");
await fixNpm();
setInterval(async () => {
try {
await watchdog();
} catch (e) {
console.log("❌ WATCHDOG ERROR");
}
}, 10000);
}

// ================== STUBS FOR MISSING GLOBAL FUNCTIONS ==================
global.getOrderBook = function() {
return { bids: [[0,0]], asks: [[0,0]] };
};
global.getTrend = function(price) {
const prices = buffers.getPrices();
if (prices.length < 10) return "SIDEWAYS";
const short = avg(prices.slice(-5));
const long = avg(prices.slice(-10));
if (short > long * 1.001) return "UP";
if (short < long * 0.999) return "DOWN";
return "SIDEWAYS";
};
global.getMomentum = function(price) {
const prices = buffers.getPrices();
if (prices.length < 3) return 0;
return (prices.at(-1) - prices.at(-3)) / prices.at(-3);
};
global.getATR = function(price) {
const prices = buffers.getPrices();
if (prices.length < 14) return price * 0.01;
let tr = 0;
for (let i = 1; i < 14; i++) {
tr += Math.abs(prices.at(-i) - prices.at(-i-1));
}
return tr / 14;
};
