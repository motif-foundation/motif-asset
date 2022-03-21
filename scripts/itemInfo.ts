import fs from 'fs-extra';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Wallet } from '@ethersproject/wallet';
import { ItemFactory } from '../typechain/ItemFactory';

async function start() {
  const args = require('minimist')(process.argv.slice(2), {
    string: ['tokenURI', 'metadataURI', 'contentHash', 'metadataHash'],
  });

  if (!args.chainId) {
    throw new Error('--chainId chain ID is required');
  }
  if (!args.tokenId && args.tokenId !== 0) {
    throw new Error('--tokenId token ID is required');
  }
  const path = `${process.cwd()}/.env.prod`;
  await require('dotenv').config({ path });
  const provider = new JsonRpcProvider(process.env.RPC_ENDPOINT);
  const wallet = new Wallet(`0x${process.env.PRIVATE_KEY}`, provider);
  const sharedAddressPath = `${process.cwd()}/addresses/${args.chainId}.json`;
  // @ts-ignore
  const addressBook = JSON.parse(await fs.readFileSync(sharedAddressPath));
  if (!addressBook.item) {
    throw new Error(`Item contract has not yet been deployed`);
  }

  const item = ItemFactory.connect(addressBook.item, wallet);

  const tokenURI = await item.tokenURI(args.tokenId);
  const contentHash = await item.tokenContentHashes(args.tokenId);
  const metadataURI = await item.tokenMetadataURI(args.tokenId);
  const metadataHash = await item.tokenMetadataHashes(args.tokenId);

  console.log(`Item Information for token ${args.tokenId}`);
  console.log({ tokenURI, contentHash, metadataURI, metadataHash });
}

start().catch((e: Error) => {
  console.error(e);
  process.exit(1);
});
