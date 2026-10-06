// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CYBRAExoskeletonAIParliament {
    enum Stage {
        TESTNET,
        LIVE,
        MAINNET
    }

    enum Level {
        LEVEL_1,
        LEVEL_2,
        LEVEL_3,
        LEVEL_4
    }

    struct Task {
        uint256 id;
        uint8 level;              // 1..4
        Stage stage;
        bytes32 taskHash;         // офлайн double-SHA / evidence identifier
        bytes32 evidenceHash;     // hash доказу виконання
        string title;

        bool required;
        bool aiConfirmed;
        bool ownerApproved;
        bool verified;
    }

    address public owner;
    address public parliamentVerifier;

    Stage public stage;
    uint256 public nextTaskId = 1;

    // requiredTotal[stage][level]
    mapping(uint8 => mapping(uint8 => uint256)) public requiredTotal;

    // requiredVerified[stage][level]
    mapping(uint8 => mapping(uint8 => uint256)) public requiredVerified;

    mapping(uint256 => Task) public tasks;

    bytes32 public constant TRUE_ONLY_AT_100_PERCENT =
        keccak256("TRUE_ONLY_AT_100_PERCENT_REQUIRED_CONFIRMATION");

    event AITaskCreated(
        uint256 indexed taskId,
        uint8 indexed level,
        uint8 indexed stage,
        bool required,
        bytes32 taskHash
    );

    event AITaskConfirmed(
        uint256 indexed taskId,
        address indexed verifier
    );

    event EvidenceRecorded(
        uint256 indexed taskId,
        bytes32 evidenceHash
    );

    event TaskVerified(
        uint256 indexed taskId,
        address indexed owner
    );

    event LiveActivated();
    event MainnetActivated();

    modifier onlyOwner() {
        require(msg.sender == owner, "OWNER_ONLY");
        _;
    }

    modifier onlyParliament() {
        require(msg.sender == parliamentVerifier, "PARLIAMENT_ONLY");
        _;
    }

    constructor(address verifier) {
        require(verifier != address(0), "BAD_VERIFIER");

        owner = msg.sender;
        parliamentVerifier = verifier;
        stage = Stage.TESTNET;
    }

    function setParliamentVerifier(address verifier)
        external
        onlyOwner
    {
        require(verifier != address(0), "BAD_VERIFIER");
        parliamentVerifier = verifier;
    }

    function addAITask(
        uint8 level,
        bytes32 taskHash,
        string calldata title,
        bool required
    )
        external
        onlyParliament
        returns (uint256 taskId)
    {
        require(stage != Stage.MAINNET, "MAINNET_LOCKED");
        require(level >= 1 && level <= 4, "BAD_LEVEL");
        require(taskHash != bytes32(0), "EMPTY_TASK_HASH");

        taskId = nextTaskId++;

        tasks[taskId] = Task({
            id: taskId,
            level: level,
            stage: stage,
            taskHash: taskHash,
            evidenceHash: bytes32(0),
            title: title,
            required: required,
            aiConfirmed: false,
            ownerApproved: false,
            verified: false
        });

        if (required) {
            requiredTotal[uint8(stage)][level] += 1;
        }

        emit AITaskCreated(
            taskId,
            level,
            uint8(stage),
            required,
            taskHash
        );
    }

    function confirmAITask(uint256 taskId)
        external
        onlyParliament
    {
        Task storage task = tasks[taskId];

        require(task.id != 0, "TASK_NOT_FOUND");
        require(!task.verified, "TASK_ALREADY_VERIFIED");

        task.aiConfirmed = true;

        emit AITaskConfirmed(taskId, msg.sender);
    }

    function recordEvidence(
        uint256 taskId,
        bytes32 evidenceHash
    )
        external
        onlyParliament
    {
        Task storage task = tasks[taskId];

        require(task.id != 0, "TASK_NOT_FOUND");
        require(task.aiConfirmed, "AI_CONFIRMATION_REQUIRED");
        require(evidenceHash != bytes32(0), "EMPTY_EVIDENCE_HASH");

        task.evidenceHash = evidenceHash;

        emit EvidenceRecorded(taskId, evidenceHash);
    }

    function approveTask(uint256 taskId)
        external
        onlyOwner
    {
        Task storage task = tasks[taskId];

        require(task.id != 0, "TASK_NOT_FOUND");
        require(!task.verified, "TASK_ALREADY_VERIFIED");
        require(task.aiConfirmed, "AI_CONFIRMATION_REQUIRED");
        require(
            task.evidenceHash != bytes32(0),
            "EVIDENCE_REQUIRED"
        );

        task.ownerApproved = true;
        task.verified = true;

        if (task.required) {
            requiredVerified[uint8(task.stage)][task.level] += 1;
        }

        emit TaskVerified(taskId, msg.sender);
    }

    function isTRUE100(Stage targetStage)
        public
        view
        returns (bool)
    {
        uint8 s = uint8(targetStage);

        for (uint8 level = 1; level <= 4; level++) {
            if (requiredTotal[s][level] == 0) {
                return false;
            }

            if (
                requiredVerified[s][level] !=
                requiredTotal[s][level]
            ) {
                return false;
            }
        }

        return true;
    }

    function currentStageTRUE100()
        external
        view
        returns (bool)
    {
        return isTRUE100(stage);
    }

    function activateLive()
        external
        onlyOwner
    {
        require(
            stage == Stage.TESTNET,
            "NOT_TESTNET"
        );

        require(
            isTRUE100(Stage.TESTNET),
            "TESTNET_NOT_TRUE100"
        );

        stage = Stage.LIVE;

        emit LiveActivated();
    }

    function activateMainnet()
        external
        onlyOwner
    {
        require(
            stage == Stage.LIVE,
            "NOT_LIVE"
        );

        require(
            isTRUE100(Stage.LIVE),
            "LIVE_NOT_TRUE100"
        );

        stage = Stage.MAINNET;

        emit MainnetActivated();
    }

    function releaseAllowed()
        external
        view
        returns (bool)
    {
        return stage == Stage.MAINNET;
    }

    function getTask(uint256 taskId)
        external
        view
        returns (Task memory)
    {
        return tasks[taskId];
    }
}
