// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "src/contracts/Pair.sol";

import "../mocks/MockERC20.sol";

contract TestPair is Test {
    address user1;
    address user2;
    MockERC20 tokenA;
    MockERC20 tokenB;
    Pair pair;

    function setUp() public {
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        tokenA = new MockERC20("Token A", "A");
        tokenB = new MockERC20("Token B", "B");
        pair = new Pair("AB Pair", "AB", tokenA, tokenB);
    }

    function test_mintInitialSupply() public {
        vm.startPrank(user1);
        tokenA.mint(1_000_000);
        tokenB.mint(100_000);
        tokenA.transfer(address(pair), 1_000_000);
        tokenB.transfer(address(pair), 100_000);
        pair.mint(user1);
        // sqrt(1_000_000 * 100_000) - 10**3;
        assertEq(pair.balanceOf(user1), 315_227);
        vm.stopPrank();
    }

    function test_mintSecondSupply() public {
        vm.startPrank(user1);
        tokenA.mint(1_000_000);
        tokenB.mint(100_000);
        tokenA.transfer(address(pair), 1_000_000);
        tokenB.transfer(address(pair), 100_000);
        pair.mint(user1);
        // sqrt(1_000_000 * 100_000) - 10**3;
        assertEq(pair.balanceOf(user1), 315_227);

        vm.startPrank(user2);
        // 50%
        tokenA.mint(500_000);
        tokenB.mint(50_000);
        tokenA.transfer(address(pair), 500_000);
        tokenB.transfer(address(pair), 50_000);
        pair.mint(user2);

        // almost equal because we burnt MINIMUM_LIQUIDITY
        assertEq(pair.balanceOf(user1) / 10000, pair.balanceOf(user2) * 2 / 10000);
        vm.stopPrank();
    }

    function test_mintInitialSupplyRevertWhenLessThanMINIMUM_LIQUIDITY() public {
        vm.startPrank(user1);
        tokenA.mint(1_000);
        tokenB.mint(1_000);
        tokenA.transfer(address(pair), 1_000);
        tokenB.transfer(address(pair), 1_000);
        vm.expectRevert();
        pair.mint(user1);
        vm.stopPrank();
    }
/*
TODO
    function test_mintFrontRunningExpensive() public {
        // owner tries to mint 10_000 & 10_000 tokens
        // attacker would need x & x to steal from owner

        // 10_000 * x / y = 1
        // 1 / 10_000 = x/y
        // 10_000 = y/x
        // I need reserveA/totalSupply to equal 10_000
        // donate to reserveA 10_000 * 10_000

        // attacker
        vm.startPrank(user2);
        tokenA.mint(10_000);
        tokenB.mint(10_000);
        tokenA.transfer(address(pair), 10_000);
        tokenB.transfer(address(pair), 10_000);
        pair.mint(user2);
        assertGt(pair.balanceOf(user2), 0);

        // owner
        vm.startPrank(user1);
        tokenA.mint(10_000);
        tokenB.mint(10_000);
        tokenA.transfer(address(pair), 10_000);
        tokenB.transfer(address(pair), 10_000);
        pair.mint(user1);
        assertEq(pair.balanceOf(user1), 1);
    }
    */
}
