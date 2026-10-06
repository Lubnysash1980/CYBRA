pragma solidity ^0.8.19;

/*
    CYBRA SELF-LEARNING V2

    Purpose:
      - register immutable datasets
      - register competing hypotheses
      - register predictions
      - register experiments
      - register evidence
      - require independent verification
      - require holdout verification
      - require EVO before TRUE_100

    IMPORTANT:
      This contract does NOT invent knowledge itself.
      The learning engine operates outside Solidity.
      Solidity stores the auditable state/evidence of learning.
*/

contract CYBRASelfLearningV2 {

    address public owner;
    address public verifier;

    constructor() {
        owner = msg.sender;
        verifier = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    modifier onlyVerifier() {
        require(msg.sender == verifier, "ONLY_VERIFIER");
        _;
    }

    enum DatasetStatus {
        NONE,
        REGISTERED,
        FROZEN,
        REJECTED
    }

    enum HypothesisStatus {
        NONE,
        PROPOSED,
        TESTING,
        SUPPORTED,
        CONTRADICTED,
        INSUFFICIENT_EVIDENCE,
        REJECTED
    }

    enum ExperimentStatus {
        NONE,
        CREATED,
        RUNNING,
        COMPLETED,
        FAILED
    }

    enum RunStatus {
        NONE,
        CREATED,
        RESEARCHING,
        HOLDOUT,
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
        uint256 sampleCount;
        uint256 createdAt;
        uint256 frozenAt;
        DatasetStatus status;
    }

    struct Hypothesis {
        bytes32 hypothesisId;
        bytes32 datasetId;
        bytes32 ruleHash;
        string description;
        HypothesisStatus status;
        uint256 createdAt;
        uint256 testedCount;
        uint256 passCount;
        uint256 failCount;
    }

    struct Experiment {
        bytes32 experimentId;
        bytes32 runId;
        bytes32 hypothesisId;
        bytes32 inputHash;
        bytes32 expectedHash;
        bytes32 actualHash;
        bytes32 evidenceHash;
        uint256 createdAt;
        uint256 completedAt;
        ExperimentStatus status;
        bool holdout;
        bool passed;
    }

    struct LearningRun {
        bytes32 runId;
        bytes32 datasetId;

        bytes32 inputHash;
        bytes32 outputHash;
        bytes32 evidenceHash;

        uint256 hypotheses;
        uint256 experiments;
        uint256 holdoutExperiments;

        uint256 passedExperiments;
        uint256 failedExperiments;

        uint256 requiredChecks;
        uint256 completedChecks;

        uint256 startedAt;
        uint256 completedAt;
        uint256 verifiedAt;

        RunStatus status;

        bool independentVerification;
        bool crossRuntimeVerification;
        bool holdoutVerification;
        bool evoVerification;

        bool candidate;
        bool true100;
        bool verified;
    }

    uint256 public constant CHECK_DATASET = 1;
    uint256 public constant CHECK_INPUT = 2;
    uint256 public constant CHECK_HYPOTHESES = 3;
    uint256 public constant CHECK_EXPERIMENTS = 4;
    uint256 public constant CHECK_EVIDENCE = 5;
    uint256 public constant CHECK_HOLDOUT = 6;
    uint256 public constant CHECK_INDEPENDENT = 7;
    uint256 public constant CHECK_CROSS_RUNTIME = 8;
    uint256 public constant CHECK_EVO = 9;

    uint256 public constant REQUIRED_CHECKS = 9;

    mapping(bytes32 => Dataset) public datasets;
    mapping(bytes32 => Hypothesis) public hypotheses;
    mapping(bytes32 => Experiment) public experiments;
    mapping(bytes32 => LearningRun) public runs;

    mapping(bytes32 => mapping(uint256 => bool)) public checkPassed;

    mapping(bytes32 => bytes32[]) private runHypotheses;
    mapping(bytes32 => bytes32[]) private runExperiments;

    event DatasetRegistered(
        bytes32 indexed datasetId,
        bytes32 contentHash,
        bytes32 manifestHash
    );

    event DatasetFrozen(bytes32 indexed datasetId);

    event HypothesisCreated(
        bytes32 indexed hypothesisId,
        bytes32 indexed datasetId,
        bytes32 ruleHash
    );

    event HypothesisUpdated(
        bytes32 indexed hypothesisId,
        HypothesisStatus status,
        uint256 passCount,
        uint256 failCount
    );

    event ExperimentCreated(
        bytes32 indexed experimentId,
        bytes32 indexed runId,
        bytes32 indexed hypothesisId,
        bool holdout
    );

    event ExperimentCompleted(
        bytes32 indexed experimentId,
        bool passed,
        bytes32 evidenceHash
    );

    event CheckPassed(
        bytes32 indexed runId,
        uint256 indexed checkId
    );

    event LearningRunCreated(
        bytes32 indexed runId,
        bytes32 indexed datasetId
    );

    event LearningRunCompleted(
        bytes32 indexed runId,
        bytes32 outputHash,
        bytes32 evidenceHash
    );

    event True100Approved(bytes32 indexed runId);

    event LearningRejected(
        bytes32 indexed runId,
        string reason
    );

    event VerifierChanged(address indexed verifier);

    function setVerifier(address newVerifier)
        external
        onlyOwner
    {
        require(newVerifier != address(0), "ZERO_VERIFIER");
        verifier = newVerifier;
        emit VerifierChanged(newVerifier);
    }

    function registerDataset(
        bytes32 datasetId,
        bytes32 contentHash,
        bytes32 manifestHash,
        string calldata name,
        string calldata source,
        uint256 sampleCount
    )
        external
        onlyOwner
    {
        require(datasetId != bytes32(0), "BAD_DATASET_ID");
        require(contentHash != bytes32(0), "BAD_CONTENT_HASH");
        require(manifestHash != bytes32(0), "BAD_MANIFEST_HASH");
        require(
            datasets[datasetId].status == DatasetStatus.NONE,
            "DATASET_EXISTS"
        );

        datasets[datasetId] = Dataset({
            datasetId: datasetId,
            contentHash: contentHash,
            manifestHash: manifestHash,
            name: name,
            source: source,
            sampleCount: sampleCount,
            createdAt: block.timestamp,
            frozenAt: 0,
            status: DatasetStatus.REGISTERED
        });

        emit DatasetRegistered(
            datasetId,
            contentHash,
            manifestHash
        );
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

        d.status = DatasetStatus.FROZEN;
        d.frozenAt = block.timestamp;

        emit DatasetFrozen(datasetId);
    }

    function createRun(
        bytes32 runId,
        bytes32 datasetId,
        bytes32 inputHash
    )
        external
        onlyOwner
    {
        require(runId != bytes32(0), "BAD_RUN_ID");
        require(inputHash != bytes32(0), "BAD_INPUT");
        require(
            datasets[datasetId].status == DatasetStatus.FROZEN,
            "DATASET_NOT_FROZEN"
        );
        require(
            runs[runId].status == RunStatus.NONE,
            "RUN_EXISTS"
        );

        runs[runId] = LearningRun({
            runId: runId,
            datasetId: datasetId,
            inputHash: inputHash,
            outputHash: bytes32(0),
            evidenceHash: bytes32(0),
            hypotheses: 0,
            experiments: 0,
            holdoutExperiments: 0,
            passedExperiments: 0,
            failedExperiments: 0,
            requiredChecks: REQUIRED_CHECKS,
            completedChecks: 0,
            startedAt: block.timestamp,
            completedAt: 0,
            verifiedAt: 0,
            status: RunStatus.RESEARCHING,
            independentVerification: false,
            crossRuntimeVerification: false,
            holdoutVerification: false,
            evoVerification: false,
            candidate: true,
            true100: false,
            verified: false
        });

        emit LearningRunCreated(runId, datasetId);
    }

    function createHypothesis(
        bytes32 hypothesisId,
        bytes32 runId,
        bytes32 ruleHash,
        string calldata description
    )
        external
        onlyOwner
    {
        require(
            runs[runId].status == RunStatus.RESEARCHING ||
            runs[runId].status == RunStatus.HOLDOUT,
            "RUN_NOT_RESEARCHING"
        );

        require(
            hypothesisId != bytes32(0),
            "BAD_HYPOTHESIS_ID"
        );

        require(
            ruleHash != bytes32(0),
            "BAD_RULE_HASH"
        );

        require(
            hypotheses[hypothesisId].status == HypothesisStatus.NONE,
            "HYPOTHESIS_EXISTS"
        );

        hypotheses[hypothesisId] = Hypothesis({
            hypothesisId: hypothesisId,
            datasetId: runs[runId].datasetId,
            ruleHash: ruleHash,
            description: description,
            status: HypothesisStatus.PROPOSED,
            createdAt: block.timestamp,
            testedCount: 0,
            passCount: 0,
            failCount: 0
        });

        runHypotheses[runId].push(hypothesisId);
        runs[runId].hypotheses++;

        emit HypothesisCreated(
            hypothesisId,
            runs[runId].datasetId,
            ruleHash
        );
    }

    function updateHypothesis(
        bytes32 hypothesisId,
        HypothesisStatus status,
        uint256 passCount,
        uint256 failCount
    )
        external
        onlyOwner
    {
        Hypothesis storage h = hypotheses[hypothesisId];

        require(
            h.status != HypothesisStatus.NONE,
            "UNKNOWN_HYPOTHESIS"
        );

        require(
            passCount + failCount >= h.testedCount,
            "INVALID_COUNTS"
        );

        h.status = status;
        h.passCount = passCount;
        h.failCount = failCount;

        emit HypothesisUpdated(
            hypothesisId,
            status,
            passCount,
            failCount
        );
    }

    function createExperiment(
        bytes32 experimentId,
        bytes32 runId,
        bytes32 hypothesisId,
        bytes32 inputHash,
        bytes32 expectedHash,
        bool holdout
    )
        external
        onlyOwner
    {
        LearningRun storage r = runs[runId];

        require(
            r.status == RunStatus.RESEARCHING ||
            r.status == RunStatus.HOLDOUT,
            "RUN_NOT_ACTIVE"
        );

        require(
            hypotheses[hypothesisId].status != HypothesisStatus.NONE,
            "UNKNOWN_HYPOTHESIS"
        );

        require(
            experiments[experimentId].status == ExperimentStatus.NONE,
            "EXPERIMENT_EXISTS"
        );

        require(inputHash != bytes32(0), "BAD_INPUT_HASH");
        require(expectedHash != bytes32(0), "BAD_EXPECTED_HASH");

        experiments[experimentId] = Experiment({
            experimentId: experimentId,
            runId: runId,
            hypothesisId: hypothesisId,
            inputHash: inputHash,
            expectedHash: expectedHash,
            actualHash: bytes32(0),
            evidenceHash: bytes32(0),
            createdAt: block.timestamp,
            completedAt: 0,
            status: ExperimentStatus.CREATED,
            holdout: holdout,
            passed: false
        });

        runExperiments[runId].push(experimentId);
        r.experiments++;

        if (holdout) {
            r.holdoutExperiments++;
        }

        emit ExperimentCreated(
            experimentId,
            runId,
            hypothesisId,
            holdout
        );
    }

    function completeExperiment(
        bytes32 experimentId,
        bytes32 actualHash,
        bytes32 evidenceHash,
        bool passed
    )
        external
        onlyOwner
    {
        Experiment storage e = experiments[experimentId];

        require(
            e.status == ExperimentStatus.CREATED ||
            e.status == ExperimentStatus.RUNNING,
            "EXPERIMENT_NOT_ACTIVE"
        );

        require(
            actualHash != bytes32(0),
            "BAD_ACTUAL_HASH"
        );

        require(
            evidenceHash != bytes32(0),
            "BAD_EVIDENCE_HASH"
        );

        e.actualHash = actualHash;
        e.evidenceHash = evidenceHash;
        e.completedAt = block.timestamp;
        e.status = ExperimentStatus.COMPLETED;
        e.passed = passed;

        LearningRun storage r = runs[e.runId];

        if (passed) {
            r.passedExperiments++;
        } else {
            r.failedExperiments++;
        }

        Hypothesis storage h = hypotheses[e.hypothesisId];

        h.testedCount++;

        if (passed) {
            h.passCount++;
        } else {
            h.failCount++;
        }

        emit ExperimentCompleted(
            experimentId,
            passed,
            evidenceHash
        );
    }

    function startHoldout(bytes32 runId)
        external
        onlyOwner
    {
        LearningRun storage r = runs[runId];

        require(
            r.status == RunStatus.RESEARCHING,
            "NOT_RESEARCHING"
        );

        require(
            r.hypotheses > 0,
            "NO_HYPOTHESES"
        );

        require(
            r.experiments > 0,
            "NO_EXPERIMENTS"
        );

        r.status = RunStatus.HOLDOUT;
    }

    function finishResearch(
        bytes32 runId,
        bytes32 outputHash,
        bytes32 evidenceHash
    )
        external
        onlyOwner
    {
        LearningRun storage r = runs[runId];

        require(
            r.status == RunStatus.HOLDOUT,
            "NOT_HOLDOUT"
        );

        require(
            outputHash != bytes32(0),
            "BAD_OUTPUT"
        );

        require(
            evidenceHash != bytes32(0),
            "BAD_EVIDENCE"
        );

        require(
            r.holdoutExperiments > 0,
            "NO_HOLDOUT"
        );

        r.outputHash = outputHash;
        r.evidenceHash = evidenceHash;
        r.completedAt = block.timestamp;
        r.status = RunStatus.VERIFYING;

        emit LearningRunCompleted(
            runId,
            outputHash,
            evidenceHash
        );
    }

    function passCheck(
        bytes32 runId,
        uint256 checkId
    )
        external
        onlyVerifier
    {
        LearningRun storage r = runs[runId];

        require(
            r.status == RunStatus.VERIFYING,
            "NOT_VERIFYING"
        );

        require(
            checkId >= CHECK_DATASET &&
            checkId <= CHECK_EVO,
            "INVALID_CHECK"
        );

        require(
            !checkPassed[runId][checkId],
            "CHECK_ALREADY_PASSED"
        );

        checkPassed[runId][checkId] = true;
        r.completedChecks++;

        if (checkId == CHECK_INDEPENDENT) {
            r.independentVerification = true;
        }

        if (checkId == CHECK_CROSS_RUNTIME) {
            r.crossRuntimeVerification = true;
        }

        if (checkId == CHECK_HOLDOUT) {
            r.holdoutVerification = true;
        }

        if (checkId == CHECK_EVO) {
            r.evoVerification = true;
        }

        emit CheckPassed(runId, checkId);
    }

    function approveTrue100(bytes32 runId)
        external
        onlyVerifier
    {
        LearningRun storage r = runs[runId];

        require(
            r.status == RunStatus.VERIFYING,
            "NOT_VERIFYING"
        );

        require(
            r.completedAt > 0,
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
            r.requiredChecks == REQUIRED_CHECKS,
            "BAD_REQUIRED_CHECKS"
        );

        require(
            r.completedChecks == REQUIRED_CHECKS,
            "NOT_ALL_CHECKS"
        );

        require(
            r.hypotheses > 0,
            "NO_HYPOTHESES"
        );

        require(
            r.experiments > 0,
            "NO_EXPERIMENTS"
        );

        require(
            r.holdoutExperiments > 0,
            "NO_HOLDOUT"
        );

        require(
            r.passedExperiments > 0,
            "NO_PASSED_EXPERIMENT"
        );

        require(
            r.independentVerification,
            "NO_INDEPENDENT_VERIFICATION"
        );

        require(
            r.crossRuntimeVerification,
            "NO_CROSS_RUNTIME"
        );

        require(
            r.holdoutVerification,
            "NO_HOLDOUT_VERIFICATION"
        );

        require(
            r.evoVerification,
            "NO_EVO"
        );

        require(checkPassed[runId][CHECK_DATASET], "CHECK_DATASET");
        require(checkPassed[runId][CHECK_INPUT], "CHECK_INPUT");
        require(checkPassed[runId][CHECK_HYPOTHESES], "CHECK_HYPOTHESES");
        require(checkPassed[runId][CHECK_EXPERIMENTS], "CHECK_EXPERIMENTS");
        require(checkPassed[runId][CHECK_EVIDENCE], "CHECK_EVIDENCE");
        require(checkPassed[runId][CHECK_HOLDOUT], "CHECK_HOLDOUT");
        require(checkPassed[runId][CHECK_INDEPENDENT], "CHECK_INDEPENDENT");
        require(checkPassed[runId][CHECK_CROSS_RUNTIME], "CHECK_CROSS_RUNTIME");
        require(checkPassed[runId][CHECK_EVO], "CHECK_EVO");

        r.true100 = true;
        r.verified = true;
        r.candidate = false;
        r.status = RunStatus.VERIFIED;
        r.verifiedAt = block.timestamp;

        emit True100Approved(runId);
    }

    function rejectRun(
        bytes32 runId,
        string calldata reason
    )
        external
        onlyVerifier
    {
        LearningRun storage r = runs[runId];

        require(
            !r.true100,
            "TRUE100_IMMUTABLE"
        );

        r.status = RunStatus.REJECTED;
        r.candidate = false;
        r.verified = false;
        r.true100 = false;

        emit LearningRejected(runId, reason);
    }

    function isTRUE100(bytes32 runId)
        external
        view
        returns (bool)
    {
        return runs[runId].true100;
    }

    function isVerified(bytes32 runId)
        external
        view
        returns (bool)
    {
        return runs[runId].verified;
    }

    function getProgress(bytes32 runId)
        external
        view
        returns (
            uint256 completed,
            uint256 required,
            bool true100,
            bool verified,
            RunStatus status
        )
    {
        LearningRun storage r = runs[runId];

        return (
            r.completedChecks,
            r.requiredChecks,
            r.true100,
            r.verified,
            r.status
        );
    }

    function getHypotheses(bytes32 runId)
        external
        view
        returns (bytes32[] memory)
    {
        return runHypotheses[runId];
    }

    function getExperiments(bytes32 runId)
        external
        view
        returns (bytes32[] memory)
    {
        return runExperiments[runId];
    }
}
