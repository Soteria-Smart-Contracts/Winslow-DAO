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

    function Vote(uint256 proposalId, bool vote, uint256 Amount) public{
        require(Voted[msg.sender][proposalId] == false, "You have already voted on this proposal");
        Voted[msg.sender][proposalId] = true;
        if(vote){
            Proposals[proposalId].Yay++;
        }else{
            Proposals[proposalId].Nay++;
        }
        Proposals[proposalId].voters.push(msg.sender);
    }











}

interface ERC20{
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}