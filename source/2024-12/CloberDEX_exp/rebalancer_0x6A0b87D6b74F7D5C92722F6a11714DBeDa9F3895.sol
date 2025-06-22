// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 ^0.8.0 ^0.8.20;

// @openzeppelin/contracts/utils/Context.sol

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

// solmate/tokens/ERC6909.sol

/// @notice Minimalist and gas efficient standard ERC6909 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC6909.sol)
abstract contract ERC6909 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             ERC6909 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(address => bool)) public isOperator;

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;

    /*//////////////////////////////////////////////////////////////
                              ERC6909 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(
        address receiver,
        uint256 id,
        uint256 amount
    ) public virtual returns (bool) {
        balanceOf[msg.sender][id] -= amount;

        balanceOf[receiver][id] += amount;

        emit Transfer(msg.sender, msg.sender, receiver, id, amount);

        return true;
    }

    function transferFrom(
        address sender,
        address receiver,
        uint256 id,
        uint256 amount
    ) public virtual returns (bool) {
        if (msg.sender != sender && !isOperator[sender][msg.sender]) {
            uint256 allowed = allowance[sender][msg.sender][id];
            if (allowed != type(uint256).max) allowance[sender][msg.sender][id] = allowed - amount;
        }

        balanceOf[sender][id] -= amount;

        balanceOf[receiver][id] += amount;

        emit Transfer(msg.sender, sender, receiver, id, amount);

        return true;
    }

    function approve(
        address spender,
        uint256 id,
        uint256 amount
    ) public virtual returns (bool) {
        allowance[msg.sender][spender][id] = amount;

        emit Approval(msg.sender, spender, id, amount);

        return true;
    }

    function setOperator(address operator, bool approved) public virtual returns (bool) {
        isOperator[msg.sender][operator] = approved;

        emit OperatorSet(msg.sender, operator, approved);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x0f632fb3; // ERC165 Interface ID for ERC6909
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(
        address receiver,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[receiver][id] += amount;

        emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(
        address sender,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[sender][id] -= amount;

        emit Transfer(msg.sender, sender, address(0), id, amount);
    }
}

// @openzeppelin/contracts/utils/Errors.sol

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
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
}

// solmate/utils/FixedPointMathLib.sol

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // Divide x * y by the denominator.
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // If x * y modulo the denominator is strictly greater than 0,
            // 1 is added to round up the division of x * y by the denominator.
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// @openzeppelin/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

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

// @openzeppelin/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

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

// clober-dex/v2-core/interfaces/ILocker.sol

/**
 * @title ILocker
 * @notice Interface for the locker contract
 */
interface ILocker {
    /**
     * @notice Called by the book manager on `msg.sender` when a lock is acquired
     * @param data The data that was passed to the call to lock
     * @return Any data that you want to be returned from the lock call
     */
    function lockAcquired(address lockCaller, bytes calldata data) external returns (bytes memory);
}

// clober-dex/v2-core/libraries/Math.sol

library Math {
    function divide(uint256 a, uint256 b, bool roundingUp) internal pure returns (uint256 ret) {
        // In the OrderBook contract code, b is never zero.
        assembly {
            ret := add(div(a, b), and(gt(mod(a, b), 0), roundingUp))
        }
    }

    /// @dev Returns `ln(x)`, denominated in `WAD`.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/22/exp-ln
    function lnWad(int256 x) internal pure returns (int256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // We want to convert `x` from `10**18` fixed point to `2**96` fixed point.
            // We do this by multiplying by `2**96 / 10**18`. But since
            // `ln(x * C) = ln(x) + ln(C)`, we can simply do nothing here
            // and add `ln(2**96 / 10**18)` at the end.

            // Compute `k = log2(x) - 96`, `r = 159 - k = 255 - log2(x) = 255 ^ log2(x)`.
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // We place the check here for more optimal stack operations.
            if iszero(sgt(x, 0)) {
                mstore(0x00, 0x1615e638) // `LnWadUndefined()`.
                revert(0x1c, 0x04)
            }
            // forgefmt: disable-next-item
            r := xor(r, byte(and(0x1f, shr(shr(r, x), 0x8421084210842108cc6318c6db6d54be)),
                0xf8f9f9faf9fdfafbf9fdfcfdfafbfcfef9fafdfafcfcfbfefafafcfbffffffff))

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            x := shr(159, shl(r, x))

            // Evaluate using a (8, 8)-term rational approximation.
            // `p` is made monic, we will multiply by a scale factor later.
            // forgefmt: disable-next-item
            let p := sub( // This heavily nested expression is to avoid stack-too-deep for via-ir.
                sar(96, mul(add(43456485725739037958740375743393,
                    sar(96, mul(add(24828157081833163892658089445524,
                        sar(96, mul(add(3273285459638523848632254066296,
                            x), x))), x))), x)), 11111509109440967052023855526967)
            p := sub(sar(96, mul(p, x)), 45023709667254063763336534515857)
            p := sub(sar(96, mul(p, x)), 14706773417378608786704636184526)
            p := sub(mul(p, x), shl(96, 795164235651350426258249787498))
            // We leave `p` in `2**192` basis so we don't need to scale it back up for the division.

            // `q` is monic by convention.
            let q := add(5573035233440673466300451813936, x)
            q := add(71694874799317883764090561454958, sar(96, mul(x, q)))
            q := add(283447036172924575727196451306956, sar(96, mul(x, q)))
            q := add(401686690394027663651624208769553, sar(96, mul(x, q)))
            q := add(204048457590392012362485061816622, sar(96, mul(x, q)))
            q := add(31853899698501571402653359427138, sar(96, mul(x, q)))
            q := add(909429971244387300277376558375, sar(96, mul(x, q)))

            // `p / q` is in the range `(0, 0.125) * 2**96`.

            // Finalization, we need to:
            // - Multiply by the scale factor `s = 5.549…`.
            // - Add `ln(2**96 / 10**18)`.
            // - Add `k * ln(2)`.
            // - Multiply by `10**18 / 2**96 = 5**18 >> 78`.

            // The q polynomial is known not to have zeros in the domain.
            // No scaling required because p is already `2**96` too large.
            p := sdiv(p, q)
            // Multiply by the scaling factor: `s * 5**18 * 2**96`, base is now `5**18 * 2**192`.
            p := mul(1677202110996718588342820967067443963516166, p)
            // Add `ln(2) * k * 5**18 * 2**192`.
            // forgefmt: disable-next-item
            p := add(mul(16597577552685614221487285958193947469193820559219878177908093499208371, sub(159, r)), p)
            // Base conversion: mul `2**96 / (5**18 * 2**192)`.
            r := sdiv(p, 302231454903657293676544000000000000000000)
        }
    }
}

// @openzeppelin/contracts/utils/math/SafeCast.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SafeCast.sol)
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
library SafeCast {
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
        /// @solidity memory-safe-assembly
        assembly {
            u := iszero(iszero(b))
        }
    }
}

// @openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

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
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// clober-dex/v2-core/libraries/Currency.sol

type Currency is address;

/// @title CurrencyLibrary
/// @dev This library allows for transferring and holding native tokens and ERC20 tokens
library CurrencyLibrary {
    using CurrencyLibrary for Currency;

    /// @notice Thrown when a native transfer fails
    error NativeTransferFailed();

    /// @notice Thrown when an ERC20 transfer fails
    error ERC20TransferFailed();

    Currency public constant NATIVE = Currency.wrap(address(0));

    function transfer(Currency currency, address to, uint256 amount) internal {
        // implementation from
        // https://github.com/transmissions11/solmate/blob/e8f96f25d48fe702117ce76c79228ca4f20206cb/src/utils/SafeTransferLib.sol

        bool success;
        if (currency.isNative()) {
            assembly {
                // Transfer the ETH and store if it succeeded or not.
                success := call(gas(), to, amount, 0, 0, 0, 0)
            }

            if (!success) revert NativeTransferFailed();
        } else {
            assembly {
                // Get a pointer to some free memory.
                let freeMemoryPointer := mload(0x40)

                // Write the abi-encoded calldata into memory, beginning with the function selector.
                mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // Append and mask the "to" argument.
                mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument. Masking not required as it's a full 32 byte type.

                success :=
                    and(
                        // Set success to whether the call reverted, if not we check it either
                        // returned exactly 1 (can't just be non-zero data), or had no return data.
                        or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                        // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                        // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                        // Counterintuitively, this call must be positioned second to the or() call in the
                        // surrounding and() call or else returndatasize() will be zero during the computation.
                        call(gas(), currency, 0, freeMemoryPointer, 68, 0, 32)
                    )
            }

            if (!success) revert ERC20TransferFailed();
        }
    }

    function balanceOfSelf(Currency currency) internal view returns (uint256) {
        if (currency.isNative()) return address(this).balance;
        else return IERC20(Currency.unwrap(currency)).balanceOf(address(this));
    }

    function equals(Currency currency, Currency other) internal pure returns (bool) {
        return Currency.unwrap(currency) == Currency.unwrap(other);
    }

    function isNative(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == Currency.unwrap(NATIVE);
    }

    function toId(Currency currency) internal pure returns (uint256) {
        return uint160(Currency.unwrap(currency));
    }

    function fromId(uint256 id) internal pure returns (Currency) {
        return Currency.wrap(address(uint160(id)));
    }
}

// src/libraries/ERC6909Supply.sol

abstract contract ERC6909Supply is ERC6909 {
    mapping(uint256 => uint256) public totalSupply;

    function _mint(address receiver, uint256 id, uint256 amount) internal virtual override {
        super._mint(receiver, id, amount);
        totalSupply[id] += amount;
    }

    function _burn(address sender, uint256 id, uint256 amount) internal virtual override {
        super._burn(sender, id, amount);
        totalSupply[id] -= amount;
    }
}

// clober-dex/v2-core/libraries/FeePolicy.sol

type FeePolicy is uint24;

library FeePolicyLibrary {
    uint256 internal constant RATE_PRECISION = 10 ** 6;
    int256 internal constant MAX_FEE_RATE = 500000;
    int256 internal constant MIN_FEE_RATE = -500000;

    uint256 internal constant RATE_MASK = 0x7fffff; // 23 bits

    error InvalidFeePolicy();

    function encode(bool usesQuote_, int24 rate_) internal pure returns (FeePolicy feePolicy) {
        if (rate_ > MAX_FEE_RATE || rate_ < MIN_FEE_RATE) {
            revert InvalidFeePolicy();
        }

        uint256 mask = usesQuote_ ? 1 << 23 : 0;
        assembly {
            feePolicy := or(mask, add(and(rate_, 0xffffff), MAX_FEE_RATE))
        }
    }

    function isValid(FeePolicy self) internal pure returns (bool) {
        int24 r = rate(self);

        return !(r > MAX_FEE_RATE || r < MIN_FEE_RATE);
    }

    function usesQuote(FeePolicy self) internal pure returns (bool f) {
        assembly {
            f := shr(23, self)
        }
    }

    function rate(FeePolicy self) internal pure returns (int24 r) {
        assembly {
            r := sub(and(self, RATE_MASK), MAX_FEE_RATE)
        }
    }

    function calculateFee(FeePolicy self, uint256 amount, bool reverseRounding) internal pure returns (int256 fee) {
        int24 r = rate(self);

        bool positive = r > 0;
        uint256 absRate;
        unchecked {
            absRate = uint256(uint24(positive ? r : -r));
        }
        // @dev absFee must be less than type(int256).max
        uint256 absFee = Math.divide(amount * absRate, RATE_PRECISION, reverseRounding ? !positive : positive);
        fee = positive ? int256(absFee) : -int256(absFee);
    }

    function calculateOriginalAmount(FeePolicy self, uint256 amount, bool reverseFee)
        internal
        pure
        returns (uint256 originalAmount)
    {
        int24 r = rate(self);

        uint256 divider;
        assembly {
            if reverseFee { r := sub(0, r) }
            divider := add(RATE_PRECISION, r)
        }
        originalAmount = Math.divide(amount * RATE_PRECISION, divider, reverseFee);
    }
}

// @openzeppelin/contracts/interfaces/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

// @openzeppelin/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

// @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

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

// @openzeppelin/contracts/token/ERC721/IERC721.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

/**
 * @dev Required interface of an ERC-721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC-721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC-721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// @openzeppelin/contracts/access/Ownable.sol

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

// clober-dex/v2-core/libraries/Tick.sol

type Tick is int24;

library TickLibrary {
    using Math for *;
    using TickLibrary for Tick;

    error InvalidTick();
    error InvalidPrice();
    error TickOverflow();

    int24 internal constant MAX_TICK = 2 ** 19 - 1;
    int24 internal constant MIN_TICK = -MAX_TICK;

    uint256 internal constant MIN_PRICE = 1350587;
    uint256 internal constant MAX_PRICE = 4647684107270898330752324302845848816923571339324334;

    uint256 private constant _R0 = 0xfff97272373d413259a46990;
    uint256 private constant _R1 = 0xfff2e50f5f656932ef12357c;
    uint256 private constant _R2 = 0xffe5caca7e10e4e61c3624ea;
    uint256 private constant _R3 = 0xffcb9843d60f6159c9db5883;
    uint256 private constant _R4 = 0xff973b41fa98c081472e6896;
    uint256 private constant _R5 = 0xff2ea16466c96a3843ec78b3;
    uint256 private constant _R6 = 0xfe5dee046a99a2a811c461f1;
    uint256 private constant _R7 = 0xfcbe86c7900a88aedcffc83b;
    uint256 private constant _R8 = 0xf987a7253ac413176f2b074c;
    uint256 private constant _R9 = 0xf3392b0822b70005940c7a39;
    uint256 private constant _R10 = 0xe7159475a2c29b7443b29c7f;
    uint256 private constant _R11 = 0xd097f3bdfd2022b8845ad8f7;
    uint256 private constant _R12 = 0xa9f746462d870fdf8a65dc1f;
    uint256 private constant _R13 = 0x70d869a156d2a1b890bb3df6;
    uint256 private constant _R14 = 0x31be135f97d08fd981231505;
    uint256 private constant _R15 = 0x9aa508b5b7a84e1c677de54;
    uint256 private constant _R16 = 0x5d6af8dedb81196699c329;
    uint256 private constant _R17 = 0x2216e584f5fa1ea92604;
    uint256 private constant _R18 = 0x48a170391f7dc42;
    uint256 private constant _R19 = 0x149b34;

    function validateTick(Tick tick) internal pure {
        if (Tick.unwrap(tick) > MAX_TICK || Tick.unwrap(tick) < MIN_TICK) revert InvalidTick();
    }

    modifier validatePrice(uint256 price) {
        if (price > MAX_PRICE || price < MIN_PRICE) revert InvalidPrice();
        _;
    }

    function fromPrice(uint256 price) internal pure validatePrice(price) returns (Tick) {
        unchecked {
            int24 tick = int24((int256(price).lnWad() * 42951820407860) / 2 ** 128);
            if (toPrice(Tick.wrap(tick)) > price) return Tick.wrap(tick - 1);
            return Tick.wrap(tick);
        }
    }

    function toPrice(Tick tick) internal pure returns (uint256 price) {
        validateTick(tick);
        int24 tickValue = Tick.unwrap(tick);
        uint256 absTick = uint24(tickValue < 0 ? -tickValue : tickValue);

        unchecked {
            if (absTick & 0x1 != 0) price = _R0;
            else price = 1 << 96;
            if (absTick & 0x2 != 0) price = (price * _R1) >> 96;
            if (absTick & 0x4 != 0) price = (price * _R2) >> 96;
            if (absTick & 0x8 != 0) price = (price * _R3) >> 96;
            if (absTick & 0x10 != 0) price = (price * _R4) >> 96;
            if (absTick & 0x20 != 0) price = (price * _R5) >> 96;
            if (absTick & 0x40 != 0) price = (price * _R6) >> 96;
            if (absTick & 0x80 != 0) price = (price * _R7) >> 96;
            if (absTick & 0x100 != 0) price = (price * _R8) >> 96;
            if (absTick & 0x200 != 0) price = (price * _R9) >> 96;
            if (absTick & 0x400 != 0) price = (price * _R10) >> 96;
            if (absTick & 0x800 != 0) price = (price * _R11) >> 96;
            if (absTick & 0x1000 != 0) price = (price * _R12) >> 96;
            if (absTick & 0x2000 != 0) price = (price * _R13) >> 96;
            if (absTick & 0x4000 != 0) price = (price * _R14) >> 96;
            if (absTick & 0x8000 != 0) price = (price * _R15) >> 96;
            if (absTick & 0x10000 != 0) price = (price * _R16) >> 96;
            if (absTick & 0x20000 != 0) price = (price * _R17) >> 96;
            if (absTick & 0x40000 != 0) price = (price * _R18) >> 96;
        }
        if (tickValue > 0) price = 0x1000000000000000000000000000000000000000000000000 / price;
    }

    function gt(Tick a, Tick b) internal pure returns (bool) {
        return Tick.unwrap(a) > Tick.unwrap(b);
    }

    function baseToQuote(Tick tick, uint256 base, bool roundingUp) internal pure returns (uint256) {
        return Math.divide((base * tick.toPrice()), 1 << 96, roundingUp);
    }

    function quoteToBase(Tick tick, uint256 quote, bool roundingUp) internal pure returns (uint256) {
        // @dev quote = unit(uint64) * unitSize(uint64) < 2^96
        //      We don't need to check overflow here
        return Math.divide(quote << 96, tick.toPrice(), roundingUp);
    }
}

// @openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Metadata.sol)

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// clober-dex/v2-core/interfaces/IERC721Permit.sol

/**
 * @title IERC721Permit
 * @notice An interface for the ERC721 permit extension
 */
interface IERC721Permit is IERC721 {
    error InvalidSignature();
    error PermitExpired();

    /**
     * @notice The EIP-712 typehash for the permit struct used by the contract
     */
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /**
     * @notice The EIP-712 domain separator for this contract
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @notice Approve the spender to transfer the given tokenId
     * @param spender The address to approve
     * @param tokenId The tokenId to approve
     * @param deadline The deadline for the signature
     * @param v The recovery id of the signature
     * @param r The r value of the signature
     * @param s The s value of the signature
     */
    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @notice Get the current nonce for a token
     * @param tokenId The tokenId to get the nonce for
     * @return The current nonce
     */
    function nonces(uint256 tokenId) external view returns (uint256);
}

// @openzeppelin/contracts/access/Ownable2Step.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable2Step.sol)

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This extension of the {Ownable} contract includes a two-step mechanism to transfer
 * ownership, where the new owner must call {acceptOwnership} in order to replace the
 * old one. This can help prevent common mistakes, such as transfers of ownership to
 * incorrect accounts, or to contracts that are unable to interact with the
 * permission system.
 *
 * The initial owner is specified at deployment time in the constructor for `Ownable`. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}

// @openzeppelin/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1363.sol)

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

// @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

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
    using Address for address;

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
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
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
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// clober-dex/v2-core/libraries/BookId.sol

type BookId is uint192;

library BookIdLibrary {
    function toId(IBookManager.BookKey memory bookKey) internal pure returns (BookId id) {
        bytes32 hash = keccak256(abi.encode(bookKey));
        assembly {
            id := and(hash, 0xffffffffffffffffffffffffffffffffffffffffffffffff)
        }
    }
}

// clober-dex/v2-core/interfaces/IBookManager.sol

/**
 * @title IBookManager
 * @notice The interface for the BookManager contract
 */
interface IBookManager is IERC721Metadata, IERC721Permit {
    error InvalidUnitSize();
    error InvalidFeePolicy();
    error InvalidProvider(address provider);
    error LockedBy(address locker, address hook);
    error CurrencyNotSettled();

    /**
     * @notice Event emitted when a new book is opened
     * @param id The book id
     * @param base The base currency
     * @param quote The quote currency
     * @param unitSize The unit size of the book
     * @param makerPolicy The maker fee policy
     * @param takerPolicy The taker fee policy
     * @param hooks The hooks contract
     */
    event Open(
        BookId indexed id,
        Currency indexed base,
        Currency indexed quote,
        uint64 unitSize,
        FeePolicy makerPolicy,
        FeePolicy takerPolicy,
        IHooks hooks
    );

    /**
     * @notice Event emitted when a new order is made
     * @param bookId The book id
     * @param user The user address
     * @param tick The order tick
     * @param orderIndex The order index
     * @param unit The order unit
     * @param provider The provider address
     */
    event Make(
        BookId indexed bookId, address indexed user, Tick tick, uint256 orderIndex, uint64 unit, address provider
    );

    /**
     * @notice Event emitted when an order is taken
     * @param bookId The book id
     * @param user The user address
     * @param tick The order tick
     * @param unit The order unit
     */
    event Take(BookId indexed bookId, address indexed user, Tick tick, uint64 unit);

    /**
     * @notice Event emitted when an order is canceled
     * @param orderId The order id
     * @param unit The canceled unit
     */
    event Cancel(OrderId indexed orderId, uint64 unit);

    /**
     * @notice Event emitted when an order is claimed
     * @param orderId The order id
     * @param unit The claimed unit
     */
    event Claim(OrderId indexed orderId, uint64 unit);

    /**
     * @notice Event emitted when a provider is whitelisted
     * @param provider The provider address
     */
    event Whitelist(address indexed provider);

    /**
     * @notice Event emitted when a provider is delisted
     * @param provider The provider address
     */
    event Delist(address indexed provider);

    /**
     * @notice Event emitted when a provider collects fees
     * @param provider The provider address
     * @param recipient The recipient address
     * @param currency The currency
     * @param amount The collected amount
     */
    event Collect(address indexed provider, address indexed recipient, Currency indexed currency, uint256 amount);

    /**
     * @notice Event emitted when new default provider is set
     * @param newDefaultProvider The new default provider address
     */
    event SetDefaultProvider(address indexed newDefaultProvider);

    /**
     * @notice This structure represents a unique identifier for a book in the BookManager.
     * @param base The base currency of the book
     * @param unitSize The unit size of the book
     * @param quote The quote currency of the book
     * @param makerPolicy The maker fee policy of the book
     * @param hooks The hooks contract of the book
     * @param takerPolicy The taker fee policy of the book
     */
    struct BookKey {
        Currency base;
        uint64 unitSize;
        Currency quote;
        FeePolicy makerPolicy;
        IHooks hooks;
        FeePolicy takerPolicy;
    }

    /**
     * @notice Returns the base URI
     * @return The base URI
     */
    function baseURI() external view returns (string memory);

    /**
     * @notice Returns the contract URI
     * @return The contract URI
     */
    function contractURI() external view returns (string memory);

    /**
     * @notice Returns the default provider
     * @return The default provider
     */
    function defaultProvider() external view returns (address);

    /**
     * @notice Returns the total reserves of a given currency
     * @param currency The currency in question
     * @return The total reserves amount
     */
    function reservesOf(Currency currency) external view returns (uint256);

    /**
     * @notice Checks if a provider is whitelisted
     * @param provider The address of the provider
     * @return True if the provider is whitelisted, false otherwise
     */
    function isWhitelisted(address provider) external view returns (bool);

    /**
     * @notice Verifies if an owner has authorized a spender for a token
     * @param owner The address of the token owner
     * @param spender The address of the spender
     * @param tokenId The token ID
     */
    function checkAuthorized(address owner, address spender, uint256 tokenId) external view;

    /**
     * @notice Calculates the amount owed to a provider in a given currency
     * @param provider The provider's address
     * @param currency The currency in question
     * @return The owed amount
     */
    function tokenOwed(address provider, Currency currency) external view returns (uint256);

    /**
     * @notice Calculates the currency balance changes for a given locker
     * @param locker The address of the locker
     * @param currency The currency in question
     * @return The net change in currency balance
     */
    function getCurrencyDelta(address locker, Currency currency) external view returns (int256);

    /**
     * @notice Retrieves the book key for a given book ID
     * @param id The book ID
     * @return The book key
     */
    function getBookKey(BookId id) external view returns (BookKey memory);

    /**
     * @notice This structure represents a current status for an order in the BookManager.
     * @param provider The provider of the order
     * @param open The open unit of the order
     * @param claimable The claimable unit of the order
     */
    struct OrderInfo {
        address provider;
        uint64 open;
        uint64 claimable;
    }

    /**
     * @notice Provides information about an order
     * @param id The order ID
     * @return Order information including provider, open status, and claimable unit
     */
    function getOrder(OrderId id) external view returns (OrderInfo memory);

    /**
     * @notice Retrieves the locker and caller addresses for a given lock
     * @param i The index of the lock
     * @return locker The locker's address
     * @return lockCaller The caller's address
     */
    function getLock(uint256 i) external view returns (address locker, address lockCaller);

    /**
     * @notice Provides the lock data
     * @return The lock data including necessary numeric values
     */
    function getLockData() external view returns (uint128, uint128);

    /**
     * @notice Returns the depth of a given book ID and tick
     * @param id The book ID
     * @param tick The tick
     * @return The depth of the tick
     */
    function getDepth(BookId id, Tick tick) external view returns (uint64);

    /**
     * @notice Retrieves the highest tick for a given book ID
     * @param id The book ID
     * @return tick The highest tick
     */
    function getHighest(BookId id) external view returns (Tick tick);

    /**
     * @notice Finds the maximum tick less than a specified tick in a book
     * @dev Returns `Tick.wrap(type(int24).min)` if the specified tick is the lowest
     * @param id The book ID
     * @param tick The specified tick
     * @return The next lower tick
     */
    function maxLessThan(BookId id, Tick tick) external view returns (Tick);

    /**
     * @notice Checks if a book is opened
     * @param id The book ID
     * @return True if the book is opened, false otherwise
     */
    function isOpened(BookId id) external view returns (bool);

    /**
     * @notice Checks if a book is empty
     * @param id The book ID
     * @return True if the book is empty, false otherwise
     */
    function isEmpty(BookId id) external view returns (bool);

    /**
     * @notice Encodes a BookKey into a BookId
     * @param key The BookKey to encode
     * @return The encoded BookId
     */
    function encodeBookKey(BookKey calldata key) external pure returns (BookId);

    /**
     * @notice Loads a value from a specific storage slot
     * @param slot The storage slot
     * @return The value in the slot
     */
    function load(bytes32 slot) external view returns (bytes32);

    /**
     * @notice Loads a sequence of values starting from a specific slot
     * @param startSlot The starting slot
     * @param nSlot The number of slots to load
     * @return The sequence of values
     */
    function load(bytes32 startSlot, uint256 nSlot) external view returns (bytes memory);

    /**
     * @notice Opens a new book
     * @param key The book key
     * @param hookData The hook data
     */
    function open(BookKey calldata key, bytes calldata hookData) external;

    /**
     * @notice Locks a book manager function
     * @param locker The locker address
     * @param data The lock data
     * @return The lock return data
     */
    function lock(address locker, bytes calldata data) external returns (bytes memory);

    /**
     * @notice This structure represents the parameters for making an order.
     * @param key The book key for the order
     * @param tick The tick for the order
     * @param unit The unit for the order. Times key.unitSize to get actual bid amount.
     * @param provider The provider for the order. The limit order service provider address to collect fees.
     */
    struct MakeParams {
        BookKey key;
        Tick tick;
        uint64 unit;
        address provider;
    }

    /**
     * @notice Make a limit order
     * @param params The order parameters
     * @param hookData The hook data
     * @return id The order id. Returns 0 if the order is not settled
     * @return quoteAmount The amount of quote currency to be paid
     */
    function make(MakeParams calldata params, bytes calldata hookData)
        external
        returns (OrderId id, uint256 quoteAmount);

    /**
     * @notice This structure represents the parameters for taking orders in the specified tick.
     * @param key The book key for the order
     * @param tick The tick for the order
     * @param maxUnit The max unit to take
     */
    struct TakeParams {
        BookKey key;
        Tick tick;
        uint64 maxUnit;
    }

    /**
     * @notice Take a limit order at specific tick
     * @param params The order parameters
     * @param hookData The hook data
     * @return quoteAmount The amount of quote currency to be received
     * @return baseAmount The amount of base currency to be paid
     */
    function take(TakeParams calldata params, bytes calldata hookData)
        external
        returns (uint256 quoteAmount, uint256 baseAmount);

    /**
     * @notice This structure represents the parameters for canceling an order.
     * @param id The order id for the order
     * @param toUnit The remaining open unit for the order after cancellation. Must not exceed the current open unit.
     */
    struct CancelParams {
        OrderId id;
        uint64 toUnit;
    }

    /**
     * @notice Cancel a limit order
     * @param params The order parameters
     * @param hookData The hook data
     * @return canceledAmount The amount of quote currency canceled
     */
    function cancel(CancelParams calldata params, bytes calldata hookData) external returns (uint256 canceledAmount);

    /**
     * @notice Claims an order
     * @param id The order ID
     * @param hookData The hook data
     * @return claimedAmount The amount claimed
     */
    function claim(OrderId id, bytes calldata hookData) external returns (uint256 claimedAmount);

    /**
     * @notice Collects fees from a provider
     * @param recipient The recipient address
     * @param currency The currency
     * @return The collected amount
     */
    function collect(address recipient, Currency currency) external returns (uint256);

    /**
     * @notice Withdraws a currency
     * @param currency The currency
     * @param to The recipient address
     * @param amount The amount
     */
    function withdraw(Currency currency, address to, uint256 amount) external;

    /**
     * @notice Settles a currency
     * @param currency The currency
     * @return The settled amount
     */
    function settle(Currency currency) external payable returns (uint256);

    /**
     * @notice Whitelists a provider
     * @param provider The provider address
     */
    function whitelist(address provider) external;

    /**
     * @notice Delists a provider
     * @param provider The provider address
     */
    function delist(address provider) external;

    /**
     * @notice Sets the default provider
     * @param newDefaultProvider The new default provider address
     */
    function setDefaultProvider(address newDefaultProvider) external;
}

// clober-dex/v2-core/interfaces/IHooks.sol

/**
 * @title IHooks
 * @notice Interface for the hooks contract
 */
interface IHooks {
    /**
     * @notice Hook called before opening a new book
     * @param sender The sender of the open transaction
     * @param key The key of the book being opened
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function beforeOpen(address sender, IBookManager.BookKey calldata key, bytes calldata hookData)
        external
        returns (bytes4);

    /**
     * @notice Hook called after opening a new book
     * @param sender The sender of the open transaction
     * @param key The key of the book being opened
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function afterOpen(address sender, IBookManager.BookKey calldata key, bytes calldata hookData)
        external
        returns (bytes4);

    /**
     * @notice Hook called before making a new order
     * @param sender The sender of the make transaction
     * @param params The parameters of the make transaction
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function beforeMake(address sender, IBookManager.MakeParams calldata params, bytes calldata hookData)
        external
        returns (bytes4);

    /**
     * @notice Hook called after making a new order
     * @param sender The sender of the make transaction
     * @param params The parameters of the make transaction
     * @param orderId The id of the order that was made
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function afterMake(
        address sender,
        IBookManager.MakeParams calldata params,
        OrderId orderId,
        bytes calldata hookData
    ) external returns (bytes4);

    /**
     * @notice Hook called before taking an order
     * @param sender The sender of the take transaction
     * @param params The parameters of the take transaction
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function beforeTake(address sender, IBookManager.TakeParams calldata params, bytes calldata hookData)
        external
        returns (bytes4);

    /**
     * @notice Hook called after taking an order
     * @param sender The sender of the take transaction
     * @param params The parameters of the take transaction
     * @param takenUnit The unit that was taken
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function afterTake(
        address sender,
        IBookManager.TakeParams calldata params,
        uint64 takenUnit,
        bytes calldata hookData
    ) external returns (bytes4);

    /**
     * @notice Hook called before canceling an order
     * @param sender The sender of the cancel transaction
     * @param params The parameters of the cancel transaction
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function beforeCancel(address sender, IBookManager.CancelParams calldata params, bytes calldata hookData)
        external
        returns (bytes4);

    /**
     * @notice Hook called after canceling an order
     * @param sender The sender of the cancel transaction
     * @param params The parameters of the cancel transaction
     * @param canceledUnit The unit that was canceled
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function afterCancel(
        address sender,
        IBookManager.CancelParams calldata params,
        uint64 canceledUnit,
        bytes calldata hookData
    ) external returns (bytes4);

    /**
     * @notice Hook called before claiming an order
     * @param sender The sender of the claim transaction
     * @param orderId The id of the order being claimed
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function beforeClaim(address sender, OrderId orderId, bytes calldata hookData) external returns (bytes4);

    /**
     * @notice Hook called after claiming an order
     * @param sender The sender of the claim transaction
     * @param orderId The id of the order being claimed
     * @param claimedUnit The unit that was claimed
     * @param hookData The data passed to the hook
     * @return Returns the function selector if the hook is successful
     */
    function afterClaim(address sender, OrderId orderId, uint64 claimedUnit, bytes calldata hookData)
        external
        returns (bytes4);
}

// clober-dex/v2-core/libraries/OrderId.sol

type OrderId is uint256;

library OrderIdLibrary {
    /**
     * @dev Encode the order id.
     * @param bookId The book id.
     * @param tick The tick.
     * @param index The index.
     * @return id The order id.
     */
    function encode(BookId bookId, Tick tick, uint40 index) internal pure returns (OrderId id) {
        // @dev If we just use tick at the assembly code, the code will convert tick into bytes32.
        //      e.g. When index == -2, the shifted value( shl(40, tick) ) will be
        //      0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0000000000 instead of 0xfffffffe0000000000
        //      Therefore, we have to safely cast tick into uint256 first.
        uint256 _tick = uint256(uint24(Tick.unwrap(tick)));
        assembly {
            id := add(index, add(shl(40, _tick), shl(64, bookId)))
        }
    }

    function decode(OrderId id) internal pure returns (BookId bookId, Tick tick, uint40 index) {
        assembly {
            bookId := shr(64, id)
            tick := and(shr(40, id), 0xffffff)
            index := and(id, 0xffffffffff)
        }
    }

    function getBookId(OrderId id) internal pure returns (BookId bookId) {
        assembly {
            bookId := shr(64, id)
        }
    }

    function getTick(OrderId id) internal pure returns (Tick tick) {
        assembly {
            tick := and(shr(40, id), 0xffffff)
        }
    }

    function getIndex(OrderId id) internal pure returns (uint40 index) {
        assembly {
            index := and(id, 0xffffffffff)
        }
    }
}

// src/interfaces/IStrategy.sol

interface IStrategy {
    struct Order {
        Tick tick;
        uint64 rawAmount;
    }

    /**
     * @notice Retrieves the orders for a specified key.
     * @param key The key of the pool.
     * @return ordersA The orders for the first token.
     * @return ordersB The orders for the second token.
     * @dev Clears pool orders if an error occurs and retains current orders if the list is empty.
     */
    function computeOrders(bytes32 key) external view returns (Order[] memory ordersA, Order[] memory ordersB);

    /**
     * @notice Hook that is called after minting.
     * @param sender The address of the sender.
     * @param key The key of the pool.
     * @param mintAmount The amount minted.
     * @param lastTotalSupply The total supply before minting.
     */
    function mintHook(address sender, bytes32 key, uint256 mintAmount, uint256 lastTotalSupply) external;

    /**
     * @notice Hook that is called after burning.
     * @param sender The address of the sender.
     * @param key The key of the pool.
     * @param burnAmount The amount burned.
     * @param lastTotalSupply The total supply before burning.
     */
    function burnHook(address sender, bytes32 key, uint256 burnAmount, uint256 lastTotalSupply) external;

    /**
     * @notice Hook that is called after rebalancing.
     * @param sender The address of the sender.
     * @param key The key of the pool.
     * @param liquidityA The liquidity orders for the first token.
     * @param liquidityB The liquidity orders for the second token.
     */
    function rebalanceHook(address sender, bytes32 key, Order[] memory liquidityA, Order[] memory liquidityB)
        external;
}

// src/interfaces/IRebalancer.sol

interface IRebalancer {
    struct Pool {
        BookId bookIdA;
        BookId bookIdB;
        IStrategy strategy;
        uint256 reserveA;
        uint256 reserveB;
        OrderId[] orderListA;
        OrderId[] orderListB;
    }

    error NotSelf();
    error InvalidHook();
    error InvalidStrategy();
    error InvalidBookPair();
    error AlreadyOpened();
    error InvalidLockAcquiredSender();
    error InvalidLockCaller();
    error LockFailure();
    error InvalidMaker();
    error InvalidAmount();
    error InvalidValue();
    error Slippage();

    event Open(bytes32 indexed key, BookId indexed bookIdA, BookId indexed bookIdB, bytes32 salt, address strategy);
    event Mint(address indexed user, bytes32 indexed key, uint256 amountA, uint256 amountB, uint256 lpAmount);
    event Burn(address indexed user, bytes32 indexed key, uint256 amountA, uint256 amountB, uint256 lpAmount);
    event Rebalance(bytes32 indexed key);
    event Claim(bytes32 indexed key, uint256 claimedAmountA, uint256 claimedAmountB);
    event Cancel(bytes32 indexed key, uint256 canceledAmountA, uint256 canceledAmountB);

    struct Liquidity {
        uint256 reserve;
        uint256 claimable;
        uint256 cancelable;
    }

    /**
     * @notice Retrieves the book pair for a specified book ID.
     * @param bookId The book ID.
     * @return The book pair.
     */
    function bookPair(BookId bookId) external view returns (BookId);

    /**
     * @notice Retrieves the pool for a specified key.
     * @param key The key of the pool.
     * @return The pool.
     */
    function getPool(bytes32 key) external view returns (Pool memory);

    /**
     * @notice Retrieves the book pairs for a specified key.
     * @param key The key of the pool.
     * @return bookIdA The book ID for the first book.
     * @return bookIdB The book ID for the second book.
     */
    function getBookPairs(bytes32 key) external view returns (BookId bookIdA, BookId bookIdB);

    /**
     * @notice Retrieves the liquidity for a specified key.
     * @param key The key of the pool.
     * @return liquidityA The liquidity for the first token.
     * @return liquidityB The liquidity for the second token.
     */
    function getLiquidity(bytes32 key)
        external
        view
        returns (Liquidity memory liquidityA, Liquidity memory liquidityB);

    /**
     * @notice Opens a new pool with the specified parameters.
     * @param bookKeyA The book key for the first book.
     * @param bookKeyB The book key for the second book.
     * @param salt The salt value.
     * @param strategy The address of the strategy.
     * @return key The key of the opened pool.
     */
    function open(
        IBookManager.BookKey calldata bookKeyA,
        IBookManager.BookKey calldata bookKeyB,
        bytes32 salt,
        address strategy
    ) external returns (bytes32 key);

    /**
     * @notice Mints liquidity for the specified key.
     * @param key The key of the pool.
     * @param amountA The amount of the first token.
     * @param amountB The amount of the second token.
     * @param minLpAmount The minimum amount of liquidity tokens to mint.
     * @return The amount of liquidity tokens minted.
     */
    function mint(bytes32 key, uint256 amountA, uint256 amountB, uint256 minLpAmount)
        external
        payable
        returns (uint256);

    /**
     * @notice Burns liquidity for the specified key.
     * @param key The key of the pool.
     * @param amount The amount of liquidity tokens to burn.
     * @param minAmountA The amount of the first token to receive.
     * @param minAmountB The minimum amount of the second token to receive.
     * @return The amounts of the first and second tokens to receive.
     */
    function burn(bytes32 key, uint256 amount, uint256 minAmountA, uint256 minAmountB)
        external
        returns (uint256, uint256);

    /**
     * @notice Rebalances the pool for the specified key.
     * @param key The key of the pool.
     */
    function rebalance(bytes32 key) external;
}

// src/Rebalancer.sol

contract Rebalancer is IRebalancer, ILocker, Ownable2Step, ERC6909Supply {
    using BookIdLibrary for IBookManager.BookKey;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using CurrencyLibrary for Currency;
    using OrderIdLibrary for OrderId;
    using TickLibrary for Tick;
    using FeePolicyLibrary for FeePolicy;

    uint256 public constant RATE_PRECISION = 1e6;

    IBookManager public immutable bookManager;

    mapping(bytes32 key => Pool) private _pools;
    mapping(BookId => BookId) public bookPair;

    modifier selfOnly() {
        if (msg.sender != address(this)) revert NotSelf();
        _;
    }

    constructor(IBookManager bookManager_, address initialOwner_) Ownable(initialOwner_) {
        bookManager = bookManager_;
    }

    function decimals(uint256) external pure returns (uint8) {
        return 18;
    }

    function getPool(bytes32 key) external view returns (Pool memory) {
        return _pools[key];
    }

    function getBookPairs(bytes32 key) external view returns (BookId, BookId) {
        return (_pools[key].bookIdA, _pools[key].bookIdB);
    }

    function getLiquidity(bytes32 key) public view returns (Liquidity memory liquidityA, Liquidity memory liquidityB) {
        Pool storage pool = _pools[key];
        liquidityA.reserve = pool.reserveA;
        liquidityB.reserve = pool.reserveB;

        OrderId[] memory orderListA = pool.orderListA;
        OrderId[] memory orderListB = pool.orderListB;

        if (orderListA.length > 0) {
            IBookManager.BookKey memory bookKeyA = bookManager.getBookKey(pool.bookIdA);
            for (uint256 i; i < orderListA.length; ++i) {
                (uint256 cancelable, uint256 claimable) =
                    _getLiquidity(bookKeyA.makerPolicy, bookKeyA.unitSize, orderListA[i]);
                liquidityA.cancelable += cancelable;
                liquidityB.claimable += claimable;
            }
        }
        if (orderListB.length > 0) {
            IBookManager.BookKey memory bookKeyB = bookManager.getBookKey(pool.bookIdB);
            for (uint256 i; i < orderListB.length; ++i) {
                (uint256 cancelable, uint256 claimable) =
                    _getLiquidity(bookKeyB.makerPolicy, bookKeyB.unitSize, orderListB[i]);
                liquidityA.claimable += claimable;
                liquidityB.cancelable += cancelable;
            }
        }
    }

    function _getLiquidity(FeePolicy makerPolicy, uint64 unitSize, OrderId orderId)
        internal
        view
        returns (uint256 cancelable, uint256 claimable)
    {
        IBookManager.OrderInfo memory orderInfo = bookManager.getOrder(orderId);
        cancelable = uint256(orderInfo.open) * unitSize;
        claimable = orderId.getTick().quoteToBase(uint256(orderInfo.claimable) * unitSize, false);
        if (makerPolicy.usesQuote()) {
            int256 fee = makerPolicy.calculateFee(cancelable, true);
            cancelable = uint256(int256(cancelable) + fee);
        } else {
            int256 fee = makerPolicy.calculateFee(claimable, false);
            claimable = uint256(int256(claimable) - fee);
        }
    }

    function open(
        IBookManager.BookKey calldata bookKeyA,
        IBookManager.BookKey calldata bookKeyB,
        bytes32 salt,
        address strategy
    ) external returns (bytes32) {
        return abi.decode(
            bookManager.lock(
                address(this), abi.encodeWithSelector(this._open.selector, bookKeyA, bookKeyB, salt, strategy)
            ),
            (bytes32)
        );
    }

    function mint(bytes32 key, uint256 amountA, uint256 amountB, uint256 minLpAmount)
        external
        payable
        returns (uint256 mintAmount)
    {
        Pool storage pool = _pools[key];
        IBookManager.BookKey memory bookKeyA = bookManager.getBookKey(pool.bookIdA);

        uint256 supply = totalSupply[uint256(key)];
        if (supply == 0) {
            if (amountA == 0 || amountB == 0) revert InvalidAmount();
            // @dev If the decimals > 18, it will revert.
            uint256 complementA =
                bookKeyA.quote.isNative() ? 1 : 10 ** (18 - IERC20Metadata(Currency.unwrap(bookKeyA.quote)).decimals());
            uint256 complementB =
                bookKeyA.base.isNative() ? 1 : 10 ** (18 - IERC20Metadata(Currency.unwrap(bookKeyA.base)).decimals());
            uint256 _amountA = amountA * complementA;
            uint256 _amountB = amountB * complementB;
            mintAmount = _amountA > _amountB ? _amountA : _amountB;
        } else {
            (Liquidity memory liquidityA, Liquidity memory liquidityB) = getLiquidity(key);
            uint256 totalLiquidityA = liquidityA.reserve + liquidityA.claimable + liquidityA.cancelable;
            uint256 totalLiquidityB = liquidityB.reserve + liquidityB.claimable + liquidityB.cancelable;

            if (totalLiquidityA == 0 && totalLiquidityB == 0) {
                mintAmount = amountA = amountB = 0;
            } else if (totalLiquidityA == 0) {
                mintAmount = FixedPointMathLib.mulDivDown(amountB, supply, totalLiquidityB);
                amountA = 0;
            } else if (totalLiquidityB == 0) {
                mintAmount = FixedPointMathLib.mulDivDown(amountA, supply, totalLiquidityA);
                amountB = 0;
            } else {
                uint256 mintA = FixedPointMathLib.mulDivDown(amountA, supply, totalLiquidityA);
                uint256 mintB = FixedPointMathLib.mulDivDown(amountB, supply, totalLiquidityB);
                if (mintA > mintB) {
                    mintAmount = mintB;
                    amountA = FixedPointMathLib.mulDivUp(totalLiquidityA, mintAmount, supply);
                } else {
                    mintAmount = mintA;
                    amountB = FixedPointMathLib.mulDivUp(totalLiquidityB, mintAmount, supply);
                }
            }
        }
        if (mintAmount < minLpAmount) revert Slippage();

        uint256 refund = msg.value;
        if (bookKeyA.quote.isNative()) {
            if (msg.value < amountA) {
                revert InvalidValue();
            } else {
                unchecked {
                    refund -= amountA;
                }
            }
        } else {
            IERC20(Currency.unwrap(bookKeyA.quote)).safeTransferFrom(msg.sender, address(this), amountA);
        }
        if (bookKeyA.base.isNative()) {
            if (msg.value < amountB) {
                revert InvalidValue();
            } else {
                unchecked {
                    refund -= amountB;
                }
            }
        } else {
            IERC20(Currency.unwrap(bookKeyA.base)).safeTransferFrom(msg.sender, address(this), amountB);
        }

        pool.reserveA += amountA;
        pool.reserveB += amountB;

        _mint(msg.sender, uint256(key), mintAmount);
        pool.strategy.mintHook(msg.sender, key, mintAmount, supply);
        emit Mint(msg.sender, key, amountA, amountB, mintAmount);

        if (refund > 0) {
            CurrencyLibrary.NATIVE.transfer(msg.sender, refund);
        }
    }

    function burn(bytes32 key, uint256 amount, uint256 minAmountA, uint256 minAmountB)
        external
        returns (uint256 withdrawalA, uint256 withdrawalB)
    {
        (withdrawalA, withdrawalB) = abi.decode(
            bookManager.lock(address(this), abi.encodeWithSelector(this._burn.selector, key, msg.sender, amount)),
            (uint256, uint256)
        );
        if (withdrawalA < minAmountA || withdrawalB < minAmountB) revert Slippage();
    }

    function rebalance(bytes32 key) public {
        bookManager.lock(address(this), abi.encodeWithSelector(this._rebalance.selector, key));
    }

    function lockAcquired(address lockCaller, bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(bookManager)) revert InvalidLockAcquiredSender();
        if (lockCaller != address(this)) revert InvalidLockCaller();

        (bool success, bytes memory returnData) = address(this).call(data);
        if (success) return returnData;
        if (returnData.length == 0) revert LockFailure();
        // if the call failed, bubble up the reason
        /// @solidity memory-safe-assembly
        assembly {
            revert(add(returnData, 32), mload(returnData))
        }
    }

    function _open(
        IBookManager.BookKey calldata bookKeyA,
        IBookManager.BookKey calldata bookKeyB,
        bytes32 salt,
        address strategy
    ) public selfOnly returns (bytes32 key) {
        if (
            !(bookKeyA.quote.equals(bookKeyB.base) && bookKeyA.base.equals(bookKeyB.quote))
                || bookKeyA.quote.equals(bookKeyA.base)
        ) revert InvalidBookPair();
        if (address(bookKeyA.hooks) != address(0) || address(bookKeyB.hooks) != address(0)) revert InvalidHook();
        if (strategy == address(0)) revert InvalidStrategy();

        BookId bookIdA = bookKeyA.toId();
        BookId bookIdB = bookKeyB.toId();
        if (!bookManager.isOpened(bookIdA)) bookManager.open(bookKeyA, "");
        if (!bookManager.isOpened(bookIdB)) bookManager.open(bookKeyB, "");

        key = _encodeKey(bookIdA, bookIdB, salt);
        if (_pools[key].strategy != IStrategy(address(0))) revert AlreadyOpened();

        _pools[key].bookIdA = bookIdA;
        _pools[key].bookIdB = bookIdB;
        _pools[key].strategy = IStrategy(strategy);
        bookPair[bookIdA] = bookIdB;
        bookPair[bookIdB] = bookIdA;

        emit Open(key, bookIdA, bookIdB, salt, strategy);
    }

    function _burn(bytes32 key, address user, uint256 burnAmount)
        public
        selfOnly
        returns (uint256 withdrawalA, uint256 withdrawalB)
    {
        Pool storage pool = _pools[key];
        uint256 supply = totalSupply[uint256(key)];

        (uint256 canceledAmountA, uint256 canceledAmountB, uint256 claimedAmountA, uint256 claimedAmountB) =
            _clearPool(key, pool, burnAmount, supply);

        uint256 reserveA = pool.reserveA;
        uint256 reserveB = pool.reserveB;

        withdrawalA = (reserveA + claimedAmountA) * burnAmount / supply + canceledAmountA;
        withdrawalB = (reserveB + claimedAmountB) * burnAmount / supply + canceledAmountB;

        _burn(user, uint256(key), burnAmount);
        pool.strategy.burnHook(msg.sender, key, burnAmount, supply);
        emit Burn(user, key, withdrawalA, withdrawalB, burnAmount);

        IBookManager.BookKey memory bookKeyA = bookManager.getBookKey(pool.bookIdA);

        pool.reserveA = _settleCurrency(bookKeyA.quote, reserveA) - withdrawalA;
        pool.reserveB = _settleCurrency(bookKeyA.base, reserveB) - withdrawalB;

        if (withdrawalA > 0) {
            bookKeyA.quote.transfer(user, withdrawalA);
        }
        if (withdrawalB > 0) {
            bookKeyA.base.transfer(user, withdrawalB);
        }
    }

    function _rebalance(bytes32 key) public selfOnly {
        Pool storage pool = _pools[key];
        uint256 reserveA = pool.reserveA;
        uint256 reserveB = pool.reserveB;
        IBookManager.BookKey memory bookKeyA = bookManager.getBookKey(pool.bookIdA);
        IBookManager.BookKey memory bookKeyB = bookManager.getBookKey(pool.bookIdB);

        // Compute allocation
        try pool.strategy.computeOrders(key) returns (
            IStrategy.Order[] memory liquidityA, IStrategy.Order[] memory liquidityB
        ) {
            if (liquidityA.length == 0 && liquidityB.length == 0) return;
            _clearPool(key, pool, 1, 1);

            _setLiquidity(bookKeyA, liquidityA, pool.orderListA);
            _setLiquidity(bookKeyB, liquidityB, pool.orderListB);

            pool.strategy.rebalanceHook(msg.sender, key, liquidityA, liquidityB);
            emit Rebalance(key);
        } catch {
            _clearPool(key, pool, 1, 1);
        }

        pool.reserveA = _settleCurrency(bookKeyA.quote, reserveA);
        pool.reserveB = _settleCurrency(bookKeyA.base, reserveB);
    }

    function _clearPool(bytes32 key, Pool storage pool, uint256 cancelNumerator, uint256 cancelDenominator)
        internal
        returns (uint256 canceledAmountA, uint256 canceledAmountB, uint256 claimedAmountA, uint256 claimedAmountB)
    {
        (canceledAmountA, claimedAmountB) = _clearOrders(pool.orderListA, cancelNumerator, cancelDenominator);
        (canceledAmountB, claimedAmountA) = _clearOrders(pool.orderListB, cancelNumerator, cancelDenominator);
        emit Claim(key, claimedAmountA, claimedAmountB);
        emit Cancel(key, canceledAmountA, canceledAmountB);
    }

    function _clearOrders(OrderId[] storage orderIds, uint256 cancelNumerator, uint256 cancelDenominator)
        internal
        returns (uint256 canceledAmount, uint256 claimedAmount)
    {
        OrderId[] memory mOrderIds = orderIds;
        for (uint256 i = 0; i < mOrderIds.length; ++i) {
            OrderId orderId = mOrderIds[i];
            IBookManager.OrderInfo memory orderInfo = bookManager.getOrder(orderId);
            if (orderInfo.claimable > 0) {
                claimedAmount += bookManager.claim(orderId, "");
            }
            if (orderInfo.open > 0) {
                canceledAmount += bookManager.cancel(
                    IBookManager.CancelParams({
                        id: orderId,
                        toUnit: (orderInfo.open - orderInfo.open * cancelNumerator / cancelDenominator).toUint64()
                    }),
                    ""
                );
            }
        }
        if (cancelDenominator == cancelNumerator) {
            assembly {
                sstore(orderIds.slot, 0)
            }
        }
    }

    function _setLiquidity(
        IBookManager.BookKey memory bookKey,
        IStrategy.Order[] memory liquidity,
        OrderId[] storage emptyOrderIds
    ) internal {
        for (uint256 i = 0; i < liquidity.length; ++i) {
            if (liquidity[i].rawAmount == 0) continue;
            (OrderId orderId,) = bookManager.make(
                IBookManager.MakeParams({
                    key: bookKey,
                    tick: liquidity[i].tick,
                    unit: liquidity[i].rawAmount,
                    provider: address(0)
                }),
                ""
            );
            emptyOrderIds.push(orderId);
        }
    }

    function _settleCurrency(Currency currency, uint256 liquidity) internal returns (uint256) {
        bookManager.settle(currency);

        int256 delta = bookManager.getCurrencyDelta(address(this), currency);
        if (delta > 0) {
            bookManager.withdraw(currency, address(this), uint256(delta));
            liquidity += uint256(delta);
        } else if (delta < 0) {
            currency.transfer(address(bookManager), uint256(-delta));
            bookManager.settle(currency);
            liquidity -= uint256(-delta);
        }
        return liquidity;
    }

    function _encodeKey(BookId bookIdA, BookId bookIdB, bytes32 salt) internal pure returns (bytes32) {
        if (BookId.unwrap(bookIdA) > BookId.unwrap(bookIdB)) (bookIdA, bookIdB) = (bookIdB, bookIdA);
        return keccak256(abi.encodePacked(bookIdA, bookIdB, salt));
    }

    receive() external payable {}
}

