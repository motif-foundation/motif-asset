import { ethers } from 'ethers';

export const privateKeys = [
  '0xd259aeb42538bb81254fc1ab36b3ab89e30a6bcc41c1b2d81d931c31d771e1d9',
  '0xb110391344b4d6de54c6905865fb184a58ce372e1f29e67d9b96a73df51cace6',
  '0x3f4337481d176f2dacc386681f794236a20d1967d0708c807e086e7c6ac8da44',
  '0x433995ba0714af8eee67ec8f5e68a91cc40f62abdf4442396dbbd4c8016ed4aa',
  '0x8386683bda31a8e6f380a1d0745483f36970a3d721623ba99b69d1563503f745',
  '0xa255d997d17a14b8a85e1ce9fcd99151c488edea13a6d67bf863b6cee8f74eae',
  '0x6b3a08d6950e30bd0b41bb7d1810f897b87697b8231658c18a363fd58448f9d6',
  '0x98488820eeb869611525ce1df54a700dc36ce0e67c8223f7cf1cf551e4324edb',
  '0xf5d1fd3fae7f96310a05ed0af35e2175b4ce289d8dae3159985dc85d27e09f16',
];

export function generatedWallets(provider: ethers.providers.BaseProvider) {
  return privateKeys.map((key: string) => {
    return new ethers.Wallet(key, provider);
  });
}

export async function signMessage(message: string, wallet: ethers.Wallet) {
  const messageHash = ethers.utils.id(message);
  const messageHashBytes = ethers.utils.arrayify(messageHash);
  const flatSig = await wallet.signMessage(messageHashBytes);
  return ethers.utils.arrayify(flatSig);
}
