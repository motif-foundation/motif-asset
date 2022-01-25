import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { ItemFactory } from '../typechain/ItemFactory';
import { ItemExchangeFactory } from '../typechain/ItemExchangeFactory';

async function start() {
  const args = require('minimist')(process.argv.slice(2));

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }
  const path = `${process.cwd()}/.env${
    args.chainId === 7018 ? '.prod' : args.chainId === 4 ? '.dev' : '.local'
  }`;
  await require('dotenv').config({ path });
  const provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
  const wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;
  // @ts-ignore
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));
  if (addressBook.itemExchange) {
    throw new Error(
      `itemExchange already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  if (addressBook.item) {
    throw new Error(
      `item already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }

  console.log('Deploying ItemExchange...');
  const deployTx = await new ItemExchangeFactory(wallet).deploy();
  console.log('Deploy TX: ', deployTx.deployTransaction.hash);
  await deployTx.deployed();
  console.log('ItemExchange deployed at ', deployTx.address);
  addressBook.itemExchange = deployTx.address;

  console.log('Deploying Item...');
  const itemDeployTx = await new ItemFactory(wallet).deploy(
    addressBook.itemExchange,
    "Motif",
    "MOTIF",
    1000000
  );
  console.log(`Deploy TX: ${itemDeployTx.deployTransaction.hash}`);
  await itemDeployTx.deployed();
  console.log(`Item deployed at ${itemDeployTx.address}`);
  addressBook.item = itemDeployTx.address;

  console.log('Configuring ItemExchange...');
  const itemExchange = ItemExchangeFactory.connect(addressBook.itemExchange, wallet);
  const tx = await itemExchange.configure(addressBook.item);
  console.log(`ItemExchange configuration tx: ${tx.hash}`);
  await tx.wait();
  console.log(`ItemExchange configured.`);

  await fs.writeFile(sharedAddressPath, JSON.stringify(addressBook, null, 2));
  console.log(`Contracts deployed and configured. `);
}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
