pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/CYBRAP2PPurchase.sol";

contract MockCYBRAP2PTokenV3 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
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
        require(balanceOf[msg.sender] >= amount, "BALANCE");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "BALANCE");
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

contract CYBRAP2PPurchaseDeadlineSecurityTestV3 is Test {
    MockCYBRAP2PTokenV3 token;
    CYBRAP2PPurchase purchase;

    address internal parliament = address(0xA11CE);
    address internal buyer = address(0xB0B);
    address internal seller = address(0xC0C);

    uint256 internal constant AMOUNT = 100 ether;

    uint256 internal deadline;

    function setUp() public {
        token = new MockCYBRAP2PTokenV3();

        purchase = new CYBRAP2PPurchase(
            address(token),
            parliament
        );

        deadline = block.timestamp + 1 days;

        token.mint(buyer, 1000 ether);

        vm.prank(buyer);
        token.approve(
            address(purchase),
            type(uint256).max
        );
    }

    function _createAgreement()
        internal
        returns (uint256 id)
    {
        vm.prank(parliament);

        id = purchase.createAgreement(
            buyer,
            seller,
            AMOUNT,
            keccak256("ORDER-1"),
            keccak256("TERMS-1"),
            deadline,
            1
        );
    }

    function _signAndFund(uint256 id) internal {
        vm.prank(buyer);
        purchase.buyerSign(id);

        vm.prank(seller);
        purchase.sellerSign(id);

        vm.prank(buyer);
        purchase.fund(id);
    }

    function test_BuyerCannotSignAfterDeadline() public {
        uint256 id = _createAgreement();

        vm.warp(deadline);

        vm.prank(buyer);

        vm.expectRevert(
            bytes("DEADLINE_PASSED")
        );

        purchase.buyerSign(id);
    }

    function test_SellerCannotSignAfterDeadline() public {
        uint256 id = _createAgreement();

        vm.warp(deadline);

        vm.prank(seller);

        vm.expectRevert(
            bytes("DEADLINE_PASSED")
        );

        purchase.sellerSign(id);
    }

    function test_ConfirmEvidenceAfterDeadlineCannotCreateTRUE100()
        public
    {
        uint256 id = _createAgreement();

        _signAndFund(id);

        vm.prank(seller);

        purchase.submitEvidence(
            id,
            keccak256("EVIDENCE-1")
        );

        vm.warp(deadline);

        vm.prank(buyer);

        vm.expectRevert(
            bytes("DEADLINE_PASSED")
        );

        purchase.confirmEvidence(id, 0);

        assertFalse(
            purchase.isTRUE100(id)
        );

        (
            ,
            ,
            ,
            bool confirmed
        ) = purchase.getEvidence(id, 0);

        assertFalse(confirmed);
    }

    function test_RefundRemainsAvailableAfterDeadline()
        public
    {
        uint256 id = _createAgreement();

        _signAndFund(id);

        vm.prank(seller);

        purchase.submitEvidence(
            id,
            keccak256("EVIDENCE-REFUND")
        );

        vm.warp(deadline);

        uint256 beforeBalance =
            token.balanceOf(buyer);

        vm.prank(buyer);

        purchase.refund(id);

        uint256 afterBalance =
            token.balanceOf(buyer);

        assertEq(
            afterBalance - beforeBalance,
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
        ) = purchase.agreements(id);

        assertEq(
            uint256(status),
            uint256(
                CYBRAP2PPurchase.Status.REFUNDED
            )
        );

        assertFalse(
            purchase.isTRUE100(id)
        );
    }
}
