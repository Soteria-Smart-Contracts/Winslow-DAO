//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract ErosProposal{
    address public DAO = 0x0000000000000000000000000000000000000000;
    uint256 public Executions;
    bool public ErosRepeatable = true; // Defines if the execute fuction is designed to be called multiple times in the future

    //Additional variables can be added here
    address public ExternalContract = 0x0000000000000000000000000000000000000000;
    //Additional variables can be added here


    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract
        require(msg.sender == DAO  || EROSDAO(DAO).CheckErosApproval(address(this)), "The caller is either not the DAO or not approved by the DAO");
        _;
    }


    function Execute() external OnlyDAO returns(bool success){
        Executions++; //Updates first to avoid recursive calling
        EROSDAO(DAO).ErosProposalExecuted(address(this));

        //External or internal code to execute
        ExtCon(ExternalContract).Increment("This value was updated by the DAO!");
        //External or internal code to execute

        return(success);
    }

    //Additional functions can go here that can only be executed by the Execute() function
    //therefore those functions must be internal as making them public may present vulenrabilities to external contracts

}

interface EROSDAO{
    function CheckErosApproval(address) external view returns(bool);
    function ErosProposalExecuted(address) external; //This function in the DAO must require that the msg.sender is the same as the input
}

interface ExtCon{
    function ErosImplemented() external view returns(bool);
    function Increment() external;
}