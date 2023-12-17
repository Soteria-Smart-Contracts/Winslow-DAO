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
    mapping(address => mapping()) public Balance;
    uint256 public ProposalCount = 0;


    function CreateProposal(string memory memo) public returns(uint256){
        ProposalCount++;
        Proposals[ProposalCount].Memo = memo;
        return ProposalCount;
    }

    function Vote(uint256 proposalId, bool vote) public{
        require(Proposals[proposalId].passed == false, "Proposal already passed");
        require(Proposals[proposalId].Yay + Proposals[proposalId].Nay < Proposals[proposalId].voters.length, "Proposal already passed");
        if(vote){
            Proposals[proposalId].Yay++;
        }else{
            Proposals[proposalId].Nay++;
        }
        Proposals[proposalId].voters.push(msg.sender);
        if(Proposals[proposalId].Yay > Proposals[proposalId].Nay){
            Proposals[proposalId].passed = true;
        }
    }











}