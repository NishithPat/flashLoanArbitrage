const IERC20 = artifacts.require("IERC20");
const FlashLoanArbitrage = artifacts.require("FlashLoanArbitrage");

contract("FlashLoanArbitrage", accounts => {
    it("executes arbitrage using flash loans", async () => {
        const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
        const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
        const DAI_WHALE = "0xC73f6738311E76D45dFED155F39773e68251D251";
        const _3pool = "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7";

        const AaveAddressProvider = "0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5";
        const uniswapRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
        const curveAddressProvider = "0x0000000022D53366457F9d5E68Ec105046FC4383";

        const flashloanarbitrage = await FlashLoanArbitrage.new(AaveAddressProvider, uniswapRouter, curveAddressProvider, { from: DAI_WHALE });
        const DAIContract = await IERC20.at(DAI);
        const USDCContract = await IERC20.at(USDC);
        const quantityToSend = web3.utils.toWei("10000");

        await DAIContract.transfer(flashloanarbitrage.address, quantityToSend, { from: DAI_WHALE });
        let flashloanarbitrageDAIBalance = await DAIContract.balanceOf(flashloanarbitrage.address);

        console.log(flashloanarbitrageDAIBalance.toString(), " = initial DAI amount sent to flashloanarbitrage contract from DAI_WHALE");

        const exchangeContractAddress = await flashloanarbitrage.returnsExchangeAddress(2, { from: DAI_WHALE });
        await flashloanarbitrage.setArbitrageDetails(exchangeContractAddress, DAI, USDC, _3pool, { from: DAI_WHALE });

        const loanAmount = web3.utils.toWei("100000");
        const tx = await flashloanarbitrage.myFlashLoanCall(DAI, loanAmount, { from: DAI_WHALE });

        for (let log of tx.logs) {
            console.log(log.args.message, "=", log.args.value.toString());
        }

        flashloanarbitrageDAIBalance = await DAIContract.balanceOf(flashloanarbitrage.address);
        console.log(flashloanarbitrageDAIBalance.toString(), " = DAI amount remaining with flashloanarbitrage contract after loan repayment");

        await flashloanarbitrage.sendsEthAndTokensBack(DAI, { from: DAI_WHALE });
        flashloanarbitrageDAIBalance = await DAIContract.balanceOf(flashloanarbitrage.address);
        console.log(flashloanarbitrageDAIBalance.toString(), " = DAI amount remaining with flashloanarbitrage contract after owner calls sendsEthAndTokensBack method");

        assert.equal(flashloanarbitrageDAIBalance.toString(), 0);
    })
})