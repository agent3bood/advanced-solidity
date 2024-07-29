// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Ownable {
    address public owner = msg.sender;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: Caller is not the owner.");
        _;
    }

    function renounceOwnership() public onlyOwner {
        owner = address(0);
    }
}

contract Pausable is Ownable {
    bool private _paused;

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() public onlyOwner {
        _paused = true;
    }

    function resume() public onlyOwner {
        _paused = false;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: Contract is paused.");
        _;
    }
}

contract Token is Ownable, Pausable {
    mapping(address => uint256) public balances;

    function transfer(address to, uint256 value) public whenNotPaused {
        // unchecked to save gas
        unchecked {
            balances[msg.sender] -= value;
            balances[to] += value;
        }
    }
}

// solc-select use 0.8.0
// echidna --contract TestToken week_7_8/echidna_exercises_1.sol
contract TestToken is Token {
    address echidna = tx.origin;

    constructor() {
        balances[echidna] = 10_000;
        pause();
        renounceOwnership();
    }

    function echidna_test_balance() public view returns (bool) {
        return balances[echidna] <= 10_000;
    }
}
