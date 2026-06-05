// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 41
// part: 3
// original_header: console.log("🎮 MODULE 41: Simulation Engine ACTIVE (sandbox mode, no real trading)");
// original_line_start: 3949
// original_line_end: 4229
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🎮 MODULE 41: Simulation Engine ACTIVE (sandbox mode, no real trading)");

// ================== 1. КОНФІГУРАЦІЯ СИМУЛЯЦІЇ ==================
const SIM_CFG = {
INITIAL_BALANCE: parseFloat(process.env.SIM_INITIAL_BALANCE || "10000"),
START_PRICE: parseFloat(process.env.SIM_START_PRICE || "0.15"),
VOLATILITY: parseFloat(process.env.SIM_VOLATILITY || "0.02"),      // 2% середньодобова волатильність
TREND_STRENGTH: parseFloat(process.env.SIM_TREND || "0.0001"),     // слабкий тренд
SPREAD: parseFloat(process.env.SIM_SPREAD || "0.001"),             // 0.1% спред
SLIPPAGE_FACTOR: parseFloat(process.env.SIM_SLIPPAGE || "0.0005"), // прослизання 0.05%
FEE_MAKER: parseFloat(process.env.SIM_FEE_MAKER || "0.0002"),      // 0.02%
FEE_TAKER: parseFloat(process.env.SIM_FEE_TAKER || "0.0004"),       // 0.04%
TICK_INTERVAL_MS: parseInt(process.env.SIM_TICK_INTERVAL || "1000"), // 1 секунда = 1 свічка (можна прискорити)
ENABLE_RANDOM_SPIKES: process.env.SIM_SPIKES !== 'false',
SPIKE_PROBABILITY: 0.01,      // 1% шанс сплеску на тік
SPIKE_MAGNITUDE: 0.05,        // 5% стрибок
MAX_SIMULATION_STEPS: parseInt(process.env.SIM_MAX_STEPS || "1000000"),
LOG_EVERY: parseInt(process.env.SIM_LOG_EVERY || "100"),           // логувати кожні N тіків
};

// Стан симуляції
let simState = {
price: SIM_CFG.START_PRICE,
balance: SIM_CFG.INITIAL_BALANCE,
positions: [],        // { side, entryPrice, quantity, timestamp }
trades: [],           // історія угод
step: 0,
startTime: Date.now(),
paused: false,
volume: 0,
lastTickPrice: SIM_CFG.START_PRICE,
};

// Глобальний прапорець для інших модулів (щоб знали, що в симуляції)
global.SIMULATION_ACTIVE = true;

// ================== 2. ГЕНЕРАЦІЯ ЦІНИ (випадкове блукання + тренд + сплески) ==================
function generateNextPrice() {
let lastPrice = simState.price;
// Випадкова зміна (нормальний розподіл)
let change = (Math.random() - 0.5) * 2 * SIM_CFG.VOLATILITY;
// Додаємо тренд
change += SIM_CFG.TREND_STRENGTH;
let newPrice = lastPrice * (1 + change);
// Обмежуємо від надто великих стрибків
const maxChangePercent = 0.10; // 10% за тік
if (Math.abs(newPrice - lastPrice) / lastPrice > maxChangePercent) {
newPrice = lastPrice * (1 + (newPrice > lastPrice ? maxChangePercent : -maxChangePercent));
}
// Випадкові сплески
if (SIM_CFG.ENABLE_RANDOM_SPIKES && Math.random() < SIM_CFG.SPIKE_PROBABILITY) {
const spikeDir = Math.random() > 0.5 ? 1 : -1;
newPrice = newPrice * (1 + spikeDir * SIM_CFG.SPIKE_MAGNITUDE);
console.log(⚡ SIM SPIKE: ${spikeDir > 0 ? 'UP' : 'DOWN'} to ${newPrice.toFixed(8)});
}
// Мінімальна ціна 1e-8
if (newPrice < 1e-8) newPrice = 1e-8;
simState.price = newPrice;
// Імітуємо об'єм (випадковий)
simState.volume = Math.random() * 1000000 + 10000;
return newPrice;
}

// ================== 3. ВИКОНАННЯ ОРДЕРА В СИМУЛЯЦІЇ ==================
async function simulatePlaceOrder(side, quantity, price) {
// Перевірка достатності коштів для маржі (5% від вартості)
const requiredMargin = price * quantity * 0.05;
if (simState.balance < requiredMargin) {
console.log(❌ SIM: Insufficient margin. Balance: ${simState.balance.toFixed(2)}, required: ${requiredMargin.toFixed(2)});
return null;
}

// Симуляція спреду та прослизання    
const spreadCost = price * SIM_CFG.SPREAD;    
const slippage = price * SIM_CFG.SLIPPAGE_FACTOR * (Math.random() - 0.5);    
let executionPrice = side === 'long' ? price + spreadCost/2 : price - spreadCost/2;    
executionPrice += slippage;    
executionPrice = Math.max(executionPrice, 1e-8);    

// Комісія (тейкер)    
const fee = executionPrice * quantity * SIM_CFG.FEE_TAKER;    
const totalCost = executionPrice * quantity + fee;    
if (side === 'long' && simState.balance < totalCost) {    
  console.log(`❌ SIM: Insufficient balance for long. Balance: ${simState.balance.toFixed(2)}, need: ${totalCost.toFixed(2)}`);    
  return null;    
}    

// Виконуємо ордер    
if (side === 'long') {    
  simState.balance -= totalCost;    
  simState.positions.push({    
    side: 'long',    
    entryPrice: executionPrice,    
    quantity: quantity,    
    timestamp: Date.now(),    
    fee: fee    
  });    
} else { // short    
  // Для шорту потрібна маржа, баланс блокується    
  simState.balance -= requiredMargin;    
  simState.positions.push({    
    side: 'short',    
    entryPrice: executionPrice,    
    quantity: quantity,    
    timestamp: Date.now(),    
    fee: fee    
  });    
}    

console.log(`✅ SIM ORDER: ${side.toUpperCase()} ${quantity} @ ${executionPrice.toFixed(8)} (fee: ${fee.toFixed(4)})`);    
console.log(`   Balance after: ${simState.balance.toFixed(2)}`);    
return { price: executionPrice, quantity, fee };

}

// Функція для закриття позицій (викликається при TP/SL або вручну)
function closePosition(position, currentPrice, reason = 'MANUAL') {
const { side, entryPrice, quantity, fee: entryFee } = position;
let pnl = 0;
let exitFee = 0;
if (side === 'long') {
pnl = (currentPrice - entryPrice) * quantity;
exitFee = currentPrice * quantity * SIM_CFG.FEE_TAKER;
simState.balance += currentPrice * quantity - exitFee;
} else { // short
pnl = (entryPrice - currentPrice) * quantity;
exitFee = currentPrice * quantity * SIM_CFG.FEE_TAKER;
simState.balance += (entryPrice * quantity) - (currentPrice * quantity) - exitFee;
}
const totalPnL = pnl - entryFee - exitFee;
console.log(💰 SIM CLOSE ${side.toUpperCase()} (${reason}): PnL = ${totalPnL.toFixed(4)} (${((totalPnL/(entryPrice*quantity))*100).toFixed(2)}%));
simState.trades.push({
side, entryPrice, exitPrice: currentPrice, quantity, pnl: totalPnL,
timestamp: Date.now(), reason
});
return totalPnL;
}

// Перевірка TP/SL для всіх відкритих позицій
function checkSimulatedExit(price) {
let closedAny = false;
for (let i = 0; i < simState.positions.length; i++) {
const pos = simState.positions[i];
const tpPercent = CONFIG.risk.TAKE_PROFIT / 100;
const slPercent = CONFIG.risk.STOP_LOSS / 100;
let shouldClose = false;
let reason = '';
if (pos.side === 'long') {
if (price >= pos.entryPrice * (1 + tpPercent)) { shouldClose = true; reason = 'TP'; }
if (price <= pos.entryPrice * (1 - slPercent)) { shouldClose = true; reason = 'SL'; }
} else {
if (price <= pos.entryPrice * (1 - tpPercent)) { shouldClose = true; reason = 'TP'; }
if (price >= pos.entryPrice * (1 + slPercent)) { shouldClose = true; reason = 'SL'; }
}
if (shouldClose) {
closePosition(pos, price, reason);
simState.positions.splice(i, 1);
i--;
closedAny = true;
}
}
return closedAny;
}

// ================== 4. ПІДМІНА ГЛОБАЛЬНИХ ФУНКЦІЙ ДЛЯ СИМУЛЯЦІЇ ==================
// Зберігаємо оригінали
const originalPlaceOrder = global.placeOrder;
const originalGetAccountBalance = global.getAccountBalance;
const originalCalcPositionSize = global.calcPositionSize;

// Підміняємо placeOrder
global.placeOrder = async function(side, quantity, price) {
if (!global.SIMULATION_ACTIVE) return originalPlaceOrder(side, quantity, price);
return simulatePlaceOrder(side, quantity, price);
};

// Підміняємо getAccountBalance (для симуляції балансу)
global.getAccountBalance = async function() {
if (!global.SIMULATION_ACTIVE) return originalGetAccountBalance();
console.log(💰 SIM Balance: ${simState.balance.toFixed(2)} USDT);
return simState.balance;
};

// Підміняємо calcPositionSize (можна використовувати оригінальний, але з симульованим балансом)
global.calcPositionSize = function(price) {
if (!global.SIMULATION_ACTIVE) return originalCalcPositionSize(price);
// Простий розрахунок для симуляції: 2% ризику від балансу
const riskAmount = simState.balance * (CONFIG.risk.MAX_RISK_PER_TRADE / 100);
const stopLossPercent = CONFIG.risk.STOP_LOSS / 100;
let qty = riskAmount / (price * stopLossPercent);
qty = Math.floor(qty * 1000) / 1000;
return Math.max(1, qty);
};

// Підміняємо onTick, щоб генерувати ціни та перевіряти вихід
const originalOnTick = onTick;
onTick = async function(price, volume) {
if (!global.SIMULATION_ACTIVE) return originalOnTick(price, volume);
// У симуляції ігноруємо вхідну ціну, генеруємо свою
const simPrice = generateNextPrice();
simState.step++;
if (simState.step % SIM_CFG.LOG_EVERY === 0) {
console.log(🎲 SIM step ${simState.step}: price=${simPrice.toFixed(8)}, balance=${simState.balance.toFixed(2)});
}
// Перевіряємо вихід по TP/SL
const closed = checkSimulatedExit(simPrice);
// Викликаємо оригінальний onTick зі згенерованою ціною для сигналів
await originalOnTick(simPrice, simState.volume);
// Якщо після оригінального onTick з'явилася позиція в реальному state, але не в simState.positions – синхронізуємо
if (state.status === 'IN_TRADE' && !simState.positions.some(p => p.side === state.side && Math.abs(p.entryPrice - state.entry) < 1e-8)) {
// Це означає, що оригінальний бот відкрив позицію – додаємо в симуляцію
const qty = calcPositionSize(simPrice);
await simulatePlaceOrder(state.side, qty, simPrice);
}
// Обмеження кількості кроків
if (simState.step >= SIM_CFG.MAX_SIMULATION_STEPS) {
console.log("🏁 Simulation reached max steps. Stopping.");
process.exit(0);
}
};

// ================== 5. ІНТЕГРАЦІЯ З МОДУЛЕМ 33 (AI воркери) ==================
// Додаємо можливість тренувати AI на симуляційних даних
global.runSimulationTraining = async (steps = 1000) => {
console.log(🧠 Starting simulation training for ${steps} steps...);
const startBalance = simState.balance;
for (let i = 0; i < steps; i++) {
await onTick(simState.price, simState.volume);
// Штучна затримка для емуляції реального часу (можна вимкнути)
await new Promise(r => setTimeout(r, SIM_CFG.TICK_INTERVAL_MS));
}
const endBalance = simState.balance;
const profit = endBalance - startBalance;
console.log(🏁 Training completed. Profit: ${profit.toFixed(2)} USDT (${((profit/startBalance)*100).toFixed(2)}%));
return { profit, finalBalance: endBalance, trades: simState.trades.length };
};

// Додаємо функцію скидання симуляції
global.resetSimulation = () => {
simState = {
price: SIM_CFG.START_PRICE,
balance: SIM_CFG.INITIAL_BALANCE,
positions: [],
trades: [],
step: 0,
startTime: Date.now(),
paused: false,
volume: 0,
lastTickPrice: SIM_CFG.START_PRICE,
};
console.log("🔄 Simulation reset.");
};

// Функція для отримання звіту
global.getSimulationReport = () => {
const totalPnL = simState.trades.reduce((sum, t) => sum + t.pnl, 0);
const winTrades = simState.trades.filter(t => t.pnl > 0).length;
const lossTrades = simState.trades.filter(t => t.pnl < 0).length;
const winRate = simState.trades.length ? (winTrades / simState.trades.length) * 100 : 0;
return {
steps: simState.step,
balance: simState.balance,
totalPnL,
tradesCount: simState.trades.length,
winRate: winRate.toFixed(2) + '%',
openPositions: simState.positions.length,
currentPrice: simState.price,
};
};

// Автоматичний старт симуляції, якщо встановлено AUTO_SIM_START=true
if (process.env.AUTO_SIM_START === 'true') {
setTimeout(() => {
console.log("🚀 Auto-starting simulation...");
global.runSimulationTraining(parseInt(process.env.SIM_STEPS || "500"));
}, 3000);
}

console.log("✅ Simulation Engine ready. Use SIMULATION_MODE=true to activate.");
})();
