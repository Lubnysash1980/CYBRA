// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 27
// part: 3
// original_header: // ================= MODULE 27: LIQUIDITY FILTER =================
// original_line_start: 1578
// original_line_end: 1607
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// ================= MODULE 27: LIQUIDITY FILTER =================
global.liquidityFilter = function(price) {
try {
const orderBook = global.getOrderBook?.();

if (!orderBook) return true;    

  const bids = orderBook.bids || [];    
  const asks = orderBook.asks || [];    

  const bidVolume = bids.reduce((sum, b) => sum + parseFloat(b[1] || 0), 0);    
  const askVolume = asks.reduce((sum, a) => sum + parseFloat(a[1] || 0), 0);    

  const imbalance = bidVolume - askVolume;    

  // ❌ avoid low liquidity    
  if (bidVolume + askVolume < 100) return false;    

  // ❌ avoid extreme imbalance (manipulation zones)    
  if (Math.abs(imbalance) > (bidVolume + askVolume) * 0.8) return false;    

  return true;    

} catch (e) {    
  console.log("❌ LIQUIDITY ERROR:", e.message);    
  return true;    
}

};
