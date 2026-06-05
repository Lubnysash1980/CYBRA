// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 31
// part: 1
// original_header: // ================== MODULE 31: WORKER POOL MANAGER ==================
// original_line_start: 2044
// original_line_end: 2050
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// ================== MODULE 31: WORKER POOL MANAGER ==================
(function initWorkerPool() {
if (global.WORKER_POOL_LOADED) return;
global.WORKER_POOL_LOADED = true;

// Активуємо тільки в режимі оркестратора
if (process.env.ORCHESTRATOR_MODE !== 'true') {
