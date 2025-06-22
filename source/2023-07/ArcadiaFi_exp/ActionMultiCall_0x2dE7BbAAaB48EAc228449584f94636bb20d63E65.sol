// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

// src/actions/utils/ActionData.sol
/**
 * Created by Pragma Labs

 */

// Struct with information to pass to and from actionHandlers.
struct ActionData {
    address[] assets; // Array of the contract addresses of the assets.
    uint256[] assetIds; // Array of the IDs of the assets.
    uint256[] assetAmounts; // Array with the amounts of the assets.
    uint256[] assetTypes; // Array with the types of the assets.
    uint256[] actionBalances; // Array with the balances of the actionHandler.
}

// src/interfaces/IERC1155.sol

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    function balanceOf(address account, uint256 id) external view returns (uint256);
}

// src/interfaces/IERC20.sol

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function decimals() external view returns (uint256);
}

// src/actions/ActionBase.sol
/**
 * Created by Pragma Labs

 */

abstract contract ActionBase {
    /**
     * @notice Calls a series of addresses with arbitrary calldata.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return resultData An actionAssetData struct with the balances of this ActionMultiCall address.
     */
    function executeAction(bytes calldata actionData) external virtual returns (ActionData memory resultData) { }
}

// src/actions/MultiCall.sol
/**
 * Created by Pragma Labs

 */

/**
 * @title Generic multicall action
 * @author Pragma Labs
 * @notice Calls any external contract with arbitrary data.
 * @dev Only calls are used, no delegatecalls.
 * @dev This address will approve random addresses. Do not store any funds on this address!
 */
contract ActionMultiCall is ActionBase {
    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() { }

    /* //////////////////////////////////////////////////////////////
                            ACTION LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Calls a series of addresses with arbitrary calldata.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return resultData An actionAssetData struct with the balances of this ActionMultiCall address.
     * @dev input address is not used in this generic action.
     */
    function executeAction(bytes calldata actionData) external override returns (ActionData memory) {
        (, ActionData memory incoming, address[] memory to, bytes[] memory data) =
            abi.decode(actionData, (ActionData, ActionData, address[], bytes[]));

        uint256 callLength = to.length;

        require(data.length == callLength, "EA: Length mismatch");

        for (uint256 i; i < callLength;) {
            (bool success, bytes memory result) = to[i].call(data[i]);
            require(success, string(result));

            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < incoming.assets.length;) {
            if (incoming.assetTypes[i] == 0) {
                incoming.assetAmounts[i] = IERC20(incoming.assets[i]).balanceOf(address(this));
            } else if (incoming.assetTypes[i] == 1) {
                incoming.assetAmounts[i] = 1;
            } else if (incoming.assetTypes[i] == 2) {
                incoming.assetAmounts[i] = IERC1155(incoming.assets[i]).balanceOf(address(this), incoming.assetIds[i]);
            }
            unchecked {
                ++i;
            }
        }

        return incoming;
    }

    /* //////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Repays an exact amount to a creditor.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset that is being repaid.
     * @param vault The contract address of the vault for which the debt is being repaid.
     * @param amount The amount of debt to.
     * @dev Can be called as one of the calls in executeAction, but fetches the actual contract balance after other DeFi interactions.
     */
    function executeRepay(address creditor, address asset, address vault, uint256 amount) external {
        if (amount < 1) {
            amount = IERC20(asset).balanceOf(address(this));
        }

        (bool success, bytes memory data) =
            creditor.call(abi.encodeWithSignature("repay(uint256,address)", amount, vault));
        require(success, string(data));
    }
}

