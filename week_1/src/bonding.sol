// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Token sale and buyback with bonding curve. The more tokens a user buys, the more expensive the token becomes. To keep things simple, use a linear bonding curve.
// Consider the case someone might [sandwhich attack](https://medium.com/coinmonks/defi-sandwich-attack-explain-776f6f43b2fd) a bonding curve. What can you do about it?

contract Curved {
    IERC20 token;
    uint256 initialPrice = 1 ether;
    uint256 currentPrice = 1 ether;
    uint256 increment = 1 ether;
    uint256 public supply = 0;

    event E(uint256);

    // load initial eth in the contract to be able to buy tokens
    constructor(IERC20 _token) payable {
        token = _token;
    }

    /// price for n tokens
    function price(uint256 n) private view returns (uint256) {
        return currentPrice * n + increment * (n - 1);
    }

    /// Buy tokens by specifying amount and sending eth
    /// if the eth is not enough the transaction will revert
    /// if the eth is more than enough the balance will be sent back
    function buy(uint256 amount) external payable {
        require(supply >= amount, "not enough supply");
        uint256 price = price(amount);
        require(msg.value >= price, "price offer too low");

        bool success = token.transfer(msg.sender, amount);
        require(success, "token transfer failed");

        supply -= amount;
        currentPrice = supply * 1 ether;

        // send back reminder
        uint256 balance = msg.value - price;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }

    /// sell amount of tokens, accept if total selling price is greater than minPrice
    function sell(uint256 amount, uint256 minPrice) external {
        uint256 part1 = (supply + amount) * (supply + amount - 1) / 2;
        uint256 part2;
        if (supply == 0) {
            part2 = 0;
        } else {
            part2 = supply * (supply - 1) / 2;
        }
        uint256 price = amount * initialPrice + increment * (part1 - part2);

        require(price >= minPrice);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success);
        payable(msg.sender).transfer(price);

        supply += amount;
        currentPrice = supply * 1 ether;
    }

    function sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
