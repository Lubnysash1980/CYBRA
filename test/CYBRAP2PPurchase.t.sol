// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CYBRAP2PPurchase.sol";

contract MockCYBRA {

    string public name = "Mock CYBRA";
    string public symbol = "CYBRA";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256))
        public allowance;

    function mint(
        address to,
        uint256 amount
    ) external {
        balanceOf[to] += amount;
    }

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) external returns (bool) {
        require(
            balanceOf[msg.sender] >= amount,
            "BALANCE"
        );

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(
            balanceOf[from] >= amount,
            "BALANCE"
        );

        require(
            allowance[from][msg.sender] >= amount,
            "ALLOWANCE"
        );

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract CYBRAP2PPurchaseTest is Test {

    MockCYBRA token;
    CYBRAP2PPurchase escrow;

    address parliament =
        address(0xA12);

    address buyer =
        address(0xA12);

    address seller =
        address(0xA12);

    uint256 constant AMOUNT =
        10_000 ether;

    bytes32 constant ORDER_HASH =
        keccak256("ORDER-0001");

    bytes32 constant TERMS_HASH =
        keccak256("TERMS-0001");

    function setUp() public {

        token = new MockCYBRA();

        escrow = new CYBRAP2PPurchase(
            address(token),
            parliament
        );

        token.mint(
            buyer,
            AMOUNT
        );
    }

    function _create()
        internal
        returns (uint256 id)
    {
        vm.prank(parliament);

        id = escrow.createAgreement(
            buyer,
            seller,
            AMOUNT,
            ORDER_HASH,
            TERMS_HASH,
            block.timestamp + 7 days,
            2
        );
    }

    function _signAndFund(
        uint256 id
    )
        internal
    {
        vm.prank(buyer);
        escrow.buyerSign(id);

        vm.prank(seller);
        escrow.sellerSign(id);

        vm.prank(buyer);
        token.approve(
            address(escrow),
            AMOUNT
        );

        vm.prank(buyer);
        escrow.fund(id);
    }

    // ------------------------------------------------------------
    // CREATE
    // ------------------------------------------------------------

    function test_CreateAgreement()
        public
    {
        uint256 id = _create();

        (
            address b,
            address s,
            uint256 amount,
            ,
            ,
            ,
            uint256 deadline,
            uint256 required,
            uint256 confirmed,
            CYBRAP2PPurchase.Status status,
            bool buyerSigned,
            bool sellerSigned
        ) = escrow.agreements(id);

        assertEq(b, buyer);
        assertEq(s, seller);
        assertEq(amount, AMOUNT);
        assertGt(deadline, block.timestamp);
        assertEq(required, 2);
        assertEq(confirmed, 0);

        assertEq(
            uint256(status),
            uint256(
                CYBRAP2PPurchase.Status.CREATED
            )
        );

        assertFalse(buyerSigned);
        assertFalse(sellerSigned);
    }

    // ------------------------------------------------------------
    // FUND
    // ------------------------------------------------------------

    function test_FundEscrow()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        assertEq(
            token.balanceOf(address(escrow)),
            AMOUNT
        );

        assertEq(
            escrow.escrowBalance(),
            AMOUNT
        );

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            CYBRAP2PPurchase.Status status,
            ,
        ) = escrow.agreements(id);

        assertEq(
            uint256(status),
            uint256(
                CYBRAP2PPurchase.Status.FUNDED
            )
        );
    }

    // ------------------------------------------------------------
    // TRUE_100 CANNOT HAPPEN EARLY
    // ------------------------------------------------------------

    function test_TRUE100CannotHappenBeforeAllEvidence()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("DELIVERY")
        );

        vm.prank(buyer);

        escrow.confirmEvidence(
            id,
            0
        );

        assertFalse(
            escrow.isTRUE100(id)
        );
    }

    // ------------------------------------------------------------
    // TRUE_100 AFTER 100%
    // ------------------------------------------------------------

    function test_TRUE100OnlyAfterAllRequiredEvidence()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("DELIVERY")
        );

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("RECEIPT")
        );

        vm.prank(buyer);

        escrow.confirmEvidence(
            id,
            0
        );

        assertFalse(
            escrow.isTRUE100(id)
        );

        vm.prank(buyer);

        escrow.confirmEvidence(
            id,
            1
        );

        assertTrue(
            escrow.isTRUE100(id)
        );
    }

    // ------------------------------------------------------------
    // SELLER CANNOT TAKE MONEY EARLY
    // ------------------------------------------------------------

    function test_SellerCannotWithdrawBeforeTRUE100()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        vm.prank(seller);

        vm.expectRevert(
            "TRUE_100_REQUIRED"
        );

        escrow.releaseToSeller(id);
    }

    // ------------------------------------------------------------
    // SELLER GETS MONEY AFTER TRUE_100
    // ------------------------------------------------------------

    function test_SellerPaidOnlyAfterTRUE100()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("DELIVERY")
        );

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("RECEIPT")
        );

        vm.prank(buyer);
        escrow.confirmEvidence(id, 0);

        vm.prank(buyer);
        escrow.confirmEvidence(id, 1);

        uint256 sellerBefore =
            token.balanceOf(seller);

        vm.prank(seller);

        escrow.releaseToSeller(id);

        assertEq(
            token.balanceOf(seller),
            sellerBefore + AMOUNT
        );
    }

    // ------------------------------------------------------------
    // REFUND
    // ------------------------------------------------------------

    function test_RefundAfterDeadlineIfNotTRUE100()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        uint256 buyerBefore =
            token.balanceOf(buyer);

        vm.warp(
            block.timestamp + 7 days
        );

        vm.prank(buyer);

        escrow.refund(id);

        assertEq(
            token.balanceOf(buyer),
            buyerBefore + AMOUNT
        );

        assertEq(
            escrow.escrowBalance(),
            0
        );
    }

    // ------------------------------------------------------------
    // REFUND IMPOSSIBLE AFTER TRUE_100
    // ------------------------------------------------------------

    function test_RefundImpossibleAfterTRUE100()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("ONE")
        );

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("TWO")
        );

        vm.prank(buyer);
        escrow.confirmEvidence(id, 0);

        vm.prank(buyer);
        escrow.confirmEvidence(id, 1);

        vm.warp(
            block.timestamp + 7 days
        );

        vm.prank(buyer);

        vm.expectRevert(
            "REFUND_NOT_AVAILABLE"
        );

        escrow.refund(id);
    }

    // ------------------------------------------------------------
    // DUPLICATE CONFIRMATION
    // ------------------------------------------------------------

    function test_CannotConfirmEvidenceTwice()
        public
    {
        uint256 id = _create();

        _signAndFund(id);

        vm.prank(seller);

        escrow.submitEvidence(
            id,
            keccak256("ONE")
        );

        vm.prank(buyer);

        escrow.confirmEvidence(id, 0);

        vm.prank(buyer);

        vm.expectRevert(
            "ALREADY_CONFIRMED"
        );

        escrow.confirmEvidence(id, 0);
    }

    // ------------------------------------------------------------
    // WRONG BUYER
    // ------------------------------------------------------------

    function test_WrongBuyerCannotSign()
        public
    {
        uint256 id = _create();

        vm.prank(address(0xA12));

        vm.expectRevert(
            "ONLY_BUYER"
        );

        escrow.buyerSign(id);
    }

    // ------------------------------------------------------------
    // WRONG SELLER
    // ------------------------------------------------------------

    function test_WrongSellerCannotSign()
        public
    {
        uint256 id = _create();

        vm.prank(address(0xA12));

        vm.expectRevert(
            "ONLY_SELLER"
        );

        escrow.sellerSign(id);
    }

    // ------------------------------------------------------------
    // PARLIAMENT ONLY CREATE
    // ------------------------------------------------------------

    function test_OnlyParliamentCanCreate()
        public
    {
        vm.prank(buyer);

        vm.expectRevert(
            "ONLY_CYBRA_PARLIAMENT"
        );

        escrow.createAgreement(
            buyer,
            seller,
            AMOUNT,
            ORDER_HASH,
            TERMS_HASH,
            block.timestamp + 7 days,
            2
        );
    }
}

// ============================================================
// USDT-style compatibility tests
// ============================================================

contract USDTStyleToken {
    // Returns NOTHING from transfer/transferFrom — like real USDT on Ethereum.
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    function transfer(address to, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "NO_BAL");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
    }
    function transferFrom(address from, address to, uint256 amount) external {
        require(balanceOf[from] >= amount, "NO_BAL");
        require(allowance[from][msg.sender] >= amount, "NO_ALLOW");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

contract FalseReturningToken {
    // Returns false instead of transferring — malicious / broken token.
    function balanceOf(address) external pure returns (uint256) { return 0; }
    function transfer(address, uint256) external pure returns (bool) { return false; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return false; }
}

contract P2PPurchaseSafeTransferTest is Test {
    CYBRAP2PPurchase p;
    USDTStyleToken usdt;

    address buyer      = address(0xA12);
    address seller     = address(0xA12);
    address parliament = address(0xA12);

    uint256 constant AMOUNT = 1000e18;

    function setUp() public {
        usdt = new USDTStyleToken();
        p = new CYBRAP2PPurchase(address(usdt), parliament);

        usdt.mint(buyer, AMOUNT * 10);

        vm.prank(buyer);
        usdt.approve(address(p), type(uint256).max);
    }

    function _createAgreement() internal returns (uint256 id) {
        vm.prank(parliament);
        id = p.createAgreement(
            buyer, seller, AMOUNT,
            keccak256("order"), keccak256("terms"),
            block.timestamp + 1 days, 1
        );
    }

    function test_usdtStyle_fundSucceeds() public {
        uint256 id = _createAgreement();

        vm.prank(buyer); p.buyerSign(id);
        vm.prank(seller); p.sellerSign(id);

        uint256 before = usdt.balanceOf(address(p));
        vm.prank(buyer); p.fund(id);
        uint256 afterBal = usdt.balanceOf(address(p));

        assertEq(afterBal - before, AMOUNT);
    }

    function test_usdtStyle_releaseToSellerSucceeds() public {
        uint256 id = _createAgreement();
        vm.prank(buyer); p.buyerSign(id);
        vm.prank(seller); p.sellerSign(id);
        vm.prank(buyer); p.fund(id);

        vm.prank(seller);
        p.submitEvidence(id, keccak256("ev"));
        vm.prank(buyer);
        p.confirmEvidence(id, 0);
        // status = TRUE_100

        uint256 before = usdt.balanceOf(seller);
        p.releaseToSeller(id);
        assertEq(usdt.balanceOf(seller) - before, AMOUNT);
    }

    function test_falseReturningToken_revertsOnFund() public {
        FalseReturningToken bad = new FalseReturningToken();
        CYBRAP2PPurchase p2 = new CYBRAP2PPurchase(address(bad), parliament);

        vm.prank(parliament);
        uint256 id = p2.createAgreement(
            buyer, seller, AMOUNT,
            keccak256("order"), keccak256("terms"),
            block.timestamp + 1 days, 1
        );

        vm.prank(buyer); p2.buyerSign(id);
        vm.prank(seller); p2.sellerSign(id);

        vm.prank(buyer);
        vm.expectRevert();
        p2.fund(id);
    }
}
