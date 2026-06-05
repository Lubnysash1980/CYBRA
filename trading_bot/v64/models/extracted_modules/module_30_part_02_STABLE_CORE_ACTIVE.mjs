// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 30
// part: 2
// original_header: console.log("🛡 MODULE 30: STABLE CORE ACTIVE");
// original_line_start: 1786
// original_line_end: 1903
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🛡 MODULE 30: STABLE CORE ACTIVE");

let lastGoodPrice = null;
let stablePrices = [];

const cfg = {
maxJumpPercent: 3,     // макс допустимий стрибок
maxHistory: 50,
maxVolatility: 5,      // %
minVolatility: 0.02    // %
};

// ================= NORMALIZE PRICE =================
function normalizePrice(price) {
if (!price || price <= 0) return null;

if (!lastGoodPrice) {    
  lastGoodPrice = price;    
  return price;    
}    

const change = Math.abs((price - lastGoodPrice) / lastGoodPrice) * 100;    

// ❌ відсікаємо дикі стрибки    
if (change > cfg.maxJumpPercent) {    
  console.log("🚫 FILTER SPIKE:", price);    
  return null;    
}    

lastGoodPrice = price;    
return price;

}

// ================= STABLE BUFFER =================
function pushStable(price) {
stablePrices.push(price);
if (stablePrices.length > cfg.maxHistory) {
stablePrices.shift();
}
}

function getStableVolatility() {
if (stablePrices.length < 10) return 0;

const max = Math.max(...stablePrices);    
const min = Math.min(...stablePrices);    

if (min <= 0) return 0;    

let vol = ((max - min) / min) * 100;    

// clamp    
if (vol > cfg.maxVolatility) vol = cfg.maxVolatility;    
if (vol < cfg.minVolatility) vol = 0;    

return vol;

}

function isStableMarket() {
const vol = getStableVolatility();
if (vol === 0) return false;
if (vol > cfg.maxVolatility) return false;
return true;
}

// ================= ENTRY BOOST =================
function stabilizeSignal(signal, price) {
if (!signal) return null;
const trend = (price - stablePrices[0]) / stablePrices[0];
if (signal.side === "long" && trend < 0) return null;
if (signal.side === "short" && trend > 0) return null;
return signal;
}

// ================= HOOK =================
const previousOnTick = onTick;
onTick = async function(price, volume) {
// 1. нормалізація
const cleanPrice = normalizePrice(price);
if (!cleanPrice) return;

// 2. стабільний буфер    
pushStable(cleanPrice);    

// 3. перевірка ринку    
if (!isStableMarket()) {    
  return; // ринок сміття → нічого не робимо    
}    

// 4. передаємо далі    
if (previousOnTick) await previousOnTick(cleanPrice, volume);

};
})();

// ================== ЗАПУСК ==================
async function main() {
console.log("\n🚀 ЗАПУСК БОТА");
await tradingModeSelector();
if (fs.existsSync('optimized_params.json')) {
const opt = JSON.parse(fs.readFileSync('optimized_params.json'));
adaptiveState.state = opt;
console.log("📥 Завантажено оптимізовані параметри:", opt);
}
startWebSocket();
loop(); // запускаємо автовідновлення PM2
}

process.on("uncaughtException", (err) => console.error("Uncaught Exception:", err));
process.on("unhandledRejection", (reason) => console.error("Unhandled Rejection:", reason));
setInterval(() => {
account.dailyLoss = 0;
account.tradesToday = 0;
console.log("🔄 DAILY RESET (обнулено денні ліміти)");
}, 24 * 60 * 60 * 1000);
