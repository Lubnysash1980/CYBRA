// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CybraToken is ERC20, Ownable {
    string private _logoURI;

    constructor() ERC20("Cybra", "CYBRA") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function setLogoURI(string memory uri) external onlyOwner {
        _logoURI = uri;
    }

    function logoURI() external view returns (string memory) {
        return _logoURI;
    }
}
