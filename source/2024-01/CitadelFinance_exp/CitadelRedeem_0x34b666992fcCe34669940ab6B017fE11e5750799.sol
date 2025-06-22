// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20 ^0.8.20;

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

// contracts/interfaces/IBCIT.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IBCIT {
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

    function burn(address from, uint256 value) external;

    function getTotalAvailableBonds() external view returns (uint256);
}

// contracts/interfaces/ICIT.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface ICIT {
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

    function mint(address to, uint256 value) external;

    function burn(address from, uint256 value) external;
}

// contracts/interfaces/ICITStaking.sol

interface ICITStaking {
    function redeemCalculator(address user) external view returns (uint256[2][2] memory);
    function removeStaking(address user, address token, uint8 rate, uint256 amount) external;
    function getFixedRate() external view returns (uint256);
    function getCITInUSDAllFixedRates(address user, uint256 amount) external view returns (uint256);
}

// @openzeppelin/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

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

// contracts/interfaces/ITreasury.sol

interface ITreasury {
    function distributeRedeem(address token, uint256 amount, address user) external;
}

// contracts/interfaces/IUniswapV2Router01.sol

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);
}

// @openzeppelin/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

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
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// contracts/interfaces/ICamelotRouter.sol

interface ICamelotRouter is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        address referrer,
        uint deadline
    ) external;

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
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

// contracts/CITRedeem.sol
//  _____  _  _              _        _  ______           _                        
// /  __ \(_)| |            | |      | | | ___ \         | |                       
// | /  \/ _ | |_  __ _   __| |  ___ | | | |_/ / ___   __| |  ___   ___  _ __ ___  
// | |    | || __|/ _` | / _` | / _ \| | |    / / _ \ / _` | / _ \ / _ \| '_ ` _ \ 
// | \__/\| || |_| (_| || (_| ||  __/| | | |\ \|  __/| (_| ||  __/|  __/| | | | | |
//  \____/|_| \__|\__,_| \__,_| \___||_| \_| \_|\___| \__,_| \___| \___||_| |_| |_|

contract CitadelRedeem is Ownable, ReentrancyGuard {

    //----------------------VARIABLES----------------------//

    ICIT public CIT;
    IBCIT public bCIT;
    IERC20 public USDC;
    IERC20 public WETH;
    ITreasury public treasury;
    ICITStaking public CITStaking;
    ICamelotRouter public camelotRouter;

    address private CITStakingAddy;

    uint256 public maxRedeemableFixed = 0;
    uint256 public maxRedeemableVariable = 0;

    mapping(address => uint256) private totalbCITRedeemedByUser;

    //----------------------CONSTRUCTOR----------------------//

    constructor(address initialOwner, address _treasury, address _bCIT) Ownable(initialOwner) {
        treasury = ITreasury(_treasury);
        bCIT = IBCIT(_bCIT);
        USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
        WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
        camelotRouter = ICamelotRouter(0xc873fEcbd354f5A56E00E710B90EF4201db2448d); // Camelot Arbitrum One 0xc873fEcbd354f5A56E00E710B90EF4201db2448d
    }

    //----------------------SETTERS----------------------//

    function setbCIT(address _bCIT) public onlyOwner {
        bCIT = IBCIT(_bCIT);
    }

    function setCIT(address _CIT) public onlyOwner {
        CIT = ICIT(_CIT);
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = ITreasury(_treasury);
    }

    function setCITStaking(address _CITStaking) public onlyOwner {
        CITStaking = ICITStaking(_CITStaking);
        CITStakingAddy = _CITStaking;
    }

    function setMaxRedeemableFixed(uint256 _maxRedeemableFixed) public onlyOwner {
        maxRedeemableFixed += _maxRedeemableFixed;
    }

    function setMaxRedeemableVariable(uint256 _maxRedeemableVariable) public onlyOwner {
        maxRedeemableVariable += _maxRedeemableVariable;
    }

    //----------------------USERS FUNCTIONS----------------------//

    /**
     * 
     * @param underlying the id of the underlying to be distributed - 0 for USDC, 1 for ETH
     * @param token the id of the token to be distributed - 0 for CIT, 1 for bCIT
     * @param amount the amount of CIT to be redeemed
     * @param rate the rate, either fixed or variable - 0 for variable, 1 for fixed
     */
    function redeem(uint256 underlying, uint256 token, uint256 amount, uint8 rate) public nonReentrant {
        require(underlying == 0 || underlying == 1, "Invalid underlying");
        require(token == 0 || token == 1, "Invalid token");
        require(rate == 0 || rate == 1, "Invalid rate");
        require(amount > 0, "Amount must be greater than 0");

        uint256 amountAvailable = CITStaking.redeemCalculator(msg.sender)[token][rate];
        require(amountAvailable > 0, "Nothing to redeem");

        uint256 amountInUnderlying;
        address tokenAddy = underlying == 0 ? address(USDC) : address(WETH);
        // Variable rate
        if (rate == 0) {
            require(amount <= amountAvailable, "Not enough CIT or bCIT to redeem");
            require(amount <= maxRedeemableVariable, "Amount too high");
            maxRedeemableVariable -= amount;
            address[] memory path = new address[](3);

            path[0] = address(CIT); // 1e18
            path[1] = address(WETH);
            path[2] = address(USDC); // 1e6

            uint[] memory a = camelotRouter.getAmountsOut(amount, path);

            if (underlying == 0) {
                amountInUnderlying = a[2]; // result in 6 decimal
            } else {
                amountInUnderlying = a[1]; // result in 18 decimal
            }
        } 
        // Fixed rate
        else {
            uint256 _amount = CITStaking.getCITInUSDAllFixedRates(msg.sender, amount);
            require(amount <= amountAvailable, "Not enough CIT or bCIT to redeem");
            require(amount <= maxRedeemableFixed, "Amount too high");
            maxRedeemableFixed -= amount;
            if (underlying == 1) {
                address[] memory path = new address[](2);

                path[0] = address(USDC); // 1e6
                path[1] = address(WETH); // 1e18

                uint[] memory a = camelotRouter.getAmountsOut(_amount / 1e12, path); // result in 18 decimal

                amountInUnderlying = a[1];
            } else {
                amountInUnderlying = _amount / 1e12; // 1e6 is the decimals of USDC, so 18 - 12 = 6
            }
        }

        if (token == 0) {
            CIT.burn(CITStakingAddy, amount);
            CITStaking.removeStaking(msg.sender, address(CIT), rate, amount);
        } else if (token == 1) {
            totalbCITRedeemedByUser[msg.sender] += amount;
            bCIT.burn(CITStakingAddy, amount);
            CITStaking.removeStaking(msg.sender, address(bCIT), rate, amount);
        }

        treasury.distributeRedeem(tokenAddy, amountInUnderlying, msg.sender);
    }

    //----------------------CALCULATORS----------------------//

    function getTreasuryBalanceETHinUSDC() private view returns (uint256) {
        uint256 amount = address(treasury).balance + WETH.balanceOf(address(treasury));
        address[] memory path = new address[](2);

        path[0] = address(WETH);
        path[1] = address(USDC);

        uint[] memory a = camelotRouter.getAmountsOut(amount, path); // result in 6 decimal

        return a[1];
    }

    function getTotalTreasuryBalance() public view returns (uint256) {
        return USDC.balanceOf(address(treasury)) + getTreasuryBalanceETHinUSDC();
    }

    //---------------------- GETTERS ----------------------//

    function getTotalbCITRedeemedByUser(address user) public view returns (uint256) {
        return totalbCITRedeemedByUser[user];
    }
}

