//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{
    address public WinslowTokenAddress = 0xd683198d0a223Bc25ad6c199A86E08a4fcF3a77a;

    struct Proposal{
        string Memo;
        uint256 Yay;
        uint256 Nay;
        bool passed;
        bool executed;
        address[] voters;
    }

    mapping(uint256 => Proposal) public Proposals;
    mapping(address => mapping(uint256 => bool)) public Voted;
    mapping(address => mapping(uint256 => uint256)) public VoteAmount;
    uint256 public ProposalCount = 0;


    function CreateProposal(string memory memo) public returns(uint256){
        ProposalCount++;
        Proposals[ProposalCount].Memo = memo;
        return ProposalCount;
    }

    function Vote(uint256 proposalId, bool vote, uint256 Amount) public{
        require(Voted[msg.sender][proposalId] == false, "You have already voted on this proposal");
        require(ERC20(WinslowTokenAddress).transferFrom(msg.sender, address(this), Amount), "Error transferring tokens");

        VoteAmount[msg.sender][proposalId] = Amount;

        Voted[msg.sender][proposalId] = true;
        if(vote){
            Proposals[proposalId].Yay += Amount;
        }else{
            Proposals[proposalId].Nay += Amount;
        }

        Proposals[proposalId].voters.push(msg.sender);
    }

    function ExecuteProposal(uint256 proposalId) public{
        require(Proposals[proposalId].executed == false, "This proposal has already been executed");
        
        if(Proposals[proposalId].Yay > Proposals[proposalId].Nay){
            Proposals[proposalId].passed = true;
        }

        Proposals[proposalId].executed = true;

        for(uint256 i = 0; i < Proposals[proposalId].voters.length; i++){
            address Voter = Proposals[proposalId].voters[i];
            uint256 Amount = VoteAmount[Voter][proposalId];    
            ERC20(WinslowTokenAddress).transfer(Voter, Amount);  

            VoteAmount[Voter][proposalId] = 0;  
        }
    }

    function GetProposalInfo(uint256 proposalId) public view returns(string memory, uint256, uint256, bool, bool){
        return(Proposals[proposalId].Memo, Proposals[proposalId].Yay, Proposals[proposalId].Nay, Proposals[proposalId].passed, Proposals[proposalId].executed);
    }

}

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 value) external returns (bool);
  function transfer(address to, uint256 value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint256);
  function Burn(uint256 _BurnAmount) external;
}