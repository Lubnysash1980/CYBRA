// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 53
// part: 2
// original_header: console.log("🎛️ MODULE 53: AI Guard Orchestrator - Structured Decision Cycle ACTIVE");
// original_line_start: 4829
// original_line_end: 5131
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🎛️ MODULE 53: AI Guard Orchestrator - Structured Decision Cycle ACTIVE");

// ========== 1. КОНФІГУРАЦІЯ ОРКЕСТРАТОРА ==========
const ORCH_CFG = {
// Часи опитування
POLL_INTERVAL_MS: 3000,           // кожні 3 секунди аналізуємо можливість входу
MAX_WAIT_FOR_SIGNAL_MS: 30000,    // 30 секунд очікування сильного сигналу
// Ваги доказів (сума має бути 1.0)
EVIDENCE_WEIGHTS: {
deviation: 0.35,     // відхилення ціни від середньої
volumeSpike: 0.25,   // сплеск об'єму
volatility: 0.15,    // волатильність
candlePattern: 0.10, // патерн свічки
trend: 0.10,         // мікротренд
liquidity: 0.05,     // ліквідність
},
// Пороги для прийняття рішення
ENTRY_THRESHOLD: 0.65,            // 65% зважених доказів для входу
EXIT_PROFIT_THRESHOLD: 0.5,       // 0.5% прибутку для виходу (або використовуємо TP)
MAX_LOSS_PERCENT: 0.3,            // максимальний збиток 0.3% перед виходом
// Режими торгів
MODES: ['conservative', 'moderate', 'aggressive'],
DEFAULT_MODE: 'moderate',
};

// Поточний стан оркестратора
let orchestrationState = {
mode: ORCH_CFG.DEFAULT_MODE,
lastPollTime: 0,
evidenceHistory: [],
pendingDecision: null,
lastEntryTime: 0,
profitTarget: CONFIG.risk.TAKE_PROFIT,
lossLimit: CONFIG.risk.STOP_LOSS,
consecutiveLosses: 0,
adaptiveFactor: 1.0,
};

// ========== 2. ЗБІР ДОКАЗІВ (ЗВАЖЕНІ ФАКТОРИ) ==========
function collectEvidence(price) {
const dev = Math.abs(deviation(price));
const spike = volumeSpike();
const vol = volatility();
const lastCandle = global.getLastCandleAnalysis ? global.getLastCandleAnalysis() : null;
const trend = (() => {
const prices = buffers.getPrices();
if (prices.length < 10) return 0;
const short = avg(prices.slice(-5));
const long = avg(prices.slice(-10));
return (short - long) / long;
})();
const liquidity = (() => {
// Симуляція ліквідності на основі об'єму
const volumes = buffers.getVolumes();
if (volumes.length < 10) return 0.5;
const avgVol = avg(volumes);
const lastVol = volumes[volumes.length - 1];
return Math.min(1, lastVol / (avgVol + 0.001));
})();

// Нормалізуємо значення до діапазону [0..1]    
const normDev = Math.min(1, dev / 0.01); // 1% відхилення = 1.0    
const normSpike = Math.min(1, spike / 3); // 3x сплеск = 1.0    
const normVol = Math.min(1, vol / 0.005); // 0.5% волатильність = 1.0    
const normCandle = lastCandle ? (lastCandle.isReversal ? 0.8 : (lastCandle.type.includes('BULLISH') ? 0.6 : 0.3)) : 0.4;    
const normTrend = Math.min(1, Math.abs(trend) / 0.002); // 0.2% тренд = 1.0    
const normLiquidity = liquidity;    

const evidence = {    
  deviation: normDev,    
  volumeSpike: normSpike,    
  volatility: normVol,    
  candlePattern: normCandle,    
  trend: normTrend,    
  liquidity: normLiquidity,    
};    
return evidence;

}

function computeWeightedScore(evidence) {
let score = 0;
for (const [key, weight] of Object.entries(ORCH_CFG.EVIDENCE_WEIGHTS)) {
score += (evidence[key] || 0) * weight;
}
return Math.min(1, Math.max(0, score));
}

// ========== 3. ТИМЧАСОВЕ ОПИТУВАННЯ ІМІТОВАНОЇ МОДЕЛІ ==========
// Штучна нейронна оцінка (простий фільтр Калмана подібний)
let predictedPrice = null;
let lastPrice = null;
let priceVelocity = 0;
function updatePrediction(currentPrice) {
if (lastPrice === null) {
lastPrice = currentPrice;
predictedPrice = currentPrice;
return;
}
const dt = 1; // умовно 1 секунда
const alpha = 0.3; // коефіцієнт згладжування
priceVelocity = priceVelocity * 0.8 + ((currentPrice - lastPrice) / dt) * 0.2;
predictedPrice = currentPrice + priceVelocity * dt;
lastPrice = currentPrice;
}
function getModelSignal(price) {
updatePrediction(price);
const predictedMove = (predictedPrice - price) / price;
if (Math.abs(predictedMove) < 0.0005) return { side: null, confidence: 0 };
const side = predictedMove > 0 ? 'long' : 'short';
const confidence = Math.min(0.9, Math.abs(predictedMove) * 100);
return { side, confidence };
}

// ========== 4. AI GUARD ПІДТВЕРДЖЕННЯ (зважені докази + модель) ==========
async function getAIGuardApproval(price, side) {
const evidence = collectEvidence(price);
const weightedScore = computeWeightedScore(evidence);
const modelSignal = getModelSignal(price);
let modelAgree = (modelSignal.side === side) ? modelSignal.confidence : (1 - modelSignal.confidence);
const totalConfidence = weightedScore * 0.6 + modelAgree * 0.4;
const approved = totalConfidence >= ORCH_CFG.ENTRY_THRESHOLD;
console.log(🧠 AI GUARD: side=${side}, score=${weightedScore.toFixed(2)}, model=${modelAgree.toFixed(2)}, total=${totalConfidence.toFixed(2)} → ${approved ? 'APPROVED' : 'REJECTED'});
return { approved, confidence: totalConfidence, evidence };
}

// ========== 5. ПЕРЕМИКАННЯ РЕЖИМАМИ ТОРГІВЛІ ==========
function adjustTradingMode(performance) {
// performance: winRate (0..1), avgProfit, consecutiveLosses
let newMode = ORCH_CFG.DEFAULT_MODE;
if (performance.winRate > 0.6 && performance.avgProfit > 0.002) {
newMode = 'aggressive';
ORCH_CFG.EVIDENCE_WEIGHTS.deviation = 0.4;
ORCH_CFG.EVIDENCE_WEIGHTS.volumeSpike = 0.3;
ORCH_CFG.ENTRY_THRESHOLD = 0.55;
} else if (performance.winRate < 0.4 || performance.consecutiveLosses > 2) {
newMode = 'conservative';
ORCH_CFG.EVIDENCE_WEIGHTS.deviation = 0.3;
ORCH_CFG.EVIDENCE_WEIGHTS.volumeSpike = 0.2;
ORCH_CFG.ENTRY_THRESHOLD = 0.75;
} else {
newMode = 'moderate';
ORCH_CFG.EVIDENCE_WEIGHTS.deviation = 0.35;
ORCH_CFG.EVIDENCE_WEIGHTS.volumeSpike = 0.25;
ORCH_CFG.ENTRY_THRESHOLD = 0.65;
}
if (newMode !== orchestrationState.mode) {
console.log(🔄 Mode switch: ${orchestrationState.mode} → ${newMode});
orchestrationState.mode = newMode;
}
// Коригування коефіцієнта заробітку (adaptiveFactor)
if (performance.winRate > 0.55) {
orchestrationState.adaptiveFactor = Math.min(1.5, orchestrationState.adaptiveFactor + 0.05);
} else if (performance.winRate < 0.45) {
orchestrationState.adaptiveFactor = Math.max(0.7, orchestrationState.adaptiveFactor - 0.05);
}
// Оновлюємо TP/SL відповідно до режиму та адаптивного фактора
if (orchestrationState.mode === 'aggressive') {
CONFIG.risk.TAKE_PROFIT = Math.min(0.5, 0.3 * orchestrationState.adaptiveFactor);
CONFIG.risk.STOP_LOSS = Math.min(0.8, 0.4 * orchestrationState.adaptiveFactor);
} else if (orchestrationState.mode === 'conservative') {
CONFIG.risk.TAKE_PROFIT = Math.max(0.1, 0.15 * orchestrationState.adaptiveFactor);
CONFIG.risk.STOP_LOSS = Math.max(0.2, 0.25 * orchestrationState.adaptiveFactor);
} else {
CONFIG.risk.TAKE_PROFIT = Math.min(0.4, 0.2 * orchestrationState.adaptiveFactor);
CONFIG.risk.STOP_LOSS = Math.min(0.6, 0.35 * orchestrationState.adaptiveFactor);
}
console.log(📊 Mode: ${orchestrationState.mode}, TP=${CONFIG.risk.TAKE_PROFIT.toFixed(2)}%, SL=${CONFIG.risk.STOP_LOSS.toFixed(2)}%, factor=${orchestrationState.adaptiveFactor.toFixed(2)});
}

// ========== 6. ПРИБУТКОВЕ ЗАКРИТТЯ ПОЗИЦІЇ (КРАЩЕ, НІЖ ЗБИТОК) ==========
function shouldCloseProfitable(price, entry, side) {
if (state.status !== 'IN_TRADE') return false;
let profitPercent = (side === 'long') ? (price - entry) / entry : (entry - price) / entry;
profitPercent *= 100;
if (profitPercent >= ORCH_CFG.EXIT_PROFIT_THRESHOLD) {
console.log(💰 PROFIT EXIT: ${profitPercent.toFixed(2)}%);
return true;
}
// Якщо збиток перевищує ліміт – виходимо, але це не прибутково, тому намагаємося уникати
if (-profitPercent > ORCH_CFG.MAX_LOSS_PERCENT) {
console.log(⚠️ LOSS LIMIT: ${(-profitPercent).toFixed(2)}%);
return true;
}
return false;
}

// Перевизначаємо checkExit, щоб додати логіку прибуткового закриття
const originalCheckExit53 = checkExit;
checkExit = function(price) {
if (state.status === 'IN_TRADE') {
if (shouldCloseProfitable(price, state.entry, state.side)) {
// Примусове закриття з прибутком
const pnl = state.side === 'long' ? (price - state.entry) : (state.entry - price);
const pnlPercent = (pnl / state.entry) * 100;
account.balance += account.balance * (pnlPercent / 100);
if (pnlPercent < 0) account.dailyLoss += Math.abs(pnlPercent);
console.log(💰 Orchestrator closed: PnL ${pnlPercent.toFixed(2)}%);
state.status = "IDLE";
state.entry = null;
state.side = null;
return 'ORCHESTRATOR_EXIT';
}
}
return originalCheckExit53(price);
};

// ========== 7. ГОЛОВНИЙ ЦИКЛ ОРКЕСТРАТОРА ==========
async function orchestrationCycle() {
const now = Date.now();
if (now - orchestrationState.lastPollTime < ORCH_CFG.POLL_INTERVAL_MS) return;
orchestrationState.lastPollTime = now;

if (state.status !== 'IDLE') return;    
if (cooldownUntil > now) return;    

// Отримуємо правдиву ціну (з модуля 50-52)    
const price = global.getTruthfulPrice ? global.getTruthfulPrice() : buffers.getPrices().slice(-1)[0];    
if (!price) return;    

// 1. Збираємо докази    
const evidence = collectEvidence(price);    
const weightedScore = computeWeightedScore(evidence);    
    
// 2. Отримуємо сигнал від імітованої моделі    
const modelSignal = getModelSignal(price);    
let proposedSide = modelSignal.side;    
if (!proposedSide) {    
  // Якщо модель не дає напрямку, використовуємо відхилення ціни    
  const dev = deviation(price);    
  if (Math.abs(dev) > 0.0005) proposedSide = dev > 0 ? 'short' : 'long';    
  else return;    
}    

// 3. AI Guard підтвердження    
const { approved, confidence, evidence: ev } = await getAIGuardApproval(price, proposedSide);    
if (!approved) return;    

// 4. Перевірка, чи не минуло занадто багато часу без сигналу (опціонально)    
// 5. Вхід    
const qty = calcPositionSize(price);    
if (qty <= 0) return;    
const order = await placeOrder(proposedSide, qty, price);    
if (order) {    
  state.status = "IN_TRADE";    
  state.entry = price;    
  state.side = proposedSide;    
  orchestrationState.lastEntryTime = now;    
  orchestrationState.consecutiveLosses = 0;    
  console.log(`🎯 ORCHESTRATOR ENTRY: ${proposedSide} @ ${price}, confidence=${confidence.toFixed(2)}`);    
}

}

// ========== 8. ЗБІР СТАТИСТИКИ ДЛЯ АДАПТАЦІЇ РЕЖИМУ ==========
let tradeResults = []; // зберігає останні 20 угод
function updateTradeStats(result, pnlPercent) {
tradeResults.push({ result, pnlPercent, timestamp: Date.now() });
if (tradeResults.length > 20) tradeResults.shift();
const wins = tradeResults.filter(t => t.result === 'win').length;
const losses = tradeResults.filter(t => t.result === 'loss').length;
const winRate = wins / (wins + losses || 1);
const avgProfit = tradeResults.filter(t => t.pnlPercent > 0).reduce((s, t) => s + t.pnlPercent, 0) / (wins || 1);
const consecutiveLosses = (() => {
let cnt = 0;
for (let i = tradeResults.length - 1; i >= 0; i--) {
if (tradeResults[i].result === 'loss') cnt++;
else break;
}
return cnt;
})();
orchestrationState.consecutiveLosses = consecutiveLosses;
adjustTradingMode({ winRate, avgProfit, consecutiveLosses });
}

// Перехоплюємо закриття позиції (TP/SL або Orchestrator exit)
const originalExitHandler = checkExit;
checkExit = function(price) {
const exitResult = originalExitHandler(price);
if (exitResult && state.status === 'IDLE') {
// Після виходу визначаємо, чи це був прибуток чи збиток
// Нам потрібно знати PnL – можна зберегти в глобальній змінній останнього PnL
const lastPnL = (() => {
// Симуляція: якщо вийшли по TP – прибуток, по SL – збиток
if (exitResult === 'TP') return 'win';
if (exitResult === 'SL') return 'loss';
if (exitResult === 'ORCHESTRATOR_EXIT') return 'win';
return 'unknown';
})();
if (lastPnL !== 'unknown') {
// pnlPercent приблизно
const pnlPercent = (lastPnL === 'win') ? CONFIG.risk.TAKE_PROFIT : -CONFIG.risk.STOP_LOSS;
updateTradeStats(lastPnL, pnlPercent);
}
}
return exitResult;
};

// ========== 9. ЗАПУСК ЦИКЛУ ==========
setInterval(() => orchestrationCycle(), ORCH_CFG.POLL_INTERVAL_MS);
console.log("✅ Orchestrator active: structured entry, mode switching, profitable exit.");
})();
