// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IUmbraPolicyToken } from "../interfaces/IUmbraPolicyToken.sol";

/// @title UmbraPolicyToken
/// @notice ERC-721-like token representing transferable insurance policies.
contract UmbraPolicyToken is IUmbraPolicyToken {
    error InvalidAddress();
    error NotMinted();
    error AlreadyMinted();
    error NotOwnerNorApproved();
    error Unauthorized();

    string public override name;
    string public override symbol;
    address public registry;

    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    modifier onlyRegistry() {
        if (msg.sender != registry) revert Unauthorized();
        _;
    }

    constructor(string memory name_, string memory symbol_, address registry_) {
        if (registry_ == address(0)) revert InvalidAddress();
        name = name_;
        symbol = symbol_;
        registry = registry_;
    }

    function setRegistry(address newRegistry) external onlyRegistry {
        if (newRegistry == address(0)) revert InvalidAddress();
        registry = newRegistry;
    }

    function balanceOf(address owner) external view override returns (uint256) {
        if (owner == address(0)) revert InvalidAddress();
        return _balanceOf[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address owner) {
        owner = _ownerOf[tokenId];
        if (owner == address(0)) revert NotMinted();
    }

    function getApproved(uint256 tokenId) external view override returns (address) {
        if (_ownerOf[tokenId] == address(0)) revert NotMinted();
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator)
        external
        view
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    function approve(address spender, uint256 tokenId) external override {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) {
            revert NotOwnerNorApproved();
        }
        _tokenApprovals[tokenId] = spender;
        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) external override {
        if (to == address(0)) revert InvalidAddress();
        address owner = ownerOf(tokenId);
        if (owner != from) revert NotOwnerNorApproved();
        if (!_isApprovedOrOwner(msg.sender, owner, tokenId)) revert NotOwnerNorApproved();

        delete _tokenApprovals[tokenId];
        unchecked {
            _balanceOf[from] -= 1;
            _balanceOf[to] += 1;
        }
        _ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function mint(address to, uint256 tokenId) external override onlyRegistry {
        if (to == address(0)) revert InvalidAddress();
        if (_ownerOf[tokenId] != address(0)) revert AlreadyMinted();
        _ownerOf[tokenId] = to;
        _balanceOf[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function burn(uint256 tokenId) external override onlyRegistry {
        address owner = ownerOf(tokenId);
        delete _tokenApprovals[tokenId];
        delete _ownerOf[tokenId];
        unchecked {
            _balanceOf[owner] -= 1;
        }
        emit Transfer(owner, address(0), tokenId);
    }

    function _isApprovedOrOwner(address spender, address owner, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        return spender == owner || _tokenApprovals[tokenId] == spender
            || _operatorApprovals[owner][spender];
    }
}

