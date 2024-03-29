// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CommonStructs.sol";
import "./callback/IUniswapV3MintCallback.sol";
import "./callback/IUniswapV3SwapCallback.sol";
import "./IUniswapV3Pool.sol";

contract UniswapV3Pool is IUniswapV3Pool {
  using TickBitmap for mapping(int16 => uint256);
  mapping(int16 => uint256) public tickBitmap;
  
  using Tick for mapping(int24 => Tick.Info);
  using Position for mapping(bytes32 => Position.Info);
  using Position for Position.Info;

  int24 internal constant MIN_TICK = -887272;
  int24 internal constant MAX_TICK = -MIN_TICK;

  // Pool tokens
  address public immutable token0;
  address public immutable token1;

  // Packing variables that are read together
  struct Slot0 {
    // Current sqrt(P)
    uint160 sqrtPriceX96;
    // Current tick
    int24 tick;
  }
  
  Slot0 public slot0;

  // Amount of liquidity, L
  uint128 public liquidity;

  // Ticks info
  mapping(int24 => Tick.Info) public ticks;
  // Positions info
  mapping(bytes32 => Position.Info) public positions;

  constructor(address token0_, address token1_, uint160 sqrtPriceX96, int24 tick) {
    token0 = token0_;
    token1 = token1_;
    slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
  }

  function mint(
    address owner,
    int24 lowerTick,
    int24 upperTick,
    uint128 amount,
    bytes calldata data
  ) external returns (uint256 amount0, uint256 amount1) {
    if (
      lowerTick >= upperTick ||
      lowerTick < MIN_TICK ||
      upperTick > MAX_TICK
    ) {
      revert Errors.InvalidTickRange();
    }

    if (amount == 0) revert Errors.ZeroLiquidity();

    ticks.update(lowerTick, amount);
    ticks.update(upperTick, amount);

    Position.Info storage position = positions.get(
      owner,
      lowerTick,
      upperTick
    );
    position.update(amount);

    amount0 = 0.998976618347425280 ether;
    amount1 = 5000 ether;
    liquidity += uint128(amount);

    uint256 balance0Before;
    uint256 balance1Before;
    if (amount0 > 0) balance0Before = balance0();
    if (amount1 > 0) balance1Before = balance1();
    
    IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

    if (amount0 > 0 && balance0Before + amount0 > balance0())
      revert Errors.InsufficientInputAmount();
    if (amount1 > 0 && balance1Before + amount1 > balance1())
      revert Errors.InsufficientInputAmount();

    emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
  }

  function swap(address recipient, bytes calldata data) public returns (int256 amount0, int256 amount1) {
    // Hardcoding values to make things simple, swapping 42 USDC for ETH
    int24 nextTick = 85184;
    uint160 nextPrice = 5604469350942327889444743441197;

    amount0 = -0.008396714242162444 ether;
    amount1 = 42 ether;

    (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);
    IERC20(token0).transfer(recipient, uint256(-amount0));

    uint256 balance1Before = balance1();
    IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);

    if (balance1Before + uint256(amount1) < balance1()) {
      revert Errors.InsufficientInputAmount();
    }
    
    emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
  }

  function balance0() internal view returns (uint256 balance) {
    balance = IERC20(token0).balanceOf(address(this));
  }

  function balance1() internal view returns (uint256 balance) {
    balance = IERC20(token1).balanceOf(address(this));
  }
}