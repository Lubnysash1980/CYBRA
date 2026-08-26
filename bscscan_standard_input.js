const fs = require("fs");

const files = [
  "CybraToken.sol",
  "@openzeppelin/contracts/token/ERC20/ERC20.sol",
  "@openzeppelin/contracts/token/ERC20/IERC20.sol",
  "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol",
  "@openzeppelin/contracts/access/Ownable.sol",
  "@openzeppelin/contracts/utils/Context.sol"
];

const sources = {};

for (const file of files) {
  sources[file] = {
    content: fs.readFileSync(
      file.startsWith("@")
        ? "node_modules/" + file
        : file,
      "utf8"
    )
  };
}

const input = {
  language: "Solidity",
  sources,
  settings: {
    optimizer: {
      enabled: true,
      runs: 200
    },
    outputSelection: {
      "*": {
        "*": [
          "abi",
          "evm.bytecode",
          "evm.deployedBytecode"
        ]
      }
    }
  }
};

fs.writeFileSync(
  "bscscan_standard_input.json",
  JSON.stringify(input, null, 2)
);

console.log("STANDARD_JSON_CREATED");
console.log("OPTIMIZER: true");
console.log("RUNS: 200");
