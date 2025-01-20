pragma solidity 0.8.27;

import {Token} from "../../src/interfaces/Token.sol";

contract MockToken is Token {
    /// @inheritdoc Token
    string public override name = "Mock Token";

    /// @inheritdoc Token
    string public override symbol = "MOCK";

    /// @inheritdoc Token
    uint8 public override decimals = 18;

    /// @inheritdoc Token
    uint256 public override totalSupply;

    /// @inheritdoc Token
    mapping(address owner => mapping(address spender => uint256 remaining)) public override allowance;

    /// @inheritdoc Token
    mapping(address owner => uint256 balance) public override balanceOf;

    // @notice Mints `amount` tokens to `recipient`.
    function mint(address recipient, uint256 amount) external {
        totalSupply += amount;
        unchecked {
            balanceOf[recipient] += amount;
        }

        emit Transfer(address(0), recipient, amount);
    }

    /// @inheritdoc Token
    function approve(address spender, uint256 amount) external returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @inheritdoc Token
    function transfer(address recipient, uint256 amount) external returns (bool success) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[recipient] += amount;
        }
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    /// @inheritdoc Token
    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success) {
        allowance[owner][msg.sender] -= amount;

        balanceOf[owner] -= amount;
        unchecked {
            balanceOf[recipient] += amount;
        }
        emit Transfer(owner, recipient, amount);
        return true;
    }
}