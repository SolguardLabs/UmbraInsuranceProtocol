// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library MathLib {
    error MathOverflow();

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function saturatingSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 0;
    }

    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a & b) + ((a ^ b) >> 1);
    }

    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) revert MathOverflow();
        if (a == 0) return 0;
        return ((a - 1) / b) + 1;
    }

    function mulDivDown(uint256 x, uint256 y, uint256 denominator)
        internal
        pure
        returns (uint256 result)
    {
        if (denominator == 0) revert MathOverflow();
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            if (prod1 == 0) return prod0 / denominator;
            if (denominator <= prod1) revert MathOverflow();

            uint256 remainder;
            assembly {
                remainder := mulmod(x, y, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            uint256 inverse = (3 * denominator) ^ 2;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;
            inverse *= 2 - denominator * inverse;

            result = prod0 * inverse;
        }
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator)
        internal
        pure
        returns (uint256 result)
    {
        result = mulDivDown(x, y, denominator);
        if (mulmod(x, y, denominator) != 0) {
            if (result == type(uint256).max) revert MathOverflow();
            unchecked {
                ++result;
            }
        }
    }

    function bpsMulDown(uint256 amount, uint256 bpsValue) internal pure returns (uint256) {
        return mulDivDown(amount, bpsValue, 10_000);
    }

    function bpsMulUp(uint256 amount, uint256 bpsValue) internal pure returns (uint256) {
        return mulDivUp(amount, bpsValue, 10_000);
    }

    function bps(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        if (denominator == 0) return 0;
        return mulDivDown(numerator, 10_000, denominator);
    }

    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) revert MathOverflow();
        return uint16(value);
    }

    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) revert MathOverflow();
        return uint32(value);
    }

    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) revert MathOverflow();
        return uint64(value);
    }

    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert MathOverflow();
        return uint128(value);
    }
}
