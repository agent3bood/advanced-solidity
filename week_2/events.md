Revisit the solidity events tutorial. How can OpenSea quickly determine which NFTs an address owns if most NFTs don’t use ERC721 enumerable? Explain how you would accomplish this if you were creating an NFT marketplace.

They listen to events and keep the accounting off-chain, this way it is free(ish) to query how many NFTs are owned by an address without sending transaction to the blockchain. Also in case an NFT does not implement the enumerable interface they keep track by just using events.
