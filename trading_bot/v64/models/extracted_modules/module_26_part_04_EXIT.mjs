// CYBRA MODULE PRESERVED FROM ORIGINAL 6000-LINE BOT
// module_number: 26
// part: 4
// original_header: // ================= MODULE 26: EXIT =================
// original_line_start: 1638
// original_line_end: 1671
// policy: preserved_source_model
// live_force_trading: disabled_by_cybra_safety_policy

// ================= MODULE 26: EXIT =================
global.optimizeExit = function(price, position) {
try {
if (!position) return "HOLD";

const pnl = global.calculatePnL?.(price) || 0;    
  const atr = global.getATR?.(price) || 0;    

  // take profit    
  if (pnl > atr * 2) {    
    return "TAKE_PROFIT";    
  }    

  // stop loss    
  if (pnl < -atr * 1.5) {    
    return "STOP_LOSS";    
  }    

  // trailing    
  if (pnl > atr) {    
    return "TRAIL";    
  }    

  return "HOLD";    

} catch (e) {    
  console.log("❌ EXIT ERROR:", e.message);    
  return "HOLD";    
}

};

})();
