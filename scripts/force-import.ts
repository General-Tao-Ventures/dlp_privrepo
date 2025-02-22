import { ethers, upgrades } from 'hardhat';

const implementationContractName = "DLP";

async function main() {
    const proxyAddress = process.env.DLP_PROXY_ADDRESS ?? "";
    const implementationContract = await ethers.getContractFactory(implementationContractName);

    // Force import the proxy into the upgrades system
    console.log(`Registering proxy at ${proxyAddress}...`);
    const importedProxy = await upgrades.forceImport(proxyAddress, implementationContract);
    console.log(`Proxy registered. Address: ${await importedProxy.getAddress()}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
