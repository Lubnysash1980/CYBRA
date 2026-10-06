// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRAResponsibilityContract.sol";

contract ResponsibilityTest is Test {
    CYBRAResponsibilityContract r;

    address buyer      = address(0xB0B);
    address seller     = address(0x5E11E4);
    address controller = address(0xC0FFEE);

    bytes32 constant INVOICE_HASH  = keccak256("invoice-rb0518-00742");
    bytes32 constant WRONG_INVOICE = keccak256("wrong-invoice");
    bytes32 constant SELLER_EV     = keccak256("seller-exec");
    bytes32 constant BUYER_EV      = keccak256("buyer-ev");
    bytes32 constant VIOLATION     = keccak256("violation-1");
    bytes32 constant EXP_1         = keccak256("exp-1");
    bytes32 constant EXP_2         = keccak256("exp-2");

    uint256 deadline;

    function setUp() public {
        deadline = block.timestamp + 30 days;
        r = new CYBRAResponsibilityContract(
            buyer, seller, controller, INVOICE_HASH, deadline
        );
    }

    function _seller() internal {
        vm.prank(seller);
        r.sellerConfirmExecution(SELLER_EV);
    }
    function _online() internal {
        vm.prank(controller);
        r.setControllerOnline(true);
    }
    function _invoice() internal {
        vm.prank(buyer);
        r.confirmInvoiceHash(INVOICE_HASH);
    }
    function _buyerConfirm() internal {
        vm.prank(buyer);
        r.buyerConfirm(BUYER_EV);
    }
    function _reject() internal {
        vm.prank(buyer);
        r.buyerReject(VIOLATION, "x");
    }

    function test_true100_fullPath() public {
        _seller(); _online(); _invoice(); _buyerConfirm();
        assertTrue(r.true100());
    }

    function test_true100_blocksWithoutController() public {
        _seller(); _invoice(); _buyerConfirm();
        assertFalse(r.true100());
        vm.expectRevert(CYBRAResponsibilityContract.TRUE100_BLOCKED.selector);
        r.finalizeTRUE100();
    }

    function test_true100_blocksWithoutInvoice() public {
        _seller(); _online(); _buyerConfirm();
        assertFalse(r.true100());
        vm.expectRevert(CYBRAResponsibilityContract.TRUE100_BLOCKED.selector);
        r.finalizeTRUE100();
    }

    function test_true100_blocksWithoutSeller() public {
        _online(); _invoice();
        vm.prank(buyer);
        vm.expectRevert(CYBRAResponsibilityContract.NOT_READY_FOR_CONFIRMATION.selector);
        r.buyerConfirm(BUYER_EV);
    }

    function test_true100_afterLateFinalize() public {
        _seller(); _invoice(); _buyerConfirm();
        assertFalse(r.true100());
        _online();
        r.finalizeTRUE100();
        assertTrue(r.true100());
    }

    function test_sellerCannotConfirmTwice() public {
        _seller();
        vm.prank(seller);
        vm.expectRevert(CYBRAResponsibilityContract.WRONG_STATE.selector);
        r.sellerConfirmExecution(SELLER_EV);
    }

    function test_sellerCannotConfirmAfterReject() public {
        _seller(); _reject();
        vm.prank(seller);
        vm.expectRevert(CYBRAResponsibilityContract.WRONG_STATE.selector);
        r.sellerConfirmExecution(SELLER_EV);
    }

    function test_buyerCannotConfirmTwice() public {
        _seller(); _online(); _invoice(); _buyerConfirm();
        vm.prank(buyer);
        vm.expectRevert(CYBRAResponsibilityContract.ALREADY_TRUE100.selector);
        r.buyerConfirm(BUYER_EV);
    }

    function test_buyerCannotRejectAfterConfirm() public {
        _seller(); _online(); _invoice(); _buyerConfirm();
        vm.prank(buyer);
        vm.expectRevert(CYBRAResponsibilityContract.ALREADY_TRUE100.selector);
        r.buyerReject(VIOLATION, "late");
    }

    function test_sellerCannotConfirmAfterDeadline() public {
        vm.warp(deadline + 1);
        vm.prank(seller);
        vm.expectRevert(CYBRAResponsibilityContract.DEADLINE_PASSED.selector);
        r.sellerConfirmExecution(SELLER_EV);
    }

    function test_openResponsibilityRequiresTimeout() public {
        vm.prank(buyer);
        vm.expectRevert(CYBRAResponsibilityContract.DEADLINE_NOT_PASSED.selector);
        r.openResponsibilityAfterDeadline(VIOLATION);

        vm.warp(deadline + 1);
        vm.prank(buyer);
        r.openResponsibilityAfterDeadline(VIOLATION);
        assertTrue(r.responsibilityOpen());
    }

    function test_controllerFlipDoesNotMoveStatus() public {
        _online();
        vm.prank(controller);
        r.setControllerOnline(false);
        assertEq(uint(r.status()), uint(CYBRAResponsibilityContract.Status.CREATED));
    }

    function test_expensesAppendOnly() public {
        _seller(); _reject();
        vm.startPrank(buyer);
        r.addExpenseEvidence(EXP_1, 100);
        r.addExpenseEvidence(EXP_2, 250);
        vm.stopPrank();
        assertEq(r.expenseEvidenceCount(), 2);
        assertEq(r.verifiedExpenseAmount(), 350);
        assertEq(r.expenseAmounts(EXP_1), 100);
        assertEq(r.expenseAmounts(EXP_2), 250);
    }

    function test_expenseDuplicateReverts() public {
        _seller(); _reject();
        vm.startPrank(buyer);
        r.addExpenseEvidence(EXP_1, 100);
        vm.expectRevert(CYBRAResponsibilityContract.DUPLICATE_EVIDENCE.selector);
        r.addExpenseEvidence(EXP_1, 999);
        vm.stopPrank();
    }

    function test_expenseZeroReverts() public {
        _seller(); _reject();
        vm.prank(buyer);
        vm.expectRevert(CYBRAResponsibilityContract.ZERO_AMOUNT.selector);
        r.addExpenseEvidence(EXP_1, 0);
    }

    function test_invoiceMismatch() public {
        vm.prank(buyer);
        vm.expectRevert(CYBRAResponsibilityContract.INVOICE_HASH_MISMATCH.selector);
        r.confirmInvoiceHash(WRONG_INVOICE);
    }

    function test_invoiceCannotRepeat() public {
        _invoice();
        vm.prank(buyer);
        vm.expectRevert(CYBRAResponsibilityContract.INVOICE_HASH_ALREADY_CONFIRMED.selector);
        r.confirmInvoiceHash(INVOICE_HASH);
    }

    function test_stuckState_isConsciousRule() public {
        _seller();
        vm.warp(deadline + 365 days);
        assertEq(
            uint(r.status()),
            uint(CYBRAResponsibilityContract.Status.CONFIRMATION_REQUIRED)
        );
        assertFalse(r.true100());
        assertFalse(r.responsibilityOpen());
        vm.prank(buyer);
        r.openResponsibilityAfterDeadline(VIOLATION);
        assertTrue(r.responsibilityOpen());
    }

    function test_responsibilityId() public {
        assertEq(
            r.RESPONSIBILITY_ID(),
            keccak256("CYBRA-RESPONSIBILITY-v1")
        );
    }
}
