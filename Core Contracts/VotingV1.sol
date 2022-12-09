//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract VotingSystemV1 {
    // Proposal executioner's bonus, proposal incentive burn percentage 
    address public DAO;
    address public CLD;
    uint256 public MemberHolding;
    // These two are in Basis Points
    uint256 public ExecutorCut;
    uint256 public BurnCut;

    event ProposalCreated(address proposer, uint256 proposalID, uint256 voteStart, uint256 voteEnd);
    event ProposalPassed(address executor, uint256 VotingInstance, uint256 amountBurned, uint256 executShare);
    event ProposalNotPassed(address executor, uint256 VotingInstance, uint256 amountBurned, uint256 executShare);
    event CastedVote(uint256 VotingInstance, string option, uint256 votesCasted);
    event ProposalIncentivized(address donator, uint256 VotingInstance, uint256 amountDonated);
    event IncentiveWithdrawed(uint256 remainingIncentive);
    event NewDAOAddress(address NewAddress);
    event FallbackToTreasury(uint256 amount);

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

    struct VoteInstance {
        uint256 ProposalID;      //DAO Proposal for voting instance
        uint256 VoteStarts;      //Unix Time
        uint256 VoteEnds;        //Unix Time
        VoteResult Result;       //Using VoteResult enum
        uint256 ActiveVoters;    //Total Number of users that have voted
        uint256 YEAvotes;        //Votes to approve
        uint256 NAYvotes;        //Votes to refuse
        bool Executed;           //Updated if the proposal utilising this instance has been executed by the DAO
        uint256 TotalIncentive;  //Total amount of CLD donated to this proposal for voting incentives, burning and execution reward
        uint256 IncentivePerVote;//Total amount of CLD per CLD voted 
        uint256 CLDToBurn;       //Total amount of CLD to be burned on proposal execution
        uint256 CLDToExecutioner;//Total amount of CLD to be sent to the address that pays the gas for executing the proposal
    }

    struct VoterDetails {
        uint256 VotesLocked;
        uint256 AmountDonated;
        bool Voted;
    }

    // Proposals being tracked by id here
    VoteInstance[] public VotingInstances;
    // Map user addresses over their info
    mapping (uint256 => mapping (address => VoterDetails)) public VoterInfo;
 
    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    }

    constructor(address CLDAddr, address DAOAddr, uint8 _ExecusCut, uint8 _BurnCut) 
    {
        ExecutorCut = _ExecusCut;
        BurnCut = _BurnCut;
        DAO = DAOAddr;
        CLD = CLDAddr;

        // TO DO insert poetic proposal #0 here
    }

    function IncentivizeProposal(uint256 VotingInstance, uint256 amount) external {
        require(ERC20(CLD).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.IncentivizeProposal: You do not have enough CLD to incentivize this proposal or you may not have given this contract enough allowance");
        require(VotingInstances[VotingInstance].Result == VoteResult(0), 'VotingSystemV1.IncentivizeProposal: This proposal has ended');
        require(block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.IncentivizeProposal: The voting period has ended, save for the next proposal!");

        VotingInstances[VotingInstance].TotalIncentive += amount;
        VoterInfo[VotingInstance][msg.sender].AmountDonated += amount;

        _updateTaxesAndIndIncentive(VotingInstance);
        emit ProposalIncentivized(msg.sender, VotingInstance, VotingInstances[VotingInstance].TotalIncentive);
    }//Checked

    function CastVote(uint256 amount, uint256 VotingInstance, Vote VoteChoice) external {
        require(ERC20(CLD).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.CastVote: You do not have enough CLD to vote this amount or have not given the proper allowance to voting");
        require(VoteChoice == Vote(0) || VoteChoice == Vote(1), "VotingSystemV1.CastVote: You must either vote Yea or 'Nay'");
        require(!VoterInfo[VotingInstance][msg.sender].Voted, "VotingSystemV1.CastVote: You already voted in this proposal");
        require(block.timestamp >= VotingInstances[VotingInstance].VoteStarts && block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.CastVote: This instance is not currently in voting");


        if(VoteChoice == Vote(0)) {
            VotingInstances[VotingInstance].YEAvotes += amount;
            emit CastedVote(VotingInstance, "Yes", amount);
        } else {
            VotingInstances[VotingInstance].NAYvotes += amount;
            emit CastedVote(VotingInstance, "No", amount);
        }
        VoterInfo[VotingInstance][msg.sender].VotesLocked += amount;
        VoterInfo[VotingInstance][msg.sender].Voted = true;
        VotingInstances[VotingInstance].ActiveVoters += 1;

        _updateTaxesAndIndIncentive(VotingInstance);
    }

    // Proposal execution code
    function ExecuteProposal(uint256 VotingInstance) external {
        require(block.timestamp >= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.ExecuteProposal: Voting is not over");      
        require(VotingInstances[VotingInstance].Executed == false, "VotingSystemV1.ExecuteProposal: Proposal already executed!");
        require(VotingInstances[VotingInstance].ActiveVoters > 0, "VotingSystemV1.ExecuteProposal: Can't execute proposals without voters!");

        ERC20(CLD).Burn(VotingInstances[VotingInstance].CLDToBurn);
        
        ERC20(CLD).transfer(msg.sender, VotingInstances[VotingInstance].CLDToExecutioner);

        VotingInstances[VotingInstance].Executed = true;
    }

    function WithdrawVoteTokens(uint256 VotingInstance) external { //Seb review this it looks weird
        if (VotingInstances[VotingInstance].ActiveVoters > 0) {
            require(VotingInstances[VotingInstance].Executed, 
            'VotingSystemV1.WithdrawMyTokens: Proposal has not been executed!');
            _returnTokens(VotingInstance, msg.sender);
        } else {
            _returnTokens(VotingInstance, msg.sender);
        }

      //  emit IncentiveWithdrawed(VotingInstances[VotingInstance].IncentiveAmount);
    }

    //OnlyDAO functions

    function InitializeVoteInstance(address Proposer, uint256 ProposalID, uint256 Time) external OnlyDAO {
        require(Time > 0, "VotingSystemV1.CreateProposal: Proposals need an end time");

        VotingInstances.push(VoteInstance(ProposalID,0,0,VoteResult(0),0,0,0,false,0,0,0,0));

        emit ProposalCreated(Proposer, ProposalID, block.timestamp, block.timestamp + Time);
    }

    function SetTaxAmount(uint256 amount, string memory taxToSet) public OnlyDAO returns (bool) {
        bytes32 _setHash = keccak256(abi.encodePacked(taxToSet));
        bytes32 _execusCut = keccak256(abi.encodePacked("execusCut"));
        bytes32 _burnCut = keccak256(abi.encodePacked("burnCut"));
        bytes32 _memberHolding = keccak256(abi.encodePacked("memberHolding"));

        if (_setHash == _execusCut || _setHash == _burnCut) {
            require(amount >= 1 && amount <= 10000, 
            "VotingSystemV1.SetTaxAmount: Percentages can't be higher than 100");
            ExecutorCut = amount;
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
    function _returnTokens(uint256 VotingInstance,address _voterAddr) internal {
        require(block.timestamp >= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.WithdrawMyTokens: The voting period isn't over");

        if (VotingInstances[VotingInstance].ActiveVoters > 0) {
            require(
                VoterInfo[VotingInstance][_voterAddr].VotesLocked > 0, 
                "VotingSystemV1.WithdrawMyTokens: You have no VotesLocked in this proposal"
            );
            ERC20(CLD).transfer(_voterAddr, (VoterInfo[VotingInstance][_voterAddr].VotesLocked + VotingInstances[VotingInstance].IncentivePerVote));
        }
        
        VoterInfo[VotingInstance][_voterAddr].VotesLocked -= VoterInfo[VotingInstance][_voterAddr].VotesLocked;
    }

    function _updateTaxesAndIndIncentive(uint256 VotingInstance) internal  {         
            uint256 newBurnAmount = VotingInstances[VotingInstance].TotalIncentive * BurnCut / 10000;
            VotingInstances[VotingInstance].CLDToBurn = newBurnAmount;

            uint newToExecutAmount = VotingInstances[VotingInstance].TotalIncentive * ExecutorCut / 10000;
            VotingInstances[VotingInstance].CLDToExecutioner = newToExecutAmount;
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