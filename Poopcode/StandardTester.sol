//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

//Just a testing contract, nothing to see here!
contract TheFakeDAO{
    address public owner;

    mapping(address => bool) public ErosProposals;

    modifier OnlyOwner{
        
    }

    constructor(){
        owner = msg.sender;
    }

    function ApproveErosContract(address Proposal)

}