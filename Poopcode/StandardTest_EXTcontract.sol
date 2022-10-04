//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract ImExternal{
    address public DAO;
    string public Information;
    uint public Integer;

    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract
        require(msg.sender == DAO  || EROSDAO(DAO).CheckErosApproval(address(this)), "The caller is either not the DAO or not approved by the DAO");
        _;
    }

    function Update(string input) external OnlyDAO{
        Information = input;
    } 

    function Increment() external OnlyDAO{
        Integer++;
    } 

    interface EROSDAO{
    function CheckErosApproval(address) external view returns(bool);
    function ErosProposalExecuted(address) external; //This function in the DAO must require that the msg.sender is the same as the input
}



}