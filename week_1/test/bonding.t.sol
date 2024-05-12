// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../src/bonding.sol";

contract Token is ERC20 {
    constructor() ERC20("Token", "TK") {}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}

contract CurvedTest is Test {
    address user1 = address(0x501);
    address user2 = address(0x502);
    Token t;
    Curved u;

    function setUp() public {
        t = new Token();
        u = new Curved{value: 1000 ether}(t);
    }

    function test() external {
        vm.startPrank(user1);
        t.mint(10);
        t.approve(address(u), 10);

        // selling
        u.sell(1, 0);
        assertEq(user1.balance, 1 ether);

        u.sell(1, 0);
        assertEq(user1.balance, 3 ether);

        u.sell(8, 0);
        assertEq(user1.balance, 55 ether);

        vm.stopPrank();

        assertEq(u.supply(), 10);

        // buying
        vm.deal(user2, 55 ether);
        vm.startPrank(user2);

        // low price reverts
        vm.expectRevert();
        u.buy{value: 0.5 ether}(1);

        // currentPrice = 10, send exact eth
        u.buy{value: 10 ether}(1);
        assertEq(t.balanceOf(user2), 1);

        // currentPrice 9
        // send extra eth
        // Curved should return balance eth
        uint256 balanceBefore = user2.balance;
        u.buy{value: 20 ether}(1);
        assertEq(t.balanceOf(user2), 2);
        assertEq(user2.balance, balanceBefore - 9 ether);
    }
}
