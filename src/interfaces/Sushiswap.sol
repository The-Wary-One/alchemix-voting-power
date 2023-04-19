//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IUniswapV2Pair {
    function balanceOf(address account) external view returns (uint256);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function totalSupply() external view returns (uint256);
}

interface IMasterChef {
    function userInfo(uint256 _1, address _2) external view returns (uint256 amount, int256 rewardDebt);
}
