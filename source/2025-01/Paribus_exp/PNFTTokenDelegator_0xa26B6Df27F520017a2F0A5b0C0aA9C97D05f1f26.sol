// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.5.0 ^0.5.17 ^0.5.5;
pragma experimental ABIEncoderV2;

// openzeppelin2/utils/Address.sol

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
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Converts an `address` into `address payable`. Note that this is
     * simply a type cast: the actual underlying value is not changed.
     *
     * _Available since v2.4.0._
     */
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
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
     *
     * _Available since v2.4.0._
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

// contracts/ErrorReporter.sol

contract ErrorReporter {
    event Failure(uint error);

    enum Error {
        NO_ERROR, // 0
        COMPTROLLER_MISMATCH, // 1
        INSUFFICIENT_SHORTFALL, // 2
        INSUFFICIENT_LIQUIDITY, // 3
        MARKET_NOT_LISTED, // 4
        NONZERO_BORROW_BALANCE, // 5
        PRICE_ERROR, // 6
        TOO_MUCH_REPAY, // 7
        NFT_USER_NOT_ALLOWED, // 8
        INVALID_EXCHANGE_PTOKEN, // 9
        USER_NOT_IN_MARKET, // 10
        TOKEN_INSUFFICIENT_CASH, // 11
        NON_WHITE_LISTED_POOL // 12
    }

    function fail(Error err) internal returns (Error) {
        assert(err != Error.NO_ERROR);
        emit Failure(uint(err));
        return err;
    }
}

// contracts/Utils/ExponentialNoError.sol

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
contract ExponentialNoError {
    uint constant expScale = 1e18;
    uint constant doubleScale = 1e36;
    uint constant halfExpScale = expScale/2;
    uint constant mantissaOne = expScale;

    struct Exp {
        uint mantissa;
    }

    struct Double {
        uint mantissa;
    }

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp memory exp) internal pure returns (uint) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return exp.mantissa / expScale;
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mul_ScalarTruncate(Exp memory a, uint scalar) internal pure returns (uint) {
        Exp memory product = mul_(a, scalar);
        return truncate(product);
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mul_ScalarTruncateAddUInt(Exp memory a, uint scalar, uint addend) internal pure returns (uint) {
        Exp memory product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }

    /**
     * @dev Checks if first Exp is less than second Exp.
     */
    function lessThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa < right.mantissa;
    }

    /**
     * @dev Checks if left Exp <= right Exp.
     */
    function lessThanOrEqualExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa <= right.mantissa;
    }

    /**
     * @dev Checks if left Exp > right Exp.
     */
    function greaterThanExp(Exp memory left, Exp memory right) internal pure returns (bool) {
        return left.mantissa > right.mantissa;
    }

    /**
     * @dev returns true if Exp is exactly zero
     */
    function isZeroExp(Exp memory value) internal pure returns (bool) {
        return value.mantissa == 0;
    }

    function safe224(uint n, string memory errorMessage) internal pure returns (uint224) {
        require(n < 2**224, errorMessage);
        return uint224(n);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function add_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: add_(a.mantissa, b.mantissa)});
    }

    function add_(uint a, uint b) internal pure returns (uint) {
        return add_(a, b, "addition overflow");
    }

    function add_(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(Exp memory a, Exp memory b, string memory errorMessage) internal pure returns (Exp memory) {
        return Exp({mantissa: sub_(a.mantissa, b.mantissa, errorMessage)});
    }

    function sub_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: sub_(a.mantissa, b.mantissa)});
    }

    function sub_(uint a, uint b) internal pure returns (uint) {
        return sub_(a, b, "subtraction underflow");
    }

    function sub_(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function mul_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b.mantissa) / expScale});
    }

    function mul_(Exp memory a, uint b) internal pure returns (Exp memory) {
        return Exp({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint a, Exp memory b) internal pure returns (uint) {
        return mul_(a, b.mantissa) / expScale;
    }

    function mul_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b.mantissa) / doubleScale});
    }

    function mul_(Double memory a, uint b) internal pure returns (Double memory) {
        return Double({mantissa: mul_(a.mantissa, b)});
    }

    function mul_(uint a, Double memory b) internal pure returns (uint) {
        return mul_(a, b.mantissa) / doubleScale;
    }

    function mul_(uint a, uint b) internal pure returns (uint) {
        return mul_(a, b, "multiplication overflow");
    }

    function mul_(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        if (a == 0 || b == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, errorMessage);
        return c;
    }

    function div_(Exp memory a, Exp memory b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(mul_(a.mantissa, expScale), b.mantissa)});
    }

    function div_(Exp memory a, uint b) internal pure returns (Exp memory) {
        return Exp({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint a, Exp memory b) internal pure returns (uint) {
        return div_(mul_(a, expScale), b.mantissa);
    }

    function div_(Double memory a, Double memory b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a.mantissa, doubleScale), b.mantissa)});
    }

    function div_(Double memory a, uint b) internal pure returns (Double memory) {
        return Double({mantissa: div_(a.mantissa, b)});
    }

    function div_(uint a, Double memory b) internal pure returns (uint) {
        return div_(mul_(a, doubleScale), b.mantissa);
    }

    function div_(uint a, uint b) internal pure returns (uint) {
        return div_(a, b, "divide by zero");
    }

    function div_(uint a, uint b, string memory errorMessage) internal pure returns (uint) {
        require(b > 0, errorMessage);
        return a / b;
    }

    function fraction(uint a, uint b) internal pure returns (Double memory) {
        return Double({mantissa: div_(mul_(a, doubleScale), b)});
    }

    /**
     * @dev Creates an exponential from numerator and denominator values.
     *      Note: Reverts if (`num` * 10e18) > MAX_INT or if `denom` is zero.
     */
    function getExp_(uint num, uint denom) internal pure returns (uint) {
        uint scaledNumerator = mul_(num, expScale);
        return div_(scaledNumerator, denom);
    }
}

// openzeppelin2/token/ERC20/IERC20.sol

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
}

// openzeppelin2/token/ERC721/IERC721Receiver.sol

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
contract IERC721Receiver {
    /**
     * @notice Handle the receipt of an NFT
     * @dev The ERC721 smart contract calls this function on the recipient
     * after a {IERC721-safeTransferFrom}. This function MUST return the function selector,
     * otherwise the caller will revert the transaction. The selector to be
     * returned can be obtained as `this.onERC721Received.selector`. This
     * function MAY throw to revert and reject the transfer.
     * Note: the ERC721 contract address is always the message sender.
     * @param operator The address which called `safeTransferFrom` function
     * @param from The address which previously owned the token
     * @param tokenId The NFT identifier which is being transferred
     * @param data Additional data with no specified format
     * @return bytes4 `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
    public returns (bytes4);
}

// contracts/InterestRateModels/InterestRateModelInterface.sol

/**
  * @title Compound's InterestRateModel Interface
  * @author Compound
  */
contract InterestRateModelInterface {
    /// @notice Indicator that this is an InterestRateModel contract (for inspection)
    bool public constant isInterestRateModel = true;

    /**
      * @notice Calculates the current borrow interest rate per block
      * @param cash The total amount of cash the market has
      * @param borrows The total amount of borrows the market has outstanding
      * @param reserves The total amount of reserves the market has
      * @return The borrow rate per block (as a percentage, and scaled by 1e18)
      */
    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint);

    /**
      * @notice Calculates the current supply interest rate per block
      * @param cash The total amount of cash the market has
      * @param borrows The total amount of borrows the market has outstanding
      * @param reserves The total amount of reserves the market has
      * @param reserveFactorMantissa The current reserve factor the market has
      * @return The supply rate per block (as a percentage, and scaled by 1e18)
      */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint);
}

// contracts/Interfaces/LPInterfaces.sol

contract LPTokenInterface {
    address public token0;
    address public token1;

    function getReserves() external view returns (uint112, uint112, uint32);

    function totalSupply() external view returns (uint);

    function factory() external view returns (address);

    function kLast() external view returns (uint);
}

contract NFPManagerInterface {
    address public token0;
    address public token1;

    function factory() external view returns (address);
}

contract UniswapNFPManagerInterface is NFPManagerInterface {
    struct Position {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint feeGrowthInside0LastX128;
        uint feeGrowthInside1LastX128;
        uint128 tokens0Owed;
        uint128 tokens1Owed;
    }

    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
    
    // function positions1(uint256 tokenId) external view returns (
    //     Position memory position
    // );
}

contract AlgebraNFPManagerInterface is NFPManagerInterface {
    // algebra v1.9 position struct is slightly different from UniV3
    struct Position {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint feeGrowthInside0LastX128;
        uint feeGrowthInside1LastX128;
        uint128 tokens0Owed;
        uint128 tokens1Owed;
    }

    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );

    // function positions1(uint256 tokenId) external view returns (
    //     Position memory position
    // );
}

// contracts/Interfaces/NFTXInterfaces.sol

interface INFTXVault {
    function assetAddress() external view returns (address);
}

interface INFTXVaultFactory {
    function vault(uint256 vaultId) external view returns (address);
}

interface INFTXMarketplaceZap {
    function WETH() external view returns (address);
    function nftxFactory() external view returns (INFTXVaultFactory);

    function mintAndSell721(uint256 vaultId, uint256[] calldata ids, uint256 minEthOut, address[] calldata path, address to) external;
    function mintAndSell721WETH(uint256 vaultId, uint256[] calldata ids, uint256 minWethOut, address[] calldata path, address to) external;

    function mintAndSell1155(uint256 vaultId, uint256[] calldata ids, uint256[] calldata amounts, uint256 minWethOut, address[] calldata path, address to) external;
    function mintAndSell1155WETH(uint256 vaultId, uint256[] calldata ids, uint256[] calldata amounts, uint256 minWethOut, address[] calldata path, address to) external;
}

// openzeppelin2/math/SafeMath.sol

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// contracts/Interfaces/SudoswapInterfaces.sol

interface SudoswapLSSVMPairETHInterface {
    function nft() external view returns (address);
    function swapNFTsForToken(uint256[] calldata nftIds, uint256 minExpectedTokenOutput, address payable tokenRecipient) external returns (uint256);
}

interface SudoswapVeryFastRouterInterface {
    struct BuyOrderWithPartialFill {
        address pair;
        bool isERC721;
        uint256[] nftIds;
        uint256 maxInputAmount;
        uint256 ethAmount;
        uint256 expectedSpotPrice;
        uint256[] maxCostPerNumNFTs; // @dev This is zero-indexed, so maxCostPerNumNFTs[x] = max price we're willing to pay to buy x+1 NFTs
    }

    struct SellOrderWithPartialFill {
        address pair;
        bool isETHSell;
        bool isERC721;
        uint256[] nftIds;
        bool doPropertyCheck;
        bytes propertyCheckParams;
        uint128 expectedSpotPrice;
        uint256 minExpectedOutput;
        uint256[] minExpectedOutputPerNumNFTs;
    }

    struct Order {
        BuyOrderWithPartialFill[] buyOrders;
        SellOrderWithPartialFill[] sellOrders;
        address payable tokenRecipient;
        address nftRecipient;
        bool recycleETH;
    }

    /**
     * @dev Performs a batch of sells and buys, avoids performing swaps where the price is beyond
     * Handles selling NFTs for tokens or ETH
     * Handles buying NFTs with tokens or ETH,
     * @param swapOrder The struct containing all the swaps to be executed
     * @return results Indices [0..swapOrder.sellOrders.length-1] contain the actual output amounts of the
     * sell orders, indices [swapOrder.sellOrders.length..swapOrder.sellOrders.length+swapOrder.buyOrders.length-1]
     * contain the actual input amounts of the buy orders.
     */
    function swap(Order calldata swapOrder) external payable returns (uint256[] memory results);
}

// contracts/Interfaces/UniswapV3Interfaces.sol

interface IUniswapV3SwapRouter {
    function WETH9() external view returns (address);
    function factory() external returns (address);

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

interface IUniswapV3Pool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
    function liquidity() external view returns (uint128);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

// openzeppelin2/token/ERC20/SafeERC20.sol

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// contracts/Comptroller/ComptrollerInterfaces.sol

contract UnitrollerInterface is UnitrollerAdminStorage {
    /// @notice Emitted when pendingComptrollerImplementation is changed
    event NewPendingImplementations(address oldPendingPart1Implementation, address newPendingPart1Implementation, address oldPendingPart2Implementation, address newPendingPart2Implementation);

    /// @notice Emitted when pendingComptrollerImplementation is accepted, which means comptroller implementation is updated
    event NewImplementation(address oldPart1Implementation, address newPart1Implementation, address oldPart2Implementation, address newPart2Implementation);

    /// @notice Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Indicator that this is a Comptroller contract (for inspection)
    function isComptroller() external pure returns (bool);

    function _setPendingImplementations(address newPendingPart1Implementation, address newPendingPart2Implementation) external;

    function _acceptImplementation() external;

    function _setPendingAdmin(address newPendingAdmin) external;

    function _acceptAdmin() external;
}

contract ComptrollerNoNFTCommonInterface is ErrorReporter, ComptrollerNoNFTStorage {
    /// @notice The initial PBX index for a market
    uint224 public constant PBXInitialIndex = 1e36;

    /// @dev closeFactorMantissa must be strictly greater than this value
    uint internal constant closeFactorMinMantissa = 0.05e18;

    /// @dev closeFactorMantissa must not exceed this value
    uint internal constant closeFactorMaxMantissa = 0.9e18;

    /// @dev market collateral factor must not exceed this value
    uint internal constant collateralFactorMaxMantissa = 0.9e18;

    /// @notice Indicator that this is a Comptroller contract (for inspection)
    function isComptroller() external pure returns (bool);

    /// @notice Emitted when an admin supports a market (marketType 0 == standard assets, 1 == nfts)
    event MarketListed(address indexed pToken, uint indexed marketType, address underlying);

    /// @notice Emitted when an account enters a market
    event MarketEntered(address indexed pToken, address indexed account);

    /// @notice Emitted when an account exits a market
    event MarketExited(address indexed pToken, address indexed account);

    /// @notice Emitted when close factor is changed by admin
    event NewCloseFactor(uint oldCloseFactorMantissa, uint newCloseFactorMantissa);

    /// @notice Emitted when a collateral factor is changed by admin
    event NewCollateralFactor(address indexed pToken, uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);

    /// @notice Emitted when liquidation incentive is changed by admin
    event NewLiquidationIncentive(uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);

    /// @notice Emitted when price oracle is changed
    event NewPriceOracle(address oldPriceOracle, address newPriceOracle);

    /// @notice Emitted when pause guardian is changed
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);

    /// @notice Emitted when an action is paused on a market or globally (pToken == 0)
    event ActionPaused(address indexed pToken, string indexed action, bool pauseState);

    /// @notice Emitted when a new borrow-side PBX speed is calculated for a market
    event PBXBorrowSpeedUpdated(PToken indexed pToken, uint newSpeed);

    /// @notice Emitted when a new supply-side PBX speed is calculated for a market
    event PBXSupplySpeedUpdated(PToken indexed pToken, uint newSpeed);

    /// @notice Emitted when a new PBX speed is set for a contributor
    event ContributorPBXSpeedUpdated(address indexed contributor, uint newSpeed);

    /// @notice Emitted when PBX is distributed to a supplier
    event DistributedSupplierPBX(PToken indexed pToken, address indexed supplier, uint compDelta, uint PBXSupplyIndex);

    /// @notice Emitted when PBX is distributed to a borrower
    event DistributedBorrowerPBX(PToken indexed pToken, address indexed borrower, uint compDelta, uint PBXBorrowIndex);

    /// @notice Emitted when borrow cap for a pToken is changed
    event NewBorrowCap(PToken indexed pToken, uint newBorrowCap);

    /// @notice Emitted when borrow cap guardian is changed
    event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);

    /// @notice Emitted when PBX is granted by admin
    event PBXGranted(address indexed recipient, uint amount);

    event NewPBXToken(address oldPBXToken, address newPBXToken);

    function _become(address unitrollerAddress) external;
}

contract ComptrollerNFTCommonInterface is ComptrollerNoNFTCommonInterface, ComptrollerNFTStorage {
    event NFTLiquidationExchangePTokenSet(PToken indexed pToken, bool indexed enabled);

    event NewNFTCollateralLiquidationIncentive(uint oldNFTCollateralLiquidationIncentiveMantissa, uint newNFTCollateralLiquidationIncentiveMantissa);

    event NewNFTCollateralLiquidationBonusPBXIncentive(uint oldNFTCollateralLiquidationBonusPBXIncentiveMantissa, uint newNFTCollateralLiquidationBonusPBXIncentiveMantissa);

    event NewNFTCollateralSeizeLiquidationFactor(uint oldNFTCollateralSeizeLiquidationFactorMantissa, uint newNFTCollateralSeizeLiquidationFactorMantissa);
}

contract ComptrollerNoNFTPart1Interface is ComptrollerNoNFTCommonInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptrollerPart1 = true;

    /*** Assets You Are In ***/

    function getAssetsIn(address account) external view returns (PToken[] memory);
    function checkMembership(address account, address pToken) external view returns (bool);
    function getDepositBorrowValues(address account) external view returns (uint, uint, uint);
    function getAllMarkets() external view returns (PToken[] memory);

    /*** Admin Functions ***/

    function _setPriceOracle(address newOracle) external;
    function _setCloseFactor(uint newCloseFactorMantissa) external;
    function _setCollateralFactor(PToken pToken, uint newCollateralFactorMantissa) external;
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external;
    function _supportMarket(PToken pToken) external;
    function _setMarketBorrowCaps(PToken[] calldata pTokens, uint[] calldata newBorrowCaps) external;
    function _setBorrowCapGuardian(address newBorrowCapGuardian) external;
    function _setPauseGuardian(address newPauseGuardian) external;
    function _setMintPaused(address pToken, bool state) external returns (bool);
    function _setMintPausedGlobal(bool state) public returns (bool);
    function _setBorrowPaused(address pToken, bool state) external returns (bool);
    function _setBorrowPausedGlobal(bool state) public returns (bool);
    function _setTransferPaused(bool state) public returns (bool);
    function _setSeizePaused(bool state) public returns (bool);
    function _setAllPausedGlobal(bool state) external returns (bool);
    function _setPBXToken(address newPBXTokenAddress) external;
    function _setMinBorrowAmount(uint newMinBorrowAmount) external;

    /*** Policy Hooks ***/

    function mintVerify(address pToken, address minter, uint mintAmount, uint mintTokens) external;
    function redeemVerify(address pToken, address redeemer, uint redeemAmount, uint redeemTokens) external;
    function borrowVerify(address pToken, address borrower, uint borrowAmount) external;
    function repayBorrowVerify(address pToken, address payer, address borrower, uint repayAmount, uint borrowerIndex) external;
    function liquidateBorrowVerify(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint repayAmount, uint seizeTokens) external;
    function seizeVerify(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external;
    function transferVerify(address pToken, address src, address dst, uint transferTokens) external;

    /*** PBX Distribution Admin ***/

    function _setContributorPBXSpeed(address contributor, uint PBXSpeed) external;

    /*** PBX Distribution ***/

    function updateContributorRewards(address contributor) public;
}

contract ComptrollerNFTPart1Interface is ComptrollerNoNFTPart1Interface, ComptrollerNFTCommonInterface {
    /*** Assets You Are In ***/

    function getNFTAssetsIn(address account) external view returns (PNFTToken[] memory);
    function getNFTDepositValue(address account) public view returns (uint);
    function getAllNFTMarkets() external view returns (PNFTToken[] memory);

    /*** Liquidity/Liquidation Calculations ***/

    function nftLiquidateCalculateValues(address PNFTTokenAddress, uint tokenId, address NFTLiquidationExchangePToken) external view returns (uint, uint, uint, uint);
    function nftLiquidateCalculatePBXBonusIncentive(uint nftMinimumSellValueUSD) public view returns (uint);

    /*** Admin Functions ***/

    function _setNFTCollateralFactor(PNFTToken pNFTToken, uint newCollateralFactorMantissa) external;
    function _setNFTCollateralLiquidationIncentive(uint newNFTCollateralLiquidationIncentiveMantissa) external;
    function _setNFTCollateralLiquidationBonusPBX(uint newNFTCollateralLiquidationBonusPBXIncentiveMantissa) external;
    function _setNFTCollateralSeizeLiquidationFactor(uint newNFTCollateralSeizeLiquidationFactorMantissa) external;
    function _supportNFTMarket(PNFTToken pNFTToken) external;
    function _setNFTLiquidationExchangePToken(address exchangePToken, bool enabled) external;
    function _setNFTXioMarketplaceZapAddress(address newNFTXioMarketplaceZapAddress) external;
    function _setSudoswapPairRouterAddress(address newSudoswapRouterAddress) external;
    function _setUniswapV3SwapRouterAddress(address newUniswapV3SwapRouterAddress) external;
    function _setNFTModuleClosedBeta(bool newNFTModuleClosedBeta) external;
    function _NFTModuleWhitelistUser(address[] calldata whitelistedUsers) external;
    function _NFTModuleRemoveWhitelistUser(address[] calldata removedUsers) external;

    /*** Policy Hooks ***/

    function mintNFTVerify(address pNFTToken, address minter, uint tokenId) external;
    function redeemNFTVerify(address pNFTToken, address redeemer, uint tokenId) external;
    function transferNFTVerify(address pNFTToken, address src, address dst, uint tokenId) external;
    function liquidateNFTCollateralVerify(address pNFTTokenCollateral, address liquidator, address borrower, uint tokenId) external;
}

contract ComptrollerNoNFTPart2Interface is ComptrollerNoNFTCommonInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptrollerPart2 = true;

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata pTokens) external;
    function exitMarket(address pToken) external returns (Error);

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(address pTokenBorrowed, address pTokenCollateral, uint repayAmount) external view returns (uint);
    function getHypotheticalAccountLiquidity(address account, address pTokenModify, uint redeemTokens, uint borrowAmount, uint redeemTokenId) public view returns (Error, uint, uint);
    function getAccountLiquidity(address account) external view returns (Error, uint, uint);
    function getCollateralBorrowValues(address account) external view returns (uint, uint, uint);

    /*** Policy Hooks ***/

    function mintAllowed(address pToken, address minter, uint mintAmount) external returns (Error);
    function redeemAllowed(address pToken, address redeemer, uint redeemTokens) external returns (Error);
    function borrowAllowed(address pToken, address borrower, uint borrowAmount) external returns (Error);
    function transferAllowed(address pToken, address src, address dst, uint transferTokens) external returns (Error);
    function repayBorrowAllowed(address pToken, address payer, address borrower, uint repayAmount) external returns (Error);
    function seizeAllowed(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external returns (Error);
    function liquidateBorrowAllowed(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint repayAmount) external returns (Error);

    /*** PBX Distribution ***/

    function claimPBXReward(address holder) external;
    function claimPBXSingle(address holder, PToken[] memory pTokens) public;
    function claimPBX(address[] memory holders, PToken[] memory pTokens, bool borrowers, bool suppliers) public;
    function PBXAccrued(address holder) public view returns (uint);

    /*** PBX Distribution Admin ***/

    function _grantPBX(address recipient, uint amount) external;
    function _setPBXSpeeds(PToken[] calldata pTokens, uint[] calldata supplySpeeds, uint[] calldata borrowSpeeds) external;
}

contract ComptrollerNFTPart2Interface is ComptrollerNoNFTPart2Interface, ComptrollerNFTCommonInterface {
    /*** Assets You Are In ***/

    function enterNFTMarkets(address[] calldata pNFTTokens) external;
    function exitNFTMarket(address pNFTToken) external returns (Error);

    /*** Liquidity/Liquidation Calculations ***/

    function nftLiquidateSendPBXBonusIncentive(uint bonusIncentive, address liquidator) external;

    /*** Policy Hooks ***/

    function mintNFTAllowed(address pNFTToken, address minter, uint tokenId) external returns (Error);
    function redeemNFTAllowed(address pToken, address redeemer, uint tokenId) external returns (Error);
    function transferNFTAllowed(address pToken, address src, address dst, uint tokenId) external returns (Error);
    function liquidateNFTCollateralAllowed(address pNFTTokenCollateral, address liquidator, address borrower, uint tokenId, address NFTLiquidationExchangePToken) external returns (Error);
}

contract ComptrollerNFTInterface is ComptrollerNFTPart1Interface, ComptrollerNFTPart2Interface { }
contract ComptrollerNoNFTInterface is ComptrollerNoNFTPart1Interface, ComptrollerNoNFTPart2Interface { }
contract ComptrollerNFTUnitrollerMergedInterface is UnitrollerInterface, ComptrollerNFTInterface { }
contract ComptrollerNoNFTUnitrollerMergedInterface is UnitrollerInterface, ComptrollerNoNFTInterface { }

// contracts/Comptroller/ComptrollerStorage.sol

contract UnitrollerAdminStorage {
    /// @notice Administrator for this contract
    address public admin;

    /// @notice Pending administrator for this contract
    address public pendingAdmin;

    /// @notice Active brains of Unitroller
    address public comptrollerPart1Implementation;
    address public comptrollerPart2Implementation;

    /// @notice Pending brains of Unitroller
    address public pendingComptrollerPart1Implementation;
    address public pendingComptrollerPart2Implementation;
}

contract ComptrollerNoNFTStorage is UnitrollerAdminStorage {
    /// @notice Oracle which gives the price of any given asset
    address public oracle;

    /// @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
    uint public closeFactorMantissa;

    /// @notice Multiplier representing the discount on collateral that a liquidator receives
    uint public liquidationIncentiveMantissa;

    /// @notice Per-account mapping of "assets you are in"
    mapping(address => PToken[]) public accountAssets;

    struct Market {
        /// @notice Whether or not this market is listed
        bool isListed;

        /**
         * @notice Multiplier representing the most one can borrow against their collateral in this market.
         *  For instance, 0.9 to allow borrowing 90% of collateral value.
         *  Must be between 0 and 1, and stored as a mantissa.
         */
        uint collateralFactorMantissa;

        /// @notice Per-market mapping of "accounts in this asset"
        mapping(address => bool) accountMembership;
    }

    /**
     * @notice Official mapping of pTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;

    /**
     * @notice The Pause Guardian can pause certain actions as a safety mechanism.
     *  Actions which allow users to remove their own assets cannot be paused.
     *  Liquidation / seizing / transfer can only be paused globally, not by market.
     */
    address public pauseGuardian;
    bool public mintGuardianPausedGlobal;
    bool public borrowGuardianPausedGlobal;
    bool public transferGuardianPausedGlobal;
    bool public seizeGuardianPausedGlobal;
    mapping(address => bool) public mintGuardianPaused;
    mapping(address => bool) public borrowGuardianPaused;

    struct PBXMarketState {
        /// @notice The market's last updated PBXBorrowIndex or PBXSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

    /// @notice A list of all markets
    PToken[] public allMarkets;

    /// @notice The PBX market supply state for each market
    mapping(address => PBXMarketState) public PBXSupplyState;

    /// @notice The PBX market borrow state for each market
    mapping(address => PBXMarketState) public PBXBorrowState;

    /// @notice The PBX borrow index for each market for each supplier as of the last time they accrued PBX
    mapping(address => mapping(address => uint)) public PBXSupplierIndex;

    /// @notice The PBX borrow index for each market for each borrower as of the last time they accrued PBX
    mapping(address => mapping(address => uint)) public PBXBorrowerIndex;

    /// @notice The PBX accrued but not yet transferred to each user
    mapping(address => uint) public PBXAccruedStored;

    /// @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap could disable borrowing on the given market.
    address public borrowCapGuardian;

    /// @notice Borrow caps enforced by borrowAllowed for each pToken address. Defaults to zero which corresponds to unlimited borrowing.
    mapping(address => uint) public borrowCaps;

    /// @notice The portion of PBX that each contributor receives per block
    mapping(address => uint) public PBXContributorSpeeds;

    /// @notice Last block at which a contributor's PBX rewards have been allocated
    mapping(address => uint) public lastContributorBlock;

    /// @notice The PBX governance token
    address public PBXToken;

    /// @notice The rate at which PBX is distributed to the corresponding borrow market (per block)
    mapping(address => uint) public PBXBorrowSpeeds;

    /// @notice The rate at which PBX is distributed to the corresponding supply market (per block)
    mapping(address => uint) public PBXSupplySpeeds;

    /// @notice Global minimum borrow amount
    uint256 public minBorrowAmount;
}

contract ComptrollerNFTStorage is ComptrollerNoNFTStorage {
    /// @notice A list of all NFT markets
    PNFTToken[] public allNFTMarkets;

    /// @notice Per-account mapping of "assets you are in"
    mapping(address => PNFTToken[]) public accountNFTAssets;

    uint public NFTCollateralLiquidationIncentiveMantissa;

    uint public NFTCollateralLiquidationBonusPBXIncentiveMantissa;

    address public NFTXioMarketplaceZapAddress;

    /// @dev Sudoswap LSSVMRouter contract
    address public sudoswapRouterAddress;

    uint public NFTCollateralSeizeLiquidationFactorMantissa;

    /// @notice whether PToken can be used as a part of NFT liquidation process
    mapping(address => bool) public isNFTLiquidationExchangePToken;

    bool public NFTModuleClosedBeta /* = false */;

    mapping(address => bool) public NFTModuleWhitelistedUsers;

    address public uniswapV3SwapRouterAddress;
}

// contracts/PNFTToken/PNFTToken.sol

/**
 * @title Paribus PNFTToken Contract
 * @notice Abstract base for PNFTTokens
 * @author Paribus
 */
contract PNFTToken is PNFTTokenInterface, ExponentialNoError {
    using SafeERC20 for IERC20;

    /**
     * @notice Initialize the money market
     * @param underlying_ The address of the underlying asset
     * @param comptroller_ The address of the Comptroller
     * @param name_ EIP-721 name of this token
     * @param symbol_ EIP-721 symbol of this token
     */
    function initialize(address underlying_,
        address comptroller_,
        string memory name_,
        string memory symbol_) public {
        require(msg.sender == admin, "only admin may initialize the market");
        require(underlying_ != address(0), "invalid argument");
        require(underlying == address(0), "can only initialize once");

        // Set the comptroller
        _setComptroller(comptroller_);

        name = name_;
        symbol = symbol_;
        underlying = underlying_;
        NFTXioVaultId = -1; // -1 == not set

        // The counter starts true to prevent changing it from zero to non-zero (i.e. smaller cost/refund)
        _notEntered = true;
    }

    /*** ERC165 Functions ***/

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return interfaceId == 0x80ac58cd || // _INTERFACE_ID_ERC721
               interfaceId == 0x01ffc9a7 || // _INTERFACE_ID_ERC165
               interfaceId == 0x780e9d63;   // _INTERFACE_ID_ERC721_ENUMERABLE
    }

    /*** EIP721 Functions ***/

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint tokenId) internal view returns (bool) {
        return tokensOwners[tokenId] != address(0);
    }

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        uint size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId The token ID
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) internal returns (bool) {
        if (!isContract(to))
            return true;

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = to.call(abi.encodeWithSelector(
                IERC721Receiver(to).onERC721Received.selector,
                msg.sender,
                from,
                tokenId,
                _data
            ));

        if (!success) {
            if (returndata.length > 0) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("transfer to non ERC721Receiver implementer");
            }
        } else {
            bytes4 retval = abi.decode(returndata, (bytes4));
            bytes4 _ERC721_RECEIVED = 0x150b7a02; // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
            return (retval == _ERC721_RECEIVED);
        }

    }

    /**
     * @dev Gets the list of token IDs of the requested owner.
     * @param owner address owning the tokens
     * @return uint[] List of token IDs owned by the requested address
     */
    function _tokensOfOwner(address owner) internal view returns (uint[] storage) {
        return ownedTokens[owner];
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint tokenId) internal {
        ownedTokensIndex[tokenId] = ownedTokens[to].length;
        ownedTokens[to].push(tokenId);
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint tokenId) internal {
        allTokensIndex[tokenId] = allTokens.length;
        allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the ownedTokensIndex mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint tokenId) internal {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint lastTokenIndex = sub_(ownedTokens[from].length, 1);
        uint tokenIndex = ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint lastTokenId = ownedTokens[from][lastTokenIndex];

            ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        ownedTokens[from].length--;

        // Note that ownedTokensIndex[tokenId] hasn't been cleared: it still points to the old slot (now occupied by
        // lastTokenId, or just over the end of the array if the token was the last one).
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the allTokens array.
     * @param tokenId uint ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint tokenId) internal {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint lastTokenIndex = sub_(allTokens.length, 1);
        uint tokenIndex = allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint lastTokenId = allTokens[lastTokenIndex];

        allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        allTokens.length--;
        allTokensIndex[tokenId] = 0;
    }

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst`
     * @dev Called by both `transfer` and `safeTransferInternal` internally
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokenId The token ID
     */
    function transferInternal(address src, address dst, uint tokenId) internal {
        require(ownerOf(tokenId) == src, "transfer from incorrect owner");
        require(dst != address(0), "transfer to the zero address");

        // Fail if transfer not allowed
        Error allowed = comptroller.transferNFTAllowed(address(this), src, dst, tokenId);
        require(allowed == Error.NO_ERROR, "transfer comptroller rejection");

        // Do the calculations, checking for {under,over}flow
        uint srcTokensNew = sub_(accountTokens[src], 1);
        uint dstTokensNew = add_(accountTokens[dst], 1);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // Clear approvals from the previous owner
        approveInternal(address(0), tokenId);

        /* Check for self-transfers
         * When src == dst, the values srcTokensNew, dstTokensNew are INCORRECT
         */
        if (src != dst) {
            accountTokens[src] = srcTokensNew;
            accountTokens[dst] = dstTokensNew;

            // Erc721Enumerable
            _removeTokenFromOwnerEnumeration(src, tokenId);
            _addTokenToOwnerEnumeration(dst, tokenId);
        }

        tokensOwners[tokenId] = dst;

        // We emit a Transfer event
        emit Transfer(src, dst, tokenId);

        // We call the defense hook
        comptroller.transferNFTVerify(address(this), src, dst, tokenId);
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokenId The token ID
     */
    function transferFrom(address src, address dst, uint tokenId) external nonReentrant {
        require(_isApprovedOrOwner(msg.sender, tokenId), "transfer caller is not owner nor approved");
        transferInternal(src, dst, tokenId);
    }

    /**
     * @dev Safely transfers `tokenId` token from `src` to `dst`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `src` cannot be the zero address.
     * - `dst` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `src`.
     * - If the caller is not `src`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `dst` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address src, address dst, uint tokenId) public {
        safeTransferFrom(src, dst, tokenId, "");
    }

    /**
     * @dev Safely transfers `tokenId` token from `src` to `dst`.
     *
     * Requirements:
     *
     * - `src` cannot be the zero address.
     * - `dst` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `src`.
     * - If the caller is not `src`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `dst` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address src, address dst, uint tokenId, bytes memory data) public nonReentrant {
        require(_isApprovedOrOwner(msg.sender, tokenId), "transfer caller is not owner nor approved");
        safeTransferInternal(src, dst, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `src` to `dst`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `dst`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `src` cannot be the zero address.
     * - `dst` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `src`.
     * - If `dst` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferInternal(address src, address dst, uint tokenId, bytes memory data) internal {
        transferInternal(src, dst, tokenId);
        require(_checkOnERC721Received(src, dst, tokenId, data), "transfer to non ERC721Receiver implementer");
    }

    /// @dev Returns whether `spender` is allowed to manage `tokenId`.
    function _isApprovedOrOwner(address spender, uint tokenId) internal view returns (bool) {
        require(_exists(tokenId), "operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

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
    function approve(address to, uint tokenId) external {
        address owner = ownerOf(tokenId);
        require(to != owner, "approval to current owner");

        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "approve caller is not owner nor approved for all");

        approveInternal(to, tokenId);
    }

    function approveInternal(address to, uint tokenId) internal {
        transferAllowances[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint tokenId) public view returns (address) {
        require(_exists(tokenId), "approved query for nonexistent token");
        return transferAllowances[tokenId];
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) public {
        setApprovalForAllInternal(msg.sender, operator, approved);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAllInternal(address owner, address operator, bool approved) internal {
        require(owner != operator, "approve to caller");
        operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return operatorApprovals[owner][operator];
    }

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint) {
        require(owner != address(0), "address zero is not a valid owner");
        return accountTokens[owner];
    }

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint tokenId) public view returns (address) {
        address owner = tokensOwners[tokenId];
        require(owner != address(0), "owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev Gets the token ID at a given index of the tokens list of the requested owner.
     * @param owner address owning the tokens list to be accessed
     * @param index uint representing the index to be accessed of the requested tokens list
     * @return uint token ID at the given index of the tokens list owned by the requested address
     */
    function tokenOfOwnerByIndex(address owner, uint index) external view returns (uint) {
        require(index < this.balanceOf(owner), "owner index out of bounds");
        return ownedTokens[owner][index];
    }

    /**
     * @dev Gets the total amount of tokens stored by the contract.
     * @return uint representing the total amount of tokens
     */
    function totalSupply() public view returns (uint) {
        return allTokens.length;
    }

    /**
     * @dev Gets the token ID at a given index of all the tokens in this contract
     * Reverts if the index is greater or equal to the total number of tokens.
     * @param index uint representing the index to be accessed of the tokens list
     * @return uint token ID at the given index of the tokens list
     */
    function tokenByIndex(uint index) public view returns (uint) {
        require(index < totalSupply(), "global index out of bounds");
        return allTokens[index];
    }

    /**
    * @dev Gets the token IDs owned by the owner
    * @param _owner owner of the token ids
    * @return uint[] token IDs owned by the requested address
    */
    function tokenOfOwner(address _owner) public view returns(uint[] memory) {
        return _tokensOfOwner(_owner);
    }

    /*** User Interface ***/

    /**
     * @notice Get the underlying balance of the `owner`
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) external view returns (uint) {
        return accountTokens[owner];
    }

    /**
     * @notice Get cash balance of this pToken in the underlying asset
     * @return The quantity of underlying asset owned by this contract
     */
    function getCash() external view returns (uint) {
        return getCashPrior();
    }

    /**
     * @notice Sender supplies assets into the market and receives pTokens in exchange
     * @param tokenId The token ID
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function mint(uint tokenId) external returns (Error) {
        return mintInternal(msg.sender, tokenId);
    }

    function safeMint(uint tokenId) external returns (Error) {
        return safeMintInternal(tokenId, "");
    }

    function safeMint(uint tokenId, bytes calldata data) external returns (Error) {
        return safeMintInternal(tokenId, data);
    }

    function safeMintInternal(uint tokenId, bytes memory data) internal returns (Error) {
        require(_checkOnERC721Received(address(0), msg.sender, tokenId, data), "transfer to non ERC721Receiver implementer");
        return mintInternal(msg.sender, tokenId);
    }

    /**
     * @notice Sender supplies assets into the market and receives pTokens in exchange
     * @param minter The address of the account which is supplying the assets
     * @param tokenId The token ID
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function mintInternal(address minter, uint tokenId) internal nonReentrant returns (Error) {
        require(!_exists(tokenId), "token already minted");

        // Fail if mint not allowed
        Error allowed = comptroller.mintNFTAllowed(address(this), minter, tokenId);
        if (allowed != Error.NO_ERROR) {
            return fail(allowed);
        }

        /*
         * We calculate the new total supply of pTokens and minter token balance, checking for overflow:
         *  accountTokensNew = accountTokens[minter] + 1
         */

        uint accountTokensNew = add_(accountTokens[minter], 1);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        doTransferIn(minter, tokenId);

        // Erc721Enumerable
        _addTokenToOwnerEnumeration(minter, tokenId);
        _addTokenToAllTokensEnumeration(tokenId);

        // We write previously calculated values into storage
        accountTokens[minter] = accountTokensNew;
        tokensOwners[tokenId] = minter;

        // We emit a Mint event, and a Transfer event
        emit Mint(minter, tokenId);
        emit Transfer(address(0), minter, tokenId);

        // We call the defense hook
        comptroller.mintNFTVerify(address(this), minter, tokenId);

        return Error.NO_ERROR;
    }

    /**
     * @notice Sender redeems pTokens in exchange for the underlying asset
     * @param tokenId The token ID
     */
    function redeem(uint tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "caller is not owner");
        return redeemInternal(tokenId);
    }

    /**
     * @notice Sender redeems pTokens in exchange for the underlying asset
     * @param tokenId The token ID
     */
    function redeemInternal(uint tokenId) internal nonReentrant {
        address owner = ownerOf(tokenId);

        // Fail if redeem not allowed
        Error allowed = comptroller.redeemNFTAllowed(address(this), owner, tokenId);
        require(allowed == Error.NO_ERROR, "redeem comptroller rejection");

        // Burn PNFTToken
        burnInternal(tokenId);

        // We invoke doTransferOut for the owner
        doTransferOut(owner, tokenId);

        emit Redeem(owner, tokenId);

        // We call the defense hook
        comptroller.redeemNFTVerify(address(this), owner, tokenId);
    }

    function burnInternal(uint tokenId) internal {
        address owner = ownerOf(tokenId);

        /*
         * We calculate the new owner balance, checking for underflow:
         *  accountTokensNew = accountTokens[owner] - 1
         */

        uint accountTokensNew = sub_(accountTokens[owner], 1);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // Clear approvals from the previous owner
        approveInternal(address(0), tokenId);

        // Erc721Enumerable
        _removeTokenFromOwnerEnumeration(owner, tokenId);
        ownedTokensIndex[tokenId] = 0;
        _removeTokenFromAllTokensEnumeration(tokenId);

        // We write previously calculated values into storage
        accountTokens[owner] = accountTokensNew;
        tokensOwners[tokenId] = address(0);

        // We emit a Transfer event, and a Redeem event
        emit Transfer(owner, address(0), tokenId);
    }

    /*** Liquidation ***/

    function liquidateCollateral(address borrower, uint tokenId, address NFTLiquidationExchangePTokenAddress) external returns (Error) {
        return liquidateCollateralInternal(msg.sender, borrower, tokenId, NFTLiquidationExchangePTokenAddress, false);
    }

    function liquidateSeizeCollateral(address borrower, uint tokenId, address NFTLiquidationExchangePTokenAddress) external returns (Error) {
        return liquidateCollateralInternal(msg.sender, borrower, tokenId, NFTLiquidationExchangePTokenAddress, true);
    }

    function liquidateCollateralInternal(address liquidator, address borrower, uint tokenId, address NFTLiquidationExchangePTokenAddress, bool isLiquidatorSeize) internal nonReentrant returns (Error) {
        require(ownerOf(tokenId) == borrower, "incorrect borrower");
        require(borrower != liquidator, "invalid account pair");

        // Fail if liquidateCollateral not allowed
        Error allowed = comptroller.liquidateNFTCollateralAllowed(address(this), liquidator, borrower, tokenId, NFTLiquidationExchangePTokenAddress);
        if (allowed != Error.NO_ERROR) {
            return fail(allowed);
        }

        // double-check...
        (, , uint beforeLiquidityShortfall) = comptroller.getAccountLiquidity(borrower);

        // liquidate collateral
        liquidateCollateralInternalImpl(liquidator, borrower, tokenId, PErc20Interface(NFTLiquidationExchangePTokenAddress), isLiquidatorSeize);

        // ...double-check
        (, , uint liquidityShortfall) = comptroller.getAccountLiquidity(borrower);
        // sanity check
        require(beforeLiquidityShortfall >= liquidityShortfall, "invalid liquidity after the exchange");

        // We emit a LiquidateCollateral event
        emit LiquidateCollateral(liquidator, borrower, tokenId, NFTLiquidationExchangePTokenAddress);

        // We call the defense hook
        comptroller.liquidateNFTCollateralVerify(address(this), liquidator, borrower, tokenId);

        return Error.NO_ERROR;
    }

    function liquidateCollateralInternalImpl(address liquidator, address borrower, uint tokenId, PErc20Interface NFTLiquidationExchangePToken, bool isLiquidatorSeize) internal {
        (uint minAmountToReceiveOnExchange, uint liquidationIncentive, uint pbxBonusIncentive,  uint seizeValueToReceive) = comptroller.nftLiquidateCalculateValues(address(this), tokenId, address(NFTLiquidationExchangePToken));

        if (isLiquidatorSeize) { // sell underlying NFT to liquidator
            require(seizeValueToReceive > 0, "NFT seize liquidation not configured");
            _exchangeUnderlying(borrower, tokenId, seizeValueToReceive, liquidationIncentive, liquidator, true, NFTLiquidationExchangePToken);
        } else { // exchange underlying NFT for NFTLiquidationExchangePToken
            assert(minAmountToReceiveOnExchange > 0);
            _exchangeUnderlying(borrower, tokenId, minAmountToReceiveOnExchange, liquidationIncentive, liquidator, false, NFTLiquidationExchangePToken);
        }

        // send liquidation incentive
        // approve already called in _exchangeUnderlying
        if (liquidationIncentive > 0) {
            uint exchangePTokenBalanceBefore = NFTLiquidationExchangePToken.balanceOf(address(this));
            require(NFTLiquidationExchangePToken.mint(liquidationIncentive) == Error.NO_ERROR, "NFTLiquidationExchangePToken mint incentive failed");
            require(NFTLiquidationExchangePToken.transfer(liquidator, NFTLiquidationExchangePToken.balanceOf(address(this)) - exchangePTokenBalanceBefore), "NFTLiquidationExchangePToken transfer incentive failed");
        }

        // send PBX bonus liquidation incentive
        comptroller.nftLiquidateSendPBXBonusIncentive(pbxBonusIncentive, liquidator);
    }

    /// @dev Exchange underlying NFT token for NFTLiquidationExchangePToken within owner's collateral
    function _exchangeUnderlying(address owner, uint tokenId, uint minAmountToReceive, uint liquidationIncentive, address liquidator, bool isLiquidatorSeize, PErc20Interface NFTLiquidationExchangePToken) internal {
        assert(ownerOf(tokenId) == owner);
        assert(minAmountToReceive > 0);
        // sanity check
        require(minAmountToReceive > liquidationIncentive, "liquidateCollateral not possible");

        IERC20 NFTLiquidationExchangeToken = IERC20(NFTLiquidationExchangePToken.underlying());
        uint exchangeTokenBalanceBefore = NFTLiquidationExchangeToken.balanceOf(address(this));

        // burn pNFTToken
        burnInternal(tokenId);

        if (isLiquidatorSeize) { // sell underlying NFT to liquidator
            _sellUnderlyingToLiquidator(tokenId, minAmountToReceive, liquidator, address(NFTLiquidationExchangeToken));

        } else { // exchange underlying NFT for NFTLiquidationExchangePToken
            if (comptroller.NFTXioMarketplaceZapAddress() != address(0) && NFTXioVaultId >= 0) { // NFTXio liquidation set
                _sellUnderlyingOnNFTXio(tokenId, minAmountToReceive, address(NFTLiquidationExchangeToken));

            } else {
                require(comptroller.sudoswapRouterAddress() != address(0) && sudoswapLSSVMPairAddress != address(0) && // sudoswap liquidation set
                        comptroller.uniswapV3SwapRouterAddress() != address(0), "NFT liquidation not configured");

                uint ethAmountReceived = _sellUnderlyingOnSudoswapForETH(tokenId, 0);
                _exchangeEthForTokensOnUniswap(address(NFTLiquidationExchangeToken), minAmountToReceive, ethAmountReceived);
            }
        }

        // address(this) has NFTLiquidationExchangeToken now
        uint amountReceived = NFTLiquidationExchangeToken.balanceOf(address(this)) - exchangeTokenBalanceBefore;
        require(amountReceived >= minAmountToReceive, "incorrect amount received");

        // exchange NFTLiquidationExchangeToken for its PToken
        NFTLiquidationExchangeToken.safeApprove(address(NFTLiquidationExchangePToken), 0);
        NFTLiquidationExchangeToken.safeApprove(address(NFTLiquidationExchangePToken), amountReceived);
        uint exchangePTokenBalanceBefore = NFTLiquidationExchangePToken.balanceOf(address(this));
        require(NFTLiquidationExchangePToken.mint(amountReceived - liquidationIncentive) == Error.NO_ERROR, "NFTLiquidationExchangePToken mint failed");

        // transfer NFTLiquidationExchangePToken to owner's collateral
        require(NFTLiquidationExchangePToken.transfer(owner, NFTLiquidationExchangePToken.balanceOf(address(this)) - exchangePTokenBalanceBefore), "NFTLiquidationExchangePToken transfer to owner failed");
    }

    function _concatBytes(bytes memory a, bytes memory b) internal pure returns (bytes memory c) {
        uint alen = a.length;
        uint totallen = alen + b.length;
        uint loopsa = (a.length + 31) / 32;
        uint loopsb = (b.length + 31) / 32;

        assembly {
            let m := mload(0x40)
            mstore(m, totallen)
            for {  let i := 0 } lt(i, loopsa) { i := add(1, i) } { mstore(add(m, mul(32, add(1, i))), mload(add(a, mul(32, add(1, i))))) }
            for {  let i := 0 } lt(i, loopsb) { i := add(1, i) } { mstore(add(m, add(mul(32, add(1, i)), alen)), mload(add(b, mul(32, add(1, i))))) }
            mstore(0x40, add(m, add(32, totallen)))
            c := m
        }
    }

    function _callSudoswapSwap(uint tokenId, uint minAmountETHToReceive) internal {
        bytes memory encodedSig = abi.encodePacked(
            bytes4(0xec72bc65),               // swap function signature
            _concatBytes(                     // function arguments
                abi.encodePacked(uint256(32),
                                 uint256(160),
                                 uint256(192),
                                 uint256(address(this)), // tokenRecipient
                                 uint256(address(this)), // nftRecipient
                                 uint256(0),  // recycleEth
                                 uint256(0),
                                 uint256(1),
                                 uint256(32),
                                 uint256(sudoswapLSSVMPairAddress), // pair
                                 uint256(1),  // isETHSell
                                 uint256(1)), // isERC721
                abi.encodePacked(uint256(288),
                                 uint256(0),  // doPropertyCheck
                                 uint256(352),
                                 uint256(0),  // expectedSpotPrice
                                 uint256(minAmountETHToReceive), // minExpectedOutput
                                 uint256(384),
                                 uint256(1),
                                 uint256(tokenId),
                                 uint256(0),
                                 uint256(1),
                                 uint256(minAmountETHToReceive)) // minExpectedOutputPerNumNFTs
            )
        );

        (bool success, bytes memory returnData) = comptroller.sudoswapRouterAddress().call(encodedSig);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
    }

    function _sellUnderlyingOnSudoswapForETH(uint tokenId, uint minAmountETHToReceive) internal returns (uint) {
        uint256 balanceBefore = address(this).balance;

        approveUnderlying(tokenId, comptroller.sudoswapRouterAddress());
        _callSudoswapSwap(tokenId, minAmountETHToReceive);

        uint amountReceived = address(this).balance - balanceBefore;
        require(amountReceived > minAmountETHToReceive, "sudoswap: too little ETH amount received");
        return amountReceived;
    }

    function _exchangeEthForTokensOnUniswap(address assetToReceive, uint minAmountToReceive, uint amountToSell) internal {
        IUniswapV3SwapRouter router = IUniswapV3SwapRouter(comptroller.uniswapV3SwapRouterAddress());

        IUniswapV3SwapRouter.ExactInputSingleParams memory swapParams;
        swapParams.tokenIn = router.WETH9();
        swapParams.tokenOut = assetToReceive;
        swapParams.fee = 500;
        swapParams.recipient = address(this);
        swapParams.deadline = block.timestamp;
        swapParams.amountIn = amountToSell;
        swapParams.amountOutMinimum = minAmountToReceive;
        swapParams.sqrtPriceLimitX96 = 0; // 0 to ensure we swap our exact input amount

        router.exactInputSingle.value(amountToSell)(swapParams);
    }

    function _sellUnderlyingToLiquidator(uint tokenId, uint amountToReceive, address liquidator, address assetToReceive) internal {
        IERC20(assetToReceive).safeTransferFrom(liquidator, address(this), amountToReceive);
        doTransferOut(liquidator, tokenId);
    }

    function _sellUnderlyingOnNFTXio(uint tokenId, uint minAmountToReceive, address assetToReceive) internal {
        INFTXMarketplaceZap NFTXioMarketplace = INFTXMarketplaceZap(comptroller.NFTXioMarketplaceZapAddress());

        // sell underlying for NFTLiquidationExchangeToken
        address[] memory path = new address[](3);
        path[0] = NFTXioMarketplace.nftxFactory().vault(uint(NFTXioVaultId));
        path[1] = NFTXioMarketplace.WETH();
        path[2] = assetToReceive;

        uint[] memory ids = new uint[](1);
        ids[0] = tokenId;

        approveUnderlying(tokenId, address(NFTXioMarketplace));
        NFTXioMarketplace.mintAndSell721WETH(uint(NFTXioVaultId), ids, minAmountToReceive, path, address(this));
    }

    /*** Admin Functions ***/

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      */
    function _setPendingAdmin(address payable newPendingAdmin) external {
        require(msg.sender == admin, "only admin");
        require(newPendingAdmin != address(0), "admin cannot be zero address");

        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);
        pendingAdmin = newPendingAdmin;
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      */
    function _acceptAdmin() external {
        require(msg.sender == pendingAdmin, "only pending admin");

        emit NewAdmin(admin, pendingAdmin);
        emit NewPendingAdmin(pendingAdmin, address(0));
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    /**
      * @notice Sets a new comptroller for the market
      * @dev Admin function to set a new comptroller
      */
    function _setComptroller(address newComptroller) public {
        require(msg.sender == admin, "only admin");
        (bool success, ) = newComptroller.staticcall(abi.encodeWithSignature("isComptroller()"));
        require(success, "not valid comptroller address");

        emit NewComptroller(address(comptroller), newComptroller);
        comptroller = ComptrollerNFTInterface(newComptroller);
    }

    function _setNFTXioVaultId(int newNFTXioVaultId) external {
        require(msg.sender == admin, "only admin");
        require(INFTXVault(INFTXMarketplaceZap(comptroller.NFTXioMarketplaceZapAddress()).nftxFactory().vault(uint(newNFTXioVaultId))).assetAddress() == underlying, "wrong NFTXVaultId");

        NFTXioVaultId = newNFTXioVaultId;
    }

    function _setSudoswapLSSVMPairAddress(address newSudoswapLSSVMPairAddress) external {
        require(msg.sender == admin, "only admin");
        require(SudoswapLSSVMPairETHInterface(newSudoswapLSSVMPairAddress).nft() == underlying, "wrong newSudoswapLSSVMPairAddress.nft()");

        sudoswapLSSVMPairAddress = newSudoswapLSSVMPairAddress;
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying owned by this contract
     */
    function getCashPrior() internal view returns (uint);

    function checkIfOwnsUnderlying(uint tokenId) internal view returns (bool);

    function approveUnderlying(uint tokenId, address addr) internal;

    /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     *  This may revert due to insufficient balance or insufficient allowance.
     */
    function doTransferIn(address from, uint tokenId) internal;

    /**
     * @dev Performs a transfer out, ideally returning an explanatory error code upon failure rather than reverting.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     */
    function doTransferOut(address to, uint tokenId) internal;

    /// @dev Prevents a contract from calling itself, directly or indirectly.
    modifier nonReentrant() {
        require(_notEntered, "reentered");
        _notEntered = false;
        _;
        _notEntered = true;
        // get a gas-refund post-Istanbul
    }
}

// contracts/PNFTToken/PNFTTokenInterfaces.sol

contract PNFTTokenDelegationStorage {
    /// @notice Implementation address for this contract
    address public implementation;

    /// @notice Administrator for this contract
    address payable public admin;

    /// @notice Pending administrator for this contract
    address payable public pendingAdmin;
}

contract PNFTTokenDelegatorInterface is PNFTTokenDelegationStorage {
    /// @notice Emitted when implementation is changed
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param newImplementation The address of the new implementation for delegation
     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(address newImplementation, bool allowResign, bytes memory becomeImplementationData) public;
}

contract PNFTTokenStorage is PNFTTokenDelegationStorage {
    /// @dev Guard variable for reentrancy checks
    bool internal _notEntered;

    /// @notice EIP-721 token name for this token
    string public name;

    /// @notice EIP-721 token symbol for this token
    string public symbol;

    /// @notice Contract which oversees inter-PNFTToken operations
    ComptrollerNFTInterface public comptroller;

    /// @notice Mapping from token ID to owner address
    mapping(uint => address) internal tokensOwners;

    /// @notice Mapping owner address to token count
    mapping(address => uint) internal accountTokens;

    /// @notice Mapping from token ID to approved address
    mapping(uint => address) internal transferAllowances;

    /// @notice Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) internal operatorApprovals;

    /// @notice Mapping from owner to list of owned token IDs
    mapping(address => uint[]) internal ownedTokens;

    /// @notice Mapping from token ID to index of the owner tokens list
    mapping(uint => uint) internal ownedTokensIndex;

    /// @notice Array with all token ids, used for enumeration
    uint[] internal allTokens;

    /// @notice Mapping from token id to position in the allTokens array
    mapping(uint => uint) internal allTokensIndex;

    /// @notice Underlying asset for this PNFTToken
    address public underlying;

    int public NFTXioVaultId;

    address public sudoswapLSSVMPairAddress; // underlying NFT -> ETH pool
}

contract PNFPStorage {
    mapping(address=>bool) public whitelistedPools;
}

contract PNFTTokenInterface is ErrorReporter, PNFTTokenStorage {
    /// @notice Indicator that this is a PNFTToken contract (for inspection)
    bool public constant isPNFTToken = true;

    /*** Market Events ***/

    /// @notice Event emitted when tokens are minted
    event Mint(address indexed minter, uint indexed tokenId);

    /// @notice Event emitted when tokens are redeemed
    event Redeem(address indexed redeemer, uint indexed tokenId);

    /// @notice Event emitted when borrower's collateral is liquidated
    event LiquidateCollateral(address indexed liquidator, address indexed borrower, uint indexed tokenId, address NFTLiquidationExchangePToken);

    /*** Admin Events ***/

    /// @notice Event emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Event emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Event emitted when comptroller is changed
    event NewComptroller(address oldComptroller, address newComptroller);

    /// @notice Event emitted when the reserve factor is changed
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);

    /// @notice EIP721 Transfer event
    event Transfer(address indexed from, address indexed to, uint indexed tokenId);

    /// @notice EIP721 Approval event
    event Approval(address indexed owner, address indexed approved, uint indexed tokenId);

    /// @notice EIP721 ApprovalForAll event
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /// @notice Event emitted when pool address is whitelisted for pnfp markets
    event WhitelistedPool(address indexed poolAddress, bool isWhitelisted);

    /*** ERC165 Functions ***/

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /*** EIP721 Functions ***/

    function transferFrom(address src, address dst, uint tokenId) external;
    function safeTransferFrom(address src, address dst, uint tokenId, bytes memory data) public;
    function safeTransferFrom(address src, address dst, uint tokenId) external;
    function approve(address to, uint tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function getApproved(uint tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function balanceOf(address owner) external view returns (uint);
    function ownerOf(uint tokenId) external view returns (address);
    function tokenOfOwnerByIndex(address owner, uint index) external view returns (uint);
    function totalSupply() public view returns (uint);
    function tokenByIndex(uint index) public view returns (uint);

    /*** User Interface ***/

    function balanceOfUnderlying(address owner) external view returns (uint);
    function getCash() external view returns (uint);
    function liquidateCollateral(address borrower, uint tokenId, address NFTLiquidationExchangePTokenAddress) external returns (Error);
    function liquidateSeizeCollateral(address borrower, uint tokenId, address NFTLiquidationExchangePTokenAddress) external returns (Error);
    function mint(uint tokenId) external returns (Error);
    function safeMint(uint tokenId) external returns (Error);
    function safeMint(uint tokenId, bytes calldata data) external returns (Error);
    function redeem(uint tokenId) external;

    /*** Admin Functions ***/

    function _setPendingAdmin(address payable newPendingAdmin) external;
    function _acceptAdmin() external;
    function _setComptroller(address newComptroller) public;
    function _setNFTXioVaultId(int newNFTXioVaultId) external;
    function _setSudoswapLSSVMPairAddress(address newSudoswapLSSVMPairAddress) external;
}

contract PErc721Interface is PNFTTokenInterface, IERC721Receiver { }

contract PNFTTokenDelegateInterface is PNFTTokenInterface {
    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @dev Should revert if any issues arise which make it unfit for delegation
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes calldata data) external;

    /// @notice Called by the delegator on a delegate to forfeit its responsibility
    function _resignImplementation() external;
}

// contracts/PToken/PToken.sol

/**
 * @title Paribus PToken Contract
 * @notice Abstract base for PTokens
 * @author Compound, Paribus
 */
contract PToken is PTokenInterface, ExponentialNoError {
    /**
     * @notice Initialize the money market
     * @param comptroller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ EIP-20 name of this token
     * @param symbol_ EIP-20 symbol of this token
     * @param decimals_ EIP-20 decimal precision of this token
     */
    function initialize(address comptroller_,
                        InterestRateModelInterface interestRateModel_,
                        uint initialExchangeRateMantissa_,
                        string memory name_,
                        string memory symbol_,
                        uint8 decimals_) public {
        require(msg.sender == admin, "only admin may initialize the market");
        require(accrualBlockNumber == 0 && borrowIndex == 0, "market may only be initialized once");

        // Set initial exchange rate
        initialExchangeRateMantissa = initialExchangeRateMantissa_;
        require(initialExchangeRateMantissa > 0, "initial exchange rate must be greater than zero");

        // Set the comptroller
        _setComptroller(comptroller_);

        // Initialize block number and borrow index (block number mocks depend on comptroller being set)
        accrualBlockNumber = getBlockNumber();
        borrowIndex = mantissaOne;

        // Set the interest rate model (depends on block number / borrow index)
        _setInterestRateModelFresh(interestRateModel_);

        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        protocolSeizeShareMantissa = 5e16; // default 5%;  0% == disabled

        // The counter starts true to prevent changing it from zero to non-zero (i.e. smaller cost/refund)
        _notEntered = true;
    }

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
     * @dev Called by both `transfer` and `transferFrom` internally
     * @param spender The address of the account performing the transfer
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokens The number of tokens to transfer
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function transferTokens(address spender, address src, address dst, uint tokens) internal returns (Error) {
        require(src != dst, "invalid account pair");
        require(dst != address(0), "invalid dst param");
        
        // Fail if transfer not allowed
        Error allowed = comptroller.transferAllowed(address(this), src, dst, tokens);
        if (allowed != Error.NO_ERROR) {
            return fail(allowed);
        }

        // Get the allowance, infinite for the account owner
        uint startingAllowance = 0;
        if (spender == src) {
            startingAllowance = uint(-1);
        } else {
            startingAllowance = transferAllowances[src][spender];
        }

        // Do the calculations, checking for {under,over}flow
        uint allowanceNew = sub_(startingAllowance, tokens, "allowance not enough");
        uint srcTokensNew = sub_(accountTokens[src], tokens, "balance not enough");
        uint dstTokensNew = add_(accountTokens[dst], tokens);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        accountTokens[src] = srcTokensNew;
        accountTokens[dst] = dstTokensNew;

        // Eat some of the allowance (if necessary)
        if (startingAllowance != uint(-1)) {
            transferAllowances[src][spender] = allowanceNew;
        }

        // We emit a Transfer event
        emit Transfer(src, dst, tokens);

        // We call the defense hook
        comptroller.transferVerify(address(this), src, dst, tokens);

        return Error.NO_ERROR;
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint amount) external nonReentrant returns (bool) {
        return transferTokens(msg.sender, msg.sender, dst, amount) == Error.NO_ERROR;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint amount) external nonReentrant returns (bool) {
        return transferTokens(msg.sender, src, dst, amount) == Error.NO_ERROR;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint amount) external returns (bool) {
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent (-1 means infinite)
     */
    function allowance(address owner, address spender) external view returns (uint) {
        return transferAllowances[owner][spender];
    }

    /**
     * @notice Get the token balance of the `owner`
     * @param owner The address of the account to query
     * @return The number of tokens owned by `owner`
     */
    function balanceOf(address owner) external view returns (uint) {
        return accountTokens[owner];
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @dev Accrues interest unless reverted
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) external returns (uint) {
        Exp memory exchangeRate = Exp({mantissa: exchangeRateCurrent()});
        return mul_ScalarTruncate(exchangeRate, accountTokens[owner]);
    }

    /**
     * @notice Get the underlying balance of the `owner` based on stored data
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`, with no interest accrued
     */
    function balanceOfUnderlyingStored(address owner) external view returns (uint) {
        Exp memory exchangeRate = Exp({mantissa: exchangeRateStored()});
        return mul_ScalarTruncate(exchangeRate, accountTokens[owner]);
    }

    /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address account) external view returns (uint, uint, uint) {
        return (accountTokens[account],
                borrowBalanceStoredInternal(account),
                exchangeRateStoredInternal());
    }

    /**
     * @dev Function to simply retrieve block number
     *  This exists mainly for inheriting test contracts to stub this result.
     */
    function getBlockNumber() internal view returns (uint) {
        return block.number;
    }

    /**
     * @notice Returns the current per-block borrow interest rate for this pToken
     * @return The borrow interest rate per block, scaled by 1e18
     */
    function borrowRatePerBlock() external view returns (uint) {
        return interestRateModel.getBorrowRate(getCashPrior(), totalBorrows, totalReserves);
    }

    /**
     * @notice Returns the current per-block supply interest rate for this pToken
     * @return The supply interest rate per block, scaled by 1e18
     */
    function supplyRatePerBlock() external view returns (uint) {
        return interestRateModel.getSupplyRate(getCashPrior(), totalBorrows, totalReserves, reserveFactorMantissa);
    }

    /**
     * @notice Returns the current total borrows plus accrued interest
     * @return The total borrows with interest
     */
    function totalBorrowsCurrent() external nonReentrant returns (uint) {
        accrueInterest();
        return totalBorrows;
    }

    /**
     * @notice Accrue interest to updated borrowIndex and then calculate account's borrow balance using the updated borrowIndex
     * @param account The address whose balance should be calculated after updating borrowIndex
     * @return The calculated balance
     */
    function borrowBalanceCurrent(address account) external nonReentrant returns (uint) {
        accrueInterest();
        return borrowBalanceStored(account);
    }

    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return The calculated balance
     */
    function borrowBalanceStored(address account) public view returns (uint) {
        return borrowBalanceStoredInternal(account);
    }

    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return the calculated balance
     */
    function borrowBalanceStoredInternal(address account) internal view returns (uint) {
        // Get borrowBalance and borrowIndex
        // Note: we do not assert that the market is up to date
        BorrowSnapshot storage borrowSnapshot = accountBorrows[account];

        /* If borrowBalance = 0 then borrowIndex is likely also 0.
         * Rather than failing the calculation with a division by 0, we immediately return 0 in this case.
         */
        if (borrowSnapshot.principal == 0) {
            return 0;
        }

        /* Calculate new borrow balance using the interest index:
         *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
         */
        uint principalTimesIndex = mul_(borrowSnapshot.principal, borrowIndex);
        return div_(principalTimesIndex, borrowSnapshot.interestIndex);
    }

    /**
     * @notice Accrue interest then return the up-to-date exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateCurrent() public nonReentrant returns (uint) {
        accrueInterest();
        return exchangeRateStored();
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the PToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateStored() public view returns (uint) {
        return exchangeRateStoredInternal();
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the PToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return calculated exchange rate scaled by 1e18
     */
    function exchangeRateStoredInternal() internal view returns (uint) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            /*
             * If there are no tokens minted:
             *  exchangeRate = initialExchangeRate
             */
            return initialExchangeRateMantissa;
        } else {
            /*
             * Otherwise:
             *  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
             */
            uint totalCash = getCashPrior();
            uint cashPlusBorrowsMinusReserves = sub_(add_(totalCash, totalBorrows), totalReserves);
            return getExp_(cashPlusBorrowsMinusReserves, _totalSupply);
        }
    }

    /// @notice Get live borrow index, including interest rates
    function getRealBorrowIndex() external view returns (uint) {
        uint currentBlockNumber = getBlockNumber();
        uint accrualBlockNumberPrior = accrualBlockNumber;

        // Short-circuit accumulating 0 interest
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return borrowIndex;
        }

        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        require(borrowRateMantissa <= borrowRateMaxMantissa, "borrow rate is absurdly high");

        uint blockDelta = sub_(currentBlockNumber, accrualBlockNumberPrior);

        Exp memory simpleInterestFactor = mul_(Exp({mantissa: borrowRateMantissa}), blockDelta);
        uint borrowIndexNew = mul_ScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);

        return borrowIndexNew;
    }

    /**
     * @notice Get cash balance of this pToken in the underlying asset
     * @return The quantity of underlying asset owned by this contract
     */
    function getCash() external view returns (uint) {
        return getCashPrior();
    }

    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed block up to the current block and writes new checkpoint to storage.
     */
    function accrueInterest() public {
        uint currentBlockNumber = getBlockNumber();
        uint accrualBlockNumberPrior = accrualBlockNumber;

        // Short-circuit accumulating 0 interest
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return;
        }

        // Read the previous values out of storage
        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        // Calculate the current borrow interest rate
        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        require(borrowRateMantissa <= borrowRateMaxMantissa, "borrow rate is absurdly high");

        // Calculate the number of blocks elapsed since the last accrual
        uint blockDelta = sub_(currentBlockNumber, accrualBlockNumberPrior);

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */
        Exp memory simpleInterestFactor = mul_(Exp({mantissa: borrowRateMantissa}), blockDelta);
        uint interestAccumulated = mul_ScalarTruncate(simpleInterestFactor, borrowsPrior);
        uint totalBorrowsNew = add_(interestAccumulated, borrowsPrior);
        uint totalReservesNew = mul_ScalarTruncateAddUInt(Exp({mantissa: reserveFactorMantissa}), interestAccumulated, reservesPrior);
        uint borrowIndexNew = mul_ScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // We write the previously calculated values into storage
        accrualBlockNumber = currentBlockNumber;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;

        // We emit an AccrueInterest event
        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
    }

    /**
     * @notice Sender supplies assets into the market and receives pTokens in exchange
     * @dev Accrues interest unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return (Error, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function mintInternal(uint mintAmount) internal nonReentrant returns (Error, uint) {
        accrueInterest();

        // mintFresh emits the actual Mint event if successful and logs on errors, so we don't need to
        return mintFresh(msg.sender, mintAmount);
    }

    struct MintLocalVars {
        Error err;
        uint exchangeRateMantissa;
        uint mintTokens;
        uint totalSupplyNew;
        uint accountTokensNew;
        uint actualMintAmount;
    }

    /**
     * @notice User supplies assets into the market and receives pTokens in exchange
     * @dev Assumes interest has already been accrued up to the current block
     * @param minter The address of the account which is supplying the assets
     * @param mintAmount The amount of the underlying asset to supply
     * @return (Error, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual mint amount.
     */
    function mintFresh(address minter, uint mintAmount) internal returns (Error, uint) {
        // Fail if mint not allowed
        Error allowed = comptroller.mintAllowed(address(this), minter, mintAmount);
        if (allowed != Error.NO_ERROR) {
            return (fail(allowed), 0);
        }

        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        MintLocalVars memory vars;
        vars.exchangeRateMantissa = exchangeRateStoredInternal();

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         *  We call `doTransferIn` for the minter and the mintAmount.
         *  Note: The pToken must handle variations between ERC-20 and ETH underlying.
         *  `doTransferIn` reverts if anything goes wrong, since we can't be sure if
         *  side-effects occurred. The function returns the amount actually transferred,
         *  in case of a fee. On success, the pToken holds an additional `actualMintAmount`
         *  of cash.
         */
        vars.actualMintAmount = doTransferIn(minter, mintAmount);

        /*
         * We get the current exchange rate and calculate the number of pTokens to be minted:
         *  mintTokens = actualMintAmount / exchangeRate
         */
        vars.mintTokens = div_(vars.actualMintAmount, Exp({mantissa: vars.exchangeRateMantissa}));

        /*
         * We calculate the new total supply of pTokens and minter token balance, checking for overflow:
         *  totalSupplyNew = totalSupply + mintTokens
         *  accountTokensNew = accountTokens[minter] + mintTokens
         */
        vars.totalSupplyNew = add_(totalSupply, vars.mintTokens);

        if (totalSupply == 0 && MINIMUM_LIQUIDITY > 0) {
            // first minter gets MINIMUM_LIQUIDITY pTokens less
            vars.mintTokens = sub_(vars.mintTokens, MINIMUM_LIQUIDITY, "first mint not enough");

            // permanently lock the first MINIMUM_LIQUIDITY tokens
            accountTokens[address(0)] = MINIMUM_LIQUIDITY;

            // we dont emit any Transfer, Mint events for that
        }

        vars.accountTokensNew = add_(accountTokens[minter], vars.mintTokens);

        // We write previously calculated values into storage
        totalSupply = vars.totalSupplyNew;
        accountTokens[minter] = vars.accountTokensNew;

        // We emit a Mint event and a Transfer event
        emit Mint(minter, vars.actualMintAmount, vars.mintTokens);
        emit Transfer(address(0), minter, vars.mintTokens);

        // We call the defense hook
        comptroller.mintVerify(address(this), minter, vars.actualMintAmount, vars.mintTokens);

        return (Error.NO_ERROR, vars.actualMintAmount);
    }

    /**
     * @notice Sender redeems pTokens in exchange for the underlying asset
     * @dev Accrues interest unless reverted
     * @param redeemTokens The number of pTokens to redeem into underlying
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemInternal(uint redeemTokens) internal nonReentrant returns (Error) {
        accrueInterest();

        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        return redeemFresh(msg.sender, redeemTokens, 0);
    }

    /**
     * @notice Sender redeems pTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest unless reverted
     * @param redeemAmount The amount of underlying to receive from redeeming pTokens
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemUnderlyingInternal(uint redeemAmount) internal nonReentrant returns (Error) {
        accrueInterest();

        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        return redeemFresh(msg.sender, 0, redeemAmount);
    }

    struct RedeemLocalVars {
        Error err;
        uint exchangeRateMantissa;
        uint redeemTokens;
        uint redeemAmount;
        uint totalSupplyNew;
        uint accountTokensNew;
    }

    /**
     * @notice User redeems pTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current block
     * @param redeemer The address of the account which is redeeming the tokens
     * @param redeemTokensIn The number of pTokens to redeem into underlying (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @param redeemAmountIn The number of underlying tokens to receive from redeeming pTokens (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemFresh(address payable redeemer, uint redeemTokensIn, uint redeemAmountIn) internal returns (Error) {
        require(redeemTokensIn == 0 || redeemAmountIn == 0, "one of redeemTokensIn or redeemAmountIn must be zero");

        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        RedeemLocalVars memory vars;

        // exchangeRate = invoke Exchange Rate Stored()
        vars.exchangeRateMantissa = exchangeRateStoredInternal();

        // If redeemTokensIn > 0:
        if (redeemTokensIn > 0) {
            /*
             * We calculate the exchange rate and the amount of underlying to be redeemed:
             *  redeemTokens = redeemTokensIn
             *  redeemAmount = redeemTokensIn x exchangeRateCurrent
             */
            vars.redeemTokens = redeemTokensIn;
            vars.redeemAmount = mul_ScalarTruncate(Exp({mantissa: vars.exchangeRateMantissa}), redeemTokensIn);
        } else {
            /*
             * We get the current exchange rate and calculate the amount to be redeemed:
             *  redeemTokens = redeemAmountIn / exchangeRate
             *  redeemAmount = redeemAmountIn
             */

            vars.redeemTokens = div_(redeemAmountIn, Exp({mantissa: vars.exchangeRateMantissa}));
            vars.redeemAmount = redeemAmountIn;
        }

        // Fail if redeem not allowed
        Error allowed = comptroller.redeemAllowed(address(this), redeemer, vars.redeemTokens);
        if (allowed != Error.NO_ERROR) {
            return fail(allowed);
        }

        // Fail gracefully if protocol has insufficient cash
        if (getCashPrior() < vars.redeemAmount) {
            return fail(Error.TOKEN_INSUFFICIENT_CASH);
        }

        /*
         * We calculate the new total supply and redeemer balance, checking for underflow:
         *  totalSupplyNew = totalSupply - redeemTokens
         *  accountTokensNew = accountTokens[redeemer] - redeemTokens
         */
        vars.totalSupplyNew = sub_(totalSupply, vars.redeemTokens, "redeem too much");
        vars.accountTokensNew = sub_(accountTokens[redeemer], vars.redeemTokens, "redeem too much");

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // We write previously calculated values into storage
        totalSupply = vars.totalSupplyNew;
        accountTokens[redeemer] = vars.accountTokensNew;

        /*
         * We invoke doTransferOut for the redeemer and the redeemAmount.
         *  Note: The pToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the pToken has redeemAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(redeemer, vars.redeemAmount);

        // We emit a Transfer event, and a Redeem event
        emit Transfer(redeemer, address(0), vars.redeemTokens);
        emit Redeem(redeemer, vars.redeemAmount, vars.redeemTokens);

        // We call the defense hook
        comptroller.redeemVerify(address(this), redeemer, vars.redeemAmount, vars.redeemTokens);

        return Error.NO_ERROR;
    }

    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function borrowInternal(uint borrowAmount) internal nonReentrant returns (Error) {
        accrueInterest();

        // borrowFresh emits borrow-specific logs on errors, so we don't need to
        return borrowFresh(msg.sender, borrowAmount);
    }

    struct BorrowLocalVars {
        uint accountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;
    }

    /**
      * @notice Users borrow assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function borrowFresh(address payable borrower, uint borrowAmount) internal returns (Error) {
        // Fail if borrow not allowed
        Error allowed = comptroller.borrowAllowed(address(this), borrower, borrowAmount);
        if (allowed != Error.NO_ERROR) {
            return fail(allowed);
        }

        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        // Fail gracefully if protocol has insufficient underlying cash
        if (getCashPrior() < borrowAmount) {
            return fail(Error.TOKEN_INSUFFICIENT_CASH);
        }

        BorrowLocalVars memory vars;

        /*
         * We calculate the new borrower and total borrow balances, failing on overflow:
         *  accountBorrowsNew = accountBorrows + borrowAmount
         *  totalBorrowsNew = totalBorrows + borrowAmount
         */
        vars.accountBorrows = borrowBalanceStoredInternal(borrower);
        vars.accountBorrowsNew = add_(vars.accountBorrows, borrowAmount);
        vars.totalBorrowsNew = add_(totalBorrows, borrowAmount);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We write the previously calculated values into storage.
         *  Note: Avoid token reentrancy attacks by writing increased borrow before external transfer.
         */
        accountBorrows[borrower].principal = vars.accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        /*
         * We invoke doTransferOut for the borrower and the borrowAmount.
         *  Note: The pToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the pToken borrowAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(borrower, borrowAmount);

        // We emit a Borrow event
        emit Borrow(borrower, borrowAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);

        // We call the defense hook
        comptroller.borrowVerify(address(this), borrower, borrowAmount);

        return Error.NO_ERROR;
    }

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay
     * @return (Error, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayBorrowInternal(uint repayAmount) internal nonReentrant returns (Error, uint) {
        accrueInterest();

        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        return repayBorrowFresh(msg.sender, msg.sender, repayAmount);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     * @param repayAmount The amount to repay
     * @return (Error, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayBorrowBehalfInternal(address borrower, uint repayAmount) internal nonReentrant returns (Error, uint) {
        accrueInterest();

        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        return repayBorrowFresh(msg.sender, borrower, repayAmount);
    }

    struct RepayBorrowLocalVars {
        Error err;
        uint repayAmount;
        uint borrowerIndex;
        uint accountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;
        uint actualRepayAmount;
    }

    /**
     * @notice Borrows are repaid by another user (possibly the borrower).
     * @param payer the account paying off the borrow
     * @param borrower the account with the debt being payed off
     * @param repayAmount the amount of underlying tokens being returned
     * @return (Error, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function repayBorrowFresh(address payer, address borrower, uint repayAmount) internal returns (Error, uint) {
        // Fail if repayBorrow not allowed
        Error allowed = comptroller.repayBorrowAllowed(address(this), payer, borrower, repayAmount);
        if (allowed != Error.NO_ERROR) {
            return (fail(allowed), 0);
        }

        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        RepayBorrowLocalVars memory vars;

        // We remember the original borrowerIndex for verification purposes
        vars.borrowerIndex = accountBorrows[borrower].interestIndex;

        // We fetch the amount the borrower owes, with accumulated interest
        vars.accountBorrows = borrowBalanceStoredInternal(borrower);

        // If repayAmount == -1, repayAmount = accountBorrows
        if (repayAmount == uint(-1)) {
            vars.repayAmount = vars.accountBorrows;
        } else {
            vars.repayAmount = repayAmount;
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We call doTransferIn for the payer and the repayAmount
         *  Note: The pToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the pToken holds an additional repayAmount of cash.
         *  doTransferIn reverts if anything goes wrong, since we can't be sure if side effects occurred.
         *   it returns the amount actually transferred, in case of a fee.
         */
        vars.actualRepayAmount = doTransferIn(payer, vars.repayAmount);

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        vars.accountBorrowsNew = sub_(vars.accountBorrows, vars.actualRepayAmount, "repay too much");
        vars.totalBorrowsNew = sub_(totalBorrows, vars.actualRepayAmount, "repay too much");

        // We write the previously calculated values into storage
        accountBorrows[borrower].principal = vars.accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = vars.totalBorrowsNew;

        // We emit a RepayBorrow event
        emit RepayBorrow(payer, borrower, vars.actualRepayAmount, vars.accountBorrowsNew, vars.totalBorrowsNew);

        // We call the defense hook
        comptroller.repayBorrowVerify(address(this), payer, borrower, vars.actualRepayAmount, vars.borrowerIndex);

        return (Error.NO_ERROR, vars.actualRepayAmount);
    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this pToken to be liquidated
     * @param pTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @return (Error, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function liquidateBorrowInternal(address borrower, uint repayAmount, PTokenInterface pTokenCollateral) internal nonReentrant returns (Error, uint) {
        require(pTokenCollateral.isPToken());

        accrueInterest();
        if (address(pTokenCollateral) != address(this)) {
            pTokenCollateral.accrueInterest();
        }

        // liquidateBorrowFresh emits borrow-specific logs on errors, so we don't need to
        return liquidateBorrowFresh(msg.sender, borrower, repayAmount, pTokenCollateral);
    }

    /**
     * @notice The liquidator liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this pToken to be liquidated
     * @param liquidator The address repaying the borrow and seizing collateral
     * @param pTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @return (Error, uint) An error code (0=success, otherwise a failure, see ErrorReporter.sol), and the actual repayment amount.
     */
    function liquidateBorrowFresh(address liquidator, address borrower, uint repayAmount, PTokenInterface pTokenCollateral) internal returns (Error, uint) {
        require(borrower != liquidator, "invalid account pair");

        // Fail if liquidate not allowed
        Error allowed = comptroller.liquidateBorrowAllowed(address(this), address(pTokenCollateral), liquidator, borrower, repayAmount);
        if (allowed != Error.NO_ERROR) {
            return (fail(allowed), 0);
        }

        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        // Verify pTokenCollateral market's block number equals current block number
        require(pTokenCollateral.accrualBlockNumber() == getBlockNumber(), "pTokenCollateral market not fresh");

        // Fail if repayAmount == -1 or 0
        require(repayAmount != uint(-1) && repayAmount > 0, "invalid argument");

        // Fail if repayBorrow fails
        (Error repayBorrowError, uint actualRepayAmount) = repayBorrowFresh(liquidator, borrower, repayAmount);
        if (repayBorrowError != Error.NO_ERROR) {
            // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
            return (repayBorrowError, 0);
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // We calculate the number of collateral tokens that will be seized
        uint seizeTokens = comptroller.liquidateCalculateSeizeTokens(address(this), address(pTokenCollateral), actualRepayAmount);

        // Revert if borrower collateral token balance < seizeTokens
        require(pTokenCollateral.balanceOf(borrower) >= seizeTokens, "liquidate seize too much");

        // If this is also the collateral, run seizeInternal to avoid reentrancy, otherwise make an external call
        Error seizeError;
        if (address(pTokenCollateral) == address(this)) {
            seizeError = seizeInternal(address(this), liquidator, borrower, seizeTokens);
        } else {
            seizeError = pTokenCollateral.seize(liquidator, borrower, seizeTokens);
        }

        // Revert if seize tokens fails (since we cannot be sure of side effects)
        require(seizeError == Error.NO_ERROR, "token seizure failed");

        // We emit a LiquidateBorrow event
        emit LiquidateBorrow(liquidator, borrower, actualRepayAmount, address(pTokenCollateral), seizeTokens);

        // We call the defense hook
        comptroller.liquidateBorrowVerify(address(this), address(pTokenCollateral), liquidator, borrower, actualRepayAmount, seizeTokens);

        return (Error.NO_ERROR, actualRepayAmount);
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Will fail unless called by another pToken during the process of liquidation.
     *  Its absolutely critical to use msg.sender as the borrowed pToken and not a parameter.
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of pTokens to seize
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function seize(address liquidator, address borrower, uint seizeTokens) external nonReentrant returns (Error) {
        return seizeInternal(msg.sender, liquidator, borrower, seizeTokens);
    }

    struct SeizeInternalLocalVars {
        uint borrowerTokensNew;
        uint liquidatorTokensNew;
        uint liquidatorSeizeTokens;
        uint protocolSeizeTokens;
        uint protocolSeizeAmount;
        uint exchangeRateMantissa;
        uint totalReservesNew;
        uint totalSupplyNew;
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another PToken.
     *  Its absolutely critical to use msg.sender as the seizer pToken and not a parameter.
     * @param seizerToken The contract seizing the collateral (i.e. borrowed pToken)
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of pTokens to seize
     * @return Error 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function seizeInternal(address seizerToken, address liquidator, address borrower, uint seizeTokens) internal returns (Error) {
        require(borrower != liquidator, "invalid account pair");

        // Fail if seize not allowed
        Error allowed = comptroller.seizeAllowed(address(this), seizerToken, liquidator, borrower, seizeTokens);
        if (allowed != Error.NO_ERROR) {
            return fail(allowed);
        }

        SeizeInternalLocalVars memory vars;

        /*
         * We calculate the new borrower and liquidator token balances, failing on underflow/overflow:
         *  borrowerTokensNew = accountTokens[borrower] - seizeTokens
         *  liquidatorTokensNew = accountTokens[liquidator] + seizeTokens
         */
        vars.borrowerTokensNew = sub_(accountTokens[borrower], seizeTokens, "seize too much");
        vars.protocolSeizeTokens = mul_(seizeTokens, Exp({mantissa: protocolSeizeShareMantissa}));
        vars.liquidatorSeizeTokens = sub_(seizeTokens, vars.protocolSeizeTokens, "seize too much");
        vars.exchangeRateMantissa = exchangeRateStoredInternal();
        vars.protocolSeizeAmount = mul_ScalarTruncate(Exp({mantissa: vars.exchangeRateMantissa}), vars.protocolSeizeTokens);
        vars.totalReservesNew = add_(totalReserves, vars.protocolSeizeAmount);
        vars.totalSupplyNew = sub_(totalSupply, vars.protocolSeizeTokens, "seize too much");
        vars.liquidatorTokensNew = add_(accountTokens[liquidator], vars.liquidatorSeizeTokens);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // We write the previously calculated values into storage
        totalReserves = vars.totalReservesNew;
        totalSupply = vars.totalSupplyNew;
        accountTokens[borrower] = vars.borrowerTokensNew;
        accountTokens[liquidator] = vars.liquidatorTokensNew;

        // Emit a Transfer event
        emit Transfer(borrower, liquidator, vars.liquidatorSeizeTokens);
        emit Transfer(borrower, address(this), vars.protocolSeizeTokens);
        emit ReservesAdded(address(this), vars.protocolSeizeAmount, vars.totalReservesNew);

        // We call the defense hook
        comptroller.seizeVerify(address(this), seizerToken, liquidator, borrower, seizeTokens);

        return Error.NO_ERROR;
    }

    /*** Admin Functions ***/

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      */
    function _setPendingAdmin(address payable newPendingAdmin) external {
        onlyAdmin();
        require(newPendingAdmin != address(0), "admin cannot be zero address");

        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);
        pendingAdmin = newPendingAdmin;
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      */
    function _acceptAdmin() external {
        require(msg.sender == pendingAdmin, "only pending admin");

        emit NewAdmin(admin, pendingAdmin);
        emit NewPendingAdmin(pendingAdmin, address(0));
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    /**
      * @notice Sets a new comptroller for the market
      * @dev Admin function to set a new comptroller
      */
    function _setComptroller(address newComptroller) public {
        onlyAdmin();
        (bool success, ) = newComptroller.staticcall(abi.encodeWithSignature("isComptroller()"));
        require(success, "not valid comptroller address");

        emit NewComptroller(address(comptroller), newComptroller);
        comptroller = ComptrollerNoNFTInterface(newComptroller);
    }

    /**
     * @notice Admin function to set the protocolSeizeShareMantissa value
     * @param newProtocolSeizeShareMantissa new protocolSeizeShareMantissa value
     */
    function _setProtocolSeizeShareMantissa(uint newProtocolSeizeShareMantissa) external {
        onlyAdmin();

        require(newProtocolSeizeShareMantissa < 1e18, "invalid argument");

        emit NewProtocolSeizeShareMantissa(protocolSeizeShareMantissa, newProtocolSeizeShareMantissa);
        protocolSeizeShareMantissa = newProtocolSeizeShareMantissa;
    }

    /**
      * @notice accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh
      * @dev Admin function to accrue interest and set a new reserve factor
      */
    function _setReserveFactor(uint newReserveFactorMantissa) external nonReentrant {
        onlyAdmin();
        accrueInterest();

        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        // Check newReserveFactor ≤ maxReserveFactor
        require(newReserveFactorMantissa <= reserveFactorMaxMantissa, "invalid argument");

        emit NewReserveFactor(reserveFactorMantissa, newReserveFactorMantissa);
        reserveFactorMantissa = newReserveFactorMantissa;
    }

    /**
     * @notice Accrues interest and reduces reserves by transferring from msg.sender
     * @param addAmount Amount of addition to reserves
     */
    function _addReservesInternal(uint addAmount) internal nonReentrant {
        accrueInterest();

        // _addReservesFresh emits reserve-addition-specific logs on errors, so we don't need to.
        _addReservesFresh(addAmount);
    }

    /**
     * @notice Add reserves by transferring from caller
     * @dev Requires fresh interest accrual
     * @param addAmount Amount of addition to reserves
     * @return the actual amount added, net token fees
     */
    function _addReservesFresh(uint addAmount) internal returns (uint) {
        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We call doTransferIn for the caller and the addAmount
         *  Note: The pToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the pToken holds an additional addAmount of cash.
         *  doTransferIn reverts if anything goes wrong, since we can't be sure if side effects occurred.
         *  it returns the amount actually transferred, in case of a fee.
         */

        uint actualAddAmount = doTransferIn(msg.sender, addAmount);
        uint totalReservesNew = totalReserves + actualAddAmount;

        // Revert on overflow
        require(totalReservesNew >= totalReserves, "add reserves unexpected overflow");

        // Store reserves[n+1] = reserves[n] + actualAddAmount
        totalReserves = totalReservesNew;

        emit ReservesAdded(msg.sender, actualAddAmount, totalReservesNew);
        return actualAddAmount;
    }

    /**
     * @notice Accrues interest and reduces reserves by transferring to admin
     * @param reduceAmount Amount of reduction to reserves
     */
    function _reduceReserves(uint reduceAmount) external nonReentrant {
        onlyAdmin();
        accrueInterest();

        // _reduceReservesFresh emits reserve-reduction-specific logs on errors, so we don't need to.
        _reduceReservesFresh(reduceAmount);
    }

    /**
     * @notice Reduces reserves by transferring to admin
     * @dev Requires fresh interest accrual
     * @param reduceAmount Amount of reduction to reserves
     */
    function _reduceReservesFresh(uint reduceAmount) internal {
        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        // Fail if protocol has insufficient underlying cash
        require(getCashPrior() >= reduceAmount, "insufficient cash");

        // Check reduceAmount ≤ reserves[n] (totalReserves)
        require(reduceAmount <= totalReserves, "invalid argument");

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // totalReserves - reduceAmount
        uint totalReservesNew = totalReserves - reduceAmount;

        // We checked reduceAmount <= totalReserves above, so this should never revert.
        assert(totalReservesNew <= totalReserves);

        // Store reserves[n+1] = reserves[n] - reduceAmount
        totalReserves = totalReservesNew;

        // doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
        doTransferOut(admin, reduceAmount);

        emit ReservesReduced(admin, reduceAmount, totalReservesNew);
    }

    /**
     * @notice accrues interest and updates the interest rate model using _setInterestRateModelFresh
     * @dev Admin function to accrue interest and update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     */
    function _setInterestRateModel(InterestRateModelInterface newInterestRateModel) public {
        onlyAdmin();
        accrueInterest();

        // _setInterestRateModelFresh emits interest-rate-model-update-specific logs on errors, so we don't need to.
        _setInterestRateModelFresh(newInterestRateModel);
    }

    /**
     * @notice updates the interest rate model (*requires fresh interest accrual)
     * @dev Admin function to update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     */
    function _setInterestRateModelFresh(InterestRateModelInterface newInterestRateModel) internal {
        // Verify market's block number equals current block number
        require(accrualBlockNumber == getBlockNumber(), "market not fresh");

        require(newInterestRateModel.isInterestRateModel());

        emit NewMarketInterestRateModel(interestRateModel, newInterestRateModel);
        interestRateModel = newInterestRateModel;
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying owned by this contract
     */
    function getCashPrior() internal view returns (uint);

    /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     *  This may revert due to insufficient balance or insufficient allowance.
     */
    function doTransferIn(address from, uint amount) internal returns (uint);

    /**
     * @dev Performs a transfer out.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     */
    function doTransferOut(address payable to, uint amount) internal;

    /// @dev Prevents a contract from calling itself, directly or indirectly.
    modifier nonReentrant() {
        require(_notEntered, "reentered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }

    /// @notice Checks caller is admin
    function onlyAdmin() internal view {
        require(msg.sender == admin, "only admin");
    }
}

// contracts/PToken/PTokenInterfaces.sol

contract PTokenStorage {
    /// @dev Guard variable for reentrancy checks
    bool internal _notEntered;

    /// @notice EIP-20 token name for this token
    string public name;

    /// @notice EIP-20 token symbol for this token
    string public symbol;

    /// @notice EIP-20 token decimals for this token
    uint8 public decimals;

    /// @notice Administrator for this contract
    address payable public admin;

    /// @notice Pending administrator for this contract
    address payable public pendingAdmin;

    /// @notice Contract which oversees inter-pToken operations
    ComptrollerNoNFTInterface public comptroller;

    /// @notice Model which tells what the current interest rate should be
    InterestRateModelInterface public interestRateModel;

    /// @notice Initial exchange rate used when minting the first PTokens (used when totalSupply = 0)
    uint internal initialExchangeRateMantissa;

    /// @notice Fraction of interest currently set aside for reserves
    uint public reserveFactorMantissa;

    /// @notice Block number that interest was last accrued at
    uint public accrualBlockNumber;

    /// @notice Accumulator of the total earned interest rate since the opening of the market
    uint public borrowIndex;

    /// @notice Total amount of outstanding borrows of the underlying in this market
    uint public totalBorrows;

    /// @notice Total amount of reserves of the underlying held in this market
    uint public totalReserves;

    /// @notice Total number of tokens in circulation
    uint public totalSupply;

    /// @notice Official record of token balances for each account
    mapping(address => uint) internal accountTokens;

    /// @notice Approved token transfer amounts on behalf of others
    mapping(address => mapping(address => uint)) internal transferAllowances;

    /**
     * @notice Container for borrow balance information
     * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
     * @member interestIndex Global borrowIndex as of the most recent balance-changing action
     */
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    /// @notice Mapping of account addresses to outstanding borrow balances
    mapping(address => BorrowSnapshot) internal accountBorrows;

    /// @notice Share of seized collateral that is added to reserves
    uint public protocolSeizeShareMantissa;
}

contract PTokenStorageV2 is PTokenStorage {
    /// @notice determines if market supports borrows, specially added for LP token markets
    bool public borrowable;
}

contract PTokenInterface is ErrorReporter, PTokenStorage {
    /// @notice Maximum borrow rate that can ever be applied (.0005% / block)
    uint internal constant borrowRateMaxMantissa = 0.0005e16;

    /// @notice Maximum fraction of interest that can be set aside for reserves
    uint internal constant reserveFactorMaxMantissa = 1e18;

    /// @notice First MINIMUM_LIQUIDITY minted pTokens gets locked on address(0) to prevent totalSupply being 0
    uint public constant MINIMUM_LIQUIDITY = 10000;

    /// @notice Indicator that this is a PToken contract (for inspection)
    bool public constant isPToken = true;

    /*** Market Events ***/

    /// @notice Event emitted when interest is accrued
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);

    /// @notice Event emitted when tokens are minted
    event Mint(address indexed minter, uint mintAmount, uint mintTokens);

    /// @notice Event emitted when tokens are redeemed
    event Redeem(address indexed redeemer, uint redeemAmount, uint redeemTokens);

    /// @notice Event emitted when underlying is borrowed
    event Borrow(address indexed borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);

    /// @notice Event emitted when a borrow is repaid
    event RepayBorrow(address indexed payer, address indexed borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);

    /// @notice Event emitted when a borrow is liquidated
    event LiquidateBorrow(address indexed liquidator, address indexed borrower, uint repayAmount, address indexed pTokenCollateral, uint seizeTokens);

    /// @notice EIP20 Transfer event
    event Transfer(address indexed from, address indexed to, uint amount);

    /// @notice EIP20 Approval event
    event Approval(address indexed owner, address indexed spender, uint amount);

    /*** Admin Events ***/

    /// @notice Event emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Event emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);

    /// @notice Event emitted when comptroller is changed
    event NewComptroller(address oldComptroller, address newComptroller);

    /// @notice Event emitted when interestRateModel is changed
    event NewMarketInterestRateModel(InterestRateModelInterface oldInterestRateModel, InterestRateModelInterface newInterestRateModel);

    /// @notice Event emitted when the reserve factor is changed
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);

    /// @notice Event emitted when the reserves are added
    event ReservesAdded(address indexed benefactor, uint addAmount, uint newTotalReserves);

    /// @notice Event emitted when the reserves are reduced
    event ReservesReduced(address indexed admin, uint reduceAmount, uint newTotalReserves);

    /// @notice Event emitted when protocolSeizeShareMantissa is changed
    event NewProtocolSeizeShareMantissa(uint oldProtocolSeizeShareMantissa, uint newProtocolSeizeShareMantissa);

    /*** User Interface ***/

    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function balanceOfUnderlyingStored(address owner) external view returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) public view returns (uint);
    function exchangeRateCurrent() public returns (uint);
    function exchangeRateStored() public view returns (uint);
    function getCash() external view returns (uint);
    function getRealBorrowIndex() external view returns (uint);
    function accrueInterest() public;
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (Error);

    /*** Admin Functions ***/

    function _setPendingAdmin(address payable newPendingAdmin) external;
    function _acceptAdmin() external;
    function _setComptroller(address newComptroller) public;
    function _setReserveFactor(uint newReserveFactorMantissa) external;
    function _reduceReserves(uint reduceAmount) external;
    function _setInterestRateModel(InterestRateModelInterface newInterestRateModel) public;
    function _setProtocolSeizeShareMantissa(uint newProtocolSeizeShareMantissa) external;
}

contract PErc20Storage {
    /// @notice Underlying asset for this PToken
    address public underlying;
}

contract PErc20Interface is PErc20Storage, PTokenInterface {
    /*** User Interface ***/

    function mint(uint mintAmount) external returns (Error);
    function redeem(uint redeemTokens) external returns (Error);
    function redeemUnderlying(uint redeemAmount) external returns (Error);
    function borrow(uint borrowAmount) external returns (Error);
    function repayBorrow(uint repayAmount) external returns (Error);
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (Error);
    function liquidateBorrow(address borrower, uint repayAmount, PTokenInterface pTokenCollateral) external returns (Error);
    function sweepToken(IERC20 token) external;

    /*** Admin Functions ***/

    function _addReserves(uint addAmount) external;
}

contract PTokenDelegationStorage {
    /// @notice Implementation address for this contract
    address public implementation;
}

contract PTokenDelegatorInterface is PTokenDelegationStorage {
    /// @notice Emitted when implementation is changed
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param newImplementation The address of the new implementation for delegation
     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(address newImplementation, bool allowResign, bytes memory becomeImplementationData) public;
}

contract PTokenDelegateInterface is PTokenInterface, PTokenDelegationStorage {
    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @dev Should revert if any issues arise which make it unfit for delegation
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes calldata data) external;

    /// @notice Called by the delegator on a delegate to forfeit its responsibility
    function _resignImplementation() external;
}

// contracts/PriceOracle/PriceOracleInterfaces.sol

contract IOracle {
    using SafeMath for uint;

    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /**
      * @notice Get the price of a given token
      * @param token The token. Use address(0) for native token (like ETH).
      * @param decimals Wanted decimals
      * @return The price of the token with a given decimals
      */
    function getPriceOfUnderlying(address token, uint decimals) public view returns (uint);

    /**
      * @notice Get the price of underlying pToken asset.
      * @param pToken The pToken
      * @return The price of pToken.underlying(). Decimals: 36 - underlyingDecimals
      */
    function getUnderlyingPrice(PToken pToken) public view returns (uint);

    /** @notice Check whether pToken is supported by this oracle and we've got a price for its underlying asset
      * @param pToken The token to check
      */
    function isPTokenSupported(PToken pToken) public view returns (bool);
}

contract IOracleNFT {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /**
     * @notice Get the price of the underlying asset of a given PNFTToken
     * @param pNFTToken The PNFTToken
     * @param tokenId The token ID of the NFT
     * @return The price of the underlying asset
     */
    function getUnderlyingNFTPrice(PNFTToken pNFTToken, uint tokenId) external view returns (uint);
    /**
      * @notice Get or request the price of the underlying asset of a given PNFTToken
      * @param pNFTToken The PNFTToken
      * @param tokenId The token ID of the NFT
      * @return The price of the underlying asset
      */

    function getOrRequestUnderlyingNFTPrice(PNFTToken pNFTToken, uint tokenId) external returns (uint);
    /**
      * @notice Get the price of ETH
      * @return The price of ETH
      */
    function getETHPrice() internal view returns (uint);
}

contract ISourceOracle {
    /// @notice Get the price of a given token
    /// @param token The token
    /// @param decimals Wanted decimals
    /// @return The price of the token with a given decimals
    function getTokenPrice(address token, uint decimals) public view returns (uint);

    /** @notice Check whether token is supported by this oracle and we've got a price for it
      * @param token The token to check
      */
    function isTokenSupported(address token) public view returns (bool);
}

contract INFPOracle {
     /**
       * @notice Check whether a given position is supported by this oracle
       * @param tokenId The token ID of the position
       * @return True if the position is supported, false otherwise
       */

    function isPositionSupported(uint tokenId) external view returns (bool);
    /**
      * @notice Get the price of a given position
      * @param tokenId The token ID of the position
      * @return The price of the position
      */
    function getPositionPrice(uint tokenId) external view returns (uint);
}

// contracts/PNFTToken/PNFTTokenDelegator.sol

/**
 * @title Paribus PNFTDelegator Contract
 * @notice PNFTTokens which wrap an NFT underlying and delegate to an implementation
 * @author Paribus
 */
contract PNFTTokenDelegator is PNFTTokenDelegatorInterface {
    constructor(address underlying_,
        address comptroller_,
        string memory name_,
        string memory symbol_,
        address payable admin_,
        address implementation_,
        bytes memory becomeImplementationData) public {

        // Creator of the contract is admin during initialization
        admin = msg.sender;

        // First delegate gets to initialize the delegator (i.e. storage contract)
        delegateTo(implementation_, abi.encodeWithSignature("initialize(address,address,string,string)",
            underlying_,
            comptroller_,
            name_,
            symbol_));

        // New implementations always get set via the setter (post-initialize)
        _setImplementation(implementation_, false, becomeImplementationData);

        // Set the proper admin now that initialization is done
        require(admin_ != address(0), "invalid argument");
        admin = admin_;
    }

    /**
     * @notice Internal method to delegate execution to another contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param callee The contract to delegatecall
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateTo(address callee, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize)
            }
        }

        require(returnData.length == 0 || (returnData.length >= 32 && uint256(abi.decode(returnData, (uint256))) != 0), "delegate call failed");
        return returnData;
    }

    /**
     * @notice Delegates execution to the implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToImplementation(bytes memory data) public returns (bytes memory) {
        return delegateTo(implementation, data);
    }

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param newImplementation The address of the new implementation for delegation
     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(address newImplementation, bool allowResign, bytes memory becomeImplementationData) public {
        require(msg.sender == admin, "only admin");
        // Perform a low-level call to check if isPNFTToken() exists and returns true
        (bool success,) = newImplementation.staticcall(
            abi.encodeWithSignature("isPNFTToken()")
        );

        require(success, "PNFTToken not supported");

        if (allowResign) {
            delegateToImplementation(abi.encodeWithSignature("_resignImplementation()"));
        }

        address oldImplementation = implementation;
        implementation = newImplementation;

        delegateToImplementation(abi.encodeWithSignature("_becomeImplementation(bytes)", becomeImplementationData));

        emit NewImplementation(oldImplementation, implementation);
    }

    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     */
    function() external payable {
        if (msg.value > 0) {
            // handle transfer ether from sudoswap during NFT token liquidation
            // nothing really to do here
            return;
        }

        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize)

            switch success
            case 0 { revert(free_mem_ptr, returndatasize) }
            default { return (free_mem_ptr, returndatasize) }
        }
    }
}

