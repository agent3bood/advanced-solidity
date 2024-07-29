// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Ownable {
    address public owner = msg.sender;

    function Owner() public onlyOwner {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
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
        require(balances[msg.sender] >= value);
        balances[msg.sender] -= value;
        balances[to] += value;
    }
}

contract MintableToken is Token {
    uint256 public totalMinted;
    uint256 public totalMintable;

    constructor(uint256 totalMintable_) {
        totalMintable = totalMintable_;
    }

    function mint(uint256 value) public onlyOwner {
        require(value + totalMinted <= totalMintable);
        totalMinted += value;

        balances[msg.sender] += value;
    }
}

// solc-select use 0.8.0
// echidna --contract TestToken week_7_8/echidna_exercises_3.sol
contract TestToken is MintableToken {
    address echidna = msg.sender;

    constructor() MintableToken(10_000) {
        Owner();
    }

    function echidna_test_balance() public view returns (bool) {
        return balances[msg.sender] <= 10_000;
    }
}
