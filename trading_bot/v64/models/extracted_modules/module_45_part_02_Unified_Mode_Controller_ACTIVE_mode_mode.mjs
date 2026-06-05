// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 45
// part: 2
// original_header: console.log(🎮 MODULE 45: Unified Mode Controller ACTIVE (${mode} mode));
// original_line_start: 4430
// original_line_end: 4518
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log(🎮 MODULE 45: Unified Mode Controller ACTIVE (${mode} mode));

if (isSimulation) {
// ========== СИМУЛЯЦІЯ: ВИМИКАЄМО ВСІ БЛОКУЮЧІ ФІЛЬТРИ ==========
console.log("🧪 Simulation mode: disabling blocking filters for maximum trading activity");

// 1. Вимкнути FAKE BREAKOUT (модуль TRAP)    
if (global.buildSignal) {    
  const originalBuild = global.buildSignal;    
  global.buildSignal = function(price) {    
    let signal = originalBuild(price);    
    if (!signal) {    
      const dev = deviation(price);    
      if (Math.abs(dev) > 0.0005) {    
        signal = { side: dev > 0 ? "short" : "long", dev, ts: Date.now(), simulation: true };    
      }    
    }    
    return signal;    
  };    
  console.log("   🔓 FAKE BREAKOUT filter disabled for simulation");    
}    

// 2. Вимкнути volatility filter    
if (global.volatilityCheck) {    
  global.volatilityCheck = function() {    
    return { action: "TRADE", volatility: 1 };    
  };    
  console.log("   🔓 Volatility filter disabled for simulation");    
}    

// 3. Вимкнути cooldown    
if (CONFIG.cooldown) CONFIG.cooldown.ENABLED = false;    
console.log("   🔓 Cooldown disabled for simulation");    

// 4. Збільшити ліміти    
CONFIG.risk.MAX_TRADES_PER_DAY = 1000;    
CONFIG.risk.MAX_DAILY_LOSS = 100;    
console.log("✅ Simulation mode: all filters disabled, ready for high-frequency trading");

} else {
// ========== РЕАЛЬНИЙ / ПАПЕРОВИЙ РЕЖИМ: ПОКРАЩУЄМО, АЛЕ НЕ ВИМИКАЄМО ==========
console.log("🛡️ Real/Paper mode: keeping filters but improving sensitivity");

// Додаємо override для FAKE BREAKOUT при сильних сигналах    
if (global.buildSignal) {    
  const originalBuild = global.buildSignal;    
  global.buildSignal = function(price) {    
    let signal = originalBuild(price);    
    if (!signal) {    
      const dev = Math.abs(deviation(price));    
      const spike = volumeSpike();    
      if (dev > 0.003 || spike > 1.8) {    
        signal = { side: deviation(price) > 0 ? "short" : "long", dev, ts: Date.now(), override: true };    
        console.log("🛡️ REAL MODE OVERRIDE: forced entry due to strong signal");    
      }    
    }    
    return signal;    
  };    
  console.log("   🔧 FAKE BREAKOUT override enabled for strong signals");    
}    

// Пом'якшуємо volatility filter    
if (global.volatilityCheck) {    
  const originalVolCheck = global.volatilityCheck;    
  global.volatilityCheck = function(price) {    
    let result = originalVolCheck(price);    
    if (result && result.action === 'HOLD' && result.reason === 'low_vol') {    
      const dev = Math.abs(deviation(price));    
      if (dev > 0.001) return { action: "TRADE", volatility: 0.5 };    
    }    
    return result;    
  };    
  console.log("   🔧 Volatility filter adjusted");    
}

}

// Додаємо функції для ручного перемикання
global.switchToSimulation = () => {
console.log("Switching to simulation mode...");
process.env.SIMULATION_MODE = 'true';
console.log("Please restart bot to apply changes");
};
global.switchToReal = () => {
console.log("Switching to real/paper mode...");
process.env.SIMULATION_MODE = 'false';
console.log("Please restart bot to apply changes");
};
