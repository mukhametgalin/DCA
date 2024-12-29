const hre = require("hardhat");

async function main() {
  // Адрес Uniswap Router для вашей сети
  const UNISWAP_ROUTER_ADDRESS = "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E"; // Замените на адрес роутера вашей сети

  // Компилируем контракт
  const DCAContract = await hre.ethers.getContractFactory("DCAContract");

  // Разворачиваем контракт
  const dcaContract = await DCAContract.deploy(UNISWAP_ROUTER_ADDRESS);

  await dcaContract.deployed();

  console.log("DCAContract deployed to:", dcaContract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
