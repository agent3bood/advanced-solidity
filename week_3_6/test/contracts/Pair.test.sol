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

    function test_burn() external {
        supplyInitialLiquidity();

        vm.startPrank(user1);
        tokenA.mint(1_000);
        tokenB.mint(1_000);
        tokenA.transfer(address(pair), 1_000);
        tokenB.transfer(address(pair), 1_000);
        (uint liquidity) = pair.mint(user1);
        assertGt(liquidity, 0);
        assertGt(pair.balanceOf(user1), 0);
        assertEq(tokenA.balanceOf(user1), 0);
        assertEq(tokenB.balanceOf(user1), 0);

        pair.transfer(address(pair), pair.balanceOf(user1));
        pair.burn(user1);
        assertEq(pair.balanceOf(address(pair)), 0, "liquidity burnt");
        assertEq(pair.balanceOf(user1), 0);
        // we do not get full amount because we did not properly calculate how much is k
        assertGt(tokenA.balanceOf(user1), 0, "Some amount returned");
        assertGt(tokenB.balanceOf(user1), 0, "Some amount returned");

        vm.stopPrank();
    }

    function test_addLiquidity() public {
        supplyInitialLiquidity();

        vm.startPrank(user1);
        tokenA.mint(1000);
        tokenA.approve(address(pair), 1000);
        tokenB.mint(100);
        tokenB.approve(address(pair), 100);

        // minLiquidity is the minimum of
        // console.log(1000 * pair.totalSupply() / tokenA.balanceOf(address(pair)));
        // console.log(100 * pair.totalSupply() / tokenB.balanceOf(address(pair)));
        uint minLiquidity = 316;
        pair.addLiquidity(minLiquidity, 1000, 100, user1, uint64(block.timestamp));
        console.log(pair.balanceOf(address(user1)));
        assertEq(pair.balanceOf(address(user1)), minLiquidity);
    }

    function test_addLiquidityTakeMin() public {
        supplyInitialLiquidity();

        vm.startPrank(user1);
        tokenA.mint(1000);
        tokenA.approve(address(pair), 1000);
        tokenB.mint(99);
        tokenB.approve(address(pair), 99);

        // minLiquidity is the minimum of
        // console.log(1000 * pair.totalSupply() / tokenA.balanceOf(address(pair)));
        // console.log(100 * pair.totalSupply() / tokenB.balanceOf(address(pair)));
        uint minLiquidity = 316;
        vm.expectRevert();
        pair.addLiquidity(minLiquidity, 1000, 99, user1, uint64(block.timestamp));
        console.log(pair.balanceOf(address(user1)));
        assertEq(pair.balanceOf(address(user1)), 0);
    }

    // Supply initial liquidity of tokenA:tokenB 10:1
    function supplyInitialLiquidity() internal {
        address userX = vm.addr(314);
        vm.startPrank(userX);
        tokenA.mint(1_000_000);
        tokenB.mint(100_000);
        tokenA.transfer(address(pair), 1_000_000);
        tokenB.transfer(address(pair), 100_000);
        pair.mint(userX);
        // sqrt(1_000_000 * 100_000) - 10**3;
        assertEq(pair.balanceOf(userX), 315_227);
        vm.stopPrank();
    }
}
