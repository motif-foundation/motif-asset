import chai, { expect } from 'chai';
import asPromised from 'chai-as-promised';
import { JsonRpcProvider } from '@ethersproject/providers';
import { Blockchain } from '../utils/Blockchain';
import { generatedWallets } from '../utils/generatedWallets';
import { ItemExchangeFactory } from '../typechain/ItemExchangeFactory';
import { Wallet } from 'ethers';
import Decimal from '../utils/Decimal';
import { BigNumber, BigNumberish } from 'ethers';
import { formatUnits } from '@ethersproject/units';
import { AddressZero, MaxUint256 } from '@ethersproject/constants';
import { BaseErc20Factory } from '../typechain/BaseErc20Factory';
import { ItemExchange } from '../typechain/ItemExchange';

chai.use(asPromised);

let provider = new JsonRpcProvider();
let blockchain = new Blockchain(provider);

type DecimalValue = { value: BigNumber };

type BidShares = {
  owner: DecimalValue;
  prevOwner: DecimalValue;
  creator: DecimalValue;
};

type Ask = {
  currency: string;
  amount: BigNumberish;
};

type Bid = {
  currency: string;
  amount: BigNumberish;
  bidder: string;
  recipient: string;
  sellOnShare: { value: BigNumberish };
};

describe('ItemExchange', () => {
  let [
    deployerWallet,
    bidderWallet,
    mockTokenWallet,
    otherWallet,
  ] = generatedWallets(provider);

  let defaultBidShares = {
    prevOwner: Decimal.new(10),
    owner: Decimal.new(80),
    creator: Decimal.new(10),
  };

  let defaultTokenId = 1;
  let defaultAsk = {
    amount: 100,
    currency: '0x41A322b28D0fF354040e2CbC676F0320d8c8850d',
    sellOnShare: Decimal.new(0),
  };

  let listAddress: string;

  function toNumWei(val: BigNumber) {
    return parseFloat(formatUnits(val, 'wei'));
  }

  function toNumEther(val: BigNumber) {
    return parseFloat(formatUnits(val, 'ether'));
  }

  async function listAs(wallet: Wallet) {
    return ItemExchangeFactory.connect(listAddress, wallet);
  }
  async function deploy() {
    const list = await (
      await new ItemExchangeFactory(deployerWallet).deploy()
    ).deployed();
    listAddress = list.address;
  }
  async function configure() {
    return ItemExchangeFactory.connect(listAddress, deployerWallet).configure(
      mockTokenWallet.address
    );
  }

  async function readItemContract() {
    return ItemExchangeFactory.connect(
      listAddress,
      deployerWallet
    ).itemContract();
  }

  async function setBidShares(
    list: ItemExchange,
    tokenId: number,
    bidShares?: BidShares
  ) {
    return list.setBidShares(tokenId, bidShares);
  }

  async function setAsk(list: ItemExchange, tokenId: number, ask?: Ask) {
    return list.setAsk(tokenId, ask);
  }

  async function deployCurrency() {
    const currency = await new BaseErc20Factory(deployerWallet).deploy(
      'test',
      'TEST',
      18
    );
    return currency.address;
  }

  async function mintCurrency(currency: string, to: string, value: number) {
    await BaseErc20Factory.connect(currency, deployerWallet).mint(to, value);
  }

  async function approveCurrency(
    currency: string,
    spender: string,
    owner: Wallet
  ) {
    await BaseErc20Factory.connect(currency, owner).approve(
      spender,
      MaxUint256
    );
  }
  async function getBalance(currency: string, owner: string) {
    return BaseErc20Factory.connect(currency, deployerWallet).balanceOf(owner);
  }
  async function setBid(
    list: ItemExchange,
    bid: Bid,
    tokenId: number,
    spender?: string
  ) {
    await list.setBid(tokenId, bid, spender || bid.bidder);
  }

  beforeEach(async () => {
    await blockchain.resetAsync();
  });

  describe('#constructor', () => {
    it('should be able to deploy', async () => {
      await expect(deploy()).eventually.fulfilled;
    });
  });

  describe('#configure', () => {
    beforeEach(async () => {
      await deploy();
    });

    it('should revert if not called by the owner', async () => {
      await expect(
        ItemExchangeFactory.connect(listAddress, otherWallet).configure(
          mockTokenWallet.address
        )
      ).eventually.rejectedWith('ItemExchange: Only owner');
    });

    it('should be callable by the owner', async () => {
      await expect(configure()).eventually.fulfilled;
      const tokenContractAddress = await readItemContract();

      expect(tokenContractAddress).eq(mockTokenWallet.address);
    });

    it('should reject if called twice', async () => {
      await configure();

      await expect(configure()).eventually.rejectedWith(
        'ItemExchange: Already configured'
      );
    });
  });

  describe('#setBidShares', () => {
    beforeEach(async () => {
      await deploy();
      await configure();
    });

    it('should reject if not called by the item address', async () => {
      const list = await listAs(otherWallet);

      await expect(
        setBidShares(list, defaultTokenId, defaultBidShares)
      ).rejectedWith('ItemExchange: Only item contract');
    });

    it('should set the bid shares if called by the item address', async () => {
      const list = await listAs(mockTokenWallet);

      await expect(setBidShares(list, defaultTokenId, defaultBidShares))
        .eventually.fulfilled;

      const tokenBidShares = Object.values(
        await list.bidSharesForToken(defaultTokenId)
      ).map((s) => parseInt(formatUnits(s.value, 'ether')));

      expect(tokenBidShares[0]).eq(
        toNumEther(defaultBidShares.prevOwner.value)
      );
      expect(tokenBidShares[1]).eq(toNumEther(defaultBidShares.creator.value));
      expect(tokenBidShares[2]).eq(toNumEther(defaultBidShares.owner.value));
    });

    it('should emit an event when bid shares are updated', async () => {
      const list = await listAs(mockTokenWallet);

      const block = await provider.getBlockNumber();
      await setBidShares(list, defaultTokenId, defaultBidShares);
      const events = await list.queryFilter(
        list.filters.BidShareUpdated(null, null),
        block
      );
      expect(events.length).eq(1);
      const logDescription = list.interface.parseLog(events[0]);
      expect(toNumWei(logDescription.args.tokenId)).to.eq(defaultTokenId);
      expect(toNumWei(logDescription.args.bidShares.prevOwner.value)).to.eq(
        toNumWei(defaultBidShares.prevOwner.value)
      );
      expect(toNumWei(logDescription.args.bidShares.creator.value)).to.eq(
        toNumWei(defaultBidShares.creator.value)
      );
      expect(toNumWei(logDescription.args.bidShares.owner.value)).to.eq(
        toNumWei(defaultBidShares.owner.value)
      );
    });

    it('should reject if the bid shares are invalid', async () => {
      const list = await listAs(mockTokenWallet);
      const invalidBidShares = {
        prevOwner: Decimal.new(0),
        owner: Decimal.new(0),
        creator: Decimal.new(101),
      };

      await expect(
        setBidShares(list, defaultTokenId, invalidBidShares)
      ).rejectedWith('ItemExchange: Invalid bid shares, must sum to 100');
    });
  });

  describe('#setAsk', () => {
    beforeEach(async () => {
      await deploy();
      await configure();
    });

    it('should reject if not called by the item address', async () => {
      const list = await listAs(otherWallet);

      await expect(setAsk(list, defaultTokenId, defaultAsk)).rejectedWith(
        'ItemExchange: Only item contract'
      );
    });

    it('should set the ask if called by the item address', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);

      await expect(setAsk(list, defaultTokenId, defaultAsk)).eventually
        .fulfilled;

      const ask = await list.currentAskForToken(defaultTokenId);

      expect(toNumWei(ask.amount)).to.eq(defaultAsk.amount);
      expect(ask.currency).to.eq(defaultAsk.currency);
    });

    it('should emit an event if the ask is updated', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);

      const block = await provider.getBlockNumber();
      await setAsk(list, defaultTokenId, defaultAsk);
      const events = await list.queryFilter(
        list.filters.AskCreated(null, null),
        block
      );

      expect(events.length).eq(1);
      const logDescription = list.interface.parseLog(events[0]);
      expect(toNumWei(logDescription.args.tokenId)).to.eq(defaultTokenId);
      expect(toNumWei(logDescription.args.ask.amount)).to.eq(defaultAsk.amount);
      expect(logDescription.args.ask.currency).to.eq(defaultAsk.currency);
    });

    it('should reject if the ask is too low', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);

      await expect(
        setAsk(list, defaultTokenId, {
          amount: 1,
          currency: AddressZero,
        })
      ).rejectedWith('ItemExchange: Ask invalid for share splitting');
    });

    it("should reject if the bid shares haven't been set yet", async () => {
      const list = await listAs(mockTokenWallet);
      await expect(setAsk(list, defaultTokenId, defaultAsk)).rejectedWith(
        'ItemExchange: Invalid bid shares for token'
      );
    });
  });

  describe('#setBid', () => {
    let currency: string;
    const defaultBid = {
      amount: 100,
      currency: currency,
      bidder: bidderWallet.address,
      recipient: otherWallet.address,
      spender: bidderWallet.address,
      sellOnShare: Decimal.new(10),
    };

    beforeEach(async () => {
      await deploy();
      await configure();
      currency = await deployCurrency();
      defaultBid.currency = currency;
    });

    it('should revert if not called by the item contract', async () => {
      const list = await listAs(otherWallet);
      await expect(setBid(list, defaultBid, defaultTokenId)).rejectedWith(
        'ItemExchange: Only item contract'
      );
    });

    it('should revert if the bidder does not have a high enough allowance for their bidding currency', async () => {
      const list = await listAs(mockTokenWallet);
      await expect(setBid(list, defaultBid, defaultTokenId)).rejectedWith(
        'SafeERC20: ERC20 operation did not succeed'
      );
    });

    it('should revert if the bidder does not have enough tokens to bid with', async () => {
      const list = await listAs(mockTokenWallet);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount - 1);
      await approveCurrency(currency, list.address, bidderWallet);

      await expect(setBid(list, defaultBid, defaultTokenId)).rejectedWith(
        'SafeERC20: ERC20 operation did not succeed'
      );
    });

    it('should revert if the bid currency is 0 address', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount);
      await approveCurrency(currency, list.address, bidderWallet);

      await expect(
        setBid(
          list,
          { ...defaultBid, currency: AddressZero },
          defaultTokenId
        )
      ).rejectedWith('ItemExchange: bid currency cannot be 0 address');
    });

    it('should revert if the bid recipient is 0 address', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount);
      await approveCurrency(currency, list.address, bidderWallet);

      await expect(
        setBid(
          list,
          { ...defaultBid, recipient: AddressZero },
          defaultTokenId
        )
      ).rejectedWith('ItemExchange: bid recipient cannot be 0 address');
    });

    it('should revert if the bidder bids 0 tokens', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount);
      await approveCurrency(currency, list.address, bidderWallet);

      await expect(
        setBid(list, { ...defaultBid, amount: 0 }, defaultTokenId)
      ).rejectedWith('ItemExchange: cannot bid amount of 0');
    });

    it('should accept a valid bid', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);
      await mintCurrency(currency, defaultBid.bidder, defaultBid.amount);
      await approveCurrency(currency, list.address, bidderWallet);

      const beforeBalance = toNumWei(
        await getBalance(currency, defaultBid.bidder)
      );

      await expect(setBid(list, defaultBid, defaultTokenId)).fulfilled;

      const afterBalance = toNumWei(
        await getBalance(currency, defaultBid.bidder)
      );
      const bid = await list.bidForTokenBidder(1, bidderWallet.address);
      expect(bid.currency).eq(currency);
      expect(toNumWei(bid.amount)).eq(defaultBid.amount);
      expect(bid.bidder).eq(defaultBid.bidder);
      expect(beforeBalance).eq(afterBalance + defaultBid.amount);
    });

    it('should accept a valid bid larger than the min bid', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);

      const largerValidBid = {
        amount: 130000000,
        currency: currency,
        bidder: bidderWallet.address,
        recipient: otherWallet.address,
        spender: bidderWallet.address,
        sellOnShare: Decimal.new(10),
      };

      await mintCurrency(
        currency,
        largerValidBid.bidder,
        largerValidBid.amount
      );
      await approveCurrency(currency, list.address, bidderWallet);

      const beforeBalance = toNumWei(
        await getBalance(currency, defaultBid.bidder)
      );

      await expect(setBid(list, largerValidBid, defaultTokenId)).fulfilled;

      const afterBalance = toNumWei(
        await getBalance(currency, largerValidBid.bidder)
      );
      const bid = await list.bidForTokenBidder(1, bidderWallet.address);
      expect(bid.currency).eq(currency);
      expect(toNumWei(bid.amount)).eq(largerValidBid.amount);
      expect(bid.bidder).eq(largerValidBid.bidder);
      expect(beforeBalance).eq(afterBalance + largerValidBid.amount);
    });

    it('should refund the original bid if the bidder bids again', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);
      await mintCurrency(currency, defaultBid.bidder, 5000);
      await approveCurrency(currency, list.address, bidderWallet);

      const bidderBalance = toNumWei(
        await BaseErc20Factory.connect(currency, bidderWallet).balanceOf(
          bidderWallet.address
        )
      );

      await setBid(list, defaultBid, defaultTokenId);
      await expect(
        setBid(
          list,
          { ...defaultBid, amount: defaultBid.amount * 2 },
          defaultTokenId
        )
      ).fulfilled;

      const afterBalance = toNumWei(
        await BaseErc20Factory.connect(currency, bidderWallet).balanceOf(
          bidderWallet.address
        )
      );
      await expect(afterBalance).eq(bidderBalance - defaultBid.amount * 2);
    });

    it('should emit a bid event', async () => {
      const list = await listAs(mockTokenWallet);
      await setBidShares(list, defaultTokenId, defaultBidShares);
      await mintCurrency(currency, defaultBid.bidder, 5000);
      await approveCurrency(currency, list.address, bidderWallet);

      const block = await provider.getBlockNumber();
      await setBid(list, defaultBid, defaultTokenId);
      const events = await list.queryFilter(
        list.filters.BidCreated(null, null),
        block
      );

      expect(events.length).eq(1);
      const logDescription = list.interface.parseLog(events[0]);
      expect(toNumWei(logDescription.args.tokenId)).to.eq(defaultTokenId);
      expect(toNumWei(logDescription.args.bid.amount)).to.eq(defaultBid.amount);
      expect(logDescription.args.bid.currency).to.eq(defaultBid.currency);
      expect(toNumWei(logDescription.args.bid.sellOnShare.value)).to.eq(
        toNumWei(defaultBid.sellOnShare.value)
      );
    });
  });
});
