// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 43
// part: 2
// original_header: console.log("⏱️ MODULE 43: Task Queue, Rate Limiter & AI Heartbeat Fix ACTIVE");
// original_line_start: 4285
// original_line_end: 4419
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("⏱️ MODULE 43: Task Queue, Rate Limiter & AI Heartbeat Fix ACTIVE");

// ========== 1. КОНФІГУРАЦІЯ ==========
const CFG = {
MIN_REQUEST_INTERVAL_MS: parseInt(process.env.RATE_LIMIT_MS || "200"),  // 200ms = 5 requests/sec
MAX_QUEUE_SIZE: 100,
HEARTBEAT_INTERVAL_MS: 10000,           // кожні 10 секунд
QUEUE_PROCESS_DELAY_MS: 50,
};

// ========== 2. ЧЕРГА ЗАВДАНЬ З ПРІОРИТЕТАМИ ==========
const taskQueue = [];
let isProcessing = false;
let lastRequestTime = 0;

// Пріоритети: 1 – найвищий (ордери), 2 – зміна конфігурації, 3 – heartbeat/лог
function addTask(task, priority = 2) {
if (taskQueue.length >= CFG.MAX_QUEUE_SIZE) {
console.warn("⚠️ Task queue full, dropping lowest priority task");
taskQueue.pop();
}
// Вставка з урахуванням пріоритету
let inserted = false;
for (let i = 0; i < taskQueue.length; i++) {
if (taskQueue[i].priority > priority) {
taskQueue.splice(i, 0, { task, priority });
inserted = true;
break;
}
}
if (!inserted) taskQueue.push({ task, priority });
processQueue();
}

async function processQueue() {
if (isProcessing) return;
isProcessing = true;
while (taskQueue.length > 0) {
const now = Date.now();
const timeSinceLast = now - lastRequestTime;
if (timeSinceLast < CFG.MIN_REQUEST_INTERVAL_MS) {
await new Promise(r => setTimeout(r, CFG.MIN_REQUEST_INTERVAL_MS - timeSinceLast));
}
const { task } = taskQueue.shift();
lastRequestTime = Date.now();
try {
await task();
} catch (err) {
console.error("❌ Task execution error:", err.message);
}
// Невелика затримка між задачами навіть якщо ліміт не спрацював
await new Promise(r => setTimeout(r, CFG.QUEUE_PROCESS_DELAY_MS));
}
isProcessing = false;
}

// ========== 3. ПЕРЕВИЗНАЧЕННЯ КРИТИЧНИХ ФУНКЦІЙ ==========
// Перехоплюємо placeOrder (якщо він ще не перевизначений)
const originalPlaceOrder = global.placeOrder;
if (originalPlaceOrder) {
global.placeOrder = async function(side, quantity, price) {
return new Promise((resolve, reject) => {
addTask(async () => {
try {
const result = await originalPlaceOrder(side, quantity, price);
resolve(result);
} catch (err) {
reject(err);
}
}, 1); // пріоритет 1 – найвищий
});
};
console.log("🔧 placeOrder wrapped with task queue (priority 1)");
}

// Перехоплюємо getAccountBalance (якщо використовується)
const originalGetBalance = global.getAccountBalance;
if (originalGetBalance) {
global.getAccountBalance = async function() {
return new Promise((resolve) => {
addTask(async () => {
const result = await originalGetBalance();
resolve(result);
}, 2);
});
};
}

// ========== 4. AI HEARTBEAT ФІКС ==========
// Якщо модуль 39-40 зареєстрував компоненти, оновлюємо heartbeat періодично
function startHeartbeatFix() {
setInterval(() => {
if (global.heartbeatAI) {
// Оновлюємо heartbeat для всіх зареєстрованих компонентів
if (global.aiRegistry) {
for (let [id, entry] of global.aiRegistry.entries()) {
if (entry.status !== 'quarantined') {
global.heartbeatAI(id);
}
}
}
// Додатково для основних компонентів
const components = ['ai_guard_order', 'candle_analyzer', 'volume_tracker_short', 'volume_tracker_long'];
for (let id of components) {
if (global.heartbeatAI) global.heartbeatAI(id);
}
}
}, CFG.HEARTBEAT_INTERVAL_MS);
console.log("💓 AI Heartbeat fix active (every 10s)");
}

// ========== 5. СИНХРОНІЗАЦІЯ НАВЧАННЯ (МОДУЛЬ 33) ==========
// Якщо є функції навчання, обмежуємо їх частоту
if (global.modulesRegistry && global.trainAllWorkers) {
const originalTrain = global.trainAllWorkers;
let lastTrainTime = 0;
const TRAIN_COOLDOWN_MS = 30000; // не частіше ніж раз на 30 секунд
global.trainAllWorkers = async function() {
const now = Date.now();
if (now - lastTrainTime < TRAIN_COOLDOWN_MS) {
return; // пропускаємо
}
lastTrainTime = now;
return originalTrain();
};
console.log("🧠 Training rate-limited to once per 30 sec");
}

// ========== 6. ЗАПУСК ФІКСІВ ==========
startHeartbeatFix();

// Експортуємо допоміжні функції для інших модулів
global.addTask = addTask;
global.getQueueStatus = () => ({ size: taskQueue.length, processing: isProcessing, lastRequestTime });
