- How does ERC721A save gas?
  It hase two main optimisations

1. Save gas when minting multiple tokens, it mints all requested NFTs in one operation instead of multiple calls to `_mint` as done in the original ERC721
2. It store less information in the contract state and calculate it when needed. This reduce the cost of minting but it adds cost on other areas of the contract.

- Where does it add cost?
  It adds cost for the read functions.
