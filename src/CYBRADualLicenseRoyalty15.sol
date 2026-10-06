// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CYBRADualLicenseRoyalty15 {

    uint256 public constant ROYALTY_BPS = 1500;
    uint256 public constant BPS = 10000;

    address public immutable authority;
    address public immutable verifier1;
    address public immutable verifier2;

    struct License {
        bytes32 licenseId;
        bytes32 gitCommitHash;
        bytes32 repositoryHash;
        address rightsHolder;

        bool registered;

        bytes32 evidenceHash;

        bool violationApproved1;
        bool violationApproved2;
        bool violationConfirmed;

        uint256 requiredChecks;
        uint256 passedChecks;
        uint256 confirmationPercent;

        uint256 confirmedProfit;
        uint256 royaltyDue;

        bool true100;

        uint256 updatedAt;
    }

    mapping(bytes32 => License) public licenses;

    event LicenseRegistered(
        bytes32 indexed licenseId,
        bytes32 gitCommitHash,
        bytes32 repositoryHash,
        address indexed rightsHolder
    );

    event ViolationApproval(
        bytes32 indexed licenseId,
        address indexed verifier,
        bytes32 evidenceHash
    );

    event ViolationConfirmed(
        bytes32 indexed licenseId,
        bytes32 evidenceHash
    );

    event ProfitConfirmed(
        bytes32 indexed licenseId,
        uint256 profit,
        uint256 royalty
    );

    event ConfirmationUpdated(
        bytes32 indexed licenseId,
        uint256 requiredChecks,
        uint256 passedChecks,
        uint256 percent
    );

    event TRUE100Confirmed(
        bytes32 indexed licenseId,
        bytes32 evidenceHash,
        uint256 profit,
        uint256 royalty
    );

    modifier onlyAuthority() {
        require(msg.sender == authority, "NOT_AUTHORITY");
        _;
    }

    modifier onlyVerifier() {
        require(
            msg.sender == verifier1 || msg.sender == verifier2,
            "NOT_VERIFIER"
        );
        _;
    }

    constructor(
        address _verifier1,
        address _verifier2
    ) {
        require(_verifier1 != address(0), "EMPTY_VERIFIER1");
        require(_verifier2 != address(0), "EMPTY_VERIFIER2");
        require(_verifier1 != _verifier2, "VERIFIERS_MUST_DIFFER");

        authority = msg.sender;
        verifier1 = _verifier1;
        verifier2 = _verifier2;
    }

    function registerLicense(
        bytes32 licenseId,
        bytes32 gitCommitHash,
        bytes32 repositoryHash,
        address rightsHolder
    ) external onlyAuthority {

        require(licenseId != bytes32(0), "EMPTY_LICENSE_ID");
        require(gitCommitHash != bytes32(0), "EMPTY_GIT_HASH");
        require(repositoryHash != bytes32(0), "EMPTY_REPOSITORY_HASH");
        require(rightsHolder != address(0), "EMPTY_RIGHTS_HOLDER");

        licenses[licenseId] = License({
            licenseId: licenseId,
            gitCommitHash: gitCommitHash,
            repositoryHash: repositoryHash,
            rightsHolder: rightsHolder,
            registered: true,
            evidenceHash: bytes32(0),
            violationApproved1: false,
            violationApproved2: false,
            violationConfirmed: false,
            requiredChecks: 0,
            passedChecks: 0,
            confirmationPercent: 0,
            confirmedProfit: 0,
            royaltyDue: 0,
            true100: false,
            updatedAt: block.timestamp
        });

        emit LicenseRegistered(
            licenseId,
            gitCommitHash,
            repositoryHash,
            rightsHolder
        );
    }

    function approveViolation(
        bytes32 licenseId,
        bytes32 evidenceHash
    ) external onlyVerifier {

        License storage l = licenses[licenseId];

        require(l.registered, "LICENSE_NOT_REGISTERED");
        require(evidenceHash != bytes32(0), "EMPTY_EVIDENCE");
        require(!l.violationConfirmed, "VIOLATION_ALREADY_CONFIRMED");

        if (l.evidenceHash == bytes32(0)) {
            l.evidenceHash = evidenceHash;
        } else {
            require(
                l.evidenceHash == evidenceHash,
                "EVIDENCE_HASH_MISMATCH"
            );
        }

        if (msg.sender == verifier1) {
            require(
                !l.violationApproved1,
                "VERIFIER1_ALREADY_APPROVED"
            );

            l.violationApproved1 = true;
        } else {
            require(
                !l.violationApproved2,
                "VERIFIER2_ALREADY_APPROVED"
            );

            l.violationApproved2 = true;
        }

        if (
            l.violationApproved1 &&
            l.violationApproved2
        ) {
            l.violationConfirmed = true;

            emit ViolationConfirmed(
                licenseId,
                evidenceHash
            );
        }

        l.updatedAt = block.timestamp;

        emit ViolationApproval(
            licenseId,
            msg.sender,
            evidenceHash
        );
    }

    function confirmProfit(
        bytes32 licenseId,
        uint256 profit
    ) external onlyAuthority {

        License storage l = licenses[licenseId];

        require(l.registered, "LICENSE_NOT_REGISTERED");
        require(
            l.violationConfirmed,
            "DUAL_VIOLATION_APPROVAL_REQUIRED"
        );
        require(profit > 0, "PROFIT_ZERO");

        uint256 royalty =
            (profit * ROYALTY_BPS) / BPS;

        l.confirmedProfit = profit;
        l.royaltyDue = royalty;
        l.updatedAt = block.timestamp;

        emit ProfitConfirmed(
            licenseId,
            profit,
            royalty
        );
    }

    function updateConfirmation(
        bytes32 licenseId,
        uint256 requiredChecks,
        uint256 passedChecks
    ) external onlyAuthority {

        License storage l = licenses[licenseId];

        require(l.registered, "LICENSE_NOT_REGISTERED");
        require(requiredChecks > 0, "NO_REQUIRED_CHECKS");
        require(
            passedChecks <= requiredChecks,
            "PASSED_GT_REQUIRED"
        );

        uint256 percent =
            (passedChecks * 100) / requiredChecks;

        l.requiredChecks = requiredChecks;
        l.passedChecks = passedChecks;
        l.confirmationPercent = percent;

        if (percent < 100) {
            l.true100 = false;
        }

        l.updatedAt = block.timestamp;

        emit ConfirmationUpdated(
            licenseId,
            requiredChecks,
            passedChecks,
            percent
        );
    }

    function confirmTRUE100(
        bytes32 licenseId
    ) external onlyAuthority {

        License storage l = licenses[licenseId];

        require(l.registered, "LICENSE_NOT_REGISTERED");
        require(
            l.violationApproved1,
            "VERIFIER1_REQUIRED"
        );
        require(
            l.violationApproved2,
            "VERIFIER2_REQUIRED"
        );
        require(
            l.violationConfirmed,
            "VIOLATION_NOT_CONFIRMED"
        );
        require(
            l.confirmedProfit > 0,
            "PROFIT_NOT_CONFIRMED"
        );
        require(
            l.requiredChecks > 0,
            "NO_REQUIRED_CHECKS"
        );
        require(
            l.passedChecks == l.requiredChecks,
            "NOT_ALL_CHECKS_PASSED"
        );
        require(
            l.confirmationPercent == 100,
            "CONFIRMATION_NOT_100"
        );
        require(
            !l.true100,
            "TRUE100_ALREADY_CONFIRMED"
        );

        l.true100 = true;
        l.updatedAt = block.timestamp;

        emit TRUE100Confirmed(
            licenseId,
            l.evidenceHash,
            l.confirmedProfit,
            l.royaltyDue
        );
    }

    function calculateRoyalty(
        uint256 profit
    ) external pure returns (uint256) {
        return (profit * ROYALTY_BPS) / BPS;
    }

    function getApprovalState(
        bytes32 licenseId
    )
        external
        view
        returns (
            bool approved1,
            bool approved2,
            bool violationConfirmed
        )
    {
        License storage l = licenses[licenseId];

        return (
            l.violationApproved1,
            l.violationApproved2,
            l.violationConfirmed
        );
    }

    function getRoyaltyState(
        bytes32 licenseId
    )
        external
        view
        returns (
            uint256 profit,
            uint256 royalty
        )
    {
        License storage l = licenses[licenseId];

        return (
            l.confirmedProfit,
            l.royaltyDue
        );
    }

    function isTRUE100(
        bytes32 licenseId
    ) external view returns (bool) {

        License storage l = licenses[licenseId];

        return
            l.registered &&
            l.violationApproved1 &&
            l.violationApproved2 &&
            l.violationConfirmed &&
            l.confirmedProfit > 0 &&
            l.requiredChecks > 0 &&
            l.passedChecks == l.requiredChecks &&
            l.confirmationPercent == 100 &&
            l.true100;
    }

    function royaltyRate()
        external
        pure
        returns (
            uint256 numerator,
            uint256 denominator
        )
    {
        return (15, 100);
    }
}
