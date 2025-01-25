import { deployments, ethers } from "hardhat";
import { task } from "hardhat/config";
import { IDataRegistry } from "../typechain-types";

const implementationContractName = "DLP";
const dataRegistryContractName = "DataRegistryImplementation";

function generateRandomSignature() {
    const randomBytes = ethers.randomBytes(65);
    return ethers.hexlify(randomBytes);
}

async function addProofToFile(fileId: string) {
    const [deployer] = await ethers.getSigners();

    const dataRegistry = await ethers.getContractAt(
        dataRegistryContractName,
        process.env.DATA_REGISTRY_CONTRACT_ADDRESS as string,
    )

    const txAddProof = await dataRegistry.connect(deployer).addProof(fileId, {
        signature: generateRandomSignature(),
        data: {
            score: 0,
            dlpId: 12,
            metadata: "{\"_\": \"00000000000000000000000000000000\"}",
            proofUrl: "",
            instruction: "https://github.com/General-Tao-Ventures/primeinsights-satya-proof/releases/download/v17/my-proof-17.tar.gz",
        }
    })
    await txAddProof.wait();
    console.log("===> Added proof to the file: ", fileId);
}

async function findUnverifiedFiles(fileIds: string[]): Promise<string[]> {
    const dataRegistry = await ethers.getContractAt(
        dataRegistryContractName,
        process.env.DATA_REGISTRY_CONTRACT_ADDRESS as string,
    )

    const unverifiedFileIds = [];
    for (const fileId of fileIds) {
        const proof = await dataRegistry.fileProofs(fileId, 1);
        if (!proof.signature || proof.signature === "0x") {
            unverifiedFileIds.push(fileId.toString());
        }
    }

    return unverifiedFileIds;
}

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

    const fileIds = logs.map(log => dlp.interface.parseLog(log)?.args[2])
    return [...new Set(fileIds)];
}

async function main() {
    const fileIds = await findAllContributions();
    console.log(`Found ${fileIds.length} files`);

    const unverifiedFiles = await findUnverifiedFiles(fileIds);
    console.log(`Found ${unverifiedFiles.length} unverified files`);

    for (let i = 0; i < unverifiedFiles.length; i++) {
        await addProofToFile(unverifiedFiles[i])
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// console.log(generateRandomSignature())

// isVerified("1")
//     .then(() => process.exit(0))
//     .catch((error) => {
//         console.error(error);
//         process.exit(1);
//     });