// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRAExoskeletonAIParliament.sol";

contract CYBRAExoskeletonAIParliamentTest is Test {
    CYBRAExoskeletonAIParliament parliament;

    address verifier = address(0xBEEF);

    function setUp() public {
        parliament =
            new CYBRAExoskeletonAIParliament(verifier);
    }

    function _createAndVerifyLevel(
        uint8 level
    )
        internal
    {
        bytes32 taskHash = keccak256(
            abi.encode(
                "TESTNET",
                level,
                block.timestamp
            )
        );

        vm.prank(verifier);

        uint256 taskId = parliament.addAITask(
            level,
            taskHash,
            string.concat(
                "Exoskeleton TESTNET L",
                vm.toString(level)
            ),
            true
        );

        vm.prank(verifier);
        parliament.confirmAITask(taskId);

        bytes32 evidenceHash = keccak256(
            abi.encode(
                "EVIDENCE",
                taskId,
                level
            )
        );

        vm.prank(verifier);

        parliament.recordEvidence(
            taskId,
            evidenceHash
        );

        parliament.approveTask(taskId);
    }

    function test_TRUE100BlockedUntilAllLevelsVerified()
        public
    {
        _createAndVerifyLevel(1);
        _createAndVerifyLevel(2);
        _createAndVerifyLevel(3);

        assertFalse(
            parliament.isTRUE100(
                CYBRAExoskeletonAIParliament.Stage.TESTNET
            )
        );
    }

    function test_TestnetTRUE100ThenLive()
        public
    {
        _createAndVerifyLevel(1);
        _createAndVerifyLevel(2);
        _createAndVerifyLevel(3);
        _createAndVerifyLevel(4);

        assertTrue(
            parliament.isTRUE100(
                CYBRAExoskeletonAIParliament.Stage.TESTNET
            )
        );

        parliament.activateLive();

        assertEq(
            uint256(
                parliament.stage()
            ),
            uint256(
                CYBRAExoskeletonAIParliament.Stage.LIVE
            )
        );
    }

    function test_MainnetBlockedWithoutLiveTRUE100()
        public
    {
        _createAndVerifyLevel(1);
        _createAndVerifyLevel(2);
        _createAndVerifyLevel(3);
        _createAndVerifyLevel(4);

        parliament.activateLive();

        vm.expectRevert("LIVE_NOT_TRUE100");
        parliament.activateMainnet();
    }

    function test_LiveTRUE100ThenMainnet()
        public
    {
        _createAndVerifyLevel(1);
        _createAndVerifyLevel(2);
        _createAndVerifyLevel(3);
        _createAndVerifyLevel(4);

        parliament.activateLive();

        for (uint8 level = 1; level <= 4; level++) {
            bytes32 taskHash = keccak256(
                abi.encode(
                    "LIVE",
                    level,
                    block.timestamp
                )
            );

            vm.prank(verifier);

            uint256 taskId =
                parliament.addAITask(
                    level,
                    taskHash,
                    string.concat(
                        "Exoskeleton LIVE L",
                        vm.toString(level)
                    ),
                    true
                );

            vm.prank(verifier);
            parliament.confirmAITask(taskId);

            vm.prank(verifier);
            parliament.recordEvidence(
                taskId,
                keccak256(
                    abi.encode(
                        "LIVE_EVIDENCE",
                        taskId
                    )
                )
            );

            parliament.approveTask(taskId);
        }

        assertTrue(
            parliament.isTRUE100(
                CYBRAExoskeletonAIParliament.Stage.LIVE
            )
        );

        parliament.activateMainnet();

        assertTrue(
            parliament.releaseAllowed()
        );
    }
}
