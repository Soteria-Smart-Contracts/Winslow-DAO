//SPDX-License-Identifier:UNLICENSE
//This contract is able to be replaced by the Harmonia Core, and can also continue to be used if a new Harmonia Core is deployed by changing DAO addresses
//When setting up a new core or voting contract, ensure cross-compatibility and record keeping done by the archive contract, voting index and proposal indexes never restart
pragma solidity ^0.8.17;



contract VotingSystemV1 {
    // Proposal executioner's bonus, proposal incentive burn percentage 
    address public DAO;
    address public CLD;
    uint256 public MemberHolding;
    // These two are in Basis Points
    uint256 public ExecutorCut;
    uint256 public BurnCut;

    // Proposals being tracked by id here
    VoteInstance[] public VotingInstances;
    mapping(uint256 => MultiVoteCard) public MultiVotes;
    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterDetails)) public VoterInfo;


    struct VoteInstance {
        uint256 ProposalID;      //DAO Proposal for voting instance
        uint256 VoteStarts;      //Unix Time
        uint256 VoteEnds;        //Unix Time
        VoteStatus Status;       //Using VoteResult enum
        uint256 ActiveVoters;    //Total Number of users that have voted
        uint256 TotalCLDVoted;   //Total of CLD used in this instance for voting
        bool MultiVote;          //Determines if this instance supports multivote
        uint256 YEAvotes;        //Votes to approve
        uint256 NAYvotes;        //Votes to refuse
        uint256 TotalIncentive;  //Total amount of CLD donated to this proposal for voting incentives, burning and execution reward
        uint256 IncentivePerVote;//Total amount of CLD per 0.01 CLD voted
        uint256 CLDtoIncentive;  //Total amount of CLD to be shared amongst voters
        uint256 CLDToBurn;       //Total amount of CLD to be burned on proposal execution
        uint256 CLDToExecutioner;//Total amount of CLD to be sent to the address that pays the gas for executing the proposal
    }

    struct MultiVoteCard{
        uint256 OptionOne;
        uint256 OptionTwo;
        uint256 OptionThree;
        uint256 OptionFour;
        uint256 OptionFive;
    }

    struct VoterDetails {
        uint256 VotesLocked;
        bool CLDReturned;
        bool Voted;
    }

    enum Vote{
        YEA,
        NAY
    }

    enum MultiOptions{
        OptionOne,
        OptionTwo,
        OptionThree,
        OptionFour,
        OptionFive
    }

    enum VoteStatus{
        VotingIncomplete,
        VotingActive,
        VotingComplete
    }

    event ProposalCreated(address proposer, uint256 proposalID, uint256 voteStart, uint256 voteEnd);
    event ProposalPassed(address executor, uint256 VotingInstance, uint256 amountBurned, uint256 executShare);
    event ProposalNotPassed(address executor, uint256 VotingInstance, uint256 amountBurned, uint256 executShare);
    event VoteCast(uint256 VotingInstance, string option, uint256 votesCasted);
    event ProposalIncentivized(address donator, uint256 VotingInstance, uint256 amountDonated);
    event IncentiveWithdrawed(uint256 remainingIncentive);
    event NewDAOAddress(address NewAddress);
    event FallbackToTreasury(uint256 amount);
 
    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    }

    constructor(address CLDAddr, address DAOAddr, uint8 _ExecusCut, uint8 _BurnCut){
        ExecutorCut = _ExecusCut;
        BurnCut = _BurnCut;
        DAO = DAOAddr;
        CLD = CLDAddr;
    }

    //Pre-Vote Functions (Incentivize is available pre and during vote)
    

    //Active Vote Functions
    function IncentivizeProposal(uint256 VotingInstance, uint256 amount) public returns(bool success){
        require(ERC20(CLD).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.IncentivizeProposal: You do not have enough CLD to incentivize this proposal or you may not have given this contract enough allowance");
        require(VotingInstances[VotingInstance].Status == VoteStatus(0), 'VotingSystemV1.IncentivizeProposal: This proposal has ended');
        require(block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.IncentivizeProposal: The voting period has ended, save for the next proposal!");

        VotingInstances[VotingInstance].TotalIncentive += amount;

        _updateTaxesAndIndIncentive(VotingInstance);
        emit ProposalIncentivized(msg.sender, VotingInstance, VotingInstances[VotingInstance].TotalIncentive);
        return(success);
    }

    function CastVote(uint256 amount, uint256 VotingInstance, Vote VoteChoice) external returns(bool success){
        require(ERC20(CLD).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.CastVote: You do not have enough CLD to vote this amount or have not given the proper allowance to voting");
        require(VoteChoice == Vote(0) || VoteChoice == Vote(1), "VotingSystemV1.CastVote: You must either vote YEA or NAY");
        require(amount >= 10000000000000000, "VotingSystemV1.CastVote: The minimum CLD per vote is 0.01"); //For incentive payout reasons
        require(!VoterInfo[VotingInstance][msg.sender].Voted, "VotingSystemV1.CastVote: You may only cast a single vote per address per proposal"); //This may be changed in V2
        require(block.timestamp >= VotingInstances[VotingInstance].VoteStarts && block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.CastVote: This instance is not currently in voting");

        if(VoteChoice == Vote(0)) {
            VotingInstances[VotingInstance].YEAvotes += amount;
            emit VoteCast(VotingInstance, "YEA", amount);
        } else {
            VotingInstances[VotingInstance].NAYvotes += amount;
            emit VoteCast(VotingInstance, "NEA", amount);
        }

        VoterInfo[VotingInstance][msg.sender].VotesLocked += amount;
        VoterInfo[VotingInstance][msg.sender].Voted = true;
        VotingInstances[VotingInstance].ActiveVoters += 1;

        _updateTaxesAndIndIncentive(VotingInstance);
        return(success);
    }

    function CastMultiVote(uint256 amount, uint256 VotingInstance, Vote VoteChoice, MultiVoteCard)

    //Post-Vote Functions

    function ReturnTokens(uint256 VotingInstance) external { //For returning your tokens for a specific instance after voting, with the incentive payout
        require(VoterInfo[VotingInstance][msg.sender].Voted == true);
        require(VoterInfo[VotingInstance][msg.sender].CLDReturned == false);
        VoterInfo[VotingInstance][msg.sender].CLDReturned = true;

        uint256 TotalToReturn;
        TotalToReturn += VoterInfo[VotingInstance][msg.sender].VotesLocked;
        TotalToReturn += (((VoterInfo[VotingInstance][msg.sender].VotesLocked * 100) * VotingInstances[VotingInstance].IncentivePerVote) / 10**9);

        //emit TokensReturned(VotingInstances[VotingInstance].IncentiveAmount);
    }

    //OnlyDAO functions

        //Vote Setup
    function InitializeVoteInstance(address Proposer, uint256 ProposalID, uint256 Time) external OnlyDAO {
        require(Time > 0, "VotingSystemV1.CreateProposal: Proposals need an end time");

        VotingInstances.push(VoteInstance(ProposalID,0,0,VoteStatus(0),0,0,0,0,0,0,0,0,0));

        emit ProposalCreated(Proposer, ProposalID, block.timestamp, block.timestamp + Time);
    }

        //Status Changes
    function EndVoting(uint256 VotingInstance) external OnlyDAO {
        require(block.timestamp >= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.ExecuteProposal: Voting is not over");      
        require(VotingInstances[VotingInstance].Status == VoteStatus(1), "VotingSystemV1.ExecuteProposal: Proposal already executed!");
        require(VotingInstances[VotingInstance].ActiveVoters > 0, "VotingSystemV1.ExecuteProposal: Can't execute proposals without voters!");

        ERC20(CLD).Burn(VotingInstances[VotingInstance].CLDToBurn);
        
        ERC20(CLD).transfer(msg.sender, VotingInstances[VotingInstance].CLDToExecutioner);

        VotingInstances[VotingInstance].IncentivePerVote = ((VotingInstances[VotingInstance].CLDtoIncentive * 10**9) / VotingInstances[VotingInstance].TotalCLDVoted);

        VotingInstances[VotingInstance].Status = VoteStatus(2);
        //Post results
    }

        //Post results to archive contract function

    function SetTaxAmount(uint256 NewExecCut, uint256 NewBurnCut) external OnlyDAO returns (bool success) {
        require(NewExecCut > 0 && NewExecCut <= 10000);
        require(NewExecCut > 0 && NewExecCut <= 10000);

        ExecutorCut = NewExecCut;
        BurnCut = NewBurnCut;

        return true;
    }

    function ChangeDAO(address newAddr) external OnlyDAO {
        require(DAO != newAddr, "VotingSystemV1.ChangeDAO: New DAO address can't be the same as the old one");
        require(address(newAddr) != address(0), "VotingSystemV1.ChangeDAO: New DAO can't be the zero address");
        DAO = newAddr;    
        emit NewDAOAddress(newAddr);
    }
    
    /////////////////////////////////////////
    /////        Internal functions     /////
    /////////////////////////////////////////

    // TO DO Refactor this

    function _updateTaxesAndIndIncentive(uint256 VotingInstance) internal  {    
            VotingInstances[VotingInstance].CLDToBurn = ((VotingInstances[VotingInstance].TotalIncentive * BurnCut) / 10000);

            VotingInstances[VotingInstance].CLDToExecutioner = ((VotingInstances[VotingInstance].TotalIncentive * ExecutorCut) / 10000);

            VotingInstances[VotingInstance].CLDtoIncentive = VotingInstances[VotingInstance].TotalIncentive - (VotingInstances[VotingInstance].CLDToBurn + VotingInstances[VotingInstance].CLDToExecutioner);
    }

    //function _updateIncentiveShare(uint256 VotingInstance, uint256 _baseTokenAmount) internal {
        
    //}

    receive() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(HarmoniaDAO(DAO).Treasury()).transfer(address(this).balance);
    }

    fallback() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(HarmoniaDAO(DAO).Treasury()).transfer(address(this).balance);
    }

}

    /////////////////////////////////////////
    /////          Interfaces           /////
    /////////////////////////////////////////

interface HarmoniaDAO {
    function Treasury() external returns(address payable TreausryAddress);
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