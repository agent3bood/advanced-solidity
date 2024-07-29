## Slither on Uniswap assignment
### Issues
- Pair.flashLoan(IERC3156FlashBorrower,ERC20,uint256,bytes) (src/contracts/Pair.sol#277-288) uses arbitrary from in transferFrom: address(token).safeTransferFrom(address(receiver),address(this),amount) (src/contracts/Pair.sol#286)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#arbitrary-from-in-transferfrom
- Non issue, we want to flash loan the `receiver` address.

- Pair.mint(address) (src/contracts/Pair.sol#99-115) uses a dangerous strict equality:
	- liquidity == 0 (src/contracts/Pair.sol#107)
Pair.swap(address) (src/contracts/Pair.sol#189-210) uses a dangerous strict equality:
	- amountInA == 0 && amountInB == 0 (src/contracts/Pair.sol#197)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
- Not an issue, we want to check for zero

- local-variable-shadowing
- This can improve code quality, accepted.

- Pair._tokenA (src/contracts/Pair.sol#20) should be immutable
Pair._tokenB (src/contracts/Pair.sol#21) should be immutable
- Accepted
