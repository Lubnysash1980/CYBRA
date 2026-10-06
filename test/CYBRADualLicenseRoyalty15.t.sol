// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRADualLicenseRoyalty15.sol";

contract CYBRADualLicenseRoyalty15Test is Test {

    CYBRADualLicenseRoyalty15 license;

    address verifier1 = address(0x1111);
    address verifier2 = address(0x2222);
    address holder = address(0x3333);

    bytes32 licenseId =
        keccak256("CYBRA-GIT-LICENSE-001");

    bytes32 gitHash =
        keccak256("CYBRA-GIT-COMMIT");

    bytes32 repoHash =
        keccak256("CYBRA-REPOSITORY");

    bytes32 evidence =
        keccak256("EVIDENCE-001");

    function setUp() public {

        license =
            new CYBRADualLicenseRoyalty15(
                verifier1,
                verifier2
            );

        license.registerLicense(
            licenseId,
            gitHash,
            repoHash,
            holder
        );
    }

    function test_StartsBlocked() public {

        assertFalse(
            license.isTRUE100(licenseId)
        );
    }

    function test_FirstVerifierCannotCreateTRUE100()
        public
    {
        vm.prank(verifier1);

        license.approveViolation(
            licenseId,
            evidence
        );

        assertFalse(
            license.isTRUE100(licenseId)
        );

        vm.expectRevert(
            "DUAL_VIOLATION_APPROVAL_REQUIRED"
        );

        license.confirmProfit(
            licenseId,
            10000
        );
    }

    function test_TwoVerifiersConfirmSameEvidence()
        public
    {
        vm.prank(verifier1);

        license.approveViolation(
            licenseId,
            evidence
        );

        vm.prank(verifier2);

        license.approveViolation(
            licenseId,
            evidence
        );

        (
            bool approved1,
            bool approved2,
            bool violationConfirmed
        ) = license.getApprovalState(licenseId);

        assertTrue(approved1);
        assertTrue(approved2);
        assertTrue(violationConfirmed);
    }

    function test_DifferentEvidenceRejected()
        public
    {
        vm.prank(verifier1);

        license.approveViolation(
            licenseId,
            evidence
        );

        vm.prank(verifier2);

        vm.expectRevert(
            "EVIDENCE_HASH_MISMATCH"
        );

        license.approveViolation(
            licenseId,
            keccak256("DIFFERENT-EVIDENCE")
        );
    }

    function test_15PercentRoyalty()
        public
    {
        uint256 profit = 10000;

        uint256 royalty =
            license.calculateRoyalty(profit);

        assertEq(royalty, 1500);
    }

    function test_TRUE100RequiresAllChecks()
        public
    {
        vm.prank(verifier1);

        license.approveViolation(
            licenseId,
            evidence
        );

        vm.prank(verifier2);

        license.approveViolation(
            licenseId,
            evidence
        );

        license.confirmProfit(
            licenseId,
            10000
        );

        license.updateConfirmation(
            licenseId,
            100,
            99
        );

        vm.expectRevert(
            "NOT_ALL_CHECKS_PASSED"
        );

        license.confirmTRUE100(
            licenseId
        );
    }

    function test_TRUE100At100Percent()
        public
    {
        vm.prank(verifier1);

        license.approveViolation(
            licenseId,
            evidence
        );

        vm.prank(verifier2);

        license.approveViolation(
            licenseId,
            evidence
        );

        license.confirmProfit(
            licenseId,
            10000
        );

        license.updateConfirmation(
            licenseId,
            100,
            100
        );

        license.confirmTRUE100(
            licenseId
        );

        assertTrue(
            license.isTRUE100(licenseId)
        );

        (
            uint256 profit,
            uint256 royalty
        ) = license.getRoyaltyState(licenseId);

        assertEq(profit, 10000);
        assertEq(royalty, 1500);
    }
}
