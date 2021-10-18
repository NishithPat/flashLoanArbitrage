// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./curve-contracts/IProvider.sol";
import "./curve-contracts/ISwap.sol";
import "./uniswap-contracts/IPeripheryPayments.sol";
import "./uniswap-contracts/ISwapRouter.sol";
import "./aave-contracts/aave/FlashLoanReceiverBase.sol";
import "./aave-contracts/aave/ILendingPool.sol";
import "./aave-contracts/aave/ILendingPoolAddressesProvider.sol";

/*
    -->Get DAI from aave(flash loan)
    -->Swap DAI for USDC(using Uniswap)
    -->Swap USDC for DAI(using Curve)
    -->Send DAI back to aave(end of transaction)
*/
contract FlashLoanArbitrage is FlashLoanReceiverBase {
    address uinswapRouter;
    address addressProviderCurve;
    event Log(string message, uint256 value);

    address inToken;
    address outToken;
    address curvePool;
    address curveExchangeContract;

    address owner;

    constructor(
        ILendingPoolAddressesProvider _addressProviderAave,
        address _uniswapRouter,
        address _addressProviderCurve
    ) FlashLoanReceiverBase(_addressProviderAave) {
        uinswapRouter = _uniswapRouter;
        addressProviderCurve = _addressProviderCurve;
        owner = msg.sender;
    }

    function myFlashLoanCall(address _tokenForLoan, uint256 _amount) public {
        require(msg.sender == owner, "only owner can call the function");
        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = _tokenForLoan;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        emit Log("borrowing amount in DAI", _amount);

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function swapTokenOnUniswap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amount
    ) public returns (uint256) {
        uint24 poolFee = 500; //DAI-USDC pool fee
        //IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amount);
        IERC20(_tokenIn).approve(uinswapRouter, _amount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 120,
                amountIn: _amount,
                amountOutMinimum: 1,
                sqrtPriceLimitX96: 0
            });

        emit Log("exchanging on uniswap(DAI to USDC)", _amount);

        uint256 amountOut = ISwapRouter(uinswapRouter).exactInputSingle(params);

        return amountOut;
    }

    function returnsExchangeAddress(uint256 _id) public view returns (address) {
        return IProvider(addressProviderCurve).get_address(_id);
    }

    function exchangesTokensOnCurve(
        address _pool,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _expected,
        address _receiver
    ) public payable {
        IERC20(_from).approve(curveExchangeContract, _amount);
        emit Log("exchanging on Curve(USDC to DAI)", _amount);

        ISwap(curveExchangeContract).exchange(
            _pool,
            _from,
            _to,
            _amount,
            _expected,
            _receiver
        );
    }

    function setArbitrageDetails(
        address _exchangeContract,
        address _tokenIn,
        address _tokenOut,
        address _pool
    ) public {
        inToken = _tokenIn;
        outToken = _tokenOut;
        curvePool = _pool;
        curveExchangeContract = _exchangeContract;
    }

    function arbitrage(
        address _tokenIn,
        address _tokenOut,
        address _pool
    ) public {
        uint256 contractTokenInBalance = IERC20(_tokenIn).balanceOf(
            address(this)
        );

        swapTokenOnUniswap(_tokenIn, _tokenOut, contractTokenInBalance); //swap DAI for USDC on Uniswap
        uint256 contractTokenOutBalance = IERC20(_tokenOut).balanceOf(
            address(this)
        );
        exchangesTokensOnCurve( //swap USDC back to DAI on Curve
            _pool,
            _tokenOut,
            _tokenIn,
            contractTokenOutBalance,
            1,
            address(this)
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        //insert arbitrage logic
        arbitrage(inToken, outToken, curvePool);

        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i] + premiums[i];
            emit Log("returning amount borrowed in DAI to Aave", amountOwing);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }

        return true;
    }

    function sendsEthAndTokensBack(address _tokenAddress) public {
        require(msg.sender == owner, "only owner can call the function");
        (bool sent, ) = payable(msg.sender).call{value: address(this).balance}(
            ""
        );
        require(sent, "Failed to send ether");

        uint256 contractTokenBalance = IERC20(_tokenAddress).balanceOf(
            address(this)
        );
        IERC20(_tokenAddress).transfer(msg.sender, contractTokenBalance);
    }
}
