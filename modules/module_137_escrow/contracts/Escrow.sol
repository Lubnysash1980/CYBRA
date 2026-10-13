// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Escrow — двосторонній ескроу з арбітражем
contract Escrow {
    enum State { Created, Funded, Released, Refunded, Disputed }

    struct Deal {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        uint64  createdAt;
        uint64  deadline;
        State   state;
        bytes32 cid;
        string  note;
    }

    mapping(bytes32 => Deal) public deals;
    bytes32[] public dealIds;

    event Created(bytes32 indexed cid, bytes32 indexed dealId, address buyer, uint256 amount);
    event Funded(bytes32 indexed cid, bytes32 indexed dealId);
    event Released(bytes32 indexed cid, bytes32 indexed dealId, uint256 amount);
    event Refunded(bytes32 indexed cid, bytes32 indexed dealId, uint256 amount);
    event Disputed(bytes32 indexed cid, bytes32 indexed dealId, string reason);

    error NotFound();
    error BadState();
    error NotParty();
    error TooEarly();
    error TooLate();
    error TransferFailed();

    function create(bytes32 cid, address seller, address arbiter,
                    uint64 deadline, string calldata note) external payable
        returns (bytes32 dealId)
    {
        dealId = keccak256(abi.encodePacked(cid, msg.sender, block.timestamp));
        deals[dealId] = Deal({
            buyer: msg.sender, seller: seller, arbiter: arbiter,
            amount: msg.value, createdAt: uint64(block.timestamp),
            deadline: deadline, state: State.Funded, cid: cid, note: note
        });
        dealIds.push(dealId);
        emit Created(cid, dealId, msg.sender, msg.value);
        emit Funded(cid, dealId);
    }

    /// @notice Покупець підтверджує отримання → гроші йдуть продавцю
    function release(bytes32 dealId) external {
        Deal storage d = deals[dealId];
        if (d.buyer == address(0)) revert NotFound();
        if (d.state != State.Funded) revert BadState();
        if (msg.sender != d.buyer) revert NotParty();
        d.state = State.Released;
        (bool ok,) = d.seller.call{value: d.amount}("");
        if (!ok) revert TransferFailed();
        emit Released(d.cid, dealId, d.amount);
    }

    /// @notice Продавець повертає кошти покупцю
    function refund(bytes32 dealId) external {
        Deal storage d = deals[dealId];
        if (d.buyer == address(0)) revert NotFound();
        if (d.state != State.Funded && d.state != State.Disputed) revert BadState();
        if (msg.sender != d.seller && msg.sender != d.arbiter) revert NotParty();
        d.state = State.Refunded;
        (bool ok,) = d.buyer.call{value: d.amount}("");
        if (!ok) revert TransferFailed();
        emit Refunded(d.cid, dealId, d.amount);
    }

    /// @notice Відкрити спір
    function dispute(bytes32 dealId, string calldata reason) external {
        Deal storage d = deals[dealId];
        if (d.buyer == address(0)) revert NotFound();
        if (msg.sender != d.buyer && msg.sender != d.seller) revert NotParty();
        if (d.state != State.Funded) revert BadState();
        d.state = State.Disputed;
        emit Disputed(d.cid, dealId, reason);
    }

    /// @notice Арбітр вирішує
    function arbitrate(bytes32 dealId, bool toSeller) external {
        Deal storage d = deals[dealId];
        if (d.buyer == address(0)) revert NotFound();
        if (d.state != State.Disputed) revert BadState();
        if (msg.sender != d.arbiter) revert NotParty();
        address payable to = payable(toSeller ? d.seller : d.buyer);
        d.state = toSeller ? State.Released : State.Refunded;
        (bool ok,) = to.call{value: d.amount}("");
        if (!ok) revert TransferFailed();
        if (toSeller) emit Released(d.cid, dealId, d.amount);
        else emit Refunded(d.cid, dealId, d.amount);
    }

    function get(bytes32 dealId) external view returns (Deal memory) {
        return deals[dealId];
    }
}
