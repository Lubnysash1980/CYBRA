// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICYBRALevelController {
    function currentLevel() external view returns (uint256);
    function true100() external view returns (bool);
}

contract CYBRABinaryMixerLicense {
    address public immutable authority;
    ICYBRALevelController public immutable levelController;

    struct License {
        bytes32 moduleHash;
        bytes32 evidenceHash;
        address responsible;
        uint256 level;
        bool active;
        bool blocked;
        uint256 updatedAt;
    }

    mapping(bytes32 => License) public licenses;

    event LicenseRegistered(bytes32 indexed moduleId, bytes32 moduleHash, address indexed responsible);

    event EvidenceRecorded(bytes32 indexed moduleId, bytes32 evidenceHash, uint256 level);

    event LicenseActivated(bytes32 indexed moduleId, uint256 level);

    event LicenseBlocked(bytes32 indexed moduleId, string reason);

    modifier onlyAuthority() {
        require(msg.sender == authority, "NOT_AUTHORITY");
        _;
    }

    constructor(address controller) {
        require(controller != address(0), "EMPTY_CONTROLLER");

        authority = msg.sender;
        levelController = ICYBRALevelController(controller);
    }

    function registerModule(bytes32 moduleId, bytes32 moduleHash, address responsible) external onlyAuthority {
        require(moduleId != bytes32(0), "EMPTY_MODULE_ID");
        require(moduleHash != bytes32(0), "EMPTY_MODULE_HASH");
        require(responsible != address(0), "EMPTY_RESPONSIBLE");

        licenses[moduleId] = License({
            moduleHash: moduleHash,
            evidenceHash: bytes32(0),
            responsible: responsible,
            level: levelController.currentLevel(),
            active: false,
            blocked: false,
            updatedAt: block.timestamp
        });

        emit LicenseRegistered(moduleId, moduleHash, responsible);
    }

    function recordEvidence(bytes32 moduleId, bytes32 evidenceHash) external onlyAuthority {
        License storage l = licenses[moduleId];

        require(l.moduleHash != bytes32(0), "MODULE_NOT_REGISTERED");
        require(!l.blocked, "LICENSE_BLOCKED");
        require(evidenceHash != bytes32(0), "EMPTY_EVIDENCE");

        l.evidenceHash = evidenceHash;
        l.level = levelController.currentLevel();
        l.updatedAt = block.timestamp;

        emit EvidenceRecorded(moduleId, evidenceHash, l.level);
    }

    function activate(bytes32 moduleId) external onlyAuthority {
        License storage l = licenses[moduleId];

        require(l.moduleHash != bytes32(0), "MODULE_NOT_REGISTERED");
        require(l.evidenceHash != bytes32(0), "EVIDENCE_REQUIRED");
        require(!l.blocked, "LICENSE_BLOCKED");

        // The level controller is the source of TRUE_100.
        require(levelController.true100(), "CYBRA_TRUE100_REQUIRED");

        l.level = levelController.currentLevel();
        l.active = true;
        l.updatedAt = block.timestamp;

        emit LicenseActivated(moduleId, l.level);
    }

    function blockLicense(bytes32 moduleId, string calldata reason) external onlyAuthority {
        License storage l = licenses[moduleId];

        require(l.moduleHash != bytes32(0), "MODULE_NOT_REGISTERED");

        l.active = false;
        l.blocked = true;
        l.updatedAt = block.timestamp;

        emit LicenseBlocked(moduleId, reason);
    }

    function isLicensed(bytes32 moduleId) external view returns (bool) {
        License storage l = licenses[moduleId];

        return
            l.moduleHash != bytes32(0) && l.evidenceHash != bytes32(0) && l.active && !l.blocked
                && levelController.true100();
    }
}
