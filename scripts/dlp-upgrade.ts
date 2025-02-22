import {
  upgradeProxy,
} from "../deploy/helpers";

const implementationContractName = "DLP";

async function main() {
  const proxyAddress = process.env.DLP_PROXY_ADDRESS ?? "";

  await upgradeProxy(proxyAddress, implementationContractName);

  console.log("Successfully upgraded proxy.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
