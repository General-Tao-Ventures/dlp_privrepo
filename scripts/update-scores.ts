import { ethers } from "hardhat";

const implementationContractName = "DLP";
async function main() {
    const epoch = 2;

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

    // update scores
    const contributorsCount = await dlp.getNumContributors();
    console.log(`===> Updating scores for ${contributorsCount} contributors`);

    for (let i = 0; i < contributorsCount; i++) {
        const txUpdateScore = await dlp.connect(deployer).updateScoreForContributior(i, epoch);
        await txUpdateScore.wait();
        console.log(`===> Updated score for contributor: ${i}`);
    }

    // unpause the dlp
    const txUnpause = await dlp.connect(deployer).unpause();
    await txUnpause.wait();
    console.log("===> Unpaused the DLP");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
