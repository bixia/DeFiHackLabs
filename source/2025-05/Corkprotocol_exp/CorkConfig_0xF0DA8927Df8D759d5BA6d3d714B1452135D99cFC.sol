// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.26 >=0.8.19 ^0.8.0 ^0.8.20 ^0.8.22 ^0.8.24;

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol

// Return type of the beforeSwap hook.
// Upper 128 bits is the delta in specified tokens. Lower 128 bits is delta in unspecified tokens (to match the afterSwap hook)
type BeforeSwapDelta is int256;

// Creates a BeforeSwapDelta from specified and unspecified
function toBeforeSwapDelta(int128 deltaSpecified, int128 deltaUnspecified)
    pure
    returns (BeforeSwapDelta beforeSwapDelta)
{
    assembly ("memory-safe") {
        beforeSwapDelta := or(shl(128, deltaSpecified), and(sub(shl(128, 1), 1), deltaUnspecified))
    }
}

/// @notice Library for getting the specified and unspecified deltas from the BeforeSwapDelta type
library BeforeSwapDeltaLibrary {
    /// @notice A BeforeSwapDelta of 0
    BeforeSwapDelta public constant ZERO_DELTA = BeforeSwapDelta.wrap(0);

    /// extracts int128 from the upper 128 bits of the BeforeSwapDelta
    /// returned by beforeSwap
    function getSpecifiedDelta(BeforeSwapDelta delta) internal pure returns (int128 deltaSpecified) {
        assembly ("memory-safe") {
            deltaSpecified := sar(128, delta)
        }
    }

    /// extracts int128 from the lower 128 bits of the BeforeSwapDelta
    /// returned by beforeSwap and afterSwap
    function getUnspecifiedDelta(BeforeSwapDelta delta) internal pure returns (int128 deltaUnspecified) {
        assembly ("memory-safe") {
            deltaUnspecified := signextend(15, delta)
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/structs/BitMaps.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/BitMaps.sol)

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, provided the keys are sequential.
 * Largely inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 *
 * BitMaps pack 256 booleans across each bit of a single 256-bit slot of `uint256` type.
 * Hence booleans corresponding to 256 _sequential_ indices would only consume a single slot,
 * unlike the regular `bool` which would consume an entire slot for a single value.
 *
 * This results in gas savings in two ways:
 *
 * - Setting a zero value to non-zero only once every 256 times
 * - Accessing the same warm slot for every 256 _sequential_ indices
 */
library BitMaps {
    struct BitMap {
        mapping(uint256 bucket => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    function setTo(BitMap storage bitmap, uint256 index, bool value) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }
}

// lib/prb-math/src/Common.sol

// Common.sol
//
// Common mathematical functions used in both SD59x18 and UD60x18. Note that these global functions do not
// always operate with SD59x18 and UD60x18 numbers.

/*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when the resultant value in {mulDiv} overflows uint256.
error PRBMath_MulDiv_Overflow(uint256 x, uint256 y, uint256 denominator);

/// @notice Thrown when the resultant value in {mulDiv18} overflows uint256.
error PRBMath_MulDiv18_Overflow(uint256 x, uint256 y);

/// @notice Thrown when one of the inputs passed to {mulDivSigned} is `type(int256).min`.
error PRBMath_MulDivSigned_InputTooSmall();

/// @notice Thrown when the resultant value in {mulDivSigned} overflows int256.
error PRBMath_MulDivSigned_Overflow(int256 x, int256 y);

/*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
//////////////////////////////////////////////////////////////////////////*/

/// @dev The maximum value a uint128 number can have.
uint128 constant MAX_UINT128 = type(uint128).max;

/// @dev The maximum value a uint40 number can have.
uint40 constant MAX_UINT40 = type(uint40).max;

/// @dev The maximum value a uint64 number can have.
uint64 constant MAX_UINT64 = type(uint64).max;

/// @dev The unit number, which the decimal precision of the fixed-point types.
uint256 constant UNIT_0 = 1e18;

/// @dev The unit number inverted mod 2^256.
uint256 constant UNIT_INVERSE = 78156646155174841979727994598816262306175212592076161876661_508869554232690281;

/// @dev The the largest power of two that divides the decimal value of `UNIT`. The logarithm of this value is the least significant
/// bit in the binary representation of `UNIT`.
uint256 constant UNIT_LPOTD = 262144;

/*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Calculates the binary exponent of x using the binary fraction method.
/// @dev Has to use 192.64-bit fixed-point numbers. See https://ethereum.stackexchange.com/a/96594/24693.
/// @param x The exponent as an unsigned 192.64-bit fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function exp2_0(uint256 x) pure returns (uint256 result) {
    unchecked {
        // Start from 0.5 in the 192.64-bit fixed-point format.
        result = 0x800000000000000000000000000000000000000000000000;

        // The following logic multiplies the result by $\sqrt{2^{-i}}$ when the bit at position i is 1. Key points:
        //
        // 1. Intermediate results will not overflow, as the starting point is 2^191 and all magic factors are under 2^65.
        // 2. The rationale for organizing the if statements into groups of 8 is gas savings. If the result of performing
        // a bitwise AND operation between x and any value in the array [0x80; 0x40; 0x20; 0x10; 0x08; 0x04; 0x02; 0x01] is 1,
        // we know that `x & 0xFF` is also 1.
        if (x & 0xFF00000000000000 > 0) {
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
        }

        if (x & 0xFF000000000000 > 0) {
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
        }

        if (x & 0xFF0000000000 > 0) {
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
        }

        if (x & 0xFF00000000 > 0) {
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
        }

        if (x & 0xFF000000 > 0) {
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
        }

        if (x & 0xFF0000 > 0) {
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
        }

        if (x & 0xFF00 > 0) {
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
        }

        if (x & 0xFF > 0) {
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
        }

        // In the code snippet below, two operations are executed simultaneously:
        //
        // 1. The result is multiplied by $(2^n + 1)$, where $2^n$ represents the integer part, and the additional 1
        // accounts for the initial guess of 0.5. This is achieved by subtracting from 191 instead of 192.
        // 2. The result is then converted to an unsigned 60.18-decimal fixed-point format.
        //
        // The underlying logic is based on the relationship $2^{191-ip} = 2^{ip} / 2^{191}$, where $ip$ denotes the,
        // integer part, $2^n$.
        result *= UNIT_0;
        result >>= (191 - (x >> 64));
    }
}

/// @notice Finds the zero-based index of the first 1 in the binary representation of x.
///
/// @dev See the note on "msb" in this Wikipedia article: https://en.wikipedia.org/wiki/Find_first_set
///
/// Each step in this implementation is equivalent to this high-level code:
///
/// ```solidity
/// if (x >= 2 ** 128) {
///     x >>= 128;
///     result += 128;
/// }
/// ```
///
/// Where 128 is replaced with each respective power of two factor. See the full high-level implementation here:
/// https://gist.github.com/PaulRBerg/f932f8693f2733e30c4d479e8e980948
///
/// The Yul instructions used below are:
///
/// - "gt" is "greater than"
/// - "or" is the OR bitwise operator
/// - "shl" is "shift left"
/// - "shr" is "shift right"
///
/// @param x The uint256 number for which to find the index of the most significant bit.
/// @return result The index of the most significant bit as a uint256.
/// @custom:smtchecker abstract-function-nondet
function msb(uint256 x) pure returns (uint256 result) {
    // 2^128
    assembly ("memory-safe") {
        let factor := shl(7, gt(x, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^64
    assembly ("memory-safe") {
        let factor := shl(6, gt(x, 0xFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^32
    assembly ("memory-safe") {
        let factor := shl(5, gt(x, 0xFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^16
    assembly ("memory-safe") {
        let factor := shl(4, gt(x, 0xFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^8
    assembly ("memory-safe") {
        let factor := shl(3, gt(x, 0xFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^4
    assembly ("memory-safe") {
        let factor := shl(2, gt(x, 0xF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^2
    assembly ("memory-safe") {
        let factor := shl(1, gt(x, 0x3))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^1
    // No need to shift x any more.
    assembly ("memory-safe") {
        let factor := gt(x, 0x1)
        result := or(result, factor)
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev Credits to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - The denominator must not be zero.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as a uint256.
/// @param y The multiplier as a uint256.
/// @param denominator The divisor as a uint256.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function mulDiv(uint256 x, uint256 y, uint256 denominator) pure returns (uint256 result) {
    // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
    // use the Chinese Remainder Theorem to reconstruct the 512-bit result. The result is stored in two 256
    // variables such that product = prod1 * 2^256 + prod0.
    uint256 prod0; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    // Handle non-overflow cases, 256 by 256 division.
    if (prod1 == 0) {
        unchecked {
            return prod0 / denominator;
        }
    }

    // Make sure the result is less than 2^256. Also prevents denominator == 0.
    if (prod1 >= denominator) {
        revert PRBMath_MulDiv_Overflow(x, y, denominator);
    }

    ////////////////////////////////////////////////////////////////////////////
    // 512 by 256 division
    ////////////////////////////////////////////////////////////////////////////

    // Make division exact by subtracting the remainder from [prod1 prod0].
    uint256 remainder;
    assembly ("memory-safe") {
        // Compute remainder using the mulmod Yul instruction.
        remainder := mulmod(x, y, denominator)

        // Subtract 256 bit number from 512-bit number.
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
    }

    unchecked {
        // Calculate the largest power of two divisor of the denominator using the unary operator ~. This operation cannot overflow
        // because the denominator cannot be zero at this point in the function execution. The result is always >= 1.
        // For more detail, see https://cs.stackexchange.com/q/138556/92363.
        uint256 lpotdod = denominator & (~denominator + 1);
        uint256 flippedLpotdod;

        assembly ("memory-safe") {
            // Factor powers of two out of denominator.
            denominator := div(denominator, lpotdod)

            // Divide [prod1 prod0] by lpotdod.
            prod0 := div(prod0, lpotdod)

            // Get the flipped value `2^256 / lpotdod`. If the `lpotdod` is zero, the flipped value is one.
            // `sub(0, lpotdod)` produces the two's complement version of `lpotdod`, which is equivalent to flipping all the bits.
            // However, `div` interprets this value as an unsigned value: https://ethereum.stackexchange.com/q/147168/24693
            flippedLpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
        }

        // Shift in bits from prod1 into prod0.
        prod0 |= prod1 * flippedLpotdod;

        // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
        // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
        // four bits. That is, denominator * inv = 1 mod 2^4.
        uint256 inverse = (3 * denominator) ^ 2;

        // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
        // in modular arithmetic, doubling the correct bits in each step.
        inverse *= 2 - denominator * inverse; // inverse mod 2^8
        inverse *= 2 - denominator * inverse; // inverse mod 2^16
        inverse *= 2 - denominator * inverse; // inverse mod 2^32
        inverse *= 2 - denominator * inverse; // inverse mod 2^64
        inverse *= 2 - denominator * inverse; // inverse mod 2^128
        inverse *= 2 - denominator * inverse; // inverse mod 2^256

        // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
        // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
        // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
        // is no longer required.
        result = prod0 * inverse;
    }
}

/// @notice Calculates x*y÷1e18 with 512-bit precision.
///
/// @dev A variant of {mulDiv} with constant folding, i.e. in which the denominator is hard coded to 1e18.
///
/// Notes:
/// - The body is purposely left uncommented; to understand how this works, see the documentation in {mulDiv}.
/// - The result is rounded toward zero.
/// - We take as an axiom that the result cannot be `MAX_UINT256` when x and y solve the following system of equations:
///
/// $$
/// \begin{cases}
///     x * y = MAX\_UINT256 * UNIT \\
///     (x * y) \% UNIT \geq \frac{UNIT}{2}
/// \end{cases}
/// $$
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
/// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function mulDiv18(uint256 x, uint256 y) pure returns (uint256 result) {
    uint256 prod0;
    uint256 prod1;
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    if (prod1 == 0) {
        unchecked {
            return prod0 / UNIT_0;
        }
    }

    if (prod1 >= UNIT_0) {
        revert PRBMath_MulDiv18_Overflow(x, y);
    }

    uint256 remainder;
    assembly ("memory-safe") {
        remainder := mulmod(x, y, UNIT_0)
        result :=
            mul(
                or(
                    div(sub(prod0, remainder), UNIT_LPOTD),
                    mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, UNIT_LPOTD), UNIT_LPOTD), 1))
                ),
                UNIT_INVERSE
            )
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev This is an extension of {mulDiv} for signed numbers, which works by computing the signs and the absolute values separately.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - None of the inputs can be `type(int256).min`.
/// - The result must fit in int256.
///
/// @param x The multiplicand as an int256.
/// @param y The multiplier as an int256.
/// @param denominator The divisor as an int256.
/// @return result The result as an int256.
/// @custom:smtchecker abstract-function-nondet
function mulDivSigned(int256 x, int256 y, int256 denominator) pure returns (int256 result) {
    if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
        revert PRBMath_MulDivSigned_InputTooSmall();
    }

    // Get hold of the absolute values of x, y and the denominator.
    uint256 xAbs;
    uint256 yAbs;
    uint256 dAbs;
    unchecked {
        xAbs = x < 0 ? uint256(-x) : uint256(x);
        yAbs = y < 0 ? uint256(-y) : uint256(y);
        dAbs = denominator < 0 ? uint256(-denominator) : uint256(denominator);
    }

    // Compute the absolute value of x*y÷denominator. The result must fit in int256.
    uint256 resultAbs = mulDiv(xAbs, yAbs, dAbs);
    if (resultAbs > uint256(type(int256).max)) {
        revert PRBMath_MulDivSigned_Overflow(x, y);
    }

    // Get the signs of x, y and the denominator.
    uint256 sx;
    uint256 sy;
    uint256 sd;
    assembly ("memory-safe") {
        // "sgt" is the "signed greater than" assembly instruction and "sub(0,1)" is -1 in two's complement.
        sx := sgt(x, sub(0, 1))
        sy := sgt(y, sub(0, 1))
        sd := sgt(denominator, sub(0, 1))
    }

    // XOR over sx, sy and sd. What this does is to check whether there are 1 or 3 negative signs in the inputs.
    // If there are, the result should be negative. Otherwise, it should be positive.
    unchecked {
        result = sx ^ sy ^ sd == 0 ? -int256(resultAbs) : int256(resultAbs);
    }
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - If x is not a perfect square, the result is rounded down.
/// - Credits to OpenZeppelin for the explanations in comments below.
///
/// @param x The uint256 number for which to calculate the square root.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function sqrt_0(uint256 x) pure returns (uint256 result) {
    if (x == 0) {
        return 0;
    }

    // For our first guess, we calculate the biggest power of 2 which is smaller than the square root of x.
    //
    // We know that the "msb" (most significant bit) of x is a power of 2 such that we have:
    //
    // $$
    // msb(x) <= x <= 2*msb(x)$
    // $$
    //
    // We write $msb(x)$ as $2^k$, and we get:
    //
    // $$
    // k = log_2(x)
    // $$
    //
    // Thus, we can write the initial inequality as:
    //
    // $$
    // 2^{log_2(x)} <= x <= 2*2^{log_2(x)+1} \\
    // sqrt(2^k) <= sqrt(x) < sqrt(2^{k+1}) \\
    // 2^{k/2} <= sqrt(x) < 2^{(k+1)/2} <= 2^{(k/2)+1}
    // $$
    //
    // Consequently, $2^{log_2(x) /2} is a good first approximation of sqrt(x) with at least one correct bit.
    uint256 xAux = uint256(x);
    result = 1;
    if (xAux >= 2 ** 128) {
        xAux >>= 128;
        result <<= 64;
    }
    if (xAux >= 2 ** 64) {
        xAux >>= 64;
        result <<= 32;
    }
    if (xAux >= 2 ** 32) {
        xAux >>= 32;
        result <<= 16;
    }
    if (xAux >= 2 ** 16) {
        xAux >>= 16;
        result <<= 8;
    }
    if (xAux >= 2 ** 8) {
        xAux >>= 8;
        result <<= 4;
    }
    if (xAux >= 2 ** 4) {
        xAux >>= 4;
        result <<= 2;
    }
    if (xAux >= 2 ** 2) {
        result <<= 1;
    }

    // At this point, `result` is an estimation with at least one bit of precision. We know the true value has at
    // most 128 bits, since it is the square root of a uint256. Newton's method converges quadratically (precision
    // doubles at every iteration). We thus need at most 7 iteration to turn our partial result with one bit of
    // precision into the expected uint128 result.
    unchecked {
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;

        // If x is not a perfect square, round the result toward zero.
        uint256 roundedResult = x / result;
        if (result >= roundedResult) {
            result = roundedResult;
        }
    }
}

// lib/Cork-Hook/src/Constants.sol

library Constants {
    // we will use our own fee, no need for uni v4 fee
    uint24 internal constant FEE = 0;
    // default tick spacing since we don't actually use it, so we just set it to 1
    int24 internal constant TICK_SPACING = 1;
    // default sqrt price, we don't really use this one either
    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
}

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/Cork-Hook/src/interfaces/CorkSwapCallback.sol

interface CorkSwapCallback {
    /**
     * @notice a callback function that will be called by the hook when doing swap, intended use case for flash swap
     * @param sender the address that initiated the swap
     * @param data the data that will be passed to the callback
     * @param paymentAmount the amount of tokens that the user must transfer to the pool manager
     * @param paymentToken the token that the user must transfer  to the pool manager
     * @param poolManager the pool manager to transfer the payment token to
     */
    function CorkCall(
        address sender,
        bytes calldata data,
        uint256 paymentAmount,
        address paymentToken,
        address poolManager
    ) external;
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/libraries/CustomRevert.sol

/// @title Library for reverting with custom errors efficiently
/// @notice Contains functions for reverting with custom errors with different argument types efficiently
/// @dev To use this library, declare `using CustomRevert for bytes4;` and replace `revert CustomError()` with
/// `CustomError.selector.revertWith()`
/// @dev The functions may tamper with the free memory pointer but it is fine since the call context is exited immediately
library CustomRevert {
    /// @dev ERC-7751 error for wrapping bubbled up reverts
    error WrappedError(address target, bytes4 selector, bytes reason, bytes details);

    /// @dev Reverts with the selector of a custom error in the scratch space
    function revertWith(bytes4 selector) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            revert(0, 0x04)
        }
    }

    /// @dev Reverts with a custom error with an address argument in the scratch space
    function revertWith(bytes4 selector, address addr) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, and(addr, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(0, 0x24)
        }
    }

    /// @dev Reverts with a custom error with an int24 argument in the scratch space
    function revertWith(bytes4 selector, int24 value) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, signextend(2, value))
            revert(0, 0x24)
        }
    }

    /// @dev Reverts with a custom error with a uint160 argument in the scratch space
    function revertWith(bytes4 selector, uint160 value) internal pure {
        assembly ("memory-safe") {
            mstore(0, selector)
            mstore(0x04, and(value, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(0, 0x24)
        }
    }

    /// @dev Reverts with a custom error with two int24 arguments
    function revertWith(bytes4 selector, int24 value1, int24 value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), signextend(2, value1))
            mstore(add(fmp, 0x24), signextend(2, value2))
            revert(fmp, 0x44)
        }
    }

    /// @dev Reverts with a custom error with two uint160 arguments
    function revertWith(bytes4 selector, uint160 value1, uint160 value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), and(value1, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(fmp, 0x24), and(value2, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(fmp, 0x44)
        }
    }

    /// @dev Reverts with a custom error with two address arguments
    function revertWith(bytes4 selector, address value1, address value2) internal pure {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, selector)
            mstore(add(fmp, 0x04), and(value1, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(fmp, 0x24), and(value2, 0xffffffffffffffffffffffffffffffffffffffff))
            revert(fmp, 0x44)
        }
    }

    /// @notice bubble up the revert message returned by a call and revert with a wrapped ERC-7751 error
    /// @dev this method can be vulnerable to revert data bombs
    function bubbleUpAndRevertWith(
        address revertingContract,
        bytes4 revertingFunctionSelector,
        bytes4 additionalContext
    ) internal pure {
        bytes4 wrappedErrorSelector = WrappedError.selector;
        assembly ("memory-safe") {
            // Ensure the size of the revert data is a multiple of 32 bytes
            let encodedDataSize := mul(div(add(returndatasize(), 31), 32), 32)

            let fmp := mload(0x40)

            // Encode wrapped error selector, address, function selector, offset, additional context, size, revert reason
            mstore(fmp, wrappedErrorSelector)
            mstore(add(fmp, 0x04), and(revertingContract, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(
                add(fmp, 0x24),
                and(revertingFunctionSelector, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            )
            // offset revert reason
            mstore(add(fmp, 0x44), 0x80)
            // offset additional context
            mstore(add(fmp, 0x64), add(0xa0, encodedDataSize))
            // size revert reason
            mstore(add(fmp, 0x84), returndatasize())
            // revert reason
            returndatacopy(add(fmp, 0xa4), 0, returndatasize())
            // size additional context
            mstore(add(fmp, add(0xa4, encodedDataSize)), 0x04)
            // additional context
            mstore(
                add(fmp, add(0xc4, encodedDataSize)),
                and(additionalContext, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            )
            revert(fmp, add(0xe4, encodedDataSize))
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/cryptography/ECDSA.sol)

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly ("memory-safe") {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[ERC-2098 short signatures]
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/Errors.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// lib/openzeppelin-contracts/contracts/access/IAccessControl.sol

// OpenZeppelin Contracts (last updated v5.1.0) (access/IAccessControl.sol)

/**
 * @dev External interface of AccessControl declared to support ERC-165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call. This account bears the admin role (for the granted role).
     * Expected in cases where the role was granted using the internal {AccessControl-_grantRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// contracts/libraries/ERC/ICustomERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface ICustomERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string memory functionName
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC1967.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1967.sol)

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 */
interface IERC1967 {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/external/IERC20Minimal.sol

/// @title Minimal ERC20 interface for Uniswap
/// @notice Contains a subset of the full ERC20 interface that is used in Uniswap V3
interface IERC20Minimal {
    /// @notice Returns an account's balance in the token
    /// @param account The account for which to look up the number of tokens it has, i.e. its balance
    /// @return The number of tokens held by the account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers the amount of token from the `msg.sender` to the recipient
    /// @param recipient The account that will receive the amount transferred
    /// @param amount The number of tokens to send from the sender to the recipient
    /// @return Returns true for a successful transfer, false for an unsuccessful transfer
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Returns the current allowance given to a spender by an owner
    /// @param owner The account of the token owner
    /// @param spender The account of the token spender
    /// @return The current allowance granted by `owner` to `spender`
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets the allowance of a spender from the `msg.sender` to the value `amount`
    /// @param spender The account which will be allowed to spend a given amount of the owners tokens
    /// @param amount The amount of tokens allowed to be used by `spender`
    /// @return Returns true for a successful approval, false for unsuccessful
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers `amount` tokens from `sender` to `recipient` up to the allowance given to the `msg.sender`
    /// @param sender The account from which the transfer will be initiated
    /// @param recipient The recipient of the transfer
    /// @param amount The amount of the transfer
    /// @return Returns true for a successful transfer, false for unsuccessful
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /// @notice Event emitted when tokens are transferred from one address to another, either via `#transfer` or `#transferFrom`.
    /// @param from The account from which the tokens were sent, i.e. the balance decreased
    /// @param to The account to which the tokens were sent, i.e. the balance increased
    /// @param value The amount of tokens that were transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Event emitted when the approval amount for the spender of a given owner's tokens changes.
    /// @param owner The account that approved spending of its tokens
    /// @param spender The account for which the spending allowance was modified
    /// @param value The new allowance from the owner to the spender
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC-20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC-20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC5267.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC5267.sol)

interface IERC5267 {
    /**
     * @dev MAY be emitted to signal that the domain could have changed.
     */
    event EIP712DomainChanged();

    /**
     * @dev returns the fields and values that describe the domain separator used by this contract for EIP-712
     * signature.
     */
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/external/IERC6909Claims.sol

/// @notice Interface for claims over a contract balance, wrapped as a ERC6909
interface IERC6909Claims {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Owner balance of an id.
    /// @param owner The address of the owner.
    /// @param id The id of the token.
    /// @return amount The balance of the token.
    function balanceOf(address owner, uint256 id) external view returns (uint256 amount);

    /// @notice Spender allowance of an id.
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @return amount The allowance of the token.
    function allowance(address owner, address spender, uint256 id) external view returns (uint256 amount);

    /// @notice Checks if a spender is approved by an owner as an operator
    /// @param owner The address of the owner.
    /// @param spender The address of the spender.
    /// @return approved The approval status.
    function isOperator(address owner, address spender) external view returns (bool approved);

    /// @notice Transfers an amount of an id from the caller to a receiver.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    /// @return bool True, always, unless the function reverts
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);

    /// @notice Transfers an amount of an id from a sender to a receiver.
    /// @param sender The address of the sender.
    /// @param receiver The address of the receiver.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    /// @return bool True, always, unless the function reverts
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);

    /// @notice Approves an amount of an id to a spender.
    /// @param spender The address of the spender.
    /// @param id The id of the token.
    /// @param amount The amount of the token.
    /// @return bool True, always
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);

    /// @notice Sets or removes an operator for the caller.
    /// @param operator The address of the operator.
    /// @param approved The approval status.
    /// @return bool True, always
    function setOperator(address operator, bool approved) external returns (bool);
}

// contracts/interfaces/IErrors.sol

interface IErrors_0 {
    /// @notice trying to do swap/remove liquidity without sufficient liquidity
    error NotEnoughLiquidity();

    /// @notice trying to do something with a token that is not in the pool or initializing token that doesn't have expiry
    error InvalidToken();

    /// @notice trying to change fee to a value higher than MAX_FEE that is 100e18
    error InvalidFee();

    /// @notice trying to add liquidity through the pool manager
    error DisableNativeLiquidityModification();

    /// @notice trying to initialize the pool more than once
    error AlreadyInitialized();

    /// @notice trying to swap/remove liquidity from non-initialized pool
    error NotInitialized();

    /// @notice trying to swap with invalid amount or adding liquidity without proportion, e.g 0
    error InvalidAmount();

    /// @notice somehow the sender is not set in the forwarder contract when using hook swap function
    error NoSender();

    /// @notice only self call is allowed when forwarding callback in hook forwarder
    error OnlySelfCall();

    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    /// @notice thrown when Permit is not supported in Given ERC20 contract
    error PermitNotSupported();

    /// @notice thrown when the caller is not the module core
    error NotModuleCore();

    /// @notice thrown when the caller is not Config contract
    error NotConfig();

    /// @notice thrown when the swap somehow got into rollover period, but the rollover period is not active
    error RolloverNotActive();

    error NotDefaultAdmin();

    error ApproxExhausted();

    error InvalidParams();

    /// @notice Error indicating the mint cap has been exceeded.
    error MintCapExceeded();

    /// @notice Error indicating an invalid value was provided.
    error InvalidValue();

    /// @notice Thrown when the DS given when minting HU isn't proportional
    error InsufficientDsAmount();

    /// @notice Thrown when the PA given when minting HU isn't proportional
    error InsufficientPaAmount();

    error NoValidDSExist();

    error OnlyLiquidatorOrOwner();

    error InsufficientFunds();

    error OnlyDissolverOrHURouterAllowed();

    error NotYetClaimable(uint256 claimableAt, uint256 blockTimestamp);

    error NotOwner(address owner, address msgSender);

    error OnlyVault();

    /// @notice thrown when the user tries to repurchase more than the available PA + DSliquidity
    /// @param available the amount of available PA + DS
    /// @param requested the amount of PA + DS user will receive
    error InsufficientLiquidity(uint256 available, uint256 requested);

    /// @notice Error indicating provided signature is invalid
    error InvalidSignature();

    /// @notice limit too long when getting deployed assets
    /// @param max Max Allowed Length
    /// @param received Length of current given parameter
    error LimitTooLong(uint256 max, uint256 received);

    /// @notice error when trying to deploying a swap asset of a non existent pair
    /// @param ra Address of RA(Redemption Asset) contract
    /// @param pa Address of PA(Pegged Asset) contract
    error NotExist(address ra, address pa);

    /// @notice only flash swap router is allowed to call this function
    error OnlyFlashSwapRouterAllowed();

    /// @notice only config contract is allowed to call this function
    error OnlyConfigAllowed();

    /// @notice Trying to issue an expired asset
    error Expired();

    /// @notice invalid asset, thrown when trying to do something with an asset not deployed with asset factory
    /// @param asset Address of given Asset contract
    error InvalidAsset(address asset);

    /// @notice PSM Deposit is paused, i.e thrown when deposit is paused for PSM
    error PSMDepositPaused();

    /// @notice PSM Withdrawal is paused, i.e thrown when withdrawal is paused for PSM
    error PSMWithdrawalPaused();

    /// @notice PSM Repurchase is paused, i.e thrown when repurchase is paused for PSM
    error PSMRepurchasePaused();

    /// @notice LV Deposit is paused, i.e thrown when deposit is paused for LV
    error LVDepositPaused();

    /// @notice LV Withdrawal is paused, i.e thrown when withdrawal is paused for LV
    error LVWithdrawalPaused();

    /// @notice When transaction is mutex locked for ensuring non-reentrancy
    error StateLocked();

    /// @notice Thrown when user deposit with 0 amount
    error ZeroDeposit();

    /// @notice Thrown this error when fees are more than 5%
    error InvalidFees();

    /// @notice thrown when trying to update rate with invalid rate
    error InvalidRate();

    /// @notice thrown when blacklisted liquidation contract tries to request funds from the vault
    error OnlyWhiteListed();

    /// @notice caller is not authorized to perform the action, e.g transfering
    /// redemption rights to another address while not having the rights
    error Unauthorized(address caller);

    /// @notice inssuficient balance to perform expiry redeem(e.g requesting 5 LV to redeem but trying to redeem 10)
    error InsufficientBalance(address caller, uint256 requested, uint256 balance);

    /// @notice insufficient output amount, e.g trying to redeem 100 LV whcih you expect 100 RA but only received 50 RA
    error InsufficientOutputAmount(uint256 amountOutMin, uint256 received);

    /// @notice vault does not have sufficient funds to do something

    /// @notice no sane root is found when calculating value for buying DS
    error InvalidS();

    /// @notice no sane upper interval is found when trying to calculate value for buying DS
    error NoSignChange();

    /// @notice bisection method fail to converge after max iterations(256)
    error NoConverge();

    /// @notice invalid parameter
    error InvalidParam();

    /// @notice thrown when Reserve is Zero
    error ZeroReserve();

    /// @notice thrown when Input amount is not sufficient
    error InsufficientInputAmount();

    /// @notice thrown when not having sufficient Liquidity
    error InsufficientLiquidityForSwap();

    /// @notice thrown when Output amount is not sufficient
    error InsufficientOutputAmountForSwap();

    /// @notice thrown when the number is too big
    error TooBig();

    error NoLowerBound();

    error ProtectedUnitExists();

    error InvalidPairId();

    // This error occurs when user passes invalid input to the function.
    error InvalidInput();

    error CallerNotFactory();

    error ProtectedUnitNotExists();

    /// @notice thrown when the internal reference id is invalid
    error InalidRefId();

    /// @notice thrown when the caller is not the hook trampoline
    error OnlyTrampoline();

    /// @notice thron when the caller is not the liquidator
    error OnlyLiquidator();

    /// @notice thrown when expiry is zero
    error InvalidExpiry();

    /// @notice the current NAV share is below the acceptable threshold for deposit
    /// try again later
    error NavBelowThreshold(uint256 referenceNav, uint256 delta, uint256 currentNav);

    /// @notice thrown when trying to swap RA for DS
    /// but the RA:CT pool is in massive imbalance
    /// or it's verrrry close to expiry
    error InvalidPoolStateOrNearExpired();
}

// lib/Cork-Hook/src/interfaces/IErrors.sol

interface IErrors_1 {
    /// @notice trying to do swap/remove liquidity without sufficient liquidity
    error NotEnoughLiquidity();

    /// @notice trying to do something with a token that is not in the pool or initializing token that doesn't have expiry
    error InvalidToken();

    /// @notice trying to change fee to a value higher than MAX_FEE that is 100e18
    error InvalidFee();

    /// @notice trying to add liquidity through the pool manager
    error DisableNativeLiquidityModification();

    /// @notice trying to initialize the pool more than once
    error AlreadyInitialized();

    /// @notice trying to swap/remove liquidity from non-initialized pool
    error NotInitialized();

    /// @notice trying to swap with invalid amount or adding liquidity without proportion, e.g 0
    error InvalidAmount();

    /// @notice somehow the sender is not set in the forwarder contract when using hook swap function
    error NoSender();

    /// @notice only self call is allowed when forwarding callback in hook forwarder
    error OnlySelfCall();

    /// @notice trying to add liquidity with insufficient amount
    error Insufficient0Amount();

    /// @notice trying to add liquidity with insufficient amount
    error Insufficient1Amount();

    /// @notice trying to remove liquidity, but the liquidity removed is less than what expected
    error InsufficientOutputAmout();

    /// @notice deadline has passed
    error Deadline();

    /// @notice trying to do flash swap with exact in
    error NoExactIn();
}

// lib/Cork-Hook/lib/Depeg-swap/contracts/interfaces/IExpiry.sol

/**
 * @title IExpiry Interface
 * @author Cork Team
 * @notice IExpiry interface for Expiry contract
 */
interface IExpiry_0 {
    /// @notice Trying to issue an expired asset
    error Expired();

    /// @notice returns true if the asset is expired
    function isExpired() external view returns (bool);

    ///@notice returns the expiry timestamp if 0 then it means it never expires
    function expiry() external view returns (uint256);

    ///@notice returns the timestamp when the asset was issued
    function issuedAt() external view returns (uint256);
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/IExtsload.sol

/// @notice Interface for functions to access any storage slot in a contract
interface IExtsload {
    /// @notice Called by external contracts to access granular pool state
    /// @param slot Key of slot to sload
    /// @return value The value of the slot as bytes32
    function extsload(bytes32 slot) external view returns (bytes32 value);

    /// @notice Called by external contracts to access granular pool state
    /// @param startSlot Key of slot to start sloading from
    /// @param nSlots Number of slots to load into return value
    /// @return values List of loaded values.
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory values);

    /// @notice Called by external contracts to access sparse pool state
    /// @param slots List of slots to SLOAD from.
    /// @return values List of loaded values.
    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory values);
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/IExttload.sol

/// @notice Interface for functions to access any transient storage slot in a contract
interface IExttload {
    /// @notice Called by external contracts to access transient storage of the contract
    /// @param slot Key of slot to tload
    /// @return value The value of the slot as bytes32
    function exttload(bytes32 slot) external view returns (bytes32 value);

    /// @notice Called by external contracts to access sparse transient pool state
    /// @param slots List of slots to tload
    /// @return values List of loaded values
    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory values);
}

// contracts/interfaces/ILiquidatorRegistry.sol

interface ILiquidatorRegistry {
    function isLiquidationWhitelisted(address liquidationAddress) external view returns (bool);

    function blacklist(address liquidationAddress) external;

    function whitelist(address liquidationAddress) external;
}

// contracts/interfaces/IRates.sol

/**
 * @title IRates Interface
 * @author Cork Team
 * @notice IRates interface for providing excahngeRate functions
 */
interface IRates {
    /// @notice returns the exchange rate, if 0 then it means that there's no rate associated with it, like the case of LV token
    function exchangeRate() external view returns (uint256 rates);

    function updateRate(uint256 newRate) external;
}

// lib/Cork-Hook/src/interfaces/ITreasury.sol

interface ITreasury {
    function treasury() external view returns (address);
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/callback/IUnlockCallback.sol

/// @notice Interface for the callback executed when an address unlocks the pool manager
interface IUnlockCallback {
    /// @notice Called by the pool manager on `msg.sender` when the manager is unlocked
    /// @param data The data that was passed to the call to unlock
    /// @return Any data that you want to be returned from the unlock call
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

// contracts/interfaces/IWithdrawalRouter.sol

interface IWithdrawalRouter {
    struct Tokens {
        address token;
        uint256 amount;
    }

    function route(address receiver, Tokens[] calldata tokens, bytes calldata routerData) external;
}

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// contracts/libraries/LogExpMath.sol

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the “Software”), to deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.

// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

/* solhint-disable */

/**
 * @dev Exponentiation and logarithm functions for 18 decimal fixed point numbers (both base and exponent/argument).
 *
 * Exponentiation and logarithm with arbitrary bases (x^y and log_x(y)) are implemented by conversion to natural
 * exponentiation and logarithm (where the base is Euler's number).
 *
 * @author Fernando Martinelli - @fernandomartinelli
 * @author Sergio Yuhjtman - @sergioyuhjtman
 * @author Daniel Fernandez - @dmf7z
 */
library LogExpMath {
    // All fixed point multiplications and divisions are inlined. This means we need to divide by ONE when multiplying
    // two numbers, and multiply by ONE when dividing them.

    // All arguments and return values are 18 decimal fixed point numbers.
    int256 constant ONE_18 = 1e18;

    // Internally, intermediate values are computed with higher precision as 20 decimal fixed point numbers, and in the
    // case of ln36, 36 decimals.
    int256 constant ONE_20 = 1e20;
    int256 constant ONE_36 = 1e36;

    // The domain of natural exponentiation is bound by the word size and number of decimals used.
    //
    // Because internally the result will be stored using 20 decimals, the largest possible result is
    // (2^255 - 1) / 10^20, which makes the largest exponent ln((2^255 - 1) / 10^20) = 130.700829182905140221.
    // The smallest possible result is 10^(-18), which makes largest negative argument
    // ln(10^(-18)) = -41.446531673892822312.
    // We use 130.0 and -41.0 to have some safety margin.
    int256 constant MAX_NATURAL_EXPONENT = 130e18;
    int256 constant MIN_NATURAL_EXPONENT = -41e18;

    // Bounds for ln_36's argument. Both ln(0.9) and ln(1.1) can be represented with 36 decimal places in a fixed point
    // 256 bit integer.
    int256 constant LN_36_LOWER_BOUND = ONE_18 - 1e17;
    int256 constant LN_36_UPPER_BOUND = ONE_18 + 1e17;

    uint256 constant MILD_EXPONENT_BOUND = 2 ** 254 / uint256(ONE_20);

    // 18 decimal constants
    int256 constant x0 = 128000000000000000000; // 2ˆ7
    int256 constant a0 = 38877084059945950922200000000000000000000000000000000000; // eˆ(x0) (no decimals)
    int256 constant x1 = 64000000000000000000; // 2ˆ6
    int256 constant a1 = 6235149080811616882910000000; // eˆ(x1) (no decimals)

    // 20 decimal constants
    int256 constant x2 = 3200000000000000000000; // 2ˆ5
    int256 constant a2 = 7896296018268069516100000000000000; // eˆ(x2)
    int256 constant x3 = 1600000000000000000000; // 2ˆ4
    int256 constant a3 = 888611052050787263676000000; // eˆ(x3)
    int256 constant x4 = 800000000000000000000; // 2ˆ3
    int256 constant a4 = 298095798704172827474000; // eˆ(x4)
    int256 constant x5 = 400000000000000000000; // 2ˆ2
    int256 constant a5 = 5459815003314423907810; // eˆ(x5)
    int256 constant x6 = 200000000000000000000; // 2ˆ1
    int256 constant a6 = 738905609893065022723; // eˆ(x6)
    int256 constant x7 = 100000000000000000000; // 2ˆ0
    int256 constant a7 = 271828182845904523536; // eˆ(x7)
    int256 constant x8 = 50000000000000000000; // 2ˆ-1
    int256 constant a8 = 164872127070012814685; // eˆ(x8)
    int256 constant x9 = 25000000000000000000; // 2ˆ-2
    int256 constant a9 = 128402541668774148407; // eˆ(x9)
    int256 constant x10 = 12500000000000000000; // 2ˆ-3
    int256 constant a10 = 113314845306682631683; // eˆ(x10)
    int256 constant x11 = 6250000000000000000; // 2ˆ-4
    int256 constant a11 = 106449445891785942956; // eˆ(x11)

    /**
     * @dev Natural exponentiation (e^x) with signed 18 decimal fixed point exponent.
     *
     * Reverts if `x` is smaller than MIN_NATURAL_EXPONENT, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function exp(int256 x) internal pure returns (int256) {
        unchecked {
            require(x >= MIN_NATURAL_EXPONENT && x <= MAX_NATURAL_EXPONENT, "Invalid exponent");

            if (x < 0) {
                // We only handle positive exponents: e^(-x) is computed as 1 / e^x. We can safely make x positive since it
                // fits in the signed 256 bit range (as it is larger than MIN_NATURAL_EXPONENT).
                // Fixed point division requires multiplying by ONE_18.
                return ((ONE_18 * ONE_18) / exp(-x));
            }

            // First, we use the fact that e^(x+y) = e^x * e^y to decompose x into a sum of powers of two, which we call x_n,
            // where x_n == 2^(7 - n), and e^x_n = a_n has been precomputed. We choose the first x_n, x0, to equal 2^7
            // because all larger powers are larger than MAX_NATURAL_EXPONENT, and therefore not present in the
            // decomposition.
            // At the end of this process we will have the product of all e^x_n = a_n that apply, and the remainder of this
            // decomposition, which will be lower than the smallest x_n.
            // exp(x) = k_0 * a_0 * k_1 * a_1 * ... + k_n * a_n * exp(remainder), where each k_n equals either 0 or 1.
            // We mutate x by subtracting x_n, making it the remainder of the decomposition.

            // The first two a_n (e^(2^7) and e^(2^6)) are too large if stored as 18 decimal numbers, and could cause
            // intermediate overflows. Instead we store them as plain integers, with 0 decimals.
            // Additionally, x0 + x1 is larger than MAX_NATURAL_EXPONENT, which means they will not both be present in the
            // decomposition.

            // For each x_n, we test if that term is present in the decomposition (if x is larger than it), and if so deduct
            // it and compute the accumulated product.

            int256 firstAN;
            if (x >= x0) {
                x -= x0;
                firstAN = a0;
            } else if (x >= x1) {
                x -= x1;
                firstAN = a1;
            } else {
                firstAN = 1; // One with no decimal places
            }

            // We now transform x into a 20 decimal fixed point number, to have enhanced precision when computing the
            // smaller terms.
            x *= 100;

            // `product` is the accumulated product of all a_n (except a0 and a1), which starts at 20 decimal fixed point
            // one. Recall that fixed point multiplication requires dividing by ONE_20.
            int256 product = ONE_20;

            if (x >= x2) {
                x -= x2;
                product = (product * a2) / ONE_20;
            }
            if (x >= x3) {
                x -= x3;
                product = (product * a3) / ONE_20;
            }
            if (x >= x4) {
                x -= x4;
                product = (product * a4) / ONE_20;
            }
            if (x >= x5) {
                x -= x5;
                product = (product * a5) / ONE_20;
            }
            if (x >= x6) {
                x -= x6;
                product = (product * a6) / ONE_20;
            }
            if (x >= x7) {
                x -= x7;
                product = (product * a7) / ONE_20;
            }
            if (x >= x8) {
                x -= x8;
                product = (product * a8) / ONE_20;
            }
            if (x >= x9) {
                x -= x9;
                product = (product * a9) / ONE_20;
            }

            // x10 and x11 are unnecessary here since we have high enough precision already.

            // Now we need to compute e^x, where x is small (in particular, it is smaller than x9). We use the Taylor series
            // expansion for e^x: 1 + x + (x^2 / 2!) + (x^3 / 3!) + ... + (x^n / n!).

            int256 seriesSum = ONE_20; // The initial one in the sum, with 20 decimal places.
            int256 term; // Each term in the sum, where the nth term is (x^n / n!).

            // The first term is simply x.
            term = x;
            seriesSum += term;

            // Each term (x^n / n!) equals the previous one times x, divided by n. Since x is a fixed point number,
            // multiplying by it requires dividing by ONE_20, but dividing by the non-fixed point n values does not.

            term = ((term * x) / ONE_20) / 2;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 3;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 4;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 5;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 6;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 7;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 8;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 9;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 10;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 11;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 12;
            seriesSum += term;

            // 12 Taylor terms are sufficient for 18 decimal precision.

            // We now have the first a_n (with no decimals), and the product of all other a_n present, and the Taylor
            // approximation of the exponentiation of the remainder (both with 20 decimals). All that remains is to multiply
            // all three (one 20 decimal fixed point multiplication, dividing by ONE_20, and one integer multiplication),
            // and then drop two digits to return an 18 decimal value.

            return (((product * seriesSum) / ONE_20) * firstAN) / 100;
        }
    }

    /**
     * @dev Natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
     */
    function ln(int256 a) internal pure returns (int256) {
        unchecked {
            // The real natural logarithm is not defined for negative numbers or zero.
            require(a > 0, "out of bounds");
            if (LN_36_LOWER_BOUND < a && a < LN_36_UPPER_BOUND) {
                return _ln_36(a) / ONE_18;
            } else {
                return _ln(a);
            }
        }
    }

    /**
     * @dev Exponentiation (x^y) with unsigned 18 decimal fixed point base and exponent.
     *
     * Reverts if ln(x) * y is smaller than `MIN_NATURAL_EXPONENT`, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function pow(uint256 x, uint256 y) internal pure returns (uint256) {
        unchecked {
            if (y == 0) {
                // We solve the 0^0 indetermination by making it equal one.
                return uint256(ONE_18);
            }

            if (x == 0) {
                return 0;
            }

            // Instead of computing x^y directly, we instead rely on the properties of logarithms and exponentiation to
            // arrive at that r`esult. In particular, exp(ln(x)) = x, and ln(x^y) = y * ln(x). This means
            // x^y = exp(y * ln(x)).

            // The ln function takes a signed value, so we need to make sure x fits in the signed 256 bit range.
            require(x < 2 ** 255, "x out of bounds");
            int256 x_int256 = int256(x);

            // We will compute y * ln(x) in a single step. Depending on the value of x, we can either use ln or ln_36. In
            // both cases, we leave the division by ONE_18 (due to fixed point multiplication) to the end.

            // This prevents y * ln(x) from overflowing, and at the same time guarantees y fits in the signed 256 bit range.
            require(y < MILD_EXPONENT_BOUND, "y out of bounds");
            int256 y_int256 = int256(y);

            int256 logx_times_y;
            if (LN_36_LOWER_BOUND < x_int256 && x_int256 < LN_36_UPPER_BOUND) {
                int256 ln_36_x = _ln_36(x_int256);

                // ln_36_x has 36 decimal places, so multiplying by y_int256 isn't as straightforward, since we can't just
                // bring y_int256 to 36 decimal places, as it might overflow. Instead, we perform two 18 decimal
                // multiplications and add the results: one with the first 18 decimals of ln_36_x, and one with the
                // (downscaled) last 18 decimals.
                logx_times_y = ((ln_36_x / ONE_18) * y_int256 + ((ln_36_x % ONE_18) * y_int256) / ONE_18);
            } else {
                logx_times_y = _ln(x_int256) * y_int256;
            }
            logx_times_y /= ONE_18;

            // Finally, we compute exp(y * ln(x)) to arrive at x^y
            require(
                MIN_NATURAL_EXPONENT <= logx_times_y && logx_times_y <= MAX_NATURAL_EXPONENT, "product out of bounds"
            );

            return uint256(exp(logx_times_y));
        }
    }

    /**
     * @dev Internal natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
     */
    function _ln(int256 a) private pure returns (int256) {
        unchecked {
            if (a < ONE_18) {
                // Since ln(a^k) = k * ln(a), we can compute ln(a) as ln(a) = ln((1/a)^(-1)) = - ln((1/a)). If a is less
                // than one, 1/a will be greater than one, and this if statement will not be entered in the recursive call.
                // Fixed point division requires multiplying by ONE_18.
                return (-_ln((ONE_18 * ONE_18) / a));
            }

            // First, we use the fact that ln^(a * b) = ln(a) + ln(b) to decompose ln(a) into a sum of powers of two, which
            // we call x_n, where x_n == 2^(7 - n), which are the natural logarithm of precomputed quantities a_n (that is,
            // ln(a_n) = x_n). We choose the first x_n, x0, to equal 2^7 because the exponential of all larger powers cannot
            // be represented as 18 fixed point decimal numbers in 256 bits, and are therefore larger than a.
            // At the end of this process we will have the sum of all x_n = ln(a_n) that apply, and the remainder of this
            // decomposition, which will be lower than the smallest a_n.
            // ln(a) = k_0 * x_0 + k_1 * x_1 + ... + k_n * x_n + ln(remainder), where each k_n equals either 0 or 1.
            // We mutate a by subtracting a_n, making it the remainder of the decomposition.

            // For reasons related to how `exp` works, the first two a_n (e^(2^7) and e^(2^6)) are not stored as fixed point
            // numbers with 18 decimals, but instead as plain integers with 0 decimals, so we need to multiply them by
            // ONE_18 to convert them to fixed point.
            // For each a_n, we test if that term is present in the decomposition (if a is larger than it), and if so divide
            // by it and compute the accumulated sum.

            int256 sum = 0;
            if (a >= a0 * ONE_18) {
                a /= a0; // Integer, not fixed point division
                sum += x0;
            }

            if (a >= a1 * ONE_18) {
                a /= a1; // Integer, not fixed point division
                sum += x1;
            }

            // All other a_n and x_n are stored as 20 digit fixed point numbers, so we convert the sum and a to this format.
            sum *= 100;
            a *= 100;

            // Because further a_n are  20 digit fixed point numbers, we multiply by ONE_20 when dividing by them.

            if (a >= a2) {
                a = (a * ONE_20) / a2;
                sum += x2;
            }

            if (a >= a3) {
                a = (a * ONE_20) / a3;
                sum += x3;
            }

            if (a >= a4) {
                a = (a * ONE_20) / a4;
                sum += x4;
            }

            if (a >= a5) {
                a = (a * ONE_20) / a5;
                sum += x5;
            }

            if (a >= a6) {
                a = (a * ONE_20) / a6;
                sum += x6;
            }

            if (a >= a7) {
                a = (a * ONE_20) / a7;
                sum += x7;
            }

            if (a >= a8) {
                a = (a * ONE_20) / a8;
                sum += x8;
            }

            if (a >= a9) {
                a = (a * ONE_20) / a9;
                sum += x9;
            }

            if (a >= a10) {
                a = (a * ONE_20) / a10;
                sum += x10;
            }

            if (a >= a11) {
                a = (a * ONE_20) / a11;
                sum += x11;
            }

            // a is now a small number (smaller than a_11, which roughly equals 1.06). This means we can use a Taylor series
            // that converges rapidly for values of `a` close to one - the same one used in ln_36.
            // Let z = (a - 1) / (a + 1).
            // ln(a) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

            // Recall that 20 digit fixed point division requires multiplying by ONE_20, and multiplication requires
            // division by ONE_20.
            int256 z = ((a - ONE_20) * ONE_20) / (a + ONE_20);
            int256 z_squared = (z * z) / ONE_20;

            // num is the numerator of the series: the z^(2 * n + 1) term
            int256 num = z;

            // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
            int256 seriesSum = num;

            // In each step, the numerator is multiplied by z^2
            num = (num * z_squared) / ONE_20;
            seriesSum += num / 3;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 5;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 7;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 9;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 11;

            // 6 Taylor terms are sufficient for 36 decimal precision.

            // Finally, we multiply by 2 (non fixed point) to compute ln(remainder)
            seriesSum *= 2;

            // We now have the sum of all x_n present, and the Taylor approximation of the logarithm of the remainder (both
            // with 20 decimals). All that remains is to sum these two, and then drop two digits to return a 18 decimal
            // value.

            return (sum + seriesSum) / 100;
        }
    }

    /**
     * @dev Intrnal high precision (36 decimal places) natural logarithm (ln(x)) with signed 18 decimal fixed point argument,
     * for x close to one.
     *
     * Should only be used if x is between LN_36_LOWER_BOUND and LN_36_UPPER_BOUND.
     */
    function _ln_36(int256 x) private pure returns (int256) {
        unchecked {
            // Since ln(1) = 0, a value of x close to one will yield a very small result, which makes using 36 digits
            // worthwhile.

            // First, we transform x to a 36 digit fixed point value.
            x *= ONE_18;

            // We will use the following Taylor expansion, which converges very rapidly. Let z = (x - 1) / (x + 1).
            // ln(x) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

            // Recall that 36 digit fixed point division requires multiplying by ONE_36, and multiplication requires
            // division by ONE_36.
            int256 z = ((x - ONE_36) * ONE_36) / (x + ONE_36);
            int256 z_squared = (z * z) / ONE_36;

            // num is the numerator of the series: the z^(2 * n + 1) term
            int256 num = z;

            // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
            int256 seriesSum = num;

            // In each step, the numerator is multiplied by z^2
            num = (num * z_squared) / ONE_36;
            seriesSum += num / 3;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 5;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 7;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 9;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 11;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 13;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 15;

            // 8 Taylor terms are sufficient for 36 decimal precision.

            // All that remains is multiplying by 2 (non fixed point).
            return seriesSum * 2;
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/Nonces.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */
abstract contract Nonces {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    mapping(address account => uint256) private _nonces;

    /**
     * @dev Returns the next unused nonce for an address.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal virtual returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return _nonces[owner]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/Panic.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Panic.sol)

/**
 * @dev Helper library for emitting standardized panic codes.
 *
 * ```solidity
 * contract Example {
 *      using Panic for uint256;
 *
 *      // Use any of the declared internal constants
 *      function foo() { Panic.GENERIC.panic(); }
 *
 *      // Alternatively
 *      function foo() { Panic.panic(Panic.GENERIC); }
 * }
 * ```
 *
 * Follows the list from https://github.com/ethereum/solidity/blob/v0.8.24/libsolutil/ErrorCodes.h[libsolutil].
 *
 * _Available since v5.1._
 */
// slither-disable-next-line unused-state
library Panic {
    /// @dev generic / unspecified error
    uint256 internal constant GENERIC = 0x00;
    /// @dev used by the assert() builtin
    uint256 internal constant ASSERT = 0x01;
    /// @dev arithmetic underflow or overflow
    uint256 internal constant UNDER_OVERFLOW = 0x11;
    /// @dev division or modulo by zero
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    /// @dev enum conversion error
    uint256 internal constant ENUM_CONVERSION_ERROR = 0x21;
    /// @dev invalid encoding in storage
    uint256 internal constant STORAGE_ENCODING_ERROR = 0x22;
    /// @dev empty array pop
    uint256 internal constant EMPTY_ARRAY_POP = 0x31;
    /// @dev array out of bounds access
    uint256 internal constant ARRAY_OUT_OF_BOUNDS = 0x32;
    /// @dev resource error (too large allocation or too large array)
    uint256 internal constant RESOURCE_ERROR = 0x41;
    /// @dev calling invalid internal function
    uint256 internal constant INVALID_INTERNAL_FUNCTION = 0x51;

    /// @dev Reverts with a panic code. Recommended to use with
    /// the internal constants with predefined codes.
    function panic(uint256 code) internal pure {
        assembly ("memory-safe") {
            mstore(0x00, 0x4e487b71)
            mstore(0x20, code)
            revert(0x1c, 0x24)
        }
    }
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/libraries/ParseBytes.sol

/// @notice Parses bytes returned from hooks and the byte selector used to check return selectors from hooks.
/// @dev parseSelector also is used to parse the expected selector
/// For parsing hook returns, note that all hooks return either bytes4 or (bytes4, 32-byte-delta) or (bytes4, 32-byte-delta, uint24).
library ParseBytes {
    function parseSelector(bytes memory result) internal pure returns (bytes4 selector) {
        // equivalent: (selector,) = abi.decode(result, (bytes4, int256));
        assembly ("memory-safe") {
            selector := mload(add(result, 0x20))
        }
    }

    function parseFee(bytes memory result) internal pure returns (uint24 lpFee) {
        // equivalent: (,, lpFee) = abi.decode(result, (bytes4, int256, uint24));
        assembly ("memory-safe") {
            lpFee := mload(add(result, 0x60))
        }
    }

    function parseReturnDelta(bytes memory result) internal pure returns (int256 hookReturn) {
        // equivalent: (, hookReturnDelta) = abi.decode(result, (bytes4, int256));
        assembly ("memory-safe") {
            hookReturn := mload(add(result, 0x40))
        }
    }
}

// contracts/libraries/ReturnDataSlotLib.sol

library ReturnDataSlotLib {
    // keccak256("RETURN")
    bytes32 public constant RETURN_SLOT = 0xb28124349b5a89ededaa96175a0b225363cf060aaa28ecb54f00fe1cc09eb9de;

    // keccak256("REFUNDED")
    bytes32 public constant REFUNDED_SLOT = 0x0ae202c5d1ff9dcd4329d24acbf3bddff6279ad182d19d899440adb36d927795;

    // keccak256("DS_FEE_AMOUNT")
    bytes32 public constant DS_FEE_AMOUNT = 0x2edcf68d3b1bfd48ba1b97a39acb4e9553bc609ae5ceef6b88a0581565dba754;

    function increase(bytes32 slot, uint256 _value) internal {
        uint256 prev = get(slot);

        set(slot, prev + _value);
    }

    function set(bytes32 slot, uint256 _value) private {
        assembly {
            tstore(slot, _value)
        }
    }

    function get(bytes32 slot) internal view returns (uint256 _value) {
        assembly {
            _value := tload(slot)
        }
    }

    function clear(bytes32 slot) internal {
        assembly {
            tstore(slot, 0)
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

/**
 * @dev Wrappers over Solidity's uintXX/intXX/bool casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast_0 {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }

    /**
     * @dev Cast a boolean (false or true) to a uint256 (0 or 1) with no jump.
     */
    function toUint(bool b) internal pure returns (uint256 u) {
        assembly ("memory-safe") {
            u := iszero(iszero(b))
        }
    }
}

// lib/Cork-Hook/src/lib/SenderSlot.sol

library SenderSlot {
    /// @notice used to store the current caller address when swapping tokens from the hook, since
    /// the caller address is lost when the hook is called from the core and while fitting the sender
    /// address in the hook data is possible, we need to decode from it, and the data is meant
    /// to be exclusively used by the hook to store callback arguments data for flash swap
    /// @dev keccak256(sender)-1 . sender as utf-8
    bytes32 constant internal SENDER_SLOT = 0x168E92CE035BA45E59A0314B0ED9A9E619B284AED8F6E5AB0A596EFD5C9F5CF8;

    function get() internal view returns (address) {
        address result;
        assembly ("memory-safe") {
            result := tload(SENDER_SLOT)
        }
        return result;
    }

    function set(address _sender) internal {
        assembly ("memory-safe") {
            tstore(SENDER_SLOT, _sender)
        }
    }

    function clear() internal {
        address zero = address(0);

        assembly ("memory-safe") {
            tstore(SENDER_SLOT, zero)
        }
    }
}

// contracts/libraries/SignatureHelperLib.sol

/**
 * @dev Signature structure
 */
struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/**
 * @title MinimalSignatureHelper Library Contract
 * @author Cork Team
 * @notice MinimalSignatureHelper Library implements signature related functions
 */
library MinimalSignatureHelper {
    /// @notice thrown when Signature length is not valid
    error InvalidSignatureLength(uint256 length);

    function split(bytes memory raw) internal pure returns (Signature memory sig) {
        if (raw.length != 65) {
            revert InvalidSignatureLength(raw.length);
        }

        (uint8 v, bytes32 r, bytes32 s) = splitUnchecked(raw);

        sig = Signature({v: v, r: r, s: s});
    }

    function splitUnchecked(bytes memory sig) private pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/TransientSlot.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/TransientSlot.sol)
// This file was procedurally generated from scripts/generate/templates/TransientSlot.js.

/**
 * @dev Library for reading and writing value-types to specific transient storage slots.
 *
 * Transient slots are often used to store temporary values that are removed after the current transaction.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 *  * Example reading and writing values using transient storage:
 * ```solidity
 * contract Lock {
 *     using TransientSlot for *;
 *
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _LOCK_SLOT = 0xf4678858b2b588224636b8522b729e7722d32fc491da849ed75b3fdf3c84f542;
 *
 *     modifier locked() {
 *         require(!_LOCK_SLOT.asBoolean().tload());
 *
 *         _LOCK_SLOT.asBoolean().tstore(true);
 *         _;
 *         _LOCK_SLOT.asBoolean().tstore(false);
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library TransientSlot {
    /**
     * @dev UDVT that represent a slot holding a address.
     */
    type AddressSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a AddressSlot.
     */
    function asAddress(bytes32 slot) internal pure returns (AddressSlot) {
        return AddressSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represent a slot holding a bool.
     */
    type BooleanSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a BooleanSlot.
     */
    function asBoolean(bytes32 slot) internal pure returns (BooleanSlot) {
        return BooleanSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represent a slot holding a bytes32.
     */
    type Bytes32Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Bytes32Slot.
     */
    function asBytes32(bytes32 slot) internal pure returns (Bytes32Slot) {
        return Bytes32Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represent a slot holding a uint256.
     */
    type Uint256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Uint256Slot.
     */
    function asUint256(bytes32 slot) internal pure returns (Uint256Slot) {
        return Uint256Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represent a slot holding a int256.
     */
    type Int256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Int256Slot.
     */
    function asInt256(bytes32 slot) internal pure returns (Int256Slot) {
        return Int256Slot.wrap(slot);
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(AddressSlot slot) internal view returns (address value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(AddressSlot slot, address value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(BooleanSlot slot) internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(BooleanSlot slot, bool value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Bytes32Slot slot) internal view returns (bytes32 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Bytes32Slot slot, bytes32 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Uint256Slot slot) internal view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Uint256Slot slot, uint256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    function tload(Int256Slot slot) internal view returns (int256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    function tstore(Int256Slot slot, int256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol

// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC-1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol

// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/utils/Create2.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Create2.sol)

/**
 * @dev Helper to make usage of the `CREATE2` EVM opcode easier and safer.
 * `CREATE2` can be used to compute in advance the address where a smart
 * contract will be deployed, which allows for interesting new mechanisms known
 * as 'counterfactual interactions'.
 *
 * See the https://eips.ethereum.org/EIPS/eip-1014#motivation[EIP] for more
 * information.
 */
library Create2 {
    /**
     * @dev There's no code to deploy.
     */
    error Create2EmptyBytecode();

    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `amount`.
     * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
     */
    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }
        if (bytecode.length == 0) {
            revert Create2EmptyBytecode();
        }
        assembly ("memory-safe") {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
            // if no address was created, and returndata is not empty, bubble revert
            if and(iszero(addr), not(iszero(returndatasize()))) {
                let p := mload(0x40)
                returndatacopy(p, 0, returndatasize())
                revert(p, returndatasize())
            }
        }
        if (addr == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the
     * `bytecodeHash` or `salt` will result in a new destination address.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Get free memory pointer

            // |                   | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
            // |-------------------|---------------------------------------------------------------------------|
            // | bytecodeHash      |                                                        CCCCCCCCCCCCC...CC |
            // | salt              |                                      BBBBBBBBBBBBB...BB                   |
            // | deployer          | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
            // | 0xFF              |            FF                                                             |
            // |-------------------|---------------------------------------------------------------------------|
            // | memory            | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
            // | keccak(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |

            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := and(keccak256(start, 85), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// contracts/interfaces/IAssetFactory.sol

/**
 * @title IAssetFactory Interface
 * @author Cork Team
 * @notice Interface for AssetsFactory contract
 */
interface IAssetFactory is IErrors_0 {
    /// @notice emitted when a new CT + DS assets is deployed
    /// @param ra Address of RA(Redemption Asset) contract
    /// @param ct Address of CT(Cover Token) contract
    /// @param ds Address of DS(Depeg Swap Token) contract
    event AssetDeployed(address indexed ra, address indexed ct, address indexed ds);

    /// @notice emitted when a new LvAsset is deployed
    /// @param ra Address of RA(Redemption Asset) contract
    /// @param pa Address of PA(Pegged Asset) contract
    /// @param lv Address of LV(Liquidity Vault) contract
    event LvAssetDeployed(address indexed ra, address indexed pa, address indexed lv);

    /// @notice emitted when a module core is changed in asset factory
    /// @param oldModuleCore old module core address
    /// @param newModuleCore new module core address
    event ModuleCoreChanged(address oldModuleCore, address newModuleCore);

    /**
     * @notice for getting list of deployed Assets with this factory
     * @param page page number
     * @param limit number of entries per page
     * @return ra list of deployed RA assets
     * @return lv list of deployed LV assets
     */
    function getDeployedAssets(uint8 page, uint8 limit)
        external
        view
        returns (address[] memory ra, address[] memory lv);

    /**
     * @notice for safety checks in psm core, also act as kind of like a registry
     * @param asset the address of Asset contract
     */
    function isDeployed(address asset) external view returns (bool);

    /**
     * @notice for getting list of deployed SwapAssets with this factory
     * @param ra Address of RA
     * @param pa Address of PA
     * @param expiryInterval expiry interval
     * @param page page number
     * @param limit number of entries per page
     * @return ct list of deployed CT assets
     * @return ds list of deployed DS assets
     */
    function getDeployedSwapAssets(
        address ra,
        address pa,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider,
        uint8 page,
        uint8 limit
    ) external view returns (address[] memory ct, address[] memory ds);

    struct DeployParams {
        address _ra;
        address _pa;
        address _owner;
        uint256 initialArp;
        uint256 expiryInterval;
        address exchangeRateProvider;
        uint256 psmExchangeRate;
        uint256 dsId;
    }

    function deploySwapAssets(DeployParams calldata params) external returns (address ct, address ds);

    /**
     * @notice deploys new LV Assets for given RA & PA
     * @param ra Address of RA
     * @param pa Address of PA
     * @param owner Address of asset owners
     * @return lv new LV contract address
     */
    function deployLv(
        address ra,
        address pa,
        address owner,
        uint256 _initialArp,
        uint256 _expiryInterval,
        address _exchangeRateProvider
    ) external returns (address lv);

    function getLv(address _ra, address _pa, uint256 initialArp, uint256 expiryInterval, address exchangeRateProvider)
        external
        view
        returns (address);
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

// lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// contracts/interfaces/IExpiry.sol

/**
 * @title IExpiry Interface
 * @author Cork Team
 * @notice IExpiry interface for Expiry contract
 */
interface IExpiry_1 is IErrors_0 {
    /// @notice returns true if the asset is expired
    function isExpired() external view returns (bool);

    ///@notice returns the expiry timestamp if 0 then it means it never expires
    function expiry() external view returns (uint256);

    ///@notice returns the timestamp when the asset was issued
    function issuedAt() external view returns (uint256);
}

// contracts/interfaces/IProtectedUnit.sol

interface IProtectedUnit is IErrors_0 {
    // Events
    /**
     * @notice Emitted when a user mints new ProtectedUnit tokens.
     * @param minter The address of the user minting the tokens.
     * @param amount The amount of ProtectedUnit tokens minted.
     */
    event Mint(address indexed minter, uint256 amount);

    /**
     * @notice Emitted when a user burns ProtectedUnit tokens.
     * @param dissolver The address of the user dissolving the tokens.
     * @param amount The amount of ProtectedUnit tokens burned.
     * @param dsAmount The amount of DS tokens received.
     * @param paAmount The amount of PA tokens received.
     */
    event Burn(address indexed dissolver, uint256 amount, uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Emitted when the mint cap is updated.
     * @param newMintCap The new mint cap value.
     */
    event MintCapUpdated(uint256 newMintCap);

    event RaRedeemed(address indexed redeemer, uint256 dsId, uint256 amount);

    // Read functions
    /**
     * @notice Returns the current mint cap.
     * @return mintCap The maximum supply cap for minting ProtectedUnit tokens.
     */
    function mintCap() external view returns (uint256);

    /**
     * @notice Returns the dsAmount and paAmount required to mint the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens required to mint the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens required to mint the specified amount of ProtectedUnit tokens.
     */
    function previewMint(uint256 amount) external view returns (uint256 dsAmount, uint256 paAmount);

    //functions
    /**
     * @notice Mints ProtectedUnit tokens by transferring the equivalent amount of DS and PA tokens.
     * @param amount The amount of ProtectedUnit tokens to mint.
     * @custom:reverts MintingPaused if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     * @return dsAmount The amount of DS tokens used to mint ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens used to mint ProtectedUnit tokens.
     */
    function mint(uint256 amount) external returns (uint256 dsAmount, uint256 paAmount);

    /**
     * @notice Returns the dsAmount, paAmount and raAmount received for dissolving the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return raAmount The amount of RA tokens received for dissolving the specified amount of ProtectedUnit tokens.
     */
    function previewBurn(address dissolver, uint256 amount)
        external
        view
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount);

    /**
     * @notice Updates the mint cap.
     * @param _newMintCap The new mint cap value.
     * @custom:reverts InvalidValue if the mint cap is not changed.
     */
    function updateMintCap(uint256 _newMintCap) external;

    function getReserves() external view returns (uint256 dsReserves, uint256 paReserves, uint256 raReserves);

    /**
     * @notice automatically sync reserve balance
     */
    function sync() external;
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/libraries/LPFeeLibrary.sol

/// @notice Library of helper functions for a pools LP fee
library LPFeeLibrary {
    using LPFeeLibrary for uint24;
    using CustomRevert for bytes4;

    /// @notice Thrown when the static or dynamic fee on a pool exceeds 100%.
    error LPFeeTooLarge(uint24 fee);

    /// @notice An lp fee of exactly 0b1000000... signals a dynamic fee pool. This isn't a valid static fee as it is > MAX_LP_FEE
    uint24 public constant DYNAMIC_FEE_FLAG = 0x800000;

    /// @notice the second bit of the fee returned by beforeSwap is used to signal if the stored LP fee should be overridden in this swap
    // only dynamic-fee pools can return a fee via the beforeSwap hook
    uint24 public constant OVERRIDE_FEE_FLAG = 0x400000;

    /// @notice mask to remove the override fee flag from a fee returned by the beforeSwaphook
    uint24 public constant REMOVE_OVERRIDE_MASK = 0xBFFFFF;

    /// @notice the lp fee is represented in hundredths of a bip, so the max is 100%
    uint24 public constant MAX_LP_FEE = 1000000;

    /// @notice returns true if a pool's LP fee signals that the pool has a dynamic fee
    /// @param self The fee to check
    /// @return bool True of the fee is dynamic
    function isDynamicFee(uint24 self) internal pure returns (bool) {
        return self == DYNAMIC_FEE_FLAG;
    }

    /// @notice returns true if an LP fee is valid, aka not above the maximum permitted fee
    /// @param self The fee to check
    /// @return bool True of the fee is valid
    function isValid(uint24 self) internal pure returns (bool) {
        return self <= MAX_LP_FEE;
    }

    /// @notice validates whether an LP fee is larger than the maximum, and reverts if invalid
    /// @param self The fee to validate
    function validate(uint24 self) internal pure {
        if (!self.isValid()) LPFeeTooLarge.selector.revertWith(self);
    }

    /// @notice gets and validates the initial LP fee for a pool. Dynamic fee pools have an initial fee of 0.
    /// @dev if a dynamic fee pool wants a non-0 initial fee, it should call `updateDynamicLPFee` in the afterInitialize hook
    /// @param self The fee to get the initial LP from
    /// @return initialFee 0 if the fee is dynamic, otherwise the fee (if valid)
    function getInitialLPFee(uint24 self) internal pure returns (uint24) {
        // the initial fee for a dynamic fee pool is 0
        if (self.isDynamicFee()) return 0;
        self.validate();
        return self;
    }

    /// @notice returns true if the fee has the override flag set (2nd highest bit of the uint24)
    /// @param self The fee to check
    /// @return bool True of the fee has the override flag set
    function isOverride(uint24 self) internal pure returns (bool) {
        return self & OVERRIDE_FEE_FLAG != 0;
    }

    /// @notice returns a fee with the override flag removed
    /// @param self The fee to remove the override flag from
    /// @return fee The fee without the override flag set
    function removeOverrideFlag(uint24 self) internal pure returns (uint24) {
        return self & REMOVE_OVERRIDE_MASK;
    }

    /// @notice Removes the override flag and validates the fee (reverts if the fee is too large)
    /// @param self The fee to remove the override flag from, and then validate
    /// @return fee The fee without the override flag set (if valid)
    function removeOverrideFlagAndValidate(uint24 self) internal pure returns (uint24 fee) {
        fee = self.removeOverrideFlag();
        fee.validate();
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/NoncesUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */
abstract contract NoncesUpgradeable is Initializable {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    /// @custom:storage-location erc7201:openzeppelin.storage.Nonces
    struct NoncesStorage {
        mapping(address account => uint256) _nonces;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Nonces")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NoncesStorageLocation = 0x5ab42ced628888259c08ac98db1eb0cf702fc1501344311d8b100cd1bfe4bb00;

    function _getNoncesStorage() private pure returns (NoncesStorage storage $) {
        assembly {
            $.slot := NoncesStorageLocation
        }
    }

    function __Nonces_init() internal onlyInitializing {
    }

    function __Nonces_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns the next unused nonce for an address.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        NoncesStorage storage $ = _getNoncesStorage();
        return $._nonces[owner];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal virtual returns (uint256) {
        NoncesStorage storage $ = _getNoncesStorage();
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return $._nonces[owner]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
    }
}

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts/contracts/utils/Pausable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// contracts/libraries/PermitChecker.sol

/**
 * @title PermitChecker Library Contract
 * @author Cork Team
 * @notice PermitChecker Library implements functions for checking if contract supports ERC20-Permit or not
 */
library PermitChecker {
    function supportsPermit(address token) internal view returns (bool) {
        return _hasNonces(token) && _hasDomainSeparator(token);
    }

    function _hasNonces(address token) internal view returns (bool) {
        try IERC20Permit(token).nonces(address(0)) returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    function _hasDomainSeparator(address token) internal view returns (bool) {
        try IERC20Permit(token).DOMAIN_SEPARATOR() returns (bytes32) {
            return true;
        } catch {
            return false;
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuardTransient.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuardTransient.sol)

/**
 * @dev Variant of {ReentrancyGuard} that uses transient storage.
 *
 * NOTE: This variant only works on networks where EIP-1153 is available.
 *
 * _Available since v5.1._
 */
abstract contract ReentrancyGuardTransient {
    using TransientSlot for *;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        REENTRANCY_GUARD_STORAGE.asBoolean().tstore(true);
    }

    function _nonReentrantAfter() private {
        REENTRANCY_GUARD_STORAGE.asBoolean().tstore(false);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return REENTRANCY_GUARD_STORAGE.asBoolean().tload();
    }
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/libraries/SafeCast.sol

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast_1 {
    using CustomRevert for bytes4;

    error SafeCastOverflow();

    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param x The uint256 to be downcasted
    /// @return y The downcasted integer, now type uint160
    function toUint160(uint256 x) internal pure returns (uint160 y) {
        y = uint160(x);
        if (y != x) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a uint256 to a uint128, revert on overflow
    /// @param x The uint256 to be downcasted
    /// @return y The downcasted integer, now type uint128
    function toUint128(uint256 x) internal pure returns (uint128 y) {
        y = uint128(x);
        if (x != y) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a int128 to a uint128, revert on overflow or underflow
    /// @param x The int128 to be casted
    /// @return y The casted integer, now type uint128
    function toUint128(int128 x) internal pure returns (uint128 y) {
        if (x < 0) SafeCastOverflow.selector.revertWith();
        y = uint128(x);
    }

    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param x The int256 to be downcasted
    /// @return y The downcasted integer, now type int128
    function toInt128(int256 x) internal pure returns (int128 y) {
        y = int128(x);
        if (y != x) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a uint256 to a int256, revert on overflow
    /// @param x The uint256 to be casted
    /// @return y The casted integer, now type int256
    function toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        if (y < 0) SafeCastOverflow.selector.revertWith();
    }

    /// @notice Cast a uint256 to a int128, revert on overflow
    /// @param x The uint256 to be downcasted
    /// @return The downcasted integer, now type int128
    function toInt128(uint256 x) internal pure returns (int128) {
        if (x >= 1 << 127) SafeCastOverflow.selector.revertWith();
        return int128(int256(x));
    }
}

// lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ShortStrings.sol)

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
    // Used as an identifier for strings longer than 31 bytes.
    bytes32 private constant FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        assembly ("memory-safe") {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev Decode a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
     */
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev Return the length of a string that was encoded to `ShortString` or written to storage using
     * {setWithFallback}.
     *
     * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
     * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
     */
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/math/SignedMath.sol)

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Branchless ternary evaluation for `a ? b : c`. Gas costs are constant.
     *
     * IMPORTANT: This function may reduce bytecode size and consume less gas when used standalone.
     * However, the compiler may optimize Solidity ternary operations (i.e. `a ? b : c`) to only compute
     * one branch when needed, making this function more expensive.
     */
    function ternary(bool condition, int256 a, int256 b) internal pure returns (int256) {
        unchecked {
            // branchless ternary works because:
            // b ^ (a ^ b) == a
            // b ^ 0 == b
            return b ^ ((a ^ b) * int256(SafeCast_0.toUint(condition)));
        }
    }

    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return ternary(a > b, a, b);
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return ternary(a < b, a, b);
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // Formula from the "Bit Twiddling Hacks" by Sean Eron Anderson.
            // Since `n` is a signed integer, the generated bytecode will use the SAR opcode to perform the right shift,
            // taking advantage of the most significant (or "sign" bit) in two's complement representation.
            // This opcode adds new most significant bits set to the value of the previous most significant bit. As a result,
            // the mask will either be `bytes32(0)` (if n is positive) or `~bytes32(0)` (if n is negative).
            int256 mask = n >> 255;

            // A `bytes32(0)` mask leaves the input unchanged, while a `~bytes32(0)` mask complements it.
            return uint256((n + mask) ^ mask);
        }
    }
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol

/// @dev Two `int128` values packed into a single `int256` where the upper 128 bits represent the amount0
/// and the lower 128 bits represent the amount1.
type BalanceDelta is int256;

using {add_0 as +, sub_0 as -, eq_0 as ==, neq_0 as !=} for BalanceDelta global;
using BalanceDeltaLibrary for BalanceDelta global;
using SafeCast_1 for int256;

function toBalanceDelta(int128 _amount0, int128 _amount1) pure returns (BalanceDelta balanceDelta) {
    assembly ("memory-safe") {
        balanceDelta := or(shl(128, _amount0), and(sub(shl(128, 1), 1), _amount1))
    }
}

function add_0(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
    int256 res0;
    int256 res1;
    assembly ("memory-safe") {
        let a0 := sar(128, a)
        let a1 := signextend(15, a)
        let b0 := sar(128, b)
        let b1 := signextend(15, b)
        res0 := add(a0, b0)
        res1 := add(a1, b1)
    }
    return toBalanceDelta(res0.toInt128(), res1.toInt128());
}

function sub_0(BalanceDelta a, BalanceDelta b) pure returns (BalanceDelta) {
    int256 res0;
    int256 res1;
    assembly ("memory-safe") {
        let a0 := sar(128, a)
        let a1 := signextend(15, a)
        let b0 := sar(128, b)
        let b1 := signextend(15, b)
        res0 := sub(a0, b0)
        res1 := sub(a1, b1)
    }
    return toBalanceDelta(res0.toInt128(), res1.toInt128());
}

function eq_0(BalanceDelta a, BalanceDelta b) pure returns (bool) {
    return BalanceDelta.unwrap(a) == BalanceDelta.unwrap(b);
}

function neq_0(BalanceDelta a, BalanceDelta b) pure returns (bool) {
    return BalanceDelta.unwrap(a) != BalanceDelta.unwrap(b);
}

/// @notice Library for getting the amount0 and amount1 deltas from the BalanceDelta type
library BalanceDeltaLibrary {
    /// @notice A BalanceDelta of 0
    BalanceDelta public constant ZERO_DELTA = BalanceDelta.wrap(0);

    function amount0(BalanceDelta balanceDelta) internal pure returns (int128 _amount0) {
        assembly ("memory-safe") {
            _amount0 := sar(128, balanceDelta)
        }
    }

    function amount1(BalanceDelta balanceDelta) internal pure returns (int128 _amount1) {
        assembly ("memory-safe") {
            _amount1 := signextend(15, balanceDelta)
        }
    }
}

// lib/openzeppelin-contracts/contracts/proxy/Clones.sol

// OpenZeppelin Contracts (last updated v5.1.0) (proxy/Clones.sol)

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[ERC-1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 */
library Clones {
    error CloneArgumentsTooLong();

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        return clone(implementation, 0);
    }

    /**
     * @dev Same as {xref-Clones-clone-address-}[clone], but with a `value` parameter to send native currency
     * to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function clone(address implementation, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(value, 0x09, 0x37)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple times will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(implementation, salt, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneDeterministic-address-bytes32-}[cloneDeterministic], but with
     * a `value` parameter to send native currency to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneDeterministic(
        address implementation,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(value, 0x09, 0x37, salt)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := and(keccak256(add(ptr, 0x43), 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, address(this));
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation` with custom
     * immutable arguments. These are provided through `args` and cannot be changed after deployment. To
     * access the arguments within the implementation, use {fetchCloneArgs}.
     *
     * This function uses the create opcode, which should never revert.
     */
    function cloneWithImmutableArgs(address implementation, bytes memory args) internal returns (address instance) {
        return cloneWithImmutableArgs(implementation, args, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneWithImmutableArgs-address-bytes-}[cloneWithImmutableArgs], but with a `value`
     * parameter to send native currency to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneWithImmutableArgs(
        address implementation,
        bytes memory args,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        assembly ("memory-safe") {
            instance := create(value, add(bytecode, 0x20), mload(bytecode))
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation` with custom
     * immutable arguments. These are provided through `args` and cannot be changed after deployment. To
     * access the arguments within the implementation, use {fetchCloneArgs}.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy the clone. Using the same
     * `implementation`, `args` and `salt` multiple time will revert, since the clones cannot be deployed twice
     * at the same address.
     */
    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        return cloneDeterministicWithImmutableArgs(implementation, args, salt, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneDeterministicWithImmutableArgs-address-bytes-bytes32-}[cloneDeterministicWithImmutableArgs],
     * but with a `value` parameter to send native currency to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.deploy(value, salt, bytecode);
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
     */
    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.computeAddress(salt, keccak256(bytecode), deployer);
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
     */
    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddressWithImmutableArgs(implementation, args, salt, address(this));
    }

    /**
     * @dev Get the immutable args attached to a clone.
     *
     * - If `instance` is a clone that was deployed using `clone` or `cloneDeterministic`, this
     *   function will return an empty array.
     * - If `instance` is a clone that was deployed using `cloneWithImmutableArgs` or
     *   `cloneDeterministicWithImmutableArgs`, this function will return the args array used at
     *   creation.
     * - If `instance` is NOT a clone deployed using this library, the behavior is undefined. This
     *   function should only be used to check addresses that are known to be clones.
     */
    function fetchCloneArgs(address instance) internal view returns (bytes memory) {
        bytes memory result = new bytes(instance.code.length - 45); // revert if length is too short
        assembly ("memory-safe") {
            extcodecopy(instance, add(result, 32), 45, mload(result))
        }
        return result;
    }

    /**
     * @dev Helper that prepares the initcode of the proxy with immutable args.
     *
     * An assembly variant of this function requires copying the `args` array, which can be efficiently done using
     * `mcopy`. Unfortunately, that opcode is not available before cancun. A pure solidity implementation using
     * abi.encodePacked is more expensive but also more portable and easier to review.
     *
     * NOTE: https://eips.ethereum.org/EIPS/eip-170[EIP-170] limits the length of the contract code to 24576 bytes.
     * With the proxy code taking 45 bytes, that limits the length of the immutable args to 24531 bytes.
     */
    function _cloneCodeWithImmutableArgs(
        address implementation,
        bytes memory args
    ) private pure returns (bytes memory) {
        if (args.length > 24531) revert CloneArgumentsTooLong();
        return
            abi.encodePacked(
                hex"61",
                uint16(args.length + 45),
                hex"3d81600a3d39f3363d3d373d3d3d363d73",
                implementation,
                hex"5af43d82803e903d91602b57fd5bf3",
                args
            );
    }
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/types/Currency.sol

type Currency is address;

using {greaterThan as >, lessThan as <, greaterThanOrEqualTo as >=, equals as ==} for Currency global;
using CurrencyLibrary for Currency global;

function equals(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) == Currency.unwrap(other);
}

function greaterThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) > Currency.unwrap(other);
}

function lessThan(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) < Currency.unwrap(other);
}

function greaterThanOrEqualTo(Currency currency, Currency other) pure returns (bool) {
    return Currency.unwrap(currency) >= Currency.unwrap(other);
}

/// @title CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
library CurrencyLibrary {
    /// @notice Additional context for ERC-7751 wrapped error when a native transfer fails
    error NativeTransferFailed();

    /// @notice Additional context for ERC-7751 wrapped error when an ERC20 transfer fails
    error ERC20TransferFailed();

    /// @notice A constant to represent the native currency
    Currency public constant ADDRESS_ZERO = Currency.wrap(address(0));

    function transfer(Currency currency, address to, uint256 amount) internal {
        // altered from https://github.com/transmissions11/solmate/blob/44a9963d4c78111f77caa0e65d677b8b46d6f2e6/src/utils/SafeTransferLib.sol
        // modified custom error selectors

        bool success;
        if (currency.isAddressZero()) {
            assembly ("memory-safe") {
                // Transfer the ETH and revert if it fails.
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }
            // revert with NativeTransferFailed, containing the bubbled up error as an argument
            if (!success) {
                CustomRevert.bubbleUpAndRevertWith(to, bytes4(0), NativeTransferFailed.selector);
            }
        } else {
            assembly ("memory-safe") {
                // Get a pointer to some free memory.
                let fmp := mload(0x40)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(fmp, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(fmp, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
                mstore(add(fmp, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

                success :=
                    and(
                        // Set success to whether the call reverted, if not we check it either
                        // returned exactly 1 (can't just be non-zero data), or had no return data.
                        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                        // Counterintuitively, this call must be positioned second to the or() call in the
                        // surrounding and() call or else returndatasize() will be zero during the computation.
                        call(gas(), currency, 0, fmp, 68, 0, 32)
                    )

                // Now clean the memory we used
                mstore(fmp, 0) // 4 byte `selector` and 28 bytes of `to` were stored here
                mstore(add(fmp, 0x20), 0) // 4 bytes of `to` and 28 bytes of `amount` were stored here
                mstore(add(fmp, 0x40), 0) // 4 bytes of `amount` were stored here
            }
            // revert with ERC20TransferFailed, containing the bubbled up error as an argument
            if (!success) {
                CustomRevert.bubbleUpAndRevertWith(
                    Currency.unwrap(currency), IERC20Minimal.transfer.selector, ERC20TransferFailed.selector
                );
            }
        }
    }

    function balanceOfSelf(Currency currency) internal view returns (uint256) {
        if (currency.isAddressZero()) {
            return address(this).balance;
        } else {
            return IERC20Minimal(Currency.unwrap(currency)).balanceOf(address(this));
        }
    }

    function balanceOf(Currency currency, address owner) internal view returns (uint256) {
        if (currency.isAddressZero()) {
            return owner.balance;
        } else {
            return IERC20Minimal(Currency.unwrap(currency)).balanceOf(owner);
        }
    }

    function isAddressZero(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == Currency.unwrap(ADDRESS_ZERO);
    }

    function toId(Currency currency) internal pure returns (uint256) {
        return uint160(Currency.unwrap(currency));
    }

    // If the upper 12 bytes are non-zero, they will be zero-ed out
    // Therefore, fromId() and toId() are not inverses of each other
    function fromId(uint256 id) internal pure returns (Currency) {
        return Currency.wrap(address(uint160(id)));
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// contracts/interfaces/IWithdrawal.sol

interface IWithdrawal is IErrors_0 {
    function add(address owner, IWithdrawalRouter.Tokens[] calldata tokens) external returns (bytes32 withdrawalId);

    function claimToSelf(bytes32 withdrawalId) external;

    function claimRouted(bytes32 withdrawalId, address router, bytes calldata routerData) external;

    event WithdrawalRequested(bytes32 indexed withdrawalId, address indexed owner, uint256 claimableAt);

    event WithdrawalClaimed(bytes32 indexed withdrawalId, address indexed owner);
}

// lib/openzeppelin-contracts/contracts/utils/math/Math.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an success flag (no overflow).
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an success flag (no overflow).
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an success flag (no overflow).
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a success flag (no division by zero).
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a success flag (no division by zero).
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Branchless ternary evaluation for `a ? b : c`. Gas costs are constant.
     *
     * IMPORTANT: This function may reduce bytecode size and consume less gas when used standalone.
     * However, the compiler may optimize Solidity ternary operations (i.e. `a ? b : c`) to only compute
     * one branch when needed, making this function more expensive.
     */
    function ternary(bool condition, uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            // branchless ternary works because:
            // b ^ (a ^ b) == a
            // b ^ 0 == b
            return b ^ ((a ^ b) * SafeCast_0.toUint(condition));
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a > b, a, b);
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a < b, a, b);
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }

        // The following calculation ensures accurate ceiling division without overflow.
        // Since a is non-zero, (a - 1) / b will not overflow.
        // The largest possible result occurs when (a - 1) / b is type(uint256).max,
        // but the largest value we can obtain is type(uint256).max - 1, which happens
        // when a = type(uint256).max and b = 1.
        unchecked {
            return SafeCast_0.toUint(a > 0) * ((a - 1) / b + 1);
        }
    }

    /**
     * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     *
     * Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2²⁵⁶ and mod 2²⁵⁶ - 1, then use
            // the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2²⁵⁶ + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2²⁵⁶. Also prevents denominator == 0.
            if (denominator <= prod1) {
                Panic.panic(ternary(denominator == 0, Panic.DIVISION_BY_ZERO, Panic.UNDER_OVERFLOW));
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2²⁵⁶ / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2²⁵⁶. Now that denominator is an odd number, it has an inverse modulo 2²⁵⁶ such
            // that denominator * inv ≡ 1 mod 2²⁵⁶. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv ≡ 1 mod 2⁴.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2¹⁶
            inverse *= 2 - denominator * inverse; // inverse mod 2³²
            inverse *= 2 - denominator * inverse; // inverse mod 2⁶⁴
            inverse *= 2 - denominator * inverse; // inverse mod 2¹²⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2²⁵⁶

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2²⁵⁶. Since the preconditions guarantee that the outcome is
            // less than 2²⁵⁶, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @dev Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        return mulDiv(x, y, denominator) + SafeCast_0.toUint(unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0);
    }

    /**
     * @dev Calculate the modular multiplicative inverse of a number in Z/nZ.
     *
     * If n is a prime, then Z/nZ is a field. In that case all elements are inversible, except 0.
     * If n is not a prime, then Z/nZ is not a field, and some elements might not be inversible.
     *
     * If the input value is not inversible, 0 is returned.
     *
     * NOTE: If you know for sure that n is (big) a prime, it may be cheaper to use Fermat's little theorem and get the
     * inverse using `Math.modExp(a, n - 2, n)`. See {invModPrime}.
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256) {
        unchecked {
            if (n == 0) return 0;

            // The inverse modulo is calculated using the Extended Euclidean Algorithm (iterative version)
            // Used to compute integers x and y such that: ax + ny = gcd(a, n).
            // When the gcd is 1, then the inverse of a modulo n exists and it's x.
            // ax + ny = 1
            // ax = 1 + (-y)n
            // ax ≡ 1 (mod n) # x is the inverse of a modulo n

            // If the remainder is 0 the gcd is n right away.
            uint256 remainder = a % n;
            uint256 gcd = n;

            // Therefore the initial coefficients are:
            // ax + ny = gcd(a, n) = n
            // 0a + 1n = n
            int256 x = 0;
            int256 y = 1;

            while (remainder != 0) {
                uint256 quotient = gcd / remainder;

                (gcd, remainder) = (
                    // The old remainder is the next gcd to try.
                    remainder,
                    // Compute the next remainder.
                    // Can't overflow given that (a % gcd) * (gcd // (a % gcd)) <= gcd
                    // where gcd is at most n (capped to type(uint256).max)
                    gcd - remainder * quotient
                );

                (x, y) = (
                    // Increment the coefficient of a.
                    y,
                    // Decrement the coefficient of n.
                    // Can overflow, but the result is casted to uint256 so that the
                    // next value of y is "wrapped around" to a value between 0 and n - 1.
                    x - y * int256(quotient)
                );
            }

            if (gcd != 1) return 0; // No inverse exists.
            return ternary(x < 0, n - uint256(-x), uint256(x)); // Wrap the result if it's negative.
        }
    }

    /**
     * @dev Variant of {invMod}. More efficient, but only works if `p` is known to be a prime greater than `2`.
     *
     * From https://en.wikipedia.org/wiki/Fermat%27s_little_theorem[Fermat's little theorem], we know that if p is
     * prime, then `a**(p-1) ≡ 1 mod p`. As a consequence, we have `a * a**(p-2) ≡ 1 mod p`, which means that
     * `a**(p-2)` is the modular multiplicative inverse of a in Fp.
     *
     * NOTE: this function does NOT check that `p` is a prime greater than `2`.
     */
    function invModPrime(uint256 a, uint256 p) internal view returns (uint256) {
        unchecked {
            return Math.modExp(a, p - 2, p);
        }
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m)
     *
     * Requirements:
     * - modulus can't be zero
     * - underlying staticcall to precompile must succeed
     *
     * IMPORTANT: The result is only valid if the underlying call succeeds. When using this function, make
     * sure the chain you're using it on supports the precompiled contract for modular exponentiation
     * at address 0x05 as specified in https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise,
     * the underlying function will succeed given the lack of a revert, but the result may be incorrectly
     * interpreted as 0.
     */
    function modExp(uint256 b, uint256 e, uint256 m) internal view returns (uint256) {
        (bool success, uint256 result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m).
     * It includes a success flag indicating if the operation succeeded. Operation will be marked as failed if trying
     * to operate modulo 0 or if the underlying precompile reverted.
     *
     * IMPORTANT: The result is only valid if the success flag is true. When using this function, make sure the chain
     * you're using it on supports the precompiled contract for modular exponentiation at address 0x05 as specified in
     * https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise, the underlying function will succeed given the lack
     * of a revert, but the result may be incorrectly interpreted as 0.
     */
    function tryModExp(uint256 b, uint256 e, uint256 m) internal view returns (bool success, uint256 result) {
        if (m == 0) return (false, 0);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            // | Offset    | Content    | Content (Hex)                                                      |
            // |-----------|------------|--------------------------------------------------------------------|
            // | 0x00:0x1f | size of b  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x20:0x3f | size of e  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x40:0x5f | size of m  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x60:0x7f | value of b | 0x<.............................................................b> |
            // | 0x80:0x9f | value of e | 0x<.............................................................e> |
            // | 0xa0:0xbf | value of m | 0x<.............................................................m> |
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), b)
            mstore(add(ptr, 0x80), e)
            mstore(add(ptr, 0xa0), m)

            // Given the result < m, it's guaranteed to fit in 32 bytes,
            // so we can use the memory scratch space located at offset 0.
            success := staticcall(gas(), 0x05, ptr, 0xc0, 0x00, 0x20)
            result := mload(0x00)
        }
    }

    /**
     * @dev Variant of {modExp} that supports inputs of arbitrary length.
     */
    function modExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bytes memory) {
        (bool success, bytes memory result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Variant of {tryModExp} that supports inputs of arbitrary length.
     */
    function tryModExp(
        bytes memory b,
        bytes memory e,
        bytes memory m
    ) internal view returns (bool success, bytes memory result) {
        if (_zeroBytes(m)) return (false, new bytes(0));

        uint256 mLen = m.length;

        // Encode call args in result and move the free memory pointer
        result = abi.encodePacked(b.length, e.length, mLen, b, e, m);

        assembly ("memory-safe") {
            let dataPtr := add(result, 0x20)
            // Write result on top of args to avoid allocating extra memory.
            success := staticcall(gas(), 0x05, dataPtr, mload(result), dataPtr, mLen)
            // Overwrite the length.
            // result.length > returndatasize() is guaranteed because returndatasize() == m.length
            mstore(result, mLen)
            // Set the memory pointer after the returned data.
            mstore(0x40, add(dataPtr, mLen))
        }
    }

    /**
     * @dev Returns whether the provided byte array is zero.
     */
    function _zeroBytes(bytes memory byteArray) private pure returns (bool) {
        for (uint256 i = 0; i < byteArray.length; ++i) {
            if (byteArray[i] != 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * This method is based on Newton's method for computing square roots; the algorithm is restricted to only
     * using integer operations.
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        unchecked {
            // Take care of easy edge cases when a == 0 or a == 1
            if (a <= 1) {
                return a;
            }

            // In this function, we use Newton's method to get a root of `f(x) := x² - a`. It involves building a
            // sequence x_n that converges toward sqrt(a). For each iteration x_n, we also define the error between
            // the current value as `ε_n = | x_n - sqrt(a) |`.
            //
            // For our first estimation, we consider `e` the smallest power of 2 which is bigger than the square root
            // of the target. (i.e. `2**(e-1) ≤ sqrt(a) < 2**e`). We know that `e ≤ 128` because `(2¹²⁸)² = 2²⁵⁶` is
            // bigger than any uint256.
            //
            // By noticing that
            // `2**(e-1) ≤ sqrt(a) < 2**e → (2**(e-1))² ≤ a < (2**e)² → 2**(2*e-2) ≤ a < 2**(2*e)`
            // we can deduce that `e - 1` is `log2(a) / 2`. We can thus compute `x_n = 2**(e-1)` using a method similar
            // to the msb function.
            uint256 aa = a;
            uint256 xn = 1;

            if (aa >= (1 << 128)) {
                aa >>= 128;
                xn <<= 64;
            }
            if (aa >= (1 << 64)) {
                aa >>= 64;
                xn <<= 32;
            }
            if (aa >= (1 << 32)) {
                aa >>= 32;
                xn <<= 16;
            }
            if (aa >= (1 << 16)) {
                aa >>= 16;
                xn <<= 8;
            }
            if (aa >= (1 << 8)) {
                aa >>= 8;
                xn <<= 4;
            }
            if (aa >= (1 << 4)) {
                aa >>= 4;
                xn <<= 2;
            }
            if (aa >= (1 << 2)) {
                xn <<= 1;
            }

            // We now have x_n such that `x_n = 2**(e-1) ≤ sqrt(a) < 2**e = 2 * x_n`. This implies ε_n ≤ 2**(e-1).
            //
            // We can refine our estimation by noticing that the middle of that interval minimizes the error.
            // If we move x_n to equal 2**(e-1) + 2**(e-2), then we reduce the error to ε_n ≤ 2**(e-2).
            // This is going to be our x_0 (and ε_0)
            xn = (3 * xn) >> 1; // ε_0 := | x_0 - sqrt(a) | ≤ 2**(e-2)

            // From here, Newton's method give us:
            // x_{n+1} = (x_n + a / x_n) / 2
            //
            // One should note that:
            // x_{n+1}² - a = ((x_n + a / x_n) / 2)² - a
            //              = ((x_n² + a) / (2 * x_n))² - a
            //              = (x_n⁴ + 2 * a * x_n² + a²) / (4 * x_n²) - a
            //              = (x_n⁴ + 2 * a * x_n² + a² - 4 * a * x_n²) / (4 * x_n²)
            //              = (x_n⁴ - 2 * a * x_n² + a²) / (4 * x_n²)
            //              = (x_n² - a)² / (2 * x_n)²
            //              = ((x_n² - a) / (2 * x_n))²
            //              ≥ 0
            // Which proves that for all n ≥ 1, sqrt(a) ≤ x_n
            //
            // This gives us the proof of quadratic convergence of the sequence:
            // ε_{n+1} = | x_{n+1} - sqrt(a) |
            //         = | (x_n + a / x_n) / 2 - sqrt(a) |
            //         = | (x_n² + a - 2*x_n*sqrt(a)) / (2 * x_n) |
            //         = | (x_n - sqrt(a))² / (2 * x_n) |
            //         = | ε_n² / (2 * x_n) |
            //         = ε_n² / | (2 * x_n) |
            //
            // For the first iteration, we have a special case where x_0 is known:
            // ε_1 = ε_0² / | (2 * x_0) |
            //     ≤ (2**(e-2))² / (2 * (2**(e-1) + 2**(e-2)))
            //     ≤ 2**(2*e-4) / (3 * 2**(e-1))
            //     ≤ 2**(e-3) / 3
            //     ≤ 2**(e-3-log2(3))
            //     ≤ 2**(e-4.5)
            //
            // For the following iterations, we use the fact that, 2**(e-1) ≤ sqrt(a) ≤ x_n:
            // ε_{n+1} = ε_n² / | (2 * x_n) |
            //         ≤ (2**(e-k))² / (2 * 2**(e-1))
            //         ≤ 2**(2*e-2*k) / 2**e
            //         ≤ 2**(e-2*k)
            xn = (xn + a / xn) >> 1; // ε_1 := | x_1 - sqrt(a) | ≤ 2**(e-4.5)  -- special case, see above
            xn = (xn + a / xn) >> 1; // ε_2 := | x_2 - sqrt(a) | ≤ 2**(e-9)    -- general case with k = 4.5
            xn = (xn + a / xn) >> 1; // ε_3 := | x_3 - sqrt(a) | ≤ 2**(e-18)   -- general case with k = 9
            xn = (xn + a / xn) >> 1; // ε_4 := | x_4 - sqrt(a) | ≤ 2**(e-36)   -- general case with k = 18
            xn = (xn + a / xn) >> 1; // ε_5 := | x_5 - sqrt(a) | ≤ 2**(e-72)   -- general case with k = 36
            xn = (xn + a / xn) >> 1; // ε_6 := | x_6 - sqrt(a) | ≤ 2**(e-144)  -- general case with k = 72

            // Because e ≤ 128 (as discussed during the first estimation phase), we know have reached a precision
            // ε_6 ≤ 2**(e-144) < 1. Given we're operating on integers, then we can ensure that xn is now either
            // sqrt(a) or sqrt(a) + 1.
            return xn - SafeCast_0.toUint(xn > a / xn);
        }
    }

    /**
     * @dev Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + SafeCast_0.toUint(unsignedRoundsUp(rounding) && result * result < a);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast_0.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast_0.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast_0.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast_0.toUint((x >> r) > 0xffff) << 4;
        // If upper 8 bits of 16-bit half set, add 8 to result
        r |= SafeCast_0.toUint((x >> r) > 0xff) << 3;
        // If upper 4 bits of 8-bit half set, add 4 to result
        r |= SafeCast_0.toUint((x >> r) > 0xf) << 2;

        // Shifts value right by the current result and use it as an index into this lookup table:
        //
        // | x (4 bits) |  index  | table[index] = MSB position |
        // |------------|---------|-----------------------------|
        // |    0000    |    0    |        table[0] = 0         |
        // |    0001    |    1    |        table[1] = 0         |
        // |    0010    |    2    |        table[2] = 1         |
        // |    0011    |    3    |        table[3] = 1         |
        // |    0100    |    4    |        table[4] = 2         |
        // |    0101    |    5    |        table[5] = 2         |
        // |    0110    |    6    |        table[6] = 2         |
        // |    0111    |    7    |        table[7] = 2         |
        // |    1000    |    8    |        table[8] = 3         |
        // |    1001    |    9    |        table[9] = 3         |
        // |    1010    |   10    |        table[10] = 3        |
        // |    1011    |   11    |        table[11] = 3        |
        // |    1100    |   12    |        table[12] = 3        |
        // |    1101    |   13    |        table[13] = 3        |
        // |    1110    |   14    |        table[14] = 3        |
        // |    1111    |   15    |        table[15] = 3        |
        //
        // The lookup table is represented as a 32-byte value with the MSB positions for 0-15 in the last 16 bytes.
        assembly ("memory-safe") {
            r := or(r, byte(shr(r, x), 0x0000010102020202030303030303030300000000000000000000000000000000))
        }
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + SafeCast_0.toUint(unsignedRoundsUp(rounding) && 1 << result < value);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + SafeCast_0.toUint(unsignedRoundsUp(rounding) && 10 ** result < value);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast_0.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast_0.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast_0.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast_0.toUint((x >> r) > 0xffff) << 4;
        // Add 1 if upper 8 bits of 16-bit half set, and divide accumulated result by 8
        return (r >> 3) | SafeCast_0.toUint((x >> r) > 0xff);
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + SafeCast_0.toUint(unsignedRoundsUp(rounding) && 1 << (result << 3) < value);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts/contracts/access/AccessControl.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/Strings.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/Strings.sol)

/**
 * @dev String operations.
 */
library Strings {
    using SafeCast_0 for *;

    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev The string being parsed contains characters that are not in scope of the given base.
     */
    error StringsInvalidChar();

    /**
     * @dev The string being parsed is not a properly formatted address.
     */
    error StringsInvalidAddressFormat();

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            assembly ("memory-safe") {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                assembly ("memory-safe") {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its checksummed ASCII `string` hexadecimal
     * representation, according to EIP-55.
     */
    function toChecksumHexString(address addr) internal pure returns (string memory) {
        bytes memory buffer = bytes(toHexString(addr));

        // hash the hex part of buffer (skip length + 2 bytes, length 40)
        uint256 hashValue;
        assembly ("memory-safe") {
            hashValue := shr(96, keccak256(add(buffer, 0x22), 40))
        }

        for (uint256 i = 41; i > 1; --i) {
            // possible values for buffer[i] are 48 (0) to 57 (9) and 97 (a) to 102 (f)
            if (hashValue & 0xf > 7 && uint8(buffer[i]) > 96) {
                // case shift by xoring with 0x20
                buffer[i] ^= 0x20;
            }
            hashValue >>= 4;
        }
        return string(buffer);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /**
     * @dev Parse a decimal string and returns the value as a `uint256`.
     *
     * Requirements:
     * - The string must be formatted as `[0-9]*`
     * - The result must fit into an `uint256` type
     */
    function parseUint(string memory input) internal pure returns (uint256) {
        return parseUint(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseUint} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `[0-9]*`
     * - The result must fit into an `uint256` type
     */
    function parseUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseUint(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @dev Variant of {parseUint-string} that returns false if the parsing fails because of an invalid character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseUint(string memory input) internal pure returns (bool success, uint256 value) {
        return _tryParseUintUncheckedBounds(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseUint-string-uint256-uint256} that returns false if the parsing fails because of an invalid
     * character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseUint(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, uint256 value) {
        if (end > bytes(input).length || begin > end) return (false, 0);
        return _tryParseUintUncheckedBounds(input, begin, end);
    }

    /**
     * @dev Variant of {tryParseUint} that does not check bounds and returns (true, 0) if they are invalid.
     */
    function _tryParseUintUncheckedBounds(
        string memory input,
        uint256 begin,
        uint256 end
    ) private pure returns (bool success, uint256 value) {
        bytes memory buffer = bytes(input);

        uint256 result = 0;
        for (uint256 i = begin; i < end; ++i) {
            uint8 chr = _tryParseChr(bytes1(_unsafeReadBytesOffset(buffer, i)));
            if (chr > 9) return (false, 0);
            result *= 10;
            result += chr;
        }
        return (true, result);
    }

    /**
     * @dev Parse a decimal string and returns the value as a `int256`.
     *
     * Requirements:
     * - The string must be formatted as `[-+]?[0-9]*`
     * - The result must fit in an `int256` type.
     */
    function parseInt(string memory input) internal pure returns (int256) {
        return parseInt(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseInt-string} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `[-+]?[0-9]*`
     * - The result must fit in an `int256` type.
     */
    function parseInt(string memory input, uint256 begin, uint256 end) internal pure returns (int256) {
        (bool success, int256 value) = tryParseInt(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @dev Variant of {parseInt-string} that returns false if the parsing fails because of an invalid character or if
     * the result does not fit in a `int256`.
     *
     * NOTE: This function will revert if the absolute value of the result does not fit in a `uint256`.
     */
    function tryParseInt(string memory input) internal pure returns (bool success, int256 value) {
        return _tryParseIntUncheckedBounds(input, 0, bytes(input).length);
    }

    uint256 private constant ABS_MIN_INT256 = 2 ** 255;

    /**
     * @dev Variant of {parseInt-string-uint256-uint256} that returns false if the parsing fails because of an invalid
     * character or if the result does not fit in a `int256`.
     *
     * NOTE: This function will revert if the absolute value of the result does not fit in a `uint256`.
     */
    function tryParseInt(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, int256 value) {
        if (end > bytes(input).length || begin > end) return (false, 0);
        return _tryParseIntUncheckedBounds(input, begin, end);
    }

    /**
     * @dev Variant of {tryParseInt} that does not check bounds and returns (true, 0) if they are invalid.
     */
    function _tryParseIntUncheckedBounds(
        string memory input,
        uint256 begin,
        uint256 end
    ) private pure returns (bool success, int256 value) {
        bytes memory buffer = bytes(input);

        // Check presence of a negative sign.
        bytes1 sign = begin == end ? bytes1(0) : bytes1(_unsafeReadBytesOffset(buffer, begin)); // don't do out-of-bound (possibly unsafe) read if sub-string is empty
        bool positiveSign = sign == bytes1("+");
        bool negativeSign = sign == bytes1("-");
        uint256 offset = (positiveSign || negativeSign).toUint();

        (bool absSuccess, uint256 absValue) = tryParseUint(input, begin + offset, end);

        if (absSuccess && absValue < ABS_MIN_INT256) {
            return (true, negativeSign ? -int256(absValue) : int256(absValue));
        } else if (absSuccess && negativeSign && absValue == ABS_MIN_INT256) {
            return (true, type(int256).min);
        } else return (false, 0);
    }

    /**
     * @dev Parse a hexadecimal string (with or without "0x" prefix), and returns the value as a `uint256`.
     *
     * Requirements:
     * - The string must be formatted as `(0x)?[0-9a-fA-F]*`
     * - The result must fit in an `uint256` type.
     */
    function parseHexUint(string memory input) internal pure returns (uint256) {
        return parseHexUint(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseHexUint} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `(0x)?[0-9a-fA-F]*`
     * - The result must fit in an `uint256` type.
     */
    function parseHexUint(string memory input, uint256 begin, uint256 end) internal pure returns (uint256) {
        (bool success, uint256 value) = tryParseHexUint(input, begin, end);
        if (!success) revert StringsInvalidChar();
        return value;
    }

    /**
     * @dev Variant of {parseHexUint-string} that returns false if the parsing fails because of an invalid character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseHexUint(string memory input) internal pure returns (bool success, uint256 value) {
        return _tryParseHexUintUncheckedBounds(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseHexUint-string-uint256-uint256} that returns false if the parsing fails because of an
     * invalid character.
     *
     * NOTE: This function will revert if the result does not fit in a `uint256`.
     */
    function tryParseHexUint(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, uint256 value) {
        if (end > bytes(input).length || begin > end) return (false, 0);
        return _tryParseHexUintUncheckedBounds(input, begin, end);
    }

    /**
     * @dev Variant of {tryParseHexUint} that does not check bounds and returns (true, 0) if they are invalid.
     */
    function _tryParseHexUintUncheckedBounds(
        string memory input,
        uint256 begin,
        uint256 end
    ) private pure returns (bool success, uint256 value) {
        bytes memory buffer = bytes(input);

        // skip 0x prefix if present
        bool hasPrefix = (begin < end + 1) && bytes2(_unsafeReadBytesOffset(buffer, begin)) == bytes2("0x"); // don't do out-of-bound (possibly unsafe) read if sub-string is empty
        uint256 offset = hasPrefix.toUint() * 2;

        uint256 result = 0;
        for (uint256 i = begin + offset; i < end; ++i) {
            uint8 chr = _tryParseChr(bytes1(_unsafeReadBytesOffset(buffer, i)));
            if (chr > 15) return (false, 0);
            result *= 16;
            unchecked {
                // Multiplying by 16 is equivalent to a shift of 4 bits (with additional overflow check).
                // This guaratees that adding a value < 16 will not cause an overflow, hence the unchecked.
                result += chr;
            }
        }
        return (true, result);
    }

    /**
     * @dev Parse a hexadecimal string (with or without "0x" prefix), and returns the value as an `address`.
     *
     * Requirements:
     * - The string must be formatted as `(0x)?[0-9a-fA-F]{40}`
     */
    function parseAddress(string memory input) internal pure returns (address) {
        return parseAddress(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseAddress} that parses a substring of `input` located between position `begin` (included) and
     * `end` (excluded).
     *
     * Requirements:
     * - The substring must be formatted as `(0x)?[0-9a-fA-F]{40}`
     */
    function parseAddress(string memory input, uint256 begin, uint256 end) internal pure returns (address) {
        (bool success, address value) = tryParseAddress(input, begin, end);
        if (!success) revert StringsInvalidAddressFormat();
        return value;
    }

    /**
     * @dev Variant of {parseAddress-string} that returns false if the parsing fails because the input is not a properly
     * formatted address. See {parseAddress} requirements.
     */
    function tryParseAddress(string memory input) internal pure returns (bool success, address value) {
        return tryParseAddress(input, 0, bytes(input).length);
    }

    /**
     * @dev Variant of {parseAddress-string-uint256-uint256} that returns false if the parsing fails because input is not a properly
     * formatted address. See {parseAddress} requirements.
     */
    function tryParseAddress(
        string memory input,
        uint256 begin,
        uint256 end
    ) internal pure returns (bool success, address value) {
        // check that input is the correct length
        bool hasPrefix = (begin < end + 1) && bytes2(_unsafeReadBytesOffset(bytes(input), begin)) == bytes2("0x"); // don't do out-of-bound (possibly unsafe) read if sub-string is empty

        uint256 expectedLength = 40 + hasPrefix.toUint() * 2;

        if (end - begin == expectedLength && end <= bytes(input).length) {
            // length guarantees that this does not overflow, and value is at most type(uint160).max
            (bool s, uint256 v) = _tryParseHexUintUncheckedBounds(input, begin, end);
            return (s, address(uint160(v)));
        } else {
            return (false, address(0));
        }
    }

    function _tryParseChr(bytes1 chr) private pure returns (uint8) {
        uint8 value = uint8(chr);

        // Try to parse `chr`:
        // - Case 1: [0-9]
        // - Case 2: [a-f]
        // - Case 3: [A-F]
        // - otherwise not supported
        unchecked {
            if (value > 47 && value < 58) value -= 48;
            else if (value > 96 && value < 103) value -= 87;
            else if (value > 64 && value < 71) value -= 55;
            else return type(uint8).max;
        }

        return value;
    }

    /**
     * @dev Reads a bytes32 from a bytes array without bounds checking.
     *
     * NOTE: making this function internal would mean it could be used with memory unsafe offset, and marking the
     * assembly block as such would prevent some optimizations.
     */
    function _unsafeReadBytesOffset(bytes memory buffer, uint256 offset) private pure returns (bytes32 value) {
        // This is not memory safe in the general case, but all calls to this private function are within bounds.
        assembly ("memory-safe") {
            value := mload(add(buffer, add(0x20, offset)))
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControl, ERC165Upgradeable {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @custom:storage-location erc7201:openzeppelin.storage.AccessControl
    struct AccessControlStorage {
        mapping(bytes32 role => RoleData) _roles;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AccessControlStorageLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;

    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := AccessControlStorageLocation
        }
    }

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        AccessControlStorage storage $ = _getAccessControlStorage();
        bytes32 previousAdminRole = getRoleAdmin(role);
        $._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (!hasRole(role, account)) {
            $._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (hasRole(role, account)) {
            $._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol

// OpenZeppelin Contracts (last updated v5.1.0) (proxy/ERC1967/ERC1967Utils.sol)

/**
 * @dev This library provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] slots.
 */
library ERC1967Utils {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit IERC1967.Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit IERC1967.AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the ERC-1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit IERC1967.BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Burnable.sol)

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys a `value` amount of tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, deducting from
     * the caller's allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `value`.
     */
    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20, IERC20Metadata, IERC20Errors {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;

        mapping(address account => mapping(address spender => uint256)) _allowances;

        uint256 _totalSupply;

        string _name;
        string _symbol;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC20Storage storage $ = _getERC20Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/cryptography/MessageHashUtils.sol)

/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[ERC-191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an ERC-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        assembly ("memory-safe") {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    /**
     * @dev Returns the keccak256 digest of an ERC-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing an arbitrary `message` with
     * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return
            keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }

    /**
     * @dev Returns the keccak256 digest of an ERC-191 signed data with version
     * `0x00` (data with intended validator).
     *
     * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
     * `validator` address. Then hashing the result.
     *
     * See {ECDSA-recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (ERC-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20BurnableUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Burnable.sol)

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20BurnableUpgradeable is Initializable, ContextUpgradeable, ERC20Upgradeable {
    function __ERC20Burnable_init() internal onlyInitializing {
    }

    function __ERC20Burnable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Destroys a `value` amount of tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, deducting from
     * the caller's allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `value`.
     */
    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}

// contracts/libraries/PeggedAssetLib.sol

/**
 * @dev PeggedAsset structure for PA(Pegged Assets)
 */
struct PeggedAsset {
    address _address;
}

/**
 * @title PeggedAssetLibrary Contract
 * @author Cork Team
 * @notice PeggedAsset Library which implements functions for Pegged assets
 */
library PeggedAssetLibrary {
    using PeggedAssetLibrary for PeggedAsset;
    using SafeERC20 for IERC20;

    function asErc20(PeggedAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }
}

// contracts/libraries/Pair.sol

type Id is bytes32;

/**
 * @dev represent a RA/PA pair
 */
struct Pair {
    // pa/ct
    address pa;
    // ra/ds
    address ra;
    // initial arp
    uint256 initialArp;
    // expiry interval
    uint256 expiryInterval;
    // IExchangeRateProvider contract address
    address exchangeRateProvider;
}

/**
 * @title PairLibrary Contract
 * @author Cork Team
 * @notice Pair Library which implements functions for handling Pair operations
 */
library PairLibrary {
    using PeggedAssetLibrary for PeggedAsset;

    /// @notice Zero Address error, thrown when passed address is 0
    error ZeroAddress();

    error InvalidAddress();

    function toId(Pair memory key) internal pure returns (Id id) {
        id = Id.wrap(keccak256(abi.encode(key)));
    }

    function initalize(address pa, address ra, uint256 initialArp, uint256 expiry, address exchangeRateProvider)
        internal
        pure
        returns (Pair memory key)
    {
        if (pa == address(0) || ra == address(0)) {
            revert ZeroAddress();
        }
        if (pa == ra) {
            revert InvalidAddress();
        }
        key = Pair(pa, ra, initialArp, expiry, exchangeRateProvider);
    }

    function peggedAsset(Pair memory key) internal pure returns (PeggedAsset memory pa) {
        pa = PeggedAsset({_address: key.pa});
    }

    function underlyingAsset(Pair memory key) internal pure returns (address ra, address pa) {
        pa = key.pa;
        ra = key.ra;
    }

    function redemptionAsset(Pair memory key) internal pure returns (address ra) {
        ra = key.ra;
    }

    function isInitialized(Pair memory key) internal pure returns (bool status) {
        status = key.pa != address(0) && key.ra != address(0);
    }
}

// contracts/libraries/RedemptionAssetManagerLib.sol

/**
 * @dev RedemptionAssetManager structure for Redemption Manager
 */
struct RedemptionAssetManager {
    address _address;
    uint256 locked;
    uint256 free;
}

/**
 * @title RedemptionAssetManagerLibrary Contract
 * @author Cork Team
 * @notice RedemptionAssetManager Library implements functions for RA(Redemption Assets) contract
 */
library RedemptionAssetManagerLibrary {
    using MinimalSignatureHelper for Signature;
    using SafeERC20 for IERC20;

    function initialize(address ra) internal pure returns (RedemptionAssetManager memory) {
        return RedemptionAssetManager(ra, 0, 0);
    }

    function reset(RedemptionAssetManager storage self) internal {
        self.locked = 0;
        self.free = 0;
    }

    function incLocked(RedemptionAssetManager storage self, uint256 amount) internal {
        self.locked = self.locked + amount;
    }

    function convertAllToFree(RedemptionAssetManager storage self) internal returns (uint256) {
        if (self.locked == 0) {
            return self.free;
        }

        self.free = self.free + self.locked;
        self.locked = 0;

        return self.free;
    }

    function decLocked(RedemptionAssetManager storage self, uint256 amount) internal {
        self.locked = self.locked - amount;
    }

    function lockFrom(RedemptionAssetManager storage self, uint256 amount, address from) internal {
        incLocked(self, amount);
        lockUnchecked(self, amount, from);
    }

    function lockUnchecked(RedemptionAssetManager storage self, uint256 amount, address from) internal {
        IERC20(self._address).safeTransferFrom(from, address(this), amount);
    }

    function unlockTo(RedemptionAssetManager storage self, address to, uint256 amount) internal {
        decLocked(self, amount);
        unlockToUnchecked(self, amount, to);
    }

    function unlockToUnchecked(RedemptionAssetManager storage self, uint256 amount, address to) internal {
        IERC20(self._address).safeTransfer(to, amount);
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/cryptography/EIP712.sol)

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP-712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP-712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * NOTE: In the upgradeable version of this contract, the cached values will correspond to the address, and the domain
 * separator of the implementation contract. This will cause the {_domainSeparatorV4} function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 */
abstract contract EIP712Upgradeable is Initializable, IERC5267 {
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @custom:storage-location erc7201:openzeppelin.storage.EIP712
    struct EIP712Storage {
        /// @custom:oz-renamed-from _HASHED_NAME
        bytes32 _hashedName;
        /// @custom:oz-renamed-from _HASHED_VERSION
        bytes32 _hashedVersion;

        string _name;
        string _version;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.EIP712")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant EIP712StorageLocation = 0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100;

    function _getEIP712Storage() private pure returns (EIP712Storage storage $) {
        assembly {
            $.slot := EIP712StorageLocation
        }
    }

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP-712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    function __EIP712_init(string memory name, string memory version) internal onlyInitializing {
        __EIP712_init_unchained(name, version);
    }

    function __EIP712_init_unchained(string memory name, string memory version) internal onlyInitializing {
        EIP712Storage storage $ = _getEIP712Storage();
        $._name = name;
        $._version = version;

        // Reset prior values in storage if upgrading
        $._hashedName = 0;
        $._hashedVersion = 0;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return _buildDomainSeparator();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _EIP712NameHash(), _EIP712VersionHash(), block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {IERC-5267}.
     */
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        EIP712Storage storage $ = _getEIP712Storage();
        // If the hashed name and version in storage are non-zero, the contract hasn't been properly initialized
        // and the EIP712 domain is not reliable, as it will be missing name and version.
        require($._hashedName == 0 && $._hashedVersion == 0, "EIP712: Uninitialized");

        return (
            hex"0f", // 01111
            _EIP712Name(),
            _EIP712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /**
     * @dev The name parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712Name() internal view virtual returns (string memory) {
        EIP712Storage storage $ = _getEIP712Storage();
        return $._name;
    }

    /**
     * @dev The version parameter for the EIP712 domain.
     *
     * NOTE: This function reads from storage by default, but can be redefined to return a constant value if gas costs
     * are a concern.
     */
    function _EIP712Version() internal view virtual returns (string memory) {
        EIP712Storage storage $ = _getEIP712Storage();
        return $._version;
    }

    /**
     * @dev The hash of the name parameter for the EIP712 domain.
     *
     * NOTE: In previous versions this function was virtual. In this version you should override `_EIP712Name` instead.
     */
    function _EIP712NameHash() internal view returns (bytes32) {
        EIP712Storage storage $ = _getEIP712Storage();
        string memory name = _EIP712Name();
        if (bytes(name).length > 0) {
            return keccak256(bytes(name));
        } else {
            // If the name is empty, the contract may have been upgraded without initializing the new storage.
            // We return the name hash in storage if non-zero, otherwise we assume the name is empty by design.
            bytes32 hashedName = $._hashedName;
            if (hashedName != 0) {
                return hashedName;
            } else {
                return keccak256("");
            }
        }
    }

    /**
     * @dev The hash of the version parameter for the EIP712 domain.
     *
     * NOTE: In previous versions this function was virtual. In this version you should override `_EIP712Version` instead.
     */
    function _EIP712VersionHash() internal view returns (bytes32) {
        EIP712Storage storage $ = _getEIP712Storage();
        string memory version = _EIP712Version();
        if (bytes(version).length > 0) {
            return keccak256(bytes(version));
        } else {
            // If the version is empty, the contract may have been upgraded without initializing the new storage.
            // We return the version hash in storage if non-zero, otherwise we assume the version is empty by design.
            bytes32 hashedVersion = $._hashedVersion;
            if (hashedVersion != 0) {
                return hashedVersion;
            } else {
                return keccak256("");
            }
        }
    }
}

// contracts/interfaces/IExchangeRateProvider.sol

/**
 * @title IExchangeRateProvider Interface
 * @author Cork Team
 * @notice Interface which provides exchange rate
 */
interface IExchangeRateProvider {
    function rate() external view returns (uint256);
    function rate(Id id) external view returns (uint256);
}

// contracts/interfaces/IVaultLiquidation.sol

/// @title Interface for the VaultLiquidation contract
/// @notice This contract is responsible for providing a way for liquidation contracts to request and send back funds
/// IMPORTANT :  the vault must make sure only authorized adddress can call the functions in this interface
interface IVaultLiquidation {
    /// @notice Request funds for liquidation, will transfer the funds directly from the vault to the liquidation contract
    /// @param id The id of the vault
    /// @param amount The amount of funds to request
    /// will revert if there's not enough funds in the vault
    /// IMPORTANT :  the vault must make sure only whitelisted liquidation contract adddress can call this function
    function requestLiquidationFunds(Id id, uint256 amount) external;

    /// @notice Receive funds from liquidation, the vault will do a transferFrom from the liquidation contract
    /// it is important to note that the vault will only transfer RA from the liquidation contract
    /// @param id The id of the vault
    /// @param amount The amount of funds to receive
    function receiveTradeExecuctionResultFunds(Id id, uint256 amount) external;

    /// @notice Use funds from liquidation, the vault will use the received funds to provide liquidity
    /// @param id The id of the vault
    /// IMPORTANT : the vault must make sure only the config contract can call this function, that in turns only can be called by the config contract manager
    function useTradeExecutionResultFunds(Id id) external;

    /// @notice Receive leftover funds from liquidation, the vault will do a transferFrom from the liquidation contract
    /// it is important to note that the vault will only transfer PA from the liquidation contract
    /// @param id The id of the vault
    /// @param amount The amount of funds to receive
    function receiveLeftoverFunds(Id id, uint256 amount) external;

    /// @notice Returns the amount of funds available for liquidation
    /// @param id The id of the vault
    function liquidationFundsAvailable(Id id) external view returns (uint256);

    /// @notice Returns the amount of RA that vault has received through liquidation
    /// @param id The id of the vault
    function tradeExecutionFundsAvailable(Id id) external view returns (uint256);

    /// @notice Event emitted when a liquidation contract requests funds
    event LiquidationFundsRequested(Id indexed id, address indexed who, uint256 amount);

    /// @notice Event emitted when a liquidation contract sends funds
    event TradeExecutionResultFundsReceived(Id indexed id, address indexed who, uint256 amount);

    /// @notice Event emitted when the vault uses funds
    event TradeExecutionResultFundsUsed(Id indexed id, address indexed who, uint256 amount);
}

// contracts/interfaces/Init.sol

/**
 * @title Initialize Interface
 * @author Cork Team
 * @notice Initialize interface for providing Initialization related functions through ModuleCore contract
 */
interface Initialize {
    /**
     * @notice initialize a new pool, this will initialize PSM and Liquidity Vault and deploy new LV token
     * @param pa address of PA token(e.g stETH)
     * @param ra address of RA token(e.g WETH)
     * @param initialArp initial assets ARP. the initial ds price will be derived from this value. must be in 18 decimals(e.g 1% = 1e18)
     * @param expiryInterval expiry interval for DS, this will be used to calculate the next expiry time for DS(block.timestamp + expiryInterval)
     * @param exchangeRateProvider address of IExchangeRateProvider contract
     */
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider
    ) external;

    /**
     * @notice issue a new DS, can only be done after the previous DS has expired(if any). will deploy CT, DS and initialize new AMM and increment ds Id
     * @param id the id of the pair
     */
    function issueNewDs(
        Id id,
        uint256 decayDiscountRateInDays, // protocol-level config
        // won't have effect on first issuance
        uint256 rolloverPeriodInblocks, // protocol-level config
        uint256 ammLiquidationDeadline
    ) external;

    /**
     * @notice update PSM repurchase fee rate for a pair
     * @param id id of the pair
     * @param newRepurchaseFeePercentage new value of repurchase fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external;

    /**
     * @notice update pausing status of PSM Deposits
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     */
    function updatePsmDepositsStatus(Id id, bool isPSMDepositPaused) external;

    /**
     * @notice update pausing status of PSM Withdrawals
     * @param id id of the pair
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     */
    function updatePsmWithdrawalsStatus(Id id, bool isPSMWithdrawalPaused) external;

    /**
     * @notice update pausing status of PSM Repurchases
     * @param id id of the pair
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     */
    function updatePsmRepurchasesStatus(Id id, bool isPSMRepurchasePaused) external;

    /**
     * @notice update pausing status of LV deposits
     * @param id id of the pair
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     */
    function updateLvDepositsStatus(Id id, bool isLVDepositPaused) external;

    /**
     * @notice update pausing status of LV withdrawals
     * @param id id of the pair
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updateLvWithdrawalsStatus(Id id, bool isLVWithdrawalPaused) external;

    /**
     * @notice update PSM base redemption fee percentage
     * @param newPsmBaseRedemptionFeePercentage new value of base redemption fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage) external;

    /**
     * @notice get next expiry time from id
     * @param id id of the pair
     * @return expiry next expiry time in seconds
     */
    function expiry(Id id) external view returns (uint256 expiry);

    /**
     * @notice Get the last DS id issued for a given module, the returned DS doesn't guarantee to be active
     * @param id The current module id
     * @return dsId The current effective DS id
     *
     */
    function lastDsId(Id id) external view returns (uint256 dsId);

    /**
     * @notice returns the address of the underlying RA and PA token
     * @param id the id of PSM
     * @return ra address of the underlying RA token
     * @return pa address of the underlying PA token
     */
    function underlyingAsset(Id id) external view returns (address ra, address pa);

    /**
     * @notice returns the address of CT and DS associated with a certain DS id
     * @param id the id of PSM
     * @param dsId the DS id
     * @return ct address of the CT token
     * @return ds address of the DS token
     */
    function swapAsset(Id id, uint256 dsId) external view returns (address ct, address ds);

    function getId(address pa, address ra, uint256 initialArp, uint256 expiry, address exchangeRateProvider)
        external
        pure
        returns (Id);

    function markets(Id id)
        external
        view
        returns (address pa, address ra, uint256 initialArp, uint256 expiryInterval, address exchangeRateProvider);

    /// @notice Emitted when a new LV and PSM is initialized with a given pair
    /// @param id The PSM id
    /// @param pa The address of the pegged asset
    /// @param ra The address of the redemption asset
    /// @param lv The address of the LV
    /// @param expiry The expiry interval of the DS
    event InitializedModuleCore(
        Id indexed id,
        address indexed pa,
        address indexed ra,
        address lv,
        uint256 expiry,
        uint256 initialArp,
        address exchangeRateProvider
    );

    /// @notice Emitted when a new DS is issued for a given PSM
    /// @param id The PSM id
    /// @param dsId The DS id
    /// @param expiry The expiry of the DS
    /// @param ds The address of the DS token
    /// @param ct The address of the CT token
    /// @param raCtUniPairId The id of the uniswap-v4 pair between RA and CT
    event Issued(
        Id indexed id, uint256 indexed dsId, uint256 indexed expiry, address ds, address ct, bytes32 raCtUniPairId
    );
}

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.1.0) (proxy/utils/UUPSUpgradeable.sol)

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC-1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC-1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC-1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC-1967 compliant implementation pointing to self.
     * See {_onlyProxy}.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC-1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/cryptography/EIP712.sol)

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP-712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP-712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * NOTE: In the upgradeable version of this contract, the cached values will correspond to the address, and the domain
 * separator of the implementation contract. This will cause the {_domainSeparatorV4} function to always rebuild the
 * separator from the immutable values, which is cheaper than accessing a cached version in cold storage.
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable
 */
abstract contract EIP712 is IERC5267 {
    using ShortStrings for *;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;
    ShortString private immutable _version;
    string private _nameFallback;
    string private _versionFallback;

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP-712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        _name = name.toShortStringWithFallback(_nameFallback);
        _version = version.toShortStringWithFallback(_versionFallback);
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
            return _cachedDomainSeparator;
        } else {
            return _buildDomainSeparator();
        }
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }

    /**
     * @dev See {IERC-5267}.
     */
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            _EIP712Name(),
            _EIP712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    /**
     * @dev The name parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _name which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Name() internal view returns (string memory) {
        return _name.toStringWithFallback(_nameFallback);
    }

    /**
     * @dev The version parameter for the EIP712 domain.
     *
     * NOTE: By default this function reads _version which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _EIP712Version() internal view returns (string memory) {
        return _version.toStringWithFallback(_versionFallback);
    }
}

// contracts/interfaces/IDsFlashSwapRouter.sol

/**
 * @title IDsFlashSwapUtility Interface
 * @author Cork Team
 * @notice Utility Interface for flashswap
 */
interface IDsFlashSwapUtility is IErrors_0 {
    /**
     * @notice returns the current price ratio of the pair
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return raPriceRatio ratio of RA
     * @return ctPriceRatio ratio of CT
     */
    function getCurrentPriceRatio(Id id, uint256 dsId)
        external
        view
        returns (uint256 raPriceRatio, uint256 ctPriceRatio);

    /**
     * @notice returns the current reserve of the pair
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return raReserve reserve of RA
     * @return ctReserve reserve of CT
     */
    function getAmmReserve(Id id, uint256 dsId) external view returns (uint256 raReserve, uint256 ctReserve);

    /**
     * @notice returns the current DS reserve that is owned by liquidity vault
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return lvReserve reserve of DS
     */
    function getLvReserve(Id id, uint256 dsId) external view returns (uint256 lvReserve);

    /**
     * @notice returns the current DS reserve that is owned by PSM
     * @param id the id of the pair
     * @param dsId the ds id of the pair
     * @return psmReserve reserve of DS
     */
    function getPsmReserve(Id id, uint256 dsId) external view returns (uint256 psmReserve);

    /**
     * @notice returns the current cumulative HIYA of the pair
     * @param id the id of the pair
     * @return hpaCummulative the current cumulative HIYA
     */
    function getCurrentCumulativeHIYA(Id id) external view returns (uint256 hpaCummulative);

    /**
     * @notice returns the current effective HIYA of the pair
     * @param id the id of the pair
     */
    function getCurrentEffectiveHIYA(Id id) external view returns (uint256 hpa);
}

/**
 * @title IDsFlashSwapCore Interface
 * @author Cork Team
 * @notice IDsFlashSwapCore interface for Flashswap Router contract
 */
interface IDsFlashSwapCore is IDsFlashSwapUtility {
    struct BuyAprroxParams {
        /// @dev the maximum amount of iterations to find the optimal amount of DS to swap, 256 is a good number
        uint256 maxApproxIter;
        /// @dev the maximum amount of iterations to find the optimal RA borrow amount(needed because of the fee, if any)
        uint256 maxFeeIter;
        /// @dev the amount that will be used to subtract borrowed amount to find the optimal amount for borrowing RA
        /// the lower the value, the more accurate the approximation will be but will be more expensive
        /// when in doubt use 0.01 ether or 1e16
        uint256 feeIntervalAdjustment;
        /// @dev the threshold tolerance that's used to find the optimal DS amount
        /// when in doubt use 1e9
        uint256 epsilon;
        /// @dev the threshold tolerance that's used to find the optimal RA amount to borrow, the smaller, the more accurate but more gas intensive it will be
        uint256 feeEpsilon;
        /// @dev the percentage buffer that's used to find the optimal DS amount. needed due to the inherent nature
        /// of the math that has some imprecision, this will be used to subtract the original amount, to offset the precision
        /// when in doubt use 0.01%(1e16) if you're trading above 0.0001 RA. Below that use 1-10%(1e17-1e18)
        uint256 precisionBufferPercentage;
    }

    /// @notice offchain guess for RA AMM borrowing used in swapping RA for DS.
    /// if empty, the router will try and calculate the optimal amount of RA to borrow
    /// using this will greatly reduce the gas cost.
    /// will be the default way to swap RA for DS
    struct OffchainGuess {
        uint256 initialBorrowAmount;
        uint256 afterSoldBorrowAmount;
    }

    struct SwapRaForDsReturn {
        uint256 amountOut;
        uint256 ctRefunded;
        /// @dev the amount of RA that needs to be borrowed on first iteration, this amount + user supplied / 2 of DS
        /// will be sold from the reserve unless it doesn't met the minimum amount, the DS reserve is empty,
        /// or the DS reserve sale is disabled. in such cases, this will be the final amount of RA that's borrowed
        /// and the "afterSoldBorrow" will be 0.
        /// if the swap is fully fullfilled by the rollover sale, both initialBorrow and afterSoldBorrow will be 0
        uint256 initialBorrow;
        /// @dev the final amount of RA that's borrowed after selling DS reserve
        uint256 afterSoldBorrow;
        uint256 fee;
    }

    /**
     * @notice Emitted when DS is swapped for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param user the user that's swapping
     * @param amountIn the amount of DS that's swapped
     * @param amountOut the amount of RA that's received
     */
    event DsSwapped(
        Id indexed reserveId, uint256 indexed dsId, address indexed user, uint256 amountIn, uint256 amountOut
    );

    /**
     * @notice Emitted when RA is swapped for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param user the user that's swapping
     * @param amountIn  the amount of RA that's swapped
     * @param amountOut the amount of DS that's received
     * @param ctRefunded the amount of excess CT that's refunded to the user
     * @param fee the DS fee that's been cut from the user RA. derived from amountIn * feePercentage * reserveSellPercentage
     * @param feePercentage the fee percentage that's taken from user RA that's in theory filled with the reserve DS
     * @param reserveSellPercentage this is the percentage of the amount of DS that's been sold from the router
     */
    event RaSwapped(
        Id indexed reserveId,
        uint256 indexed dsId,
        address indexed user,
        uint256 amountIn,
        uint256 amountOut,
        uint256 ctRefunded,
        uint256 fee,
        uint256 feePercentage,
        uint256 reserveSellPercentage
    );

    /**
     * @notice Emitted when a new issuance is made
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param ds the new DS address
     * @param pair the RA:CT pair id
     */
    event NewIssuance(Id indexed reserveId, uint256 indexed dsId, address ds, bytes32 pair);

    /**
     * @notice Emitted when a reserve is added
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS that's added to the reserve
     */
    event ReserveAdded(Id indexed reserveId, uint256 indexed dsId, uint256 amount);

    /**
     * @notice Emitted when a reserve is emptied
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS that's emptied from the reserve
     */
    event ReserveEmptied(Id indexed reserveId, uint256 indexed dsId, uint256 amount);

    /**
     * @notice Emitted when some DS is swapped via rollover
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param user the user that's swapping
     * @param dsReceived the amount of DS that's received
     * @param raLeft the amount of RA that's left
     */
    event RolloverSold(
        Id indexed reserveId, uint256 indexed dsId, address indexed user, uint256 dsReceived, uint256 raLeft
    );

    /**
     * @notice trigger new issuance logic, can only be called my moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @param ds the address of the new issued DS
     * @param ra the address of RA token
     * @param ct the address of CT token
     */
    function onNewIssuance(Id reserveId, uint256 dsId, address ds, address ra, address ct) external;

    /**
     * @notice set the discount rate rate and rollover for the new issuance
     * @dev needed to avoid stack to deep errors. MUST be called after onNewIssuance and only by moduleCore at new issuance
     * @param reserveId the pair id
     * @param decayDiscountRateInDays the decay discount rate in days
     * @param rolloverPeriodInblocks the rollover period in blocks
     */
    function setDecayDiscountAndRolloverPeriodOnNewIssuance(
        Id reserveId,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) external;

    function updateDsExtraFeePercentage(Id id, uint256 newPercentage) external;

    function updateDsExtraFeeTreasurySplitPercentage(Id id, uint256 newPercentage) external;

    /**
     * @notice add more DS reserve from liquidity vault, can only be called by moduleCore
     * @param id the pair id
     * @param dsId the ds id of the pair
     * @param amount the amount of DS to add
     */
    function addReserveLv(Id id, uint256 dsId, uint256 amount) external;

    function addReservePsm(Id id, uint256 dsId, uint256 amount) external;

    /**
     * @notice empty all DS reserve to liquidity vault, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @return amount the amount of DS that's emptied
     */
    function emptyReserveLv(Id reserveId, uint256 dsId) external returns (uint256 amount);

    function emptyReservePsm(Id reserveId, uint256 dsId) external returns (uint256 amount);

    function emptyReservePartialPsm(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 emptied);

    /**
     * @notice empty some or all DS reserve to liquidity vault, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @notice empty some or all DS reserve to liquidity vault, can only be called by moduleCore
     * @param reserveId the pair id
     * @param dsId the ds id of the pair
     * @param amount the amount of DS to empty
     * @return emptied emptied amount of DS that's emptied
     */
    function emptyReservePartialLv(Id reserveId, uint256 dsId, uint256 amount) external returns (uint256 emptied);

    /**
     * @notice Swaps RA for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @param amountOutMin the minimum amount of DS to receive, will revert if the actual amount is less than this.
     * @param params the buy approximation params(math stuff)
     * @param params the buy approximation params(math stuff)
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        BuyAprroxParams memory params,
        OffchainGuess memory offchainGuess
    ) external returns (SwapRaForDsReturn memory result);

    /**
     * @notice Swaps RA for DS
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of RA to swap
     * @param amountOutMin the minimum amount of DS to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapRaforDs
     * @param rawRaPermitSig the raw permit signature of RA
     * @param deadline the deadline for the swap
     */
    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes memory rawRaPermitSig,
        uint256 deadline,
        BuyAprroxParams memory params,
        OffchainGuess memory offchainGuess
    ) external returns (SwapRaForDsReturn memory result);

    /**
     * @notice Swaps DS for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this.
     * @return amountOut amount of RA that's received
     */
    function swapDsforRa(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        returns (uint256 amountOut);

    /**
     * @notice Swaps DS for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapDsforRa
     * @return amountOut amount of RA that's received
     */
    function swapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Updates the discount rate in D days for the pair
     * @param id the pair id
     * @param discountRateInDays the new discount rate in D days
     */
    function updateDiscountRateInDdays(Id id, uint256 discountRateInDays) external;

    /**
     * @notice update the gradual sale status, if true, will try to sell DS tokens from the reserve gradually
     */
    function updateGradualSaleStatus(Id id, bool status) external;

    function isRolloverSale(Id id) external view returns (bool);

    function updateReserveSellPressurePercentage(Id id, uint256 newPercentage) external;

    event DiscountRateUpdated(Id indexed id, uint256 discountRateInDays);

    event GradualSaleStatusUpdated(Id indexed id, bool disabled);

    event ReserveSellPressurePercentageUpdated(Id indexed id, uint256 newPercentage);

    event DsFeeUpdated(Id indexed id, uint256 newPercentage);

    event DsFeeTreasuryPercentageUpdated(Id indexed id, uint256 newPercentage);
}

// contracts/interfaces/IProtectedUnitFactory.sol

interface IProtectedUnitFactory is IErrors_0 {
    // Event emitted when a new ProtectedUnit contract is deployed
    event ProtectedUnitDeployed(Id indexed pairId, address pa, address ra, address indexed protectedUnitAddress);
}

// contracts/interfaces/IRepurchase.sol

/**
 * @title IRepurchase Interface
 * @author Cork Team
 * @notice IRepurchase interface for supporting Repurchase features through PSMCore
 */
interface IRepurchase is IErrors_0 {
    /**
     * @notice emitted when repurchase is done
     * @param id the id of PSM
     * @param buyer the address of the buyer
     * @param dsId the id of the DS
     * @param raUsed the amount of RA used
     * @param receivedPa the amount of PA received
     * @param receivedDs the amount of DS received
     * @param fee the fee charged
     * @param feePercentage the fee in percentage
     * @param exchangeRates the effective DS exchange rate at the time of repurchase
     */
    event Repurchased(
        Id indexed id,
        address indexed buyer,
        uint256 indexed dsId,
        uint256 raUsed,
        uint256 receivedPa,
        uint256 receivedDs,
        uint256 feePercentage,
        uint256 fee,
        uint256 exchangeRates
    );

    /// @notice Emitted when a repurchaseFee is updated for a given PSM
    /// @param id The PSM id
    /// @param repurchaseFeeRate The new repurchaseFee rate
    event RepurchaseFeeRateUpdated(Id indexed id, uint256 indexed repurchaseFeeRate);

    /**
     * @notice returns the fee percentage for repurchasing(1e18 = 1%)
     * @param id the id of PSM
     */
    function repurchaseFee(Id id) external view returns (uint256);

    /**
     * @notice repurchase using RA
     * @param id the id of PSM
     * @param amount the amount of RA to use
     * @return dsId the id of the DS
     * @return receivedPa the amount of PA received
     * @return receivedDs the amount of DS received
     * @return feePercentage the fee in percentage
     * @return fee the fee charged
     * @return exchangeRates the effective DS exchange rate at the time of repurchase
     */
    function repurchase(Id id, uint256 amount)
        external
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        );

    /**
     * @notice return the amount of available PA and DS to purchase.
     * @param id the id of PSM
     * @return pa the amount of PA available
     * @return ds the amount of DS available
     * @return dsId the id of the DS available
     */
    function availableForRepurchase(Id id) external view returns (uint256 pa, uint256 ds, uint256 dsId);

    /**
     * @notice returns the repurchase rates for a given DS
     * @param id the id of PSM
     */
    function repurchaseRates(Id id) external view returns (uint256 rates);
}

// contracts/interfaces/IPSMcore.sol

/**
 * @title IPSMcore Interface
 * @author Cork Team
 * @notice IPSMcore interface for PSMCore contract
 */
interface IPSMcore is IRepurchase {
    /// @notice Emitted when the exchange rate is updated
    /// @param id The PSM id
    /// @param newRate The new rate
    /// @param previousRate The previous rate
    event RateUpdated(Id indexed id, uint256 newRate, uint256 previousRate);

    /// @notice Emitted when a user deposits assets into a given PSM
    /// @param id The PSM id
    /// @param dsId The DS id
    /// @param depositor The address of the depositor
    /// @param amount The amount of the asset deposited
    /// @param received The amount of swap asset received
    /// @param exchangeRate The exchange rate of DS at the time of deposit
    event PsmDeposited(
        Id indexed id,
        uint256 indexed dsId,
        address indexed depositor,
        uint256 amount,
        uint256 received,
        uint256 exchangeRate
    );

    /// @notice Emitted when a user rolled over their CT
    /// @param id The PSM id
    /// @param currentDsId The current DS id
    /// @param owner The address of the owner
    /// @param prevDsId The previous DS id
    /// @param amountCtRolledOver The amount of CT rolled over
    /// @param dsReceived The amount of DS received, if 0 then the DS is sold to flash swap router, and implies the user opt-in for DS auto-sell
    /// @param ctReceived The amount of CT received
    /// @param paReceived The amount of PA received
    event RolledOver(
        Id indexed id,
        uint256 indexed currentDsId,
        address indexed owner,
        uint256 prevDsId,
        uint256 amountCtRolledOver,
        uint256 dsReceived,
        uint256 ctReceived,
        uint256 paReceived
    );

    /// @notice Emitted when a user claims profit from a rollover
    /// @param id The PSM id
    /// @param dsId The DS id
    /// @param owner The address of the owner
    /// @param amount The amount of the asset claimed
    /// @param profit The amount of profit claimed
    /// @param remainingDs The amount of DS remaining user claimed
    event RolloverProfitClaimed(
        Id indexed id, uint256 indexed dsId, address indexed owner, uint256 amount, uint256 profit, uint256 remainingDs
    );

    /// @notice Emitted when a user redeems a DS for a given PSM
    /// @param id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param paUsed The amount of the PA redeemed
    /// @param dsUsed The amount of DS redeemed
    /// @param raReceived The amount of  asset received
    /// @param dsExchangeRate The exchange rate of DS at the time of redeem
    /// @param feePercentage The fee percentage charged for redemption
    /// @param fee The fee charged for redemption
    event DsRedeemed(
        Id indexed id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 paUsed,
        uint256 dsUsed,
        uint256 raReceived,
        uint256 dsExchangeRate,
        uint256 feePercentage,
        uint256 fee
    );

    /// @notice Emitted when a user redeems a CT for a given PSM
    /// @param id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param amount The amount of the CT redeemed
    /// @param paReceived The amount of the pegged asset received
    /// @param raReceived The amount of the redemption asset received
    event CtRedeemed(
        Id indexed id,
        uint256 indexed dsId,
        address indexed redeemer,
        uint256 amount,
        uint256 paReceived,
        uint256 raReceived
    );

    /// @notice Emitted when a user cancels their DS position by depositing the CT + DS back into the PSM
    /// @param id The PSM id
    /// @param dsId The DS id
    /// @param redeemer The address of the redeemer
    /// @param raAmount The amount of RA received
    /// @param swapAmount The amount of CT + DS swapped
    event Cancelled(
        Id indexed id, uint256 indexed dsId, address indexed redeemer, uint256 raAmount, uint256 swapAmount
    );

    /// @notice Emitted when a Admin updates status of Deposit in the PSM
    /// @param id The PSM id
    /// @param isPSMDepositPaused The new value saying if Deposit allowed in PSM or not
    event PsmDepositsStatusUpdated(Id indexed id, bool isPSMDepositPaused);

    /// @notice Emitted when a Admin updates status of Withdrawal in the PSM
    /// @param id The PSM id
    /// @param isPSMWithdrawalPaused The new value saying if Withdrawal allowed in PSM or not
    event PsmWithdrawalsStatusUpdated(Id indexed id, bool isPSMWithdrawalPaused);

    /// @notice Emitted when a Admin updates status of Repurchase in the PSM
    /// @param id The PSM id
    /// @param isPSMRepurchasePaused The new value saying if Repurchase allowed in PSM or not
    event PsmRepurchasesStatusUpdated(Id indexed id, bool isPSMRepurchasePaused);

    /// @notice Emitted when a Admin updates fee rates for early redemption
    /// @param id The PSM id
    /// @param earlyRedemptionFeeRate The new value of early redemption fee rate
    event EarlyRedemptionFeeRateUpdated(Id indexed id, uint256 earlyRedemptionFeeRate);

    /// @notice Emmitted when psmBaseRedemptionFeePercentage is updated
    /// @param id the PSM id
    /// @param psmBaseRedemptionFeePercentage the new psmBaseRedemptionFeePercentage
    event PsmBaseRedemptionFeePercentageUpdated(Id indexed id, uint256 indexed psmBaseRedemptionFeePercentage);

    /**
     * @notice returns the amount of CT and DS tokens that will be received after deposit
     * @param id the id of PSM
     * @param amount the amount to be deposit
     * @return received the amount of CT/DS received
     * @return exchangeRate effective exchange rate at time of deposit
     */
    function depositPsm(Id id, uint256 amount) external returns (uint256 received, uint256 exchangeRate);

    /**
     * This determines the rate of how much the user will receive for the amount of asset they want to deposit.
     * for example, if the rate is 1.5, then the user will need to deposit 1.5 token to get 1 CT and DS.
     * @param id the id of the PSM
     */
    function exchangeRate(Id id) external view returns (uint256 rates);

    /**
     * @notice redeem RA with DS + PA
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of PA to redeem
     * @param redeemer The address of the redeemer
     * @param rawDsPermitSig The raw signature for DS approval permit
     * @param deadline The deadline for DS approval permit signature
     */
    function redeemRaWithDsPa(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes memory rawDsPermitSig,
        uint256 deadline
    ) external returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed);

    /**
     * @notice redeem RA with DS + PA
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of PA to redeem
     * @return received The amount of RA user will get
     * @return _exchangeRate The effective rate at the time of redemption
     * @return fee The fee charged for redemption
     */
    function redeemRaWithDsPa(Id id, uint256 dsId, uint256 amount)
        external
        returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed);
    /**
     * @notice redeem RA + PA with CT at expiry
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of CT to redeem
     * @param redeemer The address of the redeemer
     * @param rawCtPermitSig The raw signature for CT approval permit
     * @param deadline The deadline for CT approval permit signature
     */
    function redeemWithExpiredCt(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes memory rawCtPermitSig,
        uint256 deadline
    ) external returns (uint256 accruedPa, uint256 accruedRa);

    /**
     * @notice redeem RA + PA with CT at expiry
     * @param id The pair id
     * @param dsId The DS id
     * @param amount The amount of CT to redeem
     */
    function redeemWithExpiredCt(Id id, uint256 dsId, uint256 amount)
        external
        returns (uint256 accruedPa, uint256 accruedRa);

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @param redeemer The address of the redeemer
     * @param rawDsPermitSig raw signature for DS approval permit
     * @param dsDeadline deadline for DS approval permit signature
     * @param rawCtPermitSig raw signature for CT approval permit
     * @param ctDeadline deadline for CT approval permit signature
     * @return ra amount of RA user received
     */
    function returnRaWithCtDs(
        Id id,
        uint256 amount,
        address redeemer,
        bytes memory rawDsPermitSig,
        uint256 dsDeadline,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ra);

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @return ra amount of RA user received
     */
    function returnRaWithCtDs(Id id, uint256 amount) external returns (uint256 ra);

    /**
     * @notice returns amount of value locked in PSM
     * @param id The PSM id
     * @param ra true if you want to get value locked in RA, false if you want to get value locked in PA
     */
    function valueLocked(Id id, bool ra) external view returns (uint256);

    /**
     * @notice returns base redemption fees (1e18 = 1%)
     */
    function baseRedemptionFee(Id id) external view returns (uint256);

    function psmAcceptFlashSwapProfit(Id id, uint256 profit) external;

    function rolloverExpiredCt(
        Id id,
        address owner,
        uint256 amount,
        uint256 prevDsId,
        bytes memory rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived);

    function claimAutoSellProfit(Id id, uint256 prevDsId, uint256 amount)
        external
        returns (uint256 profit, uint256 dsReceived);

    function rolloverExpiredCt(Id id, uint256 amount, uint256 prevDsId)
        external
        returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived);

    function updatePsmAutoSellStatus(Id id, bool status) external;

    function rolloverProfitRemaining(Id id, uint256 dsId) external view returns (uint256);

    function psmAutoSellStatus(Id id) external view returns (bool);
}

// contracts/interfaces/IProtectedUnitLiquidation.sol

/// @title Interface for the Protected Unit contract for liquidation
/// @notice This contract is responsible for providing a way for liquidation contracts to request and send back funds
/// IMPORTANT :  the Protected Unit must make sure only authorized adddress can call the functions in this interface
interface IProtectedUnitLiquidation {
    /// @notice Request funds for liquidation, will transfer the funds directly from the Protected Unit to the liquidation contract
    /// @param amount The amount of funds to request
    /// @param token The token to request, must be either RA or PA in the contract, will fail otherwise
    /// will revert if there's not enough funds in the Protected Unit
    /// IMPORTANT :  the Protected Unit must make sure only whitelisted liquidation contract adddress can call this function
    function requestLiquidationFunds(uint256 amount, address token) external;

    /// @notice Receive funds from liquidation or leftover, the Protected Unit will do a transferFrom from the liquidation contract
    /// it is important to note that the Protected Unit will only transfer RA from the liquidation contract
    /// @param amount The amount of funds to receive
    /// @param token The token to receive, must be either RA or PA in the contract, will fail otherwise
    function receiveFunds(uint256 amount, address token) external;

    /// @notice Use funds from liquidation, the Protected Unit will use the received funds to buy DS
    /// IMPORTANT : the Protected Unit must make sure only the config contract can call this function, that in turns only can be called by the config contract manager
    function useFunds(
        uint256 amount,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external returns (uint256 amountOut);

    /// @notice Returns the amount of funds available for liquidation or trading
    /// @param token The token to check, must be either RA or PA in the contract, will fail otherwise
    /// it is important to note that the protected unit doesn't make any distinction between liquidation funds and funds that are not meant for liquidation
    /// it is the liquidator job to ensure that the funds are used for liquidation is being allocated correctly
    function fundsAvailable(address token) external view returns (uint256);

    /// @notice Event emitted when a liquidation contract requests funds
    event LiquidationFundsRequested(address indexed who, address token, uint256 amount);

    /// @notice Event emitted when a liquidation contract sends funds, can be both left over funds or resulting trade funds
    event FundsReceived(address indexed who, address token, uint256 amount);

    /// @notice Event emitted when the Protected Unit uses funds
    event FundsUsed(address indexed who, uint256 indexed dsId, uint256 raUsed, uint256 dsReceived);
}

// contracts/libraries/TransferHelper.sol

library TransferHelper_0 {
    uint8 internal constant TARGET_DECIMALS = 18;

    function normalizeDecimals(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter)
        internal
        pure
        returns (uint256)
    {
        // If we need to increase the decimals
        if (decimalsBefore > decimalsAfter) {
            // Then we shift right the amount by the number of decimals
            amount = amount / 10 ** (decimalsBefore - decimalsAfter);
            // If we need to decrease the number
        } else if (decimalsBefore < decimalsAfter) {
            // then we shift left by the difference
            amount = amount * 10 ** (decimalsAfter - decimalsBefore);
        }
        // If nothing changed this is a no-op
        return amount;
    }

    function tokenNativeDecimalsToFixed(uint256 amount, IERC20Metadata token) internal view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, decimals, TARGET_DECIMALS);
    }

    function tokenNativeDecimalsToFixed(uint256 amount, address token) internal view returns (uint256) {
        return tokenNativeDecimalsToFixed(amount, IERC20Metadata(token));
    }

    function fixedToTokenNativeDecimals(uint256 amount, IERC20Metadata token) internal view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, TARGET_DECIMALS, decimals);
    }

    function fixedToTokenNativeDecimals(uint256 amount, address token) internal view returns (uint256) {
        return fixedToTokenNativeDecimals(amount, IERC20Metadata(token));
    }

    function transferNormalize(ERC20 token, address _to, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransfer(token, _to, amount);
    }

    function transferNormalize(address token, address _to, uint256 _amount) internal returns (uint256 amount) {
        return transferNormalize(ERC20(token), _to, _amount);
    }

    function transferFromNormalize(ERC20 token, address _from, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransferFrom(token, _from, address(this), amount);
    }

    function transferFromNormalize(address token, address _from, uint256 _amount) internal returns (uint256 amount) {
        return transferFromNormalize(ERC20(token), _from, _amount);
    }

    function burnNormalize(ERC20Burnable token, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        token.burn(amount);
    }

    function burnNormalize(address token, uint256 _amount) internal returns (uint256 amount) {
        return burnNormalize(ERC20Burnable(token), _amount);
    }
}

// lib/Cork-Hook/lib/Depeg-swap/contracts/libraries/TransferHelper.sol

library TransferHelper_1 {
    uint8 constant TARGET_DECIMALS = 18;

    function normalizeDecimals(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter)
        internal
        pure
        returns (uint256)
    {
        // If we need to increase the decimals
        if (decimalsBefore > decimalsAfter) {
            // Then we shift right the amount by the number of decimals
            amount = amount / 10 ** (decimalsBefore - decimalsAfter);
            // If we need to decrease the number
        } else if (decimalsBefore < decimalsAfter) {
            // then we shift left by the difference
            amount = amount * 10 ** (decimalsAfter - decimalsBefore);
        }
        // If nothing changed this is a no-op
        return amount;
    }

    function tokenNativeDecimalsToFixed(uint256 amount, IERC20Metadata token) internal view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, decimals, TARGET_DECIMALS);
    }

    function tokenNativeDecimalsToFixed(uint256 amount, address token) internal view returns (uint256) {
        return tokenNativeDecimalsToFixed(amount, IERC20Metadata(token));
    }

    function fixedToTokenNativeDecimals(uint256 amount, IERC20Metadata token) internal view returns (uint256) {
        uint8 decimals = token.decimals();
        return normalizeDecimals(amount, TARGET_DECIMALS, decimals);
    }

    function fixedToTokenNativeDecimals(uint256 amount, address token) internal view returns (uint256) {
        return fixedToTokenNativeDecimals(amount, IERC20Metadata(token));
    }

    function transferNormalize(ERC20 token, address _to, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransfer(token, _to, amount);
    }

    function transferNormalize(address token, address _to, uint256 _amount) internal returns (uint256 amount) {
        return transferNormalize(ERC20(token), _to, _amount);
    }

    function transferFromNormalize(ERC20 token, address _from, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        SafeERC20.safeTransferFrom(token, _from, address(this), amount);
    }

    function transferFromNormalize(address token, address _from, uint256 _amount) internal returns (uint256 amount) {
        return transferFromNormalize(ERC20(token), _from, _amount);
    }

    function burnNormalize(ERC20Burnable token, uint256 _amount) internal returns (uint256 amount) {
        amount = fixedToTokenNativeDecimals(_amount, token);
        token.burn(amount);
    }

    function burnNormalize(address token, uint256 _amount) internal returns (uint256 amount) {
        return burnNormalize(ERC20Burnable(token), _amount);
    }
}

// contracts/core/Withdrawal.sol

contract Withdrawal is ReentrancyGuardTransient, IWithdrawal {
    using SafeERC20 for IERC20;

    struct WithdrawalInfo {
        uint256 claimableAt;
        address owner;
        IWithdrawalRouter.Tokens[] tokens;
    }

    uint256 public constant DELAY = 3 days;

    address public immutable VAULT;

    mapping(bytes32 => WithdrawalInfo) internal withdrawals;

    // unique nonces to generate withdrawal id
    mapping(address => uint256) public nonces;

    constructor(address _vault) {
        if (_vault == address(0)) {
            revert ZeroAddress();
        }
        VAULT = _vault;
    }

    modifier onlyVault() {
        if (msg.sender != VAULT) {
            revert OnlyVault();
        }
        _;
    }

    modifier onlyOwner(bytes32 withdrawalId) {
        if (withdrawals[withdrawalId].owner != msg.sender) {
            revert NotOwner(withdrawals[withdrawalId].owner, msg.sender);
        }
        _;
    }

    modifier onlyWhenClaimable(bytes32 withdrawalId) {
        if (withdrawals[withdrawalId].claimableAt > block.timestamp) {
            revert NotYetClaimable(withdrawals[withdrawalId].claimableAt, block.timestamp);
        }
        _;
    }

    function getWithdrawal(bytes32 withdrawalId) external view returns (WithdrawalInfo memory) {
        return withdrawals[withdrawalId];
    }

    // the token is expected to be transferred to this contract before calling this function
    function add(address owner, IWithdrawalRouter.Tokens[] calldata tokens)
        external
        onlyVault
        returns (bytes32 withdrawalId)
    {
        uint256 claimableAt = block.timestamp + DELAY;
        WithdrawalInfo memory withdrawal = WithdrawalInfo(claimableAt, owner, tokens);

        // solhint-disable-next-line gas-increment-by-one
        withdrawalId = keccak256(abi.encode(withdrawal, nonces[owner]++));

        // copy withdrawal item 1-1 to memory
        WithdrawalInfo storage withdrawalStorageRef = withdrawals[withdrawalId];

        withdrawalStorageRef.claimableAt = claimableAt;
        withdrawalStorageRef.owner = owner;

        // copy tokens data via a loop since direct memory copy isn't supported
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            withdrawalStorageRef.tokens.push(tokens[i]);
        }

        emit WithdrawalRequested(withdrawalId, owner, claimableAt);
    }

    function claimToSelf(bytes32 withdrawalId)
        external
        nonReentrant
        onlyOwner(withdrawalId)
        onlyWhenClaimable(withdrawalId)
    {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];

        uint256 length = withdrawal.tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            IERC20(withdrawal.tokens[i].token).safeTransfer(withdrawal.owner, withdrawal.tokens[i].amount);
        }

        delete withdrawals[withdrawalId];

        emit WithdrawalClaimed(withdrawalId, msg.sender);
    }

    function claimRouted(bytes32 withdrawalId, address router, bytes calldata routerData)
        external
        nonReentrant
        onlyOwner(withdrawalId)
        onlyWhenClaimable(withdrawalId)
    {
        WithdrawalInfo storage withdrawal = withdrawals[withdrawalId];

        uint256 length = withdrawal.tokens.length;

        //  transfer funds to router
        for (uint256 i = 0; i < length; ++i) {
            IERC20(withdrawal.tokens[i].token).safeTransfer(router, withdrawal.tokens[i].amount);
        }

        IWithdrawalRouter(router).route(address(this), withdrawals[withdrawalId].tokens, routerData);

        delete withdrawals[withdrawalId];

        emit WithdrawalClaimed(withdrawalId, msg.sender);
    }
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/IHooks.sol

/// @notice V4 decides whether to invoke specific hooks by inspecting the least significant bits
/// of the address that the hooks contract is deployed to.
/// For example, a hooks contract deployed to address: 0x0000000000000000000000000000000000002400
/// has the lowest bits '10 0100 0000 0000' which would cause the 'before initialize' and 'after add liquidity' hooks to be used.
/// See the Hooks library for the full spec.
/// @dev Should only be callable by the v4 PoolManager.
interface IHooks {
    /// @notice The hook called before the state of a pool is initialized
    /// @param sender The initial msg.sender for the initialize call
    /// @param key The key for the pool being initialized
    /// @param sqrtPriceX96 The sqrt(price) of the pool as a Q64.96
    /// @return bytes4 The function selector for the hook
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96) external returns (bytes4);

    /// @notice The hook called after the state of a pool is initialized
    /// @param sender The initial msg.sender for the initialize call
    /// @param key The key for the pool being initialized
    /// @param sqrtPriceX96 The sqrt(price) of the pool as a Q64.96
    /// @param tick The current tick after the state of a pool is initialized
    /// @return bytes4 The function selector for the hook
    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        returns (bytes4);

    /// @notice The hook called before liquidity is added
    /// @param sender The initial msg.sender for the add liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for adding liquidity
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4);

    /// @notice The hook called after liquidity is added
    /// @param sender The initial msg.sender for the add liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for adding liquidity
    /// @param delta The caller's balance delta after adding liquidity; the sum of principal delta, fees accrued, and hook delta
    /// @param feesAccrued The fees accrued since the last time fees were collected from this position
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BalanceDelta The hook's delta in token0 and token1. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);

    /// @notice The hook called before liquidity is removed
    /// @param sender The initial msg.sender for the remove liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for removing liquidity
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4);

    /// @notice The hook called after liquidity is removed
    /// @param sender The initial msg.sender for the remove liquidity call
    /// @param key The key for the pool
    /// @param params The parameters for removing liquidity
    /// @param delta The caller's balance delta after removing liquidity; the sum of principal delta, fees accrued, and hook delta
    /// @param feesAccrued The fees accrued since the last time fees were collected from this position
    /// @param hookData Arbitrary data handed into the PoolManager by the liquidity provider to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BalanceDelta The hook's delta in token0 and token1. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);

    /// @notice The hook called before a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param key The key for the pool
    /// @param params The parameters for the swap
    /// @param hookData Arbitrary data handed into the PoolManager by the swapper to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BeforeSwapDelta The hook's delta in specified and unspecified currencies. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    /// @return uint24 Optionally override the lp fee, only used if three conditions are met: 1. the Pool has a dynamic fee, 2. the value's 2nd highest bit is set (23rd bit, 0x400000), and 3. the value is less than or equal to the maximum fee (1 million)
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24);

    /// @notice The hook called after a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param key The key for the pool
    /// @param params The parameters for the swap
    /// @param delta The amount owed to the caller (positive) or owed to the pool (negative)
    /// @param hookData Arbitrary data handed into the PoolManager by the swapper to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return int128 The hook's delta in unspecified currency. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128);

    /// @notice The hook called before donate
    /// @param sender The initial msg.sender for the donate call
    /// @param key The key for the pool
    /// @param amount0 The amount of token0 being donated
    /// @param amount1 The amount of token1 being donated
    /// @param hookData Arbitrary data handed into the PoolManager by the donor to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4);

    /// @notice The hook called after donate
    /// @param sender The initial msg.sender for the donate call
    /// @param key The key for the pool
    /// @param amount0 The amount of token0 being donated
    /// @param amount1 The amount of token1 being donated
    /// @param hookData Arbitrary data handed into the PoolManager by the donor to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4);
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol

/// @notice Interface for the PoolManager
interface IPoolManager is IProtocolFees, IERC6909Claims, IExtsload, IExttload {
    /// @notice Thrown when a currency is not netted out after the contract is unlocked
    error CurrencyNotSettled();

    /// @notice Thrown when trying to interact with a non-initialized pool
    error PoolNotInitialized();

    /// @notice Thrown when unlock is called, but the contract is already unlocked
    error AlreadyUnlocked();

    /// @notice Thrown when a function is called that requires the contract to be unlocked, but it is not
    error ManagerLocked();

    /// @notice Pools are limited to type(int16).max tickSpacing in #initialize, to prevent overflow
    error TickSpacingTooLarge(int24 tickSpacing);

    /// @notice Pools must have a positive non-zero tickSpacing passed to #initialize
    error TickSpacingTooSmall(int24 tickSpacing);

    /// @notice PoolKey must have currencies where address(currency0) < address(currency1)
    error CurrenciesOutOfOrderOrEqual(address currency0, address currency1);

    /// @notice Thrown when a call to updateDynamicLPFee is made by an address that is not the hook,
    /// or on a pool that does not have a dynamic swap fee.
    error UnauthorizedDynamicLPFeeUpdate();

    /// @notice Thrown when trying to swap amount of 0
    error SwapAmountCannotBeZero();

    ///@notice Thrown when native currency is passed to a non native settlement
    error NonzeroNativeValue();

    /// @notice Thrown when `clear` is called with an amount that is not exactly equal to the open currency delta.
    error MustClearExactPositiveDelta();

    /// @notice Emitted when a new pool is initialized
    /// @param id The abi encoded hash of the pool key struct for the new pool
    /// @param currency0 The first currency of the pool by address sort order
    /// @param currency1 The second currency of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    /// @param hooks The hooks contract address for the pool, or address(0) if none
    /// @param sqrtPriceX96 The price of the pool on initialization
    /// @param tick The initial tick of the pool corresponding to the initialized price
    event Initialize(
        PoolId indexed id,
        Currency indexed currency0,
        Currency indexed currency1,
        uint24 fee,
        int24 tickSpacing,
        IHooks hooks,
        uint160 sqrtPriceX96,
        int24 tick
    );

    /// @notice Emitted when a liquidity position is modified
    /// @param id The abi encoded hash of the pool key struct for the pool that was modified
    /// @param sender The address that modified the pool
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param liquidityDelta The amount of liquidity that was added or removed
    /// @param salt The extra data to make positions unique
    event ModifyLiquidity(
        PoolId indexed id, address indexed sender, int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes32 salt
    );

    /// @notice Emitted for swaps between currency0 and currency1
    /// @param id The abi encoded hash of the pool key struct for the pool that was modified
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param amount0 The delta of the currency0 balance of the pool
    /// @param amount1 The delta of the currency1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of the price of the pool after the swap
    /// @param fee The swap fee in hundredths of a bip
    event Swap(
        PoolId indexed id,
        address indexed sender,
        int128 amount0,
        int128 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick,
        uint24 fee
    );

    /// @notice Emitted for donations
    /// @param id The abi encoded hash of the pool key struct for the pool that was donated to
    /// @param sender The address that initiated the donate call
    /// @param amount0 The amount donated in currency0
    /// @param amount1 The amount donated in currency1
    event Donate(PoolId indexed id, address indexed sender, uint256 amount0, uint256 amount1);

    /// @notice All interactions on the contract that account deltas require unlocking. A caller that calls `unlock` must implement
    /// `IUnlockCallback(msg.sender).unlockCallback(data)`, where they interact with the remaining functions on this contract.
    /// @dev The only functions callable without an unlocking are `initialize` and `updateDynamicLPFee`
    /// @param data Any data to pass to the callback, via `IUnlockCallback(msg.sender).unlockCallback(data)`
    /// @return The data returned by the call to `IUnlockCallback(msg.sender).unlockCallback(data)`
    function unlock(bytes calldata data) external returns (bytes memory);

    /// @notice Initialize the state for a given pool ID
    /// @dev A swap fee totaling MAX_SWAP_FEE (100%) makes exact output swaps impossible since the input is entirely consumed by the fee
    /// @param key The pool key for the pool to initialize
    /// @param sqrtPriceX96 The initial square root price
    /// @return tick The initial tick of the pool
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick);

    struct ModifyLiquidityParams {
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // how to modify the liquidity
        int256 liquidityDelta;
        // a value to set if you want unique liquidity positions at the same range
        bytes32 salt;
    }

    /// @notice Modify the liquidity for the given pool
    /// @dev Poke by calling with a zero liquidityDelta
    /// @param key The pool to modify liquidity in
    /// @param params The parameters for modifying the liquidity
    /// @param hookData The data to pass through to the add/removeLiquidity hooks
    /// @return callerDelta The balance delta of the caller of modifyLiquidity. This is the total of both principal, fee deltas, and hook deltas if applicable
    /// @return feesAccrued The balance delta of the fees generated in the liquidity range. Returned for informational purposes
    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta callerDelta, BalanceDelta feesAccrued);

    struct SwapParams {
        /// Whether to swap token0 for token1 or vice versa
        bool zeroForOne;
        /// The desired input amount if negative (exactIn), or the desired output amount if positive (exactOut)
        int256 amountSpecified;
        /// The sqrt price at which, if reached, the swap will stop executing
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swap against the given pool
    /// @param key The pool to swap in
    /// @param params The parameters for swapping
    /// @param hookData The data to pass through to the swap hooks
    /// @return swapDelta The balance delta of the address swapping
    /// @dev Swapping on low liquidity pools may cause unexpected swap amounts when liquidity available is less than amountSpecified.
    /// Additionally note that if interacting with hooks that have the BEFORE_SWAP_RETURNS_DELTA_FLAG or AFTER_SWAP_RETURNS_DELTA_FLAG
    /// the hook may alter the swap input/output. Integrators should perform checks on the returned swapDelta.
    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData)
        external
        returns (BalanceDelta swapDelta);

    /// @notice Donate the given currency amounts to the in-range liquidity providers of a pool
    /// @dev Calls to donate can be frontrun adding just-in-time liquidity, with the aim of receiving a portion donated funds.
    /// Donors should keep this in mind when designing donation mechanisms.
    /// @dev This function donates to in-range LPs at slot0.tick. In certain edge-cases of the swap algorithm, the `sqrtPrice` of
    /// a pool can be at the lower boundary of tick `n`, but the `slot0.tick` of the pool is already `n - 1`. In this case a call to
    /// `donate` would donate to tick `n - 1` (slot0.tick) not tick `n` (getTickAtSqrtPrice(slot0.sqrtPriceX96)).
    /// Read the comments in `Pool.swap()` for more information about this.
    /// @param key The key of the pool to donate to
    /// @param amount0 The amount of currency0 to donate
    /// @param amount1 The amount of currency1 to donate
    /// @param hookData The data to pass through to the donate hooks
    /// @return BalanceDelta The delta of the caller after the donate
    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        returns (BalanceDelta);

    /// @notice Writes the current ERC20 balance of the specified currency to transient storage
    /// This is used to checkpoint balances for the manager and derive deltas for the caller.
    /// @dev This MUST be called before any ERC20 tokens are sent into the contract, but can be skipped
    /// for native tokens because the amount to settle is determined by the sent value.
    /// However, if an ERC20 token has been synced and not settled, and the caller instead wants to settle
    /// native funds, this function can be called with the native currency to then be able to settle the native currency
    function sync(Currency currency) external;

    /// @notice Called by the user to net out some value owed to the user
    /// @dev Will revert if the requested amount is not available, consider using `mint` instead
    /// @dev Can also be used as a mechanism for free flash loans
    /// @param currency The currency to withdraw from the pool manager
    /// @param to The address to withdraw to
    /// @param amount The amount of currency to withdraw
    function take(Currency currency, address to, uint256 amount) external;

    /// @notice Called by the user to pay what is owed
    /// @return paid The amount of currency settled
    function settle() external payable returns (uint256 paid);

    /// @notice Called by the user to pay on behalf of another address
    /// @param recipient The address to credit for the payment
    /// @return paid The amount of currency settled
    function settleFor(address recipient) external payable returns (uint256 paid);

    /// @notice WARNING - Any currency that is cleared, will be non-retrievable, and locked in the contract permanently.
    /// A call to clear will zero out a positive balance WITHOUT a corresponding transfer.
    /// @dev This could be used to clear a balance that is considered dust.
    /// Additionally, the amount must be the exact positive balance. This is to enforce that the caller is aware of the amount being cleared.
    function clear(Currency currency, uint256 amount) external;

    /// @notice Called by the user to move value into ERC6909 balance
    /// @param to The address to mint the tokens to
    /// @param id The currency address to mint to ERC6909s, as a uint256
    /// @param amount The amount of currency to mint
    /// @dev The id is converted to a uint160 to correspond to a currency address
    /// If the upper 12 bytes are not 0, they will be 0-ed out
    function mint(address to, uint256 id, uint256 amount) external;

    /// @notice Called by the user to move value from ERC6909 balance
    /// @param from The address to burn the tokens from
    /// @param id The currency address to burn from ERC6909s, as a uint256
    /// @param amount The amount of currency to burn
    /// @dev The id is converted to a uint160 to correspond to a currency address
    /// If the upper 12 bytes are not 0, they will be 0-ed out
    function burn(address from, uint256 id, uint256 amount) external;

    /// @notice Updates the pools lp fees for the a pool that has enabled dynamic lp fees.
    /// @dev A swap fee totaling MAX_SWAP_FEE (100%) makes exact output swaps impossible since the input is entirely consumed by the fee
    /// @param key The key of the pool to update dynamic LP fees for
    /// @param newDynamicLPFee The new dynamic pool LP fee
    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external;
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/interfaces/IProtocolFees.sol

/// @notice Interface for all protocol-fee related functions in the pool manager
interface IProtocolFees {
    /// @notice Thrown when protocol fee is set too high
    error ProtocolFeeTooLarge(uint24 fee);

    /// @notice Thrown when collectProtocolFees or setProtocolFee is not called by the controller.
    error InvalidCaller();

    /// @notice Thrown when collectProtocolFees is attempted on a token that is synced.
    error ProtocolFeeCurrencySynced();

    /// @notice Emitted when the protocol fee controller address is updated in setProtocolFeeController.
    event ProtocolFeeControllerUpdated(address indexed protocolFeeController);

    /// @notice Emitted when the protocol fee is updated for a pool.
    event ProtocolFeeUpdated(PoolId indexed id, uint24 protocolFee);

    /// @notice Given a currency address, returns the protocol fees accrued in that currency
    /// @param currency The currency to check
    /// @return amount The amount of protocol fees accrued in the currency
    function protocolFeesAccrued(Currency currency) external view returns (uint256 amount);

    /// @notice Sets the protocol fee for the given pool
    /// @param key The key of the pool to set a protocol fee for
    /// @param newProtocolFee The fee to set
    function setProtocolFee(PoolKey memory key, uint24 newProtocolFee) external;

    /// @notice Sets the protocol fee controller
    /// @param controller The new protocol fee controller
    function setProtocolFeeController(address controller) external;

    /// @notice Collects the protocol fees for a given recipient and currency, returning the amount collected
    /// @dev This will revert if the contract is unlocked
    /// @param recipient The address to receive the protocol fees
    /// @param currency The currency to withdraw
    /// @param amount The amount of currency to withdraw
    /// @return amountCollected The amount of currency successfully withdrawn
    function collectProtocolFees(address recipient, Currency currency, uint256 amount)
        external
        returns (uint256 amountCollected);

    /// @notice Returns the current protocol fee controller address
    /// @return address The current protocol fee controller address
    function protocolFeeController() external view returns (address);
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/types/PoolId.sol

type PoolId is bytes32;

/// @notice Library for computing the ID of a pool
library PoolIdLibrary {
    /// @notice Returns value equal to keccak256(abi.encode(poolKey))
    function toId(PoolKey memory poolKey) internal pure returns (PoolId poolId) {
        assembly ("memory-safe") {
            // 0xa0 represents the total size of the poolKey struct (5 slots of 32 bytes)
            poolId := keccak256(poolKey, 0xa0)
        }
    }
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol

using PoolIdLibrary for PoolKey global;

/// @notice Returns the key for identifying a pool
struct PoolKey {
    /// @notice The lower currency of the pool, sorted numerically
    Currency currency0;
    /// @notice The higher currency of the pool, sorted numerically
    Currency currency1;
    /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
    uint24 fee;
    /// @notice Ticks that involve positions must be a multiple of tick spacing
    int24 tickSpacing;
    /// @notice The hooks of the pool
    IHooks hooks;
}

// lib/Cork-Hook/src/lib/Calls.sol

enum Action {
    AddLiquidity,
    RemoveLiquidity,
    Swap
}

struct AddLiquidtyParams {
    address token0;
    uint256 amount0;
    address token1;
    uint256 amount1;
    address sender;
}

struct RemoveLiquidtyParams {
    address token0;
    address token1;
    uint256 liquidityAmount;
    address sender;
}

struct SwapParams {
    // for flashswap
    bytes swapData;
    IPoolManager.SwapParams params;
    PoolKey poolKey;
    address sender;
    uint256 amountOut;
    uint256 amountIn;
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol

/// @notice Library used to interact with PoolManager.sol to settle any open deltas.
/// To settle a positive delta (a credit to the user), a user may take or mint.
/// To settle a negative delta (a debt on the user), a user make transfer or burn to pay off a debt.
/// @dev Note that sync() is called before any erc-20 transfer in `settle`.
library CurrencySettler {
    /// @notice Settle (pay) a currency to the PoolManager
    /// @param currency Currency to settle
    /// @param manager IPoolManager to settle to
    /// @param payer Address of the payer, the token sender
    /// @param amount Amount to send
    /// @param burn If true, burn the ERC-6909 token, otherwise ERC20-transfer to the PoolManager
    function settle(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) internal {
        // for native currencies or burns, calling sync is not required
        // short circuit for ERC-6909 burns to support ERC-6909-wrapped native tokens
        if (burn) {
            manager.burn(payer, currency.toId(), amount);
        } else if (currency.isAddressZero()) {
            manager.settle{value: amount}();
        } else {
            manager.sync(currency);
            if (payer != address(this)) {
                IERC20Minimal(Currency.unwrap(currency)).transferFrom(payer, address(manager), amount);
            } else {
                IERC20Minimal(Currency.unwrap(currency)).transfer(address(manager), amount);
            }
            manager.settle();
        }
    }

    /// @notice Take (receive) a currency from the PoolManager
    /// @param currency Currency to take
    /// @param manager IPoolManager to take from
    /// @param recipient Address of the recipient, the token receiver
    /// @param amount Amount to receive
    /// @param claims If true, mint the ERC-6909 token, otherwise ERC20-transfer from the PoolManager to recipient
    function take(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) internal {
        claims ? manager.mint(recipient, currency.toId(), amount) : manager.take(currency, recipient, amount);
    }
}

// lib/Cork-Hook/lib/v4-periphery/src/interfaces/IImmutableState.sol

/// @title IImmutableState
/// @notice Interface for the ImmutableState contract
interface IImmutableState {
    /// @notice The Uniswap v4 PoolManager contract
    function poolManager() external view returns (IPoolManager);
}

// lib/Cork-Hook/lib/v4-periphery/src/base/ImmutableState.sol

/// @title Immutable State
/// @notice A collection of immutable state variables, commonly used across multiple contracts
contract ImmutableState is IImmutableState {
    /// @inheritdoc IImmutableState
    IPoolManager public immutable poolManager;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }
}

// lib/Cork-Hook/lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol

/// @notice V4 decides whether to invoke specific hooks by inspecting the least significant bits
/// of the address that the hooks contract is deployed to.
/// For example, a hooks contract deployed to address: 0x0000000000000000000000000000000000002400
/// has the lowest bits '10 0100 0000 0000' which would cause the 'before initialize' and 'after add liquidity' hooks to be used.
library Hooks {
    using LPFeeLibrary for uint24;
    using Hooks for IHooks;
    using SafeCast_1 for int256;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using ParseBytes for bytes;
    using CustomRevert for bytes4;

    uint160 internal constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

    uint160 internal constant BEFORE_INITIALIZE_FLAG = 1 << 13;
    uint160 internal constant AFTER_INITIALIZE_FLAG = 1 << 12;

    uint160 internal constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 11;
    uint160 internal constant AFTER_ADD_LIQUIDITY_FLAG = 1 << 10;

    uint160 internal constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 9;
    uint160 internal constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 8;

    uint160 internal constant BEFORE_SWAP_FLAG = 1 << 7;
    uint160 internal constant AFTER_SWAP_FLAG = 1 << 6;

    uint160 internal constant BEFORE_DONATE_FLAG = 1 << 5;
    uint160 internal constant AFTER_DONATE_FLAG = 1 << 4;

    uint160 internal constant BEFORE_SWAP_RETURNS_DELTA_FLAG = 1 << 3;
    uint160 internal constant AFTER_SWAP_RETURNS_DELTA_FLAG = 1 << 2;
    uint160 internal constant AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 1;
    uint160 internal constant AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 0;

    struct Permissions {
        bool beforeInitialize;
        bool afterInitialize;
        bool beforeAddLiquidity;
        bool afterAddLiquidity;
        bool beforeRemoveLiquidity;
        bool afterRemoveLiquidity;
        bool beforeSwap;
        bool afterSwap;
        bool beforeDonate;
        bool afterDonate;
        bool beforeSwapReturnDelta;
        bool afterSwapReturnDelta;
        bool afterAddLiquidityReturnDelta;
        bool afterRemoveLiquidityReturnDelta;
    }

    /// @notice Thrown if the address will not lead to the specified hook calls being called
    /// @param hooks The address of the hooks contract
    error HookAddressNotValid(address hooks);

    /// @notice Hook did not return its selector
    error InvalidHookResponse();

    /// @notice Additional context for ERC-7751 wrapped error when a hook call fails
    error HookCallFailed();

    /// @notice The hook's delta changed the swap from exactIn to exactOut or vice versa
    error HookDeltaExceedsSwapAmount();

    /// @notice Utility function intended to be used in hook constructors to ensure
    /// the deployed hooks address causes the intended hooks to be called
    /// @param permissions The hooks that are intended to be called
    /// @dev permissions param is memory as the function will be called from constructors
    function validateHookPermissions(IHooks self, Permissions memory permissions) internal pure {
        if (
            permissions.beforeInitialize != self.hasPermission(BEFORE_INITIALIZE_FLAG)
                || permissions.afterInitialize != self.hasPermission(AFTER_INITIALIZE_FLAG)
                || permissions.beforeAddLiquidity != self.hasPermission(BEFORE_ADD_LIQUIDITY_FLAG)
                || permissions.afterAddLiquidity != self.hasPermission(AFTER_ADD_LIQUIDITY_FLAG)
                || permissions.beforeRemoveLiquidity != self.hasPermission(BEFORE_REMOVE_LIQUIDITY_FLAG)
                || permissions.afterRemoveLiquidity != self.hasPermission(AFTER_REMOVE_LIQUIDITY_FLAG)
                || permissions.beforeSwap != self.hasPermission(BEFORE_SWAP_FLAG)
                || permissions.afterSwap != self.hasPermission(AFTER_SWAP_FLAG)
                || permissions.beforeDonate != self.hasPermission(BEFORE_DONATE_FLAG)
                || permissions.afterDonate != self.hasPermission(AFTER_DONATE_FLAG)
                || permissions.beforeSwapReturnDelta != self.hasPermission(BEFORE_SWAP_RETURNS_DELTA_FLAG)
                || permissions.afterSwapReturnDelta != self.hasPermission(AFTER_SWAP_RETURNS_DELTA_FLAG)
                || permissions.afterAddLiquidityReturnDelta != self.hasPermission(AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG)
                || permissions.afterRemoveLiquidityReturnDelta
                    != self.hasPermission(AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)
        ) {
            HookAddressNotValid.selector.revertWith(address(self));
        }
    }

    /// @notice Ensures that the hook address includes at least one hook flag or dynamic fees, or is the 0 address
    /// @param self The hook to verify
    /// @param fee The fee of the pool the hook is used with
    /// @return bool True if the hook address is valid
    function isValidHookAddress(IHooks self, uint24 fee) internal pure returns (bool) {
        // The hook can only have a flag to return a hook delta on an action if it also has the corresponding action flag
        if (!self.hasPermission(BEFORE_SWAP_FLAG) && self.hasPermission(BEFORE_SWAP_RETURNS_DELTA_FLAG)) return false;
        if (!self.hasPermission(AFTER_SWAP_FLAG) && self.hasPermission(AFTER_SWAP_RETURNS_DELTA_FLAG)) return false;
        if (!self.hasPermission(AFTER_ADD_LIQUIDITY_FLAG) && self.hasPermission(AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG))
        {
            return false;
        }
        if (
            !self.hasPermission(AFTER_REMOVE_LIQUIDITY_FLAG)
                && self.hasPermission(AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)
        ) return false;

        // If there is no hook contract set, then fee cannot be dynamic
        // If a hook contract is set, it must have at least 1 flag set, or have a dynamic fee
        return address(self) == address(0)
            ? !fee.isDynamicFee()
            : (uint160(address(self)) & ALL_HOOK_MASK > 0 || fee.isDynamicFee());
    }

    /// @notice performs a hook call using the given calldata on the given hook that doesn't return a delta
    /// @return result The complete data returned by the hook
    function callHook(IHooks self, bytes memory data) internal returns (bytes memory result) {
        bool success;
        assembly ("memory-safe") {
            success := call(gas(), self, 0, add(data, 0x20), mload(data), 0, 0)
        }
        // Revert with FailedHookCall, containing any error message to bubble up
        if (!success) CustomRevert.bubbleUpAndRevertWith(address(self), bytes4(data), HookCallFailed.selector);

        // The call was successful, fetch the returned data
        assembly ("memory-safe") {
            // allocate result byte array from the free memory pointer
            result := mload(0x40)
            // store new free memory pointer at the end of the array padded to 32 bytes
            mstore(0x40, add(result, and(add(returndatasize(), 0x3f), not(0x1f))))
            // store length in memory
            mstore(result, returndatasize())
            // copy return data to result
            returndatacopy(add(result, 0x20), 0, returndatasize())
        }

        // Length must be at least 32 to contain the selector. Check expected selector and returned selector match.
        if (result.length < 32 || result.parseSelector() != data.parseSelector()) {
            InvalidHookResponse.selector.revertWith();
        }
    }

    /// @notice performs a hook call using the given calldata on the given hook
    /// @return int256 The delta returned by the hook
    function callHookWithReturnDelta(IHooks self, bytes memory data, bool parseReturn) internal returns (int256) {
        bytes memory result = callHook(self, data);

        // If this hook wasn't meant to return something, default to 0 delta
        if (!parseReturn) return 0;

        // A length of 64 bytes is required to return a bytes4, and a 32 byte delta
        if (result.length != 64) InvalidHookResponse.selector.revertWith();
        return result.parseReturnDelta();
    }

    /// @notice modifier to prevent calling a hook if they initiated the action
    modifier noSelfCall(IHooks self) {
        if (msg.sender != address(self)) {
            _;
        }
    }

    /// @notice calls beforeInitialize hook if permissioned and validates return value
    function beforeInitialize(IHooks self, PoolKey memory key, uint160 sqrtPriceX96) internal noSelfCall(self) {
        if (self.hasPermission(BEFORE_INITIALIZE_FLAG)) {
            self.callHook(abi.encodeCall(IHooks.beforeInitialize, (msg.sender, key, sqrtPriceX96)));
        }
    }

    /// @notice calls afterInitialize hook if permissioned and validates return value
    function afterInitialize(IHooks self, PoolKey memory key, uint160 sqrtPriceX96, int24 tick)
        internal
        noSelfCall(self)
    {
        if (self.hasPermission(AFTER_INITIALIZE_FLAG)) {
            self.callHook(abi.encodeCall(IHooks.afterInitialize, (msg.sender, key, sqrtPriceX96, tick)));
        }
    }

    /// @notice calls beforeModifyLiquidity hook if permissioned and validates return value
    function beforeModifyLiquidity(
        IHooks self,
        PoolKey memory key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes calldata hookData
    ) internal noSelfCall(self) {
        if (params.liquidityDelta > 0 && self.hasPermission(BEFORE_ADD_LIQUIDITY_FLAG)) {
            self.callHook(abi.encodeCall(IHooks.beforeAddLiquidity, (msg.sender, key, params, hookData)));
        } else if (params.liquidityDelta <= 0 && self.hasPermission(BEFORE_REMOVE_LIQUIDITY_FLAG)) {
            self.callHook(abi.encodeCall(IHooks.beforeRemoveLiquidity, (msg.sender, key, params, hookData)));
        }
    }

    /// @notice calls afterModifyLiquidity hook if permissioned and validates return value
    function afterModifyLiquidity(
        IHooks self,
        PoolKey memory key,
        IPoolManager.ModifyLiquidityParams memory params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) internal returns (BalanceDelta callerDelta, BalanceDelta hookDelta) {
        if (msg.sender == address(self)) return (delta, BalanceDeltaLibrary.ZERO_DELTA);

        callerDelta = delta;
        if (params.liquidityDelta > 0) {
            if (self.hasPermission(AFTER_ADD_LIQUIDITY_FLAG)) {
                hookDelta = BalanceDelta.wrap(
                    self.callHookWithReturnDelta(
                        abi.encodeCall(
                            IHooks.afterAddLiquidity, (msg.sender, key, params, delta, feesAccrued, hookData)
                        ),
                        self.hasPermission(AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG)
                    )
                );
                callerDelta = callerDelta - hookDelta;
            }
        } else {
            if (self.hasPermission(AFTER_REMOVE_LIQUIDITY_FLAG)) {
                hookDelta = BalanceDelta.wrap(
                    self.callHookWithReturnDelta(
                        abi.encodeCall(
                            IHooks.afterRemoveLiquidity, (msg.sender, key, params, delta, feesAccrued, hookData)
                        ),
                        self.hasPermission(AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG)
                    )
                );
                callerDelta = callerDelta - hookDelta;
            }
        }
    }

    /// @notice calls beforeSwap hook if permissioned and validates return value
    function beforeSwap(IHooks self, PoolKey memory key, IPoolManager.SwapParams memory params, bytes calldata hookData)
        internal
        returns (int256 amountToSwap, BeforeSwapDelta hookReturn, uint24 lpFeeOverride)
    {
        amountToSwap = params.amountSpecified;
        if (msg.sender == address(self)) return (amountToSwap, BeforeSwapDeltaLibrary.ZERO_DELTA, lpFeeOverride);

        if (self.hasPermission(BEFORE_SWAP_FLAG)) {
            bytes memory result = callHook(self, abi.encodeCall(IHooks.beforeSwap, (msg.sender, key, params, hookData)));

            // A length of 96 bytes is required to return a bytes4, a 32 byte delta, and an LP fee
            if (result.length != 96) InvalidHookResponse.selector.revertWith();

            // dynamic fee pools that want to override the cache fee, return a valid fee with the override flag. If override flag
            // is set but an invalid fee is returned, the transaction will revert. Otherwise the current LP fee will be used
            if (key.fee.isDynamicFee()) lpFeeOverride = result.parseFee();

            // skip this logic for the case where the hook return is 0
            if (self.hasPermission(BEFORE_SWAP_RETURNS_DELTA_FLAG)) {
                hookReturn = BeforeSwapDelta.wrap(result.parseReturnDelta());

                // any return in unspecified is passed to the afterSwap hook for handling
                int128 hookDeltaSpecified = hookReturn.getSpecifiedDelta();

                // Update the swap amount according to the hook's return, and check that the swap type doesn't change (exact input/output)
                if (hookDeltaSpecified != 0) {
                    bool exactInput = amountToSwap < 0;
                    amountToSwap += hookDeltaSpecified;
                    if (exactInput ? amountToSwap > 0 : amountToSwap < 0) {
                        HookDeltaExceedsSwapAmount.selector.revertWith();
                    }
                }
            }
        }
    }

    /// @notice calls afterSwap hook if permissioned and validates return value
    function afterSwap(
        IHooks self,
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        BalanceDelta swapDelta,
        bytes calldata hookData,
        BeforeSwapDelta beforeSwapHookReturn
    ) internal returns (BalanceDelta, BalanceDelta) {
        if (msg.sender == address(self)) return (swapDelta, BalanceDeltaLibrary.ZERO_DELTA);

        int128 hookDeltaSpecified = beforeSwapHookReturn.getSpecifiedDelta();
        int128 hookDeltaUnspecified = beforeSwapHookReturn.getUnspecifiedDelta();

        if (self.hasPermission(AFTER_SWAP_FLAG)) {
            hookDeltaUnspecified += self.callHookWithReturnDelta(
                abi.encodeCall(IHooks.afterSwap, (msg.sender, key, params, swapDelta, hookData)),
                self.hasPermission(AFTER_SWAP_RETURNS_DELTA_FLAG)
            ).toInt128();
        }

        BalanceDelta hookDelta;
        if (hookDeltaUnspecified != 0 || hookDeltaSpecified != 0) {
            hookDelta = (params.amountSpecified < 0 == params.zeroForOne)
                ? toBalanceDelta(hookDeltaSpecified, hookDeltaUnspecified)
                : toBalanceDelta(hookDeltaUnspecified, hookDeltaSpecified);

            // the caller has to pay for (or receive) the hook's delta
            swapDelta = swapDelta - hookDelta;
        }
        return (swapDelta, hookDelta);
    }

    /// @notice calls beforeDonate hook if permissioned and validates return value
    function beforeDonate(IHooks self, PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        internal
        noSelfCall(self)
    {
        if (self.hasPermission(BEFORE_DONATE_FLAG)) {
            self.callHook(abi.encodeCall(IHooks.beforeDonate, (msg.sender, key, amount0, amount1, hookData)));
        }
    }

    /// @notice calls afterDonate hook if permissioned and validates return value
    function afterDonate(IHooks self, PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        internal
        noSelfCall(self)
    {
        if (self.hasPermission(AFTER_DONATE_FLAG)) {
            self.callHook(abi.encodeCall(IHooks.afterDonate, (msg.sender, key, amount0, amount1, hookData)));
        }
    }

    function hasPermission(IHooks self, uint160 flag) internal pure returns (bool) {
        return uint160(address(self)) & flag != 0;
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PermitUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/ERC20Permit.sol)

/**
 * @dev Implementation of the ERC-20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC-20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
abstract contract ERC20PermitUpgradeable is Initializable, ERC20Upgradeable, IERC20Permit, EIP712Upgradeable, NoncesUpgradeable {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC-20 token name.
     */
    function __ERC20Permit_init(string memory name) internal onlyInitializing {
        __EIP712_init_unchained(name, "1");
    }

    function __ERC20Permit_init_unchained(string memory) internal onlyInitializing {}

    /**
     * @inheritdoc IERC20Permit
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    function nonces(address owner) public view virtual override(IERC20Permit, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}

// lib/Cork-Hook/lib/v4-periphery/src/base/SafeCallback.sol

/// @title Safe Callback
/// @notice A contract that only allows the Uniswap v4 PoolManager to call the unlockCallback
abstract contract SafeCallback is ImmutableState, IUnlockCallback {
    /// @notice Thrown when calling unlockCallback where the caller is not PoolManager
    error NotPoolManager();

    constructor(IPoolManager _poolManager) ImmutableState(_poolManager) {}

    /// @notice Only allow calls from the PoolManager contract
    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    /// @inheritdoc IUnlockCallback
    /// @dev We force the onlyPoolManager modifier by exposing a virtual function after the onlyPoolManager check.
    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        return _unlockCallback(data);
    }

    /// @dev to be implemented by the child contract, to safely guarantee the logic is only executed by the PoolManager
    function _unlockCallback(bytes calldata data) internal virtual returns (bytes memory);
}

// contracts/libraries/ERC/CustomERC20Permit.sol

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * This is modified version of the original OpenZeppelin Contracts ERC20Permit.sol contract.
 */
abstract contract CustomERC20Permit is ERC20, ICustomERC20Permit, EIP712, Nonces {
    bytes32 private constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline,bytes32 functionHash)"
    );

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC20 token name.
     */
    constructor(string memory name) EIP712(name, "1") {}

    /**
     * @dev This function is modified to include an additional parameter `functionHash` which is used to compute the
     * function hash for the permit signature.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string memory functionName // Additional parameter to include function name
    ) public {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        // Compute the function hash from the string input
        bytes32 functionHashBytes = keccak256(abi.encodePacked(functionName));
        bytes32 structHash =
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline, functionHashBytes));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    /**
     * @inheritdoc ICustomERC20Permit
     */
    function nonces(address owner) public view virtual override(ICustomERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @inheritdoc ICustomERC20Permit
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/ERC20Permit.sol)

/**
 * @dev Implementation of the ERC-20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC-20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
abstract contract ERC20Permit is ERC20, IERC20Permit, EIP712, Nonces {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev Permit deadline has expired.
     */
    error ERC2612ExpiredSignature(uint256 deadline);

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    /**
     * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
     *
     * It's a good idea to use the same `name` that is defined as the ERC-20 token name.
     */
    constructor(string memory name) EIP712(name, "1") {}

    /**
     * @inheritdoc IERC20Permit
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != owner) {
            revert ERC2612InvalidSigner(signer, owner);
        }

        _approve(owner, spender, value);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    function nonces(address owner) public view virtual override(IERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @inheritdoc IERC20Permit
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }
}

// lib/Cork-Hook/src/LiquidityToken.sol

contract LiquidityToken is ERC20Upgradeable, ERC20PermitUpgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, address owner) external initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __ERC20Burnable_init();
        __Ownable_init(owner);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public override onlyOwner {
        super.burn(amount);
    }
}

// lib/Cork-Hook/lib/v4-periphery/src/base/hooks/BaseHook.sol

/// @title Base Hook
/// @notice abstract contract for hook implementations
abstract contract BaseHook is IHooks, SafeCallback {
    error NotSelf();
    error InvalidPool();
    error LockFailure();
    error HookNotImplemented();

    constructor(IPoolManager _manager) SafeCallback(_manager) {
        validateHookAddress(this);
    }

    /// @dev Only this address may call this function
    modifier selfOnly() {
        if (msg.sender != address(this)) revert NotSelf();
        _;
    }

    /// @dev Only pools with hooks set to this contract may call this function
    modifier onlyValidPools(IHooks hooks) {
        if (hooks != this) revert InvalidPool();
        _;
    }

    /// @notice Returns a struct of permissions to signal which hook functions are to be implemented
    /// @dev Used at deployment to validate the address correctly represents the expected permissions
    function getHookPermissions() public pure virtual returns (Hooks.Permissions memory);

    /// @notice Validates the deployed hook address agrees with the expected permissions of the hook
    /// @dev this function is virtual so that we can override it during testing,
    /// which allows us to deploy an implementation to any address
    /// and then etch the bytecode into the correct address
    function validateHookAddress(BaseHook _this) internal pure virtual {
        Hooks.validateHookPermissions(_this, getHookPermissions());
    }

    function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory) {
        (bool success, bytes memory returnData) = address(this).call(data);
        if (success) return returnData;
        if (returnData.length == 0) revert LockFailure();
        // if the call failed, bubble up the reason
        assembly ("memory-safe") {
            revert(add(returnData, 32), mload(returnData))
        }
    }

    /// @inheritdoc IHooks
    function beforeInitialize(address, PoolKey calldata, uint160) external virtual returns (bytes4) {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterInitialize(address, PoolKey calldata, uint160, int24) external virtual returns (bytes4) {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        virtual
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        virtual
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /// @inheritdoc IHooks
    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        returns (bytes4)
    {
        revert HookNotImplemented();
    }
}

// contracts/core/assets/Asset.sol

/**
 * @title Contract for Adding Exchange Rate functionality
 * @author Cork Team
 * @notice Adds Exchange Rate functionality to Assets contracts
 */

abstract contract ExchangeRate is IRates {
    uint256 internal rate;

    constructor(uint256 _rate) {
        rate = _rate;
    }

    /**
     * @notice returns the current exchange rate
     */
    function exchangeRate() external view override returns (uint256) {
        return rate;
    }
}

/**
 * @title Contract for Adding Expiry functionality to DS
 * @author Cork Team
 * @notice Adds Expiry functionality to Assets contracts
 * @dev Used for adding Expiry functionality to contracts like DS
 */
abstract contract Expiry is IExpiry_1 {
    uint256 internal immutable EXPIRY;
    uint256 internal immutable ISSUED_AT;

    constructor(uint256 _expiry) {
        if (_expiry != 0 && _expiry < block.timestamp) {
            revert Expired();
        }

        EXPIRY = _expiry;
        ISSUED_AT = block.timestamp;
    }

    /**
     * @notice returns if contract is expired or not(if timestamp==0 then contract not having any expiry)
     */
    function isExpired() external view virtual returns (bool) {
        if (EXPIRY == 0) {
            return false;
        }

        return block.timestamp >= EXPIRY;
    }

    /**
     * @notice returns expiry timestamp of contract
     */
    function expiry() external view virtual returns (uint256) {
        return EXPIRY;
    }

    function issuedAt() external view virtual returns (uint256) {
        return ISSUED_AT;
    }
}

/**
 * @title Assets Contract
 * @author Cork Team
 * @notice Contract for implementing assets like DS/CT etc
 */
contract Asset is ERC20Burnable, CustomERC20Permit, Ownable, Expiry, ExchangeRate {
    uint256 internal immutable DS_ID;

    string public pairName;

    constructor(string memory _pairName, address _owner, uint256 _expiry, uint256 _rate, uint256 _dsId)
        ExchangeRate(_rate)
        ERC20(_pairName, _pairName)
        CustomERC20Permit(_pairName)
        Ownable(_owner)
        Expiry(_expiry)
    {
        pairName = _pairName;
        DS_ID = _dsId;
    }

    /**
     * @notice mints `amount` number of tokens to `to` address
     * @param to address of receiver
     * @param amount number of tokens to be minted
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice returns expiry timestamp of contract
     */
    function dsId() external view virtual returns (uint256) {
        return DS_ID;
    }

    function updateRate(uint256 newRate) external override onlyOwner {
        rate = newRate;
    }
}

// contracts/libraries/DepegSwapLib.sol

/**
 * @dev DepegSwap structure for DS(DepegSwap)
 */
struct DepegSwap {
    bool expiredEventEmitted;
    address _address;
    address ct;
    uint256 ctRedeemed;
}

/**
 * @title DepegSwapLibrary Contract
 * @author Cork Team
 * @notice DepegSwapLibrary library which implements DepegSwap(DS) related features
 */
library DepegSwapLibrary {
    using MinimalSignatureHelper for Signature;

    /// @notice the exchange rate of DS can only go down at maximum 10% at a time
    uint256 internal constant MAX_RATE_DELTA_PERCENTAGE = 10e18;
    /// @notice Zero Address error, thrown when passed address is 0

    error ZeroAddress();

    function isExpired(DepegSwap storage self) internal view returns (bool) {
        return Asset(self._address).isExpired();
    }

    function isInitialized(DepegSwap storage self) internal view returns (bool) {
        return self._address != address(0) && self.ct != address(0);
    }

    function initialize(address _address, address ct) internal pure returns (DepegSwap memory) {
        if (_address == address(0) || ct == address(0)) {
            revert ZeroAddress();
        }
        return DepegSwap({expiredEventEmitted: false, _address: _address, ct: ct, ctRedeemed: 0});
    }

    function permitForRA(
        address contract_,
        bytes memory rawSig,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal {
        // Split the raw signature
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        // Call the underlying ERC-20 contract's permit function
        IERC20Permit(contract_).permit(owner, spender, value, deadline, sig.v, sig.r, sig.s);
    }

    function permit(
        address contract_,
        bytes memory rawSig,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        string memory functionName
    ) internal {
        // Split the raw signature
        Signature memory sig = MinimalSignatureHelper.split(rawSig);

        // Call the underlying ERC-20 contract's permit function
        Asset(contract_).permit(owner, spender, value, deadline, sig.v, sig.r, sig.s, functionName);
    }

    function issue(DepegSwap memory self, address to, uint256 amount) internal {
        Asset(self._address).mint(to, amount);
        Asset(self.ct).mint(to, amount);
    }

    function burnCtSelf(DepegSwap storage self, uint256 amount) internal {
        Asset(self.ct).burn(amount);
    }

    function updateExchangeRate(DepegSwap storage self, uint256 rate) internal {
        Asset(self._address).updateRate(rate);
        Asset(self.ct).updateRate(rate);
    }
}

// lib/prb-math/src/sd1x18/Casting.sol

/// @notice Casts an SD1x18 number into SD59x18.
/// @dev There is no overflow check because SD1x18 ⊆ SD59x18.
function intoSD59x18_0(SD1x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(SD1x18.unwrap(x)));
}

/// @notice Casts an SD1x18 number into UD60x18.
/// @dev Requirements:
/// - x ≥ 0
function intoUD60x18_0(SD1x18 x) pure returns (UD60x18 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint128.
/// @dev Requirements:
/// - x ≥ 0
function intoUint128_0(SD1x18 x) pure returns (uint128 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUint128_Underflow(x);
    }
    result = uint128(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint256.
/// @dev Requirements:
/// - x ≥ 0
function intoUint256_0(SD1x18 x) pure returns (uint256 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUint256_Underflow(x);
    }
    result = uint256(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint40.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ MAX_UINT40
function intoUint40_0(SD1x18 x) pure returns (uint40 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD1x18_ToUint40_Underflow(x);
    }
    if (xInt > int64(uint64(MAX_UINT40))) {
        revert PRBMath_SD1x18_ToUint40_Overflow(x);
    }
    result = uint40(uint64(xInt));
}

/// @notice Alias for {wrap}.
function sd1x18(int64 x) pure returns (SD1x18 result) {
    result = SD1x18.wrap(x);
}

/// @notice Unwraps an SD1x18 number into int64.
function unwrap_0(SD1x18 x) pure returns (int64 result) {
    result = SD1x18.unwrap(x);
}

/// @notice Wraps an int64 number into SD1x18.
function wrap_0(int64 x) pure returns (SD1x18 result) {
    result = SD1x18.wrap(x);
}

// lib/prb-math/src/sd21x18/Casting.sol

/// @notice Casts an SD21x18 number into SD59x18.
/// @dev There is no overflow check because SD21x18 ⊆ SD59x18.
function intoSD59x18_1(SD21x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(SD21x18.unwrap(x)));
}

/// @notice Casts an SD21x18 number into UD60x18.
/// @dev Requirements:
/// - x ≥ 0
function intoUD60x18_1(SD21x18 x) pure returns (UD60x18 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint128(xInt));
}

/// @notice Casts an SD21x18 number into uint128.
/// @dev Requirements:
/// - x ≥ 0
function intoUint128_1(SD21x18 x) pure returns (uint128 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUint128_Underflow(x);
    }
    result = uint128(xInt);
}

/// @notice Casts an SD21x18 number into uint256.
/// @dev Requirements:
/// - x ≥ 0
function intoUint256_1(SD21x18 x) pure returns (uint256 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUint256_Underflow(x);
    }
    result = uint256(uint128(xInt));
}

/// @notice Casts an SD21x18 number into uint40.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ MAX_UINT40
function intoUint40_1(SD21x18 x) pure returns (uint40 result) {
    int128 xInt = SD21x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD21x18_ToUint40_Underflow(x);
    }
    if (xInt > int128(uint128(MAX_UINT40))) {
        revert PRBMath_SD21x18_ToUint40_Overflow(x);
    }
    result = uint40(uint128(xInt));
}

/// @notice Alias for {wrap}.
function sd21x18(int128 x) pure returns (SD21x18 result) {
    result = SD21x18.wrap(x);
}

/// @notice Unwraps an SD21x18 number into int128.
function unwrap_1(SD21x18 x) pure returns (int128 result) {
    result = SD21x18.unwrap(x);
}

/// @notice Wraps an int128 number into SD21x18.
function wrap_1(int128 x) pure returns (SD21x18 result) {
    result = SD21x18.wrap(x);
}

// lib/prb-math/src/sd59x18/Casting.sol

/// @notice Casts an SD59x18 number into int256.
/// @dev This is basically a functional alias for {unwrap}.
function intoInt256(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

/// @notice Casts an SD59x18 number into SD1x18.
/// @dev Requirements:
/// - x ≥ uMIN_SD1x18
/// - x ≤ uMAX_SD1x18
function intoSD1x18_0(SD59x18 x) pure returns (SD1x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < uMIN_SD1x18) {
        revert PRBMath_SD59x18_IntoSD1x18_Underflow(x);
    }
    if (xInt > uMAX_SD1x18) {
        revert PRBMath_SD59x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(xInt));
}

/// @notice Casts an SD59x18 number into SD21x18.
/// @dev Requirements:
/// - x ≥ uMIN_SD21x18
/// - x ≤ uMAX_SD21x18
function intoSD21x18_0(SD59x18 x) pure returns (SD21x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < uMIN_SD21x18) {
        revert PRBMath_SD59x18_IntoSD21x18_Underflow(x);
    }
    if (xInt > uMAX_SD21x18) {
        revert PRBMath_SD59x18_IntoSD21x18_Overflow(x);
    }
    result = SD21x18.wrap(int128(xInt));
}

/// @notice Casts an SD59x18 number into UD2x18.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ uMAX_UD2x18
function intoUD2x18_0(SD59x18 x) pure returns (UD2x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUD2x18_Underflow(x);
    }
    if (xInt > int256(uint256(uMAX_UD2x18))) {
        revert PRBMath_SD59x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(uint256(xInt)));
}

/// @notice Casts an SD59x18 number into UD21x18.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ uMAX_UD21x18
function intoUD21x18_0(SD59x18 x) pure returns (UD21x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUD21x18_Underflow(x);
    }
    if (xInt > int256(uint256(uMAX_UD21x18))) {
        revert PRBMath_SD59x18_IntoUD21x18_Overflow(x);
    }
    result = UD21x18.wrap(uint128(uint256(xInt)));
}

/// @notice Casts an SD59x18 number into UD60x18.
/// @dev Requirements:
/// - x ≥ 0
function intoUD60x18_2(SD59x18 x) pure returns (UD60x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint256(xInt));
}

/// @notice Casts an SD59x18 number into uint256.
/// @dev Requirements:
/// - x ≥ 0
function intoUint256_2(SD59x18 x) pure returns (uint256 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUint256_Underflow(x);
    }
    result = uint256(xInt);
}

/// @notice Casts an SD59x18 number into uint128.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ uMAX_UINT128
function intoUint128_2(SD59x18 x) pure returns (uint128 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUint128_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT128))) {
        revert PRBMath_SD59x18_IntoUint128_Overflow(x);
    }
    result = uint128(uint256(xInt));
}

/// @notice Casts an SD59x18 number into uint40.
/// @dev Requirements:
/// - x ≥ 0
/// - x ≤ MAX_UINT40
function intoUint40_2(SD59x18 x) pure returns (uint40 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert PRBMath_SD59x18_IntoUint40_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT40))) {
        revert PRBMath_SD59x18_IntoUint40_Overflow(x);
    }
    result = uint40(uint256(xInt));
}

/// @notice Alias for {wrap}.
function sd(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

/// @notice Alias for {wrap}.
function sd59x18(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

/// @notice Unwraps an SD59x18 number into int256.
function unwrap_2(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

/// @notice Wraps an int256 number into SD59x18.
function wrap_2(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

// lib/prb-math/src/ud21x18/Casting.sol

/// @notice Casts a UD21x18 number into SD59x18.
/// @dev There is no overflow check because UD21x18 ⊆ SD59x18.
function intoSD59x18_2(UD21x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(uint256(UD21x18.unwrap(x))));
}

/// @notice Casts a UD21x18 number into UD60x18.
/// @dev There is no overflow check because UD21x18 ⊆ UD60x18.
function intoUD60x18_3(UD21x18 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(UD21x18.unwrap(x));
}

/// @notice Casts a UD21x18 number into uint128.
/// @dev This is basically an alias for {unwrap}.
function intoUint128_3(UD21x18 x) pure returns (uint128 result) {
    result = UD21x18.unwrap(x);
}

/// @notice Casts a UD21x18 number into uint256.
/// @dev There is no overflow check because UD21x18 ⊆ uint256.
function intoUint256_3(UD21x18 x) pure returns (uint256 result) {
    result = uint256(UD21x18.unwrap(x));
}

/// @notice Casts a UD21x18 number into uint40.
/// @dev Requirements:
/// - x ≤ MAX_UINT40
function intoUint40_3(UD21x18 x) pure returns (uint40 result) {
    uint128 xUint = UD21x18.unwrap(x);
    if (xUint > uint128(MAX_UINT40)) {
        revert PRBMath_UD21x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud21x18(uint128 x) pure returns (UD21x18 result) {
    result = UD21x18.wrap(x);
}

/// @notice Unwrap a UD21x18 number into uint128.
function unwrap_3(UD21x18 x) pure returns (uint128 result) {
    result = UD21x18.unwrap(x);
}

/// @notice Wraps a uint128 number into UD21x18.
function wrap_3(uint128 x) pure returns (UD21x18 result) {
    result = UD21x18.wrap(x);
}

// lib/prb-math/src/ud2x18/Casting.sol

/// @notice Casts a UD2x18 number into SD59x18.
/// @dev There is no overflow check because UD2x18 ⊆ SD59x18.
function intoSD59x18_3(UD2x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(uint256(UD2x18.unwrap(x))));
}

/// @notice Casts a UD2x18 number into UD60x18.
/// @dev There is no overflow check because UD2x18 ⊆ UD60x18.
function intoUD60x18_4(UD2x18 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint128.
/// @dev There is no overflow check because UD2x18 ⊆ uint128.
function intoUint128_4(UD2x18 x) pure returns (uint128 result) {
    result = uint128(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint256.
/// @dev There is no overflow check because UD2x18 ⊆ uint256.
function intoUint256_4(UD2x18 x) pure returns (uint256 result) {
    result = uint256(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint40.
/// @dev Requirements:
/// - x ≤ MAX_UINT40
function intoUint40_4(UD2x18 x) pure returns (uint40 result) {
    uint64 xUint = UD2x18.unwrap(x);
    if (xUint > uint64(MAX_UINT40)) {
        revert PRBMath_UD2x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud2x18(uint64 x) pure returns (UD2x18 result) {
    result = UD2x18.wrap(x);
}

/// @notice Unwrap a UD2x18 number into uint64.
function unwrap_4(UD2x18 x) pure returns (uint64 result) {
    result = UD2x18.unwrap(x);
}

/// @notice Wraps a uint64 number into UD2x18.
function wrap_4(uint64 x) pure returns (UD2x18 result) {
    result = UD2x18.wrap(x);
}

// lib/prb-math/src/ud60x18/Casting.sol

/// @notice Casts a UD60x18 number into SD1x18.
/// @dev Requirements:
/// - x ≤ uMAX_SD1x18
function intoSD1x18_1(UD60x18 x) pure returns (SD1x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(int256(uMAX_SD1x18))) {
        revert PRBMath_UD60x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(uint64(xUint)));
}

/// @notice Casts a UD60x18 number into SD21x18.
/// @dev Requirements:
/// - x ≤ uMAX_SD21x18
function intoSD21x18_1(UD60x18 x) pure returns (SD21x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(int256(uMAX_SD21x18))) {
        revert PRBMath_UD60x18_IntoSD21x18_Overflow(x);
    }
    result = SD21x18.wrap(int128(uint128(xUint)));
}

/// @notice Casts a UD60x18 number into UD2x18.
/// @dev Requirements:
/// - x ≤ uMAX_UD2x18
function intoUD2x18_1(UD60x18 x) pure returns (UD2x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uMAX_UD2x18) {
        revert PRBMath_UD60x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(xUint));
}

/// @notice Casts a UD60x18 number into UD21x18.
/// @dev Requirements:
/// - x ≤ uMAX_UD21x18
function intoUD21x18_1(UD60x18 x) pure returns (UD21x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uMAX_UD21x18) {
        revert PRBMath_UD60x18_IntoUD21x18_Overflow(x);
    }
    result = UD21x18.wrap(uint128(xUint));
}

/// @notice Casts a UD60x18 number into SD59x18.
/// @dev Requirements:
/// - x ≤ uMAX_SD59x18
function intoSD59x18_4(UD60x18 x) pure returns (SD59x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(uMAX_SD59x18)) {
        revert PRBMath_UD60x18_IntoSD59x18_Overflow(x);
    }
    result = SD59x18.wrap(int256(xUint));
}

/// @notice Casts a UD60x18 number into uint128.
/// @dev This is basically an alias for {unwrap}.
function intoUint256_5(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

/// @notice Casts a UD60x18 number into uint128.
/// @dev Requirements:
/// - x ≤ MAX_UINT128
function intoUint128_5(UD60x18 x) pure returns (uint128 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT128) {
        revert PRBMath_UD60x18_IntoUint128_Overflow(x);
    }
    result = uint128(xUint);
}

/// @notice Casts a UD60x18 number into uint40.
/// @dev Requirements:
/// - x ≤ MAX_UINT40
function intoUint40_5(UD60x18 x) pure returns (uint40 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT40) {
        revert PRBMath_UD60x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

/// @notice Alias for {wrap}.
function ud60x18(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

/// @notice Unwraps a UD60x18 number into uint256.
function unwrap_5(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

/// @notice Wraps a uint256 number into the UD60x18 value type.
function wrap_5(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

// lib/prb-math/src/sd1x18/Constants.sol

/// @dev Euler's number as an SD1x18 number.
SD1x18 constant E_0 = SD1x18.wrap(2_718281828459045235);

/// @dev The maximum value an SD1x18 number can have.
int64 constant uMAX_SD1x18 = 9_223372036854775807;
SD1x18 constant MAX_SD1x18 = SD1x18.wrap(uMAX_SD1x18);

/// @dev The minimum value an SD1x18 number can have.
int64 constant uMIN_SD1x18 = -9_223372036854775808;
SD1x18 constant MIN_SD1x18 = SD1x18.wrap(uMIN_SD1x18);

/// @dev PI as an SD1x18 number.
SD1x18 constant PI_0 = SD1x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD1x18.
SD1x18 constant UNIT_1 = SD1x18.wrap(1e18);
int64 constant uUNIT_0 = 1e18;

// lib/prb-math/src/sd21x18/Constants.sol

/// @dev Euler's number as an SD21x18 number.
SD21x18 constant E_1 = SD21x18.wrap(2_718281828459045235);

/// @dev The maximum value an SD21x18 number can have.
int128 constant uMAX_SD21x18 = 170141183460469231731_687303715884105727;
SD21x18 constant MAX_SD21x18 = SD21x18.wrap(uMAX_SD21x18);

/// @dev The minimum value an SD21x18 number can have.
int128 constant uMIN_SD21x18 = -170141183460469231731_687303715884105728;
SD21x18 constant MIN_SD21x18 = SD21x18.wrap(uMIN_SD21x18);

/// @dev PI as an SD21x18 number.
SD21x18 constant PI_1 = SD21x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD21x18.
SD21x18 constant UNIT_2 = SD21x18.wrap(1e18);
int128 constant uUNIT_1 = 1e18;

// lib/prb-math/src/sd59x18/Constants.sol

// NOTICE: the "u" prefix stands for "unwrapped".

/// @dev Euler's number as an SD59x18 number.
SD59x18 constant E_2 = SD59x18.wrap(2_718281828459045235);

/// @dev The maximum input permitted in {exp}.
int256 constant uEXP_MAX_INPUT_0 = 133_084258667509499440;
SD59x18 constant EXP_MAX_INPUT_0 = SD59x18.wrap(uEXP_MAX_INPUT_0);

/// @dev Any value less than this returns 0 in {exp}.
int256 constant uEXP_MIN_THRESHOLD = -41_446531673892822322;
SD59x18 constant EXP_MIN_THRESHOLD = SD59x18.wrap(uEXP_MIN_THRESHOLD);

/// @dev The maximum input permitted in {exp2}.
int256 constant uEXP2_MAX_INPUT_0 = 192e18 - 1;
SD59x18 constant EXP2_MAX_INPUT_0 = SD59x18.wrap(uEXP2_MAX_INPUT_0);

/// @dev Any value less than this returns 0 in {exp2}.
int256 constant uEXP2_MIN_THRESHOLD = -59_794705707972522261;
SD59x18 constant EXP2_MIN_THRESHOLD = SD59x18.wrap(uEXP2_MIN_THRESHOLD);

/// @dev Half the UNIT number.
int256 constant uHALF_UNIT_0 = 0.5e18;
SD59x18 constant HALF_UNIT_0 = SD59x18.wrap(uHALF_UNIT_0);

/// @dev $log_2(10)$ as an SD59x18 number.
int256 constant uLOG2_10_0 = 3_321928094887362347;
SD59x18 constant LOG2_10_0 = SD59x18.wrap(uLOG2_10_0);

/// @dev $log_2(e)$ as an SD59x18 number.
int256 constant uLOG2_E_0 = 1_442695040888963407;
SD59x18 constant LOG2_E_0 = SD59x18.wrap(uLOG2_E_0);

/// @dev The maximum value an SD59x18 number can have.
int256 constant uMAX_SD59x18 = 57896044618658097711785492504343953926634992332820282019728_792003956564819967;
SD59x18 constant MAX_SD59x18 = SD59x18.wrap(uMAX_SD59x18);

/// @dev The maximum whole value an SD59x18 number can have.
int256 constant uMAX_WHOLE_SD59x18 = 57896044618658097711785492504343953926634992332820282019728_000000000000000000;
SD59x18 constant MAX_WHOLE_SD59x18 = SD59x18.wrap(uMAX_WHOLE_SD59x18);

/// @dev The minimum value an SD59x18 number can have.
int256 constant uMIN_SD59x18 = -57896044618658097711785492504343953926634992332820282019728_792003956564819968;
SD59x18 constant MIN_SD59x18 = SD59x18.wrap(uMIN_SD59x18);

/// @dev The minimum whole value an SD59x18 number can have.
int256 constant uMIN_WHOLE_SD59x18 = -57896044618658097711785492504343953926634992332820282019728_000000000000000000;
SD59x18 constant MIN_WHOLE_SD59x18 = SD59x18.wrap(uMIN_WHOLE_SD59x18);

/// @dev PI as an SD59x18 number.
SD59x18 constant PI_2 = SD59x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD59x18.
int256 constant uUNIT_2 = 1e18;
SD59x18 constant UNIT_3 = SD59x18.wrap(1e18);

/// @dev The unit number squared.
int256 constant uUNIT_SQUARED_0 = 1e36;
SD59x18 constant UNIT_SQUARED_0 = SD59x18.wrap(uUNIT_SQUARED_0);

/// @dev Zero as an SD59x18 number.
SD59x18 constant ZERO_0 = SD59x18.wrap(0);

// lib/prb-math/src/ud21x18/Constants.sol

/// @dev Euler's number as a UD21x18 number.
UD21x18 constant E_3 = UD21x18.wrap(2_718281828459045235);

/// @dev The maximum value a UD21x18 number can have.
uint128 constant uMAX_UD21x18 = 340282366920938463463_374607431768211455;
UD21x18 constant MAX_UD21x18 = UD21x18.wrap(uMAX_UD21x18);

/// @dev PI as a UD21x18 number.
UD21x18 constant PI_3 = UD21x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD21x18.
uint256 constant uUNIT_3 = 1e18;
UD21x18 constant UNIT_4 = UD21x18.wrap(1e18);

// lib/prb-math/src/ud2x18/Constants.sol

/// @dev Euler's number as a UD2x18 number.
UD2x18 constant E_4 = UD2x18.wrap(2_718281828459045235);

/// @dev The maximum value a UD2x18 number can have.
uint64 constant uMAX_UD2x18 = 18_446744073709551615;
UD2x18 constant MAX_UD2x18 = UD2x18.wrap(uMAX_UD2x18);

/// @dev PI as a UD2x18 number.
UD2x18 constant PI_4 = UD2x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD2x18.
UD2x18 constant UNIT_5 = UD2x18.wrap(1e18);
uint64 constant uUNIT_4 = 1e18;

// lib/prb-math/src/ud60x18/Constants.sol

// NOTICE: the "u" prefix stands for "unwrapped".

/// @dev Euler's number as a UD60x18 number.
UD60x18 constant E_5 = UD60x18.wrap(2_718281828459045235);

/// @dev The maximum input permitted in {exp}.
uint256 constant uEXP_MAX_INPUT_1 = 133_084258667509499440;
UD60x18 constant EXP_MAX_INPUT_1 = UD60x18.wrap(uEXP_MAX_INPUT_1);

/// @dev The maximum input permitted in {exp2}.
uint256 constant uEXP2_MAX_INPUT_1 = 192e18 - 1;
UD60x18 constant EXP2_MAX_INPUT_1 = UD60x18.wrap(uEXP2_MAX_INPUT_1);

/// @dev Half the UNIT number.
uint256 constant uHALF_UNIT_1 = 0.5e18;
UD60x18 constant HALF_UNIT_1 = UD60x18.wrap(uHALF_UNIT_1);

/// @dev $log_2(10)$ as a UD60x18 number.
uint256 constant uLOG2_10_1 = 3_321928094887362347;
UD60x18 constant LOG2_10_1 = UD60x18.wrap(uLOG2_10_1);

/// @dev $log_2(e)$ as a UD60x18 number.
uint256 constant uLOG2_E_1 = 1_442695040888963407;
UD60x18 constant LOG2_E_1 = UD60x18.wrap(uLOG2_E_1);

/// @dev The maximum value a UD60x18 number can have.
uint256 constant uMAX_UD60x18 = 115792089237316195423570985008687907853269984665640564039457_584007913129639935;
UD60x18 constant MAX_UD60x18 = UD60x18.wrap(uMAX_UD60x18);

/// @dev The maximum whole value a UD60x18 number can have.
uint256 constant uMAX_WHOLE_UD60x18 = 115792089237316195423570985008687907853269984665640564039457_000000000000000000;
UD60x18 constant MAX_WHOLE_UD60x18 = UD60x18.wrap(uMAX_WHOLE_UD60x18);

/// @dev PI as a UD60x18 number.
UD60x18 constant PI_5 = UD60x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD60x18.
uint256 constant uUNIT_5 = 1e18;
UD60x18 constant UNIT_6 = UD60x18.wrap(uUNIT_5);

/// @dev The unit number squared.
uint256 constant uUNIT_SQUARED_1 = 1e36;
UD60x18 constant UNIT_SQUARED_1 = UD60x18.wrap(uUNIT_SQUARED_1);

/// @dev Zero as a UD60x18 number.
UD60x18 constant ZERO_1 = UD60x18.wrap(0);

// lib/prb-math/src/sd1x18/Errors.sol

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in UD60x18.
error PRBMath_SD1x18_ToUD60x18_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint128.
error PRBMath_SD1x18_ToUint128_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint256.
error PRBMath_SD1x18_ToUint256_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint40.
error PRBMath_SD1x18_ToUint40_Overflow(SD1x18 x);

/// @notice Thrown when trying to cast an SD1x18 number that doesn't fit in uint40.
error PRBMath_SD1x18_ToUint40_Underflow(SD1x18 x);

// lib/prb-math/src/sd21x18/Errors.sol

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint128.
error PRBMath_SD21x18_ToUint128_Underflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in UD60x18.
error PRBMath_SD21x18_ToUD60x18_Underflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint256.
error PRBMath_SD21x18_ToUint256_Underflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint40.
error PRBMath_SD21x18_ToUint40_Overflow(SD21x18 x);

/// @notice Thrown when trying to cast an SD21x18 number that doesn't fit in uint40.
error PRBMath_SD21x18_ToUint40_Underflow(SD21x18 x);

// lib/prb-math/src/sd59x18/Errors.sol

/// @notice Thrown when taking the absolute value of `MIN_SD59x18`.
error PRBMath_SD59x18_Abs_MinSD59x18();

/// @notice Thrown when ceiling a number overflows SD59x18.
error PRBMath_SD59x18_Ceil_Overflow(SD59x18 x);

/// @notice Thrown when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMath_SD59x18_Convert_Overflow(int256 x);

/// @notice Thrown when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMath_SD59x18_Convert_Underflow(int256 x);

/// @notice Thrown when dividing two numbers and one of them is `MIN_SD59x18`.
error PRBMath_SD59x18_Div_InputTooSmall();

/// @notice Thrown when dividing two numbers and one of the intermediary unsigned results overflows SD59x18.
error PRBMath_SD59x18_Div_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when taking the natural exponent of a base greater than 133_084258667509499441.
error PRBMath_SD59x18_Exp_InputTooBig(SD59x18 x);

/// @notice Thrown when taking the binary exponent of a base greater than 192e18.
error PRBMath_SD59x18_Exp2_InputTooBig(SD59x18 x);

/// @notice Thrown when flooring a number underflows SD59x18.
error PRBMath_SD59x18_Floor_Underflow(SD59x18 x);

/// @notice Thrown when taking the geometric mean of two numbers and their product is negative.
error PRBMath_SD59x18_Gm_NegativeProduct(SD59x18 x, SD59x18 y);

/// @notice Thrown when taking the geometric mean of two numbers and multiplying them overflows SD59x18.
error PRBMath_SD59x18_Gm_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD1x18.
error PRBMath_SD59x18_IntoSD1x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD1x18.
error PRBMath_SD59x18_IntoSD1x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD21x18.
error PRBMath_SD59x18_IntoSD21x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in SD21x18.
error PRBMath_SD59x18_IntoSD21x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD2x18.
error PRBMath_SD59x18_IntoUD2x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD2x18.
error PRBMath_SD59x18_IntoUD2x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD21x18.
error PRBMath_SD59x18_IntoUD21x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD21x18.
error PRBMath_SD59x18_IntoUD21x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in UD60x18.
error PRBMath_SD59x18_IntoUD60x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint128.
error PRBMath_SD59x18_IntoUint128_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint128.
error PRBMath_SD59x18_IntoUint128_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint256.
error PRBMath_SD59x18_IntoUint256_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint40.
error PRBMath_SD59x18_IntoUint40_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast an SD59x18 number that doesn't fit in uint40.
error PRBMath_SD59x18_IntoUint40_Underflow(SD59x18 x);

/// @notice Thrown when taking the logarithm of a number less than or equal to zero.
error PRBMath_SD59x18_Log_InputTooSmall(SD59x18 x);

/// @notice Thrown when multiplying two numbers and one of the inputs is `MIN_SD59x18`.
error PRBMath_SD59x18_Mul_InputTooSmall();

/// @notice Thrown when multiplying two numbers and the intermediary absolute result overflows SD59x18.
error PRBMath_SD59x18_Mul_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when raising a number to a power and the intermediary absolute result overflows SD59x18.
error PRBMath_SD59x18_Powu_Overflow(SD59x18 x, uint256 y);

/// @notice Thrown when taking the square root of a negative number.
error PRBMath_SD59x18_Sqrt_NegativeInput(SD59x18 x);

/// @notice Thrown when the calculating the square root overflows SD59x18.
error PRBMath_SD59x18_Sqrt_Overflow(SD59x18 x);

// lib/prb-math/src/ud21x18/Errors.sol

/// @notice Thrown when trying to cast a UD21x18 number that doesn't fit in uint40.
error PRBMath_UD21x18_IntoUint40_Overflow(UD21x18 x);

// lib/prb-math/src/ud2x18/Errors.sol

/// @notice Thrown when trying to cast a UD2x18 number that doesn't fit in uint40.
error PRBMath_UD2x18_IntoUint40_Overflow(UD2x18 x);

// lib/prb-math/src/ud60x18/Errors.sol

/// @notice Thrown when ceiling a number overflows UD60x18.
error PRBMath_UD60x18_Ceil_Overflow(UD60x18 x);

/// @notice Thrown when converting a basic integer to the fixed-point format overflows UD60x18.
error PRBMath_UD60x18_Convert_Overflow(uint256 x);

/// @notice Thrown when taking the natural exponent of a base greater than 133_084258667509499441.
error PRBMath_UD60x18_Exp_InputTooBig(UD60x18 x);

/// @notice Thrown when taking the binary exponent of a base greater than 192e18.
error PRBMath_UD60x18_Exp2_InputTooBig(UD60x18 x);

/// @notice Thrown when taking the geometric mean of two numbers and multiplying them overflows UD60x18.
error PRBMath_UD60x18_Gm_Overflow(UD60x18 x, UD60x18 y);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD1x18.
error PRBMath_UD60x18_IntoSD1x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD21x18.
error PRBMath_UD60x18_IntoSD21x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD59x18.
error PRBMath_UD60x18_IntoSD59x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD2x18.
error PRBMath_UD60x18_IntoUD2x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD21x18.
error PRBMath_UD60x18_IntoUD21x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint128.
error PRBMath_UD60x18_IntoUint128_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint40.
error PRBMath_UD60x18_IntoUint40_Overflow(UD60x18 x);

/// @notice Thrown when taking the logarithm of a number less than UNIT.
error PRBMath_UD60x18_Log_InputTooSmall(UD60x18 x);

/// @notice Thrown when calculating the square root overflows UD60x18.
error PRBMath_UD60x18_Sqrt_Overflow(UD60x18 x);

// lib/prb-math/src/sd59x18/Helpers.sol

/// @notice Implements the checked addition operation (+) in the SD59x18 type.
function add_1(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap_2(x.unwrap_2() + y.unwrap_2());
}

/// @notice Implements the AND (&) bitwise operation in the SD59x18 type.
function and_0(SD59x18 x, int256 bits) pure returns (SD59x18 result) {
    return wrap_2(x.unwrap_2() & bits);
}

/// @notice Implements the AND (&) bitwise operation in the SD59x18 type.
function and2_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap_2(x.unwrap_2() & y.unwrap_2());
}

/// @notice Implements the equal (=) operation in the SD59x18 type.
function eq_1(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() == y.unwrap_2();
}

/// @notice Implements the greater than operation (>) in the SD59x18 type.
function gt_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() > y.unwrap_2();
}

/// @notice Implements the greater than or equal to operation (>=) in the SD59x18 type.
function gte_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() >= y.unwrap_2();
}

/// @notice Implements a zero comparison check function in the SD59x18 type.
function isZero_0(SD59x18 x) pure returns (bool result) {
    result = x.unwrap_2() == 0;
}

/// @notice Implements the left shift operation (<<) in the SD59x18 type.
function lshift_0(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() << bits);
}

/// @notice Implements the lower than operation (<) in the SD59x18 type.
function lt_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() < y.unwrap_2();
}

/// @notice Implements the lower than or equal to operation (<=) in the SD59x18 type.
function lte_0(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() <= y.unwrap_2();
}

/// @notice Implements the unchecked modulo operation (%) in the SD59x18 type.
function mod_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() % y.unwrap_2());
}

/// @notice Implements the not equal operation (!=) in the SD59x18 type.
function neq_1(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap_2() != y.unwrap_2();
}

/// @notice Implements the NOT (~) bitwise operation in the SD59x18 type.
function not_0(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(~x.unwrap_2());
}

/// @notice Implements the OR (|) bitwise operation in the SD59x18 type.
function or_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() | y.unwrap_2());
}

/// @notice Implements the right shift operation (>>) in the SD59x18 type.
function rshift_0(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() >> bits);
}

/// @notice Implements the checked subtraction operation (-) in the SD59x18 type.
function sub_1(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() - y.unwrap_2());
}

/// @notice Implements the checked unary minus operation (-) in the SD59x18 type.
function unary(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(-x.unwrap_2());
}

/// @notice Implements the unchecked addition operation (+) in the SD59x18 type.
function uncheckedAdd_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap_2(x.unwrap_2() + y.unwrap_2());
    }
}

/// @notice Implements the unchecked subtraction operation (-) in the SD59x18 type.
function uncheckedSub_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap_2(x.unwrap_2() - y.unwrap_2());
    }
}

/// @notice Implements the unchecked unary minus operation (-) in the SD59x18 type.
function uncheckedUnary(SD59x18 x) pure returns (SD59x18 result) {
    unchecked {
        result = wrap_2(-x.unwrap_2());
    }
}

/// @notice Implements the XOR (^) bitwise operation in the SD59x18 type.
function xor_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() ^ y.unwrap_2());
}

// lib/prb-math/src/ud60x18/Helpers.sol

/// @notice Implements the checked addition operation (+) in the UD60x18 type.
function add_2(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() + y.unwrap_5());
}

/// @notice Implements the AND (&) bitwise operation in the UD60x18 type.
function and_1(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() & bits);
}

/// @notice Implements the AND (&) bitwise operation in the UD60x18 type.
function and2_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() & y.unwrap_5());
}

/// @notice Implements the equal operation (==) in the UD60x18 type.
function eq_2(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() == y.unwrap_5();
}

/// @notice Implements the greater than operation (>) in the UD60x18 type.
function gt_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() > y.unwrap_5();
}

/// @notice Implements the greater than or equal to operation (>=) in the UD60x18 type.
function gte_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() >= y.unwrap_5();
}

/// @notice Implements a zero comparison check function in the UD60x18 type.
function isZero_1(UD60x18 x) pure returns (bool result) {
    // This wouldn't work if x could be negative.
    result = x.unwrap_5() == 0;
}

/// @notice Implements the left shift operation (<<) in the UD60x18 type.
function lshift_1(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() << bits);
}

/// @notice Implements the lower than operation (<) in the UD60x18 type.
function lt_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() < y.unwrap_5();
}

/// @notice Implements the lower than or equal to operation (<=) in the UD60x18 type.
function lte_1(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() <= y.unwrap_5();
}

/// @notice Implements the checked modulo operation (%) in the UD60x18 type.
function mod_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() % y.unwrap_5());
}

/// @notice Implements the not equal operation (!=) in the UD60x18 type.
function neq_2(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap_5() != y.unwrap_5();
}

/// @notice Implements the NOT (~) bitwise operation in the UD60x18 type.
function not_1(UD60x18 x) pure returns (UD60x18 result) {
    result = wrap_5(~x.unwrap_5());
}

/// @notice Implements the OR (|) bitwise operation in the UD60x18 type.
function or_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() | y.unwrap_5());
}

/// @notice Implements the right shift operation (>>) in the UD60x18 type.
function rshift_1(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() >> bits);
}

/// @notice Implements the checked subtraction operation (-) in the UD60x18 type.
function sub_2(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() - y.unwrap_5());
}

/// @notice Implements the unchecked addition operation (+) in the UD60x18 type.
function uncheckedAdd_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap_5(x.unwrap_5() + y.unwrap_5());
    }
}

/// @notice Implements the unchecked subtraction operation (-) in the UD60x18 type.
function uncheckedSub_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap_5(x.unwrap_5() - y.unwrap_5());
    }
}

/// @notice Implements the XOR (^) bitwise operation in the UD60x18 type.
function xor_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(x.unwrap_5() ^ y.unwrap_5());
}

// lib/prb-math/src/sd59x18/Math.sol

/// @notice Calculates the absolute value of x.
///
/// @dev Requirements:
/// - x > MIN_SD59x18.
///
/// @param x The SD59x18 number for which to calculate the absolute value.
/// @return result The absolute value of x as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function abs(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt == uMIN_SD59x18) {
        revert PRBMath_SD59x18_Abs_MinSD59x18();
    }
    result = xInt < 0 ? wrap_2(-xInt) : x;
}

/// @notice Calculates the arithmetic average of x and y.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// @param x The first operand as an SD59x18 number.
/// @param y The second operand as an SD59x18 number.
/// @return result The arithmetic average as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function avg_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();

    unchecked {
        // This operation is equivalent to `x / 2 +  y / 2`, and it can never overflow.
        int256 sum = (xInt >> 1) + (yInt >> 1);

        if (sum < 0) {
            // If at least one of x and y is odd, add 1 to the result, because shifting negative numbers to the right
            // rounds toward negative infinity. The right part is equivalent to `sum + (x % 2 == 1 || y % 2 == 1)`.
            assembly ("memory-safe") {
                result := add(sum, and(or(xInt, yInt), 1))
            }
        } else {
            // Add 1 if both x and y are odd to account for the double 0.5 remainder truncated after shifting.
            result = wrap_2(sum + (xInt & yInt & 1));
        }
    }
}

/// @notice Yields the smallest whole number greater than or equal to x.
///
/// @dev Optimized for fractional value inputs, because every whole value has (1e18 - 1) fractional counterparts.
/// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x ≤ MAX_WHOLE_SD59x18
///
/// @param x The SD59x18 number to ceil.
/// @return result The smallest whole number greater than or equal to x, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function ceil_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt > uMAX_WHOLE_SD59x18) {
        revert PRBMath_SD59x18_Ceil_Overflow(x);
    }

    int256 remainder = xInt % uUNIT_2;
    if (remainder == 0) {
        result = x;
    } else {
        unchecked {
            // Solidity uses C fmod style, which returns a modulus with the same sign as x.
            int256 resultInt = xInt - remainder;
            if (xInt > 0) {
                resultInt += uUNIT_2;
            }
            result = wrap_2(resultInt);
        }
    }
}

/// @notice Divides two SD59x18 numbers, returning a new SD59x18 number.
///
/// @dev This is an extension of {Common.mulDiv} for signed numbers, which works by computing the signs and the absolute
/// values separately.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
/// - The result is rounded toward zero.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
/// - None of the inputs can be `MIN_SD59x18`.
/// - The denominator must not be zero.
/// - The result must fit in SD59x18.
///
/// @param x The numerator as an SD59x18 number.
/// @param y The denominator as an SD59x18 number.
/// @return result The quotient as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function div_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();
    if (xInt == uMIN_SD59x18 || yInt == uMIN_SD59x18) {
        revert PRBMath_SD59x18_Div_InputTooSmall();
    }

    // Get hold of the absolute values of x and y.
    uint256 xAbs;
    uint256 yAbs;
    unchecked {
        xAbs = xInt < 0 ? uint256(-xInt) : uint256(xInt);
        yAbs = yInt < 0 ? uint256(-yInt) : uint256(yInt);
    }

    // Compute the absolute value (x*UNIT÷y). The resulting value must fit in SD59x18.
    uint256 resultAbs = mulDiv(xAbs, uint256(uUNIT_2), yAbs);
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert PRBMath_SD59x18_Div_Overflow(x, y);
    }

    // Check if x and y have the same sign using two's complement representation. The left-most bit represents the sign (1 for
    // negative, 0 for positive or zero).
    bool sameSign = (xInt ^ yInt) > -1;

    // If the inputs have the same sign, the result should be positive. Otherwise, it should be negative.
    unchecked {
        result = wrap_2(sameSign ? int256(resultAbs) : -int256(resultAbs));
    }
}

/// @notice Calculates the natural exponent of x using the following formula:
///
/// $$
/// e^x = 2^{x * log_2{e}}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {exp2}.
///
/// Requirements:
/// - Refer to the requirements in {exp2}.
/// - x < 133_084258667509499441.
///
/// @param x The exponent as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();

    // Any input less than the threshold returns zero.
    // This check also prevents an overflow for very small numbers.
    if (xInt < uEXP_MIN_THRESHOLD) {
        return ZERO_0;
    }

    // This check prevents values greater than 192e18 from being passed to {exp2}.
    if (xInt > uEXP_MAX_INPUT_0) {
        revert PRBMath_SD59x18_Exp_InputTooBig(x);
    }

    unchecked {
        // Inline the fixed-point multiplication to save gas.
        int256 doubleUnitProduct = xInt * uLOG2_E_0;
        result = exp2_1(wrap_2(doubleUnitProduct / uUNIT_2));
    }
}

/// @notice Calculates the binary exponent of x using the binary fraction method using the following formula:
///
/// $$
/// 2^{-x} = \frac{1}{2^x}
/// $$
///
/// @dev See https://ethereum.stackexchange.com/q/79903/24693.
///
/// Notes:
/// - If x < -59_794705707972522261, the result is zero.
///
/// Requirements:
/// - x < 192e18.
/// - The result must fit in SD59x18.
///
/// @param x The exponent as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp2_1(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < 0) {
        // The inverse of any number less than the threshold is truncated to zero.
        if (xInt < uEXP2_MIN_THRESHOLD) {
            return ZERO_0;
        }

        unchecked {
            // Inline the fixed-point inversion to save gas.
            result = wrap_2(uUNIT_SQUARED_0 / exp2_1(wrap_2(-xInt)).unwrap_2());
        }
    } else {
        // Numbers greater than or equal to 192e18 don't fit in the 192.64-bit format.
        if (xInt > uEXP2_MAX_INPUT_0) {
            revert PRBMath_SD59x18_Exp2_InputTooBig(x);
        }

        unchecked {
            // Convert x to the 192.64-bit fixed-point format.
            uint256 x_192x64 = uint256((xInt << 64) / uUNIT_2);

            // It is safe to cast the result to int256 due to the checks above.
            result = wrap_2(int256(exp2_0(x_192x64)));
        }
    }
}

/// @notice Yields the greatest whole number less than or equal to x.
///
/// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional
/// counterparts. See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x ≥ MIN_WHOLE_SD59x18
///
/// @param x The SD59x18 number to floor.
/// @return result The greatest whole number less than or equal to x, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function floor_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < uMIN_WHOLE_SD59x18) {
        revert PRBMath_SD59x18_Floor_Underflow(x);
    }

    int256 remainder = xInt % uUNIT_2;
    if (remainder == 0) {
        result = x;
    } else {
        unchecked {
            // Solidity uses C fmod style, which returns a modulus with the same sign as x.
            int256 resultInt = xInt - remainder;
            if (xInt < 0) {
                resultInt -= uUNIT_2;
            }
            result = wrap_2(resultInt);
        }
    }
}

/// @notice Yields the excess beyond the floor of x for positive numbers and the part of the number to the right.
/// of the radix point for negative numbers.
/// @dev Based on the odd function definition. https://en.wikipedia.org/wiki/Fractional_part
/// @param x The SD59x18 number to get the fractional part of.
/// @return result The fractional part of x as an SD59x18 number.
function frac_0(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(x.unwrap_2() % uUNIT_2);
}

/// @notice Calculates the geometric mean of x and y, i.e. $\sqrt{x * y}$.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x * y must fit in SD59x18.
/// - x * y must not be negative, since complex numbers are not supported.
///
/// @param x The first operand as an SD59x18 number.
/// @param y The second operand as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function gm_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();
    if (xInt == 0 || yInt == 0) {
        return ZERO_0;
    }

    unchecked {
        // Equivalent to `xy / x != y`. Checking for overflow this way is faster than letting Solidity do it.
        int256 xyInt = xInt * yInt;
        if (xyInt / xInt != yInt) {
            revert PRBMath_SD59x18_Gm_Overflow(x, y);
        }

        // The product must not be negative, since complex numbers are not supported.
        if (xyInt < 0) {
            revert PRBMath_SD59x18_Gm_NegativeProduct(x, y);
        }

        // We don't need to multiply the result by `UNIT` here because the x*y product picked up a factor of `UNIT`
        // during multiplication. See the comments in {Common.sqrt}.
        uint256 resultUint = sqrt_0(uint256(xyInt));
        result = wrap_2(int256(resultUint));
    }
}

/// @notice Calculates the inverse of x.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x must not be zero.
///
/// @param x The SD59x18 number for which to calculate the inverse.
/// @return result The inverse as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function inv_0(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap_2(uUNIT_SQUARED_0 / x.unwrap_2());
}

/// @notice Calculates the natural logarithm of x using the following formula:
///
/// $$
/// ln{x} = log_2{x} / log_2{e}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
/// - The precision isn't sufficiently fine-grained to return exactly `UNIT` when the input is `E`.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The SD59x18 number for which to calculate the natural logarithm.
/// @return result The natural logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function ln_0(SD59x18 x) pure returns (SD59x18 result) {
    // Inline the fixed-point multiplication to save gas. This is overflow-safe because the maximum value that
    // {log2} can return is ~195_205294292027477728.
    result = wrap_2(log2_0(x).unwrap_2() * uUNIT_2 / uLOG2_E_0);
}

/// @notice Calculates the common logarithm of x using the following formula:
///
/// $$
/// log_{10}{x} = log_2{x} / log_2{10}
/// $$
///
/// However, if x is an exact power of ten, a hard coded value is returned.
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The SD59x18 number for which to calculate the common logarithm.
/// @return result The common logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function log10_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < 0) {
        revert PRBMath_SD59x18_Log_InputTooSmall(x);
    }

    // Note that the `mul` in this block is the standard multiplication operation, not {SD59x18.mul}.
    // prettier-ignore
    assembly ("memory-safe") {
        switch x
        case 1 { result := mul(uUNIT_2, sub(0, 18)) }
        case 10 { result := mul(uUNIT_2, sub(1, 18)) }
        case 100 { result := mul(uUNIT_2, sub(2, 18)) }
        case 1000 { result := mul(uUNIT_2, sub(3, 18)) }
        case 10000 { result := mul(uUNIT_2, sub(4, 18)) }
        case 100000 { result := mul(uUNIT_2, sub(5, 18)) }
        case 1000000 { result := mul(uUNIT_2, sub(6, 18)) }
        case 10000000 { result := mul(uUNIT_2, sub(7, 18)) }
        case 100000000 { result := mul(uUNIT_2, sub(8, 18)) }
        case 1000000000 { result := mul(uUNIT_2, sub(9, 18)) }
        case 10000000000 { result := mul(uUNIT_2, sub(10, 18)) }
        case 100000000000 { result := mul(uUNIT_2, sub(11, 18)) }
        case 1000000000000 { result := mul(uUNIT_2, sub(12, 18)) }
        case 10000000000000 { result := mul(uUNIT_2, sub(13, 18)) }
        case 100000000000000 { result := mul(uUNIT_2, sub(14, 18)) }
        case 1000000000000000 { result := mul(uUNIT_2, sub(15, 18)) }
        case 10000000000000000 { result := mul(uUNIT_2, sub(16, 18)) }
        case 100000000000000000 { result := mul(uUNIT_2, sub(17, 18)) }
        case 1000000000000000000 { result := 0 }
        case 10000000000000000000 { result := uUNIT_2 }
        case 100000000000000000000 { result := mul(uUNIT_2, 2) }
        case 1000000000000000000000 { result := mul(uUNIT_2, 3) }
        case 10000000000000000000000 { result := mul(uUNIT_2, 4) }
        case 100000000000000000000000 { result := mul(uUNIT_2, 5) }
        case 1000000000000000000000000 { result := mul(uUNIT_2, 6) }
        case 10000000000000000000000000 { result := mul(uUNIT_2, 7) }
        case 100000000000000000000000000 { result := mul(uUNIT_2, 8) }
        case 1000000000000000000000000000 { result := mul(uUNIT_2, 9) }
        case 10000000000000000000000000000 { result := mul(uUNIT_2, 10) }
        case 100000000000000000000000000000 { result := mul(uUNIT_2, 11) }
        case 1000000000000000000000000000000 { result := mul(uUNIT_2, 12) }
        case 10000000000000000000000000000000 { result := mul(uUNIT_2, 13) }
        case 100000000000000000000000000000000 { result := mul(uUNIT_2, 14) }
        case 1000000000000000000000000000000000 { result := mul(uUNIT_2, 15) }
        case 10000000000000000000000000000000000 { result := mul(uUNIT_2, 16) }
        case 100000000000000000000000000000000000 { result := mul(uUNIT_2, 17) }
        case 1000000000000000000000000000000000000 { result := mul(uUNIT_2, 18) }
        case 10000000000000000000000000000000000000 { result := mul(uUNIT_2, 19) }
        case 100000000000000000000000000000000000000 { result := mul(uUNIT_2, 20) }
        case 1000000000000000000000000000000000000000 { result := mul(uUNIT_2, 21) }
        case 10000000000000000000000000000000000000000 { result := mul(uUNIT_2, 22) }
        case 100000000000000000000000000000000000000000 { result := mul(uUNIT_2, 23) }
        case 1000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 24) }
        case 10000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 25) }
        case 100000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 26) }
        case 1000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 27) }
        case 10000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 28) }
        case 100000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 29) }
        case 1000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 30) }
        case 10000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 31) }
        case 100000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 32) }
        case 1000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 33) }
        case 10000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 34) }
        case 100000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 35) }
        case 1000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 36) }
        case 10000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 37) }
        case 100000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 38) }
        case 1000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 39) }
        case 10000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 40) }
        case 100000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 41) }
        case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 42) }
        case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 43) }
        case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 44) }
        case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 45) }
        case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 46) }
        case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 47) }
        case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 48) }
        case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 49) }
        case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 50) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 51) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 52) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 53) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 54) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 55) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 56) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 57) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_2, 58) }
        default { result := uMAX_SD59x18 }
    }

    if (result.unwrap_2() == uMAX_SD59x18) {
        unchecked {
            // Inline the fixed-point division to save gas.
            result = wrap_2(log2_0(x).unwrap_2() * uUNIT_2 / uLOG2_10_0);
        }
    }
}

/// @notice Calculates the binary logarithm of x using the iterative approximation algorithm:
///
/// $$
/// log_2{x} = n + log_2{y}, \text{ where } y = x*2^{-n}, \ y \in [1, 2)
/// $$
///
/// For $0 \leq x \lt 1$, the input is inverted:
///
/// $$
/// log_2{x} = -log_2{\frac{1}{x}}
/// $$
///
/// @dev See https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation.
///
/// Notes:
/// - Due to the lossy precision of the iterative approximation, the results are not perfectly accurate to the last decimal.
///
/// Requirements:
/// - x > 0
///
/// @param x The SD59x18 number for which to calculate the binary logarithm.
/// @return result The binary logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function log2_0(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt <= 0) {
        revert PRBMath_SD59x18_Log_InputTooSmall(x);
    }

    unchecked {
        int256 sign;
        if (xInt >= uUNIT_2) {
            sign = 1;
        } else {
            sign = -1;
            // Inline the fixed-point inversion to save gas.
            xInt = uUNIT_SQUARED_0 / xInt;
        }

        // Calculate the integer part of the logarithm.
        uint256 n = msb(uint256(xInt / uUNIT_2));

        // This is the integer part of the logarithm as an SD59x18 number. The operation can't overflow
        // because n is at most 255, `UNIT` is 1e18, and the sign is either 1 or -1.
        int256 resultInt = int256(n) * uUNIT_2;

        // Calculate $y = x * 2^{-n}$.
        int256 y = xInt >> n;

        // If y is the unit number, the fractional part is zero.
        if (y == uUNIT_2) {
            return wrap_2(resultInt * sign);
        }

        // Calculate the fractional part via the iterative approximation.
        // The `delta >>= 1` part is equivalent to `delta /= 2`, but shifting bits is more gas efficient.
        int256 DOUBLE_UNIT = 2e18;
        for (int256 delta = uHALF_UNIT_0; delta > 0; delta >>= 1) {
            y = (y * y) / uUNIT_2;

            // Is y^2 >= 2e18 and so in the range [2e18, 4e18)?
            if (y >= DOUBLE_UNIT) {
                // Add the 2^{-m} factor to the logarithm.
                resultInt = resultInt + delta;

                // Halve y, which corresponds to z/2 in the Wikipedia article.
                y >>= 1;
            }
        }
        resultInt *= sign;
        result = wrap_2(resultInt);
    }
}

/// @notice Multiplies two SD59x18 numbers together, returning a new SD59x18 number.
///
/// @dev Notes:
/// - Refer to the notes in {Common.mulDiv18}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv18}.
/// - None of the inputs can be `MIN_SD59x18`.
/// - The result must fit in SD59x18.
///
/// @param x The multiplicand as an SD59x18 number.
/// @param y The multiplier as an SD59x18 number.
/// @return result The product as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function mul_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();
    if (xInt == uMIN_SD59x18 || yInt == uMIN_SD59x18) {
        revert PRBMath_SD59x18_Mul_InputTooSmall();
    }

    // Get hold of the absolute values of x and y.
    uint256 xAbs;
    uint256 yAbs;
    unchecked {
        xAbs = xInt < 0 ? uint256(-xInt) : uint256(xInt);
        yAbs = yInt < 0 ? uint256(-yInt) : uint256(yInt);
    }

    // Compute the absolute value (x*y÷UNIT). The resulting value must fit in SD59x18.
    uint256 resultAbs = mulDiv18(xAbs, yAbs);
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert PRBMath_SD59x18_Mul_Overflow(x, y);
    }

    // Check if x and y have the same sign using two's complement representation. The left-most bit represents the sign (1 for
    // negative, 0 for positive or zero).
    bool sameSign = (xInt ^ yInt) > -1;

    // If the inputs have the same sign, the result should be positive. Otherwise, it should be negative.
    unchecked {
        result = wrap_2(sameSign ? int256(resultAbs) : -int256(resultAbs));
    }
}

/// @notice Raises x to the power of y using the following formula:
///
/// $$
/// x^y = 2^{log_2{x} * y}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {exp2}, {log2}, and {mul}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - Refer to the requirements in {exp2}, {log2}, and {mul}.
///
/// @param x The base as an SD59x18 number.
/// @param y Exponent to raise x to, as an SD59x18 number
/// @return result x raised to power y, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function pow_0(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    int256 yInt = y.unwrap_2();

    // If both x and y are zero, the result is `UNIT`. If just x is zero, the result is always zero.
    if (xInt == 0) {
        return yInt == 0 ? UNIT_3 : ZERO_0;
    }
    // If x is `UNIT`, the result is always `UNIT`.
    else if (xInt == uUNIT_2) {
        return UNIT_3;
    }

    // If y is zero, the result is always `UNIT`.
    if (yInt == 0) {
        return UNIT_3;
    }
    // If y is `UNIT`, the result is always x.
    else if (yInt == uUNIT_2) {
        return x;
    }

    // Calculate the result using the formula.
    result = exp2_1(mul_0(log2_0(x), y));
}

/// @notice Raises x (an SD59x18 number) to the power y (an unsigned basic integer) using the well-known
/// algorithm "exponentiation by squaring".
///
/// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv18}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - Refer to the requirements in {abs} and {Common.mulDiv18}.
/// - The result must fit in SD59x18.
///
/// @param x The base as an SD59x18 number.
/// @param y The exponent as a uint256.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function powu_0(SD59x18 x, uint256 y) pure returns (SD59x18 result) {
    uint256 xAbs = uint256(abs(x).unwrap_2());

    // Calculate the first iteration of the loop in advance.
    uint256 resultAbs = y & 1 > 0 ? xAbs : uint256(uUNIT_2);

    // Equivalent to `for(y /= 2; y > 0; y /= 2)`.
    uint256 yAux = y;
    for (yAux >>= 1; yAux > 0; yAux >>= 1) {
        xAbs = mulDiv18(xAbs, xAbs);

        // Equivalent to `y % 2 == 1`.
        if (yAux & 1 > 0) {
            resultAbs = mulDiv18(resultAbs, xAbs);
        }
    }

    // The result must fit in SD59x18.
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert PRBMath_SD59x18_Powu_Overflow(x, y);
    }

    unchecked {
        // Is the base negative and the exponent odd? If yes, the result should be negative.
        int256 resultInt = int256(resultAbs);
        bool isNegative = x.unwrap_2() < 0 && y & 1 == 1;
        if (isNegative) {
            resultInt = -resultInt;
        }
        result = wrap_2(resultInt);
    }
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - Only the positive root is returned.
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x ≥ 0, since complex numbers are not supported.
/// - x ≤ MAX_SD59x18 / UNIT
///
/// @param x The SD59x18 number for which to calculate the square root.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function sqrt_1(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap_2();
    if (xInt < 0) {
        revert PRBMath_SD59x18_Sqrt_NegativeInput(x);
    }
    if (xInt > uMAX_SD59x18 / uUNIT_2) {
        revert PRBMath_SD59x18_Sqrt_Overflow(x);
    }

    unchecked {
        // Multiply x by `UNIT` to account for the factor of `UNIT` picked up when multiplying two SD59x18 numbers.
        // In this case, the two numbers are both the square root.
        uint256 resultUint = sqrt_0(uint256(xInt * uUNIT_2));
        result = wrap_2(int256(resultUint));
    }
}

// lib/prb-math/src/ud60x18/Math.sol

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Calculates the arithmetic average of x and y using the following formula:
///
/// $$
/// avg(x, y) = (x & y) + ((xUint ^ yUint) / 2)
/// $$
///
/// In English, this is what this formula does:
///
/// 1. AND x and y.
/// 2. Calculate half of XOR x and y.
/// 3. Add the two results together.
///
/// This technique is known as SWAR, which stands for "SIMD within a register". You can read more about it here:
/// https://devblogs.microsoft.com/oldnewthing/20220207-00/?p=106223
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// @param x The first operand as a UD60x18 number.
/// @param y The second operand as a UD60x18 number.
/// @return result The arithmetic average as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function avg_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    uint256 yUint = y.unwrap_5();
    unchecked {
        result = wrap_5((xUint & yUint) + ((xUint ^ yUint) >> 1));
    }
}

/// @notice Yields the smallest whole number greater than or equal to x.
///
/// @dev This is optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional
/// counterparts. See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x ≤ MAX_WHOLE_UD60x18
///
/// @param x The UD60x18 number to ceil.
/// @return result The smallest whole number greater than or equal to x, as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function ceil_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    if (xUint > uMAX_WHOLE_UD60x18) {
        revert PRBMath_UD60x18_Ceil_Overflow(x);
    }

    assembly ("memory-safe") {
        // Equivalent to `x % UNIT`.
        let remainder := mod(x, uUNIT_5)

        // Equivalent to `UNIT - remainder`.
        let delta := sub(uUNIT_5, remainder)

        // Equivalent to `x + remainder > 0 ? delta : 0`.
        result := add(x, mul(delta, gt(remainder, 0)))
    }
}

/// @notice Divides two UD60x18 numbers, returning a new UD60x18 number.
///
/// @dev Uses {Common.mulDiv} to enable overflow-safe multiplication and division.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
///
/// @param x The numerator as a UD60x18 number.
/// @param y The denominator as a UD60x18 number.
/// @return result The quotient as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function div_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(mulDiv(x.unwrap_5(), uUNIT_5, y.unwrap_5()));
}

/// @notice Calculates the natural exponent of x using the following formula:
///
/// $$
/// e^x = 2^{x * log_2{e}}
/// $$
///
/// @dev Requirements:
/// - x ≤ 133_084258667509499440
///
/// @param x The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    // This check prevents values greater than 192e18 from being passed to {exp2}.
    if (xUint > uEXP_MAX_INPUT_1) {
        revert PRBMath_UD60x18_Exp_InputTooBig(x);
    }

    unchecked {
        // Inline the fixed-point multiplication to save gas.
        uint256 doubleUnitProduct = xUint * uLOG2_E_1;
        result = exp2_2(wrap_5(doubleUnitProduct / uUNIT_5));
    }
}

/// @notice Calculates the binary exponent of x using the binary fraction method.
///
/// @dev See https://ethereum.stackexchange.com/q/79903/24693
///
/// Requirements:
/// - x < 192e18
/// - The result must fit in UD60x18.
///
/// @param x The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp2_2(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    // Numbers greater than or equal to 192e18 don't fit in the 192.64-bit format.
    if (xUint > uEXP2_MAX_INPUT_1) {
        revert PRBMath_UD60x18_Exp2_InputTooBig(x);
    }

    // Convert x to the 192.64-bit fixed-point format.
    uint256 x_192x64 = (xUint << 64) / uUNIT_5;

    // Pass x to the {Common.exp2} function, which uses the 192.64-bit fixed-point number representation.
    result = wrap_5(exp2_0(x_192x64));
}

/// @notice Yields the greatest whole number less than or equal to x.
/// @dev Optimized for fractional value inputs, because every whole value has (1e18 - 1) fractional counterparts.
/// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
/// @param x The UD60x18 number to floor.
/// @return result The greatest whole number less than or equal to x, as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function floor_1(UD60x18 x) pure returns (UD60x18 result) {
    assembly ("memory-safe") {
        // Equivalent to `x % UNIT`.
        let remainder := mod(x, uUNIT_5)

        // Equivalent to `x - remainder > 0 ? remainder : 0)`.
        result := sub(x, mul(remainder, gt(remainder, 0)))
    }
}

/// @notice Yields the excess beyond the floor of x using the odd function definition.
/// @dev See https://en.wikipedia.org/wiki/Fractional_part.
/// @param x The UD60x18 number to get the fractional part of.
/// @return result The fractional part of x as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function frac_1(UD60x18 x) pure returns (UD60x18 result) {
    assembly ("memory-safe") {
        result := mod(x, uUNIT_5)
    }
}

/// @notice Calculates the geometric mean of x and y, i.e. $\sqrt{x * y}$, rounding down.
///
/// @dev Requirements:
/// - x * y must fit in UD60x18.
///
/// @param x The first operand as a UD60x18 number.
/// @param y The second operand as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function gm_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    uint256 yUint = y.unwrap_5();
    if (xUint == 0 || yUint == 0) {
        return ZERO_1;
    }

    unchecked {
        // Checking for overflow this way is faster than letting Solidity do it.
        uint256 xyUint = xUint * yUint;
        if (xyUint / xUint != yUint) {
            revert PRBMath_UD60x18_Gm_Overflow(x, y);
        }

        // We don't need to multiply the result by `UNIT` here because the x*y product picked up a factor of `UNIT`
        // during multiplication. See the comments in {Common.sqrt}.
        result = wrap_5(sqrt_0(xyUint));
    }
}

/// @notice Calculates the inverse of x.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x must not be zero.
///
/// @param x The UD60x18 number for which to calculate the inverse.
/// @return result The inverse as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function inv_1(UD60x18 x) pure returns (UD60x18 result) {
    unchecked {
        result = wrap_5(uUNIT_SQUARED_1 / x.unwrap_5());
    }
}

/// @notice Calculates the natural logarithm of x using the following formula:
///
/// $$
/// ln{x} = log_2{x} / log_2{e}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
/// - The precision isn't sufficiently fine-grained to return exactly `UNIT` when the input is `E`.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The UD60x18 number for which to calculate the natural logarithm.
/// @return result The natural logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function ln_1(UD60x18 x) pure returns (UD60x18 result) {
    unchecked {
        // Inline the fixed-point multiplication to save gas. This is overflow-safe because the maximum value that
        // {log2} can return is ~196_205294292027477728.
        result = wrap_5(log2_1(x).unwrap_5() * uUNIT_5 / uLOG2_E_1);
    }
}

/// @notice Calculates the common logarithm of x using the following formula:
///
/// $$
/// log_{10}{x} = log_2{x} / log_2{10}
/// $$
///
/// However, if x is an exact power of ten, a hard coded value is returned.
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The UD60x18 number for which to calculate the common logarithm.
/// @return result The common logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function log10_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    if (xUint < uUNIT_5) {
        revert PRBMath_UD60x18_Log_InputTooSmall(x);
    }

    // Note that the `mul` in this assembly block is the standard multiplication operation, not {UD60x18.mul}.
    // prettier-ignore
    assembly ("memory-safe") {
        switch x
        case 1 { result := mul(uUNIT_5, sub(0, 18)) }
        case 10 { result := mul(uUNIT_5, sub(1, 18)) }
        case 100 { result := mul(uUNIT_5, sub(2, 18)) }
        case 1000 { result := mul(uUNIT_5, sub(3, 18)) }
        case 10000 { result := mul(uUNIT_5, sub(4, 18)) }
        case 100000 { result := mul(uUNIT_5, sub(5, 18)) }
        case 1000000 { result := mul(uUNIT_5, sub(6, 18)) }
        case 10000000 { result := mul(uUNIT_5, sub(7, 18)) }
        case 100000000 { result := mul(uUNIT_5, sub(8, 18)) }
        case 1000000000 { result := mul(uUNIT_5, sub(9, 18)) }
        case 10000000000 { result := mul(uUNIT_5, sub(10, 18)) }
        case 100000000000 { result := mul(uUNIT_5, sub(11, 18)) }
        case 1000000000000 { result := mul(uUNIT_5, sub(12, 18)) }
        case 10000000000000 { result := mul(uUNIT_5, sub(13, 18)) }
        case 100000000000000 { result := mul(uUNIT_5, sub(14, 18)) }
        case 1000000000000000 { result := mul(uUNIT_5, sub(15, 18)) }
        case 10000000000000000 { result := mul(uUNIT_5, sub(16, 18)) }
        case 100000000000000000 { result := mul(uUNIT_5, sub(17, 18)) }
        case 1000000000000000000 { result := 0 }
        case 10000000000000000000 { result := uUNIT_5 }
        case 100000000000000000000 { result := mul(uUNIT_5, 2) }
        case 1000000000000000000000 { result := mul(uUNIT_5, 3) }
        case 10000000000000000000000 { result := mul(uUNIT_5, 4) }
        case 100000000000000000000000 { result := mul(uUNIT_5, 5) }
        case 1000000000000000000000000 { result := mul(uUNIT_5, 6) }
        case 10000000000000000000000000 { result := mul(uUNIT_5, 7) }
        case 100000000000000000000000000 { result := mul(uUNIT_5, 8) }
        case 1000000000000000000000000000 { result := mul(uUNIT_5, 9) }
        case 10000000000000000000000000000 { result := mul(uUNIT_5, 10) }
        case 100000000000000000000000000000 { result := mul(uUNIT_5, 11) }
        case 1000000000000000000000000000000 { result := mul(uUNIT_5, 12) }
        case 10000000000000000000000000000000 { result := mul(uUNIT_5, 13) }
        case 100000000000000000000000000000000 { result := mul(uUNIT_5, 14) }
        case 1000000000000000000000000000000000 { result := mul(uUNIT_5, 15) }
        case 10000000000000000000000000000000000 { result := mul(uUNIT_5, 16) }
        case 100000000000000000000000000000000000 { result := mul(uUNIT_5, 17) }
        case 1000000000000000000000000000000000000 { result := mul(uUNIT_5, 18) }
        case 10000000000000000000000000000000000000 { result := mul(uUNIT_5, 19) }
        case 100000000000000000000000000000000000000 { result := mul(uUNIT_5, 20) }
        case 1000000000000000000000000000000000000000 { result := mul(uUNIT_5, 21) }
        case 10000000000000000000000000000000000000000 { result := mul(uUNIT_5, 22) }
        case 100000000000000000000000000000000000000000 { result := mul(uUNIT_5, 23) }
        case 1000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 24) }
        case 10000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 25) }
        case 100000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 26) }
        case 1000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 27) }
        case 10000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 28) }
        case 100000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 29) }
        case 1000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 30) }
        case 10000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 31) }
        case 100000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 32) }
        case 1000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 33) }
        case 10000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 34) }
        case 100000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 35) }
        case 1000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 36) }
        case 10000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 37) }
        case 100000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 38) }
        case 1000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 39) }
        case 10000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 40) }
        case 100000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 41) }
        case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 42) }
        case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 43) }
        case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 44) }
        case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 45) }
        case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 46) }
        case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 47) }
        case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 48) }
        case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 49) }
        case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 50) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 51) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 52) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 53) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 54) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 55) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 56) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 57) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 58) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT_5, 59) }
        default { result := uMAX_UD60x18 }
    }

    if (result.unwrap_5() == uMAX_UD60x18) {
        unchecked {
            // Inline the fixed-point division to save gas.
            result = wrap_5(log2_1(x).unwrap_5() * uUNIT_5 / uLOG2_10_1);
        }
    }
}

/// @notice Calculates the binary logarithm of x using the iterative approximation algorithm:
///
/// $$
/// log_2{x} = n + log_2{y}, \text{ where } y = x*2^{-n}, \ y \in [1, 2)
/// $$
///
/// For $0 \leq x \lt 1$, the input is inverted:
///
/// $$
/// log_2{x} = -log_2{\frac{1}{x}}
/// $$
///
/// @dev See https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
///
/// Notes:
/// - Due to the lossy precision of the iterative approximation, the results are not perfectly accurate to the last decimal.
///
/// Requirements:
/// - x ≥ UNIT
///
/// @param x The UD60x18 number for which to calculate the binary logarithm.
/// @return result The binary logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function log2_1(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    if (xUint < uUNIT_5) {
        revert PRBMath_UD60x18_Log_InputTooSmall(x);
    }

    unchecked {
        // Calculate the integer part of the logarithm.
        uint256 n = msb(xUint / uUNIT_5);

        // This is the integer part of the logarithm as a UD60x18 number. The operation can't overflow because n
        // n is at most 255 and UNIT is 1e18.
        uint256 resultUint = n * uUNIT_5;

        // Calculate $y = x * 2^{-n}$.
        uint256 y = xUint >> n;

        // If y is the unit number, the fractional part is zero.
        if (y == uUNIT_5) {
            return wrap_5(resultUint);
        }

        // Calculate the fractional part via the iterative approximation.
        // The `delta >>= 1` part is equivalent to `delta /= 2`, but shifting bits is more gas efficient.
        uint256 DOUBLE_UNIT = 2e18;
        for (uint256 delta = uHALF_UNIT_1; delta > 0; delta >>= 1) {
            y = (y * y) / uUNIT_5;

            // Is y^2 >= 2e18 and so in the range [2e18, 4e18)?
            if (y >= DOUBLE_UNIT) {
                // Add the 2^{-m} factor to the logarithm.
                resultUint += delta;

                // Halve y, which corresponds to z/2 in the Wikipedia article.
                y >>= 1;
            }
        }
        result = wrap_5(resultUint);
    }
}

/// @notice Multiplies two UD60x18 numbers together, returning a new UD60x18 number.
///
/// @dev Uses {Common.mulDiv} to enable overflow-safe multiplication and division.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
///
/// @dev See the documentation in {Common.mulDiv18}.
/// @param x The multiplicand as a UD60x18 number.
/// @param y The multiplier as a UD60x18 number.
/// @return result The product as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function mul_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap_5(mulDiv18(x.unwrap_5(), y.unwrap_5()));
}

/// @notice Raises x to the power of y.
///
/// For $1 \leq x \leq \infty$, the following standard formula is used:
///
/// $$
/// x^y = 2^{log_2{x} * y}
/// $$
///
/// For $0 \leq x \lt 1$, since the unsigned {log2} is undefined, an equivalent formula is used:
///
/// $$
/// i = \frac{1}{x}
/// w = 2^{log_2{i} * y}
/// x^y = \frac{1}{w}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2} and {mul}.
/// - Returns `UNIT` for 0^0.
/// - It may not perform well with very small values of x. Consider using SD59x18 as an alternative.
///
/// Requirements:
/// - Refer to the requirements in {exp2}, {log2}, and {mul}.
///
/// @param x The base as a UD60x18 number.
/// @param y The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function pow_1(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();
    uint256 yUint = y.unwrap_5();

    // If both x and y are zero, the result is `UNIT`. If just x is zero, the result is always zero.
    if (xUint == 0) {
        return yUint == 0 ? UNIT_6 : ZERO_1;
    }
    // If x is `UNIT`, the result is always `UNIT`.
    else if (xUint == uUNIT_5) {
        return UNIT_6;
    }

    // If y is zero, the result is always `UNIT`.
    if (yUint == 0) {
        return UNIT_6;
    }
    // If y is `UNIT`, the result is always x.
    else if (yUint == uUNIT_5) {
        return x;
    }

    // If x is > UNIT, use the standard formula.
    if (xUint > uUNIT_5) {
        result = exp2_2(mul_1(log2_1(x), y));
    }
    // Conversely, if x < UNIT, use the equivalent formula.
    else {
        UD60x18 i = wrap_5(uUNIT_SQUARED_1 / xUint);
        UD60x18 w = exp2_2(mul_1(log2_1(i), y));
        result = wrap_5(uUNIT_SQUARED_1 / w.unwrap_5());
    }
}

/// @notice Raises x (a UD60x18 number) to the power y (an unsigned basic integer) using the well-known
/// algorithm "exponentiation by squaring".
///
/// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv18}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - The result must fit in UD60x18.
///
/// @param x The base as a UD60x18 number.
/// @param y The exponent as a uint256.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function powu_1(UD60x18 x, uint256 y) pure returns (UD60x18 result) {
    // Calculate the first iteration of the loop in advance.
    uint256 xUint = x.unwrap_5();
    uint256 resultUint = y & 1 > 0 ? xUint : uUNIT_5;

    // Equivalent to `for(y /= 2; y > 0; y /= 2)`.
    for (y >>= 1; y > 0; y >>= 1) {
        xUint = mulDiv18(xUint, xUint);

        // Equivalent to `y % 2 == 1`.
        if (y & 1 > 0) {
            resultUint = mulDiv18(resultUint, xUint);
        }
    }
    result = wrap_5(resultUint);
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x ≤ MAX_UD60x18 / UNIT
///
/// @param x The UD60x18 number for which to calculate the square root.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function sqrt_2(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap_5();

    unchecked {
        if (xUint > uMAX_UD60x18 / uUNIT_5) {
            revert PRBMath_UD60x18_Sqrt_Overflow(x);
        }
        // Multiply x by `UNIT` to account for the factor of `UNIT` picked up when multiplying two UD60x18 numbers.
        // In this case, the two numbers are both the square root.
        result = wrap_5(sqrt_0(xUint * uUNIT_5));
    }
}

// lib/prb-math/src/sd1x18/ValueType.sol

/// @notice The signed 1.18-decimal fixed-point number representation, which can have up to 1 digit and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int64. This is useful when end users want to use int64 to save gas, e.g. with tight variable packing in contract
/// storage.
type SD1x18 is int64;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_0,
    intoUD60x18_0,
    intoUint128_0,
    intoUint256_0,
    intoUint40_0,
    unwrap_0
} for SD1x18 global;

// lib/prb-math/src/sd21x18/ValueType.sol

/// @notice The signed 21.18-decimal fixed-point number representation, which can have up to 21 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int128. This is useful when end users want to use int128 to save gas, e.g. with tight variable packing in contract
/// storage.
type SD21x18 is int128;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_1,
    intoUD60x18_1,
    intoUint128_1,
    intoUint256_1,
    intoUint40_1,
    unwrap_1
} for SD21x18 global;

// lib/prb-math/src/sd59x18/ValueType.sol

/// @notice The signed 59.18-decimal fixed-point number representation, which can have up to 59 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int256.
type SD59x18 is int256;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoInt256,
    intoSD1x18_0,
    intoSD21x18_0,
    intoUD2x18_0,
    intoUD21x18_0,
    intoUD60x18_2,
    intoUint256_2,
    intoUint128_2,
    intoUint40_2,
    unwrap_2
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {
    abs,
    avg_0,
    ceil_0,
    div_0,
    exp_0,
    exp2_1,
    floor_0,
    frac_0,
    gm_0,
    inv_0,
    log10_0,
    log2_0,
    ln_0,
    mul_0,
    pow_0,
    powu_0,
    sqrt_1
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {
    add_1,
    and_0,
    eq_1,
    gt_0,
    gte_0,
    isZero_0,
    lshift_0,
    lt_0,
    lte_0,
    mod_0,
    neq_1,
    not_0,
    or_0,
    rshift_0,
    sub_1,
    uncheckedAdd_0,
    uncheckedSub_0,
    uncheckedUnary,
    xor_0
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                    OPERATORS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes it possible to use these operators on the SD59x18 type.
using {
    add_1 as +,
    and2_0 as &,
    div_0 as /,
    eq_1 as ==,
    gt_0 as >,
    gte_0 as >=,
    lt_0 as <,
    lte_0 as <=,
    mod_0 as %,
    mul_0 as *,
    neq_1 as !=,
    not_0 as ~,
    or_0 as |,
    sub_1 as -,
    unary as -,
    xor_0 as ^
} for SD59x18 global;

// lib/prb-math/src/ud21x18/ValueType.sol

/// @notice The unsigned 21.18-decimal fixed-point number representation, which can have up to 21 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type uint128. This is useful when end users want to use uint128 to save gas, e.g. with tight variable packing in contract
/// storage.
type UD21x18 is uint128;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_2,
    intoUD60x18_3,
    intoUint128_3,
    intoUint256_3,
    intoUint40_3,
    unwrap_3
} for UD21x18 global;

// lib/prb-math/src/ud2x18/ValueType.sol

/// @notice The unsigned 2.18-decimal fixed-point number representation, which can have up to 2 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type uint64. This is useful when end users want to use uint64 to save gas, e.g. with tight variable packing in contract
/// storage.
type UD2x18 is uint64;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD59x18_3,
    intoUD60x18_4,
    intoUint128_4,
    intoUint256_4,
    intoUint40_4,
    unwrap_4
} for UD2x18 global;

// lib/prb-math/src/ud60x18/ValueType.sol

/// @notice The unsigned 60.18-decimal fixed-point number representation, which can have up to 60 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the Solidity type uint256.
/// @dev The value type is defined here so it can be imported in all other files.
type UD60x18 is uint256;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    intoSD1x18_1,
    intoSD21x18_1,
    intoSD59x18_4,
    intoUD2x18_1,
    intoUD21x18_1,
    intoUint128_5,
    intoUint256_5,
    intoUint40_5,
    unwrap_5
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes the functions in this library callable on the UD60x18 type.
using {
    avg_1,
    ceil_1,
    div_1,
    exp_1,
    exp2_2,
    floor_1,
    frac_1,
    gm_1,
    inv_1,
    ln_1,
    log10_1,
    log2_1,
    mul_1,
    pow_1,
    powu_1,
    sqrt_2
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes the functions in this library callable on the UD60x18 type.
using {
    add_2,
    and_1,
    eq_2,
    gt_1,
    gte_1,
    isZero_1,
    lshift_1,
    lt_1,
    lte_1,
    mod_1,
    neq_2,
    not_1,
    or_1,
    rshift_1,
    sub_2,
    uncheckedAdd_1,
    uncheckedSub_1,
    xor_1
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                    OPERATORS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes it possible to use these operators on the UD60x18 type.
using {
    add_2 as +,
    and2_1 as &,
    div_1 as /,
    eq_2 as ==,
    gt_1 as >,
    gte_1 as >=,
    lt_1 as <,
    lte_1 as <=,
    or_1 as |,
    mod_1 as %,
    mul_1 as *,
    neq_2 as !=,
    not_1 as ~,
    sub_2 as -,
    xor_1 as ^
} for UD60x18 global;

// lib/prb-math/src/sd59x18/Conversions.sol

/// @notice Converts a simple integer to SD59x18 by multiplying it by `UNIT`.
///
/// @dev Requirements:
/// - x ≥ `MIN_SD59x18 / UNIT`
/// - x ≤ `MAX_SD59x18 / UNIT`
///
/// @param x The basic integer to convert.
/// @return result The same number converted to SD59x18.
function convert_0(int256 x) pure returns (SD59x18 result) {
    if (x < uMIN_SD59x18 / uUNIT_2) {
        revert PRBMath_SD59x18_Convert_Underflow(x);
    }
    if (x > uMAX_SD59x18 / uUNIT_2) {
        revert PRBMath_SD59x18_Convert_Overflow(x);
    }
    unchecked {
        result = SD59x18.wrap(x * uUNIT_2);
    }
}

/// @notice Converts an SD59x18 number to a simple integer by dividing it by `UNIT`.
/// @dev The result is rounded toward zero.
/// @param x The SD59x18 number to convert.
/// @return result The same number as a simple integer.
function convert_1(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x) / uUNIT_2;
}

// lib/prb-math/src/ud60x18/Conversions.sol

/// @notice Converts a UD60x18 number to a simple integer by dividing it by `UNIT`.
/// @dev The result is rounded toward zero.
/// @param x The UD60x18 number to convert.
/// @return result The same number in basic integer form.
function convert_2(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x) / uUNIT_5;
}

/// @notice Converts a simple integer to UD60x18 by multiplying it by `UNIT`.
///
/// @dev Requirements:
/// - x ≤ MAX_UD60x18 / UNIT
///
/// @param x The basic integer to convert.
/// @return result The same number converted to UD60x18.
function convert_3(uint256 x) pure returns (UD60x18 result) {
    if (x > uMAX_UD60x18 / uUNIT_5) {
        revert PRBMath_UD60x18_Convert_Overflow(x);
    }
    unchecked {
        result = UD60x18.wrap(x * uUNIT_5);
    }
}

// contracts/libraries/LvAssetLib.sol

/**
 * @dev LvAsset structure for Liquidity Vault Assets
 */
struct LvAsset {
    address _address;
    uint256 locked;
}

/**
 * @title LvAssetLibrary Contract
 * @author Cork Team
 * @notice LvAsset Library which implements features related to Lv(liquidity vault) Asset contract
 */
library LvAssetLibrary {
    using LvAssetLibrary for LvAsset;
    using SafeERC20 for IERC20;

    function initialize(address _address) internal pure returns (LvAsset memory) {
        return LvAsset(_address, 0);
    }

    function asErc20(LvAsset memory self) internal pure returns (IERC20) {
        return IERC20(self._address);
    }

    function isInitialized(LvAsset memory self) internal pure returns (bool) {
        return self._address != address(0);
    }

    function totalIssued(LvAsset memory self) internal view returns (uint256 total) {
        total = IERC20(self._address).totalSupply();
    }

    function issue(LvAsset memory self, address to, uint256 amount) internal {
        Asset(self._address).mint(to, amount);
    }

    function incLocked(LvAsset storage self, uint256 amount) internal {
        self.locked = self.locked + amount;
    }

    function decLocked(LvAsset storage self, uint256 amount) internal {
        self.locked = self.locked - amount;
    }

    function lockFrom(LvAsset storage self, uint256 amount, address from) internal {
        incLocked(self, amount);
        lockUnchecked(self, amount, from);
    }

    function unlockTo(LvAsset storage self, uint256 amount, address to) internal {
        decLocked(self, amount);
        self.asErc20().safeTransfer(to, amount);
    }

    function lockUnchecked(LvAsset storage self, uint256 amount, address from) internal {
        self.asErc20().safeTransferFrom(from, address(this), amount);
    }
}

// lib/prb-math/src/SD59x18.sol

/*

██████╗ ██████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗██╗  ██╗
██╔══██╗██╔══██╗██╔══██╗████╗ ████║██╔══██╗╚══██╔══╝██║  ██║
██████╔╝██████╔╝██████╔╝██╔████╔██║███████║   ██║   ███████║
██╔═══╝ ██╔══██╗██╔══██╗██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
██║     ██║  ██║██████╔╝██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝

███████╗██████╗ ███████╗ █████╗ ██╗  ██╗ ██╗ █████╗
██╔════╝██╔══██╗██╔════╝██╔══██╗╚██╗██╔╝███║██╔══██╗
███████╗██║  ██║███████╗╚██████║ ╚███╔╝ ╚██║╚█████╔╝
╚════██║██║  ██║╚════██║ ╚═══██║ ██╔██╗  ██║██╔══██╗
███████║██████╔╝███████║ █████╔╝██╔╝ ██╗ ██║╚█████╔╝
╚══════╝╚═════╝ ╚══════╝ ╚════╝ ╚═╝  ╚═╝ ╚═╝ ╚════╝

*/

// lib/prb-math/src/UD60x18.sol

/*

██████╗ ██████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗██╗  ██╗
██╔══██╗██╔══██╗██╔══██╗████╗ ████║██╔══██╗╚══██╔══╝██║  ██║
██████╔╝██████╔╝██████╔╝██╔████╔██║███████║   ██║   ███████║
██╔═══╝ ██╔══██╗██╔══██╗██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
██║     ██║  ██║██████╔╝██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝

██╗   ██╗██████╗  ██████╗  ██████╗ ██╗  ██╗ ██╗ █████╗
██║   ██║██╔══██╗██╔════╝ ██╔═████╗╚██╗██╔╝███║██╔══██╗
██║   ██║██║  ██║███████╗ ██║██╔██║ ╚███╔╝ ╚██║╚█████╔╝
██║   ██║██║  ██║██╔═══██╗████╔╝██║ ██╔██╗  ██║██╔══██╗
╚██████╔╝██████╔╝╚██████╔╝╚██████╔╝██╔╝ ██╗ ██║╚█████╔╝
 ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═╝ ╚════╝

*/

// lib/Cork-Hook/src/lib/SwapMath.sol

library SwapMath {
    /// @notice minimum 1-t to not div by 0
    uint256 internal constant MINIMUM_ELAPSED = 1;

    /// @notice amountOut = reserveOut - (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
    /// the fee here is taken from the input token and generally doesn't need to be exposed to the user
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 _1MinT, uint256 baseFee)
        internal
        pure
        returns (uint256 amountOut, uint256 fee)
    {
        (UD60x18 amountOutRaw, UD60x18 feeRaw) =
            _getAmountOut(ud(amountIn), ud(reserveIn), ud(reserveOut), ud(_1MinT), ud(baseFee));

        amountOut = unwrap_5(amountOutRaw);
        fee = unwrap_5(feeRaw);
    }

    function _getAmountOut(UD60x18 amountIn, UD60x18 reserveIn, UD60x18 reserveOut, UD60x18 _1MinT, UD60x18 baseFee)
        internal
        pure
        returns (UD60x18 amountOut, UD60x18 fee)
    {
        // Calculate fee factor = baseFee x t in percentage, we complement _1MinT to get t
        // the end result should be total fee that we must take out
        UD60x18 feeFactor = mul_1(baseFee, sub_2(convert_3(1), _1MinT));
        fee = _calculatePercentage(amountIn, feeFactor);

        // Calculate amountIn after fee = amountIn * feeFactor
        amountIn = sub_2(amountIn, fee);

        UD60x18 reserveInExp = pow_1(reserveIn, _1MinT);
        UD60x18 reserveOutExp = pow_1(reserveOut, _1MinT);

        UD60x18 k = add_2(reserveInExp, reserveOutExp);

        // Calculate q = (k - (reserveIn + amountIn)^(1-t))^1/(1-t)
        UD60x18 q = add_2(reserveIn, amountIn);
        q = pow_1(q, _1MinT);
        q = pow_1(sub_2(k, q), div_1(convert_3(1), _1MinT));

        // Calculate amountOut = reserveOut - q
        amountOut = sub_2(reserveOut, q);
    }

    /// @notice amountIn = (k - (reserveOut - amountOut)^(1-t))^1/(1-t) - reserveIn
    /// the fee here is taken from the input token is already included in amountIn
    /// the fee is generally doesn't need to be exposed to the user since internally it's only used for splitting fees between LPs and the protocol
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 _1MinT, uint256 baseFee)
        internal
        pure
        returns (uint256 amountIn, uint256 fee)
    {
        (UD60x18 amountInRaw, UD60x18 feeRaw) =
            _getAmountIn(ud(amountOut), ud(reserveIn), ud(reserveOut), ud(_1MinT), ud(baseFee));

        amountIn = unwrap_5(amountInRaw);
        fee = unwrap_5(feeRaw);
    }

    function _getAmountIn(UD60x18 amountOut, UD60x18 reserveIn, UD60x18 reserveOut, UD60x18 _1MinT, UD60x18 baseFee)
        internal
        pure
        returns (UD60x18 amountIn, UD60x18 fee)
    {
        UD60x18 reserveInExp = pow_1(reserveIn, _1MinT);

        UD60x18 reserveOutExp = pow_1(reserveOut, _1MinT);

        UD60x18 k = reserveInExp.add_2(reserveOutExp);

        // Calculate q = (reserveOut - amountOut)^(1-t))^1/(1-t)
        UD60x18 q = pow_1(sub_2(reserveOut, amountOut), _1MinT);
        q = pow_1(sub_2(k, q), div_1(convert_3(1), _1MinT));

        // Calculate amountIn = q - reserveIn
        amountIn = sub_2(q, reserveIn);

        // normalize fee factor to 0-1
        UD60x18 feeFactor = div_1(mul_1(baseFee, sub_2(convert_3(1), _1MinT)), convert_3(100));
        feeFactor = sub_2(convert_3(1), feeFactor);

        UD60x18 adjustedAmountIn = div_1(amountIn, feeFactor);

        fee = sub_2(adjustedAmountIn, amountIn);

        assert(add_2(amountIn, fee) == adjustedAmountIn);

        amountIn = adjustedAmountIn;
    }

    function getNormalizedTimeToMaturity(uint256 startTime, uint256 maturityTime, uint256 currentTime)
        internal
        pure
        returns (uint256)
    {
        return unwrap_5(_getNormalizedTimeToMaturity(ud(startTime), ud(maturityTime), ud(currentTime)));
    }

    function _getNormalizedTimeToMaturity(UD60x18 startTime, UD60x18 maturityTime, UD60x18 currentTime)
        internal
        pure
        returns (UD60x18 t)
    {
        UD60x18 elapsedTime = currentTime.sub_2(startTime);
        elapsedTime = elapsedTime == ud(0) ? ud(MINIMUM_ELAPSED) : elapsedTime;
        UD60x18 totalDuration = maturityTime.sub_2(startTime);

        // we return 0 in case it's past maturity time
        if (elapsedTime >= totalDuration) {
            return convert_3(0);
        }

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        t = sub_2(convert_3(1), div_1(elapsedTime, totalDuration));
    }

    /// @notice calculate 1 - t
    function oneMinusT(uint256 startTime, uint256 maturityTime, uint256 currentTime) internal pure returns (uint256) {
        return _oneMinusT(startTime, maturityTime, currentTime);
    }

    function _oneMinusT(uint256 startTime, uint256 maturityTime, uint256 currentTime) internal pure returns (uint256) {
        return unwrap_5(sub_2(convert_3(1), _getNormalizedTimeToMaturity(ud(startTime), ud(maturityTime), ud(currentTime))));
    }

    /// @notice feePercentage =  baseFee x t. where t is normalized time
    function getFeePercentage(uint256 baseFee, uint256 startTime, uint256 maturityTime, uint256 currentTime)
        internal
        pure
        returns (uint256)
    {
        UD60x18 t = _getNormalizedTimeToMaturity(ud(startTime), ud(maturityTime), ud(currentTime));
        return unwrap_5(mul_1(ud(baseFee), t));
    }

    /// @notice calculate percentage of an amount = amount * percentage / 100
    function _calculatePercentage(UD60x18 amount, UD60x18 percentage) internal pure returns (UD60x18 result) {
        result = div_1(mul_1(amount, percentage), convert_3(100));
    }

    function calculatePercentage(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        return unwrap_5(_calculatePercentage(ud(amount), ud(percentage)));
    }

    /// @notice calculate fee = amount * (baseFee x t) / 100
    function getFee(uint256 amount, uint256 baseFee, uint256 startTime, uint256 maturityTime, uint256 currentTime)
        internal
        pure
        returns (uint256)
    {
        uint256 feePercentage = getFeePercentage(baseFee, startTime, maturityTime, currentTime);
        return unwrap_5(_calculatePercentage(ud(feePercentage), ud(amount)));
    }

    /// @notice calculate k = x^(1-t) + y^(1-t)
    function getInvariant(
        uint256 reserve0,
        uint256 reserve1,
        uint256 startTime,
        uint256 maturityTime,
        uint256 currentTime
    ) internal pure returns (uint256 k) {
        uint256 t = oneMinusT(startTime, maturityTime, currentTime);

        // Calculate x^(1-t) and y^(1-t) (x and y are reserveRA and reserveCT)
        UD60x18 xTerm = pow_1(ud(reserve0), ud(t));
        UD60x18 yTerm = pow_1(ud(reserve1), ud(t));

        // Invariant k is x^(1-t) + y^(1-t)
        k = unwrap_5(add_2(xTerm, yTerm));
    }
}

// contracts/libraries/Guard.sol

/**
 * @title Guard Library Contract
 * @author Cork Team
 * @notice Guard library which implements modifiers for DS related features
 */
library Guard {
    using DepegSwapLibrary for DepegSwap;
    using LvAssetLibrary for LvAsset;

    /// @notice asset is expired
    error Expired();

    /// @notice asset is not expired. e.g trying to redeem before expiry
    error NotExpired();

    /// @notice asset is not initialized
    error Uninitialized();

    function _onlyNotExpired(DepegSwap storage ds) internal view {
        if (ds.isExpired()) {
            revert Expired();
        }
    }

    function _onlyExpired(DepegSwap storage ds) internal view {
        if (!ds.isExpired()) {
            revert NotExpired();
        }
    }

    function _onlyInitialized(DepegSwap storage ds) internal view {
        if (!ds.isInitialized()) {
            revert Uninitialized();
        }
    }

    function safeBeforeExpired(DepegSwap storage ds) internal view {
        _onlyInitialized(ds);
        _onlyNotExpired(ds);
    }

    function safeAfterExpired(DepegSwap storage ds) internal view {
        _onlyInitialized(ds);
        _onlyExpired(ds);
    }
}

// contracts/libraries/State.sol

/**
 * @dev State structure
 * @dev as there are some fields that are used in PSM but not in LV
 */
struct State {
    /// @dev used to track current ds and ct for both lv and psm
    uint256 globalAssetIdx;
    Pair info;
    /// @dev dsId => DepegSwap(CT + DS)
    mapping(uint256 => DepegSwap) ds;
    PsmState psm;
    VaultState vault;
}

/**
 * @dev PsmState structure for PSM Core
 */
struct PsmState {
    Balances balances;
    uint256 repurchaseFeePercentage;
    uint256 repurchaseFeeTreasurySplitPercentage;
    BitMaps.BitMap liquiditySeparated;
    /// @dev dsId => PsmPoolArchive
    mapping(uint256 => PsmPoolArchive) poolArchive;
    mapping(address => bool) autoSell;
    bool isDepositPaused;
    bool isWithdrawalPaused;
    bool isRepurchasePaused;
    uint256 psmBaseRedemptionFeePercentage;
    uint256 psmBaseFeeTreasurySplitPercentage;
}

/**
 * @dev PsmPoolArchive structure for PSM Pools
 */
struct PsmPoolArchive {
    uint256 raAccrued;
    uint256 paAccrued;
    uint256 ctAttributed;
    uint256 attributedToRolloverProfit;
    /// @dev user => amount
    mapping(address => uint256) rolloverClaims;
    uint256 rolloverProfit;
}

/**
 * @dev Balances structure for managing balances in PSM Core
 */
struct Balances {
    RedemptionAssetManager ra;
    uint256 dsBalance;
    uint256 paBalance;
    uint256 ctBalance;
}

/**
 * @dev Balances structure for managing balances in PSM Core
 */
struct VaultBalances {
    RedemptionAssetManager ra;
    uint256 ctBalance;
    uint256 lpBalance;
}

/**
 * @dev VaultPool structure for providing pools in Vault(Liquidity Pool)
 */
struct VaultPool {
    VaultWithdrawalPool withdrawalPool;
    VaultAmmLiquidityPool ammLiquidityPool;
    /// @dev user => (dsId => amount)
    mapping(address => uint256) withdrawEligible;
}

/**
 * @dev VaultWithdrawalPool structure for providing withdrawal pools in Vault(Liquidity Pool)
 */
struct VaultWithdrawalPool {
    uint256 atrributedLv;
    uint256 raExchangeRate;
    uint256 paExchangeRate;
    uint256 raBalance;
    uint256 paBalance;
}

/**
 * @dev VaultAmmLiquidityPool structure for providing AMM pools in Vault(Liquidity Pool)
 * This should only be used at the end of each epoch(dsId) lifecyle(e.g at expiry) to pool all RA to be used
 * as liquidity for initiating AMM in the next epoch
 */
struct VaultAmmLiquidityPool {
    uint256 balance;
}

/**
 * @dev VaultState structure for VaultCore
 */
struct VaultState {
    VaultBalances balances;
    VaultConfig config;
    LvAsset lv;
    BitMaps.BitMap lpLiquidated;
    VaultPool pool;
    // will be set to true after first deposit to LV.
    // to prevent manipulative behavior when depositing to Lv since we depend on preview redeem early to get
    // the correct exchange rate of LV
    bool initialized;
    /// @notice the percentage of which the RA that user deposit will be split
    /// e.g 40% means that 40% of the RA that user deposit will be splitted into CT and DS
    /// the CT will be held in the vault while the DS is held in the vault reserve to be selled in the router
    uint256 ctHeldPercetage;
    /// @notice dsId => totalRA. will be updated on every new issuance, so dsId 1 would be update at new issuance of dsId 2
    mapping(uint256 => uint256) totalRaSnapshot;
}

/**
 * @dev VaultConfig structure for VaultConfig Contract
 */
struct VaultConfig {
    bool isDepositPaused;
    bool isWithdrawalPaused;
    NavCircuitBreaker navCircuitBreaker;
}

struct NavCircuitBreaker {
    uint256 snapshot0;
    uint256 lastUpdate0;
    uint256 snapshot1;
    uint256 lastUpdate1;
    uint256 navThreshold;
}

// lib/Cork-Hook/src/lib/LiquidityMath.sol

library LiquidityMath {
    // Adding Liquidity (Pure Function)
    // caller of this contract must ensure the both amount is already proportional in amount!
    function addLiquidity(
        uint256 reserve0, 
        uint256 reserve1, 
        uint256 totalLiquidity, 
        uint256 amount0, 
        uint256 amount1 
    )
        internal
        pure
        returns (
            uint256 newReserve0, 
            uint256 newReserve1, 
            uint256 liquidityMinted 
        )
    {
        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        if (totalLiquidity == 0) {
            // Initial liquidity provision (sqrt of product of amounts added)
            liquidityMinted = unwrap_5(sqrt_2(mul_1(ud(amount0), ud(amount1))));
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = unwrap_5(div_1(mul_1((ud(amount0)), ud(totalLiquidity)), ud(reserve0)));
        }

        // Update reserves
        newReserve0 = unwrap_5(add_2(ud(reserve0), ud(amount0)));
        newReserve1 = unwrap_5(add_2(ud(reserve1), ud(amount1)));

        return (newReserve0, newReserve1, liquidityMinted);
    }

    function getProportionalAmount(uint256 amount0, uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (uint256 amount1)
    {
        return unwrap_5(div_1(mul_1(ud(amount0), ud(reserve1)), ud(reserve0)));
    }

    // uni v2 style proportional add liquidity
    function inferOptimalAmount(
        uint256 reserve0,
        uint256 reserve1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = getProportionalAmount(amount0Desired, reserve0, reserve1);

            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) {
                    revert IErrors_1.Insufficient1Amount();
                }

                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = getProportionalAmount(amount1Desired, reserve1, reserve0);
                if (amount0Optimal < amount0Min || amount0Optimal > amount0Desired) {
                    revert IErrors_1.Insufficient0Amount();
                }
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }

    // Removing Liquidity (Pure Function)
    function removeLiquidity(
        uint256 reserve0, 
        uint256 reserve1, 
        uint256 totalLiquidity, 
        uint256 liquidityAmount 
    )
        internal
        pure
        returns (
            uint256 amount0, 
            uint256 amount1, 
            uint256 newReserve0, 
            uint256 newReserve1 
        )
    {
        if (liquidityAmount <= 0) {
            revert IErrors_1.InvalidAmount();
        }

        if (totalLiquidity <= 0) {
            revert IErrors_1.NotEnoughLiquidity();
        }

        // Calculate the proportion of reserves to return based on the liquidity removed
        amount0 = unwrap_5(div_1(mul_1(ud(liquidityAmount), ud(reserve0)), ud(totalLiquidity)));

        amount1 = unwrap_5(div_1(mul_1(ud(liquidityAmount), ud(reserve1)), ud(totalLiquidity)));

        // Update reserves after removing liquidity
        newReserve0 = unwrap_5(sub_2(ud(reserve0), ud(amount0)));

        newReserve1 = unwrap_5(sub_2(ud(reserve1), ud(amount1)));

        return (amount0, amount1, newReserve0, newReserve1);
    }
}

// lib/Cork-Hook/src/lib/MarketSnapshot.sol

struct MarketSnapshot {
    address ra;
    address ct;
    uint256 reserveRa;
    uint256 reserveCt;
    uint256 oneMinusT;
    uint256 baseFee;
    address liquidityToken;
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 treasuryFeePercentage;
}

library MarketSnapshotLib {
    function getAmountOut(MarketSnapshot memory self, uint256 amountIn, bool raForCt)
        internal
        view
        returns (uint256 amountOut)
    {
        address tokenIn = raForCt ? self.ra : self.ct;

        amountIn = TransferHelper_1.tokenNativeDecimalsToFixed(amountIn, tokenIn);

        amountOut = getAmountOutNoConvert(self, amountIn, raForCt);

        address tokenOut = raForCt ? self.ct : self.ra;
        amountOut = TransferHelper_1.fixedToTokenNativeDecimals(amountOut, self.ct);
    }

    function getAmountOutNoConvert(MarketSnapshot memory self, uint256 amountIn, bool raForCt)
        internal
        view
        returns (uint256 amountOut)
    {
        if (raForCt) {
            (amountOut,) = SwapMath.getAmountOut(amountIn, self.reserveRa, self.reserveCt, self.oneMinusT, self.baseFee);
        } else {
            (amountOut,) = SwapMath.getAmountOut(amountIn, self.reserveCt, self.reserveRa, self.oneMinusT, self.baseFee);
        }
    }

    function getAmountInNoConvert(MarketSnapshot memory self, uint256 amountOut, bool raForCt)
        internal
        view
        returns (uint256 amountIn)
    {
        if (raForCt) {
            (amountIn,) = SwapMath.getAmountIn(amountOut, self.reserveRa, self.reserveCt, self.oneMinusT, self.baseFee);
        } else {
            (amountIn,) = SwapMath.getAmountIn(amountOut, self.reserveCt, self.reserveRa, self.oneMinusT, self.baseFee);
        }
    }

    function getAmountIn(MarketSnapshot memory self, uint256 amountOut, bool raForCt)
        internal
        view
        returns (uint256 amountIn)
    {
        address tokenOut = raForCt ? self.ct : self.ra;
        amountOut = TransferHelper_1.tokenNativeDecimalsToFixed(amountOut, tokenOut);

        amountOut = getAmountInNoConvert(self, amountOut, raForCt);

        address tokenIn = raForCt ? self.ra : self.ct;
        amountIn = TransferHelper_1.fixedToTokenNativeDecimals(amountIn, tokenIn);
    }
}

// contracts/interfaces/UniV4/IMinimalHook.sol

interface ICorkHook_0 is IErrors_0 {
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        returns (uint256 amountIn);
    function addLiquidity(
        address ra,
        address ct,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt, uint256 mintedLp);

    function removeLiquidity(
        address ra,
        address ct,
        uint256 liquidityAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt);

    function getLiquidityToken(address ra, address ct) external view returns (address);

    function getReserves(address ra, address ct) external view returns (uint256, uint256);

    function getFee(address ra, address ct)
        external
        view
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage);

    function getAmountIn(address ra, address ct, bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    function getAmountOut(address ra, address ct, bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function getPoolManager() external view returns (address);

    function getForwarder() external view returns (address);

    function getMarketSnapshot(address ra, address ct) external view returns (MarketSnapshot memory);
}

// contracts/libraries/DsSwapperMathLib.sol

library BuyMathBisectionSolver {
    /// @notice returns the the normalized time to maturity from 1-0
    /// 1 means we're at the start of the period, 0 means we're at the end
    function computeT(SD59x18 start, SD59x18 end, SD59x18 current) public pure returns (SD59x18) {
        SD59x18 minimumElapsed = convert_0(1);

        SD59x18 elapsedTime = sub_1(current, start);
        elapsedTime = elapsedTime == convert_0(0) ? minimumElapsed : elapsedTime;
        SD59x18 totalDuration = sub_1(end, start);

        // we return 0 in case it's past maturity time
        if (elapsedTime >= totalDuration) {
            return convert_0(0);
        }

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        return sub_1(convert_0(1), div_0(elapsedTime, totalDuration));
    }

    function computeOneMinusT(SD59x18 start, SD59x18 end, SD59x18 current) public pure returns (SD59x18) {
        return sub_1(convert_0(1), computeT(start, end, current));
    }

    /// @notice f(s) = x^1-t + y^t - (x - s + e)^1-t - (y + s)^1-t
    function f(SD59x18 x, SD59x18 y, SD59x18 e, SD59x18 s, SD59x18 oneMinusT) public pure returns (SD59x18) {
        SD59x18 xMinSplusE = sub_1(x, s);
        xMinSplusE = add_1(xMinSplusE, e);

        SD59x18 yPlusS = add_1(y, s);

        {
            SD59x18 zero = convert_0(0);

            if (xMinSplusE < zero && yPlusS < zero) {
                revert IErrors_0.InvalidS();
            }
        }

        SD59x18 xPow = _pow(x, oneMinusT);
        SD59x18 yPow = _pow(y, oneMinusT);
        SD59x18 xMinSplusEPow = _pow(xMinSplusE, oneMinusT);
        SD59x18 yPlusSPow = _pow(yPlusS, oneMinusT);

        return sub_1(sub_1(add_1(xPow, yPow), xMinSplusEPow), yPlusSPow);
    }

    // more gas efficient than PRB
    function _pow(SD59x18 x, SD59x18 y) public pure returns (SD59x18) {
        uint256 _x = uint256(unwrap_2(x));
        uint256 _y = uint256(unwrap_2(y));

        return sd(int256(LogExpMath.pow(_x, _y)));
    }

    function findRoot(SD59x18 x, SD59x18 y, SD59x18 e, SD59x18 oneMinusT, SD59x18 epsilon, uint256 maxIter)
        public
        pure
        returns (SD59x18)
    {
        SD59x18 a = sd(0);
        SD59x18 b;

        {
            SD59x18 delta = sd(1e6);
            b = sub_1(add_1(x, e), delta);
        }

        SD59x18 fA = f(x, y, e, a, oneMinusT);
        SD59x18 fB = f(x, y, e, b, oneMinusT);
        {
            if (mul_0(fA, fB) >= sd(0)) {
                uint256 maxAdjustments = 1000;

                SD59x18 adjustment = mul_0(convert_0(-1e4), b);
                for (uint256 i = 0; i < maxAdjustments; ++i) {
                    b = sub_1(b, adjustment);
                    fB = f(x, y, e, b, oneMinusT);

                    if (mul_0(fA, fB) < sd(0)) {
                        break;
                    }
                }

                revert IErrors_0.NoSignChange();
            }
        }

        for (uint256 i = 0; i < maxIter; ++i) {
            SD59x18 c = div_0(add_1(a, b), convert_0(2));
            SD59x18 fC = f(x, y, e, c, oneMinusT);

            if (abs(fC) < epsilon) {
                return c;
            }

            if (mul_0(fA, fC) < sd(0)) {
                b = c;
                fB = fC;
            } else {
                a = c;
                fA = fC;
            }

            if (sub_1(b, a) < epsilon) {
                return div_0(add_1(a, b), convert_0(2));
            }
        }

        revert IErrors_0.NoConverge();
    }
}

/**
 * @title SwapperMathLibrary Contract
 * @author Cork Team
 * @notice SwapperMath library which implements math operations for DS swap contract
 */
library SwapperMathLibrary {
    using MarketSnapshotLib for MarketSnapshot;

    // needed since, if it's expiry and the value goes higher than this,
    // the math would fail, since near expiry it would behave similar to CSM curve,
    int256 internal constant ONE_MINUS_T_CAP = 1e18;

    // Calculate price ratio of two tokens in AMM, will return ratio on 18 decimals precision
    function getPriceRatio(uint256 raReserve, uint256 ctReserve)
        public
        pure
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        if (raReserve <= 0 || ctReserve <= 0) {
            revert IErrors_0.ZeroReserve();
        }

        raPriceRatio = unwrap_5(div_1(ud(ctReserve), ud(raReserve)));
        ctPriceRatio = unwrap_5(div_1(ud(raReserve), ud(ctReserve)));
    }

    // calculate the realized fee of a RA to DS swap
    function calculateDsExtraFee(uint256 amount, uint256 salePercentage, uint256 feePercentage)
        internal
        pure
        returns (uint256 fee)
    {
        fee = calculatePercentage(amount, salePercentage);
        fee = calculatePercentage(fee, feePercentage);
    }

    function getAmountOutBuyDs(
        uint256 x,
        uint256 y,
        uint256 e,
        uint256 start,
        uint256 end,
        uint256 current,
        uint256 epsilon,
        uint256 maxIter
    ) external pure returns (uint256 s) {
        // we don't enforce that x > y, since that means the price of the DS is negative
        // if that happens, then the user would receive the excess RA in form of DS
        // e.g if the excess RA is 10, then the user would receive 10 DS

        SD59x18 oneMinusT = BuyMathBisectionSolver.computeOneMinusT(
            convert_0(int256(start)), convert_0(int256(end)), convert_0(int256(current))
        );

        if (unwrap_2(oneMinusT) >= ONE_MINUS_T_CAP) {
            revert IErrors_0.Expired();
        }

        SD59x18 root;

        try BuyMathBisectionSolver.findRoot(
            convert_0(int256(x)), convert_0(int256(y)), convert_0(int256(e)), oneMinusT, sd(int256(epsilon)), maxIter
        ) returns (SD59x18 result) {
            root = result;
        } catch {
            revert IErrors_0.InvalidPoolStateOrNearExpired();
        }

        return uint256(convert_1(root));
    }

    function calculatePercentage(UD60x18 amount, UD60x18 percentage) internal pure returns (UD60x18 result) {
        result = div_1(mul_1(amount, percentage), convert_3(100));
    }

    function calculatePercentage(uint256 amount, uint256 percentage) internal pure returns (uint256 result) {
        result = unwrap_5(calculatePercentage(ud(amount), ud(percentage)));
    }

    /// @notice HIYA_acc = Ri x Volume_i x 1 - ((Discount / 86400) * (currentTime - issuanceTime))
    function calcHIYAaccumulated(
        uint256 startTime,
        uint256 maturityTime,
        uint256 currentTime,
        uint256 amount,
        uint256 raProvided,
        uint256 decayDiscountInDays
    ) external pure returns (uint256) {
        UD60x18 t = intoUD60x18_2(
            BuyMathBisectionSolver.computeT(
                convert_0(int256(startTime)), convert_0(int256(maturityTime)), convert_0(int256(currentTime))
            )
        );
        UD60x18 effectiveDsPrice = calculateEffectiveDsPrice(ud(amount), ud(raProvided));
        UD60x18 rateI = calcSpotArp(t, effectiveDsPrice);
        UD60x18 decay = calculateDecayDiscount(ud(decayDiscountInDays), ud(startTime), ud(currentTime));

        return unwrap_5(calculatePercentage(calculatePercentage(ud(amount), rateI), decay));
    }

    /// @notice VHIYA_acc =  Volume_i  - ((Discount / 86400) * (currentTime - issuanceTime))
    function calcVHIYAaccumulated(uint256 startTime, uint256 currentTime, uint256 decayDiscountInDays, uint256 amount)
        external
        pure
        returns (uint256)
    {
        UD60x18 decay = calculateDecayDiscount(ud(decayDiscountInDays), ud(startTime), ud(currentTime));

        return convert_2(calculatePercentage(convert_3(amount), decay));
    }

    function calculateEffectiveDsPrice(UD60x18 dsAmount, UD60x18 raProvided)
        internal
        pure
        returns (UD60x18 effectiveDsPrice)
    {
        effectiveDsPrice = div_1(raProvided, dsAmount);
    }

    function calculateHIYA(uint256 cumulatedHIYA, uint256 cumulatedVHIYA) external pure returns (uint256 hiya) {
        // we unwrap here since we want to keep the precision when storing
        hiya = unwrap_5(div_1(convert_3(cumulatedHIYA), convert_3(cumulatedVHIYA)));
    }

    /**
     * decay = 100 - ((Discount / 86400) * (currentTime - issuanceTime))
     * requirements :
     * Discount * (currentTime - issuanceTime) < 100
     */
    function calculateDecayDiscount(UD60x18 decayDiscountInDays, UD60x18 issuanceTime, UD60x18 currentTime)
        internal
        pure
        returns (UD60x18 decay)
    {
        UD60x18 discPerSec = div_1(decayDiscountInDays, convert_3(86400));
        UD60x18 t = sub_2(currentTime, issuanceTime);
        UD60x18 discount = mul_1(discPerSec, t);

        // this must hold true, it doesn't make sense to have a discount above 100%
        assert(discount < convert_3(100));
        decay = sub_2(convert_3(100), discount);
    }

    function _calculateRolloverSale(UD60x18 lvDsReserve, UD60x18 psmDsReserve, UD60x18 raProvided, UD60x18 hpa)
        public
        view
        returns (
            UD60x18 lvProfit,
            UD60x18 psmProfit,
            UD60x18 raLeft,
            UD60x18 dsReceived,
            UD60x18 lvReserveUsed,
            UD60x18 psmReserveUsed
        )
    {
        UD60x18 totalDsReserve = add_2(lvDsReserve, psmDsReserve);

        // calculate the amount of DS user will receive
        dsReceived = div_1(raProvided, hpa);

        // returns the RA if, the total reserve cannot cover the DS that user will receive. this Ra left must subject to the AMM rates
        if (totalDsReserve >= dsReceived) {
            raLeft = convert_3(0); // No shortfall
        } else {
            // Adjust the DS received to match the total reserve
            dsReceived = totalDsReserve;

            // Recalculate raLeft to account for the dust
            raLeft = sub_2(raProvided, mul_1(dsReceived, hpa));
        }

        // recalculate the DS user will receive, after the RA left is deducted
        raProvided = sub_2(raProvided, raLeft);

        // proportionally calculate how much DS should be taken from LV and PSM
        // e.g if LV has 60% of the total reserve, then 60% of the DS should be taken from LV
        lvReserveUsed = div_1(mul_1(lvDsReserve, dsReceived), totalDsReserve);
        psmReserveUsed = sub_2(dsReceived, lvReserveUsed);

        assert(unwrap_5(dsReceived) == unwrap_5(psmReserveUsed + lvReserveUsed));

        if (psmReserveUsed > psmDsReserve) {
            UD60x18 diff = sub_2(psmReserveUsed, psmDsReserve);
            psmReserveUsed = sub_2(psmReserveUsed, diff);
            lvReserveUsed = add_2(lvReserveUsed, diff);
        }

        if (lvReserveUsed > lvDsReserve) {
            UD60x18 diff = sub_2(lvReserveUsed, lvDsReserve);
            lvReserveUsed = sub_2(lvReserveUsed, diff);
            psmReserveUsed = add_2(psmReserveUsed, diff);
        }

        assert(totalDsReserve >= lvReserveUsed + psmReserveUsed);

        // calculate the RA profit of LV and PSM
        lvProfit = mul_1(lvReserveUsed, hpa);
        psmProfit = mul_1(psmReserveUsed, hpa);
    }

    function calculateRolloverSale(uint256 lvDsReserve, uint256 psmDsReserve, uint256 raProvided, uint256 hiya)
        external
        view
        returns (
            uint256 lvProfit,
            uint256 psmProfit,
            uint256 raLeft,
            uint256 dsReceived,
            uint256 lvReserveUsed,
            uint256 psmReserveUsed
        )
    {
        UD60x18 _lvDsReserve = ud(lvDsReserve);
        UD60x18 _psmDsReserve = ud(psmDsReserve);
        UD60x18 _raProvided = ud(raProvided);
        UD60x18 _hpa = sub_2(convert_3(1), calcPtConstFixed(ud(hiya)));

        (
            UD60x18 _lvProfit,
            UD60x18 _psmProfit,
            UD60x18 _raLeft,
            UD60x18 _dsReceived,
            UD60x18 _lvReserveUsed,
            UD60x18 _psmReserveUsed
        ) = _calculateRolloverSale(_lvDsReserve, _psmDsReserve, _raProvided, _hpa);

        lvProfit = unwrap_5(_lvProfit);
        psmProfit = unwrap_5(_psmProfit);
        raLeft = unwrap_5(_raLeft);
        dsReceived = unwrap_5(_dsReceived);
        lvReserveUsed = unwrap_5(_lvReserveUsed);
        psmReserveUsed = unwrap_5(_psmReserveUsed);
    }

    /**
     * @notice  e =  s - (x' - x)
     *          x' - x = (k - (reserveOut - amountOut)^(1-t))^1/(1-t) - reserveIn
     *          x' - x and x should be fetched directly from the hook
     *          x' - x is the same as regular getAmountIn
     * @param xIn the RA we must pay, get it from the hook using getAmountIn
     * @param s Amount DS user want to sell and how much CT we should borrow from the AMM and also the RA we receive from the PSM
     *
     * @return success true if the operation is successful, false otherwise. happen generally if there's insufficient liquidity
     * @return e Amount of RA user will receive
     */
    function getAmountOutSellDs(uint256 xIn, uint256 s) external pure returns (bool success, uint256 e) {
        if (s < xIn) {
            return (false, 0);
        } else {
            e = s - xIn;
            return (true, e);
        }
    }

    /// @notice rT = (f/pT)^1/t - 1
    function calcRt(UD60x18 pT, UD60x18 t) internal pure returns (UD60x18) {
        UD60x18 onePerT = div_1(convert_3(1), t);
        UD60x18 fConst = convert_3(1);

        UD60x18 fPerPt = div_1(fConst, pT);
        UD60x18 fPerPtPow = pow_1(fPerPt, onePerT);

        return sub_2(fPerPtPow, convert_3(1));
    }

    function calcSpotArp(UD60x18 t, UD60x18 effectiveDsPrice) internal pure returns (UD60x18) {
        UD60x18 pt = calcPt(effectiveDsPrice);
        return calcRt(pt, t);
    }

    /// @notice pt = 1 - effectiveDsPrice
    function calcPt(UD60x18 effectiveDsPrice) internal pure returns (UD60x18) {
        return sub_2(convert_3(1), effectiveDsPrice);
    }

    /// @notice ptConstFixed = f / (rate +1)^t
    /// where f = 1, and t = 1
    /// we expect that the rate is in 1e18 precision BEFORE passing it to this function
    function calcPtConstFixed(UD60x18 rate) internal pure returns (UD60x18) {
        UD60x18 ratePlusOne = add_2(convert_3(1), rate);
        return div_1(convert_3(1), ratePlusOne);
    }

    struct OptimalBorrowParams {
        MarketSnapshot market;
        uint256 maxIter;
        uint256 initialAmountOut;
        uint256 initialBorrowedAmount;
        uint256 amountSupplied;
        uint256 feeIntervalAdjustment;
        uint256 feeEpsilon;
    }

    struct OptimalBorrowResult {
        uint256 repaymentAmount;
        uint256 borrowedAmount;
        uint256 amountOut;
    }

    /**
     * @notice binary search to find the optimal borrowed amount
     * lower bound = the initial borrowed amount - (feeIntervalAdjustment * maxIter). if this doesn't satisfy the condition we revert as there's no sane lower bounds
     * upper = the initial borrowed amount.
     */
    function findOptimalBorrowedAmount(OptimalBorrowParams calldata params)
        external
        view
        returns (OptimalBorrowResult memory result)
    {
        UD60x18 amountOutUd = convert_3(params.initialAmountOut);
        UD60x18 initialBorrowedAmountUd = convert_3(params.initialBorrowedAmount);
        UD60x18 suppliedAmountUd = convert_3(params.amountSupplied);

        UD60x18 lowerBound;
        {
            UD60x18 maxLowerBound = convert_3(params.feeIntervalAdjustment * params.maxIter);
            lowerBound =
                maxLowerBound > initialBorrowedAmountUd ? convert_3(0) : sub_2(initialBorrowedAmountUd, maxLowerBound);
        }

        UD60x18 repaymentAmountUd = lowerBound == convert_3(0)
            ? convert_3(0)
            : convert_3(params.market.getAmountInNoConvert(convert_2(lowerBound), false));

        // we skip bounds check if the max lower bound is bigger than the initial borrowed amount
        // since it's guranteed to have enough liquidity if we never borrow
        if (repaymentAmountUd > amountOutUd && lowerBound != convert_3(0)) {
            revert IErrors_0.InvalidPoolStateOrNearExpired();
        }

        UD60x18 upperBound = initialBorrowedAmountUd;
        UD60x18 epsilon = convert_3(params.feeEpsilon);

        for (uint256 i = 0; i < params.maxIter; ++i) {
            // we break if we have reached the desired range
            if (sub_2(upperBound, lowerBound) <= epsilon) {
                break;
            }

            UD60x18 midpoint = div_1(add_2(lowerBound, upperBound), convert_3(2));
            repaymentAmountUd = convert_3(params.market.getAmountInNoConvert(convert_2(midpoint), false));

            amountOutUd = add_2(midpoint, suppliedAmountUd);

            // we re-adjust precision here, to mitigate problems that arise when the RA decimals is less than 18(e.g USDT)
            // the problem occurs when it doesn't have enough precision to represent the actual amount of CT we received
            // from PSM.
            // example would be, we're supposed to pay 3.23 CT to the AMM, but the RA only has enough decimals
            // to represent 3.2. so we deposit 3.2 RA, then we get 3.2 CT. this is less than 3.23 CT we're supposed to pay
            // to circumvent this, we basically "round" the amountOut here on the fly to be accurate to the RA decimals.
            // this will incur a slight gas costs, but it's necessary to ensure the math is correct
            amountOutUd = convert_3(TransferHelper_0.fixedToTokenNativeDecimals(convert_2(amountOutUd), params.market.ra));
            amountOutUd = convert_3(TransferHelper_0.tokenNativeDecimalsToFixed(convert_2(amountOutUd), params.market.ra));

            if (repaymentAmountUd > amountOutUd) {
                upperBound = midpoint;
            } else {
                result.repaymentAmount = convert_2(repaymentAmountUd);
                result.borrowedAmount = convert_2(midpoint);
                result.amountOut = convert_2(amountOutUd);

                lowerBound = midpoint;
            }
        }

        // this means that there's no suitable borrowed amount that satisfies the fee constraints
        if (result.borrowedAmount == 0) {
            revert IErrors_0.InvalidPoolStateOrNearExpired();
        }
    }
}

// contracts/libraries/MathHelper.sol

/**
 * @title MathHelper Library Contract
 * @author Cork Team
 * @notice MathHelper Library which implements Helper functions for Math
 */
library MathHelper {
    /// @dev default decimals for now to calculate price ratio
    uint8 internal constant DEFAULT_DECIMAL = 18;

    // this is used to calculate tolerance level when adding liqudity to AMM pair
    /// @dev 1e18 == 1%.
    uint256 internal constant UNI_STATIC_TOLERANCE = 95e18;

    /**
     * @dev calculate the amount of ra and ct needed to provide AMM with liquidity in respect to the price ratio
     *
     * @param amountra the total amount of liquidity user provide(e.g 2 ra)
     * @param priceRatio the price ratio of the pair, should be retrieved from the AMM as sqrtx96 and be converted to ratio
     * @return ra the amount of ra needed to provide AMM with liquidity
     * @return ct the amount of ct needed to provide AMM with liquidity, also the amount of how much ra should be converted to ct
     */
    function calculateProvideLiquidityAmountBasedOnCtPrice(uint256 amountra, uint256 priceRatio)
        external
        pure
        returns (uint256 ra, uint256 ct)
    {
        UD60x18 _ct = div_1(ud(amountra), ud(priceRatio) + convert_3(1));
        ct = unwrap_5(_ct);
        ra = amountra - ct;
    }

    /**
     * @dev amount = pa x exchangeRate
     * calculate how much DS(need to be provided) and RA(user will receive) in respect to the exchange rate
     * @param pa the amount of pa user provides
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     * @return amount the amount of RA user will receive & DS needs to be provided
     */
    function calculateEqualSwapAmount(uint256 pa, uint256 exchangeRate) external pure returns (uint256 amount) {
        amount = unwrap_5(mul_1(ud(pa), ud(exchangeRate)));
    }

    function calculateProvideLiquidityAmount(uint256 amountRa, uint256 raDeposited) external pure returns (uint256) {
        return amountRa - raDeposited;
    }

    /**
     * @dev calculate the fee in respect to the amount given
     * @param fee1e18 the fee in 1e18
     * @param amount the amount of lv user want to withdraw
     */
    function calculatePercentageFee(uint256 fee1e18, uint256 amount) external pure returns (uint256 percentage) {
        UD60x18 fee = SwapperMathLibrary.calculatePercentage(ud(amount), ud(fee1e18));
        return unwrap_5(fee);
    }

    /**
     * @dev calcualte how much ct + ds user will receive based on the amount of the current exchange rate
     * @param amount  the amount of user  deposit
     * @param exchangeRate the current exchange rate between RA:(CT+DS)
     */
    function calculateDepositAmountWithExchangeRate(uint256 amount, uint256 exchangeRate)
        public
        pure
        returns (uint256)
    {
        UD60x18 _amount = div_1(ud(amount), ud(exchangeRate));
        return unwrap_5(_amount);
    }

    /// @notice calculate the accrued PA & RA
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the PSM.
    ///
    /// amount * (&PA or &RA/#CT)
    function calculateAccrued(uint256 amount, uint256 available, uint256 totalCtIssued)
        internal
        pure
        returns (uint256 accrued)
    {
        UD60x18 _accrued = mul_1(ud(amount), div_1(ud(available), ud(totalCtIssued)));
        return unwrap_5(_accrued);
    }

    function separateLiquidity(uint256 totalAmount, uint256 totalLvIssued, uint256 totalLvWithdrawn)
        external
        pure
        returns (uint256 attributedWithdrawal, uint256 attributedAmm, uint256 ratePerLv)
    {
        // attribute all to AMM if no lv issued or withdrawn
        if (totalLvIssued == 0 || totalLvWithdrawn == 0) {
            return (0, totalAmount, 0);
        }

        // with 1e18 precision
        UD60x18 _ratePerLv = div_1(ud(totalAmount), ud(totalLvIssued));

        UD60x18 _attributedWithdrawal = mul_1(_ratePerLv, ud(totalLvWithdrawn));

        UD60x18 _attributedAmm = sub_2(ud(totalAmount), _attributedWithdrawal);

        attributedWithdrawal = unwrap_5(_attributedWithdrawal);
        attributedAmm = unwrap_5(_attributedAmm);
        ratePerLv = unwrap_5(_ratePerLv);
    }

    function calculateWithTolerance(uint256 ra, uint256 ct, uint256 tolerance)
        external
        pure
        returns (uint256 raTolerance, uint256 ctTolerance)
    {
        UD60x18 _raTolerance = div_1(mul_1(ud(ra), ud(tolerance)), convert_3(100));
        UD60x18 _ctTolerance = div_1(mul_1(ud(ct), ud(tolerance)), convert_3(100));

        return (unwrap_5(_raTolerance), unwrap_5(_ctTolerance));
    }

    function calculateUniLpValue(UD60x18 totalLpSupply, UD60x18 totalRaReserve, UD60x18 totalCtReserve)
        public
        pure
        returns (UD60x18 valueRaPerLp, UD60x18 valueCtPerLp)
    {
        valueRaPerLp = div_1(totalRaReserve, totalLpSupply);
        valueCtPerLp = div_1(totalCtReserve, totalLpSupply);
    }

    function calculateLvValueFromUniLp(
        uint256 totalLpSupply,
        uint256 totalLpOwned,
        uint256 totalRaReserve,
        uint256 totalCtReserve,
        uint256 totalLvIssued
    )
        external
        pure
        returns (
            uint256 raValuePerLv,
            uint256 ctValuePerLv,
            uint256 valueRaPerLp,
            uint256 valueCtPerLp,
            uint256 totalLvRaValue,
            uint256 totalLvCtValue
        )
    {
        UniLpValueParams memory params = UniLpValueParams(
            ud(totalLpSupply), ud(totalLpOwned), ud(totalRaReserve), ud(totalCtReserve), ud(totalLvIssued)
        );

        UniLpValueResult memory result = _calculateLvValueFromUniLp(params);

        raValuePerLv = unwrap_5(result.raValuePerLv);
        ctValuePerLv = unwrap_5(result.ctValuePerLv);
        valueRaPerLp = unwrap_5(result.valueRaPerLp);
        valueCtPerLp = unwrap_5(result.valueCtPerLp);
        totalLvRaValue = unwrap_5(result.totalLvRaValue);
        totalLvCtValue = unwrap_5(result.totalLvCtValue);
    }

    struct UniLpValueParams {
        UD60x18 totalLpSupply;
        UD60x18 totalLpOwned;
        UD60x18 totalRaReserve;
        UD60x18 totalCtReserve;
        UD60x18 totalLvIssued;
    }

    struct UniLpValueResult {
        UD60x18 raValuePerLv;
        UD60x18 ctValuePerLv;
        UD60x18 valueRaPerLp;
        UD60x18 valueCtPerLp;
        UD60x18 totalLvRaValue;
        UD60x18 totalLvCtValue;
    }

    function _calculateLvValueFromUniLp(UniLpValueParams memory params)
        internal
        pure
        returns (UniLpValueResult memory result)
    {
        (result.valueRaPerLp, result.valueCtPerLp) =
            calculateUniLpValue(params.totalLpSupply, params.totalRaReserve, params.totalCtReserve);

        UD60x18 cumulatedLptotalLvOwnedRa = mul_1(params.totalLpOwned, result.valueRaPerLp);
        UD60x18 cumulatedLptotalLvOwnedCt = mul_1(params.totalLpOwned, result.valueCtPerLp);

        result.raValuePerLv = div_1(cumulatedLptotalLvOwnedRa, params.totalLvIssued);
        result.ctValuePerLv = div_1(cumulatedLptotalLvOwnedCt, params.totalLvIssued);

        result.totalLvRaValue = mul_1(result.raValuePerLv, params.totalLvIssued);
        result.totalLvCtValue = mul_1(result.ctValuePerLv, params.totalLvIssued);
    }

    function convertToLp(uint256 rateRaPerLv, uint256 rateRaPerLp, uint256 redeemedLv)
        external
        pure
        returns (uint256 lpLiquidated)
    {
        lpLiquidated = ((redeemedLv * rateRaPerLv) * 1e18) / rateRaPerLp / 1e18;
    }

    struct NavParams {
        uint256 reserveRa;
        uint256 reserveCt;
        uint256 oneMinusT;
        uint256 lpSupply;
        uint256 lvSupply;
        uint256 vaultCt;
        uint256 vaultDs;
        uint256 vaultLp;
        uint256 vaultIdleRa;
    }

    function calculateDepositLv(uint256 nav, uint256 depositAmount, uint256 lvSupply)
        external
        pure
        returns (uint256 lvMinted)
    {
        UD60x18 navPerShare = div_1(ud(nav), ud(lvSupply));

        return unwrap_5(div_1(ud(depositAmount), navPerShare));
    }

    function calculateNav(NavParams calldata params) external pure returns (uint256 nav) {
        (UD60x18 navLp, UD60x18 navCt, UD60x18 navDs, UD60x18 navIdleRas) = calculateNavCombined(params);

        nav = unwrap_5(add_2(navCt, add_2(navDs, navLp)));
        nav = unwrap_5(add_2(ud(nav), navIdleRas));
    }

    struct InternalPrices {
        UD60x18 ctPrice;
        UD60x18 dsPrice;
        UD60x18 raPrice;
    }

    function calculateInternalPrice(NavParams memory params) internal pure returns (InternalPrices memory) {
        UD60x18 t = sub_2(convert_3(1), ud(params.oneMinusT));
        UD60x18 ctPrice = calculatePriceQuote(ud(params.reserveRa), ud(params.reserveCt), t);
        // we set the default ds price to 0 if for some reason the ct price is worth above 1 RA
        // if not, this'll trigger an underflow error
        UD60x18 dsPrice = ctPrice > convert_3(1) ? ud(0) : sub_2(convert_3(1), ctPrice);
        // we're pricing RA in term of itself
        UD60x18 raPrice = convert_3(1);

        return InternalPrices(ctPrice, dsPrice, raPrice);
    }

    function calculateNavCombined(NavParams memory params)
        internal
        pure
        returns (UD60x18 navLp, UD60x18 navCt, UD60x18 navDs, UD60x18 navIdleRa)
    {
        InternalPrices memory prices = calculateInternalPrice(params);

        navCt = calculateNav(prices.ctPrice, ud(params.vaultCt));
        navDs = calculateNav(prices.dsPrice, ud(params.vaultDs));

        UD60x18 raPerLp = div_1(ud(params.reserveRa), ud(params.lpSupply));
        UD60x18 navRaLp = calculateNav(prices.raPrice, mul_1(ud(params.vaultLp), raPerLp));

        UD60x18 ctPerLp = div_1(ud(params.reserveCt), ud(params.lpSupply));
        UD60x18 navCtLp = calculateNav(prices.ctPrice, mul_1(ud(params.vaultLp), ctPerLp));

        navIdleRa = calculateNav(prices.raPrice, ud(params.vaultIdleRa));

        navLp = add_2(navRaLp, navCtLp);
    }

    struct RedeemParams {
        uint256 amountLvClaimed;
        uint256 totalLvIssued;
        uint256 totalVaultLp;
        uint256 totalVaultCt;
        uint256 totalVaultDs;
        uint256 totalVaultPA;
        uint256 totalVaultIdleRa;
    }

    struct RedeemResult {
        uint256 ctReceived;
        uint256 dsReceived;
        uint256 lpLiquidated;
        uint256 paReceived;
        uint256 idleRaReceived;
    }

    function calculateRedeemLv(RedeemParams calldata params) external pure returns (RedeemResult memory result) {
        UD60x18 proportionalClaim = div_1(ud(params.amountLvClaimed), ud(params.totalLvIssued));

        result.ctReceived = unwrap_5(mul_1(proportionalClaim, ud(params.totalVaultCt)));
        result.dsReceived = unwrap_5(mul_1(proportionalClaim, ud(params.totalVaultDs)));
        result.lpLiquidated = unwrap_5(mul_1(proportionalClaim, ud(params.totalVaultLp)));
        result.paReceived = unwrap_5(mul_1(proportionalClaim, ud(params.totalVaultPA)));
        result.idleRaReceived = unwrap_5(mul_1(proportionalClaim, ud(params.totalVaultIdleRa)));
    }

    /// @notice InitialctRatio = f / (rate +1)^t
    /// where f = 1, and t = 1
    /// we expect that the rate is in 1e18 precision BEFORE passing it to this function
    function calculateInitialCtRatio(uint256 _rate) internal pure returns (uint256) {
        UD60x18 rate = convert_3(_rate);
        // normalize to 0-1
        rate = div_1(rate, convert_3(100));

        UD60x18 ratePlusOne = add_2(convert_3(1e18), rate);
        return convert_2(div_1(convert_3(1e36), ratePlusOne));
    }

    function calculateRepurchaseFee(
        uint256 _start,
        uint256 _end,
        uint256 _current,
        uint256 _amount,
        uint256 _baseFeePercentage
    ) internal pure returns (uint256 _fee, uint256 _actualFeePercentage) {
        UD60x18 t = intoUD60x18_2(
            BuyMathBisectionSolver.computeT(
                intoSD59x18_4(convert_3(_start)), intoSD59x18_4(convert_3(_end)), intoSD59x18_4(convert_3(_current))
            )
        );

        UD60x18 feeFactor = mul_1(convert_3(_baseFeePercentage), t);
        // since the amount is already on 18 decimals, we don't need to convert it
        UD60x18 fee = SwapperMathLibrary.calculatePercentage(ud(_amount), feeFactor);

        _actualFeePercentage = convert_2(feeFactor);
        _fee = convert_2(fee);
    }

    /// @notice calculates quote = (reserve0 / reserve1)^t
    function calculatePriceQuote(UD60x18 reserve0, UD60x18 reserve1, UD60x18 t) internal pure returns (UD60x18) {
        return pow_1(div_1(reserve0, reserve1), t);
    }

    function calculateNav(UD60x18 marketValueFromQuote, UD60x18 qty) internal pure returns (UD60x18) {
        return mul_1(marketValueFromQuote, qty);
    }
}

// contracts/libraries/ProtectedUnitMath.sol

library ProtectedUnitMath {
    // caller of this contract must ensure the both amount is already proportional in amount!
    function mint(uint256 reservePa, uint256 totalLiquidity, uint256 amountPa, uint256 amountDs)
        internal
        pure
        returns (uint256 liquidityMinted)
    {
        // Calculate the liquidity tokens minted based on the added amounts and the current reserves
        // we mint 1:1 if total liquidity is 0, also enforce that the amount must be the same
        if (totalLiquidity == 0) {
            if (amountPa != amountDs) {
                revert IErrors_0.InvalidAmount();
            }

            liquidityMinted = amountPa;
        } else {
            // Mint liquidity proportional to the added amounts
            liquidityMinted = unwrap_5(div_1(mul_1((ud(amountPa)), ud(totalLiquidity)), ud(reservePa)));
        }
    }

    function getProportionalAmount(uint256 amount0, uint256 reserve0, uint256 reserve1)
        internal
        pure
        returns (uint256 amount1)
    {
        return unwrap_5(div_1(mul_1(ud(amount0), ud(reserve1)), ud(reserve0)));
    }

    function previewMint(uint256 amount, uint256 paReserve, uint256 dsReserve, uint256 totalLiquidity)
        internal
        pure
        returns (uint256 dsAmount, uint256 paAmount)
    {
        if (totalLiquidity == 0) {
            return (amount, amount);
        }

        dsAmount = unwrap_5(mul_1(ud(amount), div_1(ud(dsReserve), ud(totalLiquidity))));
        paAmount = unwrap_5(mul_1(ud(amount), div_1(ud(paReserve), ud(totalLiquidity))));
    }

    function normalizeDecimals(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter)
        internal
        pure
        returns (uint256)
    {
        return TransferHelper_0.normalizeDecimals(amount, decimalsBefore, decimalsAfter);
    }

    function withdraw(
        uint256 reservePa,
        uint256 reserveDs,
        uint256 reserveRa,
        uint256 totalLiquidity,
        uint256 liquidityAmount
    ) internal pure returns (uint256 amountPa, uint256 amountDs, uint256 amountRa) {
        if (liquidityAmount <= 0) {
            revert IErrors_0.InvalidAmount();
        }

        if (totalLiquidity <= 0) {
            revert IErrors_0.NotEnoughLiquidity();
        }

        // Calculate the proportion of reserves to return based on the liquidity removed
        amountPa = unwrap_5(div_1(mul_1(ud(liquidityAmount), ud(reservePa)), ud(totalLiquidity)));

        amountDs = unwrap_5(div_1(mul_1(ud(liquidityAmount), ud(reserveDs)), ud(totalLiquidity)));

        amountRa = unwrap_5(div_1(mul_1(ud(liquidityAmount), ud(reserveRa)), ud(totalLiquidity)));
    }
}

// contracts/interfaces/IVault.sol

/**
 * @title IVault Interface
 * @author Cork Team
 * @notice IVault interface for VaultCore contract
 */
interface IVault is IErrors_0 {
    struct ProtocolContracts {
        IDsFlashSwapCore flashSwapRouter;
        ICorkHook_0 ammRouter;
        IWithdrawal withdrawalContract;
    }

    struct PermitParams {
        bytes rawLvPermitSig;
        uint256 deadline;
    }

    struct RedeemEarlyParams {
        Id id;
        uint256 amount;
        uint256 amountOutMin;
        uint256 ammDeadline;
        uint256 ctAmountOutMin;
        uint256 dsAmountOutMin;
        uint256 paAmountOutMin;
    }

    struct RedeemEarlyResult {
        Id id;
        address receiver;
        uint256 raReceivedFromAmm;
        uint256 raIdleReceived;
        uint256 paReceived;
        uint256 ctReceivedFromAmm;
        uint256 ctReceivedFromVault;
        uint256 dsReceived;
        bytes32 withdrawalId;
    }

    /// @notice Emitted when a user deposits assets into a given Vault
    /// @param id The Module id that is used to reference both psm and lv of a given pair
    /// @param depositor The address of the depositor
    /// @param received The amount of lv asset received
    /// @param deposited The amount of the asset deposited
    event LvDeposited(Id indexed id, address indexed depositor, uint256 received, uint256 deposited);

    event LvRedeemEarly(
        Id indexed id,
        address indexed redeemer,
        address indexed receiver,
        uint256 lvBurned,
        uint256 ctReceivedFromAmm,
        uint256 ctReceivedFromVault,
        uint256 dsReceived,
        uint256 paReceived,
        uint256 raReceivedFromAmm,
        uint256 raIdleReceived,
        bytes32 withdrawalId
    );

    /// @notice Emitted when the nav circuit breaker reference value is updated
    /// @param snapshotIndex The index of the snapshot that was updated(0 or 1)
    /// @param newValue The new value of the snapshot
    event SnapshotUpdated(uint256 snapshotIndex, uint256 newValue);

    /// @notice Emitted when a Admin updates status of Deposit in the LV
    /// @param id The LV id
    /// @param isLVDepositPaused The new value saying if Deposit allowed in LV or not
    event LvDepositsStatusUpdated(Id indexed id, bool isLVDepositPaused);

    /// @notice Emitted when a Admin updates status of Withdrawal in the LV
    /// @param id The LV id
    /// @param isLVWithdrawalPaused The new value saying if Withdrawal allowed in LV or not
    event LvWithdrawalsStatusUpdated(Id indexed id, bool isLVWithdrawalPaused);

    /// @notice Emitted when the protocol receive sales profit from the router
    /// @param router The address of the router
    /// @param amount The amount of RA tokens transferred.
    event ProfitReceived(address indexed router, uint256 amount);

    event VaultNavThresholdUpdated(Id indexed id, uint256 navThreshold);

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     */
    function depositLv(Id id, uint256 amount, uint256 raTolerance, uint256 ctTolerance)
        external
        returns (uint256 received);

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     * @param permitParams The object with details for permit like rawLvPermitSig(Raw signature for LV approval permit) and deadline for signature
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams, PermitParams memory permitParams)
        external
        returns (RedeemEarlyResult memory result);

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     */
    function redeemEarlyLv(RedeemEarlyParams memory redeemParams) external returns (RedeemEarlyResult memory result);

    /**
     * This will accure value for LV holders by providing liquidity to the AMM using the RA received from selling DS when a users buys DS
     * @param id the id of the pair
     * @param amount the amount of RA received from selling DS
     */
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external;

    /**
     * Returns the amount of AMM LP tokens that the vault holds
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function vaultLp(Id id) external view returns (uint256);

    function lvAcceptRolloverProfit(Id id, uint256 amount) external;

    function updateCtHeldPercentage(Id id, uint256 ctHeldPercentage) external;

    function lvAsset(Id id) external view returns (address lv);

    /**
     * Returns the total RA tokens that the vault at a given time, will be updated on every new issuance.(e.g total ra of dsId of 1 will be updated when Ds with dsId of 2 is issued)
     * Cork's team will use this snapshot value + internal tolerance(likelky would be 0.01%)to determine when the vault should resume deposits
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param dsId The DsId
     */
    function totalRaAt(Id id, uint256 dsId) external view returns (uint256);

    function updateVaultNavThreshold(Id id, uint256 newNavThreshold) external;
}

// contracts/core/ExchangeRateProvider.sol

/**
 * @title ExchangeRateProvider Contract
 * @author Cork Team
 * @notice Contract for managing exchange rate
 */
contract ExchangeRateProvider is IErrors_0, IExchangeRateProvider {
    using PairLibrary for Pair;

    address internal CONFIG;

    mapping(Id => uint256) internal exchangeRate;

    /**
     * @dev checks if caller is config contract or not
     */
    function onlyConfig() internal {
        if (msg.sender != CONFIG) {
            revert IErrors_0.OnlyConfigAllowed();
        }
    }

    constructor(address _config) {
        if (_config == address(0)) {
            revert IErrors_0.ZeroAddress();
        }
        CONFIG = _config;
    }

    function rate() external view returns (uint256) {
        return 0; // For future use
    }

    function rate(Id id) external view returns (uint256) {
        return exchangeRate[id];
    }

    /**
     * @notice updates the exchange rate of the pair
     * @param id the id of the pair
     * @param newRate the exchange rate of the DS, token that are non-rebasing MUST set this to 1e18, and rebasing tokens should set this to the current exchange rate in the market
     */
    function setRate(Id id, uint256 newRate) external {
        onlyConfig();

        exchangeRate[id] = newRate;
    }
}

// lib/Cork-Hook/src/interfaces/ICorkHook.sol

interface ICorkHook_1 is IErrors_1 {
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        returns (uint256 amountIn);

    function addLiquidity(
        address ra,
        address ct,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt, uint256 mintedLp);

    function removeLiquidity(
        address ra,
        address ct,
        uint256 liquidityAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt);

    function getLiquidityToken(address ra, address ct) external view returns (address);

    function getReserves(address ra, address ct) external view returns (uint256, uint256);

    function getFee(address ra, address ct)
        external
        view
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage);

    function getAmountIn(address ra, address ct, bool raForCt, uint256 amountOut)
        external
        view
        returns (uint256 amountIn);

    function getAmountOut(address ra, address ct, bool raForCt, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function getPoolKey(address ra, address ct) external view returns (PoolKey memory);

    function getPoolManager() external view returns (address);

    function getForwarder() external view returns (address);

    function getMarketSnapshot(address ra, address ct) external view returns (MarketSnapshot memory);

    event Swapped(
        address indexed input,
        address output,
        uint256 amountIn,
        uint256 amountOut,
        address who,
        uint256 baseFeePercentage,
        uint256 realizedFeePercentage
    );

    event AddedLiquidity(address indexed ra, address indexed ct, uint256 raAmount, uint256 ctAmount, uint256 mintedLp, address who);

    event RemovedLiquidity(address indexed ra, address indexed ct, uint256 raAmount, uint256 ctAmount, address who);

    event Initialized(address indexed ra, address indexed ct, address liquidityToken);
}

// contracts/libraries/VaultBalancesLib.sol

library VaultBalanceLibrary {
    function subtractLpBalance(State storage self, uint256 amount) internal {
        self.vault.balances.lpBalance -= amount;
    }

    function addLpBalance(State storage self, uint256 amount) internal {
        self.vault.balances.lpBalance += amount;
    }

    function lpBalance(State storage self) internal view returns (uint256) {
        return self.vault.balances.lpBalance;
    }
}

// contracts/libraries/DsFlashSwap.sol

/**
 * @dev AssetPair structure for Asset Pairs
 */
struct AssetPair {
    Asset ra;
    Asset ct;
    Asset ds;
    /// @dev this represent the amount of DS that the LV has in reserve
    /// will be used to fullfill buy DS orders based on the LV DS selling strategy
    // (i.e 50:50 for first expiry, and 80:20 on subsequent expiries. note that it's represented as LV:AMM)
    uint256 lvReserve;
    /// @dev this represent the amount of DS that the PSM has in reserve, used to fill buy pressure on rollover period
    /// and  based on the LV DS selling strategy
    uint256 psmReserve;
}

/**
 * @dev ReserveState structure for Reserve
 */
struct ReserveState {
    /// @dev dsId => [RA, CT, DS]
    mapping(uint256 => AssetPair) ds;
    uint256 reserveSellPressurePercentage;
    uint256 hiyaCumulated;
    uint256 vhiyaCumulated;
    uint256 decayDiscountRateInDays;
    uint256 rolloverEndInBlockNumber;
    uint256 hiya;
    uint256 dsExtraFeePercentage;
    uint256 dsExtraFeeTreasurySplitPercentage;
    bool gradualSaleDisabled;
}

/**
 * @title DsFlashSwaplibrary Contract, this is meant to be deployed as a library and then linked back into the main contract
 * @author Cork Team
 * @notice DsFlashSwap library which implements supporting lib and functions flashswap related features for DS/CT
 */
library DsFlashSwaplibrary {
    using MarketSnapshotLib for MarketSnapshot;

    uint256 public constant FIRST_ISSUANCE = 1;

    function onNewIssuance(ReserveState storage self, uint256 dsId, address ds, address ra, address ct) external {
        self.ds[dsId] = AssetPair(Asset(ra), Asset(ct), Asset(ds), 0, 0);

        // try to calculate implied ARP, if not present then fallback to the default value provided from previous issuance/start
        if (dsId != FIRST_ISSUANCE) {
            try SwapperMathLibrary.calculateHIYA(self.hiyaCumulated, self.vhiyaCumulated) returns (uint256 hiya) {
                self.hiya = hiya;
                // solhint-disable-next-line no-empty-blocks
            } catch {}

            self.hiyaCumulated = 0;
            self.vhiyaCumulated = 0;
        }
    }

    function rolloverSale(ReserveState storage self) external view returns (bool) {
        return block.number <= self.rolloverEndInBlockNumber;
    }

    function updateReserveSellPressurePercentage(ReserveState storage self, uint256 newPercentage) external {
        // must be between 0.01 and 100
        if (newPercentage < 1e16 || newPercentage > 1e20) {
            revert IErrors_0.InvalidParams();
        }

        self.reserveSellPressurePercentage = newPercentage;
    }

    function emptyReserveLv(ReserveState storage self, uint256 dsId, address to) external returns (uint256 emptied) {
        emptied = emptyReservePartialLv(self, dsId, self.ds[dsId].lvReserve, to);
    }

    function getEffectiveHIYA(ReserveState storage self) external view returns (uint256) {
        return self.hiya;
    }

    function getCurrentCumulativeHIYA(ReserveState storage self) external view returns (uint256) {
        try SwapperMathLibrary.calculateHIYA(self.hiyaCumulated, self.vhiyaCumulated) returns (uint256 hiya) {
            return hiya;
        } catch {
            return 0;
        }
    }

    // this function is called for every trade, it recalculates the HIYA and VHIYA for the reserve.
    function recalculateHIYA(ReserveState storage self, uint256 dsId, uint256 ra, uint256 ds) external {
        uint256 start = self.ds[dsId].ds.issuedAt();
        uint256 end = self.ds[dsId].ds.expiry();
        uint256 current = block.timestamp;
        uint256 decayDiscount = self.decayDiscountRateInDays;

        self.hiyaCumulated += SwapperMathLibrary.calcHIYAaccumulated(start, end, current, ds, ra, decayDiscount);
        self.vhiyaCumulated += SwapperMathLibrary.calcVHIYAaccumulated(start, current, decayDiscount, ds);
    }

    function emptyReservePartialLv(ReserveState storage self, uint256 dsId, uint256 amount, address to)
        public
        returns (uint256 emptied)
    {
        self.ds[dsId].lvReserve -= amount;
        self.ds[dsId].ds.transfer(to, amount);
        emptied = amount;
    }

    function emptyReservePsm(ReserveState storage self, uint256 dsId, address to) public returns (uint256 emptied) {
        emptied = emptyReservePartialPsm(self, dsId, self.ds[dsId].psmReserve, to);
    }

    function emptyReservePartialPsm(ReserveState storage self, uint256 dsId, uint256 amount, address to)
        public
        returns (uint256 emptied)
    {
        self.ds[dsId].psmReserve -= amount;
        self.ds[dsId].ds.transfer(to, amount);
        emptied = amount;
    }

    function getPriceRatio(ReserveState storage self, uint256 dsId, ICorkHook_0 router)
        external
        view
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        AssetPair storage asset = self.ds[dsId];

        (uint256 raReserve, uint256 ctReserve) = router.getReserves(address(asset.ra), address(asset.ct));

        raReserve = TransferHelper_0.tokenNativeDecimalsToFixed(raReserve, asset.ra);
        ctReserve = TransferHelper_0.tokenNativeDecimalsToFixed(ctReserve, asset.ct);

        (raPriceRatio, ctPriceRatio) = SwapperMathLibrary.getPriceRatio(raReserve, ctReserve);
    }

    function getReserve(ReserveState storage self, uint256 dsId, ICorkHook_0 router)
        external
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        AssetPair storage asset = self.ds[dsId];

        (raReserve, ctReserve) = router.getReserves(address(asset.ra), address(asset.ct));
    }

    function addReserveLv(ReserveState storage self, uint256 dsId, uint256 amount, address from)
        external
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].lvReserve += amount;
        reserve = self.ds[dsId].lvReserve;
    }

    function addReservePsm(ReserveState storage self, uint256 dsId, uint256 amount, address from)
        external
        returns (uint256 reserve)
    {
        self.ds[dsId].ds.transferFrom(from, address(this), amount);

        self.ds[dsId].psmReserve += amount;
        reserve = self.ds[dsId].psmReserve;
    }

    function getReservesSorted(AssetPair storage self, ICorkHook_0 router)
        public
        view
        returns (uint256 raReserve, uint256 ctReserve)
    {
        (raReserve, ctReserve) = router.getReserves(address(self.ra), address(self.ct));
    }

    function getAmountOutSellDS(AssetPair storage assetPair, uint256 amount, ICorkHook_0 router)
        external
        view
        returns (uint256 amountOut, uint256 repaymentAmount, bool success)
    {
        repaymentAmount = router.getAmountIn(address(assetPair.ra), address(assetPair.ct), true, amount);

        // this is done in 18 decimals precision
        (success, amountOut) = SwapperMathLibrary.getAmountOutSellDs(
            TransferHelper_0.tokenNativeDecimalsToFixed(repaymentAmount, assetPair.ra), amount
        );

        // and then we convert it back to the original token decimals
        amountOut = TransferHelper_0.fixedToTokenNativeDecimals(amountOut, assetPair.ra);
    }

    function getAmountOutBuyDS(
        AssetPair calldata assetPair,
        uint256 amount,
        ICorkHook_0 router,
        IDsFlashSwapCore.BuyAprroxParams memory params
    ) external view returns (uint256 amountOut, uint256 borrowedAmount) {
        MarketSnapshot memory market = router.getMarketSnapshot(address(assetPair.ra), address(assetPair.ct));

        market.reserveRa = TransferHelper_0.tokenNativeDecimalsToFixed(market.reserveRa, assetPair.ra);
        amount = TransferHelper_0.tokenNativeDecimalsToFixed(amount, assetPair.ra);

        uint256 issuedAt = assetPair.ds.issuedAt();
        uint256 end = assetPair.ds.expiry();

        // this expect 18 decimals both sides
        amountOut = _calculateInitialBuyOut(
            InitialTradeCaclParams(market.reserveRa, market.reserveCt, issuedAt, end, amount, params)
        );

        // we subtract some percentage of it to account for dust imprecisions
        amountOut -= SwapperMathLibrary.calculatePercentage(amountOut, params.precisionBufferPercentage);

        borrowedAmount = amountOut - amount;

        SwapperMathLibrary.OptimalBorrowParams memory optimalParams = SwapperMathLibrary.OptimalBorrowParams(
            market,
            params.maxApproxIter,
            amountOut,
            borrowedAmount,
            amount,
            params.feeIntervalAdjustment,
            params.feeEpsilon
        );

        SwapperMathLibrary.OptimalBorrowResult memory result =
            SwapperMathLibrary.findOptimalBorrowedAmount(optimalParams);

        result.borrowedAmount = TransferHelper_0.fixedToTokenNativeDecimals(result.borrowedAmount, assetPair.ra);

        amountOut = result.amountOut;
        borrowedAmount = result.borrowedAmount;
    }

    struct InitialTradeCaclParams {
        uint256 raReserve;
        uint256 ctReserve;
        uint256 issuedAt;
        uint256 end;
        uint256 amount;
        IDsFlashSwapCore.BuyAprroxParams approx;
    }

    function _calculateInitialBuyOut(InitialTradeCaclParams memory params) public view returns (uint256) {
        return SwapperMathLibrary.getAmountOutBuyDs(
            params.raReserve,
            params.ctReserve,
            params.amount,
            params.issuedAt,
            params.end,
            block.timestamp,
            params.approx.epsilon,
            params.approx.maxApproxIter
        );
    }

    function isRAsupportsPermit(address token) external view returns (bool) {
        return PermitChecker.supportsPermit(token);
    }
}

// lib/Cork-Hook/src/lib/State.sol

/// @notice amm id,
type AmmId is bytes32;

function toAmmId_0(address ra, address ct) pure returns (AmmId) {
    (address token0, address token1) = sort_0(ra, ct);

    return AmmId.wrap(keccak256(abi.encodePacked(token0, token1)));
}

function toAmmId_1(Currency _ra, Currency _ct) pure returns (AmmId) {
    (address ra, address ct) = (Currency.unwrap(_ra), Currency.unwrap(_ct));

    return toAmmId_0(ra, ct);
}

struct SortResult {
    address token0;
    address token1;
    uint256 amount0;
    uint256 amount1;
}

function sort_0(address a, address b) pure returns (address, address) {
    return a < b ? (a, b) : (b, a);
}

function reverseSortWithAmount(address a, address b, address token0, address token1, uint256 amount0, uint256 amount1)
    pure
    returns (address, address, uint256, uint256)
{
    if (a == token0 && b == token1) {
        return (token0, token1, amount0, amount1);
    } else if (a == token1 && b == token0) {
        return (token1, token0, amount1, amount0);
    } else {
        revert IErrors_1.InvalidToken();
    }
}

function sort_1(address a, address b, uint256 amountA, uint256 amountB)
    pure
    returns (address, address, uint256, uint256)
{
    return a < b ? (a, b, amountA, amountB) : (b, a, amountB, amountA);
}

function sortPacked_0(address a, address b, uint256 amountA, uint256 amountB) pure returns (SortResult memory) {
    (address token0, address token1, uint256 amount0, uint256 amount1) = sort_1(a, b, amountA, amountB);

    return SortResult(token0, token1, amount0, amount1);
}

function sortPacked_1(address a, address b) pure returns (SortResult memory) {
    (address token0, address token1) = sort_0(a, b);

    return SortResult(token0, token1, 0, 0);
}

/// @notice settle tokens from the pool manager, all numbers are fixed point 18 decimals on the hook
/// so this function is expected to be used on every "settle" action
function settleNormalized(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) {
    amount = TransferHelper_1.fixedToTokenNativeDecimals(amount, Currency.unwrap(currency));
    CurrencySettler.settle(currency, manager, payer, amount, burn);
}

function settle(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) {
    CurrencySettler.settle(currency, manager, payer, amount, burn);
}

/// @notice take tokens from the pool manager, all numbers are fixed point 18 decimals on the hook
/// so this function is expected to be used on every "take" action
function takeNormalized(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) {
    amount = TransferHelper_1.fixedToTokenNativeDecimals(amount, Currency.unwrap(currency));
    CurrencySettler.take(currency, manager, recipient, amount, claims);
}

function take(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) {
    CurrencySettler.take(currency, manager, recipient, amount, claims);
}

function normalize_0(SortResult memory result) view returns (SortResult memory) {
    return SortResult(
        result.token0,
        result.token1,
        TransferHelper_1.tokenNativeDecimalsToFixed(result.amount0, result.token0),
        TransferHelper_1.tokenNativeDecimalsToFixed(result.amount1, result.token1)
    );
}

function normalize_1(address token, uint256 amount) view returns (uint256) {
    return TransferHelper_1.tokenNativeDecimalsToFixed(amount, token);
}

function normalize_2(Currency _token, uint256 amount) view returns (uint256) {
    address token = Currency.unwrap(_token);
    return TransferHelper_1.tokenNativeDecimalsToFixed(amount, token);
}

function toNative_0(Currency _token, uint256 amount) view returns (uint256) {
    address token = Currency.unwrap(_token);
    return TransferHelper_1.fixedToTokenNativeDecimals(amount, token);
}

function toNative_1(address token, uint256 amount) view returns (uint256) {
    return TransferHelper_1.fixedToTokenNativeDecimals(amount, token);
}

/// @notice Pool state
struct PoolState {
    /// @notice reserve of token0, in the native decimals
    uint256 reserve0;
    /// @notice reserve of token1, in the native decimals
    uint256 reserve1;
    address token0;
    address token1;
    // should be deployed using clones
    LiquidityToken liquidityToken;
    // base fee in 18 decimals, 1% is 1e18\
    uint256 fee;
    uint256 startTimestamp;
    uint256 endTimestamp;
    // treasury split percentage in 18 decimals, 1% is 1e18
    // an amoount equal to treasurySplitPercentage * fee will be sent to the treasury
    uint256 treasurySplitPercentage;
}

library PoolStateLibrary {
    uint256 internal constant MAX_FEE = 100e18;

    /// to prevent price manipulation at the start of the pool
    uint256 internal constant MINIMUM_LIQUIDITY = 1e4;

    function ensureLiquidityEnoughAsNative(PoolState storage state, uint256 amountOut, address token) internal view {
        amountOut = TransferHelper_1.fixedToTokenNativeDecimals(amountOut, token);

        if (token == state.token0 && state.reserve0 < amountOut) {
            revert IErrors_1.NotEnoughLiquidity();
        } else if (token == state.token1 && state.reserve1 < amountOut) {
            revert IErrors_1.NotEnoughLiquidity();
        } else {
            return;
        }
    }

    function updateReserves(PoolState storage state, address token, uint256 amount, bool minus) internal {
        if (token == state.token0) {
            state.reserve0 = minus ? state.reserve0 - amount : state.reserve0 + amount;
        } else if (token == state.token1) {
            state.reserve1 = minus ? state.reserve1 - amount : state.reserve1 + amount;
        } else {
            revert IErrors_1.InvalidToken();
        }
    }

    function updateReservesAsNative(PoolState storage state, address token, uint256 amount, bool minus) internal {
        amount = TransferHelper_1.fixedToTokenNativeDecimals(amount, token);
        updateReserves(state, token, amount, minus);
    }

    function updateFee(PoolState storage state, uint256 fee) internal {
        if (fee >= MAX_FEE) {
            revert IErrors_1.InvalidFee();
        }

        state.fee = fee;
    }

    function getToken0(PoolState storage state) internal view returns (Currency) {
        return Currency.wrap(state.token0);
    }

    function getToken1(PoolState storage state) internal view returns (Currency) {
        return Currency.wrap(state.token1);
    }

    function initialize(PoolState storage state, address _token0, address _token1, address _liquidityToken) internal {
        state.token0 = _token0;
        state.token1 = _token1;
        state.liquidityToken = LiquidityToken(_liquidityToken);
    }

    function isInitialized(PoolState storage state) internal view returns (bool) {
        return state.token0 != address(0);
    }

    function tryAddLiquidity(
        PoolState storage state,
        uint256 amount0,
        uint256 amount1,
        uint256 amount0min,
        uint256 amount1min
    )
        internal
        returns (uint256 reserve0, uint256 reserve1, uint256 mintedLp, uint256 amount0Used, uint256 amount1Used)
    {
        reserve0 = TransferHelper_1.tokenNativeDecimalsToFixed(state.reserve0, state.token0);
        reserve1 = TransferHelper_1.tokenNativeDecimalsToFixed(state.reserve1, state.token1);

        (amount0Used, amount1Used) =
            LiquidityMath.inferOptimalAmount(reserve0, reserve1, amount0, amount1, amount0min, amount1min);

        (reserve0, reserve1, mintedLp) =
            LiquidityMath.addLiquidity(reserve0, reserve1, state.liquidityToken.totalSupply(), amount0, amount1);

        reserve0 = TransferHelper_1.fixedToTokenNativeDecimals(reserve0, state.token0);
        reserve1 = TransferHelper_1.fixedToTokenNativeDecimals(reserve1, state.token1);

        // we lock minimum liquidity to prevent price manipulation at the start of the pool
        if (state.reserve0 == 0 && state.reserve1 == 0) {
            mintedLp -= MINIMUM_LIQUIDITY;
        }
    }

    function addLiquidity(
        PoolState storage state,
        uint256 amount0,
        uint256 amount1,
        address sender,
        uint256 amount0min,
        uint256 amount1min
    )
        internal
        returns (uint256 reserve0, uint256 reserve1, uint256 mintedLp, uint256 amount0Used, uint256 amount1Used)
    {
        (reserve0, reserve1, mintedLp, amount0Used, amount1Used) =
            tryAddLiquidity(state, amount0, amount1, amount0min, amount1min);

        // we lock minimum liquidity to prevent price manipulation at the start of the pool
        if (state.reserve0 == 0 && state.reserve1 == 0) {
            state.liquidityToken.mint(address(0xd3ad), MINIMUM_LIQUIDITY);
        }

        state.reserve0 = reserve0;
        state.reserve1 = reserve1;
        state.liquidityToken.mint(sender, mintedLp);
    }

    function tryRemoveLiquidity(PoolState storage state, uint256 liquidityAmount)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1)
    {
        (amount0, amount1, reserve0, reserve1) = LiquidityMath.removeLiquidity(
            state.reserve0, state.reserve1, state.liquidityToken.totalSupply(), liquidityAmount
        );
    }

    function removeLiquidity(PoolState storage state, uint256 liquidityAmount, address sender)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 reserve0, uint256 reserve1)
    {
        (amount0, amount1, reserve0, reserve1) = tryRemoveLiquidity(state, liquidityAmount);

        state.reserve0 = reserve0;
        state.reserve1 = reserve1;
        state.liquidityToken.burnFrom(sender, liquidityAmount);
    }
}

// contracts/libraries/VaultPoolLib.sol

/**
 * @title VaultPool Library Contract
 * @author Cork Team
 * @notice VaultPool Library implements features related to LV Pools(liquidity Vault Pools)
 */
library VaultPoolLibrary {
    function reserve(VaultPool storage self, uint256 totalLvIssued, uint256 addedRa, uint256 addedPa) internal {
        // new protocol amendement, no need to reserve for lv
        uint256 totalLvWithdrawn = 0;

        // RA
        uint256 totalRa = self.withdrawalPool.raBalance + addedRa;
        (, uint256 attributedToAmm, uint256 ratePerLv) =
            MathHelper.separateLiquidity(totalRa, totalLvIssued, totalLvWithdrawn);

        self.ammLiquidityPool.balance = attributedToAmm;
        self.withdrawalPool.raExchangeRate = ratePerLv;

        // PA
        uint256 totalPa = self.withdrawalPool.paBalance + addedPa;
        (, attributedToAmm, ratePerLv) = MathHelper.separateLiquidity(totalPa, totalLvIssued, 0);

        self.withdrawalPool.paBalance = attributedToAmm;
        self.withdrawalPool.paExchangeRate = ratePerLv;

        assert(totalRa == self.withdrawalPool.raBalance + self.ammLiquidityPool.balance);
    }

    function rationedToAmm(VaultPool storage self, uint256 ratio)
        internal
        view
        returns (uint256 ra, uint256 ct, uint256 originalBalance)
    {
        originalBalance = self.ammLiquidityPool.balance;

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(originalBalance, ratio);
    }

    function resetAmmPool(VaultPool storage self) internal {
        self.ammLiquidityPool.balance = 0;
    }
}

// lib/Cork-Hook/src/Forwarder.sol

/// @title PoolInitializer
/// workaround contract to auto initialize pool & swap when adding liquidity since uni v4 doesn't support self calling from hook
contract HookForwarder is Ownable, CorkSwapCallback, IErrors_1 {
    using CurrencyLibrary for Currency;

    IPoolManager internal immutable poolManager;

    constructor(IPoolManager _poolManager) Ownable(msg.sender) {
        poolManager = _poolManager;
    }

    modifier clearSenderAfter() {
        _;
        SenderSlot.clear();
    }

    function initializePool(address token0, address token1) external onlyOwner {
        PoolKey memory key = PoolKey(
            Currency.wrap(address(token0)),
            Currency.wrap(address(token1)),
            Constants.FEE,
            Constants.TICK_SPACING,
            IHooks(owner())
        );

        poolManager.initialize(key, Constants.SQRT_PRICE_1_1);
    }

    function swap(SwapParams calldata params) external onlyOwner {
        SenderSlot.set(params.sender);
        poolManager.swap(params.poolKey, params.params, params.swapData);
    }

    /// @notice actually transfer token to user, this is needed in case of when user directly swap using hook
    /// the logic is inside the hook, but here it act on behalf of the user by settling the swap and transferring the token to the user
    /// should only be called after swap or before executing callback and MUST be called only once throughout the entire swap lifecycle
    function forwardToken(Currency _in, Currency out, uint256 amountIn, uint256 amountOut)
        external
        onlyOwner
        clearSenderAfter
    {
        // get sender from slot
        address to = SenderSlot.get();

        if (to == address(0)) {
            revert IErrors_1.NoSender();
        }

        takeNormalized(out, poolManager, to, amountOut, false);
        settleNormalized(_in, poolManager, address(this), amountIn, false);
    }

    function getCurrentSender() external view returns (address) {
        return SenderSlot.get();
    }

    /// @notice forward token without clearing the sender, MUST only be called before executing flash swap callback and ONLY ONCE in the entire swap lifecycle
    /// this is needed in case of when user directly swap using hook
    function forwardTokenUncheked(Currency out, uint256 amountOut) external onlyOwner {
        address sender = SenderSlot.get();

        if (sender == address(0)) {
            revert IErrors_1.NoSender();
        }

        takeNormalized(out, poolManager, sender, amountOut, false);
    }

    /// @notice we're just forwarding the call to the callback contract
    function CorkCall(address sender, bytes calldata data, uint256 paymentAmount, address paymentToken, address pm)
        external
        onlyOwner
        clearSenderAfter
    {
        if (sender != address(this)) {
            revert IErrors_1.OnlySelfCall();
        }

        // we set the sender to the original sender.
        sender = SenderSlot.get();

        if (sender == address(0)) {
            revert IErrors_1.NoSender();
        }

        poolManager.sync(Currency.wrap(paymentToken));

        CorkSwapCallback(sender).CorkCall(sender, data, paymentAmount, paymentToken, pm);

        poolManager.settle();
    }
}

// contracts/libraries/NavCircuitBreaker.sol

library NavCircuitBreakerLibrary {
    function _oldestSnapshotIndex(NavCircuitBreaker storage self) private view returns (uint256) {
        return self.lastUpdate0 <= self.lastUpdate1 ? 0 : 1;
    }

    function _updateSnapshot(NavCircuitBreaker storage self, uint256 currentNav) internal returns (bool) {
        uint256 oldestIndex = _oldestSnapshotIndex(self);

        if (oldestIndex == 0) {
            if (block.timestamp < self.lastUpdate0 + 1 days) return false;

            self.snapshot0 = currentNav;
            self.lastUpdate0 = block.timestamp;

            emit IVault.SnapshotUpdated(oldestIndex, currentNav);
        } else {
            if (block.timestamp < self.lastUpdate1 + 1 days) return false;

            self.snapshot1 = currentNav;
            self.lastUpdate1 = block.timestamp;

            emit IVault.SnapshotUpdated(oldestIndex, currentNav);
        }

        return true;
    }

    function _getReferenceNav(NavCircuitBreaker storage self) private view returns (uint256) {
        return self.snapshot0 > self.snapshot1 ? self.snapshot0 : self.snapshot1;
    }

    function validateAndUpdateDeposit(NavCircuitBreaker storage self, uint256 currentNav) internal {
        _updateSnapshot(self, currentNav);
        uint256 referenceNav = _getReferenceNav(self);
        uint256 delta = MathHelper.calculatePercentageFee(self.navThreshold, referenceNav);

        if (currentNav < delta) {
            revert IErrors_0.NavBelowThreshold(referenceNav, delta, currentNav);
        }
    }

    function updateOnWithdrawal(NavCircuitBreaker storage self, uint256 currentNav) internal returns (bool) {
        return _updateSnapshot(self, currentNav);
    }

    function forceUpdateSnapshot(NavCircuitBreaker storage self, uint256 currentNav) internal returns (bool) {
        return _updateSnapshot(self, currentNav);
    }
}

// contracts/libraries/PsmLib.sol

/**
 * @title Psm Library Contract
 * @author Cork Team
 * @notice Psm Library implements functions for PSM Core contract
 */
library PsmLibrary {
    using MinimalSignatureHelper for Signature;
    using PairLibrary for Pair;
    using DepegSwapLibrary for DepegSwap;
    using RedemptionAssetManagerLibrary for RedemptionAssetManager;
    using PeggedAssetLibrary for PeggedAsset;
    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;

    /**
     *   This denotes maximum fee allowed in contract
     *   Here 1 ether = 1e18 so maximum 5% fee allowed
     */
    uint256 internal constant MAX_ALLOWED_FEES = 5 ether;

    /// @notice inssuficient balance to perform rollover redeem(e.g having 5 CT worth of rollover to redeem but trying to redeem 10)
    error InsufficientRolloverBalance(address caller, uint256 requested, uint256 balance);

    /// @notice thrown when trying to rollover while no active issuance
    error NoActiveIssuance();

    function isInitialized(State storage self) external view returns (bool status) {
        status = self.info.isInitialized();
    }

    function _getLatestRate(State storage self) internal view returns (uint256 rate) {
        Id id = self.info.toId();

        uint256 exchangeRates = IExchangeRateProvider(self.info.exchangeRateProvider).rate();

        if (exchangeRates == 0) {
            exchangeRates = IExchangeRateProvider(self.info.exchangeRateProvider).rate(id);
        }

        return exchangeRates;
    }

    function _getLatestApplicableRate(State storage self) internal view returns (uint256 rate) {
        uint256 externalExchangeRates = _getLatestRate(self);
        uint256 currentExchangeRates = Asset(self.ds[self.globalAssetIdx]._address).exchangeRate();

        // return the lower of the two
        return externalExchangeRates < currentExchangeRates ? externalExchangeRates : currentExchangeRates;
    }

    // fetch and update the exchange rate. will return the lowest rate
    function _getLatestApplicableRateAndUpdate(State storage self) internal returns (uint256 rate) {
        rate = _getLatestApplicableRate(self);
        self.ds[self.globalAssetIdx].updateExchangeRate(rate);
    }

    function initialize(State storage self, Pair calldata key) external {
        self.info = key;
        self.psm.balances.ra = RedemptionAssetManagerLibrary.initialize(key.redemptionAsset());
    }

    function updateAutoSell(State storage self, address user, bool status) external {
        self.psm.autoSell[user] = status;
    }

    function autoSellStatus(State storage self, address user) external view returns (bool status) {
        return self.psm.autoSell[user];
    }

    function acceptRolloverProfit(State storage self, uint256 amount) external {
        self.psm.poolArchive[self.globalAssetIdx].rolloverProfit += amount;
    }

    function rolloverExpiredCt(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        IDsFlashSwapCore flashSwapRouter,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived) {
        if (rawCtPermitSig.length > 0 && ctDeadline != 0) {
            DepegSwapLibrary.permit(
                self.ds[dsId].ct, rawCtPermitSig, owner, address(this), amount, ctDeadline, "rolloverExpiredCt"
            );
        }

        (ctReceived, dsReceived, paReceived) = _rolloverExpiredCt(self, owner, amount, dsId, flashSwapRouter);
    }

    function claimAutoSellProfit(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        address owner,
        uint256 dsId,
        uint256 amount
    ) external returns (uint256 profit, uint256 remainingDsReceived) {
        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        (profit, remainingDsReceived) =
            _claimAutoSellProfit(self, self.psm.poolArchive[dsId], flashSwapRouter, owner, amount, dsId);
    }
    // 1. check how much expirec CT does use have
    // 2. calculate how much backed RA and PA the user can redeem
    // 3. mint new CT and DS equal to backed RA user has
    // 4. send DS to flashswap router if user opt-in for auto sell or send to user if not
    // 5. send CT to user
    // 6. send RA to user if they don't opt-in for auto sell
    // 7. send PA to user
    // regardless of amount, it will always send user all the profit from rollover

    function _rolloverExpiredCt(
        State storage self,
        address owner,
        uint256 amount,
        uint256 prevDsId,
        IDsFlashSwapCore flashSwapRouter
    ) internal returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived) {
        if (prevDsId == self.globalAssetIdx) {
            revert NoActiveIssuance();
        }

        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        // claim logic
        PsmPoolArchive storage prevArchive;

        uint256 accruedRa;
        // avoid stack too deep error
        (prevArchive, accruedRa, paReceived) = _claimCtForRollover(self, prevDsId, amount, owner);

        // deposit logic
        DepegSwap storage currentDs = self.ds[self.globalAssetIdx];
        Guard.safeBeforeExpired(currentDs);

        // by default the amount of CT received is the same as the amount of RA deposited
        // we convert it to 18 fixed decimals, since that's what the DS uses
        ctReceived = TransferHelper_0.tokenNativeDecimalsToFixed(accruedRa, self.info.ra);

        // by default the amount of DS received is the same as CT
        dsReceived = ctReceived;

        // increase current ds active RA balance locked
        self.psm.balances.ra.incLocked(accruedRa);

        // increase rollover claims if user opt-in for auto sell, avoid stack too deep error
        dsReceived = _incRolloverClaims(self, ctReceived, owner, dsReceived);
        // end deposit logic

        // send, burn tokens and mint new ones
        _afterRollover(self, currentDs, owner, ctReceived, paReceived, flashSwapRouter);
    }

    function _incRolloverClaims(State storage self, uint256 ctDsReceived, address owner, uint256 dsReceived)
        internal
        returns (uint256)
    {
        if (self.psm.autoSell[owner]) {
            PsmPoolArchive storage currentArchive = self.psm.poolArchive[self.globalAssetIdx];
            currentArchive.attributedToRolloverProfit += ctDsReceived;
            currentArchive.rolloverClaims[owner] += ctDsReceived;
            // we return 0 since the user opt-in for auto sell
            return 0;
        } else {
            return dsReceived;
        }
    }

    function _claimCtForRollover(State storage self, uint256 prevDsId, uint256 amount, address owner)
        private
        returns (PsmPoolArchive storage prevArchive, uint256 accruedRa, uint256 accruedPa)
    {
        DepegSwap storage prevDs = self.ds[prevDsId];
        Guard.safeAfterExpired(prevDs);

        if (Asset(prevDs.ct).balanceOf(owner) < amount) {
            revert InsufficientRolloverBalance(owner, amount, Asset(prevDs.ct).balanceOf(owner));
        }

        // separate liquidity first so that we can properly calculate the attributed amount
        _separateLiquidity(self, prevDsId);
        uint256 totalCtIssued = self.psm.poolArchive[prevDsId].ctAttributed;
        prevArchive = self.psm.poolArchive[prevDsId];

        // caclulate accrued RA and PA proportional to CT amount
        (accruedPa, accruedRa) =
            _calcRedeemAmount(self, amount, totalCtIssued, prevArchive.raAccrued, prevArchive.paAccrued);
        // accounting stuff(decrementing reserve etc)
        _beforeCtRedeem(self, prevDs, prevDsId, amount, accruedPa, accruedRa);

        // burn previous CT
        // this would normally go on the end of the the overall logic but needed here to avoid stack to deep error
        ERC20Burnable(prevDs.ct).burnFrom(owner, amount);
    }

    function _claimAutoSellProfit(
        State storage self,
        PsmPoolArchive storage prevArchive,
        IDsFlashSwapCore flashswapRouter,
        address owner,
        uint256 amount,
        uint256 prevDsId
    ) private returns (uint256 rolloverProfit, uint256 remainingRolloverDs) {
        if (prevArchive.rolloverClaims[owner] < amount) {
            revert InsufficientRolloverBalance(owner, amount, prevArchive.rolloverClaims[owner]);
        }

        remainingRolloverDs = MathHelper.calculateAccrued(
            amount, flashswapRouter.getPsmReserve(self.info.toId(), prevDsId), prevArchive.attributedToRolloverProfit
        );

        if (remainingRolloverDs != 0) {
            flashswapRouter.emptyReservePartialPsm(self.info.toId(), prevDsId, remainingRolloverDs);
        }

        // calculate their share of profit
        rolloverProfit = MathHelper.calculateAccrued(
            amount,
            TransferHelper_0.tokenNativeDecimalsToFixed(prevArchive.rolloverProfit, self.info.ra),
            prevArchive.attributedToRolloverProfit
        );
        rolloverProfit = TransferHelper_0.fixedToTokenNativeDecimals(rolloverProfit, self.info.ra);

        // reset their claim
        prevArchive.rolloverClaims[owner] -= amount;
        // decrement total profit
        prevArchive.rolloverProfit -= rolloverProfit;
        // decrement total ct attributed to rollover
        prevArchive.attributedToRolloverProfit -= amount;

        IERC20(self.info.redemptionAsset()).safeTransfer(owner, rolloverProfit);

        if (remainingRolloverDs != 0) {
            // mint DS to user
            IERC20(self.ds[prevDsId]._address).safeTransfer(owner, remainingRolloverDs);
        }
    }

    function _afterRollover(
        State storage self,
        DepegSwap storage currentDs,
        address owner,
        uint256 ctDsReceived,
        uint256 accruedPa,
        IDsFlashSwapCore flashSwapRouter
    ) private {
        if (self.psm.autoSell[owner]) {
            // send DS to flashswap router if auto sellf
            Asset(currentDs._address).mint(address(this), ctDsReceived);
            IERC20(currentDs._address).safeIncreaseAllowance(address(flashSwapRouter), ctDsReceived);

            flashSwapRouter.addReservePsm(self.info.toId(), self.globalAssetIdx, ctDsReceived);
        } else {
            // mint DS to user
            Asset(currentDs._address).mint(owner, ctDsReceived);
        }

        // mint new CT to user
        Asset(currentDs.ct).mint(owner, ctDsReceived);
        // transfer accrued PA to user
        self.info.peggedAsset().asErc20().safeTransfer(owner, accruedPa);
    }

    /// @notice issue a new pair of DS, will fail if the previous DS isn't yet expired
    function onNewIssuance(State storage self, address ct, address ds, uint256 idx, uint256 prevIdx) internal {
        if (prevIdx != 0) {
            DepegSwap storage _prevDs = self.ds[prevIdx];
            Guard.safeAfterExpired(_prevDs);
            _separateLiquidity(self, prevIdx);
        }

        // essentially burn unpurchased ds as we're going in with a new issuance
        self.psm.balances.dsBalance = 0;

        self.ds[idx] = DepegSwapLibrary.initialize(ds, ct);
    }

    function _separateLiquidity(State storage self, uint256 prevIdx) internal {
        if (self.psm.liquiditySeparated.get(prevIdx)) {
            return;
        }

        DepegSwap storage ds = self.ds[prevIdx];
        Guard.safeAfterExpired(ds);

        PsmPoolArchive storage archive = self.psm.poolArchive[prevIdx];

        uint256 availableRa = self.psm.balances.ra.convertAllToFree();
        uint256 availablePa = self.psm.balances.paBalance;

        archive.paAccrued = availablePa;
        archive.raAccrued = availableRa;
        archive.ctAttributed = IERC20(ds.ct).totalSupply();

        // reset current balances
        self.psm.balances.ra.reset();
        self.psm.balances.paBalance = 0;

        self.psm.liquiditySeparated.set(prevIdx);
    }

    /// @notice deposit RA to the PSM
    /// @dev the user must approve the PSM to spend their RA
    function deposit(State storage self, address depositor, uint256 amount)
        external
        returns (uint256 dsId, uint256 received, uint256 _exchangeRate)
    {
        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        dsId = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
        _exchangeRate = _getLatestApplicableRateAndUpdate(self);

        // we convert it 18 fixed decimals, since that's what the DS uses
        received = TransferHelper_0.tokenNativeDecimalsToFixed(amount, self.info.ra);

        self.psm.balances.ra.lockFrom(amount, depositor);

        ds.issue(depositor, received);
    }

    // This is here just for semantics, since in the whitepaper, all the CT DS issuance
    // happens in the PSM, although they essentially lives in the same contract, we leave it here just for consistency sake
    //
    // IMPORTANT: this is unsafe because by issuing CT, we also lock an equal amount of RA into the PSM.
    // it is a must, that the LV won't count the amount being locked in the PSM as it's balances.
    // doing so would create a mismatch between the accounting balance and the actual token balance.
    function unsafeIssueToLv(State storage self, uint256 amount) internal returns (uint256 received) {
        uint256 dsId = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[dsId];

        self.psm.balances.ra.incLocked(amount);

        // we convert it 18 fixed decimals, since that's what the DS uses
        received = TransferHelper_0.tokenNativeDecimalsToFixed(amount, self.info.ra);

        ds.issue(address(this), received);
    }

    function lvRedeemRaPaWithCt(State storage self, uint256 amount, uint256 dsId)
        internal
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        // we separate the liquidity here, that means, LP liquidation on the LV also triggers
        _separateLiquidity(self, dsId);

        // noop if amount is 0
        if (amount == 0) {
            return (0, 0);
        }

        uint256 totalCtIssued = self.psm.poolArchive[dsId].ctAttributed;
        PsmPoolArchive storage archive = self.psm.poolArchive[dsId];

        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount, totalCtIssued, archive.raAccrued, archive.paAccrued);

        _beforeCtRedeem(self, self.ds[dsId], dsId, amount, accruedPa, accruedRa);

        self.ds[dsId].burnCtSelf(amount);
    }

    function _returnRaWithCtDs(State storage self, DepegSwap storage ds, address owner, uint256 amount)
        internal
        returns (uint256 ra)
    {
        ra = TransferHelper_0.fixedToTokenNativeDecimals(amount, self.info.ra);

        self.psm.balances.ra.unlockTo(owner, ra);

        ERC20Burnable(ds.ct).burnFrom(owner, amount);
        ERC20Burnable(ds._address).burnFrom(owner, amount);
    }

    function returnRaWithCtDs(
        State storage self,
        address owner,
        uint256 amount,
        bytes calldata rawDsPermitSig,
        uint256 dsDeadline,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ra) {
        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        if (dsDeadline != 0 && ctDeadline != 0) {
            DepegSwapLibrary.permit(
                ds._address, rawDsPermitSig, owner, address(this), amount, dsDeadline, "returnRaWithCtDs"
            );
            DepegSwapLibrary.permit(ds.ct, rawCtPermitSig, owner, address(this), amount, ctDeadline, "returnRaWithCtDs");
        }

        ra = _returnRaWithCtDs(self, ds, owner, amount);
    }

    function availableForRepurchase(State storage self) external view returns (uint256 pa, uint256 ds, uint256 dsId) {
        dsId = self.globalAssetIdx;
        DepegSwap storage _ds = self.ds[dsId];
        Guard.safeBeforeExpired(_ds);

        pa = self.psm.balances.paBalance;
        ds = self.psm.balances.dsBalance;
    }

    function repurchaseRates(State storage self) external view returns (uint256 rates) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        rates = _getLatestApplicableRate(self);
    }

    function repurchaseFeePercentage(State storage self) external view returns (uint256 rates) {
        rates = self.psm.repurchaseFeePercentage;
    }

    function updateRepurchaseFeePercentage(State storage self, uint256 newFees) external {
        if (newFees > MAX_ALLOWED_FEES) {
            revert IErrors_0.InvalidFees();
        }
        self.psm.repurchaseFeePercentage = newFees;
    }

    function updatePsmDepositsStatus(State storage self, bool isPSMDepositPaused) external {
        self.psm.isDepositPaused = isPSMDepositPaused;
    }

    function updatePsmWithdrawalsStatus(State storage self, bool isPSMWithdrawalPaused) external {
        self.psm.isWithdrawalPaused = isPSMWithdrawalPaused;
    }

    function updatePsmRepurchasesStatus(State storage self, bool isPSMRepurchasePaused) external {
        self.psm.isRepurchasePaused = isPSMRepurchasePaused;
    }

    function previewRepurchase(State storage self, uint256 amount)
        internal
        view
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates,
            DepegSwap storage ds
        )
    {
        dsId = self.globalAssetIdx;

        ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        exchangeRates = _getLatestApplicableRate(self);

        // the fee is taken directly from RA before it's even converted to DS
        {
            Asset dsToken = Asset(ds._address);
            (fee, feePercentage) = MathHelper.calculateRepurchaseFee(
                dsToken.issuedAt(), dsToken.expiry(), block.timestamp, amount, self.psm.repurchaseFeePercentage
            );
        }

        amount = amount - fee;
        amount = TransferHelper_0.tokenNativeDecimalsToFixed(amount, self.info.ra);

        // we use deposit here because technically the user deposit RA to the PSM when repurchasing
        receivedPa = MathHelper.calculateDepositAmountWithExchangeRate(amount, exchangeRates);
        receivedPa = TransferHelper_0.fixedToTokenNativeDecimals(receivedPa, self.info.pa);
        receivedDs = amount;

        if (receivedPa > self.psm.balances.paBalance) {
            revert IErrors_0.InsufficientLiquidity(self.psm.balances.paBalance, receivedPa);
        }

        if (receivedDs > self.psm.balances.dsBalance) {
            revert IErrors_0.InsufficientLiquidity(amount, self.psm.balances.dsBalance);
        }
    }

    function repurchase(State storage self, address buyer, uint256 amount, address treasury)
        external
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        )
    {
        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        DepegSwap storage ds;

        (dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates, ds) = previewRepurchase(self, amount);

        // decrease PSM balance
        // we also include the fee here to separate the accumulated fee from the repurchase
        self.psm.balances.paBalance -= (receivedPa);
        self.psm.balances.dsBalance -= (receivedDs);

        // transfer user RA to the PSM/LV
        self.psm.balances.ra.lockFrom(amount, buyer);

        // decrease the locked balance with the fee(if any), since the fee is used to provide liquidity
        if (fee != 0) {
            self.psm.balances.ra.decLocked(fee);
        }

        // transfer user attrubuted DS + PA
        // PA
        (, address pa) = self.info.underlyingAsset();
        IERC20(pa).safeTransfer(buyer, receivedPa);

        // DS
        IERC20(ds._address).safeTransfer(buyer, receivedDs);

        if (fee != 0) {
            uint256 remainingFee = _attributeFeeToTreasury(self, fee, treasury);
            // Provide liquidity with the remaining fee(if any)
            VaultLibrary.allocateFeesToVault(self, remainingFee);
        }
    }

    function _attributeFeeToTreasury(State storage self, uint256 fee, address treasury)
        internal
        returns (uint256 remaining)
    {
        uint256 attributedToTreasury;

        (remaining, attributedToTreasury) = _splitFee(self.psm.repurchaseFeeTreasurySplitPercentage, fee);
        self.psm.balances.ra.unlockToUnchecked(attributedToTreasury, treasury);
    }

    function _splitFee(uint256 basePercentage, uint256 fee)
        internal
        pure
        returns (uint256 remaining, uint256 splitted)
    {
        splitted = MathHelper.calculatePercentageFee(basePercentage, fee);
        remaining = fee - splitted;
    }

    function _redeemDs(Balances storage self, uint256 pa, uint256 ds) internal {
        self.dsBalance += ds;
        self.paBalance += pa;
    }

    function _afterRedeemWithDs(
        State storage self,
        DepegSwap storage ds,
        address owner,
        uint256 raReceived,
        uint256 paProvided,
        uint256 dsProvided,
        uint256 fee,
        address treasury
    ) internal {
        IERC20(ds._address).safeTransferFrom(owner, address(this), dsProvided);
        IERC20(self.info.peggedAsset().asErc20()).safeTransferFrom(owner, address(this), paProvided);

        self.psm.balances.ra.unlockTo(owner, raReceived);
        // we decrease the locked value, as we're going to use this to provide liquidity to the LV
        self.psm.balances.ra.decLocked(fee);

        uint256 attributedToTreasury;
        (fee, attributedToTreasury) = _splitFee(self.psm.psmBaseFeeTreasurySplitPercentage, fee);

        VaultLibrary.allocateFeesToVault(self, fee);
        self.psm.balances.ra.unlockToUnchecked(attributedToTreasury, treasury);
    }

    function valueLocked(State storage self, bool ra) external view returns (uint256) {
        if (ra) {
            return self.psm.balances.ra.locked;
        } else {
            return self.psm.balances.paBalance;
        }
    }

    function exchangeRate(State storage self) external view returns (uint256 rates) {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        rates = _getLatestApplicableRate(self);
    }

    /// @notice redeem an RA with DS + PA
    /// @dev since we currently have no way of knowing if the PA contract implements permit,
    /// we depends on the frontend to make approval to the PA contract before calling this function.
    /// for the DS, we use the permit function to approve the transfer. the parameter passed here MUST be the same
    /// as the one used to generate the ds permit signature
    function redeemWithDs(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes calldata rawDsPermitSig,
        uint256 deadline,
        address treasury
    ) external returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsProvided) {
        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        DepegSwap storage ds = self.ds[dsId];
        Guard.safeBeforeExpired(ds);

        (received, dsProvided, fee, _exchangeRate) = previewRedeemWithDs(self, dsId, amount);

        if (received > self.psm.balances.ra.locked) {
            revert IErrors_0.InsufficientLiquidity(self.psm.balances.ra.locked, received);
        }

        if (deadline != 0 && rawDsPermitSig.length != 0) {
            DepegSwapLibrary.permit(
                ds._address, rawDsPermitSig, owner, address(this), dsProvided, deadline, "redeemRaWithDsPa"
            );
        }

        _redeemDs(self.psm.balances, amount, dsProvided);
        _afterRedeemWithDs(self, ds, owner, received, amount, dsProvided, fee, treasury);
    }

    /// @notice simulate a ds redeem.
    /// @return ra how much RA the user would receive
    function previewRedeemWithDs(State storage self, uint256 dsId, uint256 amount)
        public
        view
        returns (uint256 ra, uint256 ds, uint256 fee, uint256 exchangeRates)
    {
        DepegSwap storage _ds = self.ds[dsId];
        Guard.safeBeforeExpired(_ds);

        exchangeRates = _getLatestApplicableRate(self);
        // the amount here is the PA amount
        amount = TransferHelper_0.tokenNativeDecimalsToFixed(amount, self.info.pa);
        uint256 raDs = MathHelper.calculateEqualSwapAmount(amount, exchangeRates);

        ds = raDs;
        ra = TransferHelper_0.fixedToTokenNativeDecimals(raDs, self.info.ra);

        fee = MathHelper.calculatePercentageFee(ra, self.psm.psmBaseRedemptionFeePercentage);
        ra -= fee;
    }

    /// @notice return the next depeg swap expiry
    function nextExpiry(State storage self) external view returns (uint256 expiry) {
        uint256 idx = self.globalAssetIdx;

        DepegSwap storage ds = self.ds[idx];

        expiry = Asset(ds._address).expiry();
    }

    function _calcRedeemAmount(
        State storage self,
        uint256 amount,
        uint256 totalCtIssued,
        uint256 availableRa,
        uint256 availablePa
    ) internal view returns (uint256 accruedPa, uint256 accruedRa) {
        availablePa = TransferHelper_0.tokenNativeDecimalsToFixed(availablePa, self.info.pa);
        availableRa = TransferHelper_0.tokenNativeDecimalsToFixed(availableRa, self.info.ra);

        accruedPa = MathHelper.calculateAccrued(amount, availablePa, totalCtIssued);

        accruedRa = MathHelper.calculateAccrued(amount, availableRa, totalCtIssued);

        accruedPa = TransferHelper_0.fixedToTokenNativeDecimals(accruedPa, self.info.pa);
        accruedRa = TransferHelper_0.fixedToTokenNativeDecimals(accruedRa, self.info.ra);
    }

    function _beforeCtRedeem(
        State storage self,
        DepegSwap storage ds,
        uint256 dsId,
        uint256 amount,
        uint256 accruedPa,
        uint256 accruedRa
    ) internal {
        ds.ctRedeemed += amount;
        self.psm.poolArchive[dsId].ctAttributed -= amount;
        self.psm.poolArchive[dsId].paAccrued -= accruedPa;
        self.psm.poolArchive[dsId].raAccrued -= accruedRa;
    }

    function _afterCtRedeem(
        State storage self,
        DepegSwap storage ds,
        address owner,
        uint256 ctRedeemedAmount,
        uint256 accruedPa,
        uint256 accruedRa
    ) internal {
        ERC20Burnable(ds.ct).burnFrom(owner, ctRedeemedAmount);
        IERC20(self.info.peggedAsset().asErc20()).safeTransfer(owner, accruedPa);
        IERC20(self.info.redemptionAsset()).safeTransfer(owner, accruedRa);
    }

    /// @notice redeem accrued RA + PA with CT on expiry
    /// @dev since we currently have no way of knowing if the PA contract implements permit,
    /// we depends on the frontend to make approval to the PA contract before calling this function.
    /// for the CT, we use the permit function to approve the transfer.
    /// the parameter passed here MUST be the same as the one used to generate the ct permit signature.
    function redeemWithExpiredCt(
        State storage self,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes calldata rawCtPermitSig,
        uint256 deadline
    ) external returns (uint256 accruedPa, uint256 accruedRa) {
        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);
        if (deadline != 0) {
            DepegSwapLibrary.permit(
                ds.ct, rawCtPermitSig, owner, address(this), amount, deadline, "redeemWithExpiredCt"
            );
        }
        _separateLiquidity(self, dsId);

        uint256 totalCtIssued = self.psm.poolArchive[dsId].ctAttributed;
        PsmPoolArchive storage archive = self.psm.poolArchive[dsId];

        (accruedPa, accruedRa) = _calcRedeemAmount(self, amount, totalCtIssued, archive.raAccrued, archive.paAccrued);

        _beforeCtRedeem(self, ds, dsId, amount, accruedPa, accruedRa);

        _afterCtRedeem(self, ds, owner, amount, accruedPa, accruedRa);
    }

    function updatePSMBaseRedemptionFeePercentage(State storage self, uint256 newFees) external {
        if (newFees > MAX_ALLOWED_FEES) {
            revert IErrors_0.InvalidFees();
        }
        self.psm.psmBaseRedemptionFeePercentage = newFees;
    }
}

// contracts/libraries/VaultLib.sol

/**
 * @title Vault Library Contract
 * @author Cork Team
 * @notice Vault Library implements features for  LVCore(liquidity Vault Core)
 */
library VaultLibrary {
    using PairLibrary for Pair;
    using LvAssetLibrary for LvAsset;
    using PsmLibrary for State;
    using RedemptionAssetManagerLibrary for RedemptionAssetManager;
    using BitMaps for BitMaps.BitMap;
    using DepegSwapLibrary for DepegSwap;
    using VaultPoolLibrary for VaultPool;
    using SafeERC20 for IERC20;
    using VaultBalanceLibrary for State;
    using NavCircuitBreakerLibrary for NavCircuitBreaker;

    // for avoiding stack too deep errors
    struct Tolerance {
        uint256 ra;
        uint256 ct;
    }

    function initialize(VaultState storage self, address lv, address ra, uint256 initialArp) external {
        self.lv = LvAssetLibrary.initialize(lv);
        self.balances.ra = RedemptionAssetManagerLibrary.initialize(ra);
    }

    function __addLiquidityToAmmUnchecked(
        uint256 raAmount,
        uint256 ctAmount,
        address raAddress,
        address ctAddress,
        ICorkHook_0 ammRouter,
        uint256 raTolerance,
        uint256 ctTolerance
    ) internal returns (uint256 lp, uint256 dust) {
        IERC20(raAddress).safeIncreaseAllowance(address(ammRouter), raAmount);
        IERC20(ctAddress).safeIncreaseAllowance(address(ammRouter), ctAmount);

        uint256 raAdded;
        uint256 ctAdded;

        (raAdded, ctAdded, lp) =
            ammRouter.addLiquidity(raAddress, ctAddress, raAmount, ctAmount, raTolerance, ctTolerance, block.timestamp);

        uint256 dustCt = ctAmount - ctAdded;

        if (dustCt > 0) {
            SafeERC20.safeTransfer(IERC20(ctAddress), msg.sender, dustCt);
        }

        uint256 dustRa = raAmount - raAdded;

        if (dustRa > 0) {
            SafeERC20.safeTransfer(IERC20(raAddress), msg.sender, dustRa);
        }
        dust = dustRa + dustCt;
    }

    function _addFlashSwapReserveLv(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        DepegSwap storage ds,
        uint256 amount
    ) internal {
        IERC20(ds._address).safeIncreaseAllowance(address(flashSwapRouter), amount);
        flashSwapRouter.addReserveLv(self.info.toId(), self.globalAssetIdx, amount);
    }

    // MUST be called on every new DS issuance
    function onNewIssuance(
        State storage self,
        uint256 prevDsId,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook_0 ammRouter,
        uint256 deadline
    ) external {
        // do nothing at first issuance
        if (prevDsId == 0) {
            return;
        }

        // do nothing if there's no LV token minted(no liquidity to act anything)
        if (self.vault.lv.totalIssued() == 0) {
            return;
        }

        _liquidateIfExpired(self, prevDsId, ammRouter, deadline);

        __provideAmmLiquidityFromPool(self, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }

    function _liquidateIfExpired(State storage self, uint256 dsId, ICorkHook_0 ammRouter, uint256 deadline) internal {
        DepegSwap storage ds = self.ds[dsId];
        // we don't want to revert here for easier control flow, expiry check should happen at contract level not library level
        if (!ds.isExpired()) {
            return;
        }
        if (!self.vault.lpLiquidated.get(dsId)) {
            _liquidatedLp(self, dsId, ammRouter, deadline);
            _redeemCtStrategy(self, dsId);
            _takeRaSnapshot(self, dsId);
            _pauseDepositIfPaIsPresent(self);
        }
    }

    function _takeRaSnapshot(State storage self, uint256 dsId) internal {
        self.vault.totalRaSnapshot[dsId] = self.vault.pool.ammLiquidityPool.balance;
    }

    function _pauseDepositIfPaIsPresent(State storage self) internal {
        if (self.vault.pool.withdrawalPool.paBalance > 0) {
            self.vault.config.isDepositPaused = true;
        }
    }

    function safeBeforeExpired(State storage self) internal view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];

        Guard.safeBeforeExpired(ds);
    }

    function safeAfterExpired(State storage self) external view {
        uint256 dsId = self.globalAssetIdx;
        DepegSwap storage ds = self.ds[dsId];
        Guard.safeAfterExpired(ds);
    }

    function __provideLiquidityWithRatioGetLP(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook_0 ammRouter,
        Tolerance memory tolerance
    ) internal returns (uint256 ra, uint256 ct, uint256 lp) {
        (ra, ct) = __calculateProvideLiquidityAmount(self, amount, flashSwapRouter);
        (lp,) = __provideLiquidity(self, ra, ct, flashSwapRouter, ctAddress, ammRouter, tolerance, amount);
    }

    // Duplicate function of __provideLiquidityWithRatioGetLP to avoid stack too deep error
    function __provideLiquidityWithRatioGetDust(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook_0 ammRouter
    ) internal returns (uint256 ra, uint256 ct, uint256 dust) {
        Tolerance memory tolerance;

        (ra, ct) = __calculateProvideLiquidityAmount(self, amount, flashSwapRouter);

        (tolerance.ra, tolerance.ct) = MathHelper.calculateWithTolerance(ra, ct, MathHelper.UNI_STATIC_TOLERANCE);

        (, dust) = __provideLiquidity(self, ra, ct, flashSwapRouter, ctAddress, ammRouter, tolerance, amount);
    }

    function __calculateProvideLiquidityAmount(State storage self, uint256 amount, IDsFlashSwapCore flashSwapRouter)
        internal
        view
        returns (uint256 ra, uint256 ct)
    {
        uint256 dsId = self.globalAssetIdx;
        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (ra, ct) = MathHelper.calculateProvideLiquidityAmountBasedOnCtPrice(amount, ctRatio);
    }

    function __provideLiquidityWithRatio(
        State storage self,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook_0 ammRouter
    ) internal returns (uint256 ra, uint256 ct, uint256 dust) {
        (ra, ct, dust) = __provideLiquidityWithRatioGetDust(self, amount, flashSwapRouter, ctAddress, ammRouter);
    }

    function __getAmmCtPriceRatio(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 dsId)
        internal
        view
        returns (uint256 ratio)
    {
        Id id = self.info.toId();
        uint256 hpa = flashSwapRouter.getCurrentEffectiveHIYA(id);
        bool isRollover = flashSwapRouter.isRolloverSale(id);

        // slither-disable-next-line uninitialized-local
        uint256 marketRatio;

        try flashSwapRouter.getCurrentPriceRatio(id, dsId) returns (uint256, uint256 _marketRatio) {
            marketRatio = _marketRatio;
        } catch {
            marketRatio = 0;
        }

        ratio = _determineRatio(hpa, marketRatio, self.info.initialArp, isRollover, dsId);
    }

    function _determineRatio(uint256 hiya, uint256 marketRatio, uint256 initialArp, bool isRollover, uint256 dsId)
        internal
        pure
        returns (uint256 ratio)
    {
        // fallback to initial ds price ratio if hpa is 0, and market ratio is 0
        // usually happens when there's no trade on the router AND is not the first issuance
        // OR it's the first issuance
        if (hiya == 0 && marketRatio == 0) {
            ratio = MathHelper.calculateInitialCtRatio(initialArp);
            return ratio;
        }

        // this will return the hiya as hpa as ratio when it's basically not the first issuance, and there's actually an hiya to rely on
        // we must specifically check for market ratio since, we want to trigger this only when there's no market ratio(i.e freshly after a rollover)
        if (dsId != 1 && isRollover && hiya != 0 && marketRatio == 0) {
            // we add 2 zerom since the function will normalize it to 0-1 from 1-100
            ratio = MathHelper.calculateInitialCtRatio(hiya * 100);
            return ratio;
        }

        // this will be the default ratio to use
        if (marketRatio != 0) {
            ratio = marketRatio;
            return ratio;
        }
    }

    function __provideLiquidity(
        State storage self,
        uint256 raAmount,
        uint256 ctAmount,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook_0 ammRouter,
        Tolerance memory tolerance,
        uint256 amountRaOriginal
    ) internal returns (uint256 lp, uint256 dust) {
        uint256 dsId = self.globalAssetIdx;

        address ra = self.info.ra;
        // no need to provide liquidity if the amount is 0
        if (raAmount == 0 || ctAmount == 0) {
            if (raAmount != 0) {
                SafeERC20.safeTransfer(IERC20(ra), msg.sender, raAmount);
            }

            if (ctAmount != 0) {
                SafeERC20.safeTransfer(IERC20(ctAddress), msg.sender, ctAmount);
            }

            return (0, 0);
        }

        // we use the returned value here since the amount is already normalized
        ctAmount =
            PsmLibrary.unsafeIssueToLv(self, MathHelper.calculateProvideLiquidityAmount(amountRaOriginal, raAmount));

        (lp, dust) =
            __addLiquidityToAmmUnchecked(raAmount, ctAmount, ra, ctAddress, ammRouter, tolerance.ra, tolerance.ct);
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[dsId], ctAmount);

        self.addLpBalance(lp);
    }

    function __provideAmmLiquidityFromPool(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        address ctAddress,
        ICorkHook_0 ammRouter
    ) internal returns (uint256 dust) {
        uint256 dsId = self.globalAssetIdx;

        uint256 ctRatio = __getAmmCtPriceRatio(self, flashSwapRouter, dsId);

        (uint256 ra, uint256 ct, uint256 originalBalance) = self.vault.pool.rationedToAmm(ctRatio);

        // this doesn't really matter tbh, since the amm is fresh and we're the first one to add liquidity to it
        (uint256 raTolerance, uint256 ctTolerance) =
            MathHelper.calculateWithTolerance(ra, ct, MathHelper.UNI_STATIC_TOLERANCE);

        (, dust) = __provideLiquidity(
            self, ra, ct, flashSwapRouter, ctAddress, ammRouter, Tolerance(raTolerance, ctTolerance), originalBalance
        );

        self.vault.pool.resetAmmPool();
    }

    function deposit(
        State storage self,
        address from,
        uint256 amount,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook_0 ammRouter,
        uint256 raTolerance,
        uint256 ctTolerance
    ) external returns (uint256 received) {
        if (amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }
        safeBeforeExpired(self);

        self.vault.balances.ra.lockUnchecked(amount, from);

        // split the RA first according to the lv strategy
        (uint256 remaining, uint256 splitted) = _splitCtWithStrategy(self, flashSwapRouter, amount);

        uint256 dsId = self.globalAssetIdx;

        address ct = self.ds[dsId].ct;

        // we mint 1:1 if it's the first deposit, else we mint based on current vault NAV
        if (!self.vault.initialized) {
            // we don't allow depositing less than 1e10 normalized to ensure good initialization
            if (amount < TransferHelper_0.fixedToTokenNativeDecimals(1e10, self.info.ra)) {
                revert IErrors_0.InvalidAmount();
            }

            // we use the initial amount as the received amount on first issuance
            // this is important to normalize to 18 decimals since without it
            // the lv share pricing will ehave as though the lv decimals is the same as the ra
            received = TransferHelper_0.tokenNativeDecimalsToFixed(amount, self.info.ra);
            self.vault.initialized = true;

            __provideLiquidityWithRatioGetLP(
                self, remaining, flashSwapRouter, ct, ammRouter, Tolerance(raTolerance, ctTolerance)
            );
            self.vault.lv.issue(from, received);

            _updateNavCircuitBreakerOnFirstDeposit(self, flashSwapRouter, ammRouter, dsId);

            return received;
        }

        // we used the initial deposit amount to accurately calculate the NAV per share
        received = _calculateReceivedDeposit(
            self,
            ammRouter,
            CalculateReceivedDepositParams({
                ctSplitted: splitted,
                dsId: dsId,
                amount: amount,
                flashSwapRouter: flashSwapRouter
            })
        );

        __provideLiquidityWithRatioGetLP(
            self, remaining, flashSwapRouter, ct, ammRouter, Tolerance(raTolerance, ctTolerance)
        );

        self.vault.lv.issue(from, received);
    }

    struct CalculateReceivedDepositParams {
        uint256 ctSplitted;
        uint256 dsId;
        uint256 amount;
        IDsFlashSwapCore flashSwapRouter;
    }

    function _calculateReceivedDeposit(
        State storage self,
        ICorkHook_0 ammRouter,
        CalculateReceivedDepositParams memory params
    ) internal returns (uint256 received) {
        Id id = self.info.toId();
        address ct = self.ds[params.dsId].ct;

        MarketSnapshot memory snapshot = ammRouter.getMarketSnapshot(self.info.ra, ct);
        uint256 lpSupply = IERC20(snapshot.liquidityToken).totalSupply();
        uint256 vaultLp = self.lpBalance();

        // we convert ra reserve to 18 decimals to get accurate results
        snapshot.reserveRa = TransferHelper_0.tokenNativeDecimalsToFixed(snapshot.reserveRa, self.info.ra);
        params.amount = TransferHelper_0.tokenNativeDecimalsToFixed(params.amount, self.info.ra);

        MathHelper.NavParams memory navParams = MathHelper.NavParams({
            reserveRa: snapshot.reserveRa,
            reserveCt: snapshot.reserveCt,
            oneMinusT: snapshot.oneMinusT,
            lpSupply: lpSupply,
            lvSupply: Asset(self.vault.lv._address).totalSupply(),
            // we already split the CT so we need to subtract it first here
            vaultCt: self.vault.balances.ctBalance - params.ctSplitted,
            // subtract the added DS in the flash swap router
            vaultDs: params.flashSwapRouter.getLvReserve(id, params.dsId) - params.ctSplitted,
            vaultLp: vaultLp,
            vaultIdleRa: TransferHelper_0.tokenNativeDecimalsToFixed(self.vault.balances.ra.locked, self.info.ra)
        });

        uint256 nav = MathHelper.calculateNav(navParams);

        uint256 lvSupply = Asset(self.vault.lv._address).totalSupply();
        received = MathHelper.calculateDepositLv(nav, params.amount, lvSupply);

        // update nav reference for the circuit breaker
        self.vault.config.navCircuitBreaker.validateAndUpdateDeposit(nav);
    }

    function updateCtHeldPercentage(State storage self, uint256 ctHeldPercentage) external {
        // must be between 0% and 100%
        if (ctHeldPercentage >= 100 ether) {
            revert IErrors_0.InvalidParams();
        }

        self.vault.ctHeldPercetage = ctHeldPercentage;
    }

    function _splitCt(State storage self, uint256 amount) internal view returns (uint256 splitted) {
        uint256 ctHeldPercentage = self.vault.ctHeldPercetage;
        splitted = MathHelper.calculatePercentageFee(ctHeldPercentage, amount);
    }

    // return the amount left and the CT splitted(in 18 decimals)
    function _splitCtWithStrategy(State storage self, IDsFlashSwapCore flashSwapRouter, uint256 amount)
        internal
        returns (uint256 amountLeft, uint256 splitted)
    {
        splitted = _splitCt(self, amount);

        amountLeft = amount - splitted;

        // actually mint ct & ds to vault and used the normalized value
        splitted = PsmLibrary.unsafeIssueToLv(self, splitted);

        // increase the ct balance in the vault
        self.vault.balances.ctBalance += splitted;

        // add ds to flash swap reserve
        _addFlashSwapReserveLv(self, flashSwapRouter, self.ds[self.globalAssetIdx], splitted);
    }

    // redeem CT that's been held in the pool, must only be called after liquidating LP on new issuance
    function _redeemCtStrategy(State storage self, uint256 dsId) internal {
        uint256 attributedCt = self.vault.balances.ctBalance;

        // reset the ct balance
        self.vault.balances.ctBalance = 0;

        // redeem the ct to the PSM
        (uint256 accruedPa, uint256 accruedRa) = PsmLibrary.lvRedeemRaPaWithCt(self, attributedCt, dsId);

        // add the accrued RA to the amm pool
        self.vault.pool.ammLiquidityPool.balance += accruedRa;

        // add the accrued PA to the withdrawal pool
        self.vault.pool.withdrawalPool.paBalance += accruedPa;
    }

    function __liquidateUnchecked(
        State storage self,
        address raAddress,
        address ctAddress,
        ICorkHook_0 ammRouter,
        uint256 lp,
        uint256 deadline
    ) internal returns (uint256 raReceived, uint256 ctReceived) {
        IERC20(ammRouter.getLiquidityToken(raAddress, ctAddress)).approve(address(ammRouter), lp);

        // amountAMin & amountBMin = 0 for 100% tolerence
        (raReceived, ctReceived) = ammRouter.removeLiquidity(raAddress, ctAddress, lp, 0, 0, deadline);

        self.subtractLpBalance(lp);
    }

    function _liquidatedLp(State storage self, uint256 dsId, ICorkHook_0 ammRouter, uint256 deadline) internal {
        DepegSwap storage ds = self.ds[dsId];
        uint256 lpBalance = self.lpBalance();

        // if there's no LP, then there's nothing to liquidate
        if (lpBalance == 0) {
            self.vault.lpLiquidated.set(dsId);
            return;
        }

        // the following things should happen here(taken directly from the whitepaper) :
        // 1. The AMM LP is redeemed to receive CT + RA
        // 2. Any excess DS in the LV is paired with CT to redeem RA
        // 3. The excess CT is used to claim RA + PA in the PSM
        // 4. End state: Only RA + redeemed PA remains
        self.vault.lpLiquidated.set(dsId);

        (uint256 raAmm, uint256 ctAmm) = __liquidateUnchecked(self, self.info.ra, ds.ct, ammRouter, lpBalance, deadline);

        // avoid stack too deep error
        _redeemCtVault(self, dsId, ctAmm, raAmm);
    }

    function _redeemCtVault(State storage self, uint256 dsId, uint256 ctAmm, uint256 raAmm) internal {
        uint256 psmPa;
        uint256 psmRa;

        (psmPa, psmRa) = PsmLibrary.lvRedeemRaPaWithCt(self, ctAmm, dsId);

        psmRa += raAmm;

        self.vault.pool.reserve(self.vault.lv.totalIssued(), psmRa, psmPa);
    }

    function __calculateTotalRaAndCtBalanceWithReserve(
        State storage self,
        uint256 raReserve,
        uint256 ctReserve,
        uint256 lpSupply,
        uint256 lpBalance
    )
        internal
        view
        returns (
            uint256 totalRa,
            uint256 ammCtBalance,
            uint256 raPerLv,
            uint256 ctPerLv,
            uint256 raPerLp,
            uint256 ctPerLp
        )
    {
        (raPerLv, ctPerLv, raPerLp, ctPerLp, totalRa, ammCtBalance) = MathHelper.calculateLvValueFromUniLp(
            lpSupply, lpBalance, raReserve, ctReserve, Asset(self.vault.lv._address).totalSupply()
        );
    }

    // IMPORTANT : only psm, flash swap router can call this function
    function allocateFeesToVault(State storage self, uint256 amount) public {
        self.vault.balances.ra.incLocked(amount);
    }

    function _calculateSpotNav(State storage self, IDsFlashSwapCore flashSwapRouter, ICorkHook_0 ammRouter, uint256 dsId)
        internal
        returns (uint256 nav)
    {
        Id id = self.info.toId();
        address ct = self.ds[dsId].ct;

        MarketSnapshot memory snapshot = ammRouter.getMarketSnapshot(self.info.ra, ct);
        uint256 lpSupply = IERC20(snapshot.liquidityToken).totalSupply();
        uint256 vaultLp = self.lpBalance();

        // we convert ra reserve to 18 decimals to get accurate results
        snapshot.reserveRa = TransferHelper_0.tokenNativeDecimalsToFixed(snapshot.reserveRa, self.info.ra);

        MathHelper.NavParams memory navParams = MathHelper.NavParams({
            reserveRa: snapshot.reserveRa,
            reserveCt: snapshot.reserveCt,
            oneMinusT: snapshot.oneMinusT,
            lpSupply: lpSupply,
            lvSupply: Asset(self.vault.lv._address).totalSupply(),
            vaultCt: self.vault.balances.ctBalance,
            vaultDs: flashSwapRouter.getLvReserve(id, dsId),
            vaultLp: vaultLp,
            vaultIdleRa: TransferHelper_0.tokenNativeDecimalsToFixed(self.vault.balances.ra.locked, self.info.ra)
        });

        nav = MathHelper.calculateNav(navParams);
    }

    function _updateNavCircuitBreakerOnWithdrawal(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook_0 ammRouter,
        uint256 dsId
    ) internal {
        uint256 nav = _calculateSpotNav(self, flashSwapRouter, ammRouter, dsId);
        self.vault.config.navCircuitBreaker.updateOnWithdrawal(nav);
    }

    function _updateNavCircuitBreakerOnFirstDeposit(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook_0 ammRouter,
        uint256 dsId
    ) internal {
        forceUpdateNavCircuitBreakerReferenceValue(self, flashSwapRouter, ammRouter, dsId);
    }

    function forceUpdateNavCircuitBreakerReferenceValue(
        State storage self,
        IDsFlashSwapCore flashSwapRouter,
        ICorkHook_0 ammRouter,
        uint256 dsId
    ) internal {
        uint256 nav = _calculateSpotNav(self, flashSwapRouter, ammRouter, dsId);
        self.vault.config.navCircuitBreaker.forceUpdateSnapshot(nav);
    }

    // this will give user their respective balance in mixed form of CT, DS, RA, PA
    function redeemEarly(
        State storage self,
        address owner,
        IVault.RedeemEarlyParams calldata redeemParams,
        IVault.ProtocolContracts memory contracts,
        IVault.PermitParams calldata permitParams
    ) external returns (IVault.RedeemEarlyResult memory result) {
        if (redeemParams.amount == 0) {
            revert IErrors_0.ZeroDeposit();
        }

        {
            uint256 lvSupply = Asset(self.vault.lv._address).totalSupply();

            if (lvSupply < redeemParams.amount) {
                revert IErrors_0.InvalidAmount();
            }
        }

        if (permitParams.deadline != 0) {
            DepegSwapLibrary.permit(
                self.vault.lv._address,
                permitParams.rawLvPermitSig,
                owner,
                address(this),
                redeemParams.amount,
                permitParams.deadline,
                "redeemEarlyLv"
            );
        }

        result.id = redeemParams.id;
        result.receiver = owner;

        uint256 dsId = self.globalAssetIdx;

        Pair storage pair = self.info;
        DepegSwap storage ds = self.ds[dsId];

        MathHelper.RedeemResult memory redeemAmount;

        _updateNavCircuitBreakerOnWithdrawal(self, contracts.flashSwapRouter, contracts.ammRouter, dsId);

        {
            uint256 lpBalance = self.lpBalance();

            MathHelper.RedeemParams memory params = MathHelper.RedeemParams({
                amountLvClaimed: redeemParams.amount,
                totalLvIssued: Asset(self.vault.lv._address).totalSupply(),
                totalVaultLp: lpBalance,
                totalVaultCt: self.vault.balances.ctBalance,
                totalVaultDs: contracts.flashSwapRouter.getLvReserve(redeemParams.id, dsId),
                totalVaultPA: self.vault.pool.withdrawalPool.paBalance,
                totalVaultIdleRa: self.vault.balances.ra.locked
            });

            redeemAmount = MathHelper.calculateRedeemLv(params);
            result.ctReceivedFromVault = redeemAmount.ctReceived;

            result.dsReceived = redeemAmount.dsReceived;
            result.raIdleReceived = redeemAmount.idleRaReceived;
            result.paReceived = redeemAmount.paReceived;
        }

        {
            (uint256 raFromAmm, uint256 ctFromAmm) = __liquidateUnchecked(
                self, pair.ra, ds.ct, contracts.ammRouter, redeemAmount.lpLiquidated, redeemParams.ammDeadline
            );

            result.raReceivedFromAmm = raFromAmm;
            result.ctReceivedFromAmm = ctFromAmm;
        }

        _decreaseInternalBalanceAfterRedeem(self, result);

        if (result.raReceivedFromAmm < redeemParams.amountOutMin) {
            revert IErrors_0.InsufficientOutputAmount(redeemParams.amountOutMin, result.raReceivedFromAmm);
        }

        if (result.ctReceivedFromAmm + result.ctReceivedFromVault < redeemParams.ctAmountOutMin) {
            revert IErrors_0.InsufficientOutputAmount(
                redeemParams.ctAmountOutMin, result.ctReceivedFromAmm + result.ctReceivedFromVault
            );
        }

        if (result.dsReceived < redeemParams.dsAmountOutMin) {
            revert IErrors_0.InsufficientOutputAmount(redeemParams.dsAmountOutMin, result.dsReceived);
        }

        if (result.paReceived < redeemParams.paAmountOutMin) {
            revert IErrors_0.InsufficientOutputAmount(redeemParams.paAmountOutMin, result.paReceived);
        }

        ERC20Burnable(self.vault.lv._address).burnFrom(owner, redeemParams.amount);

        // fetch ds from flash swap router
        contracts.flashSwapRouter.emptyReservePartialLv(redeemParams.id, dsId, result.dsReceived);

        uint256 raReceived = result.raReceivedFromAmm + result.raIdleReceived;
        {
            IWithdrawalRouter.Tokens[] memory tokens = new IWithdrawalRouter.Tokens[](4);

            tokens[0] = IWithdrawalRouter.Tokens(pair.ra, raReceived);
            tokens[1] = IWithdrawalRouter.Tokens(ds.ct, result.ctReceivedFromVault + result.ctReceivedFromAmm);
            tokens[2] = IWithdrawalRouter.Tokens(ds._address, result.dsReceived);
            tokens[3] = IWithdrawalRouter.Tokens(pair.pa, result.paReceived);

            bytes32 withdrawalId = contracts.withdrawalContract.add(owner, tokens);

            result.withdrawalId = withdrawalId;
        }

        // send RA amm to user
        self.vault.balances.ra.unlockToUnchecked(raReceived, address(contracts.withdrawalContract));

        // send CT received from AMM and held in vault to user
        SafeERC20.safeTransfer(
            IERC20(ds.ct), address(contracts.withdrawalContract), result.ctReceivedFromVault + result.ctReceivedFromAmm
        );

        // send DS to user
        SafeERC20.safeTransfer(IERC20(ds._address), address(contracts.withdrawalContract), result.dsReceived);

        // send PA to user
        SafeERC20.safeTransfer(IERC20(pair.pa), address(contracts.withdrawalContract), result.paReceived);
    }

    function _decreaseInternalBalanceAfterRedeem(State storage self, IVault.RedeemEarlyResult memory result) internal {
        self.vault.balances.ra.decLocked(result.raIdleReceived);
        self.vault.balances.ctBalance -= result.ctReceivedFromVault;
        self.vault.pool.withdrawalPool.paBalance -= result.paReceived;
    }

    function vaultLp(State storage self, ICorkHook_0 ammRotuer) internal view returns (uint256) {
        return self.lpBalance();
    }

    function requestLiquidationFunds(State storage self, uint256 amount, address to) internal {
        if (amount > self.vault.pool.withdrawalPool.paBalance) {
            revert IErrors_0.InsufficientFunds();
        }

        self.vault.pool.withdrawalPool.paBalance -= amount;
        SafeERC20.safeTransfer(IERC20(self.info.pa), to, amount);
    }

    function receiveTradeExecuctionResultFunds(State storage self, uint256 amount, address from) internal {
        self.vault.balances.ra.lockFrom(amount, from);
    }

    function useTradeExecutionResultFunds(State storage self, IDsFlashSwapCore flashSwapRouter, ICorkHook_0 ammRouter)
        internal
        returns (uint256 raFunds)
    {
        // convert to free and reset ra balance
        raFunds = self.vault.balances.ra.convertAllToFree();
        self.vault.balances.ra.reset();

        __provideLiquidityWithRatio(self, raFunds, flashSwapRouter, self.ds[self.globalAssetIdx].ct, ammRouter);
    }

    function liquidationFundsAvailable(State storage self) internal view returns (uint256) {
        return self.vault.pool.withdrawalPool.paBalance;
    }

    function tradeExecutionFundsAvailable(State storage self) internal view returns (uint256) {
        return self.vault.balances.ra.locked;
    }

    function receiveLeftoverFunds(State storage self, uint256 amount, address from) internal {
        // transfer PA to the vault
        SafeERC20.safeTransferFrom(IERC20(self.info.pa), from, address(this), amount);
        self.vault.pool.withdrawalPool.paBalance += amount;
    }

    function updateLvDepositsStatus(State storage self, bool isLVDepositPaused) external {
        self.vault.config.isDepositPaused = isLVDepositPaused;
    }

    function updateLvWithdrawalsStatus(State storage self, bool isLVWithdrawalPaused) external {
        self.vault.config.isWithdrawalPaused = isLVWithdrawalPaused;
    }

    function updateNavThreshold(State storage self, uint256 navThreshold) external {
        self.vault.config.navCircuitBreaker.navThreshold = navThreshold;
    }
}

// lib/Cork-Hook/src/CorkHook.sol

contract CorkHook is BaseHook, Ownable, ICorkHook_1 {
    using Clones for address;
    using PoolStateLibrary for PoolState;
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;

    /// @notice Pool state
    mapping(AmmId => PoolState) internal pool;

    // we will deploy proxy to this address for each pool
    address internal immutable lpBase;
    HookForwarder internal immutable forwarder;

    constructor(IPoolManager _poolManager, LiquidityToken _lpBase, address owner)
        BaseHook(_poolManager)
        Ownable(owner)
    {
        lpBase = address(_lpBase);
        forwarder = new HookForwarder(_poolManager);
    }

    modifier onlyInitialized(address a, address b) {
        AmmId ammId = toAmmId_0(a, b);
        PoolState storage self = pool[ammId];

        if (!self.isInitialized()) {
            revert IErrors_1.NotInitialized();
        }
        _;
    }

    modifier withinDeadline(uint256 deadline) {
        if (deadline < block.timestamp) {
            revert IErrors_1.Deadline();
        }
        _;
    }

    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true, // deploy lp tokens for this pool
            afterInitialize: false,
            beforeAddLiquidity: true, // override, only allow adding liquidity from the hook
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true, // override, only allow removing liquidity from the hook
            afterRemoveLiquidity: false,
            beforeSwap: true, // override, use our price curve
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true, // override, use our price curve
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        revert IErrors_1.DisableNativeLiquidityModification();
    }

    function beforeInitialize(address, PoolKey calldata key, uint160) external virtual override returns (bytes4) {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        AmmId ammId = toAmmId_0(token0, token1);

        if (pool[ammId].isInitialized()) {
            revert IErrors_1.AlreadyInitialized();
        }

        LiquidityToken lp = LiquidityToken(lpBase.clone());
        pool[ammId].initialize(token0, token1, address(lp));

        // check for the token to be valid, i.e have expiry
        {
            PoolState storage self = pool[ammId];
            _saveIssuedAndMaturationTime(self);
        }

        // the reason we just concatenate the addresses instead of their respective symbols is that because this way, we don't need to worry about
        // tokens symbols to have different encoding and other shinanigans. Frontend should parse and display the token symbols accordingly
        string memory identifier =
            string.concat(Strings.toHexString(uint160(token0)), "-", Strings.toHexString(uint160(token1)));

        lp.initialize(string.concat("Liquidity Token ", identifier), string.concat("LP-", identifier), address(this));

        return this.beforeInitialize.selector;
    }

    function _ensureValidAmount(uint256 amount0, uint256 amount1) internal pure {
        if (amount0 == 0 && amount1 == 0) {
            revert IErrors_1.InvalidAmount();
        }

        if (amount0 != 0 && amount1 != 0) {
            revert IErrors_1.InvalidAmount();
        }
    }

    // we default to exact out swap, since it's easier to do flash swap this way
    // only support flash swap where the user pays with the other tokens
    // for paying with the same token, use "take" and "settle" directly in the pool manager
    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        onlyInitialized(ra, ct)
        returns (uint256 amountIn)
    {
        SortResult memory sortResult = sortPacked_0(ra, ct, amountRaOut, amountCtOut);
        sortResult = normalize_0(sortResult);

        _ensureValidAmount(sortResult.amount0, sortResult.amount1);

        // if the amount1 is zero, then we swap token0 to token1, and vice versa
        bool zeroForOne = sortResult.amount0 <= 0;
        uint256 out = zeroForOne ? sortResult.amount1 : sortResult.amount0;

        {
            PoolState storage self = pool[toAmmId_0(sortResult.token0, sortResult.token1)];
            (amountIn,) = _getAmountIn(self, zeroForOne, out);
        }

        // turn the amount back to the original token decimals for user returns and accountings
        {
            amountIn = toNative_1(zeroForOne ? sortResult.token0 : sortResult.token1, amountIn);
            out = toNative_1(zeroForOne ? sortResult.token1 : sortResult.token0, out);
        }

        bytes memory swapData;
        IPoolManager.SwapParams memory ammSwapParams;
        ammSwapParams = IPoolManager.SwapParams(zeroForOne, int256(out), Constants.SQRT_PRICE_1_1);

        SwapParams memory params;
        PoolKey memory key = getPoolKey(sortResult.token0, sortResult.token1);

        params = SwapParams(data, ammSwapParams, key, msg.sender, out, amountIn);
        swapData = abi.encode(Action.Swap, params);

        poolManager.unlock(swapData);
    }

    function _initSwap(SwapParams memory params) internal {
        // trf user token to forwarder
        address token0 = Currency.unwrap(params.poolKey.currency0);
        address token1 = Currency.unwrap(params.poolKey.currency1);

        // regular swap, the user already has the token, so we directly transfer the token to the forwarder
        // if it has data, then its a flash swap, user usually doesn't have the token to pay, so we skip this step
        // and let the user pay on the callback directly to pool manager
        if (params.swapData.length == 0) {
            if (params.params.zeroForOne) {
                IERC20(token0).transferFrom(params.sender, address(forwarder), params.amountIn);
            } else {
                IERC20(token1).transferFrom(params.sender, address(forwarder), params.amountIn);
            }
        }

        forwarder.swap(params);
    }

    function _addLiquidity(PoolState storage self, uint256 amount0, uint256 amount1, address sender) internal {
        // we can safely insert 0 here since we have checked for validity at the start
        self.addLiquidity(amount0, amount1, sender, 0, 0);

        Currency token0 = self.getToken0();
        Currency token1 = self.getToken1();

        // settle claims token
        settleNormalized(token0, poolManager, sender, amount0, false);
        settleNormalized(token1, poolManager, sender, amount1, false);

        // take the tokens
        takeNormalized(token0, poolManager, address(this), amount0, true);
        takeNormalized(token1, poolManager, address(this), amount1, true);
    }

    function _removeLiquidity(PoolState storage self, uint256 liquidityAmount, address sender) internal {
        (uint256 amount0, uint256 amount1,,) = self.removeLiquidity(liquidityAmount, sender);

        Currency token0 = self.getToken0();
        Currency token1 = self.getToken1();

        // burn claims token
        settle(token0, poolManager, address(this), amount0, true);
        settle(token1, poolManager, address(this), amount1, true);

        // send back the tokens
        take(token0, poolManager, sender, amount0, false);
        take(token1, poolManager, sender, amount1, false);
    }

    // we dont check for initialization here since we want to pre init the fee
    function updateBaseFeePercentage(address ra, address ct, uint256 baseFeePercentage) external onlyOwner {
        pool[toAmmId_0(ra, ct)].fee = baseFeePercentage;
    }

    function updateTreasurySplitPercentage(address ra, address ct, uint256 treasurySplit) external onlyOwner {
        pool[toAmmId_0(ra, ct)].treasurySplitPercentage = treasurySplit;
    }

    function addLiquidity(
        address ra,
        address ct,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external withinDeadline(deadline) returns (uint256 amountRa, uint256 amountCt, uint256 mintedLp) {
        // returns how much liquidity token was minted
        SortResult memory sortResult = sortPacked_0(ra, ct, raAmount, ctAmount);
        sortResult = normalize_0(sortResult);

        PoolState storage self = pool[toAmmId_0(sortResult.token0, sortResult.token1)];

        // all sanitiy check should go here
        if (!self.isInitialized()) {
            forwarder.initializePool(sortResult.token0, sortResult.token1);
            emit Initialized(ra, ct, address(self.liquidityToken));
        }

        {
            (,, uint256 amount0min, uint256 amount1min) = sort_1(ra, ct, amountRamin, amountCtmin);
            // check and returns how much lp minted
            // we use the return argument as container here but amountRa is actually token0 used right now
            // we stay it like this to avoid stack too deep errors and because we need the actual amount used to transfer from user
            (,, mintedLp, amountRa, amountCt) =
                self.tryAddLiquidity(sortResult.amount0, sortResult.amount1, amount0min, amount1min);
        }

        {
            // we use the previously used amount here
            AddLiquidtyParams memory params =
                AddLiquidtyParams(sortResult.token0, amountRa, sortResult.token1, amountCt, msg.sender);

            // now we actually sort back the tokens
            (amountRa, amountCt) = ra == sortResult.token0 ? (amountRa, amountCt) : (amountCt, amountRa);

            // we convert the amount to the native decimals to reflect the actual amount when returning
            amountRa = toNative_1(ra, amountRa);
            amountCt = toNative_1(ct, amountCt);

            bytes memory data = abi.encode(Action.AddLiquidity, params);

            poolManager.unlock(data);
        }

        emit ICorkHook_1.AddedLiquidity(ra, ct, amountRa, amountCt, mintedLp, msg.sender);
    }

    function removeLiquidity(
        address ra,
        address ct,
        uint256 liquidityAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external withinDeadline(deadline) returns (uint256 amountRa, uint256 amountCt) {
        SortResult memory sortResult = sortPacked_1(ra, ct);

        AmmId ammId = toAmmId_0(sortResult.token0, sortResult.token1);
        PoolState storage self = pool[ammId];

        // sanity check, we explicitly check here instrad of using modifier to avoid stack too deep
        if (!self.isInitialized()) {
            revert IErrors_1.NotInitialized();
        }

        (uint256 amount0, uint256 amount1,,) = self.tryRemoveLiquidity(liquidityAmount);
        (,, amountRa, amountCt) = reverseSortWithAmount(ra, ct, sortResult.token0, sortResult.token1, amount0, amount1);

        if (amountRa < amountRamin || amountCt < amountCtmin) {
            revert IErrors_1.InsufficientOutputAmout();
        }

        {
            RemoveLiquidtyParams memory params =
                RemoveLiquidtyParams(sortResult.token0, sortResult.token1, liquidityAmount, msg.sender);

            bytes memory data = abi.encode(Action.RemoveLiquidity, params);

            poolManager.unlock(data);
        }

        {
            emit ICorkHook_1.RemovedLiquidity(ra, ct, amountRa, amountCt, msg.sender);
        }
    }

    function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory) {
        Action action = abi.decode(data, (Action));

        if (action == Action.AddLiquidity) {
            (, AddLiquidtyParams memory params) = abi.decode(data, (Action, AddLiquidtyParams));

            _addLiquidity(pool[toAmmId_0(params.token0, params.token1)], params.amount0, params.amount1, params.sender);
            return "";
        }

        if (action == Action.RemoveLiquidity) {
            (, RemoveLiquidtyParams memory params) = abi.decode(data, (Action, RemoveLiquidtyParams));

            _removeLiquidity(pool[toAmmId_0(params.token0, params.token1)], params.liquidityAmount, params.sender);
            return "";
        }

        if (action == Action.Swap) {
            (, SwapParams memory params) = abi.decode(data, (Action, SwapParams));

            _initSwap(params);
        }

        return "";
    }

    function getLiquidityToken(address ra, address ct) external view onlyInitialized(ra, ct) returns (address) {
        return address(pool[toAmmId_0(ra, ct)].liquidityToken);
    }

    function getReserves(address ra, address ct) external view onlyInitialized(ra, ct) returns (uint256, uint256) {
        AmmId ammId = toAmmId_0(ra, ct);

        uint256 reserve0 = pool[ammId].reserve0;
        uint256 reserve1 = pool[ammId].reserve1;

        // we sort according what user requested
        return ra < ct ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta delta, uint24) {
        PoolState storage self = pool[toAmmId_0(Currency.unwrap(key.currency0), Currency.unwrap(key.currency1))];
        // kinda packed, avoid stack too deep

        delta = toBeforeSwapDelta(-int128(params.amountSpecified), int128(_beforeSwap(self, params, hookData, sender)));

        // TODO: do we really need to specify the fee here?
        return (this.beforeSwap.selector, delta, 0);
    }

    // logically the flow is
    // 1. the hook settle the output token first, to create a debit. this enable flash swap
    // 2. token is transferred to the user using forwarder or router
    // 3 the user/router settle(pay) the input token
    // 4. the hook take the input token
    function _beforeSwap(
        PoolState storage self,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData,
        address sender
    ) internal returns (int256 unspecificiedAmount) {
        bool exactIn = (params.amountSpecified < 0);
        uint256 amountIn;
        uint256 amountOut;
        // the fee here will always refer to the input token
        uint256 fee;

        (Currency input, Currency output) = _getInputOutput(self, params.zeroForOne);

        // we calculate how much they must pay
        if (exactIn) {
            amountIn = uint256(-params.amountSpecified);
            amountIn = normalize_2(input, amountIn);
            (amountOut, fee) = _getAmountOut(self, params.zeroForOne, amountIn);
        } else {
            amountOut = uint256(params.amountSpecified);
            amountOut = normalize_2(output, amountOut);
            (amountIn, fee) = _getAmountIn(self, params.zeroForOne, amountOut);
        }

        // if exact in, the hook must goes into "debt" equal to amount out
        // since at that point, the user specifies how much token they wanna swap. you can think of it like
        //
        // EXACT IN :
        // specifiedDelta : unspecificiedDelta =  how much input token user want to swap : how much the hook must give
        //
        // EXACT OUT :
        // unspecificiedDelta : specifiedDelta =  how much output token the user wants : how much input token user must pay
        unspecificiedAmount = exactIn ? -int256(toNative_0(output, amountOut)) : int256(toNative_0(input, amountIn));

        self.ensureLiquidityEnoughAsNative(amountOut, Currency.unwrap(output));

        // update reserve
        self.updateReservesAsNative(Currency.unwrap(output), amountOut, true);

        // we transfer their tokens, i.e we settle the output token first so that the user can take the input token
        settleNormalized(output, poolManager, address(this), amountOut, true);

        // there is data, means flash swap
        if (hookData.length > 0) {
            // will 0 if user pay with the same token
            unspecificiedAmount = _executeFlashSwap(self, hookData, input, output, amountIn, amountOut, sender, exactIn);
            // no data, means normal swap
        } else {
            // update reserve
            self.updateReservesAsNative(Currency.unwrap(input), amountIn, false);

            // settle swap, i.e we take the input token from the pool manager, the debt will be payed by the user
            takeNormalized(input, poolManager, address(this), amountIn, true);

            // forward token to user if caller is forwarder
            if (sender == address(forwarder)) {
                forwarder.forwardToken(input, output, amountIn, amountOut);
            }
        }

        // IMPORTANT: we won't compare K right now since the K amount will never be the same and have slight imprecision.
        // but this is fine since the hook knows how much tokens it should receive and give based on the balance delta which it calculate from the invariants

        // split fee from input token
        _splitFee(self, fee, input);

        {
            // the true caller, we try to infer this by checking if the sender is the forwarder, we can get the true caller from
            // the forwarder transient slot
            // if not then we fallback to whoever is the sender
            address actualSender = sender == address(forwarder) ? forwarder.getCurrentSender() : sender;

            (uint256 baseFeePercentage, uint256 actualFeePercentage) = _getFee(self);

            emit ICorkHook_1.Swapped(
                Currency.unwrap(input),
                Currency.unwrap(output),
                toNative_0(input, amountIn),
                toNative_0(output, amountOut),
                actualSender,
                baseFeePercentage,
                actualFeePercentage
            );
        }
    
    }

    function _splitFee(PoolState storage self, uint256 fee, Currency _token) internal {
        address token = Currency.unwrap(_token);
        
        // split fee
        uint256 treasuryAttributed = SwapMath.calculatePercentage(fee, self.treasurySplitPercentage);
        self.updateReservesAsNative(token, treasuryAttributed, true);

        // take and settle fee token from manager
        settleNormalized(_token, poolManager, address(this), treasuryAttributed, true);
        takeNormalized(_token, poolManager, address(this), treasuryAttributed, false);
        
        // send fee to treasury
        ITreasury config = ITreasury(owner());
        address treasury = config.treasury();

        TransferHelper_1.transferNormalize(token, treasury, treasuryAttributed);
    }

    function getFee(address ra, address ct)
        external
        view
        onlyInitialized(ra, ct)
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage)
    {
        PoolState storage self = pool[toAmmId_0(ra, ct)];

        (baseFeePercentage, actualFeePercentage) = _getFee(self);
    }

    function _getFee(PoolState storage self)
        internal
        view
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage)
    {
        baseFeePercentage = self.fee;

        (uint256 start, uint256 end) = _getIssuedAndMaturationTime(self);
        actualFeePercentage = SwapMath.getFeePercentage(baseFeePercentage, start, end, block.timestamp);
    }

    function _executeFlashSwap(
        PoolState storage self,
        bytes calldata hookData,
        Currency input,
        Currency output,
        uint256 amountIn,
        uint256 amountOut,
        address sender,
        bool exactIn
    ) internal returns (int256 unspecificiedAmount) {
        // exact in doesn't make sense on flash swap
        if (exactIn) {
            revert IErrors_1.NoExactIn();
        }

        {
            // send funds to the user
            try forwarder.forwardTokenUncheked(output, amountOut) {}
            // if failed then the user directly calls pool manager to flash swap, in that case we must send their token directly here
            catch {
                takeNormalized(input, poolManager, sender, amountIn, false);
            }

            // we expect user to use exact output swap when dealing with flash swap
            // so we use amountIn as the payment amount cause they they have to pay with the other token
            (uint256 paymentAmount, address paymentToken) = (amountIn, Currency.unwrap(input));

            // we convert the payment amount to the native decimals, fso that integrator contract can use it directly
            paymentAmount = toNative_1(paymentToken, paymentAmount);

            // call the callback
            CorkSwapCallback(sender).CorkCall(sender, hookData, paymentAmount, paymentToken, address(poolManager));
        }

        // process repayments

        // update reserve
        self.updateReservesAsNative(Currency.unwrap(input), amountIn, false);

        // settle swap, i.e we take the input token from the pool manager, the debt will be payed by the user, at this point, the user should've created a debit on the PM
        takeNormalized(input, poolManager, address(this), amountIn, true);

        // this is similar to normal swap, the unspecified amount is the other tokens
        // if exact in, the hook must goes into "debt" equal to amount out
        // since at that point, the user specifies how much token they wanna swap. you can think of it like
        //
        // EXACT IN :
        // specifiedDelta : unspecificiedDelta =  how much input token user want to swap : how much the hook must give
        //
        // EXACT OUT :
        // unspecificiedDelta : specifiedDelta =  how much output token the user wants : how much input token user must pay
        //
        // since in this case, exact in swap doesn't really make sense, we just return the amount in
        unspecificiedAmount = int256(toNative_0(input, amountIn));
    }

    function _getAmountIn(PoolState storage self, bool zeroForOne, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn, uint256 fee)
    {
        if (amountOut <= 0) {
            revert IErrors_1.InvalidAmount();
        }

        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (self.reserve0, self.reserve1) : (self.reserve1, self.reserve0);

        (Currency input, Currency output) = _getInputOutput(self, zeroForOne);

        reserveIn = normalize_2(input, reserveIn);
        reserveOut = normalize_2(output, reserveOut);

        if (reserveIn <= 0 || reserveOut <= 0) {
            revert IErrors_1.NotEnoughLiquidity();
        }

        uint256 oneMinusT = _1MinT(self);
        (amountIn, fee) = SwapMath.getAmountIn(amountOut, reserveIn, reserveOut, oneMinusT, self.fee);
    }

    function getAmountIn(address ra, address ct, bool raForCt, uint256 amountOut)
        external
        view
        onlyInitialized(ra, ct)
        returns (uint256 amountIn)
    {
        (address token0, address token1) = sort_0(ra, ct);
        // infer zero to one
        bool zeroForOne = raForCt ? (token0 == ra) : (token0 == ct);

        PoolState storage self = pool[toAmmId_0(token0, token1)];

        address inToken = zeroForOne ? token0 : token1;
        address outToken = zeroForOne ? token1 : token0;

        // we need to normalize the amount out, since we calculate everything in 18 decimals
        amountOut = normalize_1(outToken, amountOut);
        (amountIn,) = _getAmountIn(self, zeroForOne, amountOut);

        // convert to the proper decimals
        amountIn = TransferHelper_1.fixedToTokenNativeDecimals(amountIn, inToken);
    }

    function _getAmountOut(PoolState storage self, bool zeroForOne, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut, uint256 fee)
    {
        if (amountIn <= 0) {
            revert IErrors_1.InvalidAmount();
        }

        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (self.reserve0, self.reserve1) : (self.reserve1, self.reserve0);

        (Currency input, Currency output) = _getInputOutput(self, zeroForOne);

        reserveIn = normalize_2(input, reserveIn);
        reserveOut = normalize_2(output, reserveOut);

        if (reserveIn <= 0 || reserveOut <= 0) {
            revert IErrors_1.NotEnoughLiquidity();
        }

        uint256 oneMinusT = _1MinT(self);
        (amountOut, fee) = SwapMath.getAmountOut(amountIn, reserveIn, reserveOut, oneMinusT, self.fee);
    }

    function getAmountOut(address ra, address ct, bool raForCt, uint256 amountIn)
        external
        view
        onlyInitialized(ra, ct)
        returns (uint256 amountOut)
    {
        (address token0, address token1) = sort_0(ra, ct);
        // infer zero to one
        bool zeroForOne = raForCt ? (token0 == ra) : (token0 == ct);

        address inToken = zeroForOne ? token0 : token1;
        address outToken = zeroForOne ? token1 : token0;

        PoolState storage self = pool[toAmmId_0(token0, token1)];

        // we need to normalize the amount out, since we calculate everything in 18 decimals
        amountIn = normalize_1(inToken, amountIn);
        (amountOut,) = _getAmountOut(self, zeroForOne, amountIn);

        amountOut = normalize_1(outToken, amountOut);
    }

    function _getInputOutput(PoolState storage self, bool zeroForOne)
        internal
        view
        returns (Currency input, Currency output)
    {
        (address _input, address _output) = zeroForOne ? (self.token0, self.token1) : (self.token1, self.token0);
        return (Currency.wrap(_input), Currency.wrap(_output));
    }

    function _saveIssuedAndMaturationTime(PoolState storage self) internal {
        IExpiry_0 token0 = IExpiry_0(self.token0);
        IExpiry_0 token1 = IExpiry_0(self.token1);

        try token0.issuedAt() returns (uint256 issuedAt0) {
            self.startTimestamp = issuedAt0;
            self.endTimestamp = token0.expiry();
            return;
        } catch {}

        try token1.issuedAt() returns (uint256 issuedAt1) {
            self.startTimestamp = issuedAt1;
            self.endTimestamp = token1.expiry();
            return;
        } catch {}

        revert IErrors_1.InvalidToken();
    }

    function _getIssuedAndMaturationTime(PoolState storage self) internal view returns (uint256 start, uint256 end) {
        return (self.startTimestamp, self.endTimestamp);
    }

    function _1MinT(PoolState storage self) internal view returns (uint256) {
        (uint256 start, uint256 end) = _getIssuedAndMaturationTime(self);
        return SwapMath.oneMinusT(start, end, block.timestamp);
    }

    function getPoolKey(address ra, address ct) public view returns (PoolKey memory) {
        (address token0, address token1) = sort_0(ra, ct);
        return PoolKey(
            Currency.wrap(token0), Currency.wrap(token1), Constants.FEE, Constants.TICK_SPACING, IHooks(address(this))
        );
    }

    function getPoolManager() external view returns (address) {
        return address(poolManager);
    }

    function getForwarder() external view returns (address) {
        return address(forwarder);
    }

    function getMarketSnapshot(address ra, address ct) external view returns (MarketSnapshot memory snapshot) {
        PoolState storage self = pool[toAmmId_0(ra, ct)];

        // sort reserve according user input
        uint256 raReserve = self.token0 == ra ? self.reserve0 : self.reserve1;
        uint256 ctReserve = self.token0 == ct ? self.reserve0 : self.reserve1;

        snapshot.baseFee = self.fee;
        snapshot.liquidityToken = address(self.liquidityToken);
        snapshot.oneMinusT = _1MinT(self);
        snapshot.ra = ra;
        snapshot.ct = ct;
        snapshot.reserveRa = raReserve;
        snapshot.reserveCt = ctReserve;
        snapshot.startTimestamp = self.startTimestamp;
        snapshot.endTimestamp = self.endTimestamp;
        snapshot.treasuryFeePercentage = self.treasurySplitPercentage;
    }
}

// contracts/core/flash-swaps/FlashSwapRouter.sol

/**
 * @title Router contract for Flashswap
 * @author Cork Team
 * @notice Router contract for implementing flashswaps for DS/CT
 */
contract RouterState is
    IDsFlashSwapUtility,
    IDsFlashSwapCore,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    CorkSwapCallback
{
    using DsFlashSwaplibrary for ReserveState;
    using DsFlashSwaplibrary for AssetPair;
    using SafeERC20 for IERC20;

    bytes32 public constant MODULE_CORE = keccak256("MODULE_CORE");
    bytes32 public constant CONFIG = keccak256("CONFIG");

    // 30% max fee
    uint256 public constant MAX_DS_FEE = 30e18;

    address public _moduleCore;
    ICorkHook_0 public hook;
    CorkConfig public config;
    mapping(Id => ReserveState) internal reserves;

    // this is here to prevent stuck funds, essentially it can happen that the reserve DS is so low but not empty,
    // when the router tries to sell it, the trade fails, preventing user from buying DS properly
    uint256 public constant RESERVE_MINIMUM_SELL_AMOUNT = 0.001 ether;

    struct CalculateAndSellDsParams {
        Id reserveId;
        uint256 dsId;
        uint256 amount;
        IDsFlashSwapCore.BuyAprroxParams approxParams;
        IDsFlashSwapCore.OffchainGuess offchainGuess;
        uint256 initialBorrowedAmount;
        uint256 initialAmountOut;
    }

    struct SellDsParams {
        Id reserveId;
        uint256 dsId;
        uint256 amountSellFromReserve;
        uint256 amount;
        BuyAprroxParams approxParams;
    }

    struct SellResult {
        uint256 amountOut;
        uint256 borrowedAmount;
        bool success;
    }

    struct CallbackData {
        bool buyDs;
        address caller;
        // CT or RA amount borrowed
        uint256 borrowed;
        // DS or RA amount provided
        uint256 provided;
        Id reserveId;
        uint256 dsId;
    }

    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    modifier onlyDefaultAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotDefaultAdmin();
        }
        _;
    }

    modifier onlyModuleCore() {
        if (!hasRole(MODULE_CORE, msg.sender)) {
            revert NotModuleCore();
        }
        _;
    }

    modifier onlyConfig() {
        if (!hasRole(CONFIG, msg.sender)) {
            revert NotConfig();
        }
        _;
    }

    modifier autoClearReturnData() {
        _;
        ReturnDataSlotLib.clear(ReturnDataSlotLib.RETURN_SLOT);
        ReturnDataSlotLib.clear(ReturnDataSlotLib.REFUNDED_SLOT);
        ReturnDataSlotLib.clear(ReturnDataSlotLib.DS_FEE_AMOUNT);
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _config) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONFIG, _config);
        config = CorkConfig(_config);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyDefaultAdmin {}

    function updateDiscountRateInDdays(Id id, uint256 discountRateInDays) external override onlyConfig {
        reserves[id].decayDiscountRateInDays = discountRateInDays;

        emit DiscountRateUpdated(id, discountRateInDays);
    }

    function updateGradualSaleStatus(Id id, bool status) external override onlyConfig {
        reserves[id].gradualSaleDisabled = status;

        emit GradualSaleStatusUpdated(id, status);
    }

    function updateDsExtraFeePercentage(Id id, uint256 newPercentage) external onlyConfig {
        if (newPercentage > MAX_DS_FEE) {
            revert InvalidFee();
        }
        reserves[id].dsExtraFeePercentage = newPercentage;

        emit DsFeeUpdated(id, newPercentage);
    }

    function updateDsExtraFeeTreasurySplitPercentage(Id id, uint256 newPercentage) external onlyConfig {
        reserves[id].dsExtraFeeTreasurySplitPercentage = newPercentage;

        emit DsFeeTreasuryPercentageUpdated(id, newPercentage);
    }

    function getCurrentCumulativeHIYA(Id id) external view returns (uint256 hpaCummulative) {
        hpaCummulative = reserves[id].getCurrentCumulativeHIYA();
    }

    function getCurrentEffectiveHIYA(Id id) external view returns (uint256 hpa) {
        hpa = reserves[id].getEffectiveHIYA();
    }

    function setModuleCore(address moduleCore) external onlyDefaultAdmin {
        if (moduleCore == address(0)) {
            revert ZeroAddress();
        }
        _moduleCore = moduleCore;
        _grantRole(MODULE_CORE, moduleCore);
    }

    function updateReserveSellPressurePercentage(Id id, uint256 newPercentage) external override onlyConfig {
        reserves[id].updateReserveSellPressurePercentage(newPercentage);

        emit ReserveSellPressurePercentageUpdated(id, newPercentage);
    }

    function setHook(address _hook) external onlyDefaultAdmin {
        hook = ICorkHook_0(_hook);
    }

    function onNewIssuance(Id reserveId, uint256 dsId, address ds, address ra, address ct)
        external
        override
        onlyModuleCore
    {
        reserves[reserveId].onNewIssuance(dsId, ds, ra, ct);

        emit NewIssuance(reserveId, dsId, ds, AmmId.unwrap(toAmmId_0(ra, ct)));
    }

    /// @notice set the discount rate rate and rollover for the new issuance
    /// @dev needed to avoid stack to deep errors. MUST be called after onNewIssuance and only by moduleCore at new issuance
    function setDecayDiscountAndRolloverPeriodOnNewIssuance(
        Id reserveId,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks
    ) external override onlyModuleCore {
        ReserveState storage self = reserves[reserveId];
        self.decayDiscountRateInDays = decayDiscountRateInDays;
        self.rolloverEndInBlockNumber = block.number + rolloverPeriodInblocks;
    }

    function getAmmReserve(Id id, uint256 dsId) external view override returns (uint256 raReserve, uint256 ctReserve) {
        (raReserve, ctReserve) = reserves[id].getReserve(dsId, hook);
    }

    function getLvReserve(Id id, uint256 dsId) external view override returns (uint256 lvReserve) {
        return reserves[id].ds[dsId].lvReserve;
    }

    function getPsmReserve(Id id, uint256 dsId) external view override returns (uint256 psmReserve) {
        return reserves[id].ds[dsId].psmReserve;
    }

    function emptyReserveLv(Id reserveId, uint256 dsId) external override onlyModuleCore returns (uint256 amount) {
        amount = reserves[reserveId].emptyReserveLv(dsId, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePartialLv(Id reserveId, uint256 dsId, uint256 amount)
        external
        override
        onlyModuleCore
        returns (uint256 emptied)
    {
        emptied = reserves[reserveId].emptyReservePartialLv(dsId, amount, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePsm(Id reserveId, uint256 dsId) external override onlyModuleCore returns (uint256 amount) {
        amount = reserves[reserveId].emptyReservePsm(dsId, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function emptyReservePartialPsm(Id reserveId, uint256 dsId, uint256 amount)
        external
        override
        onlyModuleCore
        returns (uint256 emptied)
    {
        emptied = reserves[reserveId].emptyReservePartialPsm(dsId, amount, _moduleCore);
        emit ReserveEmptied(reserveId, dsId, amount);
    }

    function getCurrentPriceRatio(Id id, uint256 dsId)
        external
        view
        override
        returns (uint256 raPriceRatio, uint256 ctPriceRatio)
    {
        (raPriceRatio, ctPriceRatio) = reserves[id].getPriceRatio(dsId, hook);
    }

    function addReserveLv(Id id, uint256 dsId, uint256 amount) external override onlyModuleCore {
        reserves[id].addReserveLv(dsId, amount, _moduleCore);
        emit ReserveAdded(id, dsId, amount);
    }

    function addReservePsm(Id id, uint256 dsId, uint256 amount) external override onlyModuleCore {
        reserves[id].addReservePsm(dsId, amount, _moduleCore);
        emit ReserveAdded(id, dsId, amount);
    }

    /// will return that can't be filled from the reserve, this happens when the total reserve is less than the amount requested
    function _swapRaForDsViaRollover(Id reserveId, uint256 dsId, address user, uint256 amountRa)
        internal
        returns (uint256 raLeft, uint256 dsReceived)
    {
        // this means that we ignore and don't do rollover sale when it's first issuance or it's not rollover time, or no hiya(means no trade, unlikely but edge case)
        if (
            dsId == DsFlashSwaplibrary.FIRST_ISSUANCE || !reserves[reserveId].rolloverSale()
                || reserves[reserveId].hiya == 0
        ) {
            // noop and return back the full amountRa
            return (amountRa, 0);
        }

        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        // If there's no reserve, we will proceed without using rollover
        if (assetPair.lvReserve == 0 && assetPair.psmReserve == 0) {
            return (amountRa, 0);
        }

        amountRa = TransferHelper_0.tokenNativeDecimalsToFixed(amountRa, reserves[reserveId].ds[dsId].ra);

        uint256 lvProfit;
        uint256 psmProfit;
        uint256 lvReserveUsed;
        uint256 psmReserveUsed;

        (lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed) =
            SwapperMathLibrary.calculateRolloverSale(assetPair.lvReserve, assetPair.psmReserve, amountRa, self.hiya);

        amountRa = TransferHelper_0.fixedToTokenNativeDecimals(amountRa, assetPair.ra);
        raLeft = TransferHelper_0.fixedToTokenNativeDecimals(raLeft, assetPair.ra);

        assetPair.psmReserve = assetPair.psmReserve - psmReserveUsed;
        assetPair.lvReserve = assetPair.lvReserve - lvReserveUsed;

        // we first transfer and normalized the amount, we get back the actual normalized amount
        psmProfit = TransferHelper_0.transferNormalize(assetPair.ra, _moduleCore, psmProfit);
        lvProfit = TransferHelper_0.transferNormalize(assetPair.ra, _moduleCore, lvProfit);

        assert(psmProfit + lvProfit <= amountRa);

        // then use the profit
        IPSMcore(_moduleCore).psmAcceptFlashSwapProfit(reserveId, psmProfit);
        IVault(_moduleCore).lvAcceptRolloverProfit(reserveId, lvProfit);

        IERC20(assetPair.ds).safeTransfer(user, dsReceived);

        {
            uint256 raLeftNormalized = TransferHelper_0.fixedToTokenNativeDecimals(raLeft, assetPair.ra);
            emit RolloverSold(reserveId, dsId, user, dsReceived, raLeftNormalized);
        }
    }

    function rolloverSaleEnds(Id reserveId) external view returns (uint256 endInBlockNumber) {
        return reserves[reserveId].rolloverEndInBlockNumber;
    }

    function _swapRaforDs(
        ReserveState storage self,
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address user,
        IDsFlashSwapCore.BuyAprroxParams memory approxParams,
        IDsFlashSwapCore.OffchainGuess memory offchainGuess
    ) internal returns (uint256 initialBorrowedAmount, uint256 finalBorrowedAmount) {
        uint256 dsReceived;
        // try to swap the RA for DS via rollover, this will noop if the condition for rollover is not met
        (amount, dsReceived) = _swapRaForDsViaRollover(reserveId, dsId, user, amount);

        // short circuit if all the swap is filled using rollover
        if (amount == 0) {
            // we directly increase the return data slot value with DS that the user got from rollover sale here since,
            // there's no possibility of selling the reserve, hence no chance of mix-up of return value
            ReturnDataSlotLib.increase(ReturnDataSlotLib.RETURN_SLOT, dsReceived);
            return (0, 0);
        }

        {
            uint256 amountOut;
            if (offchainGuess.initialBorrowAmount == 0) {
                // calculate the amount of DS tokens attributed
                (amountOut, finalBorrowedAmount) = getAmountOutBuyDs(assetPair, hook, approxParams, amount);
                initialBorrowedAmount = finalBorrowedAmount;
            } else {
                // we convert the amount to fixed point 18 decimals since, the amount out will be DS, and DS is always 18 decimals.
                amountOut =
                    TransferHelper_0.tokenNativeDecimalsToFixed(offchainGuess.initialBorrowAmount + amount, assetPair.ra);
                finalBorrowedAmount = offchainGuess.initialBorrowAmount;
                initialBorrowedAmount = offchainGuess.initialBorrowAmount;
            }

            (finalBorrowedAmount, amount) = calculateAndSellDsReserve(
                self,
                assetPair,
                CalculateAndSellDsParams(
                    reserveId, dsId, amount, approxParams, offchainGuess, finalBorrowedAmount, amountOut
                )
            );
        }
        // increase the return data slot value with DS that the user got from rollover sale
        // the reason we do this after selling the DS reserve is to prevent mix-up of return value
        // basically, the return value is increased when the reserve sell DS, but that value is meant for thr vault/psm
        // so we clear them and start with a clean transient storage slot
        ReturnDataSlotLib.clear(ReturnDataSlotLib.RETURN_SLOT);
        ReturnDataSlotLib.increase(ReturnDataSlotLib.RETURN_SLOT, dsReceived);

        // trigger flash swaps and send the attributed DS tokens to the user
        __flashSwap(assetPair, finalBorrowedAmount, 0, dsId, reserveId, true, user, amount);
    }

    function getAmountOutBuyDs(
        AssetPair storage assetPair,
        ICorkHook_0 hook,
        BuyAprroxParams memory approxParams,
        uint256 amount
    ) internal view returns (uint256 amountOut, uint256 borrowedAmount) {
        try assetPair.getAmountOutBuyDS(amount, hook, approxParams) returns (
            uint256 _amountOut, uint256 _borrowedAmount
        ) {
            amountOut = _amountOut;
            borrowedAmount = _borrowedAmount;
        } catch {
            revert IErrors_0.InvalidPoolStateOrNearExpired();
        }
    }

    function calculateAndSellDsReserve(
        ReserveState storage self,
        AssetPair storage assetPair,
        CalculateAndSellDsParams memory params
    ) internal returns (uint256 borrowedAmount, uint256 amount) {
        // we initially set this to the initial amount user supplied, later we will charge a fee on this.
        amount = params.amount;
        // calculate the amount of DS tokens that will be sold from reserve
        uint256 amountSellFromReserve = calculateSellFromReserve(self, params.initialAmountOut, params.dsId);

        if (amountSellFromReserve < RESERVE_MINIMUM_SELL_AMOUNT || self.gradualSaleDisabled) {
            return (params.initialBorrowedAmount, amount);
        }

        bool success = _sellDsReserve(
            assetPair, SellDsParams(params.reserveId, params.dsId, amountSellFromReserve, amount, params.approxParams)
        );

        if (!success) {
            return (params.initialBorrowedAmount, amount);
        }

        amount = takeDsFee(self, assetPair, params.reserveId, amount);

        // we calculate the borrowed amount if user doesn't supply offchain guess
        if (params.offchainGuess.afterSoldBorrowAmount == 0) {
            (, borrowedAmount) = getAmountOutBuyDs(assetPair, hook, params.approxParams, amount);
        } else {
            borrowedAmount = params.offchainGuess.afterSoldBorrowAmount;
        }
    }

    function takeDsFee(ReserveState storage self, AssetPair storage pair, Id reserveId, uint256 amount)
        internal
        returns (uint256 amountLeft)
    {
        uint256 fee = SwapperMathLibrary.calculateDsExtraFee(
            amount, self.reserveSellPressurePercentage, self.dsExtraFeePercentage
        );

        if (fee == 0) {
            return amount;
        }

        amountLeft = amount - fee;

        // increase the fee amount in transient slot
        ReturnDataSlotLib.increase(ReturnDataSlotLib.DS_FEE_AMOUNT, fee);

        uint256 attributedToTreasury =
            SwapperMathLibrary.calculatePercentage(fee, self.dsExtraFeeTreasurySplitPercentage);
        uint256 attributedToVault = fee - attributedToTreasury;

        assert(attributedToTreasury + attributedToVault == fee);

        // we calculate it in native decimals, should go through
        IERC20(address(pair.ra)).safeTransfer(_moduleCore, attributedToVault);
        IVault(_moduleCore).provideLiquidityWithFlashSwapFee(reserveId, attributedToVault);

        address treasury = config.treasury();
        IERC20(address(pair.ra)).safeTransfer(treasury, attributedToTreasury);
    }

    function calculateSellFromReserve(ReserveState storage self, uint256 amountOut, uint256 dsId)
        internal
        view
        returns (uint256 amount)
    {
        AssetPair storage assetPair = self.ds[dsId];

        uint256 amountSellFromReserve =
            amountOut - MathHelper.calculatePercentageFee(self.reserveSellPressurePercentage, amountOut);

        uint256 lvReserve = assetPair.lvReserve;
        uint256 totalReserve = lvReserve + assetPair.psmReserve;

        // sell all tokens if the sell amount is higher than the available reserve
        amount = totalReserve < amountSellFromReserve ? totalReserve : amountSellFromReserve;
    }

    function _sellDsReserve(AssetPair storage assetPair, SellDsParams memory params) internal returns (bool success) {
        uint256 profitRa;

        // sell the DS tokens from the reserve and accrue value to LV holders
        // it's safe to transfer all profit to the module core since the profit for each PSM and LV is calculated separately and we invoke
        // the profit acceptance function for each of them
        //
        // this function can fail, if there's not enough CT liquidity to sell the DS tokens, in that case, we skip the selling part and let user buy the DS tokens
        (profitRa, success) =
            __swapDsforRa(assetPair, params.reserveId, params.dsId, params.amountSellFromReserve, 0, _moduleCore);

        if (success) {
            uint256 lvReserve = assetPair.lvReserve;
            uint256 totalReserve = lvReserve + assetPair.psmReserve;

            // calculate the amount of DS tokens that will be sold from both reserve
            uint256 lvReserveUsed = lvReserve * params.amountSellFromReserve * 1e18 / (totalReserve) / 1e18;

            // decrement reserve
            assetPair.lvReserve -= lvReserveUsed;
            assetPair.psmReserve -= params.amountSellFromReserve - lvReserveUsed;

            // calculate the profit of the liquidity vault
            uint256 vaultProfit = profitRa * lvReserveUsed / params.amountSellFromReserve;

            // send profit to the vault
            IVault(_moduleCore).provideLiquidityWithFlashSwapFee(params.reserveId, vaultProfit);
            // send profit to the PSM
            IPSMcore(_moduleCore).psmAcceptFlashSwapProfit(params.reserveId, profitRa - vaultProfit);
        }
    }

    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes calldata rawRaPermitSig,
        uint256 deadline,
        BuyAprroxParams calldata params,
        OffchainGuess calldata offchainGuess
    ) external autoClearReturnData returns (SwapRaForDsReturn memory result) {
        if (rawRaPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        if (!DsFlashSwaplibrary.isRAsupportsPermit(address(assetPair.ra))) {
            revert PermitNotSupported();
        }

        DepegSwapLibrary.permitForRA(address(assetPair.ra), rawRaPermitSig, msg.sender, address(this), amount, deadline);
        IERC20(assetPair.ra).safeTransferFrom(msg.sender, address(this), amount);

        (result.initialBorrow, result.afterSoldBorrow) =
            _swapRaforDs(self, assetPair, reserveId, dsId, amount, amountOutMin, msg.sender, params, offchainGuess);

        result.amountOut = ReturnDataSlotLib.get(ReturnDataSlotLib.RETURN_SLOT);

        // slippage protection, revert if the amount of DS tokens received is less than the minimum amount
        if (result.amountOut < amountOutMin) {
            revert InsufficientOutputAmountForSwap();
        }

        result.ctRefunded = ReturnDataSlotLib.get(ReturnDataSlotLib.REFUNDED_SLOT);
        result.fee = ReturnDataSlotLib.get(ReturnDataSlotLib.DS_FEE_AMOUNT);

        self.recalculateHIYA(dsId, TransferHelper_0.tokenNativeDecimalsToFixed(amount, assetPair.ra), result.amountOut);

        {
            // we do a conditional here since we won't apply any fee if the router doesn't sold any DS
            uint256 feePercentage = result.fee == 0 ? 0 : self.dsExtraFeePercentage;

            emit RaSwapped(
                reserveId,
                dsId,
                msg.sender,
                amount,
                result.amountOut,
                result.ctRefunded,
                result.fee,
                feePercentage,
                self.reserveSellPressurePercentage
            );
        }
    }

    function swapRaforDs(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        BuyAprroxParams calldata params,
        OffchainGuess calldata offchainGuess
    ) external autoClearReturnData returns (SwapRaForDsReturn memory result) {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        IERC20(assetPair.ra).safeTransferFrom(msg.sender, address(this), amount);

        (result.initialBorrow, result.afterSoldBorrow) =
            _swapRaforDs(self, assetPair, reserveId, dsId, amount, amountOutMin, msg.sender, params, offchainGuess);

        result.amountOut = ReturnDataSlotLib.get(ReturnDataSlotLib.RETURN_SLOT);

        // slippage protection, revert if the amount of DS tokens received is less than the minimum amount
        if (result.amountOut < amountOutMin) {
            revert InsufficientOutputAmountForSwap();
        }

        result.ctRefunded = ReturnDataSlotLib.get(ReturnDataSlotLib.REFUNDED_SLOT);
        result.fee = ReturnDataSlotLib.get(ReturnDataSlotLib.DS_FEE_AMOUNT);

        // we do a conditional here since we won't apply any fee if the router doesn't sold any DS
        uint256 feePercentage = result.fee == 0 ? 0 : self.dsExtraFeePercentage;

        self.recalculateHIYA(dsId, TransferHelper_0.tokenNativeDecimalsToFixed(amount, assetPair.ra), result.amountOut);

        emit RaSwapped(
            reserveId,
            dsId,
            msg.sender,
            amount,
            result.amountOut,
            result.ctRefunded,
            result.fee,
            feePercentage,
            self.reserveSellPressurePercentage
        );
    }

    function isRolloverSale(Id id) external view returns (bool) {
        return reserves[id].rolloverSale();
    }

    function swapDsforRa(
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        bytes calldata rawDsPermitSig,
        uint256 deadline
    ) external autoClearReturnData returns (uint256 amountOut) {
        if (rawDsPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        DepegSwapLibrary.permit(
            address(assetPair.ds), rawDsPermitSig, msg.sender, address(this), amount, deadline, "swapDsforRa"
        );
        assetPair.ds.transferFrom(msg.sender, address(this), amount);

        (, bool success) = __swapDsforRa(assetPair, reserveId, dsId, amount, amountOutMin, msg.sender);

        if (!success) {
            revert IErrors_0.InsufficientLiquidityForSwap();
        }

        amountOut = ReturnDataSlotLib.get(ReturnDataSlotLib.RETURN_SLOT);

        self.recalculateHIYA(dsId, TransferHelper_0.tokenNativeDecimalsToFixed(amountOut, assetPair.ra), amount);

        emit DsSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    /**
     * @notice Swaps DS for RA
     * @param reserveId the reserve id same as the id on PSM and LV
     * @param dsId the ds id of the pair, the same as the DS id on PSM and LV
     * @param amount the amount of DS to swap
     * @param amountOutMin the minimum amount of RA to receive, will revert if the actual amount is less than this. should be inserted with value from previewSwapDsforRa
     * @return amountOut amount of RA that's received
     */
    function swapDsforRa(Id reserveId, uint256 dsId, uint256 amount, uint256 amountOutMin)
        external
        autoClearReturnData
        returns (uint256 amountOut)
    {
        ReserveState storage self = reserves[reserveId];
        AssetPair storage assetPair = self.ds[dsId];

        assetPair.ds.transferFrom(msg.sender, address(this), amount);

        (, bool success) = __swapDsforRa(assetPair, reserveId, dsId, amount, amountOutMin, msg.sender);

        if (!success) {
            revert IErrors_0.InsufficientLiquidityForSwap();
        }

        amountOut = ReturnDataSlotLib.get(ReturnDataSlotLib.RETURN_SLOT);

        self.recalculateHIYA(dsId, TransferHelper_0.tokenNativeDecimalsToFixed(amountOut, assetPair.ra), amount);

        emit DsSwapped(reserveId, dsId, msg.sender, amount, amountOut);
    }

    function __swapDsforRa(
        AssetPair storage assetPair,
        Id reserveId,
        uint256 dsId,
        uint256 amount,
        uint256 amountOutMin,
        address caller
    ) internal returns (uint256 amountOut, bool success) {
        try assetPair.getAmountOutSellDS(amount, hook) returns (uint256 _amountOut, uint256, bool _success) {
            amountOut = _amountOut;
            success = _success;
        } catch {
            return (0, false);
        }

        if (!success) {
            return (amountOut, success);
        }

        if (amountOut < amountOutMin) {
            revert InsufficientOutputAmountForSwap();
        }

        __flashSwap(assetPair, 0, amount, dsId, reserveId, false, caller, amount);
    }

    function __flashSwap(
        AssetPair storage assetPair,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 dsId,
        Id reserveId,
        bool buyDs,
        address caller,
        // DS or RA amount provided
        uint256 provided
    ) internal {
        uint256 borrowed = buyDs ? raAmount : ctAmount;
        CallbackData memory callbackData = CallbackData(buyDs, caller, borrowed, provided, reserveId, dsId);

        bytes memory data = abi.encode(callbackData);

        hook.swap(address(assetPair.ra), address(assetPair.ct), raAmount, ctAmount, data);
    }

    function CorkCall(
        address sender,
        bytes calldata data,
        uint256 paymentAmount,
        address paymentToken,
        address poolManager
    ) external {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        ReserveState storage self = reserves[callbackData.reserveId];

        {
            // make sure only hook and forwarder can call this function
            assert(msg.sender == address(hook) || msg.sender == address(hook.getForwarder()));
            assert(sender == address(this));
        }

        if (callbackData.buyDs) {
            assert(paymentToken == address(self.ds[callbackData.dsId].ct));

            __afterFlashswapBuy(
                self,
                callbackData.reserveId,
                callbackData.dsId,
                callbackData.caller,
                callbackData.provided,
                callbackData.borrowed,
                poolManager,
                paymentAmount
            );
        } else {
            assert(paymentToken == address(self.ds[callbackData.dsId].ra));

            // same as borrowed since we're redeeming the same number of DS tokens with CT
            __afterFlashswapSell(
                self,
                callbackData.borrowed,
                callbackData.reserveId,
                callbackData.dsId,
                callbackData.caller,
                poolManager,
                paymentAmount
            );
        }
    }

    function __afterFlashswapBuy(
        ReserveState storage self,
        Id reserveId,
        uint256 dsId,
        address caller,
        uint256 provided,
        uint256 borrowed,
        address poolManager,
        uint256 actualRepaymentAmount
    ) internal {
        AssetPair storage assetPair = self.ds[dsId];

        uint256 deposited = provided + borrowed;

        IERC20(assetPair.ra).safeIncreaseAllowance(_moduleCore, deposited);

        IPSMcore psm = IPSMcore(_moduleCore);
        (uint256 received,) = psm.depositPsm(reserveId, deposited);

        // slither-disable-next-line uninitialized-local
        uint256 repaymentAmount;
        {
            // slither-disable-next-line uninitialized-local
            uint256 refunded;

            // not enough liquidity
            if (actualRepaymentAmount > received) {
                revert IErrors_0.InsufficientLiquidityForSwap();
            } else {
                refunded = received - actualRepaymentAmount;
                repaymentAmount = actualRepaymentAmount;
            }

            if (refunded > 0) {
                // refund the user with extra ct
                assetPair.ct.transfer(caller, refunded);
            }

            ReturnDataSlotLib.increase(ReturnDataSlotLib.REFUNDED_SLOT, refunded);
        }

        // send caller their DS
        assetPair.ds.transfer(caller, received);
        // repay flash loan
        assetPair.ct.transfer(poolManager, repaymentAmount);

        // set the return data slot
        ReturnDataSlotLib.increase(ReturnDataSlotLib.RETURN_SLOT, received);
    }

    function __afterFlashswapSell(
        ReserveState storage self,
        uint256 ctAmount,
        Id reserveId,
        uint256 dsId,
        address caller,
        address poolManager,
        uint256 actualRepaymentAmount
    ) internal {
        AssetPair storage assetPair = self.ds[dsId];

        IERC20(address(assetPair.ds)).safeIncreaseAllowance(_moduleCore, ctAmount);
        IERC20(address(assetPair.ct)).safeIncreaseAllowance(_moduleCore, ctAmount);

        IPSMcore psm = IPSMcore(_moduleCore);

        uint256 received = psm.returnRaWithCtDs(reserveId, ctAmount);

        Asset ra = assetPair.ra;

        if (actualRepaymentAmount > received) {
            revert IErrors_0.InsufficientLiquidityForSwap();
        }

        received = received - actualRepaymentAmount;

        // send caller their RA
        IERC20(ra).safeTransfer(caller, received);
        // repay flash loan
        IERC20(ra).safeTransfer(poolManager, actualRepaymentAmount);

        ReturnDataSlotLib.increase(ReturnDataSlotLib.RETURN_SLOT, received);
    }
}

// contracts/core/ModuleCore.sol

/**
 * @title ModuleCore Contract
 * @author Cork Team
 * @notice Modulecore contract for integrating abstract modules like PSM and Vault contracts
 */
contract ModuleCore is OwnableUpgradeable, UUPSUpgradeable, PsmCore, Initialize, VaultCore {
    /// @notice __gap variable to prevent storage collisions
    // slither-disable-next-line unused-state
    uint256[49] private __gap;

    using PsmLibrary for State;
    using PairLibrary for Pair;

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer function for upgradeable contracts
    function initialize(address _swapAssetFactory, address _ammHook, address _flashSwapRouter, address _config)
        external
        initializer
    {
        if (
            _swapAssetFactory == address(0) || _ammHook == address(0) || _flashSwapRouter == address(0)
                || _config == address(0)
        ) {
            revert ZeroAddress();
        }

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        initializeModuleState(_swapAssetFactory, _ammHook, _flashSwapRouter, _config);
    }

    function setWithdrawalContract(address _withdrawalContract) external {
        onlyConfig();
        _setWithdrawalContract(_withdrawalContract);
    }

    /// @notice Authorization function for UUPS proxy upgrades
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _msgSender() internal view override(ContextUpgradeable, Context) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override(ContextUpgradeable, Context) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view override(ContextUpgradeable, Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    function getId(address pa, address ra, uint256 initialArp, uint256 expiry, address exchangeRateProvider)
        external
        pure
        returns (Id)
    {
        return PairLibrary.initalize(pa, ra, initialArp, expiry, exchangeRateProvider).toId();
    }

    function markets(Id id)
        external
        view
        returns (address pa, address ra, uint256 initialArp, uint256 expiryInterval, address exchangeRateProvider)
    {
        Pair storage pair = states[id].info;
        pa = pair.pa;
        ra = pair.ra;
        initialArp = pair.initialArp;
        expiryInterval = pair.expiryInterval;
        exchangeRateProvider = pair.exchangeRateProvider;
    }

    function initializeModuleCore(
        address pa,
        address ra,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider
    ) external override {
        onlyConfig();
        if (expiryInterval == 0) {
            revert InvalidExpiry();
        }
        Pair memory key = PairLibrary.initalize(pa, ra, initialArp, expiryInterval, exchangeRateProvider);
        Id id = key.toId();

        State storage state = states[id];

        if (state.isInitialized()) {
            revert AlreadyInitialized();
        }

        IAssetFactory assetsFactory = IAssetFactory(SWAP_ASSET_FACTORY);

        address lv = assetsFactory.deployLv(ra, pa, address(this), initialArp, expiryInterval, exchangeRateProvider);

        PsmLibrary.initialize(state, key);
        VaultLibrary.initialize(state.vault, lv, ra, initialArp);

        emit InitializedModuleCore(id, pa, ra, lv, expiryInterval, initialArp, exchangeRateProvider);
    }

    function issueNewDs(
        Id id,
        uint256 decayDiscountRateInDays,
        uint256 rolloverPeriodInblocks,
        uint256 ammLiquidationDeadline
    ) external override {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];

        Pair storage info = state.info;

        // we update the rate, if this is a yield bearing PA then the rate should go up.
        // that's why there's no check that prevents the rate from going up.
        uint256 exchangeRates = PsmLibrary._getLatestRate(state);

        (address ct, address ds) = IAssetFactory(SWAP_ASSET_FACTORY).deploySwapAssets(
            IAssetFactory.DeployParams(
                info.ra,
                state.info.pa,
                address(this),
                info.initialArp,
                info.expiryInterval,
                info.exchangeRateProvider,
                exchangeRates,
                state.globalAssetIdx + 1
            )
        );

        // avoid stack to deep error
        _initOnNewIssuance(id, ct, ds, info.expiryInterval);
        // avoid stack to deep error
        getRouterCore().setDecayDiscountAndRolloverPeriodOnNewIssuance(
            id, decayDiscountRateInDays, rolloverPeriodInblocks
        );
        VaultLibrary.onNewIssuance(
            state, state.globalAssetIdx - 1, getRouterCore(), getAmmRouter(), ammLiquidationDeadline
        );
    }

    function _initOnNewIssuance(Id id, address ct, address ds, uint256 _expiryInterval) internal {
        State storage state = states[id];

        address ra = state.info.ra;
        uint256 prevIdx = state.globalAssetIdx;
        uint256 idx = ++state.globalAssetIdx;

        PsmLibrary.onNewIssuance(state, ct, ds, idx, prevIdx);

        getRouterCore().onNewIssuance(id, idx, ds, ra, ct);

        emit Issued(id, idx, block.timestamp + _expiryInterval, ds, ct, AmmId.unwrap(toAmmId_0(ra, ct)));
    }

    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updateRepurchaseFeePercentage(state, newRepurchaseFeePercentage);

        emit RepurchaseFeeRateUpdated(id, newRepurchaseFeePercentage);
    }

    /**
     * @notice update pausing status of PSM Deposits
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     */
    function updatePsmDepositsStatus(Id id, bool isPSMDepositPaused) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePsmDepositsStatus(state, isPSMDepositPaused);
        emit PsmDepositsStatusUpdated(id, isPSMDepositPaused);
    }

    /**
     * @notice update pausing status of PSM Withdrawals
     * @param id id of the pair
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     */
    function updatePsmWithdrawalsStatus(Id id, bool isPSMWithdrawalPaused) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePsmWithdrawalsStatus(state, isPSMWithdrawalPaused);
        emit PsmWithdrawalsStatusUpdated(id, isPSMWithdrawalPaused);
    }

    /**
     * @notice update pausing status of PSM Repurchases
     * @param id id of the pair
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     */
    function updatePsmRepurchasesStatus(Id id, bool isPSMRepurchasePaused) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePsmRepurchasesStatus(state, isPSMRepurchasePaused);
        emit PsmRepurchasesStatusUpdated(id, isPSMRepurchasePaused);
    }

    /**
     * @notice update pausing status of LV deposits
     * @param id id of the pair
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     */
    function updateLvDepositsStatus(Id id, bool isLVDepositPaused) external {
        onlyConfig();
        State storage state = states[id];
        VaultLibrary.updateLvDepositsStatus(state, isLVDepositPaused);
        emit LvDepositsStatusUpdated(id, isLVDepositPaused);
    }

    /**
     * @notice update pausing status of LV withdrawals
     * @param id id of the pair
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updateLvWithdrawalsStatus(Id id, bool isLVWithdrawalPaused) external {
        onlyConfig();
        State storage state = states[id];
        VaultLibrary.updateLvWithdrawalsStatus(state, isLVWithdrawalPaused);
        emit LvWithdrawalsStatusUpdated(id, isLVWithdrawalPaused);
    }

    /**
     * @notice Get the last DS id issued for a given module, the returned DS doesn't guarantee to be active
     * @param id The current module id
     * @return dsId The current effective DS id
     *
     */
    function lastDsId(Id id) external view override returns (uint256 dsId) {
        return states[id].globalAssetIdx;
    }

    /**
     * @notice returns the address of the underlying RA and PA token
     * @param id the id of PSM
     * @return ra address of the underlying RA token
     * @return pa address of the underlying PA token
     */
    function underlyingAsset(Id id) external view override returns (address ra, address pa) {
        (ra, pa) = states[id].info.underlyingAsset();
    }

    /**
     * @notice returns the address of CT and DS associated with a certain DS id
     * @param id the id of PSM
     * @param dsId the DS id
     * @return ct address of the CT token
     * @return ds address of the DS token
     */
    function swapAsset(Id id, uint256 dsId) external view override returns (address ct, address ds) {
        ct = states[id].ds[dsId].ct;
        ds = states[id].ds[dsId]._address;
    }

    /**
     * @notice update value of PSMBaseRedemption fees
     * @param newPsmBaseRedemptionFeePercentage new value of fees
     */
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage) external {
        onlyConfig();
        State storage state = states[id];
        PsmLibrary.updatePSMBaseRedemptionFeePercentage(state, newPsmBaseRedemptionFeePercentage);
        emit PsmBaseRedemptionFeePercentageUpdated(id, newPsmBaseRedemptionFeePercentage);
    }

    function expiry(Id id) external view override returns (uint256 expiry) {
        expiry = PsmLibrary.nextExpiry(states[id]);
    }
}

// contracts/core/ModuleState.sol

/**
 * @title ModuleState Abstract Contract
 * @author Cork Team
 * @notice Abstract ModuleState contract for providing base for Modulecore contract
 */
abstract contract ModuleState is IErrors_0, ReentrancyGuardTransient {
    using PsmLibrary for State;

    mapping(Id => State) internal states;

    address internal SWAP_ASSET_FACTORY;

    address internal DS_FLASHSWAP_ROUTER;

    /// @dev in this case is uni v4
    address internal AMM_HOOK;

    address internal CONFIG;

    address internal WITHDRAWAL_CONTRACT;

    /**
     * @dev checks if caller is config contract or not
     */
    function onlyConfig() internal view {
        if (msg.sender != CONFIG) {
            revert OnlyConfigAllowed();
        }
    }

    function factory() external view returns (address) {
        return SWAP_ASSET_FACTORY;
    }

    function initializeModuleState(
        address _swapAssetFactory,
        address _ammHook,
        address _dsFlashSwapRouter,
        address _config
    ) internal {
        if (
            _swapAssetFactory == address(0) || _ammHook == address(0) || _dsFlashSwapRouter == address(0)
                || _config == address(0)
        ) {
            revert ZeroAddress();
        }

        SWAP_ASSET_FACTORY = _swapAssetFactory;
        DS_FLASHSWAP_ROUTER = _dsFlashSwapRouter;
        CONFIG = _config;
        AMM_HOOK = _ammHook;
    }

    function _setWithdrawalContract(address _withdrawalContract) internal {
        WITHDRAWAL_CONTRACT = _withdrawalContract;
    }

    function getRouterCore() public view returns (RouterState) {
        return RouterState(DS_FLASHSWAP_ROUTER);
    }

    function getAmmRouter() public view returns (ICorkHook_0) {
        return ICorkHook_0(AMM_HOOK);
    }

    function getWithdrawalContract() public view returns (Withdrawal) {
        return Withdrawal(WITHDRAWAL_CONTRACT);
    }

    function getTreasuryAddress() public view returns (address) {
        return CorkConfig(CONFIG).treasury();
    }

    function onlyInitialized(Id id) internal view {
        if (!states[id].isInitialized()) {
            revert NotInitialized();
        }
    }

    function PSMDepositNotPaused(Id id) internal view {
        if (states[id].psm.isDepositPaused) {
            revert PSMDepositPaused();
        }
    }

    function onlyFlashSwapRouter() internal view {
        if (msg.sender != DS_FLASHSWAP_ROUTER) {
            revert OnlyFlashSwapRouterAllowed();
        }
    }

    function PSMWithdrawalNotPaused(Id id) internal view {
        if (states[id].psm.isWithdrawalPaused) {
            revert PSMWithdrawalPaused();
        }
    }

    function PSMRepurchaseNotPaused(Id id) internal view {
        if (states[id].psm.isRepurchasePaused) {
            revert PSMRepurchasePaused();
        }
    }

    function LVDepositNotPaused(Id id) internal view {
        if (states[id].vault.config.isDepositPaused) {
            revert LVDepositPaused();
        }
    }

    function LVWithdrawalNotPaused(Id id) internal view {
        if (states[id].vault.config.isWithdrawalPaused) {
            revert LVWithdrawalPaused();
        }
    }

    function onlyWhiteListedLiquidationContract() internal view {
        if (!ILiquidatorRegistry(CONFIG).isLiquidationWhitelisted(msg.sender)) {
            revert OnlyWhiteListed();
        }
    }
}

// contracts/core/assets/ProtectedUnit.sol

// TODO : support permit

struct DSData {
    address dsAddress;
    uint256 totalDeposited;
}

/**
 * @title ProtectedUnit
 * @notice This contract allows minting and dissolving ProtectedUnit tokens in exchange for two underlying assets.
 * @dev The contract uses OpenZeppelin's ERC20, ReentrancyGuardTransient,Pausable and Ownable modules.
 */
contract ProtectedUnit is
    ERC20Permit,
    ReentrancyGuardTransient,
    Ownable,
    Pausable,
    IProtectedUnit,
    IProtectedUnitLiquidation,
    ERC20Burnable
{
    string public constant DS_PERMIT_MINT_TYPEHASH = "mint(uint256 amount)";

    using SafeERC20 for IERC20;

    CorkConfig public immutable CONFIG;
    IDsFlashSwapCore public immutable FLASHSWAP_ROUTER;
    ModuleCore public immutable MODULE_CORE;

    /// @notice The ERC20 token representing the PA asset.
    ERC20 public immutable PA;
    ERC20 public immutable RA;

    uint256 public dsReserve;
    uint256 public paReserve;
    uint256 public raReserve;

    Id public id;

    /// @notice The ERC20 token representing the ds asset.
    Asset internal ds;

    /// @notice Maximum supply cap for minting ProtectedUnit tokens.
    uint256 public mintCap;

    DSData[] public dsHistory;
    mapping(address => uint256) private dsIndexMap;

    /**
     * @dev Constructor that sets the DS and pa tokens and initializes the mint cap.
     * @param _moduleCore Address of the moduleCore.
     * @param _pa Address of the pa token.
     * @param _pairName Name of the ProtectedUnit pair.
     * @param _mintCap Initial mint cap for the ProtectedUnit tokens.
     */
    constructor(
        address _moduleCore,
        Id _id,
        address _pa,
        address _ra,
        string memory _pairName,
        uint256 _mintCap,
        address _config,
        address _flashSwapRouter
    )
        ERC20(string(abi.encodePacked("Protected Unit - ", _pairName)), string(abi.encodePacked("PU - ", _pairName)))
        ERC20Permit(string(abi.encodePacked("Protected Unit - ", _pairName)))
        Ownable(_config)
    {
        MODULE_CORE = ModuleCore(_moduleCore);
        id = _id;
        PA = ERC20(_pa);
        RA = ERC20(_ra);
        mintCap = _mintCap;
        FLASHSWAP_ROUTER = IDsFlashSwapCore(_flashSwapRouter);
        CONFIG = CorkConfig(_config);
    }

    modifier autoUpdateDS() {
        _getLastDS();
        _;
    }

    modifier onlyLiquidationContract() {
        if (!CONFIG.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidator();
        }
        _;
    }

    modifier onlyValidToken(address token) {
        if (token != address(PA) && token != address(RA)) {
            revert InvalidToken();
        }
        _;
    }

    modifier onlyOwnerOrLiquidator() {
        if (msg.sender != owner() && !CONFIG.isLiquidationWhitelisted(msg.sender)) {
            revert OnlyLiquidatorOrOwner();
        }
        _;
    }

    modifier autoSync() {
        _;
        _sync();
    }

    function _sync() internal autoUpdateDS {
        dsReserve = ds.balanceOf(address(this));
        paReserve = PA.balanceOf(address(this));
        raReserve = RA.balanceOf(address(this));
    }

    function sync() external autoUpdateDS {
        _sync();
    }

    function _fetchLatestDS() internal view returns (Asset) {
        uint256 dsId = MODULE_CORE.lastDsId(id);
        (, address dsAdd) = MODULE_CORE.swapAsset(id, dsId);

        if (dsAdd == address(0) || Asset(dsAdd).isExpired()) {
            revert NoValidDSExist();
        }

        return Asset(dsAdd);
    }

    function latestDs() external view returns (address) {
        return address(_fetchLatestDS());
    }

    function getReserves() external view returns (uint256 _dsReserves, uint256 _paReserves, uint256 _raReserves) {
        _dsReserves = dsReserve;
        _paReserves = paReserve;
        _raReserves = raReserve;
    }

    function requestLiquidationFunds(uint256 amount, address token)
        external
        onlyLiquidationContract
        onlyValidToken(token)
        autoSync
    {
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance < amount) {
            revert InsufficientFunds();
        }

        IERC20(token).safeTransfer(msg.sender, amount);

        emit LiquidationFundsRequested(msg.sender, token, amount);
    }

    function receiveFunds(uint256 amount, address token) external onlyValidToken(token) autoSync {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit FundsReceived(msg.sender, token, amount);
    }

    function useFunds(
        uint256 amount,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external autoUpdateDS onlyOwnerOrLiquidator autoSync returns (uint256 amountOut) {
        uint256 dsId = MODULE_CORE.lastDsId(id);
        IERC20(RA).safeIncreaseAllowance(address(FLASHSWAP_ROUTER), amount);

        IDsFlashSwapCore.SwapRaForDsReturn memory result =
            FLASHSWAP_ROUTER.swapRaforDs(id, dsId, amount, amountOutMin, params, offchainGuess);

        amountOut = result.amountOut;

        emit FundsUsed(msg.sender, dsId, amount, result.amountOut);
    }

    function redeemRaWithDsPa(uint256 amountPa, uint256 amountDs) external autoUpdateDS onlyOwner autoSync {
        uint256 dsId = MODULE_CORE.lastDsId(id);

        ds.approve(address(MODULE_CORE), amountDs);
        IERC20(PA).safeIncreaseAllowance(address(MODULE_CORE), amountPa);

        MODULE_CORE.redeemRaWithDsPa(id, dsId, amountPa);

        // auto pause
        _pause();

        emit RaRedeemed(msg.sender, dsId, amountPa);
    }

    function fundsAvailable(address token) external view onlyValidToken(token) returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Internal function to get the latest DS address.
     * Calls moduleCore to get the latest DS id and retrieves the associated DS address.
     * The reason we don't update the reserve is to avoid DDoS manipulation where user
     * could frontrun and send just 1 wei more to skew the reserve. resulting in failing transaction.
     * But since we need the address of the new DS if it's expired to transfer it correctly, we only update
     * the address here at the start of the function call, then finally update the balance after the function call
     */
    function _getLastDS() internal {
        if (address(ds) == address(0) || ds.isExpired()) {
            Asset _ds = _fetchLatestDS();

            // Check if the DS address already exists in history
            bool found = false;
            uint256 index = dsIndexMap[address(_ds)];
            if (dsHistory.length > 0 && dsHistory[index].dsAddress == address(_ds)) {
                // DS address is already at index
                ds = _ds;
                found = true;
            }

            // If not found, add new DS address to history
            if (!found) {
                ds = _ds;
                dsHistory.push(DSData({dsAddress: address(ds), totalDeposited: 0}));
                dsIndexMap[address(ds)] = dsHistory.length - 1; // Store the index
            }
        }
    }

    function _selfPaReserve() internal view returns (uint256) {
        return TransferHelper_0.tokenNativeDecimalsToFixed(paReserve, PA);
    }

    function _selfRaReserve() internal view returns (uint256) {
        return TransferHelper_0.tokenNativeDecimalsToFixed(raReserve, RA);
    }

    function _selfDsReserve() internal view returns (uint256) {
        return dsReserve;
    }

    function _transferDs(address _to, uint256 _amount) internal {
        IERC20(ds).safeTransfer(_to, _amount);
    }

    /**
     * @notice Returns the dsAmount and paAmount required to mint the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens required to mint the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of pa tokens required to mint the specified amount of ProtectedUnit tokens.
     */
    function previewMint(uint256 amount) public view returns (uint256 dsAmount, uint256 paAmount) {
        if (amount == 0) {
            revert InvalidAmount();
        }

        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        (dsAmount, paAmount) = ProtectedUnitMath.previewMint(amount, _selfPaReserve(), _selfDsReserve(), totalSupply());

        paAmount = TransferHelper_0.fixedToTokenNativeDecimals(paAmount, PA);
    }

    /**
     * @notice Mints ProtectedUnit tokens by transferring the equivalent amount of DS and pa tokens.
     * @dev The function checks for the paused state and mint cap before minting.
     * @param amount The amount of ProtectedUnit tokens to mint.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts MintCapExceeded if the mint cap is exceeded.
     * @return dsAmount The amount of DS tokens used to mint ProtectedUnit tokens.
     * @return paAmount The amount of pa tokens used to mint ProtectedUnit tokens.
     */
    function mint(uint256 amount)
        external
        whenNotPaused
        nonReentrant
        autoUpdateDS
        autoSync
        returns (uint256 dsAmount, uint256 paAmount)
    {
        (dsAmount, paAmount) = __mint(msg.sender, amount);
    }

    function __mint(address minter, uint256 amount) internal returns (uint256 dsAmount, uint256 paAmount) {
        if (amount == 0) {
            revert InvalidAmount();
        }

        if (totalSupply() + amount > mintCap) {
            revert MintCapExceeded();
        }

        {
            (dsAmount, paAmount) =
                ProtectedUnitMath.previewMint(amount, _selfPaReserve(), _selfDsReserve(), totalSupply());

            paAmount = TransferHelper_0.fixedToTokenNativeDecimals(paAmount, PA);
        }

        TransferHelper_0.transferFromNormalize(ds, minter, dsAmount);

        // this calculation is based on the assumption that the DS token has 18 decimals but pa can have different decimals

        TransferHelper_0.transferFromNormalize(PA, minter, paAmount);
        dsHistory[dsIndexMap[address(ds)]].totalDeposited += amount;

        _mint(minter, amount);

        emit Mint(minter, amount);
    }

    // if pa do not support permit, then user can still use this function with only ds permit and manual approval on the PA side
    function mint(
        address minter,
        uint256 amount,
        bytes calldata rawDsPermitSig,
        bytes calldata rawPaPermitSig,
        uint256 deadline
    ) external whenNotPaused nonReentrant autoUpdateDS autoSync returns (uint256 dsAmount, uint256 paAmount) {
        if (rawDsPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }

        (dsAmount, paAmount) = previewMint(amount);

        Signature memory sig = MinimalSignatureHelper.split(rawDsPermitSig);
        ds.permit(minter, address(this), dsAmount, deadline, sig.v, sig.r, sig.s, DS_PERMIT_MINT_TYPEHASH);

        if (rawPaPermitSig.length != 0) {
            sig = MinimalSignatureHelper.split(rawPaPermitSig);
            IERC20Permit(address(PA)).permit(minter, address(this), paAmount, deadline, sig.v, sig.r, sig.s);
        }

        (uint256 _actualDs, uint256 _actualPa) = __mint(minter, amount);

        assert(_actualDs == dsAmount);
        assert(_actualPa == paAmount);
    }

    /**
     * @notice Returns the dsAmount, paAmount and raAmount received for dissolving the specified amount of ProtectedUnit tokens.
     * @return dsAmount The amount of DS tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return paAmount The amount of PA tokens received for dissolving the specified amount of ProtectedUnit tokens.
     * @return raAmount The amount of RA tokens received for dissolving the specified amount of ProtectedUnit tokens.
     */
    function previewBurn(address dissolver, uint256 amount)
        public
        view
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount)
    {
        if (amount == 0 || amount > balanceOf(dissolver)) {
            revert InvalidAmount();
        }
        uint256 totalLiquidity = totalSupply();
        uint256 reservePa = _selfPaReserve();
        uint256 reserveDs = ds.balanceOf(address(this));
        uint256 reserveRa = _selfRaReserve();

        (paAmount, dsAmount, raAmount) =
            ProtectedUnitMath.withdraw(reservePa, reserveDs, reserveRa, totalLiquidity, amount);
    }

    /**
     * @notice Burns ProtectedUnit tokens and returns the equivalent amount of DS and pa tokens.
     * @param amount The amount of ProtectedUnit tokens to burn.
     * @custom:reverts EnforcedPause if minting is currently paused.
     * @custom:reverts InvalidAmount if the user has insufficient ProtectedUnit balance.
     */
    function burnFrom(address account, uint256 amount)
        public
        override
        whenNotPaused
        nonReentrant
        autoUpdateDS
        autoSync
    {
        _burnHU(account, amount);
    }

    function burn(uint256 amount) public override whenNotPaused nonReentrant autoUpdateDS autoSync {
        _burnHU(msg.sender, amount);
    }

    function _burnHU(address dissolver, uint256 amount)
        internal
        returns (uint256 dsAmount, uint256 paAmount, uint256 raAmount)
    {
        (dsAmount, paAmount, raAmount) = previewBurn(dissolver, amount);

        _burnFrom(dissolver, amount);

        TransferHelper_0.transferNormalize(PA, dissolver, paAmount);
        _transferDs(dissolver, dsAmount);
        TransferHelper_0.transferNormalize(RA, dissolver, raAmount);

        emit Burn(dissolver, amount, dsAmount, paAmount);
    }

    function _burnFrom(address account, uint256 value) internal {
        if (account != msg.sender) {
            _spendAllowance(account, msg.sender, value);
        }

        _burn(account, value);
    }

    /**
     * @notice Updates the mint cap.
     * @param _newMintCap The new mint cap value.
     * @custom:reverts InvalidValue if the mint cap is not changed.
     */
    function updateMintCap(uint256 _newMintCap) external onlyOwner {
        if (_newMintCap == mintCap) {
            revert InvalidValue();
        }
        mintCap = _newMintCap;
        emit MintCapUpdated(_newMintCap);
    }

    /**
     * @notice Pause this contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause this contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function _normalize(uint256 amount, uint8 decimalsBefore, uint8 decimalsAfter) public pure returns (uint256) {
        return ProtectedUnitMath.normalizeDecimals(amount, decimalsBefore, decimalsAfter);
    }

    //  Make reserves in sync with the actual balance of the contract
    function skim(address to) external nonReentrant {
        if (PA.balanceOf(address(this)) - paReserve > 0) {
            PA.transfer(to, PA.balanceOf(address(this)) - paReserve);
        }
        if (RA.balanceOf(address(this)) - raReserve > 0) {
            RA.transfer(to, RA.balanceOf(address(this)) - raReserve);
        }
        if (ds.balanceOf(address(this)) - dsReserve > 0) {
            ds.transfer(to, ds.balanceOf(address(this)) - dsReserve);
        }
    }
}

// contracts/core/assets/ProtectedUnitFactory.sol

/**
 * @title ProtectedUnitFactory
 * @notice This contract is used to deploy and manage multiple ProtectedUnit contracts for different asset pairs.
 * @dev The factory contract keeps track of all deployed ProtectedUnit contracts.
 */
contract ProtectedUnitFactory is IProtectedUnitFactory {
    using PairLibrary for Pair;

    uint256 internal idx;

    // Addresses needed for the construction of new ProtectedUnit contracts
    address public immutable MODULE_CORE;
    address public immutable CONFIG;
    address public immutable ROUTER;

    // Mapping to keep track of ProtectedUnit contracts by a unique pair identifier
    mapping(Id => address) public protectedUnitContracts;
    mapping(uint256 => Id) internal protectedUnits;

    modifier onlyConfig() {
        if (msg.sender != CONFIG) {
            revert NotConfig();
        }
        _;
    }

    /**
     * @notice Constructor sets the initial addresses for moduleCore, config and flashswap router.
     * @param _moduleCore Address of the MODULE_CORE.
     * @param _config Address of the config contract
     */
    constructor(address _moduleCore, address _config, address _flashSwapRouter) {
        if (_moduleCore == address(0) || _config == address(0) || _flashSwapRouter == address(0)) {
            revert ZeroAddress();
        }
        MODULE_CORE = _moduleCore;
        CONFIG = _config;
        ROUTER = _flashSwapRouter;
    }

    /**
     * @notice Fetches a paginated list of ProtectedUnits deployed by this factory.
     * @param _page Page number (starting from 0).
     * @param _limit Number of entries per page.
     * @return protectedUnitsList List of deployed ProtectedUnit addresses for the given page.
     * @return idsList List of corresponding pair IDs for the deployed ProtectedUnits.
     */
    function getDeployedProtectedUnits(uint8 _page, uint8 _limit)
        external
        view
        returns (address[] memory protectedUnitsList, Id[] memory idsList)
    {
        uint256 start = uint256(_page) * uint256(_limit);
        uint256 end = start + uint256(_limit);

        if (end > idx) {
            end = idx;
        }

        if (start >= idx) {
            return (protectedUnitsList, idsList); // Return empty arrays if out of bounds.
        }

        uint256 arrLen = end - start;
        protectedUnitsList = new address[](arrLen);
        idsList = new Id[](arrLen);

        for (uint256 i = start; i < end; ++i) {
            uint256 localIndex = i - start;
            Id pairId = protectedUnits[i];
            protectedUnitsList[localIndex] = protectedUnitContracts[pairId];
            idsList[localIndex] = pairId;
        }
    }

    /**
     * @notice Deploys a new ProtectedUnit contract for a specific asset pair.
     * @param _id Id of the pair to be managed by the ProtectedUnit contract.
     * @param _pa Address of the PA token.
     * @param _pairName Name of the ProtectedUnit pair.
     * @param _mintCap Initial mint cap for the ProtectedUnit tokens.
     * @return newUnit of the newly deployed ProtectedUnit contract.
     */
    function deployProtectedUnit(Id _id, address _pa, address _ra, string calldata _pairName, uint256 _mintCap)
        external
        onlyConfig
        returns (address newUnit)
    {
        if (protectedUnitContracts[_id] != address(0)) {
            revert ProtectedUnitExists();
        }

        // Deploy a new ProtectedUnit contract
        ProtectedUnit newProtectedUnit =
            new ProtectedUnit(MODULE_CORE, _id, _pa, _ra, _pairName, _mintCap, CONFIG, ROUTER);
        newUnit = address(newProtectedUnit);

        // Store the address of the new contract
        protectedUnitContracts[_id] = newUnit;

        // solhint-disable-next-line gas-increment-by-one
        protectedUnits[idx++] = _id;

        emit ProtectedUnitDeployed(_id, _pa, _ra, newUnit);
    }

    /**
     * @notice Returns the address of the deployed ProtectedUnit contract for a given pair.
     * @param _id The unique identifier of the pair.
     * @return Address of the ProtectedUnit contract.
     */
    function getProtectedUnitAddress(Id _id) external view returns (address) {
        return protectedUnitContracts[_id];
    }

    function deRegisterProtectedUnit(Id _id) external onlyConfig {
        delete protectedUnitContracts[_id];
    }
}

// contracts/core/Psm.sol

/**
 * @title PsmCore Abstract Contract
 * @author Cork Team
 * @notice Abstract PsmCore contract provides PSM related logics
 */
abstract contract PsmCore is IPSMcore, ModuleState, Context {
    using PsmLibrary for State;
    using PairLibrary for Pair;

    /**
     * @notice returns the fee percentage for repurchasing(1e18 = 1%)
     * @param id the id of PSM
     */
    function repurchaseFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.repurchaseFeePercentage();
    }

    /**
     * @notice repurchase using RA
     * @param id the id of PSM
     * @param amount the amount of RA to use
     */
    function repurchase(Id id, uint256 amount)
        external
        override
        nonReentrant
        returns (
            uint256 dsId,
            uint256 receivedPa,
            uint256 receivedDs,
            uint256 feePercentage,
            uint256 fee,
            uint256 exchangeRates
        )
    {
        PSMRepurchaseNotPaused(id);

        State storage state = states[id];

        (dsId, receivedPa, receivedDs, feePercentage, fee, exchangeRates) =
            state.repurchase(_msgSender(), amount, getTreasuryAddress());

        emit Repurchased(id, _msgSender(), dsId, amount, receivedPa, receivedDs, feePercentage, fee, exchangeRates);
    }

    /**
     * @notice return the amount of available PA and DS to purchase.
     * @param id the id of PSM
     * @return pa the amount of PA available
     * @return ds the amount of DS available
     * @return dsId the id of the DS available
     */
    function availableForRepurchase(Id id) external view override returns (uint256 pa, uint256 ds, uint256 dsId) {
        State storage state = states[id];
        (pa, ds, dsId) = state.availableForRepurchase();
    }

    /**
     * @notice returns the repurchase rates for a given DS
     * @param id the id of PSM
     */
    function repurchaseRates(Id id) external view returns (uint256 rates) {
        State storage state = states[id];
        rates = state.repurchaseRates();
    }

    /**
     * @notice returns the amount of CT and DS tokens that will be received after deposit
     * @param id the id of PSM
     * @param amount the amount to be deposit
     * @return received the amount of CT/DS received
     * @return _exchangeRate effective exchange rate at time of deposit
     */
    function depositPsm(Id id, uint256 amount) external override returns (uint256 received, uint256 _exchangeRate) {
        onlyInitialized(id);
        PSMDepositNotPaused(id);

        State storage state = states[id];
        uint256 dsId;
        (dsId, received, _exchangeRate) = state.deposit(_msgSender(), amount);
        emit PsmDeposited(id, dsId, _msgSender(), amount, received, _exchangeRate);
    }

    function redeemRaWithDsPa(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes calldata rawDsPermitSig,
        uint256 deadline
    ) external override nonReentrant returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed) {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        if (rawDsPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];

        (received, _exchangeRate, fee, dsUsed) =
            state.redeemWithDs(redeemer, amount, dsId, rawDsPermitSig, deadline, getTreasuryAddress());

        emit DsRedeemed(
            id, dsId, redeemer, amount, dsUsed, received, _exchangeRate, state.psm.psmBaseRedemptionFeePercentage, fee
        );
    }

    function redeemRaWithDsPa(Id id, uint256 dsId, uint256 amount)
        external
        override
        nonReentrant
        returns (uint256 received, uint256 _exchangeRate, uint256 fee, uint256 dsUsed)
    {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        State storage state = states[id];

        (received, _exchangeRate, fee, dsUsed) =
            state.redeemWithDs(_msgSender(), amount, dsId, bytes(""), 0, getTreasuryAddress());

        emit DsRedeemed(
            id,
            dsId,
            _msgSender(),
            amount,
            dsUsed,
            received,
            _exchangeRate,
            state.psm.psmBaseRedemptionFeePercentage,
            fee
        );
    }

    /**
     * This determines the rate of how much the user will receive for the amount of asset they want to deposit.
     * for example, if the rate is 1.5, then the user will need to deposit 1.5 token to get 1 CT and DS.
     * @param id the id of the PSM
     */
    function exchangeRate(Id id) external view override returns (uint256 rates) {
        State storage state = states[id];
        rates = state.exchangeRate();
    }

    function redeemWithExpiredCt(
        Id id,
        uint256 dsId,
        uint256 amount,
        address redeemer,
        bytes calldata rawCtPermitSig,
        uint256 deadline
    ) external override nonReentrant returns (uint256 accruedPa, uint256 accruedRa) {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        if (rawCtPermitSig.length == 0 || deadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];

        (accruedPa, accruedRa) = state.redeemWithExpiredCt(redeemer, amount, dsId, rawCtPermitSig, deadline);

        emit CtRedeemed(id, dsId, redeemer, amount, accruedPa, accruedRa);
    }

    function redeemWithExpiredCt(Id id, uint256 dsId, uint256 amount)
        external
        override
        nonReentrant
        returns (uint256 accruedPa, uint256 accruedRa)
    {
        onlyInitialized(id);
        PSMWithdrawalNotPaused(id);

        State storage state = states[id];

        (accruedPa, accruedRa) = state.redeemWithExpiredCt(_msgSender(), amount, dsId, bytes(""), 0);

        emit CtRedeemed(id, dsId, _msgSender(), amount, accruedPa, accruedRa);
    }

    /**
     * @notice returns amount of value locked in the PSM
     * @param id The PSM id
     */
    function valueLocked(Id id, bool ra) external view override returns (uint256) {
        State storage state = states[id];
        return state.valueLocked(ra);
    }

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @param rawDsPermitSig raw signature for DS approval permit
     * @param dsDeadline deadline for DS approval permit signature
     * @param rawCtPermitSig raw signature for CT approval permit
     * @param ctDeadline deadline for CT approval permit signature
     */
    function returnRaWithCtDs(
        Id id,
        uint256 amount,
        address redeemer,
        bytes calldata rawDsPermitSig,
        uint256 dsDeadline,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external override nonReentrant returns (uint256 ra) {
        PSMWithdrawalNotPaused(id);

        if (rawDsPermitSig.length == 0 || dsDeadline == 0 || rawCtPermitSig.length == 0 || ctDeadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];
        ra = state.returnRaWithCtDs(redeemer, amount, rawDsPermitSig, dsDeadline, rawCtPermitSig, ctDeadline);

        emit Cancelled(id, state.globalAssetIdx, redeemer, ra, amount);
    }

    /**
     * @notice returns amount of ra user will get when Redeem RA with CT+DS
     * @param id The PSM id
     * @param amount amount user wants to redeem
     * @return ra amount of RA user received
     */
    function returnRaWithCtDs(Id id, uint256 amount) external override nonReentrant returns (uint256 ra) {
        PSMWithdrawalNotPaused(id);

        State storage state = states[id];

        ra = state.returnRaWithCtDs(_msgSender(), amount, bytes(""), 0, bytes(""), 0);

        emit Cancelled(id, state.globalAssetIdx, _msgSender(), ra, amount);
    }

    /**
     * @notice returns base redemption fees (1e18 = 1%)
     */
    function baseRedemptionFee(Id id) external view override returns (uint256) {
        State storage state = states[id];
        return state.psm.psmBaseRedemptionFeePercentage;
    }

    function psmAcceptFlashSwapProfit(Id id, uint256 profit) external {
        onlyFlashSwapRouter();
        State storage state = states[id];
        state.acceptRolloverProfit(profit);
    }

    function rolloverExpiredCt(
        Id id,
        address owner,
        uint256 amount,
        uint256 dsId,
        bytes calldata rawCtPermitSig,
        uint256 ctDeadline
    ) external returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived) {
        PSMDepositNotPaused(id);
        if (rawCtPermitSig.length == 0 || ctDeadline == 0) {
            revert InvalidSignature();
        }
        State storage state = states[id];
        (ctReceived, dsReceived, paReceived) =
            state.rolloverExpiredCt(owner, amount, dsId, getRouterCore(), rawCtPermitSig, ctDeadline);
        emit RolledOver(id, state.globalAssetIdx, owner, dsId, amount, dsReceived, ctReceived, paReceived);
    }

    function rolloverExpiredCt(Id id, uint256 amount, uint256 dsId)
        external
        returns (uint256 ctReceived, uint256 dsReceived, uint256 paReceived)
    {
        PSMDepositNotPaused(id);
        State storage state = states[id];
        // slither-disable-next-line uninitialized-local
        bytes memory signaturePlaceHolder;
        (ctReceived, dsReceived, paReceived) =
            state.rolloverExpiredCt(_msgSender(), amount, dsId, getRouterCore(), signaturePlaceHolder, 0);
        emit RolledOver(id, state.globalAssetIdx, _msgSender(), dsId, amount, dsReceived, ctReceived, paReceived);
    }

    function claimAutoSellProfit(Id id, uint256 dsId, uint256 amount)
        external
        nonReentrant
        returns (uint256 profit, uint256 dsReceived)
    {
        State storage state = states[id];
        (profit, dsReceived) = state.claimAutoSellProfit(getRouterCore(), _msgSender(), dsId, amount);
        emit RolloverProfitClaimed(id, dsId, _msgSender(), amount, profit, dsReceived);
    }

    function rolloverProfitRemaining(Id id, uint256 dsId) external view returns (uint256) {
        State storage state = states[id];
        return state.psm.poolArchive[dsId].rolloverClaims[msg.sender];
    }

    function updatePsmAutoSellStatus(Id id, bool status) external {
        State storage state = states[id];
        state.updateAutoSell(_msgSender(), status);
    }

    function psmAutoSellStatus(Id id) external view returns (bool) {
        State storage state = states[id];
        return state.autoSellStatus(_msgSender());
    }

    function updatePsmBaseRedemptionFeeTreasurySplitPercentage(Id id, uint256 percentage) external {
        onlyConfig();
        State storage state = states[id];
        state.psm.psmBaseFeeTreasurySplitPercentage = percentage;
    }

    function updatePsmRepurchaseFeeTreasurySplitPercentage(Id id, uint256 percentage) external {
        onlyConfig();
        State storage state = states[id];
        state.psm.repurchaseFeeTreasurySplitPercentage = percentage;
    }
}

// contracts/core/Vault.sol

/**
 * @title VaultCore Abstract Contract
 * @author Cork Team
 * @notice Abstract VaultCore contract which provides Vault related logics
 */

abstract contract VaultCore is ModuleState, Context, IVault, IVaultLiquidation {
    using PairLibrary for Pair;
    using VaultLibrary for State;

    /**
     * @notice Deposit a wrapped asset into a given vault
     * @param id The Module id that is used to reference both psm and lv of a given pair
     * @param amount The amount of the redemption asset(ra) deposited
     * @return received The amount of lv received
     */
    function depositLv(Id id, uint256 amount, uint256 raTolerance, uint256 ctTolerance)
        external
        override
        nonReentrant
        returns (uint256 received)
    {
        LVDepositNotPaused(id);
        State storage state = states[id];
        received = state.deposit(_msgSender(), amount, getRouterCore(), getAmmRouter(), raTolerance, ctTolerance);
        emit LvDeposited(id, _msgSender(), received, amount);
    }

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     * @param permitParams The object with details for permit like rawLvPermitSig(Raw signature for LV approval permit) and deadline for signature
     */
    function redeemEarlyLv(RedeemEarlyParams calldata redeemParams, PermitParams calldata permitParams)
        external
        override
        nonReentrant
        returns (IVault.RedeemEarlyResult memory result)
    {
        LVWithdrawalNotPaused(redeemParams.id);
        if (permitParams.rawLvPermitSig.length == 0 || permitParams.deadline == 0) {
            revert InvalidSignature();
        }
        ProtocolContracts memory routers = ProtocolContracts({
            flashSwapRouter: getRouterCore(),
            ammRouter: getAmmRouter(),
            withdrawalContract: getWithdrawalContract()
        });

        result = states[redeemParams.id].redeemEarly(msg.sender, redeemParams, routers, permitParams);

        emit LvRedeemEarly(
            redeemParams.id,
            _msgSender(),
            _msgSender(),
            redeemParams.amount,
            result.ctReceivedFromAmm,
            result.ctReceivedFromVault,
            result.dsReceived,
            result.paReceived,
            result.raReceivedFromAmm,
            result.raIdleReceived,
            result.withdrawalId
        );
    }

    /**
     * @notice Redeem lv before expiry
     * @param redeemParams The object with details like id, reciever, amount, amountOutMin, ammDeadline
     */
    function redeemEarlyLv(RedeemEarlyParams calldata redeemParams)
        external
        override
        nonReentrant
        returns (IVault.RedeemEarlyResult memory result)
    {
        LVWithdrawalNotPaused(redeemParams.id);
        ProtocolContracts memory routers = ProtocolContracts({
            flashSwapRouter: getRouterCore(),
            ammRouter: getAmmRouter(),
            withdrawalContract: getWithdrawalContract()
        });
        PermitParams memory permitParams = PermitParams({rawLvPermitSig: bytes(""), deadline: 0});

        result = states[redeemParams.id].redeemEarly(_msgSender(), redeemParams, routers, permitParams);

        emit LvRedeemEarly(
            redeemParams.id,
            _msgSender(),
            _msgSender(),
            redeemParams.amount,
            result.ctReceivedFromAmm,
            result.ctReceivedFromVault,
            result.dsReceived,
            result.paReceived,
            result.raReceivedFromAmm,
            result.raIdleReceived,
            result.withdrawalId
        );
    }

    /**
     * This will accure value for LV holders by providing liquidity to the AMM using the RA received from selling DS when a users buys DS
     * @param id the id of the pair
     * @param amount the amount of RA received from selling DS
     * @dev assumes that `amount` is already transferred to the vault
     */
    function provideLiquidityWithFlashSwapFee(Id id, uint256 amount) external {
        onlyFlashSwapRouter();
        State storage state = states[id];
        state.allocateFeesToVault(amount);
        emit ProfitReceived(msg.sender, amount);
    }

    /**
     * Returns the amount of AMM LP tokens that the vault holds
     * @param id The Module id that is used to reference both psm and lv of a given pair
     */
    function vaultLp(Id id) external view returns (uint256) {
        return states[id].vaultLp(getAmmRouter());
    }

    function lvAcceptRolloverProfit(Id id, uint256 amount) external {
        onlyFlashSwapRouter();
        State storage state = states[id];
        state.allocateFeesToVault(amount);
    }

    function updateCtHeldPercentage(Id id, uint256 ctHeldPercentage) external {
        onlyConfig();
        states[id].updateCtHeldPercentage(ctHeldPercentage);
    }

    function requestLiquidationFunds(Id id, uint256 amount) external override {
        onlyWhiteListedLiquidationContract();
        State storage state = states[id];
        state.requestLiquidationFunds(amount, msg.sender);
        emit LiquidationFundsRequested(id, msg.sender, amount);
    }

    function receiveTradeExecuctionResultFunds(Id id, uint256 amount) external override {
        State storage state = states[id];
        state.receiveTradeExecuctionResultFunds(amount, msg.sender);
        emit TradeExecutionResultFundsReceived(id, msg.sender, amount);
    }

    function useTradeExecutionResultFunds(Id id) external override {
        onlyConfig();
        State storage state = states[id];
        uint256 used = state.useTradeExecutionResultFunds(getRouterCore(), getAmmRouter());
        emit TradeExecutionResultFundsUsed(id, msg.sender, used);
    }

    function liquidationFundsAvailable(Id id) external view returns (uint256) {
        return states[id].liquidationFundsAvailable();
    }

    function tradeExecutionFundsAvailable(Id id) external view returns (uint256) {
        return states[id].tradeExecutionFundsAvailable();
    }

    function lvAsset(Id id) external view override returns (address lv) {
        lv = states[id].vault.lv._address;
    }

    function totalRaAt(Id id, uint256 dsId) external view override returns (uint256) {
        return states[id].vault.totalRaSnapshot[dsId];
    }

    function receiveLeftoverFunds(Id id, uint256 amount) external override {
        states[id].receiveLeftoverFunds(amount, _msgSender());
    }

    function updateVaultNavThreshold(Id id, uint256 newNavThreshold) external override {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];
        VaultLibrary.updateNavThreshold(state, newNavThreshold);
        emit VaultNavThresholdUpdated(id, newNavThreshold);
    }

    function forceUpdateNavCircuitBreakerReferenceValue(Id id) external {
        onlyConfig();
        onlyInitialized(id);

        State storage state = states[id];
        state.forceUpdateNavCircuitBreakerReferenceValue(getRouterCore(), getAmmRouter(), state.globalAssetIdx);
    }
}

// contracts/core/CorkConfig.sol

/**
 * @title Config Contract
 * @author Cork Team
 * @notice Config contract for managing pairs and configurations of Cork protocol
 */
contract CorkConfig is AccessControl, Pausable {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant RATE_UPDATERS_ROLE = keccak256("RATE_UPDATERS_ROLE");
    bytes32 public constant BASE_LIQUIDATOR_ROLE = keccak256("BASE_LIQUIDATOR_ROLE");

    ModuleCore public moduleCore;
    IDsFlashSwapCore public flashSwapRouter;
    CorkHook public hook;
    ProtectedUnitFactory public protectedUnitFactory;
    ExchangeRateProvider public defaultExchangeRateProvider;
    // Cork Protocol's treasury address. Other Protocol component should fetch this address directly from the config contract
    // instead of storing it themselves, since it'll be hard to update the treasury address in all the components if it changes vs updating it in the config contract once
    address public treasury;

    uint256 public rolloverPeriodInBlocks = 480;

    uint256 public defaultDecayDiscountRateInDays = 0;

    // this essentially means deposit will not be allowed if the NAV of the pair is below this threshold
    // the nav is updated every vault deposit
    uint256 public defaultNavThreshold = 90 ether;

    uint256 public constant WHITELIST_TIME_DELAY = 7 days;

    /// @notice liquidation address => timestamp when liquidation is allowed
    mapping(address => uint256) internal liquidationWhitelist;

    /// @notice thrown when caller is not manager/Admin of Cork Protocol
    error CallerNotManager();

    /// @notice thrown when passed Invalid/Zero Address
    error InvalidAddress();

    /// @notice Emitted when a moduleCore variable set
    /// @param moduleCore Address of Modulecore contract
    event ModuleCoreSet(address moduleCore);

    /// @notice Emitted when a flashSwapRouter variable set
    /// @param flashSwapRouter Address of flashSwapRouter contract
    event FlashSwapCoreSet(address flashSwapRouter);

    /// @notice Emitted when a hook variable set
    /// @param hook Address of hook contract
    event HookSet(address hook);

    /// @notice Emitted when a protectedUnitFactory variable set
    /// @param protectedUnitFactory Address of protectedUnitFactory contract
    event ProtectedUnitFactorySet(address protectedUnitFactory);

    /// @notice Emitted when a treasury is set
    /// @param treasury Address of treasury contract/address
    event TreasurySet(address treasury);

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    modifier onlyUpdaterOrManager() {
        if (!hasRole(RATE_UPDATERS_ROLE, msg.sender) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    constructor(address adminAdd, address managerAdd) {
        if (adminAdd == address(0) || managerAdd == address(0)) {
            revert InvalidAddress();
        }

        defaultExchangeRateProvider = new ExchangeRateProvider(address(this));

        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RATE_UPDATERS_ROLE, MANAGER_ROLE);
        _setRoleAdmin(BASE_LIQUIDATOR_ROLE, MANAGER_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, adminAdd);
        _grantRole(MANAGER_ROLE, managerAdd);
    }

    function updateDecayDiscountRateInDays(uint256 newDiscountRateInDays) external onlyManager {
        defaultDecayDiscountRateInDays = newDiscountRateInDays;
    }

    function updateRolloverPeriodInBlocks(uint256 newRolloverPeriodInBlocks) external onlyManager {
        rolloverPeriodInBlocks = newRolloverPeriodInBlocks;
    }

    function updateDefaultNavThreshold(uint256 newNavThreshold) external onlyManager {
        defaultNavThreshold = newNavThreshold;
    }

    function updateNavThreshold(Id id, uint256 newNavThreshold) external onlyManager {
        moduleCore.updateVaultNavThreshold(id, newNavThreshold);
    }

    function _computeLiquidatorRoleHash(address account) public view returns (bytes32) {
        return keccak256(abi.encodePacked(BASE_LIQUIDATOR_ROLE, account));
    }

    // This will be only used in case of emergency to change the manager of the different roles if any of the manager is compromised
    function setRoleAdmin(bytes32 role, bytes32 newAdminRole) external onlyRole(getRoleAdmin(role)) {
        _setRoleAdmin(role, newAdminRole);
    }

    function grantRole(bytes32 role, address account) public override onlyManager {
        _grantRole(role, account);
    }

    function transferAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
    }

    function isTrustedLiquidationExecutor(address liquidationContract, address user) external view returns (bool) {
        return hasRole(_computeLiquidatorRoleHash(liquidationContract), user);
    }

    function grantLiquidatorRole(address liquidationContract, address account) external onlyManager {
        _grantRole(_computeLiquidatorRoleHash(liquidationContract), account);
    }

    function revokeLiquidatorRole(address liquidationContract, address account) external onlyManager {
        _revokeRole(_computeLiquidatorRoleHash(liquidationContract), account);
    }

    function isLiquidationWhitelisted(address liquidationAddress) external view returns (bool) {
        return
            liquidationWhitelist[liquidationAddress] <= block.timestamp && liquidationWhitelist[liquidationAddress] != 0;
    }

    function blacklist(address liquidationAddress) external onlyManager {
        delete liquidationWhitelist[liquidationAddress];
    }

    function whitelist(address liquidationAddress) external onlyManager {
        liquidationWhitelist[liquidationAddress] = block.timestamp + WHITELIST_TIME_DELAY;
    }

    /**
     * @dev Sets new ModuleCore contract address
     * @param _moduleCore new moduleCore contract address
     */
    function setModuleCore(address _moduleCore) external onlyManager {
        if (_moduleCore == address(0)) {
            revert InvalidAddress();
        }
        moduleCore = ModuleCore(_moduleCore);
        emit ModuleCoreSet(_moduleCore);
    }

    function setFlashSwapCore(address _flashSwapRouter) external onlyManager {
        if (_flashSwapRouter == address(0)) {
            revert InvalidAddress();
        }
        flashSwapRouter = IDsFlashSwapCore(_flashSwapRouter);
        emit FlashSwapCoreSet(_flashSwapRouter);
    }

    function setHook(address _hook) external onlyManager {
        if (_hook == address(0)) {
            revert InvalidAddress();
        }
        hook = CorkHook(_hook);
        emit HookSet(_hook);
    }

    function setProtectedUnitFactory(address _protectedUnitFactory) external onlyManager {
        if (_protectedUnitFactory == address(0)) {
            revert InvalidAddress();
        }
        protectedUnitFactory = ProtectedUnitFactory(_protectedUnitFactory);
        emit ProtectedUnitFactorySet(_protectedUnitFactory);
    }

    function setTreasury(address _treasury) external onlyManager {
        if (_treasury == address(0)) {
            revert InvalidAddress();
        }
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    function updateAmmBaseFeePercentage(Id id, uint256 newBaseFeePercentage) external onlyManager {
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, moduleCore.lastDsId(id));
        hook.updateBaseFeePercentage(ra, ct, newBaseFeePercentage);
    }

    function updateAmmTreasurySplitPercentage(Id id, uint256 newTreasurySplitPercentage) external onlyManager {
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, moduleCore.lastDsId(id));
        hook.updateTreasurySplitPercentage(ra, ct, newTreasurySplitPercentage);
    }

    function updatePsmBaseRedemptionFeeTreasurySplitPercentage(Id id, uint256 percentage) external onlyManager {
        moduleCore.updatePsmBaseRedemptionFeeTreasurySplitPercentage(id, percentage);
    }

    function updatePsmRepurchaseFeeTreasurySplitPercentage(Id id, uint256 percentage) external onlyManager {
        moduleCore.updatePsmRepurchaseFeeTreasurySplitPercentage(id, percentage);
    }

    function setWithdrawalContract(address _withdrawalContract) external onlyManager {
        moduleCore.setWithdrawalContract(_withdrawalContract);
    }

    function updateRouterDsExtraFee(Id id, uint256 newPercentage) external onlyManager {
        flashSwapRouter.updateDsExtraFeePercentage(id, newPercentage);
    }

    function updateDsExtraFeeTreasurySplitPercentage(Id id, uint256 newPercentage) external onlyManager {
        flashSwapRouter.updateDsExtraFeeTreasurySplitPercentage(id, newPercentage);
    }

    function forceUpdateNavCircuitBreakerReferenceValue(Id id) external onlyManager {
        moduleCore.forceUpdateNavCircuitBreakerReferenceValue(id);
    }

    /**
     * @dev Initialize Module Core
     * @param pa Address of PA
     * @param ra Address of RA
     * @param initialArp initial price of DS
     */
    function initializeModuleCore(
        address pa,
        address ra,
        uint256 initialArp,
        uint256 expiryInterval,
        address exchangeRateProvider
    ) external {
        moduleCore.initializeModuleCore(pa, ra, initialArp, expiryInterval, exchangeRateProvider);

        // auto assign nav threshold
        Id id = moduleCore.getId(pa, ra, initialArp, expiryInterval, exchangeRateProvider);
        moduleCore.updateVaultNavThreshold(id, defaultNavThreshold);
    }

    /**
     * @dev Issues new assets, will auto assign amm fees from the previous issuance
     * for first issuance, separate transaction must be made to set the fees in the AMM
     */
    function issueNewDs(Id id, uint256 ammLiquidationDeadline) external whenNotPaused {
        moduleCore.issueNewDs(id, defaultDecayDiscountRateInDays, rolloverPeriodInBlocks, ammLiquidationDeadline);

        _autoAssignFees(id);
        _autoAssignTreasurySplitPercentage(id);
    }

    function _autoAssignFees(Id id) internal {
        uint256 currentDsId = moduleCore.lastDsId(id);
        uint256 prevDsId = currentDsId - 1;

        // first issuance, no AMM fees to assign
        if (prevDsId == 0) {
            return;
        }

        // get previous issuance's assets
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, prevDsId);

        // get fees from previous issuance, we won't revert here since the fees can be assigned manually
        // if for some reason the previous issuance AMM is not created for some reason(no LV deposits)
        // slither-disable-next-line uninitialized-local
        uint256 prevBaseFee;

        try hook.getFee(ra, ct) returns (uint256 baseFee, uint256) {
            prevBaseFee = baseFee;
        } catch {
            return;
        }

        // assign fees to current issuance
        (ct,) = moduleCore.swapAsset(id, currentDsId);

        // we don't revert here since an edge case would occur where the Lv token circulation is 0 but the issuance continues
        // and in that case the AMM would not have been created yet. This is a rare edge case and the fees can be assigned manually in such cases
        // solhint-disable-next-line no-empty-blocks
        try hook.updateBaseFeePercentage(ra, ct, prevBaseFee) {} catch {}
    }

    function _autoAssignTreasurySplitPercentage(Id id) internal {
        uint256 currentDsId = moduleCore.lastDsId(id);
        uint256 prevDsId = currentDsId - 1;

        // first issuance, no AMM fees to assign
        if (prevDsId == 0) {
            return;
        }

        // get previous issuance's assets
        (address ra,) = moduleCore.underlyingAsset(id);
        (address ct,) = moduleCore.swapAsset(id, prevDsId);

        // get fees from previous issuance, we won't revert here since the fees can be assigned manually
        // if for some reason the previous issuance AMM is not created for some reason(no LV deposits)
        // slither-disable-next-line uninitialized-local
        uint256 prevCtSplit;

        try hook.getMarketSnapshot(ra, ct) returns (MarketSnapshot memory snapshot) {
            prevCtSplit = snapshot.treasuryFeePercentage;
        } catch {
            return;
        }

        (ct,) = moduleCore.swapAsset(id, currentDsId);

        // we don't revert here since an edge case would occur where the Lv token circulation is 0 but the issuance continues
        // and in that case the AMM would not have been created yet. This is a rare edge case and the fees can be assigned manually in such cases
        // solhint-disable-next-line no-empty-blocks
        try hook.updateTreasurySplitPercentage(ra, ct, prevCtSplit) {} catch {}
    }

    /**
     * @notice Updates fee rates for psm repurchase
     * @param id id of PSM
     * @param newRepurchaseFeePercentage new value of repurchase fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updateRepurchaseFeeRate(Id id, uint256 newRepurchaseFeePercentage) external onlyManager {
        moduleCore.updateRepurchaseFeeRate(id, newRepurchaseFeePercentage);
    }

    /**
     * @notice update pausing status of PSM Deposits
     * @param id id of the pair
     * @param isPSMDepositPaused set to true if you want to pause PSM deposits
     */
    function updatePsmDepositsStatus(Id id, bool isPSMDepositPaused) external onlyManager {
        moduleCore.updatePsmDepositsStatus(id, isPSMDepositPaused);
    }

    /**
     * @notice update pausing status of PSM Withdrawals
     * @param id id of the pair
     * @param isPSMWithdrawalPaused set to true if you want to pause PSM withdrawals
     */
    function updatePsmWithdrawalsStatus(Id id, bool isPSMWithdrawalPaused) external onlyManager {
        moduleCore.updatePsmWithdrawalsStatus(id, isPSMWithdrawalPaused);
    }

    /**
     * @notice update pausing status of PSM Repurchases
     * @param id id of the pair
     * @param isPSMRepurchasePaused set to true if you want to pause PSM repurchases
     */
    function updatePsmRepurchasesStatus(Id id, bool isPSMRepurchasePaused) external onlyManager {
        moduleCore.updatePsmRepurchasesStatus(id, isPSMRepurchasePaused);
    }

    /**
     * @notice update pausing status of LV deposits
     * @param id id of the pair
     * @param isLVDepositPaused set to true if you want to pause LV deposits
     */
    function updateLvDepositsStatus(Id id, bool isLVDepositPaused) external onlyManager {
        moduleCore.updateLvDepositsStatus(id, isLVDepositPaused);
    }

    /**
     * @notice update pausing status of LV withdrawals
     * @param id id of the pair
     * @param isLVWithdrawalPaused set to true if you want to pause LV withdrawals
     */
    function updateLvWithdrawalsStatus(Id id, bool isLVWithdrawalPaused) external onlyManager {
        moduleCore.updateLvWithdrawalsStatus(id, isLVWithdrawalPaused);
    }

    /**
     * @notice Updates base redemption fee percentage
     * @param newPsmBaseRedemptionFeePercentage new value of fees, make sure it has 18 decimals(e.g 1% = 1e18)
     */
    function updatePsmBaseRedemptionFeePercentage(Id id, uint256 newPsmBaseRedemptionFeePercentage)
        external
        onlyManager
    {
        moduleCore.updatePsmBaseRedemptionFeePercentage(id, newPsmBaseRedemptionFeePercentage);
    }

    function updateFlashSwapRouterDiscountInDays(Id id, uint256 newDiscountInDays) external onlyManager {
        flashSwapRouter.updateDiscountRateInDdays(id, newDiscountInDays);
    }

    function updateRouterGradualSaleStatus(Id id, bool status) external onlyManager {
        flashSwapRouter.updateGradualSaleStatus(id, status);
    }

    function updateLvStrategyCtSplitPercentage(Id id, uint256 newCtSplitPercentage) external onlyManager {
        IVault(address(moduleCore)).updateCtHeldPercentage(id, newCtSplitPercentage);
    }

    function updateReserveSellPressurePercentage(Id id, uint256 newSellPressurePercentage) external onlyManager {
        flashSwapRouter.updateReserveSellPressurePercentage(id, newSellPressurePercentage);
    }

    function updatePsmRate(Id id, uint256 newRate) external onlyUpdaterOrManager {
        // we update the rate in our provider regardless it's up or down. won't affect other market's rates that doesn't use this provider
        defaultExchangeRateProvider.setRate(id, newRate);
    }

    function useVaultTradeExecutionResultFunds(Id id) external onlyManager {
        moduleCore.useTradeExecutionResultFunds(id);
    }

    function updateProtectedUnitMintCap(address protectedUnit, uint256 newMintCap) external onlyManager {
        ProtectedUnit(protectedUnit).updateMintCap(newMintCap);
    }

    function deployProtectedUnit(Id id, address pa, address ra, string calldata pairName, uint256 mintCap)
        external
        onlyManager
        returns (address)
    {
        return protectedUnitFactory.deployProtectedUnit(id, pa, ra, pairName, mintCap);
    }

    function deRegisterProtectedUnit(Id id) external onlyManager {
        protectedUnitFactory.deRegisterProtectedUnit(id);
    }

    function pauseProtectedUnitMinting(address protectedUnit) external onlyManager {
        ProtectedUnit(protectedUnit).pause();
    }

    function resumeProtectedUnitMinting(address protectedUnit) external onlyManager {
        ProtectedUnit(protectedUnit).unpause();
    }

    function redeemRaWithDsPaWithProtectedUnit(address protectedUnit, uint256 amount, uint256 amountDS)
        external
        onlyManager
    {
        ProtectedUnit(protectedUnit).redeemRaWithDsPa(amount, amountDS);
    }

    function buyDsFromProtectedUnit(
        address protectedUnit,
        uint256 amount,
        uint256 amountOutMin,
        IDsFlashSwapCore.BuyAprroxParams calldata params,
        IDsFlashSwapCore.OffchainGuess calldata offchainGuess
    ) external onlyManager returns (uint256 amountOut) {
        amountOut = ProtectedUnit(protectedUnit).useFunds(amount, amountOutMin, params, offchainGuess);
    }

    /**
     * @notice Pause this contract
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @notice Unpause this contract
     */
    function unpause() external onlyManager {
        _unpause();
    }
}

