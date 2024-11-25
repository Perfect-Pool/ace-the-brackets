// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILinkToken {
    function balanceOf(address owner) external view returns (uint256);
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
}
