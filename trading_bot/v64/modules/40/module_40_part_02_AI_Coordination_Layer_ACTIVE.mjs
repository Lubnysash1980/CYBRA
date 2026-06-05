// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 40
// part: 2
// original_header: console.log("🔗 MODULE 40: AI Coordination Layer ACTIVE");
// original_line_start: 3636
// original_line_end: 3936
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("🔗 MODULE 40: AI Coordination Layer ACTIVE");

// ================== 1. РЕЄСТР AI КОМПОНЕНТІВ ==================
const aiRegistry = new Map(); // id -> { type, lastHeartbeat, status, restartCount, processRef, metadata }
const HEALTH_CHECK_INTERVAL_MS = 15000;   // перевірка кожні 15 секунд
const HEARTBEAT_TIMEOUT_MS = 30000;       // 30 секунд без heartbeat – dead
const MAX_RESTARTS_PER_HOUR = 5;           // макс перезапусків за годину

// Лічильники перезапусків для запобігання циклічним перезапускам
const restartCounter = new Map(); // id -> { count, firstRestartTime }

// Функція реєстрації AI компонента (воркер, ядро, AI guard тощо)
global.registerAIComponent = (id, type, metadata = {}) => {
if (aiRegistry.has(id)) {
// Оновлюємо heartbeat
aiRegistry.get(id).lastHeartbeat = Date.now();
aiRegistry.get(id).status = 'active';
return;
}
aiRegistry.set(id, {
type,          // 'worker', 'core', 'ai_guard', 'candle_analyzer', 'volume_tracker'
lastHeartbeat: Date.now(),
status: 'active',
restartCount: 0,
metadata,
createdAt: Date.now()
});
console.log(🟢 AI component registered: ${id} (${type}));
};

// Функція оновлення heartbeat (викликається кожним AI компонентом)
global.heartbeatAI = (id) => {
if (aiRegistry.has(id)) {
aiRegistry.get(id).lastHeartbeat = Date.now();
if (aiRegistry.get(id).status === 'inactive') {
aiRegistry.get(id).status = 'active';
console.log(💓 AI component ${id} recovered (heartbeat received));
}
} else {
// Автоматична реєстрація при першому heartbeat
global.registerAIComponent(id, 'unknown');
}
};

// Функція перевірки здоров'я компонента
function isComponentHealthy(entry) {
const now = Date.now();
const timeSinceHeartbeat = now - entry.lastHeartbeat;
return (timeSinceHeartbeat <= HEARTBEAT_TIMEOUT_MS && entry.status === 'active');
}

// Функція перезапуску компонента (примусовий запуск)
async function restartAIComponent(id) {
const entry = aiRegistry.get(id);
if (!entry) {
console.log(⚠️ Cannot restart unknown component: ${id});
return false;
}

// Перевірка ліміту перезапусків    
const now = Date.now();    
let counter = restartCounter.get(id);    
if (!counter) {    
  counter = { count: 0, firstRestartTime: now };    
  restartCounter.set(id, counter);    
}    
if (now - counter.firstRestartTime < 3600000) { // за годину    
  if (counter.count >= MAX_RESTARTS_PER_HOUR) {    
    console.log(`🚫 Component ${id} exceeded restart limit (${MAX_RESTARTS_PER_HOUR}/hour). Manual intervention required.`);    
    entry.status = 'quarantined';    
    return false;    
  }    
} else {    
  // Скидаємо лічильник після години    
  counter.count = 0;    
  counter.firstRestartTime = now;    
}    
    
console.log(`🔄 Restarting AI component: ${id} (type: ${entry.type})`);    
counter.count++;    
    
// Спробуємо перезапустити залежно від типу компонента    
try {    
  if (entry.type === 'worker' && global.restartWorker) {    
    // Якщо є глобальна функція перезапуску воркера (модуль 31)    
    await global.restartWorker(parseInt(id.split('_').pop()), true);    
  } else if (entry.type === 'core' && global.restartCore) {    
    await global.restartCore(id);    
  } else if (entry.type === 'ai_guard' && global.restartAIGuard) {    
    await global.restartAIGuard();    
  } else {    
    // Загальний метод: перестворюємо через reinitialization    
    if (entry.metadata && entry.metadata.reinitFn && typeof global[entry.metadata.reinitFn] === 'function') {    
      await global[entry.metadata.reinitFn]();    
    } else {    
      // Якщо немає специфічного методу, просто скидаємо статус    
      entry.status = 'active';    
      entry.lastHeartbeat = Date.now();    
      console.log(`⚠️ No restart method for ${id}, reset status only`);    
    }    
  }    
  entry.restartCount++;    
  entry.lastHeartbeat = Date.now();    
  entry.status = 'active';    
  return true;    
} catch (err) {    
  console.error(`❌ Failed to restart ${id}:`, err.message);    
  entry.status = 'error';    
  return false;    
}

}

// Періодична перевірка всіх зареєстрованих компонентів
async function healthCheckLoop() {
const now = Date.now();
for (let [id, entry] of aiRegistry.entries()) {
if (!isComponentHealthy(entry)) {
console.log(⚠️ Unhealthy AI component detected: ${id} (last heartbeat: ${new Date(entry.lastHeartbeat).toISOString()}));
await restartAIComponent(id);
}
}
}

// Запускаємо періодичну перевірку
setInterval(healthCheckLoop, HEALTH_CHECK_INTERVAL_MS);

// ================== 2. AI COORDINATION LAYER (МОДУЛЬ 40) ==================
// Черги повідомлень, синхронізація, пріоритети

// Типи повідомлень: 'order', 'config_change', 'signal', 'trade_result', 'error'
const priorityOrder = { 'order': 1, 'trade_result': 2, 'config_change': 3, 'signal': 4, 'error': 5 };
const messageQueue = [];
let isProcessingQueue = false;

// Лок для синхронізації доступу до спільних ресурсів (state, account, CONFIG)
const mutex = {
locked: false,
queue: [],
async acquire() {
return new Promise((resolve) => {
if (!this.locked) {
this.locked = true;
resolve();
} else {
this.queue.push(resolve);
}
});
},
release() {
if (this.queue.length > 0) {
const next = this.queue.shift();
next();
} else {
this.locked = false;
}
}
};

// Функція надсилання повідомлення в чергу з пріоритетом
global.sendAIMessage = (type, payload, priority = null) => {
const prio = priority !== null ? priority : (priorityOrder[type] || 5);
const message = { type, payload, timestamp: Date.now(), priority: prio };
// Вставка з урахуванням пріоритету
let inserted = false;
for (let i = 0; i < messageQueue.length; i++) {
if (messageQueue[i].priority > prio) {
messageQueue.splice(i, 0, message);
inserted = true;
break;
}
}
if (!inserted) messageQueue.push(message);

if (!isProcessingQueue) processMessageQueue();

};

async function processMessageQueue() {
if (isProcessingQueue) return;
isProcessingQueue = true;
while (messageQueue.length > 0) {
const msg = messageQueue.shift();
await handleMessage(msg);
}
isProcessingQueue = false;
}

async function handleMessage(msg) {
// Використовуємо mutex для критичних секцій (наприклад, зміна стану або балансу)
await mutex.acquire();
try {
switch (msg.type) {
case 'order':
if (global.executeOrderFromAI) {
await global.executeOrderFromAI(msg.payload);
}
break;
case 'config_change':
if (global.applyConfigChange) {
await global.applyConfigChange(msg.payload);
} else {
// Пряме застосування змін до CONFIG
for (const [key, value] of Object.entries(msg.payload)) {
if (key.startsWith('CONFIG.')) {
const parts = key.split('.');
let obj = global;
for (let i = 0; i < parts.length - 1; i++) obj = obj[parts[i]];
if (obj && obj[parts[parts.length-1]] !== undefined) {
obj[parts[parts.length-1]] = value;
}
}
}
}
break;
case 'signal':
if (global.handleAISignal) await global.handleAISignal(msg.payload);
break;
case 'trade_result':
if (global.handleTradeResult) await global.handleTradeResult(msg.payload);
break;
default:
console.log(📨 Unhandled AI message type: ${msg.type});
}
} finally {
mutex.release();
}
}

// Функція для безпечного доступу до спільних даних (state, account, adaptiveState)
global.withAILock = async (fn) => {
await mutex.acquire();
try {
return await fn();
} finally {
mutex.release();
}
};

// Автоматична реєстрація наявних AI компонентів (модулі 33, 34, 35, 36-38)
function registerExistingComponents() {
// Реєструємо воркерів з модуля 33 (якщо є)
if (global.modulesRegistry) {
for (let [modName, modData] of global.modulesRegistry.entries()) {
if (modData.workers) {
for (let [workerId, worker] of modData.workers.entries()) {
global.registerAIComponent(workerId, 'worker', { module: modName });
// Якщо є можливість надсилати heartbeat від воркера – налагоджуємо
if (worker.performance && worker.performance.lastScore !== undefined) {
// Оновлюємо heartbeat при кожному оновленні продуктивності
const originalTrain = worker.train;
if (originalTrain) {
worker.train = function(...args) {
global.heartbeatAI(workerId);
return originalTrain.apply(this, args);
};
}
}
}
}
if (modData.cores) {
for (let [coreId, core] of modData.cores.entries()) {
global.registerAIComponent(coreId, 'core', { module: modName });
}
}
}
}

// Реєструємо AI Guard (модуль 34,35) – за глобальними функціями    
if (global.placeOrder !== undefined) {    
  global.registerAIComponent('ai_guard_order', 'ai_guard', { reinitFn: 'reinitAIGuard' });    
}    
if (global.getMarketSentiment !== undefined) {    
  global.registerAIComponent('candle_analyzer', 'candle_analyzer');    
}    
if (global.getShortVolume !== undefined) {    
  global.registerAIComponent('volume_tracker_short', 'volume_tracker');    
  global.registerAIComponent('volume_tracker_long', 'volume_tracker');    
}

}

// Функція, яку можна викликати для примусової перевірки та відновлення
global.forceAICheck = async () => {
console.log("🔍 Force AI health check...");
await healthCheckLoop();
};

// Запускаємо реєстрацію через невелику затримку (після завантаження всіх модулів)
setTimeout(registerExistingComponents, 2000);

// Періодичне логування статусу (кожні 5 хвилин)
setInterval(() => {
const active = Array.from(aiRegistry.values()).filter(e => e.status === 'active').length;
const total = aiRegistry.size;
console.log(📊 AI Health: ${active}/${total} components active);
}, 300000);

console.log("✅ AI Health Supervisor and Coordination Layer ready");
})();
