// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "solady/tokens/ERC20.sol";
/*import "../../../lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";*/

interface IPair {
    event Swap(address sender, uint inA, uint inB, uint outA, uint outB, address to);

    function tokenA() external view returns (ERC20);
    function tokenB() external view returns (ERC20);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amountAOut, uint amountBOut, address to) external;
}
