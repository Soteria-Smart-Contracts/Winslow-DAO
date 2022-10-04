//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract ErosProposal{
    address public DAO = 0x0000000000000000000000000000000000000000;
    bool public Executed;
    bool public ErosRepeatable = false; // Defines if the execute fuction is designed to be called multiple times in the future

    //Additional variables can be added here

    constructor(bool Repeatable){
        ErosRepeatable = Repeatable;
    }

    modifier OnlyDAO{
        require(msg.sender == DAO  || );
    }


    function Execute() public {

    }


}

interface EROSDAO{
    function CheckErosApproval(address) public view returns(bool);
}

interface EROSDAO{
    function CheckErosApproval(address) public view returns(bool);
}