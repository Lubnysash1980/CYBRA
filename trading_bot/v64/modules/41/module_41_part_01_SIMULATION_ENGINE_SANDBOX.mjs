// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 41
// part: 1
// original_header: // ================== MODULE 41: SIMULATION ENGINE (SANDBOX) ==================
// original_line_start: 3937
// original_line_end: 3944
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// ================== MODULE 41: SIMULATION ENGINE (SANDBOX) ==================
(function initSimulationEngine() {
if (global.SIMULATION_ENGINE_LOADED) return;
global.SIMULATION_ENGINE_LOADED = true;

// Активуємо через змінну оточення SIMULATION_MODE=true
const SIMULATION_MODE = process.env.SIMULATION_MODE === 'true';
if (!SIMULATION_MODE) {
