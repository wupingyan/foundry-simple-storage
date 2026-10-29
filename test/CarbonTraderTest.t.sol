// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {CarbonTrader} from "../src/CarbonTrader.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract CarbonTraderTest is Test{
    CarbonTrader  carbonTrader;
    ERC20Mock ustdToken;

    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public{
        ustdToken = new ERC20Mock("USDT","USDT",owner,1000000000000000000000);
        carbonTrader = new CarbonTrader(address(ustdToken));
    }


    function testIssueAllowance() public{
        carbonTrader.issueAllowance(owner,1000);
        assertEq(carbonTrader.getAllowance(owner),1000);
    }

    function testFreezeAllowance() public{
        carbonTrader.issueAllowance(owner,1000);
        carbonTrader.freezeAllowance(owner,500);
        assertEq(carbonTrader.getAllowance(owner),500);
        assertEq(carbonTrader.getFrozenAllowance(owner),500);
    }

    function testUnfreezeAllowance() public{
        carbonTrader.issueAllowance(owner,1000);
        carbonTrader.freezeAllowance(owner,500);
        carbonTrader.unfreezeAllowance(owner,300);
        assertEq(carbonTrader.getAllowance(owner),800);
        assertEq(carbonTrader.getFrozenAllowance(owner),200);
    }

    function testDestroyAllowance() public{
        carbonTrader.issueAllowance(owner,1000);
        carbonTrader.destroyAllowance(owner,400);
        assertEq(carbonTrader.getAllowance(owner),600);
        // vm.prank(owner);
        // vm.expectRevert();
        carbonTrader.destroyAllAllowance(owner);
        assertEq(carbonTrader.getAllowance(owner),0);
    }

    function testStartTrade() public{
        string memory tradeID="tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp+1000,100, 10);
        (address seller,uint256 sellAmount,,,,)=carbonTrader.getTrade(tradeID);
        assertEq(seller, owner);
        assertEq(sellAmount, 500);

    }

    function testDeposit() public{
        string memory tradeID="tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp+1000,100, 10);

        ustdToken.mint(user2, 1*10**6); //给用户2发行1个ustd
        vm.prank(user2);
        ustdToken.approve(address(carbonTrader), 1*10**6);//授权给合约

        vm.prank(user2);
        carbonTrader.deposit(tradeID, 1*10**6, "INFO");

        vm.prank(user2);
        assertEq(carbonTrader.getDeposit(tradeID), 1*10**6);
    }

    function testRefundDeposit() public{
        string memory tradeID="tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp+1000,100, 10);

        ustdToken.mint(user2, 1*10**6); //给用户2发行1个ustd
        vm.prank(user2);
        ustdToken.approve(address(carbonTrader), 1*10**6);//授权给合约

       vm.prank(user2);
        carbonTrader.deposit(tradeID, 1*10**6, "INFO");

        assertEq(ustdToken.balanceOf(user2), 0);

        vm.prank(user2);
        carbonTrader.refundDeposit(tradeID);

        assertEq(ustdToken.balanceOf(user2), 1*10**6);
    }

    function testFinalizeAuctionAndTransferCarbon() public{
        string memory tradeID="tradeID";
        carbonTrader.issueAllowance(owner, 1000);
        carbonTrader.startTrade(tradeID, 500, block.timestamp, block.timestamp+1000,100, 10);

        ustdToken.mint(user2, 1.5*10**6); //给用户2发行1个ustd
        vm.prank(user2);
        ustdToken.approve(address(carbonTrader), 1.5*10**6);//授权给合约

        vm.prank(user2);
        carbonTrader.deposit(tradeID, 1*10**6, "INFO");

        vm.prank(user2);
        carbonTrader.finalizeAuctionAndTransferCarbon(tradeID, 500, 0.5*10**6);

        assertEq(ustdToken.balanceOf(user2), 0);

        assertEq(carbonTrader.getAllowance(user2), 500);
    }


}