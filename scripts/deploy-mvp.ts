import { ethers } from "hardhat";
import fs from "fs";

async function main() {
    const network = await ethers.provider.getNetwork();
    const networkName =
        network.chainId === 8453n ? "Base Mainnet" :
            network.chainId === 84532n ? "Base Sepolia" :
                network.chainId === 5003n ? "Mantle Sepolia" :
                    network.chainId === 5000n ? "Mantle Mainnet" :
                        network.chainId === 421614n ? "Arbitrum Sepolia" :
                            network.chainId === 42161n ? "Arbitrum Mainnet" :
                                "Local Network";

    console.log(`🚀 Starting Quinty MVP deployment to ${networkName}...`);

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

    // Helper function to wait with delay
    const waitForDeploy = async (txPromise: any, description: string) => {
        console.log(`${description}...`);
        const contract = await txPromise;
        await contract.waitForDeployment();
        console.log(`✅ ${description} completed`);
        await new Promise(resolve => setTimeout(resolve, 2000));
        return contract;
    };

    const waitForTx = async (txPromise: any, description: string) => {
        console.log(`${description}...`);
        const tx = await txPromise;
        await tx.wait();
        console.log(`✅ ${description} completed`);
        await new Promise(resolve => setTimeout(resolve, 2000));
    };

    // 1. Deploy QuintyReputation
    console.log("\n📋 Deploying QuintyReputation...");
    const QuintyReputation = await ethers.getContractFactory("QuintyReputation");
    const reputation = await waitForDeploy(
        QuintyReputation.deploy("ipfs://QmReputation/"),
        "Deploying QuintyReputation"
    );
    const reputationAddress = await reputation.getAddress();
    console.log("   Address:", reputationAddress);

    // 2. Deploy Quinty (Core)
    console.log("\n🎯 Deploying Quinty (Core Bounty Contract)...");
    const Quinty = await ethers.getContractFactory("Quinty");
    const quinty = await waitForDeploy(
        Quinty.deploy(),
        "Deploying Quinty"
    );
    const quintyAddress = await quinty.getAddress();
    console.log("   Address:", quintyAddress);

    // 3. Deploy QuintyNFT
    console.log("\n🏅 Deploying QuintyNFT (Badge System)...");
    const QuintyNFT = await ethers.getContractFactory("QuintyNFT");
    const nft = await waitForDeploy(
        QuintyNFT.deploy("ipfs://QmNFT/"),
        "Deploying QuintyNFT"
    );
    const nftAddress = await nft.getAddress();
    console.log("   Address:", nftAddress);

    // 4. Setup contract connections
    console.log("\n🔗 Setting up contract connections...");

    await waitForTx(
        quinty.setAddresses(reputationAddress, nftAddress),
        "Setting Quinty addresses"
    );

    await waitForTx(
        reputation.transferOwnership(quintyAddress),
        "Transferring QuintyReputation ownership to Quinty"
    );

    await waitForTx(
        nft.authorizeMinter(quintyAddress),
        "Authorizing Quinty as NFT minter"
    );

    console.log("\n✨ MVP Deployment completed successfully!");

    const deploymentInfo = {
        chainId: Number(network.chainId),
        network: networkName,
        timestamp: new Date().toISOString(),
        contracts: {
            Quinty: quintyAddress,
            QuintyReputation: reputationAddress,
            QuintyNFT: nftAddress,
        },
    };

    fs.writeFileSync(
        'deployments-mvp.json',
        JSON.stringify(deploymentInfo, null, 2)
    );
    console.log("\n💾 Deployment info saved to deployments-mvp.json");

    console.log("\n📋 Contract Addresses Summary:");
    console.log("==========================================");
    console.log(`Quinty:              ${quintyAddress}`);
    console.log(`QuintyReputation:    ${reputationAddress}`);
    console.log(`QuintyNFT:           ${nftAddress}`);
    console.log("==========================================");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Fatal error:", error);
        process.exit(1);
    });
