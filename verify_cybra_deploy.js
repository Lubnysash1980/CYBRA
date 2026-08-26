const fs = require("fs");
const ethers = require("ethers");

const env = fs.readFileSync(".env", "utf8")
  .split("\n")
  .filter(line => line.trim() && !line.trim().startsWith("#"))
  .reduce((acc, line) => {
    const [key, ...val] = line.split("=");
    acc[key.trim()] = val.join("=").trim();
    return acc;
  }, {});

const rpc = env.BSC_RPC || "https://bsc-dataseed.binance.org/";

async function main() {
  const provider = new ethers.JsonRpcProvider(rpc);

  const network = await provider.getNetwork();

  console.log("=== CYBRA DEPLOY DRY RUN ===");
  console.log("RPC:", rpc);
  console.log("Chain ID:", network.chainId.toString());

  if (network.chainId !== 56n) {
    throw new Error(
      `НЕ BSC MAINNET: chainId=${network.chainId.toString()}`
    );
  }

  let bytecode = fs.readFileSync(
    "./contracts/CybraToken.bin",
    "utf8"
  ).trim();

  if (!bytecode.startsWith("0x")) {
    bytecode = "0x" + bytecode;
  }

  const hex = bytecode.slice(2);

  if (!/^[0-9a-fA-F]+$/.test(hex)) {
    throw new Error("Bytecode містить неhex символи");
  }

  if (hex.length % 2 !== 0) {
    throw new Error("Bytecode має непарну кількість hex символів");
  }

  console.log("Bytecode bytes:", hex.length / 2);
  console.log("Bytecode prefix:", hex.slice(0, 40));

  const signerAddress =
    env.HOT_PRIVATE_KEY &&
    env.HOT_PRIVATE_KEY !==
      "0x0000000000000000000000000000000000000000000000000000000000000000"
      ? new ethers.Wallet(
          env.HOT_PRIVATE_KEY.startsWith("0x")
            ? env.HOT_PRIVATE_KEY
            : "0x" + env.HOT_PRIVATE_KEY
        ).address
      : null;

  if (!signerAddress) {
    throw new Error("HOT_PRIVATE_KEY не налаштований");
  }

  console.log("Deployer:", signerAddress);

  const balance = await provider.getBalance(signerAddress);

  console.log(
    "Balance BNB:",
    ethers.formatEther(balance)
  );

  const tx = {
    from: signerAddress,
    data: bytecode
  };

  console.log("Running eth_estimateGas...");

  const gas = await provider.estimateGas(tx);

  console.log("Estimated gas:", gas.toString());

  const feeData = await provider.getFeeData();
  const gasPrice = feeData.gasPrice || 5000000000n;

  console.log(
    "Gas price Gwei:",
    ethers.formatUnits(gasPrice, "gwei")
  );

  const estimatedCost = gas * gasPrice;

  console.log(
    "Estimated deployment cost BNB:",
    ethers.formatEther(estimatedCost)
  );

  console.log("");
  console.log("================================");
  console.log("DRY RUN PASSED");
  console.log("NO TRANSACTION WAS SENT");
  console.log("================================");
}

main().catch(err => {
  console.error("");
  console.error("❌ DRY RUN FAILED");
  console.error(err.shortMessage || err.message);
  process.exit(1);
});
