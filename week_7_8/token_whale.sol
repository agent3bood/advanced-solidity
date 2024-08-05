pragma solidity ^0.4.21;

// This ERC20-compatible token is hard to acquire. There’s a fixed supply of 1,000 tokens, all of which are yours to start with.
// Find a way to accumulate at least 1,000,000 tokens to solve this challenge.
//
//
//
contract TokenWhaleChallenge {
    address player;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name = "Simple ERC20 Token";
    string public symbol = "SET";
    uint8 public decimals = 18;

    function TokenWhaleChallenge(address _player) public {
        player = _player;
        totalSupply = 1000;
        balanceOf[player] = 1000;
    }

    function isComplete() public view returns (bool) {
        return balanceOf[player] >= 1000000;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);

    // function _transfer(address to, uint256 value) internal { ///////////////// original
    function _transfer(address from, address to, uint256 value) internal {
        ///////////////// fix
        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
    }

    function transfer(address to, uint256 value) public {
        require(balanceOf[msg.sender] >= value);
        require(balanceOf[to] + value >= balanceOf[to]);

        _transfer(msg.sender, to, value);
    }

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function approve(address spender, uint256 value) public {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
    }

    function transferFrom(address from, address to, uint256 value) public {
        require(balanceOf[from] >= value);
        require(balanceOf[to] + value >= balanceOf[to]);
        require(allowance[from][msg.sender] >= value);

        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
    }
}

// solc-select use 0.4.25
// echidna --contract TestTokenWhaleChallenge --test-mode assertion week_7_8/token_whale.sol
contract TestTokenWhaleChallenge is TokenWhaleChallenge(msg.sender) {
    function echidna_check_balance() public view returns (bool) {
        return balanceOf[msg.sender] <= 1000;
    }
}
