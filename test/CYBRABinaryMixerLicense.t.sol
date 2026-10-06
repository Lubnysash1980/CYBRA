// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRALevelController.sol";
import "../src/CYBRABinaryMixerLicense.sol";

contract CYBRABinaryMixerLicenseTest is Test {
    CYBRALevelController controller;
    CYBRABinaryMixerLicense license;

    bytes32 constant MODULE_ID = keccak256("CYBRA-BINARY-MIXER-001");

    bytes32 constant MODULE_HASH = keccak256("CYBRA-BINARY-MIXER-MODULE");

    bytes32 constant EVIDENCE_HASH = keccak256("CYBRA-BINARY-MIXER-EVIDENCE");

    bytes32 constant SNAPSHOT_HASH = keccak256("CYBRA-BINARY-MIXER-SNAPSHOT");

    function setUp() public {
        controller = new CYBRALevelController(22);

        license = new CYBRABinaryMixerLicense(address(controller));
    }

    function test_StartsBlocked() public {
        assertFalse(controller.true100());
        assertFalse(license.isLicensed(MODULE_ID));
    }

    function test_RegisterModuleRequiresNoTRUE100() public {
        license.registerModule(MODULE_ID, MODULE_HASH, address(this));

        assertFalse(license.isLicensed(MODULE_ID));
    }

    function test_EvidenceDoesNotCreateLicense() public {
        license.registerModule(MODULE_ID, MODULE_HASH, address(this));

        license.recordEvidence(MODULE_ID, EVIDENCE_HASH);

        assertFalse(license.isLicensed(MODULE_ID));
    }

    function test_ActivationBlockedBelow100() public {
        license.registerModule(MODULE_ID, MODULE_HASH, address(this));

        license.recordEvidence(MODULE_ID, EVIDENCE_HASH);

        vm.expectRevert("CYBRA_TRUE100_REQUIRED");
        license.activate(MODULE_ID);

        assertFalse(license.isLicensed(MODULE_ID));
    }

    function test_ActivationRequiresControllerTRUE100() public {
        controller.updateEvidence(100, 100, EVIDENCE_HASH);

        controller.confirmTRUE100();

        license.registerModule(MODULE_ID, MODULE_HASH, address(this));

        license.recordEvidence(MODULE_ID, EVIDENCE_HASH);

        license.activate(MODULE_ID);

        assertTrue(license.isLicensed(MODULE_ID));
    }

    function test_BlockDisablesLicense() public {
        controller.updateEvidence(100, 100, EVIDENCE_HASH);

        controller.confirmTRUE100();

        license.registerModule(MODULE_ID, MODULE_HASH, address(this));

        license.recordEvidence(MODULE_ID, EVIDENCE_HASH);

        license.activate(MODULE_ID);

        assertTrue(license.isLicensed(MODULE_ID));

        license.blockLicense(MODULE_ID, "EVIDENCE_INVALID");

        assertFalse(license.isLicensed(MODULE_ID));
    }

    function test_ControllerTRUE100IsNotCreatedByLicense() public {
        license.registerModule(MODULE_ID, MODULE_HASH, address(this));

        license.recordEvidence(MODULE_ID, EVIDENCE_HASH);

        assertFalse(controller.true100());
        assertFalse(license.isLicensed(MODULE_ID));
    }
}
