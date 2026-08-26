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

async function main() {
  const rpc =
    env.BSC_RPC ||
    "https://bsc-dataseed.binance.org/";

  const provider = new ethers.JsonRpcProvider(rpc);

  const privateKey = env.HOT_PRIVATE_KEY.startsWith("0x")
    ? env.HOT_PRIVATE_KEY
    : "0x" + env.HOT_PRIVATE_KEY;

  const wallet = new ethers.Wallet(privateKey, provider);

  const network = await provider.getNetwork();

  if (network.chainId !== 56n) {
    throw new Error(
      `Wrong network. Expected BSC chainId 56, got ${network.chainId}`
    );
  }

  let bytecode = fs
    .readFileSync("./contracts/CybraToken.bin", "utf8")
    .trim();

  if (!bytecode.startsWith("0x")) {
    bytecode = "0x" + bytecode;
  }

  const hex = bytecode.slice(2);

  if (!/^[0-9a-fA-F]+$/.test(hex) || hex.length % 2 !== 0) {
    throw new Error("Invalid deployment bytecode");
  }

  console.log("=== CYBRA BSC DEPLOY ===");
  console.log("Deployer:", wallet.address);
  console.log("Chain ID:", network.chainId.toString());
  console.log("Nonce:", await wallet.getNonce());
  console.log("Bytecode bytes:", hex.length / 2);

  const balance = await provider.getBalance(wallet.address);

  console.log(
    "Balance:",
    ethers.formatEther(balance),
    "BNB"
  );

  // Simulate deployment first.
  const estimatedGas = await provider.estimateGas({
    from: wallet.address,
    data: bytecode
  });

  const feeData = await provider.getFeeData();

  let gasPrice = feeData.gasPrice;

  if (!gasPrice) {
    gasPrice = 50_000_000n; // 0.05 Gwei
  }

  console.log(
    "Estimated gas:",
    estimatedGas.toString()
  );

  console.log(
    "Gas price:",
    ethers.formatUnits(gasPrice, "gwei"),
    "Gwei"
  );

  // 20% safety margin.
  const gasLimit =
    (estimatedGas * 120n) / 100n;

  const maxCost = gasLimit * gasPrice;

  console.log(
    "Gas limit:",
    gasLimit.toString()
  );

  console.log(
    "Maximum gas cost:",
    ethers.formatEther(maxCost),
    "BNB"
  );

  if (balance < maxCost) {
    throw new Error(
      `Insufficient balance. Need ${ethers.formatEther(maxCost)} BNB, have ${ethers.formatEther(balance)} BNB`
    );
  }

  const nonce = await wallet.getNonce();

  const tx = {
    data: bytecode,
    gasLimit,
    chainId: 56n,
    nonce,
    gasPrice
  };

  console.log("");
  console.log("Signing deployment transaction...");

  const signed = await wallet.signTransaction(tx);

  fs.writeFileSync(
    "./wallet/runtime/signed.tx",
    signed
  );

  console.log("Signed transaction created.");
  console.log("Broadcasting...");

  const response =
    await provider.broadcastTransaction(signed);

  console.log("TX HASH:", response.hash);

  fs.writeFileSync(
    "./wallet/runtime/deploy_hash.txt",
    response.hash
  );

  console.log("Waiting for confirmation...");

  const receipt = await response.wait();

  if (!receipt || receipt.status !== 1) {
    throw new Error("Deployment transaction failed");
  }

  console.log("");
  console.log("================================");
  console.log("CYBRA DEPLOYMENT SUCCESS");
  console.log("================================");
  console.log("TX:", response.hash);
  console.log("Contract:", receipt.contractAddress);
  console.log("Gas used:", receipt.gasUsed.toString());

  fs.writeFileSync(
    "./wallet/runtime/contract_address.txt",
    receipt.contractAddress
  );
}

main().catch(err => {
  console.error("");
  console.error("DEPLOY ERROR:");
  console.error(err.shortMessage || err.message);
  process.exit(1);
});
