# How to deploy a WrappedFeedPXETH smart contract?

You will find here a step by step explanation to how to deploy a WrappedFeedPXETH smart contract

##### Step 1

Inside the .env file set :

- PK="deployer address private key"
- ALCHEMY_ID="your alchemy api key"
- ETHERSCAN_API_KEY="your etherscan api key"

##### Step 2 :

Run `npx hardhat run --network mainnet scripts/WrappedFeedPXETHDeployment.ts`.
That will deploy wrappedFeedPXETH and output the address of this one into the terminal.
Now that the smart contract is deployed let's verify it.

##### Step 3 :

Inside the scripts/verification/WrappedFeedPXETHVerification.ts file set wrappedFeedPXETH with the address get in step 3.

##### Step 4 :

Run `npx hardhat run --network mainnet scripts/verification/WrappedFeedPXETHVerification.ts`

Now you have a wrappedFeedPXETH deployed and verified.
