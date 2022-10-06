//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract ErosProposal{
    address public DAO = 0x0000000000000000000000000000000000000000;
    uint256 public Executions;
    bool public ErosRepeatable = true; // Defines if the execute fuction is designed to be called multiple times in the future

    //These Variables are NOT optional, and the execution will fail if they do not exist. If there is no request for ether or tokens, leave the variables empty.
    uint256 RequestEther = 0; //The amount of ether the contract would like to receive on execution
    uint256 RequestTokens = 0; //The amount of tokens the contract would like to receive on execution
    address TokenAddress = 0x0000000000000000000000000000000000000000; //The address of the ERC20 token in which the contract may ask to receive


    //Additional variables can be added here
    address public ExternalContract = 0x0000000000000000000000000000000000000000;
    //Additional variables can be added here


    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract
        require(msg.sender == DAO);
        _;
    }


    function Execute() external OnlyDAO returns(bool success){
        Executions++; //Updates first to avoid recursive calling
//        EROSDAO(DAO).ErosProposalExecuted(address(this));

        //External or internal code to execute
        ExtCon(ExternalContract).Increment();
        //External or internal code to execute

        if()
        return(success);
    }
    //The contract will return any ether unused in the transaction back to the DAO on execution
    //therefore the contract will never have greater than 0 ether in state.


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