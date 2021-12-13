# Arbitrage using flash loans

Smart contract executes arbitrage logic using AAVE flash loans. It executes the same logic as seen here - https://youtu.be/mCJUhnXQ76s?t=371

Flash loans allow users to borrow instantly a large sum of money without any collateral, as long as the borrowed money is returned within the same transaction. In this repo, AAVE flash loans are being used to execute the same arbitrage logic as seen in the youtube video by Finematics.

--> DAI is borrowed from AAVE using flash loan 
--> DAI is swapped for USDC through Uniswap
--> USDC is swapped back into DAI using Curve Finance
--> DAI is sent back to AAVE with some fees at the end of transaction.

The project was executed by forking the Mainnet using Ganache-cli. This allows us to interact with smart contracts on the Mainnet without sending actual transactions to the mainnet. One more benefit is that we can have access to the Whale accounts, meaning access to a huge amount of crypto tokens to test our smart contracts.

Note: Only meant for educational purpose. 