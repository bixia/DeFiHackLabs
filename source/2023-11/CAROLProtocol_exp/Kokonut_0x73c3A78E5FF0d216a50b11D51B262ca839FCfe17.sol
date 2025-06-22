// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ^0.8.1 ^0.8.3;

// @openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// @openzeppelin/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// contracts/interfaces/IKokonutSwapExchangeCallback.sol

interface IKokonutSwapExchangeCallback {
    function onExchange(uint256 i, uint256 j, uint256 dx, uint256 dy, bytes calldata data) external;
}

// contracts/interfaces/IKokonutSwapFlashCallback.sol

interface IKokonutSwapFlashCallback {
    function onFlashLoan(
        address initiator,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external;
}

// @openzeppelin/contracts/utils/math/Math.sol

// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
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
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

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

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

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
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
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
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// contracts/library/Ownable.sol

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// contracts/library/Pausable.sol

abstract contract Pausable {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier whenPaused() {
        _requirePaused();
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable");
    }

    function _requirePaused() internal view virtual {
        require(paused(), "Pausable");
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

// contracts/library/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)
// Modified by KokonutSwap

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

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
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "Reentrant");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function reentrancyGuardEntered() public view returns (bool) {
        return _status == _ENTERED;
    }
}

// @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
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

// @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
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

// contracts/interfaces/IKokonutSwapPool.sol

interface IKokonutSwapPool {
    event TokenExchange(
        address indexed buyer,
        uint256 soldId,
        uint256 tokensSold,
        uint256 boughtId,
        uint256 tokensBought,
        uint256 fee
    );
    event RemoveLiquidity(address indexed provider, uint256[] tokenAmounts, uint256 tokenSupply);
    event FlashLoan(address indexed borrower, uint256[] amounts, uint256[] fees);

    function N_COINS() external view returns (uint256);

    function balances(uint256 i) external view returns (uint256);

    function token() external view returns (address);

    function coins(uint256 i) external view returns (address);

    function getPrice(uint256 i, uint256 j) external view returns (uint256);

    function getVirtualPrice() external view returns (uint256);

    function A() external view returns (uint256);

    function fee() external view returns (uint256);

    function adminFee() external view returns (uint256);

    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy,
        bytes calldata data
    ) external returns (uint256, uint256);

    function flashLoanFee() external view returns (uint256);

    function removeLiquidity(uint256 amount, uint256[] calldata minAmounts) external returns (uint256[] memory);

    function getDy(uint256 i, uint256 j, uint256 dx) external view returns (uint256, uint256);

    function calcWithdraw(uint256 amount) external view returns (uint256[] memory);

    function flashLoan(IKokonutSwapFlashCallback borrower, uint256[] calldata amounts, bytes calldata data) external;

    function withdrawLostToken(address token, uint256 amount, address to) external;
}

// contracts/interfaces/ICryptoSwap2Pool.sol

interface ICryptoSwap2Pool is IKokonutSwapPool {
    event AddLiquidity(
        address indexed provider,
        uint256[] tokenAmounts,
        uint256 fee,
        uint256 invariant,
        uint256 tokenSupply
    );
    event RemoveLiquidityOne(
        address indexed provider,
        uint256 i,
        uint256 tokenAmount,
        uint256 lpFee,
        uint256 tokenSupply
    );
    event CommitNewParameters(
        uint256 indexed deadline,
        uint256 adminFee,
        uint256 flashLoanFee,
        uint256 midFee,
        uint256 outFee,
        uint256 feeGamma,
        uint256 allowedExtraProfit,
        uint256 minRemainingPostRebalanceRatio,
        uint256 adjustmentStep,
        uint256 maHalfTime
    );
    event NewParameters(
        uint256 adminFee,
        uint256 flashLoanFee,
        uint256 midFee,
        uint256 outFee,
        uint256 feeGamma,
        uint256 allowedExtraProfit,
        uint256 minRemainingPostRebalanceRatio,
        uint256 adjustmentStep,
        uint256 maHalfTime
    );
    event RampAGamma(
        uint256 initialA,
        uint256 futureA,
        uint256 initialGamma,
        uint256 futureGamma,
        uint256 initialTime,
        uint256 futureTime
    );
    event StopRampA(uint256 currentA, uint256 currentGamma, uint256 time);
    event ClaimAdminFee(address indexed admin, uint256 tokens);
    event TweakPrice(uint256 priceScale, uint256 newD, uint256 virtualPrice, uint256 xcpProfit);

    function lpPrice() external view returns (uint256);

    function gamma() external view returns (uint256);

    function midFee() external view returns (uint256);

    function outFee() external view returns (uint256);

    function priceOracle() external view returns (uint256);

    function addLiquidity(uint256[] calldata amounts, uint256 minMintAmount) external returns (uint256, uint256);

    function calcDeposit(uint256[] calldata amounts) external view returns (uint256, uint256);

    function removeLiquidityOneCoin(
        uint256 tokenAmount,
        uint256 i,
        uint256 minAmount
    ) external returns (uint256, uint256);

    function calcWithdrawOneCoin(uint256 tokenAmount, uint256 i) external view returns (uint256, uint256);

    function claimableAdminFee() external view returns (uint256);

    function claimAdminFee() external;

    function rampAGamma(uint32 futureA, uint64 futureGamma, uint32 futureTime) external;

    function stopRampAGamma() external;

    function commitNewParameters(
        uint256 _newMidFee,
        uint256 _newOutFee,
        uint256 _newAdminFee,
        uint256 _newFlashLoanFee,
        uint256 _newFeeGamma,
        uint256 _newAllowedExtraProfit,
        uint256 _newRebalancingThreshold,
        uint256 _newAdjustmentStep,
        uint256 _newMaHalfTime
    ) external;

    function applyNewParameters() external;

    function revertNewParameters() external;

    struct InitializeArgs {
        uint32 A;
        uint64 gamma;
        uint256 midFee;
        uint256 outFee;
        uint256 allowedExtraProfit;
        uint256 minRemainingPostRebalanceRatio;
        uint256 feeGamma;
        uint256 adjustmentStep;
        uint256 adminFee;
        uint256 flashLoanFee;
        uint256 maHalfTime;
        uint256 initialPrice;
        address[] coins;
    }

    function priceScale() external view returns (uint256);

    function lastPrices() external view returns (uint256);

    function lastPricesTimestamp() external view returns (uint256);

    function initialA() external view returns (uint32);

    function futureA() external view returns (uint32);

    function initialGamma() external view returns (uint64);

    function futureGamma() external view returns (uint64);

    function initialAGammaTime() external view returns (uint32);

    function futureAGammaTime() external view returns (uint32);

    function allowedExtraProfit() external view returns (uint256);

    function futureAllowedExtraProfit() external view returns (uint256);

    function minRemainingPostRebalanceRatio() external view returns (uint256);

    function futureRebalancingThreshold() external view returns (uint256);

    function feeGamma() external view returns (uint256);

    function futureFeeGamma() external view returns (uint256);

    function adjustmentStep() external view returns (uint256);

    function futureAdjustmentStep() external view returns (uint256);

    function maHalfTime() external view returns (uint256);

    function futureMaHalfTime() external view returns (uint256);

    function futureMidFee() external view returns (uint256);

    function futureOutFee() external view returns (uint256);

    function futureAdminFee() external view returns (uint256);

    function futureFlashLoanFee() external view returns (uint256);

    function D() external view returns (uint256);

    function xcpProfit() external view returns (uint256);

    function xcpProfitA() external view returns (uint256);

    function virtualPrice() external view returns (uint256);

    function adminActionsDeadline() external view returns (uint256);
}

// contracts/interfaces/IPoolToken.sol

interface IPoolToken is IERC20Metadata {
    function mint(address user, uint256 amount) external returns (bool);

    function burn(address user, uint256 amount) external returns (bool);

    // permit interfaces //
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// contracts/utils/ZKokonutAccess.sol

abstract contract ZKokonutAccess is Ownable, Pausable {
    function _initializeZKokonutAccess(address owner_) internal {
        _transferOwnership(owner_);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}

// contracts/interfaces/ICryptoPoolToken.sol

interface ICryptoPoolToken is IPoolToken {
    function mintRelative(address to, uint256 frac) external returns (uint256);
}

// contracts/interfaces/ICryptoSwapFactory.sol

interface ICryptoSwapFactory {
    event CryptoPoolDeployed(address pool, ICryptoSwap2Pool.InitializeArgs args, address deployer);
    event UpdatePoolDeployer(address oldPoolDeployer, address newPoolDeployer);
    event UpdateFeeReceiver(address oldFeeReceiver, address newFeeReceiver);

    struct PoolArray {
        uint256 index;
        address[] coins;
        address token;
    }

    function poolDeployer() external view returns (address);

    function poolList(uint256 i) external view returns (address);

    function deployPool(ICryptoSwap2Pool.InitializeArgs calldata args) external returns (address);

    function setPoolDeployer(address poolDeployer) external;

    function setFeeReceiver(address newFeeReceiver) external;

    function findPoolForCoins(address _from, address _to, uint256 i) external view returns (address);

    function getFeeReceiver() external view returns (address);

    function getPoolList() external view returns (address[] memory);

    function poolCount() external view returns (uint256);

    function getPoolInfo(address _pool) external view returns (PoolArray memory);
}

// @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// contracts/CryptoSwap2Pool.sol

contract CryptoSwap2Pool is ICryptoSwap2Pool, ReentrancyGuard, ZKokonutAccess {
    using SafeERC20 for IERC20;

    uint256 internal constant _ADMIN_ACTIONS_DELAY = 3 * 86400;
    uint256 internal constant _MIN_RAMP_TIME = 86400;

    uint256 internal constant _MAX_ADMIN_FEE = 10 * 10 ** 9;
    uint256 internal constant _MIN_FEE = 5 * 10 ** 5; // 0.5 bps
    uint256 internal constant _MAX_FEE = 5 * 10 ** 9;
    uint256 internal constant _MAX_A_CHANGE = 10;
    uint256 internal constant _NOISE_FEE = 10 ** 5; // 0.1 bps

    uint256 internal constant _MIN_GAMMA = 10 ** 10;
    uint256 internal constant _MAX_GAMMA = 2 * 10 ** 16;

    uint256 internal constant _MIN_A = (N_COINS ** N_COINS * _A_MULTIPLIER) / 10;
    uint256 internal constant _MAX_A = N_COINS ** N_COINS * _A_MULTIPLIER * 100000;

    uint256 public constant override N_COINS = 2;
    uint256 internal constant _PRECISION_PRICE_SCALE = 10 ** 18; // The precision to convert to
    uint256 internal constant _PRECISION_EXP = 10 ** 10;
    uint256 internal constant _PRECISION_FEE = 10 ** 10;
    uint256 internal constant _A_MULTIPLIER = 10000;

    address internal immutable _factory;

    address public immutable override token;
    address internal immutable _coin0;
    address internal immutable _coin1;

    uint256 internal immutable _PRECISION_COIN0;
    uint256 internal immutable _PRECISION_COIN1;

    uint256 public override priceScale; // Internal price scale
    uint256 internal _PriceOracle; // Price target given by MA

    uint256 public override lastPrices;
    uint256 public override lastPricesTimestamp;

    uint32 public override initialA;
    uint32 public override futureA;
    uint64 public override initialGamma;
    uint64 public override futureGamma;
    uint32 public override initialAGammaTime;
    uint32 public override futureAGammaTime;

    uint256 public override allowedExtraProfit; // 2 * 10**12 - recommended value;
    uint256 public override futureAllowedExtraProfit;

    uint256 public override minRemainingPostRebalanceRatio;
    uint256 public override futureRebalancingThreshold;

    uint256 public override feeGamma;
    uint256 public override futureFeeGamma;

    uint256 public override adjustmentStep;
    uint256 public override futureAdjustmentStep;

    uint256 public override maHalfTime;
    uint256 public override futureMaHalfTime;

    uint256 public override midFee;
    uint256 public override outFee;
    uint256 public override adminFee;
    uint256 public override flashLoanFee;
    uint256 public override futureMidFee;
    uint256 public override futureOutFee;
    uint256 public override futureAdminFee;
    uint256 public override futureFlashLoanFee;

    uint256[N_COINS] public override balances;
    uint256 public override D;

    uint256 public override xcpProfit;
    uint256 public override xcpProfitA; // Full profit at last claim of admin fees
    uint256 public override virtualPrice; // Cached (fast to read) virtual price also used internally
    bool internal _notAdjusted;

    uint256 public override adminActionsDeadline;

    modifier readOnlyNonReentrant() {
        _checkReadOnlyNonReentrant();
        _;
    }

    function _checkReadOnlyNonReentrant() internal view {
        require(!reentrancyGuardEntered(), "Reentrant");
    }

    constructor(InitializeArgs memory args, address token_, address owner_, address factory_) {
        _initializeZKokonutAccess(owner_);
        _factory = factory_;

        // Pack A and gamma:
        // shifted A + gamma

        initialA = args.A;
        initialGamma = args.gamma;
        futureA = args.A;
        futureGamma = args.gamma;

        midFee = args.midFee;
        outFee = args.outFee;
        allowedExtraProfit = args.allowedExtraProfit;
        minRemainingPostRebalanceRatio = args.minRemainingPostRebalanceRatio;
        feeGamma = args.feeGamma;
        adjustmentStep = args.adjustmentStep;
        adminFee = args.adminFee;
        flashLoanFee = args.flashLoanFee;

        priceScale = args.initialPrice;
        _PriceOracle = args.initialPrice;
        lastPrices = args.initialPrice;
        lastPricesTimestamp = block.timestamp;
        maHalfTime = args.maHalfTime;

        xcpProfitA = 10 ** 18;

        token = token_;
        _coin0 = args.coins[0];
        _coin1 = args.coins[1];
        _PRECISION_COIN0 = 10 ** (18 - _getDecimals(args.coins[0]));
        _PRECISION_COIN1 = 10 ** (18 - _getDecimals(args.coins[1]));
    }

    function _getDecimals(address tokenAddress) internal view returns (uint256) {
        return IERC20Metadata(tokenAddress).decimals();
    }

    function _AGamma() internal view returns (uint256 mA, uint256 mGamma) {
        unchecked {
            uint256 t1 = futureAGammaTime;
            mA = futureA;
            mGamma = futureGamma;

            if (block.timestamp < t1) {
                // handle ramping up and down of A
                uint256 t0 = initialAGammaTime;

                // Less readable but more compact way of writing and converting to uint256
                // gamma0: uint256 = bitwise_and(AGamma0, 2**128-1)
                // A0: uint256 = shift(AGamma0, -128)
                // A1 = A0 + (A1 - A0) * (block.timestamp - t0) / (t1 - t0)
                // gamma1 = gamma0 + (gamma1 - gamma0) * (block.timestamp - t0) / (t1 - t0)

                t1 -= t0;
                t0 = block.timestamp - t0;
                uint256 t2 = t1 - t0;

                mA = (initialA * t2 + mA * t0) / t1;
                mGamma = (initialGamma * t2 + mGamma * t0) / t1;
            }
        }
    }

    function _standardize(uint256 x, uint256 y) internal view returns (uint256[N_COINS] memory result) {
        result[0] = x * _PRECISION_COIN0;
        result[1] = (y * _PRECISION_COIN1 * priceScale) / _PRECISION_PRICE_SCALE;
        return result;
    }

    function _unStandardize(uint256 standardizedAmount, uint256 i) internal view returns (uint256) {
        return
            i == 0
                ? standardizedAmount / _PRECISION_COIN0
                : (standardizedAmount * _PRECISION_PRICE_SCALE) / _PRECISION_COIN1 / priceScale;
    }

    function _feeRate(uint256[N_COINS] memory xp) internal view returns (uint256) {
        /*
        f = feeGamma / (feeGamma + (1 - K))
        where
        K = prod(x) / (sum(x) / N)**N
        (all normalized to 1e18)
        */

        uint256 feeGamma_ = feeGamma;
        uint256 f = xp[0] + xp[1]; // sum
        f =
            (feeGamma_ * 10 ** 18) /
            (feeGamma_ + 10 ** 18 - ((((10 ** 18 * N_COINS ** N_COINS) * xp[0]) / f) * xp[1]) / f);
        return (midFee * f + outFee * (10 ** 18 - f)) / 10 ** 18;
    }

    function _getXcp(uint256 _D) internal view returns (uint256) {
        uint256[N_COINS] memory x;
        unchecked {
            x[0] = _D / N_COINS;
            x[1] = (_D * _PRECISION_PRICE_SCALE) / (priceScale * N_COINS);
        }
        return _geometricMean(x, true);
    }

    function _halfpow(uint256 power) internal pure returns (uint256) {
        /*
        1e18 * 0.5 ** (power/1e18)
        Inspired by: https://github.com/balancer-labs/balancer-core/blob/master/contracts/BNum.sol#L128
        */
        uint256 intpow = power / 10 ** 18;
        uint256 otherpow = power - intpow * 10 ** 18;
        if (intpow > 59) {
            return 0;
        }
        uint256 result = 10 ** 18 / (2 ** intpow);
        if (otherpow == 0) {
            return result;
        }

        uint256 term = 10 ** 18;
        uint256 S = 10 ** 18;
        bool neg = false;

        for (uint256 i = 1; i < 256; ++i) {
            uint256 K = i * 10 ** 18;
            uint256 c = K - 10 ** 18;
            if (otherpow > c) {
                c = otherpow - c;
                neg = !neg;
            } else {
                c -= otherpow;
            }
            term = (term * (c / 2)) / K;
            if (neg) {
                S -= term;
            } else {
                S += term;
            }
            if (term < _PRECISION_EXP) {
                return (result * S) / 10 ** 18;
            }
        }

        revert("C");
    }

    function _sqrtInt(uint256 x) internal pure returns (uint256) {
        /*
        Originating from: https://github.com/vyperlang/vyper/issues/1266
        */
        if (x == 0) {
            return 0;
        }

        uint256 z = (x + 10 ** 18) / 2;
        uint256 y = x;

        for (uint256 i = 0; i < 256; ++i) {
            if (z == y) {
                return y;
            }
            y = z;
            z = ((x * 10 ** 18) / z + z) / 2;
        }

        revert("C");
    }

    function _calcTokenFeeRate(
        uint256[N_COINS] memory xp0,
        uint256[N_COINS] memory xp1
    ) internal view returns (uint256) {
        uint256 feeRate = _feeRate(xp1);
        uint256 sum = 0;
        uint256 diff = 0;
        uint256[N_COINS] memory amounts;
        unchecked {
            for (uint256 i = 0; i < N_COINS; ++i) {
                amounts[i] = xp1[i] - xp0[i]; // always xp1[i] > xp0[i]
                sum += amounts[i];
                require(sum >= amounts[i]);
            }
            uint256 avg = sum / N_COINS;
            for (uint256 i = 0; i < N_COINS; ++i) {
                diff += (amounts[i] > avg) ? amounts[i] - avg : avg - amounts[i];
            }
            feeRate = (feeRate * N_COINS) / (4 * (N_COINS - 1));
        }
        return (feeRate * diff) / sum + _NOISE_FEE;
    }

    function _calcWithdrawOneCoin(
        uint256 tokenAmount,
        uint256 i,
        uint256[N_COINS] memory xp0
    ) internal view returns (uint256 dy, uint256 lpFee, uint256 D1, uint256[N_COINS] memory xp1) {
        require(i < N_COINS); // dev: coin out of range

        uint256 tokenSupply = _lpTotalSupply();
        xp1 = _arrCopy(xp0);
        (uint256 mA, uint256 mGamma) = _AGamma();
        require(tokenAmount <= tokenSupply);
        uint256 D0 = futureAGammaTime > 0 ? _newtonD(mA, mGamma, xp1) : D;
        uint256 y;
        unchecked {
            lpFee = (_feeRate(xp1) * tokenAmount) / (2 * _PRECISION_FEE) + 1;
            D1 = D0 - (D0 * (tokenAmount - lpFee)) / tokenSupply;
            y = _newtonY(mA, mGamma, xp1[1 - i], D1);
        }
        dy = _unStandardize(xp1[i] - y, i);
        xp1[i] = y;
    }

    function _arrCopy(uint256[N_COINS] memory _input) internal pure returns (uint256[N_COINS] memory result) {
        unchecked {
            for (uint256 i = 0; i < N_COINS; ++i) {
                result[i] = _input[i];
            }
        }
    }

    // Internal Functions
    function _claimAdminFee() internal {
        (uint256 mA, uint256 mGamma) = _AGamma();

        uint256 _xcpProfit = xcpProfit;
        uint256 _xcpProfitA = xcpProfitA;
        uint256 _minRemainingPostRebalanceRatio = minRemainingPostRebalanceRatio;

        // Gulp here
        unchecked {
            for (uint256 i = 0; i < N_COINS; ++i) {
                balances[i] = _thisBalanceOf(_coins(i));
            }
        }

        uint256 vprice = virtualPrice;

        if (_xcpProfit > _xcpProfitA) {
            uint256 fees;
            unchecked {
                fees = ((_xcpProfit - _xcpProfitA) * adminFee) / _PRECISION_FEE;
            }
            if (fees > 0) {
                address receiver = ICryptoSwapFactory(_factory).getFeeReceiver();
                if (receiver != address(0)) {
                    uint256 frac = (vprice * 10 ** 18) /
                        (vprice - (fees * _minRemainingPostRebalanceRatio) / _PRECISION_FEE) -
                        10 ** 18;
                    uint256 claimed = ICryptoPoolToken(token).mintRelative(receiver, frac);
                    _xcpProfit -= fees;
                    xcpProfit = _xcpProfit;
                    emit ClaimAdminFee(receiver, claimed);
                }
            }
        }

        // Recalculate D b/c we gulped
        D = _newtonD(mA, mGamma, _standardize(balances[0], balances[1]));

        virtualPrice = (10 ** 18 * _getXcp(D)) / _lpTotalSupply();

        if (_xcpProfit > _xcpProfitA) {
            xcpProfitA = _xcpProfit;
        }
    }

    function _tweakPrice(uint256 mA, uint256 mGamma, uint256[N_COINS] memory xp, uint256 newD) internal {
        uint256 oldPriceScale = priceScale;
        uint256 newPriceOracle = _PriceOracle;
        uint256 lastPrices_ = lastPrices;
        {
            uint256 lastPricesTimestamp_ = lastPricesTimestamp;

            if (lastPricesTimestamp_ < block.timestamp) {
                // MA update required
                uint256 alpha = _halfpow(((block.timestamp - lastPricesTimestamp_) * 10 ** 18) / maHalfTime);
                uint256 price = Math.max(Math.min(lastPrices_, 2 * oldPriceScale), oldPriceScale / 2);
                newPriceOracle = (price * (10 ** 18 - alpha) + newPriceOracle * alpha) / 10 ** 18;
                _PriceOracle = newPriceOracle;
                lastPricesTimestamp = block.timestamp;
            }

            // Withdrawal methods know new D already
            if (newD == 0) {
                // We will need this a few times (35k gas)
                // @dev Reuse newD as DUnadjusted
                newD = _newtonD(mA, mGamma, xp);
            }

            lastPrices_ = _getPrice(1, mA, mGamma, xp, newD);
            lastPrices = lastPrices_;
        }

        uint256 oldVirtualPrice = virtualPrice;

        // Update profit numbers without price adjustment first
        uint256[N_COINS] memory mXp;
        mXp[0] = newD / N_COINS;
        mXp[1] = (newD * _PRECISION_PRICE_SCALE) / (N_COINS * oldPriceScale);
        uint256 newXcpProfit = 10 ** 18;
        uint256 newVirtualPrice = 10 ** 18;

        if (oldVirtualPrice > 0) {
            newVirtualPrice = (10 ** 18 * _geometricMean(mXp, true)) / _lpTotalSupply();
            newXcpProfit = (xcpProfit * newVirtualPrice) / oldVirtualPrice;

            uint256 t = futureAGammaTime;
            if (newVirtualPrice < oldVirtualPrice && t == 0) {
                revert("Loss");
            }
            if (t == 1) {
                futureAGammaTime = 0;
            }
        }

        xcpProfit = newXcpProfit;

        uint256 norm = (newPriceOracle * 10 ** 18) / oldPriceScale;
        unchecked {
            if (norm > 10 ** 18) {
                norm -= 10 ** 18;
            } else {
                norm = 10 ** 18 - norm;
            }
        }
        uint256 mAdjustmentStep = Math.max(adjustmentStep, norm / 5);

        bool needsAdjustment = _notAdjusted;
        // if not needsAdjustment and (virtualPrice-10**18 > (xcpProfit-10**18)*minRemainingPostRebalanceRatio + allowedExtraProfit):
        // (re-arrange for gas efficiency)
        if (
            !needsAdjustment &&
            (newVirtualPrice - 10 ** 18 >
                ((newXcpProfit - 10 ** 18) * minRemainingPostRebalanceRatio) / _PRECISION_FEE + allowedExtraProfit) &&
            (norm > mAdjustmentStep) &&
            (oldVirtualPrice > 0)
        ) {
            needsAdjustment = true;
            _notAdjusted = true;
        }

        if (needsAdjustment) {
            if (norm > mAdjustmentStep && oldVirtualPrice > 0) {
                // We reuse lastPrices_ as pNew
                lastPrices_ = (oldPriceScale * (norm - mAdjustmentStep) + mAdjustmentStep * newPriceOracle) / norm;

                // Calculate balances*prices
                mXp[0] = xp[0];
                mXp[1] = (xp[1] * lastPrices_) / oldPriceScale;

                // Calculate "extended constant product" invariant xCP and virtual price
                uint256 _D = _newtonD(mA, mGamma, mXp);
                mXp[0] = _D / N_COINS;
                mXp[1] = (_D * _PRECISION_PRICE_SCALE) / (N_COINS * lastPrices_);
                // We reuse oldVirtualPrice here but it's not old anymore
                oldVirtualPrice = (10 ** 18 * _geometricMean(mXp, true)) / _lpTotalSupply();

                // Proceed if we've got enough profit
                // if (oldVirtualPrice > 10**18) and (oldVirtualPrice - 10**18 > (xcpProfit - 10**18) * minRemainingPostRebalanceRatio):
                if (
                    (oldVirtualPrice > 10 ** 18) &&
                    (oldVirtualPrice - 10 ** 18 >
                        ((newXcpProfit - 10 ** 18) * minRemainingPostRebalanceRatio) / _PRECISION_FEE)
                ) {
                    priceScale = lastPrices_;
                    D = _D;
                    virtualPrice = oldVirtualPrice;

                    emit TweakPrice(lastPrices_, _D, oldVirtualPrice, newXcpProfit);
                    return;
                } else {
                    _notAdjusted = false;

                    // Can instead do another flag variable if we want to save bytespace
                    D = newD;
                    virtualPrice = newVirtualPrice;
                    _claimAdminFee();

                    return;
                }
            }
        }

        // If we are here, the priceScale adjustment did not happen
        // Still need to update the profit counter and D
        D = newD;
        virtualPrice = newVirtualPrice;

        // norm appeared < adjustmentStep after
        if (needsAdjustment) {
            _notAdjusted = false;
            _claimAdminFee();
        }
    }

    function _internalPriceOracle() internal view returns (uint256) {
        uint256 _lastPricesTimestamp = lastPricesTimestamp;

        if (_lastPricesTimestamp < block.timestamp) {
            uint256 alpha = _halfpow(((block.timestamp - _lastPricesTimestamp) * 10 ** 18) / maHalfTime);
            return (lastPrices * (10 ** 18 - alpha) + _PriceOracle * alpha) / 10 ** 18;
        } else {
            return _PriceOracle;
        }
    }

    /* External Functions */

    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 minDy,
        bytes calldata data
    ) external nonReentrant whenNotPaused returns (uint256 dy, uint256 dyFee) {
        require(i + j == 1); // dev: coin index out of range
        require(dx > 0); // dev: do not exchange 0 coins

        (uint256 mA, uint256 mGamma) = _AGamma();

        if (futureAGammaTime > 0) {
            D = _newtonD(mA, mGamma, _standardize(balances[0], balances[1]));
            if (block.timestamp >= futureAGammaTime) {
                futureAGammaTime = 1;
            }
        }
        uint256[N_COINS] memory xp0 = balances;
        uint256[N_COINS] memory xp1 = _arrCopy(xp0);
        xp1[i] = xp1[i] + dx;
        balances[i] = xp1[i];
        xp0 = _standardize(xp0[0], xp0[1]);
        xp1 = _standardize(xp1[0], xp1[1]);

        dy = xp1[j] - _newtonY(mA, mGamma, xp1[i], D);
        require(dy > 0);
        unchecked {
            xp1[j] -= dy;
            dy = _unStandardize(dy - 1, j);
            dyFee = (_feeRate(xp1) * dy) / _PRECISION_FEE;
            dy -= dyFee;
            require(dy >= minDy, "SP");
            balances[j] = balances[j] - dy;
        }

        // support flash swap
        _transfer(_coins(j), msg.sender, dy);

        // Do transfers in and out together
        if (data.length == 0) {
            _pullToken(_coins(i), msg.sender, dx);
        } else {
            address inCoin = _coins(i);
            // reuse minDy as balance
            minDy = _thisBalanceOf(inCoin);
            IKokonutSwapExchangeCallback(msg.sender).onExchange(i, j, dx, dy, data);
            require(_thisBalanceOf(inCoin) - minDy >= dx); // dev: callback didn't give us sufficient coins
        }

        xp1 = _standardize(balances[0], balances[1]);
        _tweakPrice(mA, mGamma, xp1, 0);

        emit TokenExchange(msg.sender, i, dx, j, dy, dyFee);
    }

    function addLiquidity(
        uint256[] calldata amounts,
        uint256 minMintAmount
    ) external nonReentrant whenNotPaused returns (uint256 dToken, uint256 lpFee) {
        require(amounts.length == N_COINS);
        require(amounts[0] > 0 || amounts[1] > 0); // dev: no coins to add

        (uint256 mA, uint256 mGamma) = _AGamma();

        uint256 D0;
        if (futureAGammaTime > 0) {
            D0 = _newtonD(mA, mGamma, _standardize(balances[0], balances[1]));
            if (block.timestamp >= futureAGammaTime) {
                futureAGammaTime = 1;
            }
        } else {
            D0 = D;
        }

        uint256[N_COINS] memory xp0 = balances;
        uint256[N_COINS] memory xp1 = _arrCopy(xp0);
        for (uint256 i = 0; i < N_COINS; ++i) {
            uint256 amount = amounts[i];
            if (amount > 0) {
                xp1[i] = xp1[i] + amount;
                _pullToken(_coins(i), msg.sender, amount);
            }
            balances[i] = xp1[i];
        }

        xp0 = _standardize(xp0[0], xp0[1]);
        xp1 = _standardize(xp1[0], xp1[1]);

        uint256 D1 = _newtonD(mA, mGamma, xp1);

        uint256 tokenSupply = _lpTotalSupply();
        if (D0 > 0) {
            dToken = (tokenSupply * D1) / D0 - tokenSupply;
        } else {
            dToken = _getXcp(D1); // making initial virtual price equal to 1
        }
        require(dToken > 0); // dev: nothing minted

        if (D0 > 0) {
            lpFee = (_calcTokenFeeRate(xp0, xp1) * dToken) / _PRECISION_FEE + 1;
            dToken -= lpFee;
            tokenSupply += dToken;
            _mintMsgSender(dToken);

            _tweakPrice(mA, mGamma, xp1, D1);
        } else {
            D = D1;
            virtualPrice = 10 ** 18;
            xcpProfit = 10 ** 18;
            _mintMsgSender(dToken);
            tokenSupply += dToken;
        }

        require(dToken >= minMintAmount, "SP");

        emit AddLiquidity(msg.sender, amounts, lpFee, D1, tokenSupply);
    }

    function removeLiquidity(
        uint256 amount,
        uint256[] calldata minAmounts
    ) external nonReentrant returns (uint256[] memory) {
        /*
        This withdrawal method is very safe, does no complex math
        */
        require(minAmounts.length == N_COINS);
        uint256 _totalSupply = _lpTotalSupply();
        _burnMsgSender(amount);
        uint256[] memory dBalances = new uint256[](N_COINS);
        uint256[] memory balances_ = new uint256[](N_COINS);

        unchecked {
            for (uint256 i = 0; i < N_COINS; ++i) {
                balances_[i] = balances[i];
                uint256 dBalance = (balances_[i] * amount) / _totalSupply;
                require(dBalance >= minAmounts[i]);
                balances[i] = balances_[i] - dBalance;
                balances_[i] = dBalance;
                // now it's the amounts going out
                address coin = _coins(i);
                _transfer(coin, msg.sender, dBalance);
                dBalances[i] = dBalance;
            }

            uint256 _D = D;
            D = _D - (_D * amount) / _totalSupply;

            emit RemoveLiquidity(msg.sender, balances_, _totalSupply - amount);
        }
        return dBalances;
    }

    function removeLiquidityOneCoin(
        uint256 tokenAmount,
        uint256 i,
        uint256 minAmount
    ) external nonReentrant whenNotPaused returns (uint256, uint256) {
        uint256[N_COINS] memory xp0 = _standardize(balances[0], balances[1]);
        (uint256 dy, uint256 lpFee, uint256 D1, uint256[N_COINS] memory xp1) = _calcWithdrawOneCoin(
            tokenAmount,
            i,
            xp0
        );
        require(dy >= minAmount, "SP");

        if (block.timestamp >= futureAGammaTime) {
            futureAGammaTime = 1;
        }

        balances[i] -= dy;
        _burnMsgSender(tokenAmount);
        _transfer(_coins(i), msg.sender, dy);

        (uint256 mA, uint256 mGamma) = _AGamma();
        _tweakPrice(mA, mGamma, xp1, D1);

        emit RemoveLiquidityOne(msg.sender, i, dy, lpFee, _lpTotalSupply());

        return (dy, lpFee);
    }

    function claimableAdminFee() external view readOnlyNonReentrant returns (uint256) {
        uint256 _xcpProfit = xcpProfit;
        uint256 _xcpProfitA = xcpProfitA;

        uint256 vprice = virtualPrice;

        if (_xcpProfit > _xcpProfitA) {
            uint256 fees = ((_xcpProfit - _xcpProfitA) * adminFee * minRemainingPostRebalanceRatio) /
                (_PRECISION_FEE * _PRECISION_FEE);
            if (fees > 0) {
                uint256 frac = (vprice * 10 ** 18) / (vprice - fees) - 10 ** 18;
                uint256 supply = _lpTotalSupply();
                return (supply * frac) / 10 ** 18;
            }
        }
        return 0;
    }

    function claimAdminFee() external nonReentrant {
        _claimAdminFee();
    }

    /* Admin parameters */
    function rampAGamma(uint32 futureA_, uint64 futureGamma_, uint32 futureTime_) external onlyOwner {
        unchecked {
            require(block.timestamp > initialAGammaTime + (_MIN_RAMP_TIME - 1));
            require(futureTime_ > block.timestamp + (_MIN_RAMP_TIME - 1)); // dev: insufficient time

            (uint256 mA, uint256 mGamma) = _AGamma();

            require(futureA_ > _MIN_A - 1);
            require(futureA_ < _MAX_A + 1);
            require(futureGamma_ > _MIN_GAMMA - 1);
            require(futureGamma_ < _MAX_GAMMA + 1);

            uint256 ratio = (10 ** 18 * uint256(futureA_)) / mA;
            require(ratio < 10 ** 18 * _MAX_A_CHANGE + 1);
            require(ratio > 10 ** 18 / _MAX_A_CHANGE - 1);

            ratio = (10 ** 18 * uint256(futureGamma_)) / mGamma;
            require(ratio < 10 ** 18 * _MAX_A_CHANGE + 1);
            require(ratio > 10 ** 18 / _MAX_A_CHANGE - 1);

            initialA = uint32(mA);
            initialGamma = uint64(mGamma);
            initialAGammaTime = uint32(block.timestamp);

            futureA = uint32(futureA_);
            futureGamma = uint64(futureGamma_);
            futureAGammaTime = uint32(futureTime_);

            emit RampAGamma(mA, futureA_, mGamma, futureGamma_, block.timestamp, futureTime_);
        }
    }

    function stopRampAGamma() external onlyOwner {
        (uint256 mA, uint256 mGamma) = _AGamma();
        initialA = uint32(mA);
        initialGamma = uint64(mGamma);
        futureA = uint32(mA);
        futureGamma = uint64(mGamma);
        initialAGammaTime = uint32(block.timestamp);
        futureAGammaTime = uint32(block.timestamp);
        // now (block.timestamp < t1) is always False, so we return saved A

        emit StopRampA(mA, mGamma, block.timestamp);
    }

    function commitNewParameters(
        uint256 _newMidFee,
        uint256 _newOutFee,
        uint256 _newAdminFee,
        uint256 _newFlashLoanFee,
        uint256 _newFeeGamma,
        uint256 _newAllowedExtraProfit,
        uint256 _newRebalancingThreshold,
        uint256 _newAdjustmentStep,
        uint256 _newMaHalfTime
    ) external onlyOwner {
        unchecked {
            require(adminActionsDeadline == 0); // dev: active action

            // Fees
            if (_newOutFee < _MAX_FEE + 1) {
                require(_newOutFee > _MIN_FEE - 1); // dev: fee is out of range
            } else {
                _newOutFee = outFee;
            }
            if (_newMidFee > _MAX_FEE) {
                _newMidFee = midFee;
            }
            require(_newMidFee <= _newOutFee); // dev: mid-fee is too high
            if (_newAdminFee > _MAX_ADMIN_FEE) {
                _newAdminFee = adminFee;
            }
            if (_newFlashLoanFee > _MAX_FEE) {
                _newFlashLoanFee = flashLoanFee;
            }

            // AMM parameters
            if (_newFeeGamma < 10 ** 18) {
                require(_newFeeGamma > 0); // dev: feeGamma out of range [1 .. 10**18]
            } else {
                _newFeeGamma = feeGamma;
            }
            if (_newAllowedExtraProfit > 10 ** 18) {
                _newAllowedExtraProfit = allowedExtraProfit;
            }
            if (_newAdjustmentStep > 10 ** 18) {
                _newAdjustmentStep = adjustmentStep;
            }
            if (_newRebalancingThreshold > _PRECISION_FEE) {
                _newRebalancingThreshold = minRemainingPostRebalanceRatio;
            } else {
                require(_newRebalancingThreshold >= 2 * 10 ** 9);
            }

            // MA
            if (_newMaHalfTime < 7 * 86400) {
                require(_newMaHalfTime > 0); // dev: MA time should be longer than 1 second
            } else {
                _newMaHalfTime = maHalfTime;
            }

            uint256 _deadline = block.timestamp + _ADMIN_ACTIONS_DELAY;
            adminActionsDeadline = _deadline;

            futureAdminFee = _newAdminFee;
            futureMidFee = _newMidFee;
            futureOutFee = _newOutFee;
            futureFlashLoanFee = _newFlashLoanFee;
            futureFeeGamma = _newFeeGamma;
            futureAllowedExtraProfit = _newAllowedExtraProfit;
            futureRebalancingThreshold = _newRebalancingThreshold;
            futureAdjustmentStep = _newAdjustmentStep;
            futureMaHalfTime = _newMaHalfTime;

            emit CommitNewParameters(
                _deadline,
                _newAdminFee,
                _newFlashLoanFee,
                _newMidFee,
                _newOutFee,
                _newFeeGamma,
                _newAllowedExtraProfit,
                _newRebalancingThreshold,
                _newAdjustmentStep,
                _newMaHalfTime
            );
        }
    }

    function applyNewParameters() external nonReentrant onlyOwner {
        require(block.timestamp >= adminActionsDeadline); // dev: insufficient time
        require(adminActionsDeadline != 0); // dev: no active action

        adminActionsDeadline = 0;

        uint256 adminFee_ = futureAdminFee;
        if (adminFee != adminFee_) {
            _claimAdminFee();
            adminFee = adminFee_;
        }

        uint256 flashLoanFee_ = futureFlashLoanFee;
        flashLoanFee = flashLoanFee_;
        uint256 midFee_ = futureMidFee;
        midFee = midFee_;
        uint256 outFee_ = futureOutFee;
        outFee = outFee_;
        uint256 feeGamma_ = futureFeeGamma;
        feeGamma = feeGamma_;
        uint256 allowedExtraProfit_ = futureAllowedExtraProfit;
        allowedExtraProfit = allowedExtraProfit_;
        uint256 minRemainingPostRebalanceRatio_ = futureRebalancingThreshold;
        minRemainingPostRebalanceRatio = minRemainingPostRebalanceRatio_;
        uint256 adjustmentStep_ = futureAdjustmentStep;
        adjustmentStep = adjustmentStep_;
        uint256 maHalfTime_ = futureMaHalfTime;
        maHalfTime = maHalfTime_;

        emit NewParameters(
            adminFee_,
            flashLoanFee_,
            midFee_,
            outFee_,
            feeGamma_,
            allowedExtraProfit_,
            minRemainingPostRebalanceRatio_,
            adjustmentStep_,
            maHalfTime_
        );
    }

    function revertNewParameters() external onlyOwner {
        adminActionsDeadline = 0;
    }

    function withdrawLostToken(address _target, uint256 _amount, address _to) external onlyOwner {
        address[N_COINS] memory coins_ = _coins();
        unchecked {
            for (uint256 i = 0; i < N_COINS; ++i) {
                require(coins_[i] != _target);
            }
        }
        _transfer(_target, _to, _amount);
    }

    function flashLoan(
        IKokonutSwapFlashCallback borrower,
        uint256[] calldata amounts,
        bytes calldata data
    ) external nonReentrant {
        require(amounts.length == N_COINS);

        address[N_COINS] memory coinsList = _coins();
        uint256[N_COINS] memory oldBalance;
        uint256[] memory fees = new uint256[](N_COINS);
        uint256 currentFee = flashLoanFee;
        for (uint256 i = 0; i < N_COINS; ++i) {
            address coin = coinsList[i];
            // rounding up
            fees[i] = (amounts[i] * currentFee + _PRECISION_FEE - 1) / _PRECISION_FEE;
            oldBalance[i] = _thisBalanceOf(coin);
            if (amounts[i] > 0) {
                _transfer(coin, address(borrower), amounts[i]);
            }
        }

        borrower.onFlashLoan(msg.sender, amounts, fees, data);

        for (uint256 i = 0; i < N_COINS; ++i) {
            uint256 newBalance = _thisBalanceOf(coinsList[i]);
            require(newBalance >= oldBalance[i] + fees[i], "flashLoan");
            unchecked {
                fees[i] = newBalance - oldBalance[i];
            }
            balances[i] += fees[i];
        }

        (uint256 mA, uint256 mGamma) = _AGamma();
        _tweakPrice(mA, mGamma, _standardize(balances[0], balances[1]), 0);

        emit FlashLoan(address(borrower), amounts, fees);
    }

    /* View Methods*/
    function getDy(
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view readOnlyNonReentrant returns (uint256 dy, uint256 dyFee) {
        require(i + j == 1);

        (uint256 mA, uint256 mGamma) = _AGamma();
        uint256[N_COINS] memory xp = balances;
        uint256 D0 = (futureAGammaTime > 0) ? _newtonD(mA, mGamma, _standardize(xp[0], xp[1])) : D;

        xp[i] += dx;
        xp = _standardize(xp[0], xp[1]);

        dy = xp[j] - _newtonY(mA, mGamma, xp[i], D0);
        require(dy > 0);
        unchecked {
            xp[j] -= dy;
            dy = _unStandardize(dy - 1, j);
            dyFee = (_feeRate(xp) * dy) / _PRECISION_FEE;
            dy -= dyFee;
        }
    }

    function _getPrice(
        uint256 i,
        uint256 mA,
        uint256 mGamma,
        uint256[N_COINS] memory xp,
        uint256 D_
    ) internal view returns (uint256) {
        uint256 K0 = ((((10 ** 18 * N_COINS ** N_COINS) * xp[0]) / D_) * xp[1]) / D_;
        require(K0 <= 10 ** 18, "K0");
        uint256 _g1k0 = mGamma + 10 ** 18 - K0;

        uint256 K = (((mA * K0 * mGamma) / _g1k0) * mGamma) / _g1k0 / _A_MULTIPLIER / N_COINS ** N_COINS;
        uint256 S = xp[0] + xp[1];
        require(D_ <= S, "D");

        // mul = X / (K*D**(N-1))
        uint256 mul = ((S - D_) * (mGamma + 10 ** 18 + K0)) / _g1k0 + (D_ * K0) / K / N_COINS ** N_COINS;
        uint256 dxi = _PRECISION_PRICE_SCALE + (_PRECISION_PRICE_SCALE * mul) / xp[1 - i];
        uint256 dxj = _PRECISION_PRICE_SCALE + (_PRECISION_PRICE_SCALE * mul) / xp[i];
        if (i == 0) {
            return (((_PRECISION_PRICE_SCALE * dxj) / dxi) * _PRECISION_PRICE_SCALE) / priceScale;
        } else {
            return (((_PRECISION_PRICE_SCALE * dxj) / dxi) * priceScale) / _PRECISION_PRICE_SCALE;
        }
    }

    // the price of i for j
    function getPrice(uint256 i, uint256 j) public view readOnlyNonReentrant returns (uint256) {
        require(i + j == 1);

        uint256[N_COINS] memory xp = _standardize(balances[0], balances[1]);

        (uint256 mA, uint256 mGamma) = _AGamma(); // [A*N**N, gamma]
        uint256 D_ = futureAGammaTime > 0 ? _newtonD(mA, mGamma, xp) : D;

        return _getPrice(i, mA, mGamma, xp, D_);
    }

    function calcDeposit(
        uint256[] calldata amounts
    ) external view readOnlyNonReentrant returns (uint256 lpAmount, uint256 lpFee) {
        require(amounts.length == N_COINS);
        uint256 tokenSupply = _lpTotalSupply();
        (uint256 mA, uint256 mGamma) = _AGamma();

        uint256[N_COINS] memory xp0 = balances;
        uint256[N_COINS] memory xp1 = _arrCopy(xp0);
        xp1[0] = xp0[0] + amounts[0];
        xp1[1] = xp0[1] + amounts[1];

        xp0 = _standardize(xp0[0], xp0[1]);
        xp1 = _standardize(xp1[0], xp1[1]);
        uint256 D0 = (futureAGammaTime > 0) ? _newtonD(mA, mGamma, xp0) : D;
        uint256 D1 = _newtonD(mA, mGamma, xp1);
        lpAmount = (tokenSupply * D1) / D0 - tokenSupply;
        lpFee = (_calcTokenFeeRate(xp0, xp1) * lpAmount) / _PRECISION_FEE + 1;
        lpAmount -= lpFee;
    }

    function calcWithdraw(uint256 _amount) external view readOnlyNonReentrant returns (uint256[] memory amounts) {
        uint256 _totalSupply = _lpTotalSupply();
        uint256[N_COINS] memory balances_ = balances;
        amounts = new uint256[](N_COINS);
        for (uint256 i = 0; i < N_COINS; ++i) {
            amounts[i] = (balances_[i] * _amount) / _totalSupply;
        }
    }

    function calcWithdrawOneCoin(
        uint256 tokenAmount,
        uint256 i
    ) external view readOnlyNonReentrant returns (uint256 dy, uint256 lpFee) {
        (dy, lpFee, , ) = _calcWithdrawOneCoin(tokenAmount, i, _standardize(balances[0], balances[1]));
    }

    /// @return The rate of lpPrice/coin[0] with 1e18 precision
    function lpPrice() external view returns (uint256) {
        /*
        Approximate LP token price
        */
        return (2 * virtualPrice * _sqrtInt(_internalPriceOracle())) / 10 ** 18;
    }

    function A() external view returns (uint256 result) {
        (result, ) = _AGamma();
    }

    function gamma() external view returns (uint256 result) {
        (, result) = _AGamma();
    }

    function fee() external view readOnlyNonReentrant returns (uint256) {
        return _feeRate(_standardize(balances[0], balances[1]));
    }

    function getVirtualPrice() external view readOnlyNonReentrant returns (uint256) {
        return (10 ** 18 * _getXcp(D)) / _lpTotalSupply();
    }

    /// @return The rate of coin[1]/coin[0] with 1e18 precision
    function priceOracle() external view returns (uint256) {
        return _internalPriceOracle();
    }

    function coins(uint256 i) external view returns (address) {
        return _coins(i);
    }

    function _coins() internal view returns (address[N_COINS] memory) {
        return [_coin0, _coin1];
    }

    function _coins(uint256 i) internal view returns (address) {
        if (i == 0) {
            return _coin0;
        } else if (i == 1) {
            return _coin1;
        } else {
            revert();
        }
    }

    function _lpTotalSupply() internal view returns (uint256) {
        return ICryptoPoolToken(token).totalSupply();
    }

    function _thisBalanceOf(address coin) internal view returns (uint256) {
        return IERC20(coin).balanceOf(address(this));
    }

    function _pullToken(address coin, address from, uint256 amount) internal {
        IERC20(coin).safeTransferFrom(from, address(this), amount);
    }

    function _transfer(address coin, address to, uint256 amount) internal {
        IERC20(coin).safeTransfer(to, amount);
    }

    function _geometricMean(uint256[N_COINS] memory unsortedX, bool sort) internal pure returns (uint256) {
        /// (x[0] * x[1] * ...) ** (1/N)
        uint256[N_COINS] memory x = _arrCopy(unsortedX);
        if (sort && x[0] < x[1]) {
            x[0] = unsortedX[1];
            x[1] = unsortedX[0];
        }
        uint256 _D = x[0];
        uint256 diff = 0;
        for (uint256 i = 0; i < 255; ++i) {
            uint256 DPrev = _D;
            // tmp: uint256 = 10**18
            // for _x in x:
            //     tmp = tmp * _x / D
            // D = D * ((N_COINS - 1) * 10**18 + tmp) / (N_COINS * 10**18)
            // line below makes it for 2 coins
            _D = (_D + (x[0] * x[1]) / _D) / N_COINS;
            unchecked {
                if (_D > DPrev) {
                    diff = _D - DPrev;
                } else {
                    diff = DPrev - _D;
                }
            }
            if (diff <= 1 || diff * 10 ** 18 < _D) {
                return _D;
            }
        }
        revert("C");
    }

    function _newtonD(uint256 mA, uint256 mGamma, uint256[N_COINS] memory xUnsorted) internal pure returns (uint256) {
        /*
        Finding the invariant using Newton method.
        ANN is higher by the factor A_MULTIPLIER
        ANN is already A * N**N

        Currently uses 60k gas
        */
        // Safety checks
        unchecked {
            require(mA > _MIN_A - 1 && mA < _MAX_A + 1); // dev: unsafe values A
            require(mGamma > _MIN_GAMMA - 1 && mGamma < _MAX_GAMMA + 1); // dev: unsafe values gamma
        }
        // Initial value of invariant D is that for constant-product invariant
        uint256[N_COINS] memory x = _arrCopy(xUnsorted);
        if (x[0] < x[1]) {
            x[0] = xUnsorted[1];
            x[1] = xUnsorted[0];
        }

        require(x[0] > 10 ** 9 - 1 && x[0] < 10 ** 15 * 10 ** 18 + 1); // dev: unsafe values x[0]
        require((x[1] * 10 ** 18) / x[0] > 10 ** 14 - 1); // dev: unsafe values x[i] (input)

        uint256 _D = N_COINS * _geometricMean(x, false);
        uint256 S = x[0] + x[1];

        for (uint256 i = 0; i < 255; ++i) {
            uint256 DPrev = _D;

            // K0: uint256 = 10**18
            // for _x in x:
            //     K0 = K0 * _x * N_COINS / D
            // collapsed for 2 coins
            uint256 K0 = ((((10 ** 18 * N_COINS ** 2) * x[0]) / _D) * x[1]) / _D;

            uint256 _g1k0 = mGamma + 10 ** 18;
            unchecked {
                if (_g1k0 > K0) {
                    _g1k0 = _g1k0 - K0 + 1;
                } else {
                    _g1k0 = K0 - _g1k0 + 1;
                }
            }

            // D / (A * N**N) * _g1k0**2 / gamma**2
            uint256 mul1 = (((((10 ** 18 * _D) / mGamma) * _g1k0) / mGamma) * _g1k0 * _A_MULTIPLIER) / mA;

            // 2*N*K0 / _g1k0
            uint256 mul2 = ((2 * 10 ** 18) * N_COINS * K0) / _g1k0;

            uint256 negFprime = (S + (S * mul2) / 10 ** 18) + (mul1 * N_COINS) / K0 - (mul2 * _D) / 10 ** 18;

            // D -= f / fprime
            uint256 D_plus = (_D * (negFprime + S)) / negFprime;
            uint256 D_minus = (_D * _D) / negFprime;
            if (10 ** 18 > K0) {
                D_minus += (((_D * (mul1 / negFprime)) / 10 ** 18) * (10 ** 18 - K0)) / K0;
            } else {
                D_minus -= (((_D * (mul1 / negFprime)) / 10 ** 18) * (K0 - 10 ** 18)) / K0;
            }
            unchecked {
                if (D_plus > D_minus) {
                    _D = D_plus - D_minus;
                } else {
                    _D = (D_minus - D_plus) / 2;
                }
            }

            uint256 diff = 0;
            unchecked {
                if (_D > DPrev) {
                    diff = _D - DPrev;
                } else {
                    diff = DPrev - _D;
                }
            }
            if (diff * 10 ** 14 < Math.max(10 ** 16, _D)) {
                // Could reduce precision for gas efficiency here
                // Test that we are safe with the next newton_y
                for (uint256 j = 0; j < x.length; ++j) {
                    uint256 frac = (x[j] * 10 ** 18) / _D;
                    require((frac > 10 ** 16 - 1) && (frac < 10 ** 20 + 1)); // dev: unsafe values x[i]
                }
                return _D;
            }
        }
        revert("C");
    }

    function _newtonY(uint256 mA, uint256 mGamma, uint256 xJ, uint256 _D) internal pure returns (uint256 y) {
        /*
        Calculating x[i] given other balances x[0..N_COINS-1] and invariant D
        ANN = A * N**N
        */
        // Safety checks
        unchecked {
            require(mA > _MIN_A - 1 && mA < _MAX_A + 1); // dev: unsafe values A
            require(mGamma > _MIN_GAMMA - 1 && mGamma < _MAX_GAMMA + 1); // dev: unsafe values gamma
            require(_D > 10 ** 17 - 1 && _D < 10 ** 15 * 10 ** 18 + 1); // dev: unsafe values D
        }

        y = _D ** 2 / (xJ * N_COINS ** 2);
        uint256 K0I = ((10 ** 18 * N_COINS) * xJ) / _D;
        // S_i = xJ

        // frac = xJ * 1e18 / D => frac = K0I / N_COINS
        require((K0I > 10 ** 16 * N_COINS - 1) && (K0I < 10 ** 20 * N_COINS + 1)); // dev: unsafe values x[i]

        // x_sorted: uint256[N_COINS] = x
        // x_sorted[i] = 0
        // x_sorted = self.sort(x_sorted)  // From high to low
        // x[not i] instead of x_sorted since x_sorted has only 1 element

        uint256 convergenceLimit = Math.max(Math.max(xJ / 10 ** 14, _D / 10 ** 14), 100);

        for (uint256 j = 0; j < 255; ++j) {
            uint256 K0 = (K0I * y * N_COINS) / _D;

            uint256 mul1;
            uint256 mul2;
            {
                uint256 _g1k0 = mGamma + 10 ** 18;
                unchecked {
                    if (_g1k0 > K0) {
                        _g1k0 = _g1k0 - K0 + 1;
                    } else {
                        _g1k0 = K0 - _g1k0 + 1;
                    }
                }

                // D / (A * N**N) * _g1k0**2 / gamma**2
                mul1 = (((((10 ** 18 * _D) / mGamma) * _g1k0) / mGamma) * _g1k0 * _A_MULTIPLIER) / mA;

                // 2*K0 / _g1k0
                mul2 = 10 ** 18 + ((2 * 10 ** 18) * K0) / _g1k0;
            }

            uint256 S = xJ + y;
            uint256 yfprime = 10 ** 18 * y + S * mul2 + mul1;
            uint256 yPrev = y;
            {
                uint256 _dyfprime = _D * mul2;
                if (yfprime < _dyfprime) {
                    y = yPrev / 2;
                    continue;
                } else {
                    unchecked {
                        yfprime -= _dyfprime;
                    }
                }
            }
            {
                uint256 fprime = yfprime / y;

                // y -= f / f_prime;  y = (y * fprime - f) / fprime
                // y = (yfprime + 10**18 * D - 10**18 * S) // fprime + mul1 // fprime * (10**18 - K0) // K0
                uint256 yMinus = mul1 / fprime;
                uint256 yPlus = (yfprime + 10 ** 18 * _D) / fprime + (yMinus * 10 ** 18) / K0;
                yMinus += (10 ** 18 * S) / fprime;

                if (yPlus < yMinus) {
                    y = yPrev / 2;
                } else {
                    unchecked {
                        y = yPlus - yMinus;
                    }
                }
            }

            uint256 diff;
            unchecked {
                diff = y > yPrev ? y - yPrev : yPrev - y;
            }
            if (diff < Math.max(convergenceLimit, y / 10 ** 14)) {
                uint256 frac = (y * 10 ** 18) / _D;
                require((frac > 10 ** 16 - 1) && (frac < 10 ** 20 + 1)); // dev: unsafe value for y
                return y;
            }
        }
        revert("C");
    }

    function _burnMsgSender(uint256 amount) internal {
        ICryptoPoolToken(token).burn(msg.sender, amount);
    }

    function _mintMsgSender(uint256 amount) internal {
        ICryptoPoolToken(token).mint(msg.sender, amount);
    }
}

