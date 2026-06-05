// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 15
// part: 2
// original_header: console.log("⚡ MODULE 15 ACTIVE (з перевіркою ціни)");
// original_line_start: 1166
// original_line_end: 1210
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("⚡ MODULE 15 ACTIVE (з перевіркою ціни)");

const vf = { prices: [] };
const vcfg = {
window: 20,
minVolatility: 0.02,     // %
maxVolatility: 5,        // %
minPrice: 0.0001,        // мінімальна реальна ціна (DOGE ~0.15)
maxPrice: 1000           // максимальна реальна ціна
};

global.volatilityCheck = function(price) {
// 1. ВІДСІЧЕННЯ НЕКОРЕКТНИХ ЦІН
if (!price || !Number.isFinite(price) || price <= 0) {
return { action: "WAIT", reason: "invalid_price" };
}
if (price < vcfg.minPrice || price > vcfg.maxPrice) {
// тихо ігноруємо – не спамимо в лог
return { action: "WAIT", reason: "price_out_of_range" };
}

// 2. Накопичення тільки чистих цін    
vf.prices.push(price);    
if (vf.prices.length > vcfg.window) vf.prices.shift();    
if (vf.prices.length < vcfg.window) {    
  return { action: "WAIT", reason: "collecting" };    
}    

// 3. Обчислення волатильності (min > 0 гарантовано)    
const min = Math.min(...vf.prices);    
const max = Math.max(...vf.prices);    
const volPercent = ((max - min) / min) * 100;    

// 4. Захист від аномалій (хоча їх вже не буде)    
if (!Number.isFinite(volPercent) || volPercent > 100) {    
  return { action: "HOLD", reason: "vol_out_of_range" };    
}    
if (volPercent < vcfg.minVolatility) return { action: "HOLD", reason: "low_vol" };    
if (volPercent > vcfg.maxVolatility) return { action: "HOLD", reason: "high_vol" };    

return { action: "TRADE", volatility: volPercent };

};
})();
