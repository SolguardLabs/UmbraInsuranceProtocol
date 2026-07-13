// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "../interfaces/IERC20.sol";

/// @title UmbraRiskShare
/// @notice Lightweight receipt token minted by the risk pool for underwriter accounting.
contract UmbraRiskShare is IERC20 {
    error InvalidAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error Unauthorized();

    string public override name;
    string public override symbol;
    uint8 public immutable override decimals;
    uint256 public override totalSupply;

    address public minter;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    modifier onlyMinter() {
        if (msg.sender != minter) revert Unauthorized();
        _;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address minter_) {
        if (minter_ == address(0)) revert InvalidAddress();
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        minter = minter_;
    }

    function setMinter(address newMinter) external onlyMinter {
        if (newMinter == address(0)) revert InvalidAddress();
        minter = newMinter;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        external
        override
        returns (bool)
    {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        if (to == address(0)) revert InvalidAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = balance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert InvalidAddress();
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = balance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}

