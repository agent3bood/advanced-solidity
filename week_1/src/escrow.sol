// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Untrusted escrow.
// Create a contract where a buyer can put an arbitrary ERC20 token into a contract and a seller can withdraw it 3 days later.
// Based on your readings above, what issues do you need to defend against?
// Create the safest version of this that you can while guarding against issues that you cannot control.
// Does your contract handle fee-on transfer tokens or non-standard ERC20 tokens.

contract Escrow {
    address seller;
    address buyer;
    IERC20 token;
    uint256 amount;
    uint256 depositedAt;

    constructor(IERC20 _token, address _seller, address _buyer, uint256 _amount) {
        token = _token;
        seller = _seller;
        buyer = _buyer;
        amount = _amount;
    }

    function deposit() external {
        require(msg.sender == buyer);
        bytes4 transferFromSelector = bytes4(keccak256("transferFrom(address,address,uint256)"));
        bytes memory transferFrom = abi.encodeWithSelector(transferFromSelector, buyer, address(this), amount);
        (bool success, bytes memory transfered) = address(token).call(transferFrom);
        require(success);
        if (transfered.length > 0) {
            bool transferOk = abi.decode(transfered, (bool));
            require(transferOk);
        }
        depositedAt = block.timestamp;
    }

    function withdraw() external {
        require(msg.sender == seller);
        require(depositedAt + 3 days < block.timestamp);
        token.transfer(seller, amount);
        amount = 0;
    }
}
