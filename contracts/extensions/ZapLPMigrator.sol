// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Zap.sol";

abstract contract ZapLPMigrator is Zap {
    /// @notice Zap LPs to other DEX LPs
    /// @param _router The LP router to zap from
    /// @param _lp LP address to zap
    /// @param _amount Amount of LPs to zap
    /// @param _amountAMinRemove The minimum amount of token0 to receive after removing liquidity
    /// @param _amountBMinRemove The minimum amount of token1 to receive after removing liquidity
    /// @param _amountAMinAdd The minimum amount of token0 to add to LP on add liquidity
    /// @param _amountBMinAdd The minimum amount of token1 to add to LP on add liquidity
    /// @param _deadline Unix timestamp after which the transaction will revert
    function zapLPMigrator(
        IUniswapV2Router02 _router,
        IUniswapPair _lp,
        uint256 _amount,
        uint256 _amountAMinRemove,
        uint256 _amountBMinRemove,
        uint256 _amountAMinAdd,
        uint256 _amountBMinAdd,
        uint256 _deadline
    ) external {
        address token0 = _lp.token0();
        address token1 = _lp.token1();

        _lp.transferFrom(msg.sender, address(this), _amount);
        _lp.approve(address(_router), _amount);
        (uint256 amountAReceived, uint256 amountBReceived) = _router
            .removeLiquidity(
                token0,
                token1,
                _amount,
                _amountAMinRemove,
                _amountBMinRemove,
                address(this),
                _deadline
            );

        IERC20(token0).approve(address(router), amountAReceived);
        IERC20(token1).approve(address(router), amountBReceived);
        (uint256 amountASent, uint256 amountBSent, ) = router.addLiquidity(
            token0,
            token1,
            amountAReceived,
            amountBReceived,
            _amountAMinAdd,
            _amountBMinAdd,
            msg.sender,
            _deadline
        );

        if (amountAReceived - amountASent > 0) {
            IERC20(token0).transfer(msg.sender, amountAReceived - amountASent);
        }
        if (amountBReceived - amountBSent > 0) {
            IERC20(token1).transfer(msg.sender, amountBReceived - amountBSent);
        }
    }
}
