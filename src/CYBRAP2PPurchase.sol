// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20CYBRA {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract CYBRAP2PPurchase {
    enum Status {
        NONE,
        CREATED,
        FUNDED,
        TRUE_100,
        PAID,
        REFUNDED
    }

    struct Evidence {
        bytes32 evidenceHash;
        address submittedBy;
        uint256 timestamp;
        bool confirmed;
    }

    struct Agreement {
        address buyer;
        address seller;
        uint256 amount;
        bytes32 orderHash;
        bytes32 termsHash;
        uint256 createdAt;
        uint256 deadline;
        uint256 requiredEvidence;
        uint256 confirmedEvidence;
        Status status;
        bool buyerSigned;
        bool sellerSigned;
    }

    IERC20CYBRA public immutable cybra;
    address public immutable parliament;

    uint256 public nextAgreementId = 1;

    mapping(uint256 => Agreement) public agreements;

    mapping(uint256 => Evidence[]) private evidences;

    mapping(uint256 => mapping(bytes32 => bool)) private evidenceUsed;

    uint256 private _lock = 1;

    event AgreementCreated(
        uint256 indexed id,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        bytes32 orderHash,
        bytes32 termsHash,
        uint256 deadline,
        uint256 requiredEvidence
    );

    event BuyerSigned(uint256 indexed id, address indexed buyer);

    event SellerSigned(uint256 indexed id, address indexed seller);

    event Funded(uint256 indexed id, uint256 amount);

    event EvidenceSubmitted(
        uint256 indexed id, uint256 indexed evidenceId, bytes32 evidenceHash, address indexed submittedBy
    );

    event EvidenceConfirmed(uint256 indexed id, uint256 indexed evidenceId, address indexed confirmedBy);

    event TRUE100(uint256 indexed id);

    event SellerPaid(uint256 indexed id, uint256 amount);

    event Refunded(uint256 indexed id, uint256 amount);

    modifier onlyParliament() {
        require(msg.sender == parliament, "ONLY_CYBRA_PARLIAMENT");
        _;
    }

    modifier nonReentrant() {
        require(_lock == 1, "REENTRANT");
        _lock = 2;
        _;
        _lock = 1;
    }

    modifier exists(uint256 id) {
        require(agreements[id].status != Status.NONE, "AGREEMENT_NOT_FOUND");
        _;
    }

    constructor(address cybraToken, address cybraParliament) {
        require(cybraToken != address(0), "ZERO_CYBRA");

        require(cybraToken.code.length > 0, "CYBRA_NOT_CONTRACT");

        require(cybraParliament != address(0), "ZERO_PARLIAMENT");

        cybra = IERC20CYBRA(cybraToken);
        parliament = cybraParliament;
    }

    // ------------------------------------------------------------
    // CREATE
    // ------------------------------------------------------------

    function createAgreement(
        address buyer,
        address seller,
        uint256 amount,
        bytes32 orderHash,
        bytes32 termsHash,
        uint256 deadline,
        uint256 requiredEvidence
    ) external onlyParliament returns (uint256 id) {
        require(buyer != address(0), "ZERO_BUYER");

        require(seller != address(0), "ZERO_SELLER");

        require(buyer != seller, "SAME_PARTIES");

        require(amount > 0, "ZERO_AMOUNT");

        require(orderHash != bytes32(0), "ZERO_ORDER_HASH");

        require(termsHash != bytes32(0), "ZERO_TERMS_HASH");

        require(deadline > block.timestamp, "INVALID_DEADLINE");

        require(requiredEvidence > 0, "ZERO_REQUIRED_EVIDENCE");

        id = nextAgreementId++;

        agreements[id] = Agreement({
            buyer: buyer,
            seller: seller,
            amount: amount,
            orderHash: orderHash,
            termsHash: termsHash,
            createdAt: block.timestamp,
            deadline: deadline,
            requiredEvidence: requiredEvidence,
            confirmedEvidence: 0,
            status: Status.CREATED,
            buyerSigned: false,
            sellerSigned: false
        });

        emit AgreementCreated(id, buyer, seller, amount, orderHash, termsHash, deadline, requiredEvidence);
    }

    // ------------------------------------------------------------
    // SIGNING
    // ------------------------------------------------------------

    function buyerSign(uint256 id) external exists(id) {
        Agreement storage a = agreements[id];

        require(msg.sender == a.buyer, "ONLY_BUYER");

        require(a.status == Status.CREATED, "INVALID_STATUS");
        require(block.timestamp < a.deadline, "DEADLINE_PASSED");

        require(!a.buyerSigned, "ALREADY_SIGNED");

        a.buyerSigned = true;

        emit BuyerSigned(id, msg.sender);
    }

    function sellerSign(uint256 id) external exists(id) {
        Agreement storage a = agreements[id];

        require(msg.sender == a.seller, "ONLY_SELLER");

        require(a.status == Status.CREATED, "INVALID_STATUS");
        require(block.timestamp < a.deadline, "DEADLINE_PASSED");

        require(!a.sellerSigned, "ALREADY_SIGNED");

        a.sellerSigned = true;

        emit SellerSigned(id, msg.sender);
    }

    // ------------------------------------------------------------
    // FUND ESCROW
    // ------------------------------------------------------------

    function fund(uint256 id) external exists(id) nonReentrant {
        Agreement storage a = agreements[id];

        require(msg.sender == a.buyer, "ONLY_BUYER");

        require(a.status == Status.CREATED, "INVALID_STATUS");

        require(a.buyerSigned, "BUYER_NOT_SIGNED");

        require(a.sellerSigned, "SELLER_NOT_SIGNED");

        require(block.timestamp < a.deadline, "DEADLINE_PASSED");

        uint256 beforeBalance = cybra.balanceOf(address(this));

        _safeTransferFrom(address(cybra), msg.sender, address(this), a.amount);

        uint256 afterBalance = cybra.balanceOf(address(this));

        require(afterBalance >= beforeBalance, "INVALID_ESCROW_BALANCE");

        require(afterBalance - beforeBalance == a.amount, "INVALID_ESCROW_AMOUNT");

        a.status = Status.FUNDED;

        emit Funded(id, a.amount);
    }

    // ------------------------------------------------------------
    // EVIDENCE
    // ------------------------------------------------------------

    function submitEvidence(uint256 id, bytes32 evidenceHash) external exists(id) returns (uint256 evidenceId) {
        Agreement storage a = agreements[id];

        require(a.status == Status.FUNDED, "NOT_FUNDED");

        require(block.timestamp < a.deadline, "DEADLINE_PASSED");

        require(msg.sender == a.seller || msg.sender == parliament, "NOT_AUTHORIZED");

        require(evidenceHash != bytes32(0), "ZERO_EVIDENCE");

        require(!evidenceUsed[id][evidenceHash], "EVIDENCE_ALREADY_USED");

        require(evidences[id].length < a.requiredEvidence, "REQUIRED_EVIDENCE_REACHED");

        evidenceId = evidences[id].length;

        evidences[id].push(
            Evidence({
                evidenceHash: evidenceHash, submittedBy: msg.sender, timestamp: block.timestamp, confirmed: false
            })
        );

        evidenceUsed[id][evidenceHash] = true;

        emit EvidenceSubmitted(id, evidenceId, evidenceHash, msg.sender);
    }

    // ------------------------------------------------------------
    // CONFIRM EVIDENCE
    // ------------------------------------------------------------

    function confirmEvidence(uint256 id, uint256 evidenceId) external exists(id) {
        Agreement storage a = agreements[id];

        require(msg.sender == a.buyer, "ONLY_BUYER");

        require(a.status == Status.FUNDED, "NOT_FUNDED");
        require(block.timestamp < a.deadline, "DEADLINE_PASSED");

        require(evidenceId < evidences[id].length, "INVALID_EVIDENCE");

        Evidence storage e = evidences[id][evidenceId];

        require(!e.confirmed, "ALREADY_CONFIRMED");

        e.confirmed = true;

        a.confirmedEvidence++;

        emit EvidenceConfirmed(id, evidenceId, msg.sender);

        // TRUE ONLY AT 100%
        if (a.confirmedEvidence == a.requiredEvidence) {
            require(evidences[id].length >= a.requiredEvidence, "REQUIRED_EVIDENCE_MISSING");

            a.status = Status.TRUE_100;

            emit TRUE100(id);
        }
    }

    // ------------------------------------------------------------
    // SELLER PAYMENT
    // ------------------------------------------------------------

    function releaseToSeller(uint256 id) external exists(id) nonReentrant {
        Agreement storage a = agreements[id];

        require(a.status == Status.TRUE_100, "TRUE_100_REQUIRED");

        require(msg.sender == a.seller || msg.sender == parliament, "NOT_AUTHORIZED");

        a.status = Status.PAID;

        _safeTransfer(address(cybra), a.seller, a.amount);

        emit SellerPaid(id, a.amount);
    }

    // ------------------------------------------------------------
    // REFUND
    // ------------------------------------------------------------

    function refund(uint256 id) external exists(id) nonReentrant {
        Agreement storage a = agreements[id];

        require(msg.sender == a.buyer || msg.sender == parliament, "NOT_AUTHORIZED");

        require(a.status == Status.FUNDED, "REFUND_NOT_AVAILABLE");

        require(block.timestamp >= a.deadline, "DEADLINE_NOT_REACHED");

        require(a.confirmedEvidence < a.requiredEvidence, "TRUE_100_REACHED");

        a.status = Status.REFUNDED;

        _safeTransfer(address(cybra), a.buyer, a.amount);

        emit Refunded(id, a.amount);
    }

    // ------------------------------------------------------------
    // VIEWS
    // ------------------------------------------------------------

    function isTRUE100(uint256 id) external view exists(id) returns (bool) {
        return agreements[id].status == Status.TRUE_100;
    }

    function evidenceCount(uint256 id) external view exists(id) returns (uint256) {
        return evidences[id].length;
    }

    function getEvidence(uint256 id, uint256 evidenceId)
        external
        view
        exists(id)
        returns (bytes32 evidenceHash, address submittedBy, uint256 timestamp, bool confirmed)
    {
        require(evidenceId < evidences[id].length, "INVALID_EVIDENCE");

        Evidence memory e = evidences[id][evidenceId];

        return (e.evidenceHash, e.submittedBy, e.timestamp, e.confirmed);
    }

    function escrowBalance() external view returns (uint256) {
        return cybra.balanceOf(address(this));
    }
    // ============================================================
    // SAFE TRANSFER (USDT-compatible)
    // ============================================================

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20CYBRA.transferFrom.selector, from, to, amount));
        require(ok, "SAFE_TRANSFER_FROM_REVERT");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SAFE_TRANSFER_FROM_FALSE");
        }
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20CYBRA.transfer.selector, to, amount));
        require(ok, "SAFE_TRANSFER_REVERT");
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "SAFE_TRANSFER_FALSE");
        }
    }
}
