// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IPool {
    function balanceOf(address account) external view returns (uint256);
    function reserve1() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function stable() external view returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

interface IRouter {
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface IGauge {
    function balanceOf(address account) external view returns (uint256);

    function deposit(uint256 _amount) external;
}
