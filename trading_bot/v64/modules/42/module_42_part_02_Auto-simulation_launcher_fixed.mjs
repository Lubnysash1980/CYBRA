// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 42
// part: 2
// original_header: console.log("🚀 Module 42: Auto-simulation launcher (fixed)");
// original_line_start: 4260
// original_line_end: 4280
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🚀 Module 42: Auto-simulation launcher (fixed)");

const simWorkerScript = path.join(process.cwd(), '.sim_worker.js');
const workerContent =     process.env.SIMULATION_MODE = 'true';     process.env.INSIDE_SIMULATION = 'true';     process.env.AUTO_SELECT_MODE = '1';     process.env.SIM_INITIAL_BALANCE = '${SIM_CONFIG.initialBalance}';     process.env.SIM_START_PRICE = '${SIM_CONFIG.startPrice}';     process.env.SIM_VOLATILITY = '${SIM_CONFIG.volatility}';     process.env.SIM_TREND = '${SIM_CONFIG.trendStrength}';     process.env.SIM_SPREAD = '${SIM_CONFIG.spread}';     process.env.SIM_SLIPPAGE = '${SIM_CONFIG.slippage}';     process.env.SIM_TICK_INTERVAL = '${SIM_CONFIG.tickIntervalMs}';     process.env.AUTO_SIM_START = '${SIM_CONFIG.autoStart}';     process.env.SIM_STEPS = '${SIM_CONFIG.steps}';     process.env.SIM_LOG_EVERY = '${SIM_CONFIG.logEvery}';     import('./bot.js');    ;

if (!fs.existsSync(simWorkerScript)) {
fs.writeFileSync(simWorkerScript, workerContent);
}

let simProcess = null;
function startSimulation() {
if (simProcess) simProcess.kill();
simProcess = fork(simWorkerScript, [], {
env: { ...process.env, SIMULATION_MODE: 'true', INSIDE_SIMULATION: 'true' },
silent: false,
});
simProcess.on('exit', () => setTimeout(startSimulation, 5000));
}
setTimeout(startSimulation, 2000);
})();
