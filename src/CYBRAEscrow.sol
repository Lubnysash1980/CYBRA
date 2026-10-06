// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICYBRAResponsibility {
    function true100() external view returns (bool);
    function responsibilityOpen() external view returns (bool);
    function buyer() external view returns (address);
    function seller() external view returns (address);
    function RESPONSIBILITY_ID() external view returns (bytes32);
}

contract CYBRAEscrow {

    bytes32 public constant EXPECTED_RESPONSIBILITY_ID =
        keccak256("CYBRA-RESPONSIBILITY-v1");

    enum EscrowStatus { CREATED, FUNDED, RELEASED, SETTLEMENT, REFUNDED }

    ICYBRAResponsibility public immutable responsibility;
    address public immutable buyer;
    address public immutable seller;
    address public immutable arbiter;
    uint256 public immutable settlementTimeout;

    EscrowStatus public status;
    uint256 public depositedAmount;
    uint256 public settlementEnteredAt;

    uint256 private _lock = 1;

    event Deposited(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount);
    event SettlementEntered(uint256 enteredAt);
    event SettledToSeller(address indexed seller, uint256 amount);
    event SettledToBuyer(address indexed buyer, uint256 amount);

    error INVALID_ADDRESS();
    error INVALID_SETTLEMENT_TIMEOUT();
    error RESPONSIBILITY_MISMATCH();
    error RESPONSIBILITY_ID_MISMATCH();
    error NOT_BUYER();
    error NOT_ARBITER();
    error WRONG_STATE();
    error ZERO_DEPOSIT();
    error NOT_TRUE100();
    error NOT_RESPONSIBILITY_OPEN();
    error SETTLEMENT_TIMED_OUT();
    error TRANSFER_FAILED();
    error REENTRANT();

    modifier nonReentrant() {
        if (_lock != 1) revert REENTRANT();
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor(
        address _responsibility,
        address _arbiter,
        uint256 _settlementTimeout
    ) {
        if (_responsibility == address(0) || _arbiter == address(0)) {
            revert INVALID_ADDRESS();
        }
        if (_responsibility.code.length == 0) revert INVALID_ADDRESS();
        if (_settlementTimeout == 0) revert INVALID_SETTLEMENT_TIMEOUT();

        ICYBRAResponsibility r = ICYBRAResponsibility(_responsibility);

        if (r.RESPONSIBILITY_ID() != EXPECTED_RESPONSIBILITY_ID) {
            revert RESPONSIBILITY_ID_MISMATCH();
        }

        address rBuyer  = r.buyer();
        address rSeller = r.seller();

        if (
            rBuyer == address(0) ||
            rSeller == address(0) ||
            rBuyer == rSeller
        ) revert RESPONSIBILITY_MISMATCH();

        responsibility = r;
        buyer = rBuyer;
        seller = rSeller;
        arbiter = _arbiter;
        settlementTimeout = _settlementTimeout;

        status = EscrowStatus.CREATED;
    }

    function deposit() external payable {
        if (msg.sender != buyer) revert NOT_BUYER();
        if (status != EscrowStatus.CREATED) revert WRONG_STATE();
        if (msg.value == 0) revert ZERO_DEPOSIT();

        depositedAmount = msg.value;
        status = EscrowStatus.FUNDED;

        emit Deposited(msg.sender, msg.value);
    }

    function release() external nonReentrant {
        if (status != EscrowStatus.FUNDED) revert WRONG_STATE();
        if (!responsibility.true100()) revert NOT_TRUE100();
        if (responsibility.responsibilityOpen()) revert NOT_TRUE100();

        status = EscrowStatus.RELEASED;
        uint256 amount = depositedAmount;

        (bool ok, ) = seller.call{value: amount}("");
        if (!ok) revert TRANSFER_FAILED();

        emit Released(seller, amount);
    }

    function enterSettlement() external {
        if (status != EscrowStatus.FUNDED) revert WRONG_STATE();
        if (!responsibility.responsibilityOpen()) {
            revert NOT_RESPONSIBILITY_OPEN();
        }

        status = EscrowStatus.SETTLEMENT;
        settlementEnteredAt = block.timestamp;

        emit SettlementEntered(block.timestamp);
    }

    function settleToBuyer() external nonReentrant {
        if (status != EscrowStatus.SETTLEMENT) revert WRONG_STATE();

        bool isArbiter  = msg.sender == arbiter;
        bool isTimedOut =
            block.timestamp >= settlementEnteredAt + settlementTimeout;

        if (!isArbiter && !isTimedOut) revert NOT_ARBITER();

        status = EscrowStatus.REFUNDED;
        uint256 amount = depositedAmount;

        (bool ok, ) = buyer.call{value: amount}("");
        if (!ok) revert TRANSFER_FAILED();

        emit SettledToBuyer(buyer, amount);
    }

    function settleToSeller() external nonReentrant {
        if (msg.sender != arbiter) revert NOT_ARBITER();
        if (status != EscrowStatus.SETTLEMENT) revert WRONG_STATE();
        if (block.timestamp >= settlementEnteredAt + settlementTimeout) {
            revert SETTLEMENT_TIMED_OUT();
        }

        status = EscrowStatus.RELEASED;
        uint256 amount = depositedAmount;

        (bool ok, ) = seller.call{value: amount}("");
        if (!ok) revert TRANSFER_FAILED();

        emit SettledToSeller(seller, amount);
    }
}
