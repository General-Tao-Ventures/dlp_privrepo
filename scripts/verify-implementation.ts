import { run, upgrades } from "hardhat";

async function main() {
  const proxyAddress = process.env.DLP_PROXY_ADDRESS ?? "";
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);

  await run("verify:verify", {
    address: implementationAddress,
    force: true,
    constructorArguments: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
