//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IVault {
    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (address[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);
}
