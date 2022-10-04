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
        require(msg.sender == DAO  || EROSDAO(DAO).CheckErosApproval(address(this)));
    }


    function Execute() public {
        Executed = true;
        //External or internal code to execute
    }

    //Additional functions can go here that can only be 


}

interface EROSDAO{
    function CheckErosApproval(address) public view returns(bool);
}

interface ExtCon{
    function Update(string) public view returns(bool);
}