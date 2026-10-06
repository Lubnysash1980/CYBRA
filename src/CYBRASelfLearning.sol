// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CYBRASelfLearning {

    address public owner;
    address public verifier;

    enum DatasetStatus {
        NONE,
        REGISTERED,
        FROZEN,
        ANALYZED,
        REJECTED
    }

    enum RunStatus {
        NONE,
        CREATED,
        RUNNING,
        CANDIDATE,
        VERIFYING,
        VERIFIED,
        REJECTED
    }

    struct Dataset {
        bytes32 datasetId;
        bytes32 contentHash;
        bytes32 manifestHash;
        string name;
        string source;
        uint256 documentCount;
        uint256 createdAt;
        uint256 frozenAt;
        DatasetStatus status;
    }

    struct LearningRun {
        bytes32 runId;
        bytes32 datasetId;
        bytes32 inputHash;
        bytes32 outputHash;
        bytes32 evidenceHash;

        uint256 documentsProcessed;
        uint256 knowledgeGenerated;
        uint256 confirmed;
        uint256 rejected;

        uint256 requiredChecks;
        uint256 completedChecks;

        uint256 startedAt;
        uint256 completedAt;
        uint256 verifiedAt;

        RunStatus status;

        bool candidate;
        bool true100;
        bool verified;
    }

    uint256 public constant REQUIRED_CHECK_COUNT = 9;

    bytes32 public constant CHECK_DATASET =
        keccak256("DATASET_INTEGRITY");

    bytes32 public constant CHECK_INPUT =
        keccak256("INPUT_INTEGRITY");

    bytes32 public constant CHECK_OUTPUT =
        keccak256("OUTPUT_INTEGRITY");

    bytes32 public constant CHECK_EVIDENCE =
        keccak256("EVIDENCE");

    bytes32 public constant CHECK_REPRODUCIBILITY =
        keccak256("REPRODUCIBILITY");

    bytes32 public constant CHECK_INDEPENDENT_VERIFICATION =
        keccak256("INDEPENDENT_VERIFICATION");

    bytes32 public constant CHECK_CROSS_RUNTIME =
        keccak256("CROSS_RUNTIME");

    bytes32 public constant CHECK_HOLDOUT =
        keccak256("HOLDOUT");

    bytes32 public constant CHECK_EVO =
        keccak256("EVO");

    mapping(bytes32 => Dataset) public datasets;
    mapping(bytes32 => LearningRun) public learningRuns;

    mapping(bytes32 => mapping(bytes32 => bool))
        public checkPassed;

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    modifier onlyVerifier() {
        require(msg.sender == verifier, "NOT_VERIFIER");
        _;
    }

    constructor(address _verifier) {
        require(_verifier != address(0), "BAD_VERIFIER");

        owner = msg.sender;
        verifier = _verifier;
    }

    function setVerifier(address _verifier)
        external
        onlyOwner
    {
        require(_verifier != address(0), "BAD_VERIFIER");
        verifier = _verifier;
    }

    function registerDataset(
        bytes32 datasetId,
        bytes32 contentHash,
        bytes32 manifestHash,
        string calldata name,
        string calldata source,
        uint256 documentCount
    )
        external
        onlyOwner
    {
        require(
            datasetId != bytes32(0),
            "BAD_DATASET_ID"
        );

        require(
            datasets[datasetId].status ==
                DatasetStatus.NONE,
            "DATASET_EXISTS"
        );

        datasets[datasetId] = Dataset({
            datasetId: datasetId,
            contentHash: contentHash,
            manifestHash: manifestHash,
            name: name,
            source: source,
            documentCount: documentCount,
            createdAt: block.timestamp,
            frozenAt: 0,
            status: DatasetStatus.REGISTERED
        });
    }

    function freezeDataset(bytes32 datasetId)
        external
        onlyOwner
    {
        Dataset storage d = datasets[datasetId];

        require(
            d.status == DatasetStatus.REGISTERED,
            "DATASET_NOT_REGISTERED"
        );

        d.frozenAt = block.timestamp;
        d.status = DatasetStatus.FROZEN;
    }

    function createLearningRun(
        bytes32 runId,
        bytes32 datasetId,
        bytes32 inputHash
    )
        external
        onlyOwner
    {
        require(
            learningRuns[runId].status ==
                RunStatus.NONE,
            "RUN_EXISTS"
        );

        require(
            datasets[datasetId].status ==
                DatasetStatus.FROZEN,
            "DATASET_NOT_FROZEN"
        );

        learningRuns[runId] = LearningRun({
            runId: runId,
            datasetId: datasetId,
            inputHash: inputHash,
            outputHash: bytes32(0),
            evidenceHash: bytes32(0),

            documentsProcessed: 0,
            knowledgeGenerated: 0,
            confirmed: 0,
            rejected: 0,

            requiredChecks: REQUIRED_CHECK_COUNT,
            completedChecks: 0,

            startedAt: 0,
            completedAt: 0,
            verifiedAt: 0,

            status: RunStatus.CREATED,

            candidate: true,
            true100: false,
            verified: false
        });
    }

    function startLearning(bytes32 runId)
        external
        onlyOwner
    {
        LearningRun storage r = learningRuns[runId];

        require(
            r.status == RunStatus.CREATED,
            "BAD_RUN_STATE"
        );

        r.startedAt = block.timestamp;
        r.status = RunStatus.RUNNING;
    }

    function completeLearning(
        bytes32 runId,
        bytes32 outputHash,
        bytes32 evidenceHash,
        uint256 documentsProcessed,
        uint256 knowledgeGenerated,
        uint256 confirmed,
        uint256 rejected
    )
        external
        onlyOwner
    {
        LearningRun storage r = learningRuns[runId];

        require(
            r.status == RunStatus.RUNNING,
            "NOT_RUNNING"
        );

        require(
            outputHash != bytes32(0),
            "OUTPUT_REQUIRED"
        );

        require(
            evidenceHash != bytes32(0),
            "EVIDENCE_REQUIRED"
        );

        r.outputHash = outputHash;
        r.evidenceHash = evidenceHash;

        r.documentsProcessed = documentsProcessed;
        r.knowledgeGenerated = knowledgeGenerated;
        r.confirmed = confirmed;
        r.rejected = rejected;

        r.completedAt = block.timestamp;
        r.status = RunStatus.VERIFYING;
    }

    function passCheck(
        bytes32 runId,
        bytes32 checkId
    )
        external
        onlyVerifier
    {
        LearningRun storage r = learningRuns[runId];

        require(
            r.status == RunStatus.VERIFYING,
            "NOT_VERIFYING"
        );

        require(
            isRequiredCheck(checkId),
            "INVALID_CHECK"
        );

        require(
            !checkPassed[runId][checkId],
            "CHECK_ALREADY_PASSED"
        );

        checkPassed[runId][checkId] = true;
        r.completedChecks++;
    }

    function isRequiredCheck(bytes32 checkId)
        public
        pure
        returns (bool)
    {
        return
            checkId == CHECK_DATASET ||
            checkId == CHECK_INPUT ||
            checkId == CHECK_OUTPUT ||
            checkId == CHECK_EVIDENCE ||
            checkId == CHECK_REPRODUCIBILITY ||
            checkId == CHECK_INDEPENDENT_VERIFICATION ||
            checkId == CHECK_CROSS_RUNTIME ||
            checkId == CHECK_HOLDOUT ||
            checkId == CHECK_EVO;
    }

    function approveTrue100(bytes32 runId)
        external
        onlyVerifier
    {
        LearningRun storage r = learningRuns[runId];

        require(
            r.status == RunStatus.VERIFYING,
            "NOT_VERIFYING"
        );

        require(
            r.completedAt != 0,
            "NOT_COMPLETED"
        );

        require(
            r.outputHash != bytes32(0),
            "NO_OUTPUT"
        );

        require(
            r.evidenceHash != bytes32(0),
            "NO_EVIDENCE"
        );

        require(
            r.requiredChecks ==
                REQUIRED_CHECK_COUNT,
            "BAD_REQUIRED_CHECKS"
        );

        require(
            r.completedChecks ==
                REQUIRED_CHECK_COUNT,
            "CHECKS_INCOMPLETE"
        );

        require(
            r.knowledgeGenerated > 0,
            "NO_KNOWLEDGE"
        );

        require(
            r.confirmed ==
                r.knowledgeGenerated,
            "KNOWLEDGE_NOT_CONFIRMED"
        );

        require(
            r.rejected == 0,
            "REJECTED_KNOWLEDGE"
        );

        require(
            checkPassed[runId][CHECK_DATASET],
            "DATASET_CHECK"
        );

        require(
            checkPassed[runId][CHECK_INPUT],
            "INPUT_CHECK"
        );

        require(
            checkPassed[runId][CHECK_OUTPUT],
            "OUTPUT_CHECK"
        );

        require(
            checkPassed[runId][CHECK_EVIDENCE],
            "EVIDENCE_CHECK"
        );

        require(
            checkPassed[runId][CHECK_REPRODUCIBILITY],
            "REPRODUCIBILITY_CHECK"
        );

        require(
            checkPassed[runId][CHECK_INDEPENDENT_VERIFICATION],
            "INDEPENDENT_CHECK"
        );

        require(
            checkPassed[runId][CHECK_CROSS_RUNTIME],
            "CROSS_RUNTIME_CHECK"
        );

        require(
            checkPassed[runId][CHECK_HOLDOUT],
            "HOLDOUT_CHECK"
        );

        require(
            checkPassed[runId][CHECK_EVO],
            "EVO_CHECK"
        );

        r.true100 = true;
        r.verified = true;
        r.candidate = false;
        r.status = RunStatus.VERIFIED;
        r.verifiedAt = block.timestamp;
    }

    function rejectLearning(bytes32 runId)
        external
        onlyVerifier
    {
        LearningRun storage r = learningRuns[runId];

        require(
            !r.true100,
            "TRUE100_LOCKED"
        );

        r.candidate = false;
        r.verified = false;
        r.true100 = false;
        r.status = RunStatus.REJECTED;
    }

    function isTRUE100(bytes32 runId)
        external
        view
        returns (bool)
    {
        return learningRuns[runId].true100;
    }

    function isVerified(bytes32 runId)
        external
        view
        returns (bool)
    {
        return learningRuns[runId].verified;
    }

    function getProgress(bytes32 runId)
        external
        view
        returns (
            uint256 completed,
            uint256 required,
            bool candidate,
            bool true100,
            bool verified
        )
    {
        LearningRun storage r = learningRuns[runId];

        return (
            r.completedChecks,
            r.requiredChecks,
            r.candidate,
            r.true100,
            r.verified
        );
    }
}
