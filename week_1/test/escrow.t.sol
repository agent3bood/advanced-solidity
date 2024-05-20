// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../src/escrow.sol";

contract Token is ERC20 {
    constructor() ERC20("Token", "TK") {}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}

contract EscrowTest is Test {
    address seller = address(0x501);
    address buyer = address(0x502);
    Token t;
    Escrow u;

    function setUp() external {
        t = new Token();
        u = new Escrow(t, seller, buyer, 91);
    }

    function test() external {
        vm.startPrank(buyer);
        t.mint(91);
        t.approve(address(u), 91);
        u.deposit();

        vm.startPrank(seller);
        vm.expectRevert();
        u.withdraw();

        vm.warp(3 days + 1 minutes);
        u.withdraw();

        assertEq(t.balanceOf(buyer), 0);
        assertEq(t.balanceOf(seller), 91);
        assertEq(t.balanceOf(address(u)), 0);
    }
}
