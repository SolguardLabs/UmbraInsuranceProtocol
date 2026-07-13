// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ICoverageTerms {
    event TermsPublished(
        bytes32 indexed productId, uint64 indexed version, bytes32 termsHash, string uri
    );
    event TermsDeprecated(bytes32 indexed productId, uint64 indexed version);
    event TermsAttested(
        bytes32 indexed productId,
        uint64 indexed version,
        address indexed account,
        bytes32 attestationHash
    );

    function publishTerms(bytes32 productId, bytes32 termsHash, string calldata uri)
        external
        returns (uint64 version);
    function deprecateTerms(bytes32 productId, uint64 version) external;
    function attestTerms(bytes32 productId, uint64 version, bytes32 attestationHash) external;
    function latestVersion(bytes32 productId) external view returns (uint64);
    function termsHash(bytes32 productId, uint64 version) external view returns (bytes32);
    function isDeprecated(bytes32 productId, uint64 version) external view returns (bool);
    function attestationOf(bytes32 productId, uint64 version, address account)
        external
        view
        returns (bytes32);
}

