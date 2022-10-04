//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract ErosProposal{
    address public DAO = 0x0000000000000000000000000000000000000000;
    bool public Executed;
    bool public ErosRepeatable = false; // Defines if the execute fuction is designed to be called multiple times in the future

    //Additional variables can be added here
    address public ExternalContract = 0x0000000000000000000000000000000000000000;
    //Additional variables can be added here

    modifier OnlyDAO{
        require(msg.sender == DAO  || EROSDAO(DAO).CheckErosApproval(address(this)));
        _;
    }


    function Execute() public OnlyDAO returns(bool success){
        Executed = true; //Updates first to avoid recursive calling
        //External or internal code to execute

        ExtCon(ExternalContract).Update("This value was updated by the DAO!");

        //External or internal code to execute
        return(success);
    }

    //Additional functions can go here that can only be executed by the Execute() function, therefore must be internal


}

interface EROSDAO{
    function CheckErosApproval(address) external view returns(bool);
}

interface ExtCon{
    function Update(string calldata) external view returns(bool);
}