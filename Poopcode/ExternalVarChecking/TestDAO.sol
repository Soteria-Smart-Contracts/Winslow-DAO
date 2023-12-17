//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{

    struct Proposal{
        string Memo;
        uint256 Yay;
        uint256 Nay;
        bool passed;
        address[] voters;
    }

    mapping(uint256 => Proposal) public Proposals;
    mapping(address => mapping(uint256 => bool)) public Voted;
    uint256 public ProposalCount = 0;


    function CreateProposal(string memory memo) public returns(uint256){
        ProposalCount++;
        Proposals[ProposalCount].Memo = memo;
        return ProposalCount;
    }

    











}