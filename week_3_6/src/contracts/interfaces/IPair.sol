// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "solady/tokens/ERC20.sol";
/*import "../../../lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";*/

/*interface IPair {
    event Swap(address sender, uint inA, uint inB, uint outA, uint outB, address to);

    function tokenA() external view returns (ERC20);
    function tokenB() external view returns (ERC20);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amountAOut, uint amountBOut, address to) external;
}*/


interface IPair {
    /*********
    * Events *
    **********/

    event Swap(address indexed sender, uint amountAIn, uint amountBIn, uint amountAOut, uint amountBOut, addressed indexed to);
    event Sync(uint reserveA, uint reserveB);


    /***************************
    * State changing functions *
    ***************************/

    /// @notice Add liquidity by approving amountA and amountB
    /// @dev Mint liquidity by approving amountA and amountB
    /// @param liquidity The minimum amount of liquidity to be minted
    /// @param amountA The approved amount for tokenA
    /// @param amountB The approved amount for tokenB
    /// @param deadline Transaction deadline
    /// @param liquidity The minted liquidity amount
    function addLiquidity(
        uint minLiquidity, uint amountA,
        uint amountB,
        address to,
        uint deadline
    ) external returns(uint liquidity);

    /// @notice Remove liquidity by approving
    /// @dev Burn liquidity by approving it first
    /// @param liquidity The amount of liquidity to be burnt
    /// @param amountAMin The minimum desired amount of tokenA
    /// @param amountBMin The minimum desired amount of tokenB
    /// @param deadline Transaction deadline
    /// @param amountA The returned amount of tokenA
    /// @param amountB The returned amount of tokenB
    function removeLiquidity(
        uint liquidity,
        uint amountAMin,
        uint amountBMint,
        uint deadline
    ) external returns(uint amountA, uint amountB);

    /// @notice Low level call to mint liquidity
    /// @param to The liquidity receiving address
    /// @param liquidity The amount of liquidity minted
    function mint(address to) external returns (uint liquidity);

    /// @notice Low level call to burn liquidity
    /// @param to The receiving address of tokens
    /// @param amountA The amount received for tokenA
    /// @param amountB The amount received for tokenB
    function burn(address to) external returns (uint amountA, uint amountB);

    /// @notice Swap exact amount of input token for not less than output amount of tokens
    /// @param amountIn The approved amount of input token
    /// @param amountOutMin The minimum desired amount of output token
    /// @param path The exchange path
    /// @param to The receiving address
    /// @param deadline Transaction deadline
    /// @param amounts The exchanged amounts
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    /// @notice Swap not less than amount of input token for exact output amount of tokens
    /// @param amountOut The desired amount of output token
    /// @param amountOutMin The minimum desired amount of output token
    /// @param path The exchange path
    /// @param to The receiving address
    /// @param amounts The exchanged amounts
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to
    ) external returns(uint[] memory amounts);

    /// @notice Low level call to swap tokens
    /// @param amountAOut the desired amount of tokenA
    /// @param amountBOut the desired amount of tokenB
    /// @param to The receiving address of tokens
    function swap(uint amountAOut, uint amountBOut, address to) external;

    /*****************
    * View functions *
    *****************/

    /// @notice The first token in the pair
    function tokenA() external view returns (ERC20);

    /// @notice The secont token in the pair
    function tokenB() external view returns (ERC20);

    /// @notice The pair reserves
    /// @param reserveA The reserve of tokenA
    /// @param reserveB The reserve of tokenB
    function getReserves() external view returns(uint reserveA, uint reserveB);

    /// @notice Given the input amount get the equivalent amount of the other token
    /// @param amountA The amount of asset A
    /// @param reserveA The reserve amount of asset A
    /// @param reserveB The reserve amount of asset B
    /// @param amountB The equivalent amount of asset B
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns(uint amountB);
}
