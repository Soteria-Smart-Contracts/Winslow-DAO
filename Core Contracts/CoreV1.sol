//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract HarmoniaDAO_V1_Core{
    address public Treasury;


    constructor(address TreasuryAddress){
        Treasury = TreasuryAddress;
    }


    receive() external payable{
        //send ether to treasury then update balance there
    }

    fallback() external payable{
        //send ether to treasury then update balance there
    }
}