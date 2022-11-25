//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract ValueChecker{

    address public ValueHolder;

    constructor(address VH){
      ValueHolder = VH;
    }

    function GetInt() public view returns(uint256 value){
      return(VAL(ValueHolder).IntValue());
    }

    function GetArray(uint256 num) public view returns(uint256 value){
      return(VAL(ValueHolder).IntArray(num));
    }

    function GetMapping(uint256 num) public view returns(address addy){
      return(VAL(ValueHolder).IntMap(num));
    }


}

interface VAL {
  function IntValue() external view returns(uint256);
  function IntArray(uint256 num) external view returns(uint256);
  function IntMap(uint256 num) external view returns(address);
}