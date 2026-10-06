// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRARefundClaim.sol";

contract CYBRARefundClaimE2ETest is Test {
    CYBRARefundClaim claim;

    address claimant = address(0x111);
    address merchant = address(0x222);
    address verifier = address(0x333);

    bytes32 orderHash = keccak256("E2E-ORDER-001");
    bytes32 paymentHash = keccak256("E2E-PAYMENT-PROOF");
    bytes32 deliveryHash = keccak256("E2E-NOT-RECEIVED-PROOF");
    bytes32 identityHash = keccak256("E2E-IDENTITY-PROOF");

    function setUp() public {
        claim = new CYBRARefundClaim();
        claim.setVerifier(verifier, true);
    }

    function test_E2E_CompleteRefundLifecycle() public {
        vm.prank(claimant);

        uint256 id = claim.createClaim(
            merchant,
            100 ether,
            orderHash,
            2
        );

        assertEq(id, 0);

        assertFalse(
            claim.isTRUE100(id),
            "TRUE100 MUST START FALSE"
        );

        vm.prank(claimant);

        claim.recordEvidence(
            id,
            paymentHash,
            deliveryHash,
            identityHash
        );

        claim.confirmClaim(id);

        assertFalse(
            claim.isTRUE100(id),
            "TRUE100 BEFORE ALL REQUIRED CONFIRMATIONS"
        );

        vm.prank(verifier);

        claim.confirmClaim(id);

        assertTrue(
            claim.isTRUE100(id),
            "TRUE100 NOT REACHED AFTER ALL CONFIRMATIONS"
        );

        claim.authorizeRefund(id);

        claim.markRefunded(id);

        (
            ,
            ,
            uint256 amount_,
            bytes32 orderHash_,
            bytes32 paymentEvidenceHash_,
            bytes32 nonDeliveryEvidenceHash_,
            bytes32 identityEvidenceHash_,
            uint8 requiredConfirmations_,
            uint8 confirmations_,
            CYBRARefundClaim.Status status_,
            bool refundExecuted
        ) = claim.claims(id);

        assertEq(amount_, 100 ether, "WRONG REFUND AMOUNT");

        assertEq(
            orderHash_,
            orderHash,
            "WRONG ORDER HASH"
        );

        assertEq(
            paymentEvidenceHash_,
            paymentHash,
            "WRONG PAYMENT EVIDENCE"
        );

        assertEq(
            nonDeliveryEvidenceHash_,
            deliveryHash,
            "WRONG NONDELIVERY EVIDENCE"
        );

        assertEq(
            identityEvidenceHash_,
            identityHash,
            "WRONG IDENTITY EVIDENCE"
        );

        assertEq(
            requiredConfirmations_,
            2,
            "WRONG REQUIRED CONFIRMATIONS"
        );

        assertEq(
            confirmations_,
            2,
            "WRONG CONFIRMATION COUNT"
        );

        assertTrue(
            refundExecuted,
            "REFUND WAS NOT EXECUTED"
        );

        assertEq(
            uint256(status_),
            uint256(CYBRARefundClaim.Status.REFUNDED),
            "WRONG FINAL STATUS"
        );

        assertTrue(
            claim.isTRUE100(id),
            "TRUE100 LOST AFTER REFUND"
        );
    }
}
