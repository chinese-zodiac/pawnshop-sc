## TCu29 Sale

Allows purchase of TCu29 up to $10,000 in one transaction, with no slippage.

## Official Deployments

BSC:0x6AEEe36069b881B536cA7d9761353ec2c2405B03

## deployment

The admin address is hardcoded in the deployment script.

forge script script/DeployTCu29Sale.s.sol:DeployTCu29Sale --broadcast --verify -vvv --rpc-url https://rpc.ankr.com/bsc --etherscan-api-key $ETHERSCAN_API_KEY -i 1 --sender $DEPLOYER_ADDRESS
