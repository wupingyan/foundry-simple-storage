## 编译

```
forge build

如果合约里导入了库 需要安装 eg:
forge install OpenZeppelin/openzeppelin-contracts --no-git 

forge test
forge test -vvvv     //-vvvv 类似与日志等级  输出详细
forge test --gas-report  //输出gas报告

forge test --mt  方法名   //单独测试某个方法

forge coverage  //测试覆盖率
```



