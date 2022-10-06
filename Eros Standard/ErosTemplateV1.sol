//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract ErosProposal{
    address public DAO = 0x0000000000000000000000000000000000000000;
    bool public Executed;
    uint256 RequestEther = 1 ether;
    uint256 RequestTokens = 0;
    address TokenAddress = 0x0000000000000000000000000000000000000000;

    //Events
    event Executed
    //Events

    //Additional variables can be added here
    address public ExternalContract = 0x0000000000000000000000000000000000000000;
    //Additional variables can be added here

    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract 
        require(msg.sender == DAO);
        _;
    }


    function Execute() external OnlyDAO returns(bool success){
        Executed = true; //Updates first to avoid recursive calling
//        EROSDAO(DAO).ErosProposalExecuted(address(this)); Updates in the DAO automatically instead fyi

        //External or internal code to execute
        ExtCon(ExternalContract).Update("This value was updated by the DAO!");
        //External or internal code to execute


        if(address(this).balance > 0){ //Must be the last part of this function
            payable(DAO).transfer(address(this).balance);
        }
        if((TokenAddress != address(0)) && (ERC20(TokenAddress).balanceOf(address(this)) < 0)){
            ERC20(TokenAddress).transfer(DAO, ERC20(TokenAddress).balanceOf(address(this)));
        }

        return(success);
    }

    //Additional functions can go here that can only be executed by the Execute() function, therefore must be internal, public functions may present vulenrabilities to external contracts

}

interface EROSDAO{
    function CheckErosApproval(address) external view returns(bool);
    function ErosProposalExecuted(address) external; //This function in the DAO must require that the msg.sender is the same as the input
}

interface ExtCon{ //Interface name can be different, ensure it is updated correctly with the external functions to be used in execution
    function ErosImplemented() external view returns(bool);
    function Update(string calldata) external;
}

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
} 