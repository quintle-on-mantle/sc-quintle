import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Quinty MVP System", function () {
  let quinty: any;
  let reputation: any;
  let nft: any;
  let owner: any;
  let creator: any;
  let solver1: any;
  let solver2: any;
  let addrs: any[];

  const BOUNTY_AMOUNT = ethers.parseEther("1.0"); // 1 ETH
  const SUBMISSION_DEPOSIT = ethers.parseEther("0.1"); // 10% of bounty

  beforeEach(async function () {
    [owner, creator, solver1, solver2, ...addrs] = await ethers.getSigners();

    // Deploy contracts
    const QuintyReputation = await ethers.getContractFactory("QuintyReputation");
    reputation = await QuintyReputation.deploy("ipfs://QmReputation/");
    await reputation.waitForDeployment();

    const Quinty = await ethers.getContractFactory("Quinty");
    quinty = await Quinty.deploy();
    await quinty.waitForDeployment();

    const QuintyNFT = await ethers.getContractFactory("QuintyNFT");
    nft = await QuintyNFT.deploy("ipfs://QmNFT/");
    await nft.waitForDeployment();

    // Set up connections
    await quinty.setAddresses(await reputation.getAddress(), await nft.getAddress());
    await reputation.transferOwnership(await quinty.getAddress());
    await nft.authorizeMinter(await quinty.getAddress());
  });

  describe("Bounty Creation", function () {
    it("Should create a bounty with escrow", async function () {
      const deadline = (await time.latest()) + 86400;

      await expect(
        quinty
          .connect(creator)
          .createBounty(
            "Test bounty description",
            deadline,
            false,
            [],
            3000, // 30% slash percent (unused in MVP but required by param)
            false,
            0,
            { value: BOUNTY_AMOUNT }
          )
      )
        .to.emit(quinty, "BountyCreated")
        .withArgs(1, creator.address, BOUNTY_AMOUNT, deadline, false);

      const bounty = await quinty.getBountyData(1);
      expect(bounty.creator).to.equal(creator.address);
      expect(bounty.amount).to.equal(BOUNTY_AMOUNT);
      expect(bounty.status).to.equal(1); // OPEN
    });
  });

  describe("Submissions and Winners", function () {
    beforeEach(async function () {
      const deadline = (await time.latest()) + 86400;
      await quinty.connect(creator).createBounty("Test", deadline, false, [], 3000, false, 0, { value: BOUNTY_AMOUNT });
    });

    it("Should accept submissions", async function () {
      await expect(
        quinty.connect(solver1).submitSolution(1, "QmBlinded", [], { value: SUBMISSION_DEPOSIT })
      ).to.emit(quinty, "SubmissionCreated");
    });

    it("Should allow creator to select winner and winner to reveal", async function () {
      await quinty.connect(solver1).submitSolution(1, "QmBlinded", [], { value: SUBMISSION_DEPOSIT });

      await quinty.connect(creator).selectWinners(1, [solver1.address], [0]);

      const bountyAfterSelect = await quinty.getBountyData(1);
      expect(bountyAfterSelect.status).to.equal(2); // PENDING_REVEAL

      await expect(quinty.connect(solver1).revealSolution(1, 0, "QmRevealed"))
        .to.emit(quinty, "SolutionRevealed");

      const bountyAfterReveal = await quinty.getBountyData(1);
      expect(bountyAfterReveal.status).to.equal(3); // RESOLVED
    });
  });

  describe("Reputation and NFTs", function () {
    it("Should update reputation stats", async function () {
      const deadline = (await time.latest()) + 86400;
      await quinty.connect(creator).createBounty("Test", deadline, false, [], 3000, false, 0, { value: BOUNTY_AMOUNT });

      const stats = await reputation.getUserStats(creator.address);
      expect(stats.totalBountiesCreated).to.equal(1);
    });

    it("Should mint NFT badge on win", async function () {
      const deadline = (await time.latest()) + 86400;
      await quinty.connect(creator).createBounty("Test", deadline, false, [], 3000, false, 0, { value: BOUNTY_AMOUNT });
      await quinty.connect(solver1).submitSolution(1, "QmBlinded", [], { value: SUBMISSION_DEPOSIT });
      await quinty.connect(creator).selectWinners(1, [solver1.address], [0]);

      // Reveal triggers the win record which triggers NFT minting in QuintyNFT if authorized
      // Note: QuintyNFT minting logic is separate from Reputation milestones
      await quinty.connect(solver1).revealSolution(1, 0, "QmRevealed");

      // Check if solver1 got a badge
      const badges = await nft.getUserBadges(solver1.address);
      expect(badges.length).to.be.greaterThan(0);
    });
  });
});