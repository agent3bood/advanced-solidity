// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "../../src/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external {
        _mint(to, id, amount, data);
    }

    function batchMint(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external {
        _batchMint(to, ids, amounts, data);
    }


    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }

    function batchBurn(address from, uint256[] calldata ids, uint256[] calldata amounts) external {
        _batchBurn(from, ids, amounts);
    }
}
