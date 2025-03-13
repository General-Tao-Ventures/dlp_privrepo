import { deployments, ethers } from "hardhat";
import { task } from "hardhat/config";
import { IDataRegistry } from "../typechain-types";

const implementationContractName = "DLP";
const dataRegistryContractName = "DataRegistryImplementation";

async function findAllContributions() {
    const dlpAddress = process.env.DLP_PROXY_ADDRESS as string;

    const dlp = await ethers.getContractAt(
        implementationContractName,
        dlpAddress,
    );

    const logs = await ethers.provider.getLogs({
        address: dlpAddress,
        topics: [
            "0x28a82d53b868461296eb4d69d0b1247a29fed6d1cd5480f797cc0971a6cb35e3",
        ],
        fromBlock: 0,
        toBlock: "latest",
    });

    const contributions = logs.map(log => ({
        epoch: dlp.interface.parseLog(log)?.args[0],
        contributor: dlp.interface.parseLog(log)?.args[1],
        contributionId: dlp.interface.parseLog(log)?.args[2],
    }))

    const removedLogs = await ethers.provider.getLogs({
        address: dlpAddress,
        topics: [
            "0x7c0832306a3b4afcebb2702a9bcfc529dbece6fd9004f1d3cfeb4a3a6cf8413e",
        ],
        fromBlock: 0,
        toBlock: "latest",
    });

    const removedContributions = removedLogs.map(log => (dlp.interface.parseLog(log)?.args[2]));

    const contributionsByContributor = contributions.filter(contribution => !removedContributions.includes(contribution.contributionId));

    return contributionsByContributor;
}

async function getProof(contributionId: string) {
    const dataRegistryAddress = process.env.DATA_REGISTRY_CONTRACT_ADDRESS as string;

    const dataRegistry = await ethers.getContractAt(
        dataRegistryContractName,
        dataRegistryAddress,
    );

    const proof = await dataRegistry.fileProofs(contributionId, 1);
    return proof;
}

async function main() {
    const contributions = await findAllContributions();
    console.log(`Found ${contributions.length} files in total`);

    // const contributor = "0xd8c0dCbb28A6599ba9e6bf072547e68f635cA912";
    const contributor = "0x81395D774847335d9aF3Ad2cb776b04bde20a66a";
    const contributionsByContributor = contributions.filter(contribution => contribution.contributor === contributor);

    console.log(`Found ${contributionsByContributor.length} contributions for contributor ${contributor}`);
    
    const proofs = [];
    for (const contribution of contributionsByContributor) {
        const proof = await getProof(contribution.contributionId);
        const metadata = proof[1][2].slice(7, 7 + 32);
        console.log(`Proof for ${contribution.contributionId} at epoch ${contribution.epoch}: ${proof[1][2].slice(7, 7 + 32)}`);
        proofs.push({
            metadata: metadata,
            contributionId: contribution.contributionId,
        });
    }

    for (let i = proofs.length - 1; i >= 0; i--) {
        const proof = proofs[i];
        const metadata = proof.metadata;
        if (metadata === '00000000000000000000000000000000') {
            console.log("Found a contribution with no metadata with contributionId: ", proof.contributionId);
        } else break;
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
