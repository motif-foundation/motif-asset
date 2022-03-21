import fs from 'fs-extra';
import {readFileSync,  writeFileSync} from 'fs' 
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { ItemFactory } from '../typechain/ItemFactory';
import { ItemExchangeFactory } from '../typechain/ItemExchangeFactory';
import { AvatarFactory } from '../typechain/AvatarFactory';
import { AvatarExchangeFactory } from '../typechain/AvatarExchangeFactory';
import { SpaceFactory } from '../typechain/SpaceFactory';
import { SpaceExchangeFactory } from '../typechain/SpaceExchangeFactory';
import { LandFactory } from '../typechain/LandFactory';
import { LandExchangeFactory } from '../typechain/LandExchangeFactory';

async function start() {


 const landOperatorAddr = "0x75ce0516387D7B149E368e43ed585dF1f0F5C875"


  const args = require('minimist')(process.argv.slice(2));

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }
  const path = `${process.cwd()}/.env.prod`
  await require('dotenv').config({ path });
  const provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
  const wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;
  // @ts-ignore
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));
  // if (addressBook.itemExchange) {
  //   throw new Error(
  //     `itemExchange already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
  //   );
  // }
  // if (addressBook.item) {
  //   throw new Error(
  //     `item already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
  //   );
  // }


  //ITEM

  console.log('Deploying ItemExchange...');
  const deployTx = await new ItemExchangeFactory(wallet).deploy("8107");
  console.log('Deploy TX: ', deployTx.deployTransaction.hash);
  await deployTx.deployed();
  console.log('ItemExchange deployed at ', deployTx.address);
  addressBook.itemExchange = deployTx.address;

  console.log('Deploying Item...');
  const itemDeployTx = await new ItemFactory(wallet).deploy(
    addressBook.itemExchange,
    "Motif",
    "MOTIF",
    1000000,
    "8107"
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

 
  ///AVATAR
  if (addressBook.avatarExchange) {
    throw new Error(
      `avatarExchange already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  if (addressBook.avatar) {
    throw new Error(
      `avatar already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  console.log('Deploying AvatarExchange...');
  const adeployTx = await new AvatarExchangeFactory(wallet).deploy();
  console.log('Deploy TX: ', adeployTx.deployTransaction.hash);
  await adeployTx.deployed();
  console.log('AvatarExchange deployed at ', adeployTx.address);
  addressBook.avatarExchange = adeployTx.address;

  console.log('Deploying Avatar...');
  const avatarDeployTx = await new AvatarFactory(wallet).deploy(
    addressBook.avatarExchange 
  );
  console.log(`Deploy TX: ${avatarDeployTx.deployTransaction.hash}`);
  await avatarDeployTx.deployed();
  console.log(`Avatar deployed at ${avatarDeployTx.address}`);
  addressBook.avatar = avatarDeployTx.address;
  console.log('Configuring AvatarExchange...');
  const avatarExchange = AvatarExchangeFactory.connect(addressBook.avatarExchange, wallet);
  const atx = await avatarExchange.configure(addressBook.avatar);
  console.log(`AvatarExchange configuration tx: ${atx.hash}`);
  await atx.wait();
  console.log(`AvatarExchange configured.`);

  ///SPACE
  if (addressBook.spaceExchange) {
    throw new Error(
      `spaceExchange already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  if (addressBook.space) {
    throw new Error(
      `space already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  console.log('Deploying SpaceExchange...');
  const sdeployTx = await new SpaceExchangeFactory(wallet).deploy();
  console.log('Deploy TX: ', sdeployTx.deployTransaction.hash);
  await sdeployTx.deployed();
  console.log('SpaceExchange deployed at ', sdeployTx.address);
  addressBook.spaceExchange = sdeployTx.address;

  console.log('Deploying Space...');
  const spaceDeployTx = await new SpaceFactory(wallet).deploy(
    addressBook.spaceExchange
  );
  console.log(`Deploy TX: ${spaceDeployTx.deployTransaction.hash}`);
  await spaceDeployTx.deployed();
  console.log(`Space deployed at ${spaceDeployTx.address}`);
  addressBook.space = spaceDeployTx.address;
  console.log('Configuring SpaceExchange...');
  const spaceExchange = SpaceExchangeFactory.connect(addressBook.spaceExchange, wallet);
  const stx = await spaceExchange.configure(addressBook.space);
  console.log(`SpaceExchange configuration tx: ${stx.hash}`);
  await stx.wait();
  console.log(`SpaceExchange configured.`);


  ///LAND
  if (addressBook.landExchange) {
    throw new Error(
      `landExchange already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  if (addressBook.land) {
    throw new Error(
      `land already exists in address book at ${sharedAddressPath}. Please move it first so it is not overwritten`
    );
  }
  console.log('Deploying LandExchange...');
  const ldeployTx = await new LandExchangeFactory(wallet).deploy();
  console.log('Deploy TX: ', ldeployTx.deployTransaction.hash);
  await ldeployTx.deployed();
  console.log('LandExchange deployed at ', ldeployTx.address);
  addressBook.landExchange = ldeployTx.address;

  console.log('Deploying Land...');
  const landDeployTx = await new LandFactory(wallet).deploy(
    addressBook.landExchange, addressBook.space, landOperatorAddr
  );
  console.log(`Deploy TX: ${landDeployTx.deployTransaction.hash}`);
  await landDeployTx.deployed();
  console.log(`Land deployed at ${landDeployTx.address}`);
  addressBook.land = landDeployTx.address;
  console.log('Configuring LandExchange...');
  const landExchange = LandExchangeFactory.connect(addressBook.landExchange, wallet);
  const ltx = await landExchange.configure(addressBook.land);
  console.log(`LandExchange configuration tx: ${ltx.hash}`);
  await ltx.wait();
  console.log(`LandExchange configured.`);
 

  await writeFileSync(sharedAddressPath, JSON.stringify(addressBook, null, 2));
  console.log(`Contracts deployed and configured.`);



 


}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
