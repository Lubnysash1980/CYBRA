// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 38
// part: 2
// original_header: console.log("📊 MODULE 36-38: AI Guard - Candle Analyzer & Volume Trackers ACTIVE");
// original_line_start: 3468
// original_line_end: 3630
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

console.log("📊 MODULE 36-38: AI Guard - Candle Analyzer & Volume Trackers ACTIVE");

// ================== 1. CANDLE ANALYZER (36) ==================
const candles = [];
const MAX_CANDLES = 200;
let currentCandle = null;
let lastProcessedTime = 0;

function initCandleWebSocket() {
const wsCandles = new WebSocket(wss://fstream.binance.com/ws/${CONFIG.ws.SYMBOL}@kline_1m);
wsCandles.on('message', (data) => {
try {
const msg = JSON.parse(data.toString());
if (!msg.k) return;
const k = msg.k;
const candle = {
time: k.t,
open: parseFloat(k.o),
high: parseFloat(k.h),
low: parseFloat(k.l),
close: parseFloat(k.c),
volume: parseFloat(k.v),
isFinal: k.x,
};
if (candle.isFinal) {
candles.push(candle);
if (candles.length > MAX_CANDLES) candles.shift();
analyzeCandle(candle);
} else {
currentCandle = candle;
}
lastProcessedTime = Date.now();
} catch (err) { /* тихо */ }
});
wsCandles.on('error', () => {});
wsCandles.on('close', () => setTimeout(initCandleWebSocket, 5000));
console.log("🕯️ Candle analyzer WebSocket connected");
}

function analyzeCandle(candle) {
const body = Math.abs(candle.close - candle.open);
const upperWick = candle.high - Math.max(candle.open, candle.close);
const lowerWick = Math.min(candle.open, candle.close) - candle.low;
const bodyPercent = (body / (candle.high - candle.low || 1)) * 100;
let candleType = "NEUTRAL";
if (candle.close > candle.open) {
if (upperWick > body * 1.5) candleType = "SHOOTING_STAR";
else if (lowerWick > body * 1.5) candleType = "HAMMER";
else if (bodyPercent > 60) candleType = "STRONG_BULLISH";
else candleType = "BULLISH";
} else if (candle.close < candle.open) {
if (lowerWick > body * 1.5) candleType = "INVERTED_HAMMER";
else if (upperWick > body * 1.5) candleType = "HANGING_MAN";
else if (bodyPercent > 60) candleType = "STRONG_BEARISH";
else candleType = "BEARISH";
}
global.lastCandleAnalysis = {
timestamp: candle.time,
type: candleType,
bodyPercent,
volume: candle.volume,
high: candle.high,
low: candle.low,
close: candle.close,
isReversal: (candleType === "HAMMER" || candleType === "SHOOTING_STAR" || candleType === "INVERTED_HAMMER" || candleType === "HANGING_MAN")
};
if (Math.random() < 0.1) {
console.log(🕯️ Candle: ${candleType} | body ${bodyPercent.toFixed(1)}% | vol ${candle.volume.toFixed(0)});
}
if (global.onCandleClose) global.onCandleClose(global.lastCandleAnalysis);
}

global.getCandles = () => [...candles];
global.getCurrentCandle = () => currentCandle;
global.getLastCandleAnalysis = () => global.lastCandleAnalysis;

// ================== 2. SHORT VOLUME TRACKER (37) ==================
let shortVolume = 0;
let shortTrades = [];
let currentShortExposure = 0;

global.addShortTrade = (quantity, price, timestamp = Date.now()) => {
const tradeValue = quantity * price;
shortVolume += tradeValue;
currentShortExposure += tradeValue;
shortTrades.push({ quantity, price, value: tradeValue, timestamp, type: 'short' });
if (shortTrades.length > 100) shortTrades.shift();
console.log(📉 SHORT: +${quantity} @ ${price} | total short volume: ${shortVolume.toFixed(2)} USDT);
if (global.onShortUpdate) global.onShortUpdate({ quantity, price, totalVolume: shortVolume });
};

global.closeShortTrade = (quantity, price, timestamp = Date.now()) => {
const tradeValue = quantity * price;
currentShortExposure = Math.max(0, currentShortExposure - tradeValue);
console.log(📈 SHORT CLOSED: -${quantity} @ ${price} | remaining exposure: ${currentShortExposure.toFixed(2)} USDT);
if (global.onShortClose) global.onShortClose({ quantity, price, remainingExposure: currentShortExposure });
};

global.getShortVolume = () => shortVolume;
global.getCurrentShortExposure = () => currentShortExposure;
global.getShortTrades = () => [...shortTrades];

// ================== 3. LONG VOLUME TRACKER (38) ==================
let longVolume = 0;
let longTrades = [];
let currentLongExposure = 0;

global.addLongTrade = (quantity, price, timestamp = Date.now()) => {
const tradeValue = quantity * price;
longVolume += tradeValue;
currentLongExposure += tradeValue;
longTrades.push({ quantity, price, value: tradeValue, timestamp, type: 'long' });
if (longTrades.length > 100) longTrades.shift();
console.log(📈 LONG: +${quantity} @ ${price} | total long volume: ${longVolume.toFixed(2)} USDT);
if (global.onLongUpdate) global.onLongUpdate({ quantity, price, totalVolume: longVolume });
};

global.closeLongTrade = (quantity, price, timestamp = Date.now()) => {
const tradeValue = quantity * price;
currentLongExposure = Math.max(0, currentLongExposure - tradeValue);
console.log(📉 LONG CLOSED: -${quantity} @ ${price} | remaining exposure: ${currentLongExposure.toFixed(2)} USDT);
if (global.onLongClose) global.onLongClose({ quantity, price, remainingExposure: currentLongExposure });
};

global.getLongVolume = () => longVolume;
global.getCurrentLongExposure = () => currentLongExposure;
global.getLongTrades = () => [...longTrades];

// ================== 4. ІНТЕГРАЦІЯ З placeOrder ==================
const originalPlaceOrder363738 = global.placeOrder;
if (originalPlaceOrder363738) {
global.placeOrder = async function(side, quantity, currentPrice) {
const result = await originalPlaceOrder363738(side, quantity, currentPrice);
if (result) {
if (side === 'short') global.addShortTrade(quantity, currentPrice);
if (side === 'long') global.addLongTrade(quantity, currentPrice);
}
return result;
};
}

// ================== 5. ІНТЕГРАЦІЯ З AI GUARD (МОДУЛЬ 34) ==================
if (global.MODULE_34_LOADED) {
global.getMarketSentiment = () => {
const lastCandle = global.getLastCandleAnalysis();
const shortExposure = global.getCurrentShortExposure?.() || 0;
const longExposure = global.getCurrentLongExposure?.() || 0;
const totalExposure = shortExposure + longExposure;
return {
candle: lastCandle,
shortRatio: totalExposure > 0 ? shortExposure / totalExposure : 0.5,
longRatio: totalExposure > 0 ? longExposure / totalExposure : 0.5,
netPosition: longExposure - shortExposure,
timestamp: Date.now()
};
};
console.log("🔗 Modules 36-38 integrated with AI Guard (34)");
}

// Запуск аналізатора свічок
initCandleWebSocket();
})();
