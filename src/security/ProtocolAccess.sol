// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

abstract contract ProtocolAccess {
    error Unauthorized();
    error InvalidAddress();
    error GuardianCannotUnpause();

    event GovernorUpdated(address indexed previousGovernor, address indexed newGovernor);
    event GuardianUpdated(address indexed previousGuardian, address indexed newGuardian);
    event KeeperUpdated(address indexed keeper, bool enabled);

    address public governor;
    address public guardian;
    mapping(address => bool) public isKeeper;

    modifier onlyGovernor() {
        if (msg.sender != governor) revert Unauthorized();
        _;
    }

    modifier onlyGovernorOrGuardian() {
        if (msg.sender != governor && msg.sender != guardian) revert Unauthorized();
        _;
    }

    modifier onlyGovernorOrKeeper() {
        if (msg.sender != governor && !isKeeper[msg.sender]) revert Unauthorized();
        _;
    }

    constructor(address initialGovernor, address initialGuardian) {
        if (initialGovernor == address(0) || initialGuardian == address(0)) {
            revert InvalidAddress();
        }
        governor = initialGovernor;
        guardian = initialGuardian;
        emit GovernorUpdated(address(0), initialGovernor);
        emit GuardianUpdated(address(0), initialGuardian);
    }

    function setGovernor(address newGovernor) external onlyGovernor {
        if (newGovernor == address(0)) revert InvalidAddress();
        address previous = governor;
        governor = newGovernor;
        emit GovernorUpdated(previous, newGovernor);
    }

    function setGuardian(address newGuardian) external onlyGovernor {
        if (newGuardian == address(0)) revert InvalidAddress();
        address previous = guardian;
        guardian = newGuardian;
        emit GuardianUpdated(previous, newGuardian);
    }

    function setKeeper(address keeper, bool enabled) external onlyGovernor {
        if (keeper == address(0)) revert InvalidAddress();
        isKeeper[keeper] = enabled;
        emit KeeperUpdated(keeper, enabled);
    }
}

