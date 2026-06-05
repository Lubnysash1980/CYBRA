// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 45
// part: 1
// original_header: // ================== MODULE 45: UNIFIED MODE CONTROLLER ==================
// original_line_start: 4423
// original_line_end: 4429
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// ================== MODULE 45: UNIFIED MODE CONTROLLER ==================
(function initModule45() {
if (global.MODULE_45_LOADED) return;
global.MODULE_45_LOADED = true;

const isSimulation = process.env.SIMULATION_MODE === 'true';
const mode = isSimulation ? 'SIMULATION' : (CONFIG.trading.REAL_MODE ? 'REAL' : 'PAPER');
