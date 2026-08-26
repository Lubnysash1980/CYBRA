const fs = require("fs");
const solc = require("solc");

const source = fs.readFileSync("./CybraToken.sol", "utf8");

function findImports(path) {
  try {
    return {
      contents: fs.readFileSync(
        path.startsWith("@openzeppelin/")
          ? "./node_modules/" + path
          : path,
        "utf8"
      )
    };
  } catch (e) {
    return { error: "Import not found: " + path };
  }
}

const input = {
  language: "Solidity",
  sources: {
    "CybraToken.sol": {
      content: source
    }
  },
  settings: {
    optimizer: {
      enabled: true,
      runs: 200
    },
    evmVersion: "paris",
    outputSelection: {
      "*": {
        "*": [
          "abi",
          "evm.bytecode.object",
          "evm.deployedBytecode.object"
        ]
      }
    }
  }
};

const output = JSON.parse(
  solc.compile(JSON.stringify(input), { import: findImports })
);

if (output.errors) {
  for (const e of output.errors) {
    console.error(e.formattedMessage);
  }

  const fatal = output.errors.some(
    e => e.severity === "error"
  );

  if (fatal) process.exit(1);
}

const contract = output.contracts?.["CybraToken.sol"]?.["CybraToken"];

if (!contract) {
  console.error("ERROR: CybraToken contract not found");
  process.exit(1);
}

const bytecode = contract.evm.bytecode.object;
const abi = contract.abi;

if (!bytecode || bytecode.length < 1000) {
  console.error("ERROR: deployment bytecode is missing or suspiciously short");
  console.error("HEX chars:", bytecode.length);
  process.exit(1);
}

fs.mkdirSync("./contracts", { recursive: true });

fs.writeFileSync(
  "./contracts/CybraToken.bin",
  "0x" + bytecode + "\n"
);

fs.writeFileSync(
  "./contracts/CybraToken.abi",
  JSON.stringify(abi, null, 2) + "\n"
);

console.log("================================");
console.log("CYBRA COMPILATION SUCCESS");
console.log("================================");
console.log("Solidity: 0.8.19");
console.log("EVM: paris");
console.log("Optimizer: ON");
console.log("Runs: 200");
console.log("Bytecode bytes:", bytecode.length / 2);
console.log("ABI entries:", abi.length);
console.log("PUSH0 occurrences:", (bytecode.match(/5f/g) || []).length);
console.log("BIN:", "./contracts/CybraToken.bin");
console.log("ABI:", "./contracts/CybraToken.abi");
