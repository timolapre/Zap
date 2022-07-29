const { expect } = require("chai");
const { expectRevert, time, ether, constants, BN } = require('@openzeppelin/test-helpers');
const { accounts, contract } = require('@openzeppelin/test-environment');

const Zap = contract.fromArtifact("ZapFullV0");
const dex = undefined;

describe("Zap", function () {
    this.timeout("60000");
    beforeEach(async () => {
        const [owner, feeTo, alice, bob, carol] = accounts;
        this.owner = owner;
        this.feeTo = feeTo;
        this.alice = alice;
        this.bob = bob;
        this.carol = carol;

        const {
            dexFactory,
            dexRouter,
            mockWBNB,
            mockTokens,
            dexPairs,
        } = await dex.deployMockDex([owner, feeTo, alice], 4); // accounts passed will be used in the deployment
        this.dexFactory = dexFactory;
        this.dexRouter = dexRouter;
        this.mockWBNB = mockWBNB;
        this.dogecoin = mockTokens[0];
        this.bitcoin = mockTokens[1];
        this.ethereum = mockTokens[2];
        this.busd = mockTokens[3];
        this.dexPairs = dexPairs;

        await this.dogecoin.mint(ether("3000"));
        await this.bitcoin.mint(ether("3000"));
        await this.ethereum.mint(ether("3000"));
        await this.busd.mint(ether("3000"));
        await this.dogecoin.mint(ether("1000"), { from: alice });
        await this.bitcoin.mint(ether("1000"), { from: alice });
        await this.ethereum.mint(ether("1000"), { from: alice });
        await this.busd.mint(ether("1000"), { from: alice });

        await this.dogecoin.approve(this.dexRouter.address, ether("3000"));
        await this.bitcoin.approve(this.dexRouter.address, ether("3000"));
        await this.ethereum.approve(this.dexRouter.address, ether("3000"));
        await this.busd.approve(this.dexRouter.address, ether("3000"));

        await this.dexRouter.addLiquidity(this.dogecoin.address, this.bitcoin.address, ether("1000"), ether("1000"), 0, 0, owner, "9999999999");
        await this.dexRouter.addLiquidity(this.dogecoin.address, this.ethereum.address, ether("1000"), ether("1000"), 0, 0, owner, "9999999999");
        await this.dexRouter.addLiquidity(this.bitcoin.address, this.ethereum.address, ether("1000"), ether("1000"), 0, 0, owner, "9999999999");
        await this.dexRouter.addLiquidity(this.dogecoin.address, this.busd.address, ether("1000"), ether("1000"), 0, 0, owner, "9999999999");

        this.zapContract = await Zap.new(this.dexRouter.address);

        await this.dogecoin.approve(this.zapContract.address, ether("1000"), { from: alice });
        await this.bitcoin.approve(this.zapContract.address, ether("1000"), { from: alice });
        await this.ethereum.approve(this.zapContract.address, ether("1000"), { from: alice });
        await this.busd.approve(this.zapContract.address, ether("1000"), { from: alice });
    });

    it("Should be able to do a token -> token-token zap", async () => {
        const lp = await this.dexFactory.getPair(this.dogecoin.address, this.bitcoin.address);
        const lpContract = contract.fromArtifact('IUniswapPair', lp);
        const balanceBefore = await lpContract.balanceOf(this.alice);

        await this.zapContract.zap(this.dogecoin.address, ether("1"), [this.dogecoin.address, this.bitcoin.address], [], [this.dogecoin.address, this.bitcoin.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice });

        const balanceAfter = await lpContract.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore));
    });

    it("Should be able to do a token -> different token-token zap", async () => {
        const lp = await this.dexFactory.getPair(this.ethereum.address, this.bitcoin.address);
        const lpContract = contract.fromArtifact('IUniswapPair', lp);
        const balanceBefore = await lpContract.balanceOf(this.alice);

        await this.zapContract.zap(this.dogecoin.address, ether("1"), [this.ethereum.address, this.bitcoin.address], [this.dogecoin.address, this.ethereum.address], [this.dogecoin.address, this.bitcoin.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice });

        const balanceAfter = await lpContract.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore));
    });

    it("Should be able to do a token -> native-token zap", async () => {
        const lp = await this.dexFactory.getPair(this.dogecoin.address, this.mockWBNB.address);
        const lpContract = contract.fromArtifact('IUniswapPair', lp);
        const balanceBefore = await lpContract.balanceOf(this.alice);

        await this.zapContract.zap(this.dogecoin.address, ether("1"), [this.dogecoin.address, this.mockWBNB.address], [], [this.dogecoin.address, this.mockWBNB.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice });

        const balanceAfter = await lpContract.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore));
    });

    it("Should be able to do a wrapped -> token-token zap", async () => {
        const lp = await this.dexFactory.getPair(this.ethereum.address, this.bitcoin.address);
        const lpContract = contract.fromArtifact('IUniswapPair', lp);
        const balanceBefore = await lpContract.balanceOf(this.alice);

        await this.mockWBNB.deposit({ from: this.alice, value: ether("1") })
        await this.mockWBNB.approve(this.zapContract.address, ether("1000"), { from: this.alice });

        await this.zapContract.zap(this.mockWBNB.address, ether("0.01"), [this.ethereum.address, this.bitcoin.address], [this.mockWBNB.address, this.ethereum.address], [this.mockWBNB.address, this.bitcoin.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice });

        const balanceAfter = await lpContract.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore));
    });

    it("Should be able to do a wrapped -> native-token zap", async () => {
        const lp = await this.dexFactory.getPair(this.mockWBNB.address, this.bitcoin.address);
        const lpContract = contract.fromArtifact('IUniswapPair', lp);
        const balanceBefore = await lpContract.balanceOf(this.alice);

        await this.mockWBNB.deposit({ from: this.alice, value: ether("1") })
        await this.mockWBNB.approve(this.zapContract.address, ether("1000"), { from: this.alice });

        await this.zapContract.zap(this.mockWBNB.address, ether("0.01"), [this.mockWBNB.address, this.bitcoin.address], [], [this.mockWBNB.address, this.bitcoin.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice });

        const balanceAfter = await lpContract.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore));
    });

    it("Should be able to do a native -> token-token zap", async () => {
        const lp = await this.dexFactory.getPair(this.dogecoin.address, this.bitcoin.address);
        const lpContract = contract.fromArtifact('IUniswapPair', lp);
        const balanceBefore = await lpContract.balanceOf(this.alice);

        await this.zapContract.zapNative([this.dogecoin.address, this.bitcoin.address], [this.mockWBNB.address, this.dogecoin.address], [this.mockWBNB.address, this.bitcoin.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice, value: ether("1") });

        const balanceAfter = await lpContract.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore));
    });

    it("Should be able to do a native -> native-token zap", async () => {
        const lp = await this.dexFactory.getPair(this.dogecoin.address, this.mockWBNB.address);
        const lpContract = contract.fromArtifact('IUniswapPair', lp);
        const balanceBefore = await lpContract.balanceOf(this.alice);

        await this.zapContract.zapNative([this.dogecoin.address, this.mockWBNB.address], [this.mockWBNB.address, this.dogecoin.address], [], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice, value: ether("1") });

        const balanceAfter = await lpContract.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore));
    });

    it("Should receive dust back", async () => {
        const tokenContract0 = contract.fromArtifact('IERC20', this.dogecoin.address);
        const tokenContract1 = contract.fromArtifact('IERC20', this.bitcoin.address);
        const balanceBefore = await tokenContract0.balanceOf(this.alice);

        await this.zapContract.zap(this.dogecoin.address, ether("1"), [this.dogecoin.address, this.bitcoin.address], [], [this.dogecoin.address, this.bitcoin.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice });

        const balanceAfter = await tokenContract0.balanceOf(this.alice);
        expect(Number(balanceAfter)).gt(Number(balanceBefore) - Number(ether("1")));

        const token0Balance = await tokenContract0.balanceOf(this.zapContract.address);
        const token1Balance = await tokenContract1.balanceOf(this.zapContract.address);
        expect(Number(token0Balance)).equal(0);
        expect(Number(token1Balance)).equal(0);
    });

    it("Should revert for non existing pair", async () => {
        await expectRevert(this.zapContract.zap(this.dogecoin.address, ether("1"), [this.bitcoin.address, this.busd.address], [this.dogecoin.address, this.bitcoin.address], [this.dogecoin.address, this.busd.address], [0, 0], [0, 0], this.alice, "9999999999", { from: this.alice }), "Zap: Pair doesn't exist -- Reason given: Zap: Pair doesn't exist.");
    });
});