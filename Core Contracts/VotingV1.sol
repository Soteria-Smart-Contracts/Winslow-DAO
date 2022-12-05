//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract VotingSystemV1 {
    // Proposal executioner's bonus, proposal incentive burn percentage 
    address public DAO;
    address public CLD;
    uint256 public MemberHolding;
    // These two are in Basis Points
    uint256 public ExecusCut;
    uint256 public BurnCut;

    event ProposalCreated(address proposer, uint256 proposalID, uint256 voteStart, uint256 voteEnd);
    event ProposalPassed(address executor, uint256 proposalId, uint256 amountBurned, uint256 executShare);
    event ProposalNotPassed(address executor, uint256 proposalId, uint256 amountBurned, uint256 executShare);
    event CastedVote(uint256 proposalId, string option, uint256 votesCasted);
    event ProposalIncentivized(address donator, uint256 proposalId, uint256 amountDonated);
    event IncentiveWithdrawed(uint256 remainingIncentive);
    event NewDAOAddress(address NewAddress);

    enum Vote{
        YEA,
        NAY
    }

    enum VoteResult{
        VotingIncomplete,
        Approved,
        Refused
    }

    //Create vote status enum instead of using uint8

    struct ProposalCore {
        uint256 ProposalID;
        uint256 VoteStarts;
        uint256 VoteEnds;
        VoteResult Result;
        uint256 ActiveVoters;
        uint256 YEAvotes;
        uint256 NAYvotes;
        bool Executed;
        uint256 TotalIncentive;
        uint256 IncentivePerVote;
        uint256 CLDToBurn;
        uint256 CLDToExecutioner;
    }

    struct VoterInfo {
        uint256 VotesLocked;
        uint256 AmountDonated;
        bool Voted;
        bool IsExecutioner;
    }

    // Proposals being tracked by id here
    ProposalCore[] public proposal;
    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterInfo)) internal voterInfo;
 
    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    }

    constructor(address CLDAddr, address DAOAddr, uint8 _ExecusCut, uint8 _BurnCut) 
    {
        ExecusCut = _ExecusCut;
        BurnCut = _BurnCut;
        DAO = DAOAddr;
        CLD = CLDAddr;

        // TO DO insert poetic proposal #0 here
    }

    // To do people should lock tokens in order to propose?
    function InitializeVote(address Proposer, uint256 ProposalID, uint256 Time) external OnlyDAO {
        require(Time > 0, "VotingSystemV1.CreateProposal: Proposals need an end time");

        proposal.push(
            ProposalCore({
                ProposalID,
                0, //Vote will only start when the DAO says so, so not at this point, must await security verification
                0,
                0, // Not voted yet
                0,
                0,
                0,
                false,
                IncentiveAmount: 0,
                IncentiveShare: 0,
                AmountToBurn: 0,
                AmountToExecutioner: 0
            })
        );

        emit ProposalCreated(Proposer, ProposalID, block.timestamp, block.timestamp + Time);
    }

    function IncentivizeProposal(uint256 proposalId, uint256 amount) external {
        require(ERC20(CLD).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.IncentivizeProposal: You do not have enough CLD to incentivize this proposal or you may not have given this contract enough allowance");
//        require(ERC20(CLD).allowance(msg.sender, address(this)) >= amount, 
//            "VotingSystemV1.IncentivizeProposal: You have not given Voting enough allowance" //Dont need this, transferfrom will fail first
//        );
        require(proposal[proposalId].Passed == 0, 
            'VotingSystemV1.IncentivizeProposal: This proposal has ended');
        require(block.timestamp <= proposal[proposalId].VoteEnds, "VotingSystemV1.IncentivizeProposal: The voting period has ended, save for the next proposal!");

        proposal[proposalId].IncentiveAmount += amount;
        voterInfo[proposalId][msg.sender].AmountDonated += amount;

        _updateTaxesAndIndIncentive(proposalId, true);
        emit ProposalIncentivized(msg.sender, proposalId, proposal[proposalId].IncentiveAmount);
    }//Checked

    function CastVote(uint256 amount, uint256 proposalId, Vote VoteChoice) external {
        require(
            ERC20(CLD).allowance(msg.sender, address(this)) >= amount, 
            "VotingSystemV1.CastVote: You have not given the voting contract enough allowance"
        );
        require(
            ERC20(CLD).transferFrom(msg.sender, address(this), amount), 
            "VotingSystemV1.CastVote: You do not have enough CLD to vote this amount"
        );
        require(
            VoteChoice == Vote(0) || VoteChoice == Vote(1), 
            "VotingSystemV1.CastVote: You must either vote 'Yea' or 'Nay'"
        );
        require(proposal[proposalId].Passed == 0, 'VotingSystemV1.CastVote: This proposal has ended');
        require(!voterInfo[proposalId][msg.sender].Voted, "VotingSystemV1.CastVote: You already voted in this proposal");
        require(block.timestamp <= proposal[proposalId].VoteEnds, "VotingSystemV1.CastVote: The voting period has ended");


        if(VoteChoice == Vote(0)) {
            proposal[proposalId].ApprovingVotes += amount;
            emit CastedVote(proposalId, "Yes", amount);
        } else {
            proposal[proposalId].RefusingVotes += amount;
            emit CastedVote(proposalId, "No", amount);
        }
        voterInfo[proposalId][msg.sender].VotesLocked += amount;
        voterInfo[proposalId][msg.sender].Voted = true;
        proposal[proposalId].ActiveVoters += 1;

        _updateTaxesAndIndIncentive(proposalId, false);
    }

    // Proposal execution code
    function ExecuteProposal(uint256 proposalId) external {
        require(block.timestamp >= proposal[proposalId].VoteEnds, 
            "VotingSystemV1.ExecuteProposal: Voting has not ended");      
        require(proposal[proposalId].Executed == false, 
            "VotingSystemV1.ExecuteProposal: Proposal already executed!");
        require(proposal[proposalId].ActiveVoters > 0, 
            "VotingSystemV1.ExecuteProposal: Can't execute proposals without voters!");
        voterInfo[proposalId][msg.sender].IsExecutioner = true;

        ERC20(CLD).Burn(proposal[proposalId].AmountToBurn);
        proposal[proposalId].IncentiveAmount -= proposal[proposalId].AmountToBurn;
        
        ERC20(CLD).transfer(msg.sender, proposal[proposalId].AmountToExecutioner);
        proposal[proposalId].IncentiveAmount -= proposal[proposalId].AmountToExecutioner;

        if (proposal[proposalId].ApprovingVotes > proposal[proposalId].RefusingVotes) {
            // TO DO Connect this to the real core
            proposal[proposalId].Passed = 1;
//            FakeDAO(DAO).ExecuteCoreProposal(proposalId, true); //turn into interface

            emit ProposalPassed(msg.sender, proposalId, proposal[proposalId].AmountToBurn, proposal[proposalId].AmountToExecutioner);
        } else {
            // TO DO Execution (or lack of)
            proposal[proposalId].Passed = 2;
//            FakeDAO(DAO).ExecuteCoreProposal(proposalId, false); //turn into interface

            emit ProposalNotPassed(msg.sender, proposalId, proposal[proposalId].AmountToBurn, proposal[proposalId].AmountToExecutioner);
        }

        proposal[proposalId].Executed = true;
    }

    function WithdrawMyTokens(uint256 proposalId) external {
        if (proposal[proposalId].ActiveVoters > 0) {
            require(proposal[proposalId].Executed, 
            'VotingSystemV1.WithdrawMyTokens: Proposal has not been executed!');
            _returnTokens(proposalId, msg.sender);
        } else {
            _returnTokens(proposalId, msg.sender);
        }

        emit IncentiveWithdrawed(proposal[proposalId].IncentiveAmount);
    }

    function SetTaxAmount(uint256 amount, string memory taxToSet) public OnlyDAO returns (bool) {
        bytes32 _setHash = keccak256(abi.encodePacked(taxToSet));
        bytes32 _execusCut = keccak256(abi.encodePacked("execusCut"));
        bytes32 _burnCut = keccak256(abi.encodePacked("burnCut"));
        bytes32 _memberHolding = keccak256(abi.encodePacked("memberHolding"));

        if (_setHash == _execusCut || _setHash == _burnCut) {
            require(amount >= 10 && amount <= 10000, 
            "VotingSystemV1.SetTaxAmount: Percentages can't be higher than 100");
            ExecusCut = amount;
        } else if (_setHash == _memberHolding) {
            MemberHolding = amount;
        } else {
            revert("VotingSystemV1.SetTaxAmount: You didn't choose a valid setting to modify!");
        }

        return true;
    }

    function ChangeDAO(address newAddr) external OnlyDAO {
        require(DAO != newAddr, 
            "VotingSystemV1.ChangeDAO: New DAO address can't be the same as the old one");
        require(address(newAddr) != address(0), 
            "VotingSystemV1.ChangeDAO: New DAO can't be the zero address");
        DAO = newAddr;        
        emit NewDAOAddress(newAddr);
    }
    
    /////////////////////////////////////////
    /////        Internal functions     /////
    /////////////////////////////////////////

    // TO DO Refactor this
    function _returnTokens(
        uint256 _proposalId,
        address _voterAddr
        )
        internal {
        require(block.timestamp >= proposal[_proposalId].VoteEnds, 
            "VotingSystemV1.WithdrawMyTokens: The voting period hasn't ended");

        if (proposal[_proposalId].ActiveVoters > 0) {
            require(
                voterInfo[_proposalId][_voterAddr].VotesLocked > 0, 
                "VotingSystemV1.WithdrawMyTokens: You have no VotesLocked in this proposal"
            );
            ERC20(CLD).transfer(_voterAddr, voterInfo[_proposalId][_voterAddr].VotesLocked + proposal[_proposalId].IncentiveShare);
            proposal[_proposalId].IncentiveAmount -= proposal[_proposalId].IncentiveShare; 
        } else {
            require(
                voterInfo[_proposalId][_voterAddr].AmountDonated > 0, 
                "VotingSystemV1.WithdrawMyTokens: You have no AmountDonated in this proposal"
            );
            ERC20(CLD).transfer(_voterAddr, voterInfo[_proposalId][_voterAddr].AmountDonated);
            voterInfo[_proposalId][_voterAddr].AmountDonated -= voterInfo[_proposalId][_voterAddr].AmountDonated;
            proposal[_proposalId].IncentiveAmount -= voterInfo[_proposalId][_voterAddr].AmountDonated;
        }
        
        voterInfo[_proposalId][_voterAddr].VotesLocked -= voterInfo[_proposalId][_voterAddr].VotesLocked;
    }

    function _updateTaxesAndIndIncentive(uint256 _proposalId, bool allOfThem) internal  {
        if (allOfThem) {            
            uint256 newBurnAmount = proposal[_proposalId].IncentiveAmount * BurnCut / 10000;
            proposal[_proposalId].AmountToBurn = newBurnAmount;

            uint newToExecutAmount = proposal[_proposalId].IncentiveAmount * ExecusCut / 10000;
            proposal[_proposalId].AmountToExecutioner = newToExecutAmount;

            _updateIncentiveShare(_proposalId, proposal[_proposalId].IncentiveAmount);
        } else {
            _updateIncentiveShare(_proposalId, proposal[_proposalId].IncentiveAmount);
        }

    }

    function _updateIncentiveShare(uint256 _proposalId, uint256 _baseTokenAmount) internal {
        uint256 totalTokenAmount = _baseTokenAmount - (proposal[_proposalId].AmountToBurn + proposal[_proposalId].AmountToExecutioner);
        if (proposal[_proposalId].ActiveVoters > 0) {
            proposal[_proposalId].IncentiveShare = totalTokenAmount / proposal[_proposalId].ActiveVoters;
        } else {
            proposal[_proposalId].IncentiveShare = totalTokenAmount;
        }
    }

    /////////////////////////////////////////
    /////          Debug Tools          /////
    /////////////////////////////////////////

    function viewVoterInfo(
        address voter, 
        uint256 proposalId
        ) 
        external view returns (
        uint256,
        uint256,  
        bool 
    ) 
    {
        return (
            voterInfo[proposalId][voter].VotesLocked,
            voterInfo[proposalId][voter].AmountDonated,
            voterInfo[proposalId][voter].Voted
        );
    }
}

    /////////////////////////////////////////
    /////          Interfaces           /////
    /////////////////////////////////////////

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 value) external returns (bool);
  function transfer(address to, uint256 value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint256);
  function Burn(uint256 _BurnAmount) external;
}