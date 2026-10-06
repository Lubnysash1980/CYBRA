// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CYBRAResponsibilityContract {

    bytes32 public constant RESPONSIBILITY_ID =
        keccak256("CYBRA-RESPONSIBILITY-v1");

    address public immutable buyer;
    address public immutable seller;
    address public immutable eventController;

    string public constant SUPPLIER_NAME = "TOV KOMFI TRADE";
    string public constant BUYER_NAME    = "Hrabovskyi Oleksandr";
    string public constant INVOICE_NUMBER = "RB0518-00742";
    string public constant INVOICE_DATE   = "2026-10-06";

    uint256 public constant INVOICE_AMOUNT_UAH_KOPECK = 13_747_500;

    enum Status {
        CREATED,
        CONFIRMATION_REQUIRED,
        CONFIRMED,
        RESPONSIBILITY_OPEN,
        TRUE_100
    }

    enum Decision { NONE, CONFIRM, REJECT }

    Status   public status;
    Decision public buyerDecision;

    bool public sellerConfirmedExecution;
    bool public eventControllerOnline;
    bool public sellerEvidenceProvided;
    bool public buyerEvidenceProvided;
    bool public invoiceHashConfirmed;
    bool public responsibilityOpen;
    bool public true100;

    uint256 public immutable deadline;

    bytes32 public immutable invoiceHash;
    bytes32 public executionEvidenceHash;
    bytes32 public buyerEvidenceHash;
    bytes32 public violationHash;

    uint256 public verifiedExpenseAmount;
    bytes32[] public expenseEvidenceHashes;
    mapping(bytes32 => uint256) public expenseAmounts;

    event SellerConfirmedExecution(bytes32 indexed evidenceHash);
    event ConfirmationRequired();
    event BuyerConfirmed(bytes32 indexed evidenceHash);
    event BuyerRejected(bytes32 indexed evidenceHash, string reason);
    event ControllerStatusChanged(bool online);
    event InvoiceHashConfirmed(bytes32 indexed invoiceHash);
    event ResponsibilityOpened(bytes32 indexed violationHash);
    event ExpenseEvidenceAdded(bytes32 indexed evidenceHash, uint256 amount);
    event TRUE100();

    error NOT_BUYER();
    error NOT_SELLER();
    error NOT_CONTROLLER();
    error INVALID_ADDRESS();
    error INVALID_DEADLINE();
    error WRONG_STATE();
    error ALREADY_DECIDED();
    error NOT_READY_FOR_CONFIRMATION();
    error ALREADY_TRUE100();
    error RESPONSIBILITY_ALREADY_OPEN();
    error RESPONSIBILITY_NOT_OPEN();
    error TRUE100_BLOCKED();
    error MISSING_SELLER_EVIDENCE();
    error MISSING_BUYER_EVIDENCE();
    error MISSING_VIOLATION_HASH();
    error MISSING_EXPENSE_HASH();
    error DUPLICATE_EVIDENCE();
    error ZERO_AMOUNT();
    error INVOICE_HASH_MISMATCH();
    error INVOICE_HASH_ALREADY_CONFIRMED();
    error DEADLINE_PASSED();
    error DEADLINE_NOT_PASSED();

    modifier onlyBuyer() {
        if (msg.sender != buyer) revert NOT_BUYER();
        _;
    }
    modifier onlySeller() {
        if (msg.sender != seller) revert NOT_SELLER();
        _;
    }
    modifier onlyController() {
        if (msg.sender != eventController) revert NOT_CONTROLLER();
        _;
    }

    constructor(
        address _buyer,
        address _seller,
        address _eventController,
        bytes32 _invoiceHash,
        uint256 _deadline
    ) {
        if (
            _buyer == address(0) ||
            _seller == address(0) ||
            _eventController == address(0)
        ) revert INVALID_ADDRESS();
        if (_deadline <= block.timestamp) revert INVALID_DEADLINE();

        buyer = _buyer;
        seller = _seller;
        eventController = _eventController;
        invoiceHash = _invoiceHash;
        deadline = _deadline;

        status = Status.CREATED;
        buyerDecision = Decision.NONE;
    }

    function setControllerOnline(bool online) external onlyController {
        eventControllerOnline = online;
        emit ControllerStatusChanged(online);
    }

    function confirmInvoiceHash(bytes32 _hash) external onlyBuyer {
        if (invoiceHashConfirmed) revert INVOICE_HASH_ALREADY_CONFIRMED();
        if (_hash != invoiceHash) revert INVOICE_HASH_MISMATCH();
        invoiceHashConfirmed = true;
        emit InvoiceHashConfirmed(_hash);
    }

    function sellerConfirmExecution(
        bytes32 _executionEvidenceHash
    ) external onlySeller {
        if (status != Status.CREATED) revert WRONG_STATE();
        if (block.timestamp > deadline) revert DEADLINE_PASSED();
        if (_executionEvidenceHash == bytes32(0)) {
            revert MISSING_SELLER_EVIDENCE();
        }

        sellerConfirmedExecution = true;
        sellerEvidenceProvided = true;
        executionEvidenceHash = _executionEvidenceHash;

        status = Status.CONFIRMATION_REQUIRED;

        emit SellerConfirmedExecution(_executionEvidenceHash);
        emit ConfirmationRequired();
    }

    function buyerConfirm(bytes32 _buyerEvidenceHash) external onlyBuyer {
        if (true100) revert ALREADY_TRUE100();
        if (responsibilityOpen) revert RESPONSIBILITY_ALREADY_OPEN();
        if (status != Status.CONFIRMATION_REQUIRED) {
            revert NOT_READY_FOR_CONFIRMATION();
        }
        if (buyerDecision != Decision.NONE) revert ALREADY_DECIDED();
        if (_buyerEvidenceHash == bytes32(0)) {
            revert MISSING_BUYER_EVIDENCE();
        }

        buyerDecision = Decision.CONFIRM;
        buyerEvidenceProvided = true;
        buyerEvidenceHash = _buyerEvidenceHash;

        status = Status.CONFIRMED;

        emit BuyerConfirmed(_buyerEvidenceHash);

        _evaluateTRUE100();
    }

    function buyerReject(
        bytes32 _violationHash,
        string calldata reason
    ) external onlyBuyer {
        if (true100) revert ALREADY_TRUE100();
        if (responsibilityOpen) revert RESPONSIBILITY_ALREADY_OPEN();
        if (buyerDecision != Decision.NONE) revert ALREADY_DECIDED();
        if (_violationHash == bytes32(0)) revert MISSING_VIOLATION_HASH();

        buyerDecision = Decision.REJECT;
        _openResponsibility(_violationHash);

        emit BuyerRejected(_violationHash, reason);
    }

    function openResponsibilityAfterDeadline(
        bytes32 _violationHash
    ) external onlyBuyer {
        if (true100) revert ALREADY_TRUE100();
        if (responsibilityOpen) revert RESPONSIBILITY_ALREADY_OPEN();
        if (block.timestamp <= deadline) revert DEADLINE_NOT_PASSED();
        if (buyerDecision != Decision.NONE) revert ALREADY_DECIDED();
        if (_violationHash == bytes32(0)) revert MISSING_VIOLATION_HASH();

        buyerDecision = Decision.REJECT;
        _openResponsibility(_violationHash);
    }

    function _openResponsibility(bytes32 _violationHash) internal {
        responsibilityOpen = true;
        violationHash = _violationHash;
        status = Status.RESPONSIBILITY_OPEN;
        emit ResponsibilityOpened(_violationHash);
    }

    function addExpenseEvidence(
        bytes32 _expenseEvidenceHash,
        uint256 _amount
    ) external onlyBuyer {
        if (!responsibilityOpen) revert RESPONSIBILITY_NOT_OPEN();
        if (_expenseEvidenceHash == bytes32(0)) revert MISSING_EXPENSE_HASH();
        if (_amount == 0) revert ZERO_AMOUNT();
        if (expenseAmounts[_expenseEvidenceHash] != 0) {
            revert DUPLICATE_EVIDENCE();
        }

        expenseAmounts[_expenseEvidenceHash] = _amount;
        expenseEvidenceHashes.push(_expenseEvidenceHash);
        verifiedExpenseAmount += _amount;

        emit ExpenseEvidenceAdded(_expenseEvidenceHash, _amount);
    }

    function expenseEvidenceCount() external view returns (uint256) {
        return expenseEvidenceHashes.length;
    }

    function finalizeTRUE100() external {
        if (true100) revert ALREADY_TRUE100();
        if (status != Status.CONFIRMED) revert NOT_READY_FOR_CONFIRMATION();
        if (!_evaluateTRUE100()) revert TRUE100_BLOCKED();
    }

    function _evaluateTRUE100() internal returns (bool) {
        if (true100) return false;
        if (responsibilityOpen) return false;
        if (!eventControllerOnline) return false;
        if (!invoiceHashConfirmed) return false;
        if (!sellerConfirmedExecution) return false;
        if (!sellerEvidenceProvided) return false;
        if (buyerDecision != Decision.CONFIRM) return false;
        if (!buyerEvidenceProvided) return false;

        true100 = true;
        status = Status.TRUE_100;
        emit TRUE100();
        return true;
    }

    function isTRUE100() external view returns (bool) { return true100; }
    function isPending() external view returns (bool) {
        return buyerDecision == Decision.NONE;
    }
    function canReachTRUE100() external view returns (bool) {
        return
            !true100 &&
            !responsibilityOpen &&
            eventControllerOnline &&
            invoiceHashConfirmed &&
            sellerConfirmedExecution &&
            sellerEvidenceProvided &&
            buyerDecision == Decision.CONFIRM &&
            buyerEvidenceProvided;
    }
}
