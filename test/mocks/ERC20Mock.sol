// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;


import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20{
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    ) ERC20(name,symbol){ //调用父合约的构造函数
        _mint(initialAccount, initialBalance); //调用父合约的铸币函数铸造初始代币
    }


    function mint(address account, uint256 amount) public{ //公开父合约的铸币函数，方便测试使用
        _mint(account, amount);
    }

}