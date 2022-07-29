// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.6;

import "./IZap.sol";
import "./lib/IUniswapV2Router02.sol";
import "./lib/IUniswapFactory.sol";
import "./lib/IUniswapPair.sol";
import "./lib/IWETH.sol";

contract Zap is IZap {
    IUniswapV2Router02 public router;
    IUniswapFactory public factory;
    address WNATIVE;

    constructor(address _router) {
        router = IUniswapV2Router02(_router);
        factory = IUniswapFactory(router.factory());
        WNATIVE = router.WETH();
    }

    /// @notice get min amounts for swaps
    /// @param _inputAmount total input amount for swap
    /// @param _path0 path from input token to LP token0
    /// @param _path1 path from input token to LP token1
    function getMinAmounts(
        uint256 _inputAmount,
        address[] calldata _path0,
        address[] calldata _path1
    )
        external
        view
        override
        returns (
            uint256[2] memory _minAmountsSwap,
            uint256[2] memory _minAmountsLP
        )
    {
        require(
            _path0.length >= 2 || _path1.length >= 2,
            "Zap: Needs at least one path"
        );

        uint256 _inputAmountHalf = _inputAmount / 2;

        uint256 _minAmountSwap0 = _inputAmountHalf;
        if (_path0.length != 0) {
            uint256[] memory amountsOut0 = router.getAmountsOut(
                _inputAmountHalf,
                _path0
            );
            _minAmountSwap0 = amountsOut0[amountsOut0.length - 1];
        }

        uint256 _minAmountSwap1 = _inputAmountHalf;
        if (_path1.length != 0) {
            uint256[] memory amountsOut1 = router.getAmountsOut(
                _inputAmountHalf,
                _path1
            );
            _minAmountSwap1 = amountsOut1[amountsOut1.length - 1];
        }

        address token0 = _path0.length == 0
            ? _path1[0]
            : _path0[_path0.length - 1];
        address token1 = _path1.length == 0
            ? _path0[0]
            : _path1[_path1.length - 1];

        IUniswapPair lp = IUniswapPair(factory.getPair(token0, token1));
        (uint256 reserveA, uint256 reserveB, ) = lp.getReserves();
        if (token0 == lp.token1()) {
            (reserveA, reserveB) = (reserveB, reserveA);
        }
        uint256 amountB = router.quote(_minAmountSwap0, reserveA, reserveB);

        _minAmountsSwap = [_minAmountSwap0, _minAmountSwap1];
        _minAmountsLP = [_minAmountSwap0, amountB];
    }

    /// @notice Zap single token to LP
    /// @param _inputToken Input token
    /// @param _inputAmount Input amount
    /// @param _lpTokens Tokens of LP to zap to
    /// @param _path0 Path from input token to LP token0
    /// @param _path1 Path from input token to LP token1
    /// @param _minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param _minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param _to address to receive LPs
    /// @param _deadline Unix timestamp after which the transaction will revert
    function zap(
        IERC20 _inputToken,
        uint256 _inputAmount,
        address[] memory _lpTokens, //[tokenA, tokenB]
        address[] calldata _path0,
        address[] calldata _path1,
        uint256[] memory _minAmountsSwap, //[A, B]
        uint256[] memory _minAmountsLP, //[amountAMin, amountBMin]
        address _to,
        uint256 _deadline
    ) public override {
        uint256 _balanceBefore = _getBalance(address(_inputToken));
        _inputToken.transferFrom(msg.sender, address(this), _inputAmount);
        _inputAmount = _getBalance(address(_inputToken)) - _balanceBefore;

        _zap(
            _inputToken,
            _inputAmount,
            _lpTokens,
            _path0,
            _path1,
            _minAmountsSwap,
            _minAmountsLP,
            _to,
            _deadline
        );
    }

    /// @notice Zap native token to LP
    /// @param _lpTokens Tokens of LP to zap to
    /// @param _path0 Path from input token to LP token0
    /// @param _path1 Path from input token to LP token1
    /// @param _minAmountsSwap The minimum amount of output tokens that must be received for swap
    /// @param _minAmountsLP AmountAMin and amountBMin for adding liquidity
    /// @param _to address to receive LPs
    /// @param _deadline Unix timestamp after which the transaction will revert
    function zapNative(
        address[] memory _lpTokens, //[tokenA, tokenB]
        address[] calldata _path0,
        address[] calldata _path1,
        uint256[] memory _minAmountsSwap, //[A, B]
        uint256[] memory _minAmountsLP, //[amountAMin, amountBMin]
        address _to,
        uint256 _deadline
    ) public payable override {
        uint256 _inputAmount = msg.value;
        IERC20 _inputToken = IERC20(WNATIVE);
        IWETH(WNATIVE).deposit{value: _inputAmount}();
        if (_to == address(0)) {
            _to = msg.sender;
        }

        _zap(
            _inputToken,
            _inputAmount,
            _lpTokens,
            _path0,
            _path1,
            _minAmountsSwap,
            _minAmountsLP,
            _to,
            _deadline
        );
    }

    function _zap(
        IERC20 _inputToken,
        uint256 _inputAmount,
        address[] memory _lpTokens, //[tokenA, tokenB]
        address[] calldata _path0,
        address[] calldata _path1,
        uint256[] memory _minAmountsSwap, //[A, B]
        uint256[] memory _minAmountsLP, //[amountAMin, amountBMin]
        address _to,
        uint256 _deadline
    ) internal {
        require(
            _lpTokens.length == 2,
            "Zap: need exactly 2 tokens to form a LP"
        );
        require(
            factory.getPair(_lpTokens[0], _lpTokens[1]) != address(0),
            "Zap: Pair doesn't exist"
        );

        _inputToken.approve(address(router), _inputAmount);

        uint256 amount0 = _inputAmount / 2;
        if (_lpTokens[0] != address(_inputToken)) {
            require(
                _path0[0] == address(_inputToken),
                "Zap: wrong path _path0[0]"
            );
            require(
                _path0[_path0.length - 1] == _lpTokens[0],
                "Zap: wrong path _path0[-1]"
            );
            uint256 _balanceBefore = _getBalance(_lpTokens[0]);
            router.swapExactTokensForTokens(
                _inputAmount / 2,
                _minAmountsSwap[0],
                _path0,
                address(this),
                _deadline
            );
            amount0 = _getBalance(_lpTokens[0]) - _balanceBefore;
        }

        uint256 amount1 = _inputAmount / 2;
        if (_lpTokens[1] != address(_inputToken)) {
            require(
                _path1[0] == address(_inputToken),
                "Zap: wrong path _path1[0]"
            );
            require(
                _path1[_path1.length - 1] == _lpTokens[1],
                "Zap: wrong path _path1[-1]"
            );
            uint256 _balanceBefore = _getBalance(_lpTokens[1]);
            router.swapExactTokensForTokens(
                _inputAmount / 2,
                _minAmountsSwap[1],
                _path1,
                address(this),
                _deadline
            );
            amount1 = _getBalance(_lpTokens[1]) - _balanceBefore;
        }

        IERC20(_lpTokens[0]).approve(address(router), amount0);
        IERC20(_lpTokens[1]).approve(address(router), amount1);
        router.addLiquidity(
            _lpTokens[0],
            _lpTokens[1],
            amount0,
            amount1,
            _minAmountsLP[0],
            _minAmountsLP[1],
            _to,
            _deadline
        );

        uint256 _balance0 = _getBalance(_lpTokens[0]);
        if (_balance0 > 0) {
            _transfer(_lpTokens[0], _balance0);
        }
        uint256 _balance1 = _getBalance(_lpTokens[1]);
        if (_balance1 > 0) {
            _transfer(_lpTokens[1], _balance1);
        }
    }

    function _getBalance(address _token)
        internal
        view
        returns (uint256 _balance)
    {
        _balance = IERC20(_token).balanceOf(address(this));
    }

    function _transfer(address _token, uint256 _amount) internal {
        if (_token == WNATIVE) {
            IWETH(WNATIVE).withdraw(_amount);
            payable(msg.sender).transfer(_amount);
        } else {
            IERC20(_token).transfer(msg.sender, _amount);
        }
    }

    /// @dev The receive method is used as a fallback function in a contract and is called when ether is sent to a contract with no calldata.
    receive() external payable {
        require(msg.sender == WNATIVE, "Zap: Only receive ether from wrapped");
    }
}
