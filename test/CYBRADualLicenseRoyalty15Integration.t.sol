// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRADualLicenseRoyalty15.sol";
import "../src/CYBRALevelController.sol";

contract CYBRADualLicenseRoyalty15IntegrationTest is Test {
    CYBRADualLicenseRoyalty15 public license;
    CYBRALevelController public controller;

    address internal authority = address(0xA001);
    address internal verifier1 = address(0xB001);
    address internal verifier2 = address(0xB002);
    address internal rightsHolder = address(0xC001);

    bytes32 internal licenseId =
        keccak256("CYBRA-INTEGRATION-LICENSE-001");

    bytes32 internal gitCommitHash =
        keccak256("CYBRA-GIT-COMMIT-TEST");

    bytes32 internal repositoryHash =
        keccak256("CYBRA-REPOSITORY-TEST");

    bytes32 internal evidenceHash =
        keccak256("CYBRA-LICENSE-EVIDENCE-TEST");

    bytes32 internal snapshotHash =
        keccak256("CYBRA-SNAPSHOT-TEST");

    function setUp() public {
        vm.startPrank(authority);

        license = new CYBRADualLicenseRoyalty15(
            verifier1,
            verifier2
        );

        controller = new CYBRALevelController(1);

        vm.stopPrank();
    }

    function _registerAndVerify() internal {
        vm.prank(authority);

        license.registerLicense(
            licenseId,
            gitCommitHash,
            repositoryHash,
            rightsHolder
        );

        vm.prank(verifier1);
        license.approveViolation(
            licenseId,
            evidenceHash
        );

        vm.prank(verifier2);
        license.approveViolation(
            licenseId,
            evidenceHash
        );
    }

    function test_INTEGRATION_StartsBlocked() public {
        assertFalse(license.isTRUE100(licenseId));
        assertFalse(controller.isTRUE100());
    }

    function test_INTEGRATION_LicenseAndControllerBothReach100() public {
        _registerAndVerify();

        vm.prank(authority);
        license.confirmProfit(
            licenseId,
            1000 ether
        );

        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            100
        );

        vm.prank(authority);
        license.confirmTRUE100(licenseId);

        vm.prank(authority);
        controller.updateEvidence(
            100,
            100,
            evidenceHash
        );

        vm.prank(authority);
        controller.confirmTRUE100();

        assertTrue(license.isTRUE100(licenseId));
        assertTrue(controller.true100());
        assertFalse(controller.isTRUE100());
    }

    function test_INTEGRATION_ControllerLifecycleRequired() public {
        _registerAndVerify();

        vm.prank(authority);
        license.confirmProfit(
            licenseId,
            1000 ether
        );

        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            100
        );

        vm.prank(authority);
        license.confirmTRUE100(licenseId);

        vm.prank(authority);
        controller.updateEvidence(
            100,
            100,
            evidenceHash
        );

        vm.prank(authority);
        controller.confirmTRUE100();

        // Evidence-level TRUE_100 is not enough for the full controller gate.
        assertTrue(controller.true100());
        assertFalse(controller.isTRUE100());

        vm.prank(authority);
        controller.createSnapshot(snapshotHash);

        assertFalse(controller.isTRUE100());

        vm.prank(authority);
        controller.enableLive();

        assertFalse(controller.isTRUE100());

        vm.prank(authority);
        controller.openMainnetGate();

        assertTrue(controller.isTRUE100());
        assertTrue(license.isTRUE100(licenseId));
    }

    function test_INTEGRATION_99PercentBlocksBoth() public {
        _registerAndVerify();

        vm.prank(authority);
        license.confirmProfit(
            licenseId,
            1000 ether
        );

        vm.prank(authority);
        license.updateConfirmation(
            licenseId,
            100,
            99
        );

        vm.prank(authority);
        controller.updateEvidence(
            100,
            99,
            evidenceHash
        );

        assertFalse(license.isTRUE100(licenseId));
        assertFalse(controller.true100());
        assertFalse(controller.isTRUE100());

        vm.prank(authority);
        vm.expectRevert("NOT_ALL_CHECKS_PASSED");
        license.confirmTRUE100(licenseId);

        vm.prank(authority);
        vm.expectRevert("NOT_ALL_CHECKS_PASSED");
        controller.confirmTRUE100();
    }

    function test_INTEGRATION_OneVerifierBlocksLicense() public {
        vm.prank(authority);
        license.registerLicense(
            licenseId,
            gitCommitHash,
            repositoryHash,
            rightsHolder
        );

        vm.prank(verifier1);
        license.approveViolation(
            licenseId,
            evidenceHash
        );

        // One verifier is insufficient.
        // Profit confirmation must remain blocked.
        vm.startPrank(authority);
        vm.expectRevert("DUAL_VIOLATION_APPROVAL_REQUIRED");
        license.confirmProfit(
            licenseId,
            1000 ether
        );
        vm.stopPrank();

        assertFalse(license.isTRUE100(licenseId));
    }

    function test_INTEGRATION_MismatchedEvidenceBlocksLicense() public {
        vm.prank(authority);

        license.registerLicense(
            licenseId,
            gitCommitHash,
            repositoryHash,
            rightsHolder
        );

        vm.prank(verifier1);
        license.approveViolation(
            licenseId,
            evidenceHash
        );

        vm.prank(verifier2);
        vm.expectRevert("EVIDENCE_HASH_MISMATCH");

        license.approveViolation(
            licenseId,
            keccak256("DIFFERENT-EVIDENCE")
        );

        assertFalse(license.isTRUE100(licenseId));
    }

    function test_INTEGRATION_MainnetGateCannotOpenEarly() public {
        _registerAndVerify();

        vm.prank(authority);
        vm.expectRevert("TRUE100_REQUIRED");
        controller.openMainnetGate();

        vm.prank(authority);
        controller.updateEvidence(
            100,
            100,
            evidenceHash
        );

        vm.prank(authority);
        vm.expectRevert("TRUE100_REQUIRED");
        controller.openMainnetGate();

        vm.prank(authority);
        controller.confirmTRUE100();

        vm.prank(authority);
        vm.expectRevert("SNAPSHOT_REQUIRED");
        controller.openMainnetGate();
    }

    function test_INTEGRATION_NextLevelBlockedUntilCurrentLifecycleComplete()
        public
    {
        vm.prank(authority);
        controller.updateEvidence(
            100,
            100,
            evidenceHash
        );

        vm.prank(authority);
        vm.expectRevert("CURRENT_LEVEL_NOT_TRUE100");
        controller.advanceLevel();

        vm.prank(authority);
        controller.confirmTRUE100();

        vm.prank(authority);
        vm.expectRevert("CURRENT_SNAPSHOT_REQUIRED");
        controller.advanceLevel();

        vm.prank(authority);
        controller.createSnapshot(snapshotHash);

        vm.prank(authority);
        vm.expectRevert("CURRENT_LIVE_REQUIRED");
        controller.advanceLevel();

        vm.prank(authority);
        controller.enableLive();

        // Mainnet gate is not required by advanceLevel() in the
        // current controller implementation.
        vm.prank(authority);
        controller.advanceLevel();

        assertEq(controller.currentLevel(), 2);
        assertFalse(controller.isTRUE100());
    }
}
