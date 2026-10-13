// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Reputation {
    struct Rating { uint8 score; bytes32 cid; address rater; uint64 at; }
    mapping(address => Rating[]) public ratings;
    mapping(address => uint256) public sumScores;
    mapping(address => uint256) public countRatings;
    mapping(bytes32 => bool) public ratedOnce;

    event Rated(address indexed subject, address indexed rater, uint8 score, bytes32 cid);

    function rate(address subject, uint8 score, bytes32 cid) external {
        require(score >= 1 && score <= 5, "score 1-5");
        bytes32 key = keccak256(abi.encodePacked(subject, msg.sender, cid));
        require(!ratedOnce[key], "already rated for this cid");
        ratedOnce[key] = true;
        ratings[subject].push(Rating(score, cid, msg.sender, uint64(block.timestamp)));
        sumScores[subject] += score;
        countRatings[subject] += 1;
        emit Rated(subject, msg.sender, score, cid);
    }

    function avgScore(address subject) external view returns (uint256) {
        if (countRatings[subject] == 0) return 0;
        return (sumScores[subject] * 100) / countRatings[subject];
    }

    function total(address subject) external view returns (uint256) {
        return countRatings[subject];
    }
}
