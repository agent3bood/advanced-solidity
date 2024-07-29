// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Ownable {
    address public owner = msg.sender;

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: Caller is not the owner.");
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

    function transfer(address to, uint256 value) public virtual whenNotPaused {
        require(balances[msg.sender] >= value);
        // unchecked to save gas
        unchecked {
            balances[msg.sender] -= value;
            balances[to] += value;
        }
    }
}

// solc-select use 0.8.0
// echidna --contract TestToken --test-mode assertion week_7_8/echidna_exercises_4.sol
contract TestToken is Token {
    event Balance(string, uint);

    function transfer(address to, uint256 value) public override {
        uint balanceBeforeFrom = balances[msg.sender];
        emit Balance("sender before", balanceBeforeFrom);
        uint balanceBeforeTo = balances[to];
        emit Balance("to before", balanceBeforeTo);
        super.transfer(to, value);
        assert(balances[msg.sender] <= balanceBeforeFrom);
        emit Balance("sender after", balances[msg.sender]);
        assert(balances[to] >= balanceBeforeTo);
        emit Balance("to after", balances[to]);
    }
}
