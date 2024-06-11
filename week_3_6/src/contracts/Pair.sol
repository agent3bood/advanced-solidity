// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "solady/tokens/ERC20.sol";
import "solady/utils/FixedPointMathLib.sol";

import "./interfaces/IPair.sol";

contract Pair is IPair, ERC20 {
    error InsufficientLuquidityBurnt();
    error InsufficientAmountIn();

    string private _name;
    string private _symbol;
    uint constant MINIMUM_LIQUIDITY = 10**3;
    ERC20 private _tokenA;
    ERC20 private _tokenB;
    uint private _reserveA;
    uint private _reserveB;
    uint private _lock = 1;

    modifier lock {
        require(_lock == 1, "No Reentrancy");
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor(string memory name_, string memory symbol_, ERC20 tokenA_, ERC20 tokenB_) {
        _name = name_;
        _symbol = symbol_;
        _tokenA = tokenA_;
        _tokenB = tokenB_;
    }

    /// @dev Returns the name of the token.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @dev Returns the decimals places of the token.
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /// @dev token A
    function tokenA() external view returns (ERC20) {
        return _tokenA;
    }

    /// @dev token B
    function tokenB() external view returns (ERC20) {
        return _tokenB;
    }

    /// @dev Mints tokens to `to`.
    /// User must transfer `tokenA` and/or `tokenB` before calling `mint`.
    ///
    /// Emits a {Transfer} event.
    function mint(address to) external override lock returns (uint liquidity) {
        uint totalSupply = totalSupply();
        (uint reserveA, uint reserveB) = getReserves();
        uint balanceA = _tokenA.balanceOf(address(this));
        uint balanceB = _tokenB.balanceOf(address(this));
        uint amountA = balanceA - reserveA;
        uint amountB = balanceB - reserveB;
        if(totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            uint liquidityA = amountA * totalSupply / reserveA;
            uint liquidityB = amountB * totalSupply / reserveB;
            if(liquidityA > liquidityB) {
                liquidity = liquidityB;
            } else {
                liquidity = liquidityA;
            }
        }

        require(liquidity > 0, "Not enought tokens");

        _mint(to, liquidity);
        _update(balanceA, balanceB);
    }

    function burn(address to) external override lock returns (uint amountA, uint amountB) {
        uint totalSupply = totalSupply();
        uint liquidity = balanceOf(address(this));
        (uint reserveA, uint reserveB) = getReserves();
        ERC20 tokenA = _tokenA;
        ERC20 tokenB = _tokenB;
        uint balanceA = tokenA.balanceOf(address(this));
        uint balanceB = tokenB.balanceOf(address(this));

        amountA = liquidity * balanceA / totalSupply;
        amountB = liquidity * balanceB / totalSupply;
        if(amountA < 1 || amountB < 1) {
            revert InsufficientLuquidityBurnt();
        }

        _burn(address(this), liquidity);
        tokenA.transfer(to, amountA);
        tokenB.transfer(to, amountB);

        _update(balanceA, balanceB);

    }

    function swap(uint amountOutA, uint amountOutB, address to) override lock external {
        (uint reserveA, uint reserveB) = getReserves();
        ERC20 tokenA = _tokenA;
        ERC20 tokenB = _tokenB;
        uint balanceA = tokenA.balanceOf(address(this));
        uint balanceB = tokenB.balanceOf(address(this));
        uint amountInA = reserveA - balanceA;
        uint amountInB = reserveB - balanceB;

        {
            // scope for Stack too deep error
            uint adjustedBalanceA = reserveA + amountInA - amountOutA;
            uint adjustedBalanceB = reserveB + amountInB - amountOutB;
            if(adjustedBalanceA * adjustedBalanceB < reserveA * reserveB) {
                revert InsufficientAmountIn();
            }
            _update(adjustedBalanceA, adjustedBalanceB);
        }

        {
            // scope for Stack too deep error
            tokenA.transfer(to, amountOutA);
            tokenB.transfer(to, amountOutB);
            emit Swap(msg.sender, amountInA, amountInB, amountOutA, amountOutB, to);
        }
    }

    function _update(uint newBalanceA, uint newBalanceB) private {
        _reserveA = newBalanceA;
        _reserveB = newBalanceB;
    }

    // TODO
    /*function assertK(uint reserveA) internal {
        require(amountA * amountB >= k);
    }*/

    function getReserves() private view returns (uint reserveA, uint reserveB) {
         reserveA = _reserveA;
         reserveB = _reserveB;
    }
}
