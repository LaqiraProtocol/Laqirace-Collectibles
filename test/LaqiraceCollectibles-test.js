const { expect } = require("chai");
const { ethers } = require("hardhat");
const { constants } = require('@openzeppelin/test-helpers');

describe("LaqiraceCollectibles", function () {
    let laqiraceCollectibles, LaqiraceCollectibles, BEP20token, TokenContract;
    let owner, minter, mintingFeeAddress, anotherAddress;
    beforeEach(async function () {
        [owner, minter, mintingFeeAddress, anotherAddress] = await ethers.getSigners();
        laqiraceCollectibles = await ethers.getContractFactory("LaqiraceCollectibles");
        BEP20token = await ethers.getContractFactory("QuoteToken");
        TokenContract = await BEP20token.deploy('Quote', 'QT', '10000000000000000000000000000');
        LaqiraceCollectibles = await laqiraceCollectibles.deploy(minter.address, mintingFeeAddress.address);
        await LaqiraceCollectibles.deployed();
    });

    let collectibleName, figure, price, raceCost;
    collectibleName = "Laqira";
    figure = "IPFS://carImage";
    price = "2000000000000000000"; // 2 BUSD
    raceCost = "10000000000000000000"; // 10 LQR
    maxRaces = 5;
    data = {
        collectibleName,
        figure,
        price,
        raceCost,
        maxRaces
    }

    describe('importCollectible', function () {
        it("Trigger", async function () {
            const expectedSig = generateSigUsingEthers(data);
            await expect(LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces)).to.emit(LaqiraceCollectibles, 'ImportCollectible').withArgs(collectibleName, figure, price, raceCost, maxRaces, expectedSig);
            
            await expect(LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces)).to.be.revertedWith('Collectible already exists');

            const collectbleData = await LaqiraceCollectibles.getCollectibleData(expectedSig);
            expect(collectbleData['name']).to.equal(collectibleName);
            expect(collectbleData['figure']).to.equal(figure);
            expect(collectbleData['price']).to.equal(price);
            expect(collectbleData['raceCost']).to.equal(raceCost);
            expect(collectbleData['maxRaces']).to.equal(maxRaces);

            expect(await LaqiraceCollectibles.getCollectibleSigByName(collectibleName)).to.equal(expectedSig);
            expect((await LaqiraceCollectibles.getCollectiblesSigs())[0]).to.equal(expectedSig);
        });

        it("Only Owner", async function () {
            await expect(LaqiraceCollectibles.connect(anotherAddress).importCollectible(collectibleName, figure, price, raceCost, maxRaces)).to.be.revertedWith('Ownable: caller is not the owner');
        });
    });

    /*
        NOTE:
            permissions:
                salePermit: true
                preSale: false
                saleByRequest: false

    */
    describe("mintCollectible", function () {
        let collectibleSig;
        let approveAmount = price;
        let expectedTokenId = 1;
        
        beforeEach(async function () {
            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);
            collectibleSig = (await LaqiraceCollectibles.getCollectiblesSigs())[0];
        });
        it("Trigger", async function () {
            await LaqiraceCollectibles.setSaleStatus(collectibleSig, 10, true, false, false);
            const CollectibleSaleData = await LaqiraceCollectibles.getCollectibleSaleData(collectibleSig);
            expect(CollectibleSaleData['maxSupply']).to.equal(10);
            expect(CollectibleSaleData['totalSupply']).to.equal(0);
            expect(CollectibleSaleData['salePermit']).to.be.true;
            expect(CollectibleSaleData['preSale']).to.be.false;
            expect(CollectibleSaleData['saleByRequest']).to.be.false;

            // Add quote Token
            await LaqiraceCollectibles.addQuoteToken(TokenContract.address);
            
            expect(await LaqiraceCollectibles.totalSupply()).to.equal(0);

            // payment section
            await TokenContract.approve(LaqiraceCollectibles.address, approveAmount);
            await LaqiraceCollectibles.mintCollectible(collectibleSig, TokenContract.address);

            expect(await LaqiraceCollectibles.totalSupply()).to.equal(1);
            const CollectibleSaleData2 = await LaqiraceCollectibles.getCollectibleSaleData(collectibleSig);
            expect(CollectibleSaleData2['totalSupply']).to.equal('1');
            expect(await LaqiraceCollectibles.tokenOfOwnerByIndex(owner.address, 0)).to.equal(expectedTokenId);
            let tokenIdAttr = await LaqiraceCollectibles.getTokenIdAttr(expectedTokenId);
            expect(tokenIdAttr['collectible']).to.equal(collectibleSig);
            expect(tokenIdAttr['collectibleNum']).to.equal(1);
        });

        it("Max supply", async function () {
            let newApproveAmount = '4000000000000000000';
            let maxSupply = 2;
            await LaqiraceCollectibles.setSaleStatus(collectibleSig, maxSupply, true, false, false);

            await LaqiraceCollectibles.addQuoteToken(TokenContract.address);
            await TokenContract.approve(LaqiraceCollectibles.address, newApproveAmount);
            for (let index = 0; index < maxSupply; index++) {
                await LaqiraceCollectibles.mintCollectible(collectibleSig, TokenContract.address);
            }

            expect(await LaqiraceCollectibles.totalSupply()).to.equal(2);
            expect(await TokenContract.balanceOf(mintingFeeAddress.address)).to.equal(newApproveAmount);
            await expect(LaqiraceCollectibles.mintCollectible(collectibleSig, TokenContract.address)).to.be.revertedWith('Max supply for the collectible was reached');
            
            let tokenIdAttr = await LaqiraceCollectibles.getTokenIdAttr(2);
            expect(tokenIdAttr['collectibleNum']).to.equal(2);
        });
    });

    /*
        NOTE:
            permissions:
                salePermit: true
                preSale: true
                saleByRequest: false

    */
    describe("preSaleCollectible" ,function () {
        let collectibleSig;
        let approveAmount = price;
        let expectedTokenId = 1;
        
        beforeEach(async function () {
            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);
            collectibleSig = (await LaqiraceCollectibles.getCollectiblesSigs())[0];
        });
        it("Trigger", async function () {
            await LaqiraceCollectibles.setSaleStatus(collectibleSig, 10, true, true, false);
            
            await LaqiraceCollectibles.addQuoteToken(TokenContract.address);

            expect(await LaqiraceCollectibles.totalSupply()).to.equal(0);

            await TokenContract.approve(LaqiraceCollectibles.address, approveAmount);

            await LaqiraceCollectibles.preSaleCollectible(collectibleSig, TokenContract.address);
            
            expect(await LaqiraceCollectibles.totalSupply()).to.equal(1);
            const CollectibleSaleData = await LaqiraceCollectibles.getCollectibleSaleData(collectibleSig);
            expect(CollectibleSaleData['totalSupply']).to.equal('1');
            expect(await LaqiraceCollectibles.tokenOfOwnerByIndex(owner.address, 0)).to.equal(expectedTokenId);
            expect(await LaqiraceCollectibles.getUserPreSaleStatus(owner.address, collectibleName)).to.be.true;
            let tokenIdAttr = await LaqiraceCollectibles.getTokenIdAttr(expectedTokenId);
            expect(tokenIdAttr['collectible']).to.equal(collectibleSig);
            expect(tokenIdAttr['collectibleNum']).to.equal(1);
            await expect(LaqiraceCollectibles.preSaleCollectible(collectibleSig, TokenContract.address)).to.be.revertedWith('Player has already bought the collectible in presale stage');
        });
    });

    describe("requestForMint", function () {
        let collectibleSig;
        let approveAmount = price;
        let expectedTokenId = 1;
        
        beforeEach(async function () {
            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);
            collectibleSig = (await LaqiraceCollectibles.getCollectiblesSigs())[0];
        });
        it("Trigger", async function () {
            await LaqiraceCollectibles.setSaleStatus(collectibleSig, 10, true, true, true);

            await LaqiraceCollectibles.addQuoteToken(TokenContract.address);

            await TokenContract.approve(LaqiraceCollectibles.address, approveAmount);
            await expect(LaqiraceCollectibles.requestForMint(collectibleSig, TokenContract.address)).to.emit(LaqiraceCollectibles, 'RequestForMinting').withArgs(owner.address, collectibleSig, '1');

            const CollectibleSaleData = await LaqiraceCollectibles.getCollectibleSaleData(collectibleSig);
            expect(CollectibleSaleData['totalSupply']).to.equal('1');
            const userMintRequests = await LaqiraceCollectibles.getUserMintRequest(owner.address);
            expect(userMintRequests[0][0]).to.equal(collectibleSig);
            expect(userMintRequests[0][1]).to.equal(expectedTokenId);

            const mintRequests = await LaqiraceCollectibles.getMintRequests();
            expect(mintRequests[0]).to.equal(owner.address);
        });

        it("mintForRequest (requestForMint -> mintForRequest)", async function () {
            await LaqiraceCollectibles.setSaleStatus(collectibleSig, 10, true, true, true);
            await LaqiraceCollectibles.addQuoteToken(TokenContract.address);
            await TokenContract.approve(LaqiraceCollectibles.address, approveAmount);
            await LaqiraceCollectibles.requestForMint(collectibleSig, TokenContract.address);

            expect(await LaqiraceCollectibles.totalSupply()).to.equal(0);
            
            await LaqiraceCollectibles.mintForRequest(owner.address, collectibleSig, 1);
            
            expect(await LaqiraceCollectibles.totalSupply()).to.equal(1);
            
            const tokenIdAttr = await LaqiraceCollectibles.getTokenIdAttr(expectedTokenId);
            expect(tokenIdAttr['collectible']).to.equal(collectibleSig);
            expect(tokenIdAttr['collectibleNum']).to.equal(1);
            const userMintRequests = await LaqiraceCollectibles.getUserMintRequest(owner.address);
            
            // delStructFromArray
            expect(userMintRequests.length).to.equal(0);

            // mintRequests array
            expect((await LaqiraceCollectibles.getMintRequests()).length).to.equal(0);
        });
    });

    describe("mintTo", function () {
        let collectibleSig;
        let expectedTokenId = 1;
        
        beforeEach(async function () {
            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);
            collectibleSig = (await LaqiraceCollectibles.getCollectiblesSigs())[0];
        });
        it("Trigger", async function () {
            await LaqiraceCollectibles.mintTo(anotherAddress.address, collectibleSig);
            expect((await LaqiraceCollectibles.getCollectibleSaleData(collectibleSig))['totalSupply']).to.equal(1);
            expect(await LaqiraceCollectibles.totalSupply()).to.equal(1);
            expect(await LaqiraceCollectibles.tokenOfOwnerByIndex(anotherAddress.address, 0)).to.equal(expectedTokenId);
            
            let tokenIdAttr = await LaqiraceCollectibles.getTokenIdAttr(expectedTokenId);
            expect(tokenIdAttr['collectible']).to.equal(collectibleSig);
            expect(tokenIdAttr['collectibleNum']).to.equal(expectedTokenId);
        });
    });

    describe('updateCollectibleAttr', function() {
        let newCollectibleName = "Laqira new char";
        let newFigure = "IPFS://newCarImage";
        let newPrice = "4000000000000000000";
        let newRaceCost = "50000000000000000000";
        let newMaxRaces = 6;

        it('Trigger', async function () {
            const expectedSig = generateSigUsingEthers(data);
            await expect(LaqiraceCollectibles.updateCollectibleAttr(expectedSig, collectibleName, figure, price, raceCost, maxRaces)).to.be.revertedWith('Collectible does not exist');
            
            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);
            
            await expect(LaqiraceCollectibles.updateCollectibleAttr(expectedSig, newCollectibleName, newFigure, newPrice, newRaceCost, newMaxRaces)).to.emit(LaqiraceCollectibles, 'UpdateCollectible').withArgs(newCollectibleName, newFigure, newPrice, newRaceCost, newMaxRaces, expectedSig);
            
            const collectibleSigFromNewName = await LaqiraceCollectibles.getCollectibleSigByName(newCollectibleName);
            
            expect(collectibleSigFromNewName).to.equal(expectedSig);

            const collectbleData = await LaqiraceCollectibles.getCollectibleData(expectedSig);

            expect(collectbleData['name']).to.equal(newCollectibleName);
            expect(collectbleData['figure']).to.equal(newFigure);
            expect(collectbleData['price']).to.equal(newPrice);
            expect(collectbleData['raceCost']).to.equal(newRaceCost);
            expect(collectbleData['maxRaces']).to.equal(newMaxRaces);

            const deletedSignature = await LaqiraceCollectibles.getCollectibleSigByName(collectibleName);
            expect(deletedSignature).to.equal(constants.ZERO_BYTES32);
        });
    });

    describe('setSaleStatus', function() {
        it('Trigger', async function () {
            const expectedSig = generateSigUsingEthers(data);
            await expect(LaqiraceCollectibles.setSaleStatus(expectedSig, 0, false, false, false)).to.be.revertedWith('Collectible does not exist');

            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);

            await LaqiraceCollectibles.setSaleStatus(expectedSig, 0, true, false, false);

            const saleData = await LaqiraceCollectibles.getCollectibleSaleData(expectedSig);
            expect(saleData['maxSupply']).to.equal(0);
            expect(saleData['totalSupply']).to.equal(0);
            expect(saleData['salePermit']).to.true;
            expect(saleData['preSale']).to.false;
            expect(saleData['saleByRequest']).to.false;
        }); 
    });

    describe("requestChargeCollectible", function () {
        let approveAmount = price;
        const collectibleSig = generateSigUsingEthers(data);
        
        it('Trigger', async function () {
            await expect(LaqiraceCollectibles.requestChargeCollectible(1, 1, TokenContract.address)).to.been.revertedWith('tokenId does not exist');
            
            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);
            await LaqiraceCollectibles.setSaleStatus(collectibleSig, 0, true, false, false);
            await LaqiraceCollectibles.addQuoteToken(TokenContract.address);
            await TokenContract.approve(LaqiraceCollectibles.address, approveAmount);
            
            await LaqiraceCollectibles.mintCollectible(collectibleSig, TokenContract.address);
            
            await TokenContract.approve(LaqiraceCollectibles.address, raceCost);
            await expect(LaqiraceCollectibles.requestChargeCollectible(1, 10, TokenContract.address)).to.been.revertedWith('Number of races is more than max allowed races');
            await expect(LaqiraceCollectibles.requestChargeCollectible(1, 1, TokenContract.address)).to.emit(LaqiraceCollectibles, 'RechargeRequest').withArgs(1, owner.address, 1, (raceCost), TokenContract.address);        });
    });

    describe("removeCollectible", function () {
        it("Trigger", async function () {
            const expectedSig = generateSigUsingEthers(data);
            await expect(LaqiraceCollectibles.removeCollectible(expectedSig)).to.be.revertedWith('Collectible does not exist');
            await LaqiraceCollectibles.importCollectible(collectibleName, figure, price, raceCost, maxRaces);
            await expect(LaqiraceCollectibles.removeCollectible(expectedSig)).to.emit(LaqiraceCollectibles, 'RemoveCollectible').withArgs(expectedSig);

            expect(await LaqiraceCollectibles.getCollectibleSigByName(collectibleName)).to.equal(constants.ZERO_BYTES32);
            const collectibleData = await LaqiraceCollectibles.getCollectibleData(expectedSig);
            expect(collectibleData['price']).to.equal(0);
            expect((await LaqiraceCollectibles.getCollectiblesSigs()).length).to.equal(0);
        });
    });
});

function generateSigUsingEthers(data) {
    return ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode([ "string", "string", "uint256", "uint256", "uint256" ], [data.collectibleName, data.figure, data.price, data.raceCost, data.maxRaces]));
}
