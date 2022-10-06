//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract HarmoniaDAO_V1{
    address public Treasury;


    constructor(address TreasuryAddress){
        
    }


    receive() external payable{
        //update the balance
    }

    fallback() external payable{
        //update the balance
    }
}