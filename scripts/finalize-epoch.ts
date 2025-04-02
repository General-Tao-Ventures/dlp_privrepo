import { ethers } from "hardhat";

const implementationContractName = "DLP";
async function main() {
    const [deployer] = await ethers.getSigners();

    const dlpAddress = process.env.DLP_PROXY_ADDRESS as string;

    const dlp = await ethers.getContractAt(
        implementationContractName,
        dlpAddress,
    );

    // pause the dlp
    const txPause = await dlp.connect(deployer).pause();
    await txPause.wait();
    console.log("===> Paused the DLP");

    const epoch = await dlp.currentEpoch();

    // update scores
    const contributorsCount = await dlp.getNumContributors();
    console.log(`===> Updating scores for ${contributorsCount} contributors`);

    for (let i = 0; i < contributorsCount; i++) {
        const txUpdateScore = await dlp.connect(deployer).updateScoreAndOwnerRewardsForContributor(i, epoch);
        console.log(`===> Updating score for contributor: ${i}, Txn_hash: ${txUpdateScore.hash}`);
        await txUpdateScore.wait();
        console.log(`===> Updated score for contributor: ${i}`);
    }

    // unpause the dlp
    const txUnpause = await dlp.connect(deployer).unpause();
    await txUnpause.wait();
    console.log("===> Unpaused the DLP");

    // finish epoch
    const txFinishEpoch = await dlp.connect(deployer).finishEpoch();
    await txFinishEpoch.wait();
    console.log("===> Finished the epoch");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
