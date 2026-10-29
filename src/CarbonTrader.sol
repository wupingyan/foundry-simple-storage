// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


error CarbonTrader_NotOwner();
error CarbonTrader_ParamError();
error CarbonTrader_TransferFailed();

contract CarbonTrader{
    mapping(address => uint256) private s_addressToAllowances;
    mapping(address => uint256) private s_freezeAllowances;
    mapping(address =>uint256) private s_auctionAmount;

    mapping(string =>trade) private s_trade;

    struct trade{
        address seller;             // 卖家地址
        uint256 sellAmount;         // 要拍卖的碳额度
        uint256 startTimestamp;     //拍卖开始时间
        uint256 endTimestamp;       //拍卖结束时间
        uint256 minimumBidAmount;   //最少起拍数量
        uint256 initPriceOfUnit;    //每单位的起拍价格
        mapping(address => uint256) deposits;
        mapping(address => string) bidInfos;
        mapping(address => string)bidSecrets;
    }

    address private i_owner;
    IERC20  private i_ustdToken;

    constructor(address ustdTokenAddress){
        i_owner=msg.sender;
        i_ustdToken=IERC20(ustdTokenAddress);
    }

    modifier onlyOwner(){
        if(msg.sender !=i_owner){
            revert CarbonTrader_NotOwner();
        }
        _;
    }
    //发放碳额度
    function issueAllowance(address user,uint256 amount) public{
        s_addressToAllowances[user] += amount;
    }

    //查询用户碳额度
    function getAllowance(address user) public view returns(uint256){
        return s_addressToAllowances[user];
    }

    // 冻结用户碳额度
    function freezeAllowance(address user,uint freezeAmount) public onlyOwner{
        s_addressToAllowances[user] -=freezeAmount;
        s_freezeAllowances[user] +=freezeAmount;
    }

    // 解冻用户碳配额
    function unfreezeAllowance(address user,uint freezeAmount) public onlyOwner{
        s_addressToAllowances[user] +=freezeAmount;
        s_freezeAllowances[user] -=freezeAmount;
    }

    // 查询用户冻结配额
    function getFrozenAllowance(address user) public view returns(uint256){
        return s_freezeAllowances[user];
    }

    // 销毁用户冻结配额
    function destroyAllowance(address user,uint256 desrtroyAmount) public onlyOwner{
        s_addressToAllowances[user] -=desrtroyAmount;
    }

    function destroyAllAllowance(address user) public onlyOwner{
        s_addressToAllowances[user]=0;
        s_freezeAllowances[user]=0;
    }

    // 开始新的碳额拍卖
    function startTrade(
        string memory tradeID,
        uint256 amount,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 minimumBidAmount,
        uint256 initPriceOfUnit
    )public {
        if(amount <=0 || startTimestamp >=endTimestamp || minimumBidAmount<=0 || initPriceOfUnit <=0 || minimumBidAmount>amount) revert CarbonTrader_ParamError();
        trade storage newTrade=s_trade[tradeID];
        newTrade.seller=msg.sender;
        newTrade.sellAmount=amount;
        newTrade.startTimestamp=startTimestamp;
        newTrade.endTimestamp=endTimestamp;
        newTrade.minimumBidAmount=minimumBidAmount;
        newTrade.initPriceOfUnit=initPriceOfUnit;

        s_addressToAllowances[msg.sender] -=amount;
        s_freezeAllowances[msg.sender] +=amount;

    }

    // 获取交易信息
    function getTrade(string memory tradeID) public view returns(address,uint256,uint256,uint256,uint256,uint256){
        trade storage curTrade=s_trade[tradeID];
        return(curTrade.seller,curTrade.sellAmount,curTrade.startTimestamp,curTrade.endTimestamp,curTrade.minimumBidAmount,curTrade.initPriceOfUnit);
    }

    // 存入保证金
    function deposit(string memory tradeID,uint256 amount,string memory info) public{
        trade storage curTrade=s_trade[tradeID];
        //从哪里转到合约
        bool success=i_ustdToken.transferFrom(msg.sender, address(this), amount);
        if(!success){
            revert CarbonTrader_TransferFailed();
        }
        curTrade.deposits[msg.sender]=amount;
        setBidInfo(tradeID, info);

    }

    function getDeposit(string memory tradeId) public view returns(uint256){
        return s_trade[tradeId].deposits[msg.sender];
    }



    // 退还保证金
    function refundDeposit(string memory tradeID) public{
        trade storage curTrade=s_trade[tradeID];
        uint256 depositAmount=curTrade.deposits[msg.sender];
        curTrade.deposits[msg.sender]=0;

        //从合约转到哪里去
        bool success=i_ustdToken.transfer(msg.sender,depositAmount);
        if(!success) {
            curTrade.deposits[msg.sender] =depositAmount;
            revert CarbonTrader_TransferFailed();
        }

    }
    // 设置竞拍信息
    function setBidInfo(string memory tradeID,string memory info) public{
        trade storage curTrade=s_trade[tradeID];
        curTrade.bidInfos[msg.sender]=info;
    }

    
    function setBidSecret(string memory tradeID,string memory secret) public{
        trade storage curTrade=s_trade[tradeID];
        curTrade.bidSecrets[msg.sender]=secret;
    }

    function getBidInfo(string memory tradeID)public view returns(string memory){
        trade storage curTrade=s_trade[tradeID];
        return curTrade.bidInfos[msg.sender];
    }

    //结算
    function finalizeAuctionAndTransferCarbon(string memory tradeID,uint256 allowanceAmount,uint256 additionalAmountToPay) public{
        //获取保证金
        uint256 depositAmount=s_trade[tradeID].deposits[msg.sender];
        s_trade[tradeID].deposits[msg.sender]=0;
        //把保证金和新补的这些钱给卖家
        address seller=s_trade[tradeID].seller;
        s_auctionAmount[seller] +=(depositAmount + additionalAmountToPay);

        //扣除卖家的碳额度
        s_freezeAllowances[seller] =0;
        //增加买家的碳额度
        s_addressToAllowances[msg.sender] +=allowanceAmount;
        bool success=i_ustdToken.transferFrom(msg.sender, address(this), additionalAmountToPay);
        if(!success){
            revert CarbonTrader_TransferFailed();
        }

    }

    // 提取拍卖所得
    function withdrawAuctionAmount() public{
        uint256 auctionAmount =s_auctionAmount[msg.sender];
        s_auctionAmount[msg.sender]=0;

        bool success=i_ustdToken.transfer(msg.sender,auctionAmount);
        if(!success) {
            s_auctionAmount[msg.sender] =auctionAmount;
            revert CarbonTrader_TransferFailed();
        }
    }
    
}