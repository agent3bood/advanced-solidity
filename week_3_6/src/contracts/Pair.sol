// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "solady/tokens/ERC20.sol";
import "solady/utils/FixedPointMathLib.sol";

import "./interfaces/IPair.sol";

contract Pair is IPair, ERC20 {
    string private _name;
    string private _symbol;

    uint constant MINIMUM_LIQUIDITY = 10**3;
    ERC20 private _tokenA;
    ERC20 private _tokenB;
    uint private _k;
    uint private _reserveA;
    uint private _reserveB;

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

    /// @dev Mints tokens to `to`.
    /// User must transfer `tokenA` and/or `tokenB` before calling `mint`.
    ///
    /// Emits a {Transfer} event.
    function mint(address to) external override returns (uint liquidity) {
        uint totalSupply = totalSupply();
        ERC20 tokenA = _tokenA;
        ERC20 tokenB = _tokenB;
        (uint reserveA, uint reserveB) = getReserves();
        uint balanceA = tokenA.balanceOf(address(this));
        uint balanceB = tokenB.balanceOf(address(this));
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

    function burn(address to) external override returns (uint amount0, uint amount1) {}

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) override external {}

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

    function tokenA() external view returns (ERC20) {
        return _tokenA;
    }


    function tokenB() external view returns (ERC20) {
        return _tokenB;
    }
}
