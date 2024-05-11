## Why does the SafeERC20 program exist and when should it be used?

The SafeERC20 is an implementation with additional checks to make sure the sending of tokens did succeed.

When using `transfer` and `transferFrom` on an ERC20 it should return a boolean, according to the standards, however
some ERC20 tokens do not follow this standard.

### Should it be used?

Yes, kinda. When calling `transfer` or `transferFrom` the return is one of

- revert: in this case the transaction is reverted.
- no data: in this case the transaction is assumed successful.
- data: if the data is `true` the transaction is successful, otherwise it is reverted.

The SafeERC20, does not check if the called address is *EOA*, in this case the call will success because it does a low
level function call, low level calls does not check `CODESIZE` in Solidity.
