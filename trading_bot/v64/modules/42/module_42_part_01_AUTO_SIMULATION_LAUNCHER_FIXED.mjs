// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 42
// part: 1
// original_header: // ================== MODULE 42: AUTO SIMULATION LAUNCHER (FIXED) ==================
// original_line_start: 4230
// original_line_end: 4259
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// ================== MODULE 42: AUTO SIMULATION LAUNCHER (FIXED) ==================
(function initAutoSimulationFixed() {
if (global.AUTO_SIM_FIXED_LOADED) return;
global.AUTO_SIM_FIXED_LOADED = true;

// Запобігаємо запуску в дочірньому процесі
if (process.env.INSIDE_SIMULATION === 'true') {
console.log("🧪 Simulation worker active - skipping main init");
return;
}

const { fork } = require('child_process');
const fs = require('fs');
const path = require('path');

const SIM_CONFIG = {
enabled: true,
initialBalance: 10000,
startPrice: 0.15,
volatility: 0.02,
trendStrength: 0.0001,
spread: 0.001,
slippage: 0.0005,
tickIntervalMs: 1000,
autoStart: true,
steps: 2000,
logEvery: 100,
};

if (!SIM_CONFIG.enabled) return;
