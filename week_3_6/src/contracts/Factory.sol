// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "./Pair.sol";

contract Factory {

    /// @dev Emitted when a new pair is created
    event PairCreated(address indexed tokenA, address indexed tokenB, address pair);

    /// @dev Returns the address of the pair for two tokens
    mapping(address => address) public getPair;

    /// @dev Creates a new pair for two tokens
    /// @param token0 The address of the first token
    /// @param token1 The address of the second token
    /// @return pair The address of the new pair
    function createPair(address token0, address token1) external returns (address pair) {
        require(token0 != token1, "identical tokens!");
        require(token0 != address(0), "zero address");
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        require(getPair[tokenA] == address(0), "pair exists");
        pair = address(new Pair("name", "symbol", ERC20(tokenA), ERC20(tokenB)));
        getPair[tokenA] = pair;
        getPair[tokenB] = pair;
        emit PairCreated(tokenA, tokenB, pair);
    }
}
