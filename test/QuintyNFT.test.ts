import { expect } from "chai";
import { ethers } from "hardhat";

describe("QuintyNFT MVP", function () {
  let quintyNFT: any;
  let owner: any;
  let user1: any;
  let user2: any;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const QuintyNFT = await ethers.getContractFactory("QuintyNFT");
    quintyNFT = await QuintyNFT.deploy("ipfs://QmBaseURI/");
    await quintyNFT.waitForDeployment();
  });

  describe("Badge Minting", function () {
    it("Should mint BountyCreator badge", async function () {
      await expect(quintyNFT.mintBadge(user1.address, 0, "ipfs://creator-badge/"))
        .to.emit(quintyNFT, "BadgeMinted");

      expect(await quintyNFT.ownerOf(1)).to.equal(user1.address);
    });

    it("Should mint only MVP badge types", async function () {
      await quintyNFT.mintBadge(user1.address, 0, "ipfs://creator-badge/"); // BountyCreator
      await quintyNFT.mintBadge(user1.address, 1, "ipfs://solver-badge/"); // BountySolver
      await quintyNFT.mintBadge(user1.address, 2, "ipfs://team-badge/"); // TeamMember

      expect(await quintyNFT.balanceOf(user1.address)).to.equal(3);
    });

    it("Should prevent non-authorized from minting", async function () {
      await expect(
        quintyNFT.connect(user1).mintBadge(user2.address, 0, "ipfs://badge/")
      ).to.be.revertedWith("Not authorized to mint");
    });
  });

  describe("Soulbound Behavior", function () {
    it("Should prevent transfers", async function () {
      await quintyNFT.mintBadge(user1.address, 0, "ipfs://badge/");
      await expect(
        quintyNFT.connect(user1).transferFrom(user1.address, user2.address, 1)
      ).to.be.revertedWith("Soulbound: Transfer not allowed");
    });
  });
});
