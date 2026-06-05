// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 31
// part: 4
// original_header: console.log(🎛️ MODULE 31: ${NUM_WORKERS} workers, threshold ${CONSENSUS_THRESHOLD*100}%);
// original_line_start: 2218
// original_line_end: 2229
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log(🎛️ MODULE 31: ${NUM_WORKERS} workers, threshold ${CONSENSUS_THRESHOLD*100}%);

// Зупинка при завершенні
process.on('SIGINT', () => {
clearInterval(orchestratorInterval);
for (let { worker } of workers.values()) worker.kill();
process.exit();
});
// В кінці модуля 31, після запуску звичайних воркерів, додайте:
if (global.MODULE_33_LOADED && typeof global.startAIWorkers === 'function') {
global.startAIWorkers();
} else {
