// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/*
- [ ]  **Smart contract ecosystem 1:** Smart contract trio: NFT with merkle tree discount, ERC20 token, staking contract
- [x]  Create an ERC721 NFT with a supply of 1000.
- [x]  Include ERC 2918 royalty in your contract to have a reward rate of 2.5% for any NFT in the collection. Use the openzeppelin implementation.
- [ ]  Addresses in a merkle tree can mint NFTs at a discount. Use the bitmap methodology described above. Use openzeppelin’s bitmap, don’t implement it yourself.
- [x]  Create an ERC20 contract that will be used to reward staking
- [x]  Create and a third smart contract that can mint new ERC20 tokens and receive ERC721 tokens.
A classic feature of NFTs is being able to receive them to stake tokens.
Users can send their NFTs and withdraw 10 ERC20 tokens every 24 hours. Don’t forget about decimal places!
The user can withdraw the NFT at any time.
The smart contract must take possession of the NFT and only the user should be able to withdraw it.
**IMPORTANT**:
your staking mechanism must follow the sequence suggested in https://www.rareskills.io/post/erc721 under “Gas efficient staking, bypassing approval”
- [x]  Make the funds from the NFT sale in the contract withdrawable by the owner. Use Ownable2Step.
- [ ]  **Important:**
Use a combination of unit tests and the gas profiler in foundry or hardhat to measure the gas cost of the various operations.
*/

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";

contract NFT is ERC721, ERC2981, Ownable2Step {
    error NoMoreTokens();

    constructor() ERC721("NFT", "NFT") Ownable(msg.sender) {}

    /// we mint tokens 1 -> 1000
    /// --cursor before minting
    /// gas saving, don't go to `0`
    uint256 private cursor = 1001;

    function mint() external {
        if (cursor == 1) {
            revert NoMoreTokens();
        }
        _mint(msg.sender, --cursor);
    }

    function supportsInterface(bytes4 interfaceId) public pure override(ERC721, ERC2981) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Metadata).interfaceId
            || interfaceId == type(IERC2981).interfaceId;
    }

    function royaltyInfo(uint256, uint256 salePrice) public view override returns (address, uint256) {
        return (address(this), Math.mulDiv(salePrice, 25, 1000, Math.Rounding.Trunc));
        //return (address(this), salePrice * 25 / 1000);
    }

    function withdraw() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }
}

contract Token is ERC20, IERC721Receiver {
    NFT private nft;
    mapping(uint256 => address) private owners;
    mapping(uint256 => uint256) private lastWithdraw;

    constructor(NFT _nft) ERC20("Token", "TK") {
        nft = _nft;
    }

    function withdrawNFT(uint256 tokenId) external {
        address owner = msg.sender;
        require(owner == owners[tokenId]);
        nft.transferFrom(address(this), owner, tokenId);
        delete owners[tokenId];
        delete lastWithdraw[tokenId];
    }

    function withdrawToken(uint256 tokenId) external {
        address owner = msg.sender;
        require(owner == owners[tokenId]);
        require(lastWithdraw[tokenId] < block.timestamp - 24 hours);
        lastWithdraw[tokenId] = block.timestamp;

        _mint(owner, 10);
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(nft));
        owners[tokenId] = from;
        lastWithdraw[tokenId] = block.timestamp;

        return IERC721Receiver.onERC721Received.selector;
    }
}
