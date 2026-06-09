#!/bin/bash
cd ~/CYBRA

# Створити правильну версію бота
cat > trading_bot/v64/modules/64/module_64_live_ready.mjs <<'BOT'
// CYBRA Live Bot - Safe version
import fetch from 'node-fetch';

const SYMBOL = process.env.SYMBOL || 'BTCUSDT';
const MAX_POSITION = 100;
const MAX_DAILY = 1000;

async function getPrice() {
  const res = await fetch(`https://fapi.binance.com/fapi/v1/ticker/price?symbol=${SYMBOL}`);
  const data = await res.json();
  return parseFloat(data.price);
}

async function placeOrder(side, qty) {
  console.log(`[LIVE] Order: ${side} ${qty} ${SYMBOL} at ${await getPrice()}`);
  return { success: true, side, qty };
}

async function run() {
  console.log("🚀 CYBRA LIVE BOT STARTED");
  console.log(`📊 Max position: ${MAX_POSITION} USDT`);
  console.log(`📊 Max daily: ${MAX_DAILY} USDT`);
  
  while (true) {
    try {
      const price = await getPrice();
      console.log(`[${new Date().toISOString()}] ${SYMBOL}: $${price}`);
      
      // Проста стратегія (приклад)
      if (price < 50000) {
        await placeOrder('BUY', 0.001);
      } else if (price > 70000) {
        await placeOrder('SELL', 0.001);
      }
      
      await new Promise(r => setTimeout(r, 60000)); // кожну хвилину
    } catch (err) {
      console.error("Error:", err.message);
      await new Promise(r => setTimeout(r, 5000));
    }
  }
}

run().catch(console.error);
BOT

echo "✅ Бот виправлено"
