// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "solady/tokens/ERC20.sol";
import "solady/utils/FixedPointMathLib.sol";
import "solady/utils/SafeTransferLib.sol";
import "./interfaces/IERC3156FlashBorrower.sol";

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
    error InsufficientAmountOut();
    error DeadlinePassed();
    error Locked();

    /************
    * Modifiers *
    ************/

    modifier ensureDeadline(uint64 deadline) {
        if (deadline > uint(block.timestamp)) {
            revert DeadlinePassed();
        }
        _;
    }

    modifier ensureToken(ERC20 token) {
        require(_tokenA == token || _tokenB == token, "Unknown token");
        _;
    }

    modifier ensureTokens(ERC20 tokenA_, ERC20 tokenB_) {
        require(_tokenA == tokenA_ || _tokenB == tokenA_, "Unknown tokenA");
        require(_tokenA == tokenB_ || _tokenB == tokenB_, "Unknown tokenB");
        require(tokenA_ != tokenB_);
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
        liquidity = quoteLiquidity(amountA, amountB, reserveA, reserveB, totalSupply);
        if (liquidity == 0) {
            revert InsufficientLiquidityMint();
        }
        if (totalSupply == 0) {
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        _mint(to, liquidity);
        _updateReserves(balanceA, balanceB);
    }

    /// @notice Low level call to burn liquidity
    /// @param to The receiving address of tokens
    /// @return amountA The amount received for tokenA
    /// @return amountB The amount received for tokenB
    function burn(address to) public lock returns (uint amountA, uint amountB) {
        uint totalSupply = totalSupply();
        uint liquidity = balanceOf(address(this));
        if (liquidity == 0) {
            revert InsufficientLiquidityBurnt();
        }
        (uint reserveA, uint reserveB) = getReserves();
        (amountA, amountB) = quoteAmounts(liquidity, reserveA, reserveB, totalSupply);

        _burn(address(this), liquidity);
        address(_tokenA).safeTransfer(to, amountA);
        address(_tokenB).safeTransfer(to, amountB);

        _updateReserves(reserveA - amountA, reserveB - amountB);
    }

    /// @notice Add liquidity by approving amountA and amountB
    /// @param minLiquidity The minimum amount of liquidity to be minted
    /// @param amountA The approved amount for tokenA
    /// @param amountB The approved amount for tokenB
    /// @param to The address to receive liquidity tokens
    /// @param deadline Transaction deadline
    /// @return liquidity The minted liquidity amount
    function addLiquidity(
        uint minLiquidity,
        uint amountA,
        uint amountB,
        address to,
        uint64 deadline
    ) external ensureDeadline(deadline) returns (uint liquidity) {
        (uint reserveA, uint reserveB) = getReserves();
        liquidity = quoteLiquidity(amountA, amountB, reserveA, reserveB, totalSupply());
        if (liquidity < minLiquidity) {
            revert InsufficientLiquidityMint();
        }
        address(_tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        address(_tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        mint(to);
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
    ) external ensureDeadline(deadline) returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = getReserves();
        (amountA, amountB) = quoteAmounts(liquidity, reserveA, reserveB, totalSupply());
        if (amountA < amountAMin || amountB < amountBMin) {
            revert InsufficientLiquidityBurnt();
        }
        address(this).safeTransferFrom(msg.sender, address(this), liquidity);
        burn(to);
    }

    /// @notice Low level call to swap tokens
    /// @param to The receiving address of tokens
    /// @return amountOut the out amount
    function swap(address to) lock public returns (uint amountOut) {
        ERC20 __tokenA = _tokenA;
        ERC20 __tokenB = _tokenB;
        (uint reserveA, uint reserveB) = getReserves();
        uint balanceA = __tokenA.balanceOf(address(this));
        uint balanceB = __tokenB.balanceOf(address(this));
        uint amountInA = balanceA > reserveA ? balanceA - reserveA : 0;
        uint amountInB = balanceB > reserveB ? balanceB - reserveB : 0;
        if (amountInA == 0 && amountInB == 0) {
            revert InsufficientAmountIn();
        }
        if (amountInA > 0) {
            amountOut = quote(amountInA, reserveA, reserveB);
            address(__tokenB).safeTransfer(to, amountOut);
            emit Swap(msg.sender, amountInA, amountInB, 0, amountOut, to);
        } else {
            amountOut = quote(amountInB, reserveB, reserveA);
            address(__tokenA).safeTransfer(to, amountOut);
            emit Swap(msg.sender, amountInA, amountInB, amountOut, 0, to);
        }
        _updateReserves(balanceA, balanceB);
    }

    /// @notice Swap exact amount of input token for not less than output amount of tokens
    /// @param tokenIn The input token
    /// @param tokenOut The output token
    /// @param amountIn The approved amount of input token
    /// @param amountOutMin The minimum desired amount of output token
    /// @param to The receiving address
    /// @param deadline Transaction deadline
    /// @return amountOut The exchanged output amount
    function swapExactTokensForTokens(
        ERC20 tokenIn,
        ERC20 tokenOut,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint64 deadline
    ) external ensureDeadline(deadline) ensureTokens(tokenIn, tokenOut) returns (uint amountOut) {
        (uint reserveA, uint reserveB) = getReserves();
        if (tokenIn == _tokenA) {
            amountOut = quote(amountIn, reserveA, reserveB);
        } else {
            amountOut = quote(amountIn, reserveB, reserveA);
        }
        if (amountOut < amountOutMin) {
            revert InsufficientAmountIn();
        }

        address(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        address(tokenOut).safeTransferFrom(msg.sender, address(this), amountOut);
        swap(to);
    }

    /// @notice Swap tokens for an exact amount of output tokens
    /// @param tokenIn The input token
    /// @param tokenOut The output token
    /// @param amountOut The desired amount of output token
    /// @param amountInMax The maximum amount of input token
    /// @param to The receiving address
    /// @param deadline Transaction deadline
    /// @return amountIn The exchanged input amount
    function swapTokensForExactTokens(
        ERC20 tokenIn,
        ERC20 tokenOut,
        uint amountOut,
        uint amountInMax,
        address to,
        uint64 deadline
    ) external ensureDeadline(deadline) ensureTokens(tokenIn, tokenOut) returns (uint amountIn) {
        (uint reserveA, uint reserveB) = getReserves();
        if (tokenIn == _tokenA) {
            amountIn = quote(amountOut, reserveB, reserveA);
        } else {
            amountIn = quote(amountIn, reserveA, reserveB);
        }
        if (amountIn < amountInMax) {
            revert InsufficientAmountOut();
        }

        address(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        address(tokenOut).safeTransferFrom(msg.sender, address(this), amountOut);
        swap(to);
    }

    /// @dev Initiate a flash loan.
    /// @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
    /// @param token The loan currency.
    /// @param amount The amount of tokens lent.
    /// @param data Arbitrary data structure, intended to contain user-defined parameters.
    function flashLoan(
        IERC3156FlashBorrower receiver,
        ERC20 token,
        uint256 amount,
        bytes calldata data
    ) lock ensureToken(token) external returns (bool) {
        require(amount <= token.balanceOf(address(this)), "Insufficient funds");
        address(token).safeTransfer(address(receiver), amount);
        require(receiver.onFlashLoan(msg.sender, address(token), amount, 0, data) == keccak256("ERC3156FlashBorrower.onFlashLoan"), "Invalid return");
        address(token).safeTransferFrom(address(receiver), address(this), amount);
        return true;
    }

    /*******************
    * Public Functions *
    *******************/

    /// @dev Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset.
    /// @param amountA The amount of tokenA.
    /// @param reserveA The reserve amount of tokenA in the liquidity pool.
    /// @param reserveB The reserve amount of tokenB in the liquidity pool.
    /// @return amountB The calculated amount of tokenB.
    /// @notice This function assumes that `amountA`, `reserveA`, and `reserveB` are all positive values.
    /// @notice The invariant is `(ReserveA + AmountA) * (reserveB - amountB) = reserveA * reserveB`
    function quote(uint amountA, uint reserveA, uint reserveB) public pure returns (uint amountB) {
        require(amountA > 0, "amountA must be greater than 0");
        require(reserveA > 0 && reserveB > 0, "reserves must be greater than 0");
        amountB = amountA * reserveB / (reserveA + amountA);
    }

    /// @dev Calculates the amount of liquidity tokens to mint based on the provided token amounts and current reserves.
    /// @param amountA The amount of token A being added to the pool.
    /// @param amountB The amount of token B being added to the pool.
    /// @param reserveA The current reserve of token A in the pool.
    /// @param reserveB The current reserve of token B in the pool.
    /// @param totalSupply The current total supply of liquidity tokens.
    /// @return liquidity The amount of liquidity tokens to mint.
    function quoteLiquidity(uint amountA, uint amountB, uint reserveA, uint reserveB, uint totalSupply) public pure returns (uint liquidity) {
        if (totalSupply == 0) {
            // Initial liquidity provision
            liquidity = FixedPointMathLib.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        } else {
            // Proportional to existing reserves
            uint liquidityA = amountA * totalSupply / reserveA;
            uint liquidityB = amountB * totalSupply / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }
    }

    /// @dev Calculates the amount of tokens to return to the user when burning liquidity tokens.
    /// @param liquidity The amount of liquidity tokens to burn.
    /// @param reserveA The current reserve of token A in the pool.
    /// @param reserveB The current reserve of token B in the pool.
    /// @param totalSupply The current total supply of liquidity tokens.
    /// @return amountA The amount of token A to return.
    /// @return amountB The amount of token B to return.
    function quoteAmounts(uint liquidity, uint reserveA, uint reserveB, uint totalSupply) public pure returns (uint amountA, uint amountB) {
        require(totalSupply > 0, "Total supply must be greater than 0");
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;
    }

    /*********************
    * Internal Functions *
    *********************/

    /********************
    * Private Functions *
    ********************/

    /// @notice Update the pool reserve values and emit Sync event
    function _updateReserves(uint newBalanceA, uint newBalanceB) private {
        _reserveA = newBalanceA;
        _reserveB = newBalanceB;
        emit Sync(newBalanceA, newBalanceB);
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

    /// @dev Returns the current total supply of the token.
    /// @param token The token address
    /// @return The total supply of the token
    function maxFlashLoan(
        ERC20 token
    ) ensureToken(token) external view returns (uint256) {
        require(token == _tokenA || token == _tokenB, "Unknown token");
        return token.balanceOf(address(this));
    }

    /// @notice The fee is always zero; enjoy your flash loan!
    /// @dev The fee to be charged for a given loan.
    /// @param token The loan currency.
    /// @return The amount of `token` to be charged for the loan, on top of the returned principal.
    function flashFee(ERC20 token, uint256) ensureToken(token) external view returns (uint256) {
        return 0;
    }

    /*****************
    * Pure Functions *
    *****************/
}
