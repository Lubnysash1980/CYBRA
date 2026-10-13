// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TimeLock — відкладене виконання контракту
/// @notice Кошти приймаються від depositor, активуються через delay,
///         протягом delay можна скасувати. Після активації — release.
contract TimeLock {
    struct Lock {
        address depositor;
        address beneficiary;
        uint256 amount;
        uint64  createdAt;
        uint64  activateAt;
        uint64  cancelUntil;
        bytes32 cid;
        bool    released;
        bool    cancelled;
        string  note;
    }

    mapping(bytes32 => Lock) public locks;
    bytes32[] public lockIds;

    event LockCreated(bytes32 indexed cid, bytes32 indexed lockId,
                      address depositor, uint256 amount, uint64 activateAt);
    event LockCancelled(bytes32 indexed cid, bytes32 indexed lockId);
    event LockReleased(bytes32 indexed cid, bytes32 indexed lockId, uint256 amount);

    error AlreadyExists();
    error NotFound();
    error StillLocked();
    error AlreadyFinal();
    error OnlyDepositor();
    error TransferFailed();
    error BadTimes();

    /// @notice Створити time-lock. Кошти надсилаються у value.
    function create(bytes32 cid, address beneficiary,
                    uint64 delaySec, uint64 cancelWindowSec,
                    string calldata note)
        external payable returns (bytes32 lockId)
    {
        lockId = keccak256(abi.encodePacked(cid, msg.sender, block.timestamp));
        if (locks[lockId].depositor != address(0)) revert AlreadyExists();
        if (delaySec == 0) revert BadTimes();
        if (cancelWindowSec > delaySec) revert BadTimes();

        uint64 nowTs = uint64(block.timestamp);
        locks[lockId] = Lock({
            depositor: msg.sender,
            beneficiary: beneficiary,
            amount: msg.value,
            createdAt: nowTs,
            activateAt: nowTs + delaySec,
            cancelUntil: nowTs + cancelWindowSec,
            cid: cid,
            released: false,
            cancelled: false,
            note: note
        });
        lockIds.push(lockId);
        emit LockCreated(cid, lockId, msg.sender, msg.value, nowTs + delaySec);
    }

    /// @notice Скасувати поки дозволено. Повертає кошти.
    function cancel(bytes32 lockId) external {
        Lock storage L = locks[lockId];
        if (L.depositor == address(0)) revert NotFound();
        if (L.released || L.cancelled) revert AlreadyFinal();
        if (msg.sender != L.depositor) revert OnlyDepositor();
        if (block.timestamp > L.cancelUntil) revert StillLocked();

        L.cancelled = true;
        (bool ok,) = L.depositor.call{value: L.amount}("");
        if (!ok) revert TransferFailed();
        emit LockCancelled(L.cid, lockId);
    }

    /// @notice Реліз бенефіціару після активації.
    function release(bytes32 lockId) external {
        Lock storage L = locks[lockId];
        if (L.depositor == address(0)) revert NotFound();
        if (L.released || L.cancelled) revert AlreadyFinal();
        if (block.timestamp < L.activateAt) revert StillLocked();

        L.released = true;
        (bool ok,) = L.beneficiary.call{value: L.amount}("");
        if (!ok) revert TransferFailed();
        emit LockReleased(L.cid, lockId, L.amount);
    }

    function get(bytes32 lockId) external view returns (Lock memory) {
        return locks[lockId];
    }

    function count() external view returns (uint256) {
        return lockIds.length;
    }
}
