// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "solady/tokens/ERC20.sol";
import "solady/utils/FixedPointMathLib.sol";
import "solady/utils/SafeTransferLib.sol";

contract Pair is ERC20 {
    using SafeTransferLib for address;

    /******************
    * State Variables *
    ******************/

    string private _name;
    string private _symbol;
    uint constant private MINIMUM_LIQUIDITY = 10 ** 3;
    ERC20 private _tokenA;
    ERC20 private _tokenB;
    uint private _reserveA;
    uint private _reserveB;
    uint private _lock = 1;

    /*********
    * Events *
    *********/

    event Swap(address indexed sender, uint amountAIn, uint amountBIn, uint amountAOut, uint amountBOut, address indexed to);
    event Sync(uint reserveA, uint reserveB);

    /*********
    * Errors *
    *********/

    error InsufficientLiquidityMint();
    error InsufficientLiquidityBurnt();
    error InsufficientLiquidityToMint();
    error InsufficientAmountIn();
    error DeadlinePassed();
    error Locked();

    /************
    * Modifiers *
    ************/

    modifier ensure(uint64 deadline) {
        if (deadline > uint(block.timestamp)) {
            revert DeadlinePassed();
        }
        _;
    }

    modifier lock {
        if (_lock == 2) {
            revert Locked();
        }
        _lock = 2;
        _;
        _lock = 1;
    }

    /************
    * Functions *
    ************/

    constructor(string memory name_, string memory symbol_, ERC20 tokenA_, ERC20 tokenB_) {
        _name = name_;
        _symbol = symbol_;
        _tokenA = tokenA_;
        _tokenB = tokenB_;
    }

    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }

    /*********************
    * External Functions *
    *********************/

    /// @notice Low level call to mint liquidity
    /// @dev Mints tokens to `to`.
    /// User must transfer `tokenA` and `tokenB` before calling `mint`.
    ///
    /// Emits a {Transfer} event.
    /// @param to The liquidity receiving address
    /// @return liquidity The amount of liquidity minted
    function mint(address to) public lock returns (uint liquidity) {
        uint totalSupply = totalSupply();
        (uint reserveA, uint reserveB) = getReserves();
        uint balanceA = _tokenA.balanceOf(address(this));
        uint balanceB = _tokenB.balanceOf(address(this));
        uint amountA = balanceA - reserveA;
        uint amountB = balanceB - reserveB;
        if (totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            uint liquidityA = amountA * totalSupply / reserveA;
            uint liquidityB = amountB * totalSupply / reserveB;
            if (liquidityA > liquidityB) {
                liquidity = liquidityB;
            } else {
                liquidity = liquidityA;
            }
        }

        if (liquidity == 0) {
            revert InsufficientLiquidityMint();
        }

        _mint(to, liquidity);
        _updateReserves(balanceA, balanceB);
    }

    /// @notice Low level call to burn liquidity
    /// @param to The receiving address of tokens
    /// @return amountA The amount received for tokenA
    /// @return amountB The amount received for tokenB
    function burn(address to) external lock returns (uint amountA, uint amountB) {
        uint totalSupply = totalSupply();
        uint liquidity = balanceOf(address(this));
        (uint reserveA, uint reserveB) = getReserves();
        ERC20 tokenA = _tokenA;
        ERC20 tokenB = _tokenB;
        uint balanceA = tokenA.balanceOf(address(this));
        uint balanceB = tokenB.balanceOf(address(this));

        amountA = liquidity * balanceA / totalSupply;
        amountB = liquidity * balanceB / totalSupply;
        if (amountA < 1 || amountB < 1) {
            revert InsufficientLiquidityBurnt();
        }

        _burn(address(this), liquidity);
        tokenA.transfer(to, amountA);
        tokenB.transfer(to, amountB);

        _updateReserves(balanceA, balanceB);

    }

    /// @notice Low level call to swap tokens
    /// @param amountAOut The desired amount of tokenA
    /// @param amountBOut The desired amount of tokenB
    /// @param to The receiving address of tokens
    function swap(uint amountOutA, uint amountOutB, address to) lock external {
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
            if (adjustedBalanceA * adjustedBalanceB < reserveA * reserveB) {
                revert InsufficientAmountIn();
            }
            _updateReserves(adjustedBalanceA, adjustedBalanceB);
        }

        {
            // scope for Stack too deep error
            tokenA.transfer(to, amountOutA);
            tokenB.transfer(to, amountOutB);
            emit Swap(msg.sender, amountInA, amountInB, amountOutA, amountOutB, to);
        }
    }

    // TODO liquidity calculation here is different from mint()
    /// @notice Add liquidity by approving amountA and amountB
    /// @dev Mint liquidity by approving amountA and amountB
    /// @param minLiquidity The minimum amount of liquidity to be minted
    /// @param amountA The approved amount for tokenA
    /// @param amountB The approved amount for tokenB
    /// @param to The address to receive liquidity tokens
    /// @param deadline Transaction deadline
    /// @return liquidity The minted liquidity amount
    function addLiquidity(
        uint minLiquidity,
        uint amountADesired,
        uint amountBDesired,
        address to,
        uint64 deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        // We want to keep the constant k the same (or greater)
        // after the liquidity is added
        // Ra is reserveA
        // Rb is reserveB
        // Ra' is reserveA after the liquidity is added
        // Rb' is reserveB after the liquidity is added
        // ∆A is amountA that will be added to the liquidity
        // ∆B is amountB that will be added to the liquidity
        // Ra' = Ra + ∆A
        // Rb' = Rb + ∆B
        // Maintaining the ratio
        // ∆A/∆B == Ra/Rb
        // we want to take amount from the liquidity provider that maintain this ratio

        uint liquidityOptimal;
        (uint reserveA, uint reserveB) = getReserves();
        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            amountA = amountADesired;
            amountB = quote(amountA, reserveA, reserveB);
            liquidityOptimal = amountA * amountB;
            if (liquidityOptimal < minLiquidity) {
                amountB = amountBDesired;
                amountA = quote(amountB, reserveB, reserveA);
                liquidityOptimal = amountA * amountB;
                if (liquidityOptimal < minLiquidity) {
                    revert InsufficientLiquidityToMint();
                }
            }
        }

        if (totalSupply() == 0) {
            liquidityOptimal == liquidityOptimal - MINIMUM_LIQUIDITY;
            if (liquidityOptimal < minLiquidity) {
                revert InsufficientLiquidityToMint();
            }
        }

        address(_tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        address(_tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        uint liquidityMinted = mint(to);

        // Not supposed to happen unless my math is wrong
        // TODO remove this require and add test case
        require(liquidityMinted == liquidityOptimal, "Dev wrong liquidity minted");
        liquidity = liquidityMinted;
    }

    /// @notice Remove liquidity by approving amountAMin & amountBMin
    /// @dev Burn liquidity by approving it first
    /// @param liquidity The amount of liquidity to be burnt
    /// @param amountAMin The minimum desired amount of tokenA
    /// @param amountBMin The minimum desired amount of tokenB
    /// @param to The address to receive the tokens
    /// @param deadline Transaction deadline
    /// @return amountA The returned amount of tokenA
    /// @return amountB The returned amount of tokenB
    function removeLiquidity(
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint64 deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB) {}

    /*******************
    * Public Functions *
    *******************/

    /*********************
    * Internal Functions *
    *********************/

    /********************
    * Private Functions *
    ********************/
    function _updateReserves(uint newBalanceA, uint newBalanceB) private {
        _reserveA = newBalanceA;
        _reserveB = newBalanceB;
    }

    /*****************
    * View Functions *
    *****************/
    /// @dev Returns the name of the token.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @dev token A
    function tokenA() external view returns (ERC20) {
        return _tokenA;
    }

    /// @dev token B
    function tokenB() external view returns (ERC20) {
        return _tokenB;
    }

    function getReserves() public view returns (uint reserveA, uint reserveB) {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    /*****************
    * Pure Functions *
    *****************/

     /// @dev Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset.
     /// @param amountA The amount of tokenA.
     /// @param reserveA The reserve amount of tokenA in the liquidity pool.
     /// @param reserveB The reserve amount of tokenB in the liquidity pool.
     /// @return amountB The calculated amount of tokenB.
     /// @notice This function assumes that `amountA`, `reserveA`, and `reserveB` are all positive values.
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, "amountA must be greater than 0");
        require(reserveA > 0 && reserveB > 0, "reserves must be greater than 0");
        amountB = amountA * reserveB / reserveA;
    }
}
