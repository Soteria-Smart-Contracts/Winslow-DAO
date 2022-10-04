//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

//Just a testing contract, nothing to see here!
contract TheFakeDAO{
    address public owner;

    mapping(address => bool) public ErosProposals;

    modifier OnlyOwner{
        require(msg.sender == owner);
        _;
    }

    constructor(){
        owner = msg.sender;
    }

    function ApproveErosContract(address Proposal) external OnlyOwner{
        ErosProposals[Proposal] = true;
    }

    function ExecuteErosProposal(address Proposal) external OnlyOwner{

    }

}

interface EROSEXT{
    function Execute() external 
}

