// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CYBRALevelController {
    enum Mode {
        TEST,
        SNAPSHOT,
        LIVE
    }

    struct Level {
        uint256 level;
        uint256 requiredChecks;
        uint256 passedChecks;
        uint256 confirmationPercent;

        bool true100;
        bool snapshotCreated;
        bool liveEnabled;
        bool mainnetGateOpen;

        bytes32 evidenceHash;
        bytes32 snapshotHash;

        uint256 snapshotBlock;
        uint256 snapshotTimestamp;
    }

    address public immutable authority;
    uint256 public currentLevel;
    Mode public mode;

    bool public true100;
    bool public mainnetGateOpen;

    mapping(uint256 => Level) public levels;

    event EvidenceUpdated(
        uint256 indexed level,
        uint256 requiredChecks,
        uint256 passedChecks,
        uint256 confirmationPercent,
        bytes32 evidenceHash
    );

    event TRUE100Confirmed(uint256 indexed level, bytes32 evidenceHash);

    event SnapshotCreated(uint256 indexed level, bytes32 snapshotHash, uint256 blockNumber, uint256 timestamp);

    event LiveEnabled(uint256 indexed level);

    event MainnetGateOpened(uint256 indexed level);

    event LevelAdvanced(uint256 previousLevel, uint256 newLevel);

    modifier onlyAuthority() {
        require(msg.sender == authority, "NOT_AUTHORITY");
        _;
    }

    constructor(uint256 initialLevel) {
        require(initialLevel > 0, "INVALID_LEVEL");

        authority = msg.sender;
        currentLevel = initialLevel;
        mode = Mode.TEST;

        levels[initialLevel] = Level({
            level: initialLevel,
            requiredChecks: 0,
            passedChecks: 0,
            confirmationPercent: 0,
            true100: false,
            snapshotCreated: false,
            liveEnabled: false,
            mainnetGateOpen: false,
            evidenceHash: bytes32(0),
            snapshotHash: bytes32(0),
            snapshotBlock: 0,
            snapshotTimestamp: 0
        });
    }

    function updateEvidence(uint256 requiredChecks, uint256 passedChecks, bytes32 evidenceHash) external onlyAuthority {
        require(requiredChecks > 0, "NO_REQUIRED_CHECKS");
        require(passedChecks <= requiredChecks, "PASSED_GT_REQUIRED");

        uint256 percent = (passedChecks * 100) / requiredChecks;

        Level storage state = levels[currentLevel];

        state.requiredChecks = requiredChecks;
        state.passedChecks = passedChecks;
        state.confirmationPercent = percent;
        state.evidenceHash = evidenceHash;

        if (percent < 100) {
            state.true100 = false;
            state.snapshotCreated = false;
            state.liveEnabled = false;
            state.mainnetGateOpen = false;

            true100 = false;
            mainnetGateOpen = false;
            mode = Mode.TEST;
        }

        emit EvidenceUpdated(currentLevel, requiredChecks, passedChecks, percent, evidenceHash);
    }

    function confirmTRUE100() external onlyAuthority {
        Level storage state = levels[currentLevel];

        require(state.requiredChecks > 0, "NO_REQUIRED_CHECKS");
        require(state.passedChecks == state.requiredChecks, "NOT_ALL_CHECKS_PASSED");
        require(state.confirmationPercent == 100, "CONFIRMATION_NOT_100");
        require(!state.true100, "TRUE100_ALREADY_CONFIRMED");

        state.true100 = true;
        true100 = true;

        emit TRUE100Confirmed(currentLevel, state.evidenceHash);
    }

    function createSnapshot(bytes32 snapshotHash) external onlyAuthority {
        Level storage state = levels[currentLevel];

        require(state.true100, "TRUE100_REQUIRED");
        require(!state.snapshotCreated, "SNAPSHOT_ALREADY_CREATED");
        require(snapshotHash != bytes32(0), "EMPTY_SNAPSHOT_HASH");

        state.snapshotCreated = true;
        state.snapshotHash = snapshotHash;
        state.snapshotBlock = block.number;
        state.snapshotTimestamp = block.timestamp;

        mode = Mode.SNAPSHOT;

        emit SnapshotCreated(currentLevel, snapshotHash, block.number, block.timestamp);
    }

    function enableLive() external onlyAuthority {
        Level storage state = levels[currentLevel];

        require(state.true100, "TRUE100_REQUIRED");
        require(state.snapshotCreated, "SNAPSHOT_REQUIRED");
        require(!state.liveEnabled, "LIVE_ALREADY_ENABLED");

        state.liveEnabled = true;
        mode = Mode.LIVE;

        emit LiveEnabled(currentLevel);
    }

    function openMainnetGate() external onlyAuthority {
        Level storage state = levels[currentLevel];

        require(state.true100, "TRUE100_REQUIRED");
        require(state.snapshotCreated, "SNAPSHOT_REQUIRED");
        require(state.liveEnabled, "LIVE_REQUIRED");
        require(!state.mainnetGateOpen, "MAINNET_ALREADY_OPEN");

        state.mainnetGateOpen = true;
        mainnetGateOpen = true;

        emit MainnetGateOpened(currentLevel);
    }

    function advanceLevel() external onlyAuthority {
        Level storage state = levels[currentLevel];

        require(state.true100, "CURRENT_LEVEL_NOT_TRUE100");
        require(state.snapshotCreated, "CURRENT_SNAPSHOT_REQUIRED");
        require(state.liveEnabled, "CURRENT_LIVE_REQUIRED");

        uint256 previousLevel = currentLevel;
        uint256 nextLevel = previousLevel + 1;

        currentLevel = nextLevel;

        true100 = false;
        mainnetGateOpen = false;
        mode = Mode.TEST;

        levels[nextLevel] = Level({
            level: nextLevel,
            requiredChecks: 0,
            passedChecks: 0,
            confirmationPercent: 0,
            true100: false,
            snapshotCreated: false,
            liveEnabled: false,
            mainnetGateOpen: false,
            evidenceHash: bytes32(0),
            snapshotHash: bytes32(0),
            snapshotBlock: 0,
            snapshotTimestamp: 0
        });

        emit LevelAdvanced(previousLevel, nextLevel);
    }

    function getCurrentState()
        external
        view
        returns (
            uint256 level,
            uint256 requiredChecks,
            uint256 passedChecks,
            uint256 confirmationPercent,
            bool levelTRUE100,
            bool snapshotCreated,
            bool liveEnabled,
            bool levelMainnetGateOpen,
            Mode currentMode,
            bytes32 evidenceHash,
            bytes32 snapshotHash
        )
    {
        Level storage state = levels[currentLevel];

        return (
            state.level,
            state.requiredChecks,
            state.passedChecks,
            state.confirmationPercent,
            state.true100,
            state.snapshotCreated,
            state.liveEnabled,
            state.mainnetGateOpen,
            mode,
            state.evidenceHash,
            state.snapshotHash
        );
    }

    function isTRUE100() external view returns (bool) {
        Level storage state = levels[currentLevel];

        return state.requiredChecks > 0 && state.passedChecks == state.requiredChecks
            && state.confirmationPercent == 100 && state.true100 && state.snapshotCreated && state.liveEnabled
            && state.mainnetGateOpen;
    }
}
