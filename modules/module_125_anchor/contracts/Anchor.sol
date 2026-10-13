// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Anchor — незмінний timestamp для хешів документів
contract Anchor {
    struct Entry {
        bytes32 hash;
        bytes32 cid;
        address publisher;
        uint64  timestamp;
        string  note;
    }

    mapping(bytes32 => Entry) public entries;
    bytes32[] public all;

    event Anchored(bytes32 indexed hash, bytes32 indexed cid, address publisher, uint64 at);

    error AlreadyAnchored();

    function anchor(bytes32 cid, bytes32 hash, string calldata note) external {
        if (entries[hash].publisher != address(0)) revert AlreadyAnchored();
        entries[hash] = Entry({
            hash: hash, cid: cid, publisher: msg.sender,
            timestamp: uint64(block.timestamp), note: note
        });
        all.push(hash);
        emit Anchored(hash, cid, msg.sender, uint64(block.timestamp));
    }

    function verify(bytes32 hash) external view returns (bool, address, uint64) {
        Entry memory e = entries[hash];
        return (e.publisher != address(0), e.publisher, e.timestamp);
    }

    function count() external view returns (uint256) {
        return all.length;
    }
}
