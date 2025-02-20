//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IBeefyVaultV7 {
    function balanceOf(address account) external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);

    function deposit(uint256 _amount) external;
}
