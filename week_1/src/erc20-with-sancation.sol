// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

// Token with sanctions. Create a fungible token that allows an admin to ban specified addresses from sending and receiving tokens.
contract WithSancation {
    address admin;
    string name;
    string symbol;
    uint8 decimals = 1;
    uint256 totalSupply = 0;
    mapping(address => uint256) balanceOf;

    // owner => spender => allowance
    mapping(address => mapping(address => uint256)) allowance;

    mapping(address => bool) sancations;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        admin = msg.sender;
        name = _name;
        symbol = _symbol;
    }

    modifier sancation(address addr) {
        require(sancations[addr] == false);
        _;
    }

    function impose(address addr) external {
        require(msg.sender == admin);
        sancations[addr] = true;
    }

    function lift(address addr) external {
        require(msg.sender == admin);
        delete sancations[addr];
    }

    function transfer(address to, uint256 value) external sancation(msg.sender) returns (bool) {
        require(balanceOf[msg.sender] >= value);
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external sancation(from) returns (bool) {
        require(allowance[from][msg.sender] >= value);
        require(balanceOf[from] >= value);
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external sancation(msg.sender) returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function mint() external sancation(msg.sender) {
        balanceOf[msg.sender] += 1;
        totalSupply += 1;
        emit Transfer(address(0), msg.sender, 1);
    }
}
