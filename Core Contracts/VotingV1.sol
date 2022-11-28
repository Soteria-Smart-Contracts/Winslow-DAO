//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract VotingSystemV1 {
    // Proposal executioner's bonus, proposal incentive burn percentage 
    address public DAO;
    address public CLD;
    uint public MemberHolding;
    // These two are in Basis Points
    uint public ExecusCut;
    uint public BurnCut;

    event ProposalCreated(address proposer, uint256 proposalID, uint voteStart, uint voteEnd);
    event ProposalPassed(address executor, uint proposalId, uint amountBurned, uint executShare);
    event ProposalNotPassed(address executor, uint proposalId, uint amountBurned, uint executShare);
    event CastedVote(uint proposalId, string option, uint votesCasted);
    event ProposalIncentivized(address donator, uint proposalId, uint amountDonated);
    event IncentiveWithdrawed(uint remainingIncentive);
    event NewDAOAddress(address NewAddress);

    enum Vote{
        Yea,
        Nay
    }

    struct ProposalCore {
        uint256 ProposalID;
        uint VoteStarts;
        uint VoteEnds;
        uint8 Passed; // Can be 0 "Not voted", 1 "Passed" or 2 "Not Passed"
        uint ActiveVoters;
        uint ApprovingVotes;
        uint RefusingVotes;
        bool Executed;
        uint IncentiveAmount;
        uint IncentiveShare;
        uint AmountToBurn;
        uint AmountToExecutioner;
    }

    struct VoterInfo {
        uint VotesLocked;
        uint AmountDonated;
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
    function CreateProposal(address Proposer, uint256 ProposalID, uint Time) external OnlyDAO {
        require(Time > 0, "VotingSystemV1.CreateProposal: Proposals need an end time");

        proposal.push(
            ProposalCore({
                ProposalID: ProposalID,
                VoteStarts: block.timestamp,
                VoteEnds: block.timestamp + Time,
                Passed: 0, // Not voted yet
                ActiveVoters: 0,
                ApprovingVotes: 0,
                RefusingVotes: 0,
                Executed: false,
                IncentiveAmount: 0,
                IncentiveShare: 0,
                AmountToBurn: 0,
                AmountToExecutioner: 0
            })
        );

        emit ProposalCreated(Proposer, ProposalID, block.timestamp, block.timestamp + Time);
    }

    function IncentivizeProposal(uint proposalId, uint amount) external {
        require(ERC20(CLD).transferFrom(msg.sender, address(this), amount), 
            "VotingSystemV1.IncentivizeProposal: You do not have enough CLD to incentivize this proposal"
        );
        require(ERC20(CLD).allowance(msg.sender, address(this)) >= amount, 
            "VotingSystemV1.IncentivizeProposal: You have not given Voting enough allowance"
        );
        require(proposal[proposalId].Passed == 0, 
            'VotingSystemV1.IncentivizeProposal: This proposal has ended');
        require(block.timestamp <= proposal[proposalId].VoteEnds, 
            "VotingSystemV1.IncentivizeProposal: The voting period has ended, save for the next proposal!"
        );

        proposal[proposalId].IncentiveAmount += amount;
        voterInfo[proposalId][msg.sender].AmountDonated += amount;

        _updateTaxesAndIndIncentive(proposalId, true);
        emit ProposalIncentivized(msg.sender, proposalId, proposal[proposalId].IncentiveAmount);
    }

    function CastVote(uint amount, uint proposalId, uint8 yesOrNo) external {
        require(
            ERC20(CLD).allowance(msg.sender, address(this)) >= amount, 
            "VotingSystemV1.CastVote: You have not given the voting contract enough allowance"
        );
        require(
            ERC20(CLD).transferFrom(msg.sender, address(this), amount), 
            "VotingSystemV1.CastVote: You do not have enough CLD to vote this amount"
        );
        require(
            yesOrNo == 0 || yesOrNo == 1, 
            "VotingSystemV1.CastVote: You must either vote 'Yes' or 'No'"
        );
        require(proposal[proposalId].Passed == 0, 'VotingSystemV1.CastVote: This proposal has ended');
        require(!voterInfo[proposalId][msg.sender].Voted, "VotingSystemV1.CastVote: You already voted in this proposal");
        require(block.timestamp <= proposal[proposalId].VoteEnds, "VotingSystemV1.CastVote: The voting period has ended");


        if(yesOrNo == 0) {
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
    function ExecuteProposal(uint proposalId) external {
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

    function WithdrawMyTokens(uint proposalId) external {
        if (proposal[proposalId].ActiveVoters > 0) {
            require(proposal[proposalId].Executed, 
            'VotingSystemV1.WithdrawMyTokens: Proposal has not been executed!');
            _returnTokens(proposalId, msg.sender);
        } else {
            _returnTokens(proposalId, msg.sender);
        }

        emit IncentiveWithdrawed(proposal[proposalId].IncentiveAmount);
    }

    function SetTaxAmount(uint amount, string memory taxToSet) public OnlyDAO returns (bool) {
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

    function SeeProposalInfo(uint proposalId) 
    public 
    view 
    returns (
        uint256,
        uint,
        uint,
        uint8,
        uint,
        uint,
        uint,
        bool,
        uint,
        uint,
        uint,
        uint
    ) 
    {
        ProposalCore memory _proposal = proposal[proposalId];      
        return (
            _proposal.ProposalID,
            _proposal.VoteStarts,
            _proposal.VoteEnds,
            _proposal.Passed,
            _proposal.ActiveVoters,
            _proposal.ApprovingVotes,
            _proposal.RefusingVotes,
            _proposal.Executed,
            _proposal.IncentiveAmount,
            _proposal.IncentiveShare,
            _proposal.AmountToBurn,
            _proposal.AmountToExecutioner
            );
    }
    
    /////////////////////////////////////////
    /////        Internal functions     /////
    /////////////////////////////////////////

    // TO DO Refactor this
    function _returnTokens(
        uint _proposalId,
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

    function _updateTaxesAndIndIncentive(uint _proposalId, bool allOfThem) internal  {
        if (allOfThem) {            
            uint newBurnAmount = proposal[_proposalId].IncentiveAmount * BurnCut / 10000;
            proposal[_proposalId].AmountToBurn = newBurnAmount;

            uint newToExecutAmount = proposal[_proposalId].IncentiveAmount * ExecusCut / 10000;
            proposal[_proposalId].AmountToExecutioner = newToExecutAmount;

            _updateIncentiveShare(_proposalId, proposal[_proposalId].IncentiveAmount);
        } else {
            _updateIncentiveShare(_proposalId, proposal[_proposalId].IncentiveAmount);
        }

    }

    function _updateIncentiveShare(uint _proposalId, uint _baseTokenAmount) internal {
        uint totalTokenAmount = _baseTokenAmount - (proposal[_proposalId].AmountToBurn + proposal[_proposalId].AmountToExecutioner);
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
        uint proposalId
        ) 
        external view returns (
        uint,
        uint,  
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
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
  function Burn(uint256 _BurnAmount) external;
}

//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future, only Eros proposals will be able to access it due to their flexibility
interface TreasuryV1{
    //Public State Modifing Functions
    function ReceiveRegisteredAsset(uint8 AssetID, uint amount) external;
    function UserAssetClaim(uint256 CLDamount) external returns(bool success);
    function AssetClaim(uint256 CLDamount, address From, address payable To) external returns(bool success);
    //OnlyDAO or OnlyEros State Modifing Functions
    function TransferETH(uint256 amount, address payable receiver) external;
    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external;
    function RegisterAsset(address tokenAddress, uint8 slot) external;
    function ChangeRegisteredAssetLimit(uint8 NewLimit) external;
    //Public View Functions
    function IsRegistered(address TokenAddress) external view returns(bool);
    function GetBackingValueEther(uint256 CLDamount) external view returns(uint256 EtherBacking);
    function GetBackingValueAsset(uint256 CLDamount, uint8 AssetID) external view returns(uint256 AssetBacking);

}