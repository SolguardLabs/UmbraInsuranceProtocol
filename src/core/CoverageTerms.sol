// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ICoverageTerms } from "../interfaces/ICoverageTerms.sol";
import { MathLib } from "../libraries/MathLib.sol";
import { ProtocolAccess } from "../security/ProtocolAccess.sol";

/// @title CoverageTerms
/// @notice Versioned policy wording registry for products sold through Umbra.
contract CoverageTerms is ICoverageTerms, ProtocolAccess {
    error InvalidProduct();
    error InvalidTerms();
    error InvalidVersion();
    error TermsUnavailable();

    struct TermsDocument {
        bytes32 productId;
        uint64 version;
        bytes32 termsHash;
        string uri;
        uint64 publishedAt;
        bool deprecated;
    }

    mapping(bytes32 => uint64) internal _latestVersion;
    mapping(bytes32 => mapping(uint64 => TermsDocument)) internal _documents;
    mapping(bytes32 => mapping(uint64 => mapping(address => bytes32))) internal _attestations;
    bytes32[] internal _products;

    constructor(address governor_, address guardian_) ProtocolAccess(governor_, guardian_) { }

    function publishTerms(bytes32 productId, bytes32 termsHash_, string calldata uri)
        external
        override
        onlyGovernorOrKeeper
        returns (uint64 version)
    {
        if (productId == bytes32(0)) revert InvalidProduct();
        if (termsHash_ == bytes32(0) || bytes(uri).length == 0) revert InvalidTerms();

        if (_latestVersion[productId] == 0) _products.push(productId);
        version = _latestVersion[productId] + 1;
        _latestVersion[productId] = version;
        _documents[productId][version] = TermsDocument({
            productId: productId,
            version: version,
            termsHash: termsHash_,
            uri: uri,
            publishedAt: MathLib.toUint64(block.timestamp),
            deprecated: false
        });

        emit TermsPublished(productId, version, termsHash_, uri);
    }

    function deprecateTerms(bytes32 productId, uint64 version)
        external
        override
        onlyGovernorOrGuardian
    {
        TermsDocument storage item = _documents[productId][version];
        if (item.version == 0) revert InvalidVersion();
        if (msg.sender == guardian && version == _latestVersion[productId]) {
            revert TermsUnavailable();
        }
        item.deprecated = true;
        emit TermsDeprecated(productId, version);
    }

    function attestTerms(bytes32 productId, uint64 version, bytes32 attestationHash)
        external
        override
    {
        TermsDocument memory item = _documents[productId][version];
        if (item.version == 0 || item.deprecated) revert TermsUnavailable();
        if (attestationHash == bytes32(0)) revert InvalidTerms();
        _attestations[productId][version][msg.sender] = attestationHash;
        emit TermsAttested(productId, version, msg.sender, attestationHash);
    }

    function latestVersion(bytes32 productId) external view override returns (uint64) {
        return _latestVersion[productId];
    }

    function termsHash(bytes32 productId, uint64 version) external view override returns (bytes32) {
        TermsDocument memory item = _documents[productId][version];
        if (item.version == 0) revert InvalidVersion();
        return item.termsHash;
    }

    function isDeprecated(bytes32 productId, uint64 version) external view override returns (bool) {
        TermsDocument memory item = _documents[productId][version];
        if (item.version == 0) revert InvalidVersion();
        return item.deprecated;
    }

    function attestationOf(bytes32 productId, uint64 version, address account)
        external
        view
        override
        returns (bytes32)
    {
        return _attestations[productId][version][account];
    }

    function document(bytes32 productId, uint64 version)
        external
        view
        returns (TermsDocument memory)
    {
        TermsDocument memory item = _documents[productId][version];
        if (item.version == 0) revert InvalidVersion();
        return item;
    }

    function productCount() external view returns (uint256) {
        return _products.length;
    }

    function productAt(uint256 index) external view returns (bytes32) {
        return _products[index];
    }
}
