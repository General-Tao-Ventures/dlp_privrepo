import {
  upgradeProxy,
} from "./helpers";

const implementationContractName = "DLP";

async function main() {
  const proxyAddress = process.env.DLP_PROXY_ADDRESS ?? "";

  await upgradeProxy(proxyAddress, implementationContractName);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
