// SPDX-License-Identifier: GPL-2.0-or-later
// NOTE: version bump to solc 0.8.0
pragma solidity >=0.8.0;

// NOTE: node_modules style import replaced with forge import
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}
