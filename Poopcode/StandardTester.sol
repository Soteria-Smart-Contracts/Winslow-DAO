//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

//Just a testing contract, nothing to see here!
contract TheFakeDAO{
    address public owner;

    mapping(address => bool) public ApprovedErosProposals;

    modifier OnlyOwner{
        require(msg.sender == owner);
        _;
    }

    constructor(){
        owner = msg.sender;
    }

    function ApproveErosContract(address Proposal) external OnlyOwner{
        ApprovedErosProposals[Proposal] = true;
    }

    function ExecuteErosProposal(address Proposal) external OnlyOwner{
        require(ApprovedErosProposals[Proposal] == true, "Eros External Proposal Contract not approved");

        EROSEXT(Proposal).Execute();
    }

    function 

}

interface EROSEXT{
    function Execute() external;
}

