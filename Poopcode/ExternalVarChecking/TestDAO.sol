//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract WinslowDAOcompact{
    address public WinslowTokenAddress;

    struct Proposal{
        string Memo;
        uint256 Yay;
        uint256 Nay;
        bool passed;
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