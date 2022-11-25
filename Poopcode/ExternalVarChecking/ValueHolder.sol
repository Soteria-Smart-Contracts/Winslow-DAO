//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract ValueHolder{

    uint256 public IntValue = 25;
    uint256[] public IntArray = [50, 75];
    mapping(uint256 => address) public IntMap;

    constructor(){
      IntMap[1] = msg.sender;
      IntMap[2] = address(1);
    }


}