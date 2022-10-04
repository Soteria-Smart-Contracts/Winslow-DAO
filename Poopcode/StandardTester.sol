//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract TheFakeDAO{
    address public owner;

    mapping(address => bool) public ErosProposals;

    constructor(){
        owner = msg.sender;
    }

    function ApproveErosContract(address Proposal)

}