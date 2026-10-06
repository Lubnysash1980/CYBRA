// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRAResponsibilityContract.sol";
import "../src/CYBRAEscrow.sol";

contract FakeResponsibility {
    address private _b;
    address private _s;
    constructor(address b, address s) { _b = b; _s = s; }
    function true100() external pure returns (bool) { return false; }
    function responsibilityOpen() external pure returns (bool) { return false; }
    function buyer() external view returns (address) { return _b; }
    function seller() external view returns (address) { return _s; }
    function RESPONSIBILITY_ID() external pure returns (bytes32) {
        return keccak256("FAKE");
    }
}

contract EscrowTest is Test {
    CYBRAResponsibilityContract r;
    CYBRAEscrow e;

    address buyer      = address(0xB0B);
    address seller     = address(0x5E11E4);
    address controller = address(0xC0FFEE);
    address arbiter    = address(0xAAB1);
    address stranger   = address(0xDEAD);

    bytes32 constant INVOICE_HASH = keccak256("invoice-rb0518-00742");
    bytes32 constant SELLER_EV    = keccak256("seller-exec");
    bytes32 constant BUYER_EV     = keccak256("buyer-ev");
    bytes32 constant VIOLATION    = keccak256("violation-1");

    uint256 constant DEPOSIT            = 1 ether;
    uint256 constant SETTLEMENT_TIMEOUT = 7 days;

    uint256 deadline;

    function setUp() public {
        vm.deal(buyer, 100 ether);
        deadline = block.timestamp + 30 days;

        r = new CYBRAResponsibilityContract(
            buyer, seller, controller, INVOICE_HASH, deadline
        );
        e = new CYBRAEscrow(address(r), arbiter, SETTLEMENT_TIMEOUT);
    }

    function _fund() internal {
        vm.prank(buyer);
        e.deposit{value: DEPOSIT}();
    }

    function _true100() internal {
        vm.prank(seller);
        r.sellerConfirmExecution(SELLER_EV);
        vm.prank(controller);
        r.setControllerOnline(true);
        vm.prank(buyer);
        r.confirmInvoiceHash(INVOICE_HASH);
        vm.prank(buyer);
        r.buyerConfirm(BUYER_EV);
        assertTrue(r.true100());
    }

    function _respOpen() internal {
        vm.prank(seller);
        r.sellerConfirmExecution(SELLER_EV);
        vm.prank(buyer);
        r.buyerReject(VIOLATION, "x");
        assertTrue(r.responsibilityOpen());
    }

    function test_escrowExpectsV1Id() public {
        assertEq(
            e.EXPECTED_RESPONSIBILITY_ID(),
            keccak256("CYBRA-RESPONSIBILITY-v1")
        );
        assertEq(r.RESPONSIBILITY_ID(), e.EXPECTED_RESPONSIBILITY_ID());
    }

    function test_wrongIdRejected() public {
        FakeResponsibility f = new FakeResponsibility(buyer, seller);
        vm.expectRevert(CYBRAEscrow.RESPONSIBILITY_ID_MISMATCH.selector);
        new CYBRAEscrow(address(f), arbiter, SETTLEMENT_TIMEOUT);
    }

    function test_zeroTimeoutRejected() public {
        vm.expectRevert(CYBRAEscrow.INVALID_SETTLEMENT_TIMEOUT.selector);
        new CYBRAEscrow(address(r), arbiter, 0);
    }

    function test_noCodeRejected() public {
        vm.expectRevert(CYBRAEscrow.INVALID_ADDRESS.selector);
        new CYBRAEscrow(stranger, arbiter, SETTLEMENT_TIMEOUT);
    }

    function test_depositOk() public {
        _fund();
        assertEq(e.depositedAmount(), DEPOSIT);
        assertEq(address(e).balance, DEPOSIT);
    }

    function test_depositOnlyBuyer() public {
        vm.deal(stranger, DEPOSIT);
        vm.deal(stranger, DEPOSIT);
        vm.prank(stranger);
        vm.expectRevert(CYBRAEscrow.NOT_BUYER.selector);
        e.deposit{value: DEPOSIT}();
    }

    function test_depositZeroReverts() public {
        vm.prank(buyer);
        vm.expectRevert(CYBRAEscrow.ZERO_DEPOSIT.selector);
        e.deposit{value: 0}();
    }

    function test_secondDepositReverts() public {
        _fund();
        vm.prank(buyer);
        vm.expectRevert(CYBRAEscrow.WRONG_STATE.selector);
        e.deposit{value: 5 ether}();
    }

    function test_releaseBlockedBeforeTrue100() public {
        _fund();
        vm.expectRevert(CYBRAEscrow.NOT_TRUE100.selector);
        e.release();
    }

    function test_releaseBlockedWhenRespOpen() public {
        _fund(); _respOpen();
        vm.expectRevert(CYBRAEscrow.NOT_TRUE100.selector);
        e.release();
    }

    function test_releaseOk() public {
        _fund(); _true100();
        uint256 before = seller.balance;
        e.release();
        assertEq(seller.balance, before + DEPOSIT);
        assertEq(address(e).balance, 0);
    }

    function test_releaseOnce() public {
        _fund(); _true100();
        e.release();
        vm.expectRevert(CYBRAEscrow.WRONG_STATE.selector);
        e.release();
    }

    function test_enterSettlementNeedsRespOpen() public {
        _fund();
        vm.expectRevert(CYBRAEscrow.NOT_RESPONSIBILITY_OPEN.selector);
        e.enterSettlement();
    }

    function test_enterSettlementOnce() public {
        _fund(); _respOpen();
        e.enterSettlement();
        vm.expectRevert(CYBRAEscrow.WRONG_STATE.selector);
        e.enterSettlement();
    }

    function test_enterSettlementRecordsTime() public {
        _fund(); _respOpen();
        vm.warp(block.timestamp + 123);
        uint256 t = block.timestamp;
        e.enterSettlement();
        assertEq(e.settlementEnteredAt(), t);
    }

    function test_arbiterRefundBeforeTimeout() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.prank(arbiter);
        e.settleToBuyer();
        assertEq(uint(e.status()), uint(CYBRAEscrow.EscrowStatus.REFUNDED));
    }

    function test_arbiterReleaseBeforeTimeout() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.prank(arbiter);
        e.settleToSeller();
        assertEq(uint(e.status()), uint(CYBRAEscrow.EscrowStatus.RELEASED));
    }

    function test_strangerBlockedBeforeTimeout() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.warp(block.timestamp + SETTLEMENT_TIMEOUT - 1);
        vm.prank(stranger);
        vm.expectRevert(CYBRAEscrow.NOT_ARBITER.selector);
        e.settleToBuyer();
    }

    function test_buyerBlockedBeforeTimeout() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.prank(buyer);
        vm.expectRevert(CYBRAEscrow.NOT_ARBITER.selector);
        e.settleToBuyer();
    }

    function test_anyoneRefundsAfterTimeout() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.warp(e.settlementEnteredAt() + SETTLEMENT_TIMEOUT);
        uint256 before = buyer.balance;
        vm.prank(stranger);
        e.settleToBuyer();
        assertEq(buyer.balance, before + DEPOSIT);
    }

    function test_sellerBlockedAfterTimeout() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.warp(e.settlementEnteredAt() + SETTLEMENT_TIMEOUT);
        vm.prank(arbiter);
        vm.expectRevert(CYBRAEscrow.SETTLEMENT_TIMED_OUT.selector);
        e.settleToSeller();
    }

    function test_strangerCannotSellerSettle() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.warp(e.settlementEnteredAt() + SETTLEMENT_TIMEOUT);
        vm.prank(stranger);
        vm.expectRevert(CYBRAEscrow.NOT_ARBITER.selector);
        e.settleToSeller();
    }

    function test_timeoutUsesSettlementEntryTime() public {
        _fund(); _respOpen();
        vm.warp(block.timestamp + 500 days);
        e.enterSettlement();
        uint256 t = block.timestamp;
        vm.warp(t + SETTLEMENT_TIMEOUT - 1);
        vm.prank(stranger);
        vm.expectRevert(CYBRAEscrow.NOT_ARBITER.selector);
        e.settleToBuyer();
        vm.warp(t + SETTLEMENT_TIMEOUT);
        vm.prank(stranger);
        e.settleToBuyer();
        assertEq(uint(e.status()), uint(CYBRAEscrow.EscrowStatus.REFUNDED));
    }

    function test_timeoutNoEffectBeforeSettlement() public {
        _fund(); _respOpen();
        vm.warp(block.timestamp + 3650 days);
        vm.prank(stranger);
        vm.expectRevert(CYBRAEscrow.WRONG_STATE.selector);
        e.settleToBuyer();
    }

    function test_refundOnce() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.prank(arbiter);
        e.settleToBuyer();
        vm.prank(arbiter);
        vm.expectRevert(CYBRAEscrow.WRONG_STATE.selector);
        e.settleToBuyer();
        vm.prank(arbiter);
        vm.expectRevert(CYBRAEscrow.WRONG_STATE.selector);
        e.settleToSeller();
    }

    function test_settleToSellerOnce() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.prank(arbiter);
        e.settleToSeller();
        vm.prank(arbiter);
        vm.expectRevert(CYBRAEscrow.WRONG_STATE.selector);
        e.settleToSeller();
    }

    function test_payoutEqualsDeposit_notBalance() public {
        _fund(); _true100();
        vm.deal(address(e), address(e).balance + 5 ether);
        uint256 before = seller.balance;
        e.release();
        assertEq(seller.balance, before + DEPOSIT);
        assertEq(address(e).balance, 5 ether);
    }

    function test_forcedEthDoesNotChangeAccounting() public {
        _fund();
        vm.deal(address(e), 100 ether);
        assertEq(e.depositedAmount(), DEPOSIT);
    }

    function test_timeoutRefundIgnoresForcedEth() public {
        _fund(); _respOpen(); e.enterSettlement();
        vm.deal(address(e), address(e).balance + 3 ether);
        vm.warp(e.settlementEnteredAt() + SETTLEMENT_TIMEOUT);
        uint256 before = buyer.balance;
        vm.prank(stranger);
        e.settleToBuyer();
        assertEq(buyer.balance, before + DEPOSIT);
        assertEq(address(e).balance, 3 ether);
    }

    function test_directEthTransferReverts() public {
        vm.prank(buyer);
        (bool ok, ) = address(e).call{value: 1 ether}("");
        assertFalse(ok);
    }
}
