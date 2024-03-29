import "./CoreV1.sol";

//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by the Winslow Core, and can also continue to be used 
if a new Winslow Core is deployed by changing DAO addresses
When setting up a new core or voting contract, ensure cross-compatibility and record keeping 
done by the archive contract, voting index and proposal indexes never restart */
pragma solidity ^0.8.17;


contract Winslow_Voting_V1 {
    // Contracts and Routing Variables
    string public Version = "V1";
    address public DAO;
    uint256 public Quorum = 1500000000000000000000; //Default quorum to be changed in initial proposals

    // Percentages in Basis Points
    uint256 public ExecutorCut;
    uint256 public BurnCut;

    // Proposals being tracked by id here
    mapping(uint256 => VoteInstance) public VotingInstances;
    uint256 MRInstance; // Most recent [poll/voting] instance tracker for new initializations
    uint256 ActiveInstances;

    uint256 public CurrentOngoingVote;
    uint256[] public VotingQueue;
    mapping(uint256 => uint256) public VotingQueueIndex;
    
    mapping(uint256 => MultiVoteCard) public MultiVotes;
    // Map user addresses to their voting information
    mapping(uint256 => mapping(address => VoterDetails)) public VoterInfo;

    mapping(address => uint256[]) public UserUnreturnedVotes;
    mapping(address => mapping(uint256 => uint256)) public UserUnreturnedVotesIndex;

    //TODO: Somehow list all active proposals for voting for frontend

    struct VoteInstance {
        uint256 ProposalID;      //DAO Proposal for voting instance
        uint256 VoteStarts;      //Unix Time, also used to store the debate period end time
        uint256 VoteEnds;        //Unix Time
        VoteStatus Status;       //Using VoteStatus enum
        address[] Voters;        //List of users that have voted that also can be called for total number of voters
        uint256 TotalCLDVoted;   //Total of CLD used in this instance for voting
        bool MultiVote;          //Determines if this instance supports multivote
        uint8 MaxMulti;      //Max number of options for multivote
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

    //TODO: Review events for each function

    event VoteCast(address Voter, uint256 VotingInstance, string option, uint256 votesCasted);
    event ProposalIncentivized(address donator, uint256 VotingInstance, uint256 amountDonated);
    event TokensReturned(address Voter, uint256 TotalSent, uint256 IncentiveShare);
    event NewDAOAddress(address NewAddress);
    event FallbackToTreasury(uint256 amount);
 
    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    } 

    constructor(){
        ExecutorCut = 200;
        BurnCut = 200;
        DAO = msg.sender;
    }

    //Pre-Vote Functions (Incentivize is available pre and during vote)
    

    //Active Vote Functions

    function CastVote(uint256 amount, uint256 VotingInstance, Vote VoteChoice) external returns(bool success){
        require(VotingInstances[VotingInstance].MultiVote == false);
        require(ERC20(CLDAddress()).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.CastVote: You do not have enough CLD to vote this amount or have not given the proper allowance to voting");
        require(VoteChoice == Vote(0) || VoteChoice == Vote(1), "VotingSystemV1.CastVote: You must either vote YEA or NAY");
        require(amount >= 10000000000000000, "VotingSystemV1.CastVote: The minimum CLD per vote is 0.01"); //For incentive payout reasons
        require(!VoterInfo[VotingInstance][msg.sender].Voted, "VotingSystemV1.CastVote: You may only cast a single vote per address per proposal"); //This may be changed in V2
        require(block.timestamp >= VotingInstances[VotingInstance].VoteStarts && block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.CastVote: This instance is not currently in voting");

        if(VotingInstances[VotingInstance].Voters.length == 0){
            VotingInstances[VotingInstance].Status = VoteStatus(1);
        }

        if(VoteChoice == Vote(0)) {
            VotingInstances[VotingInstance].YEAvotes += amount;
            emit VoteCast(msg.sender, VotingInstance, "YEA", amount);
        } else {
            VotingInstances[VotingInstance].NAYvotes += amount;
            emit VoteCast(msg.sender, VotingInstance, "NEA", amount);
        }

        VoterInfo[VotingInstance][msg.sender].VotesLocked += amount;
        VoterInfo[VotingInstance][msg.sender].Voted = true;
        VotingInstances[VotingInstance].Voters.push(msg.sender);
        UserUnreturnedVotes[msg.sender].push(VotingInstance);
        UserUnreturnedVotesIndex[msg.sender][VotingInstance] = UserUnreturnedVotes[msg.sender].length - 1;
        
        return(success);
    }
    
        //This is set up so that you can vote for or against the proposal, and if yes what of the options you prefer
    function CastMultiVote(uint256 amount, uint256 VotingInstance, Vote VoteChoice, MultiOptions OptionChoice) external returns(bool success){ 
        require(VotingInstances[VotingInstance].MultiVote == true);
        require(ERC20(CLDAddress()).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.CastMultiVote: You do not have enough CLD to vote this amount or have not given the proper allowance to voting");
        require(VoteChoice == Vote(0) || VoteChoice == Vote(1), "VotingSystemV1.CastMultiVote: You must either vote YEA or NAY");
        require(amount >= 10000000000000000, "VotingSystemV1.CastMultiVote: The minimum CLD per vote is 0.01"); //For incentive payout reasons
        require(!VoterInfo[VotingInstance][msg.sender].Voted, "VotingSystemV1.CastMultiVote: You may only cast a single vote per address per proposal"); //This may be changed in V2
        require(block.timestamp >= VotingInstances[VotingInstance].VoteStarts && block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.CastMultiVote: This instance is not currently in voting");
        require(uint8(OptionChoice) <= VotingInstances[VotingInstance].MaxMulti, "VotingSystemV1.CastMultiVote: You have selected an option that is not available for this instance");
        require(CurrentOngoingVote == VotingInstance, "VotingSystemV1.CastMultiVote: This is not the current ongoing vote");

        if(VotingInstances[VotingInstance].Voters.length == 0){
            VotingInstances[VotingInstance].Status = VoteStatus(1);
        }

        if(VoteChoice == Vote(0)) {
            VotingInstances[VotingInstance].YEAvotes += amount;
            emit VoteCast(msg.sender, VotingInstance, "YEA", amount);
        } else {
            VotingInstances[VotingInstance].NAYvotes += amount;
            emit VoteCast(msg.sender, VotingInstance, "NEA", amount);
        }

        if (OptionChoice == MultiOptions(0)){ //Options number is -1 because of how enums work
            MultiVotes[VotingInstance].OptionOne += amount;
        }
        if (OptionChoice == MultiOptions(1)){
            MultiVotes[VotingInstance].OptionTwo += amount;
        }
        if (OptionChoice == MultiOptions(2)){
            MultiVotes[VotingInstance].OptionThree += amount;
        }
        if (OptionChoice == MultiOptions(3)){
            MultiVotes[VotingInstance].OptionFour += amount;
        }
        if (OptionChoice == MultiOptions(4)){
            MultiVotes[VotingInstance].OptionFive += amount;
        }

        VoterInfo[VotingInstance][msg.sender].VotesLocked += amount;
        VoterInfo[VotingInstance][msg.sender].Voted = true;
        VotingInstances[VotingInstance].Voters.push(msg.sender);
        UserUnreturnedVotes[msg.sender].push(VotingInstance);
        UserUnreturnedVotesIndex[msg.sender][VotingInstance] = UserUnreturnedVotes[msg.sender].length - 1;

        return(success);
    }

    function IncentivizeProposal(uint256 VotingInstance, uint256 amount) public returns(bool success){
        require(ERC20(CLDAddress()).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.IncentivizeProposal: You do not have enough CLD to incentivize this proposal or you may not have given this contract enough allowance");
        require(VotingInstances[VotingInstance].Status == VoteStatus(0), 'VotingSystemV1.IncentivizeProposal: This proposal has ended');
        require(block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.IncentivizeProposal: The voting period has ended, save for the next proposal!");

        VotingInstances[VotingInstance].TotalIncentive += amount;

        _updateTaxesAndIndIncentive(VotingInstance);
        emit ProposalIncentivized(msg.sender, VotingInstance, VotingInstances[VotingInstance].TotalIncentive);
        
        return(success);
    }

    //Post-Vote Functions

    function ReturnTokens(uint256 VotingInstance) public { //For returning your tokens for a specific instance after voting, with the incentive payout
        require(VoterInfo[VotingInstance][msg.sender].Voted == true);
        require(VoterInfo[VotingInstance][msg.sender].CLDReturned == false);
        require(block.timestamp >= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.ReturnTokens: Voting has not ended for this instance");

        uint256 index = UserUnreturnedVotesIndex[msg.sender][VotingInstance];

        UserUnreturnedVotes[msg.sender][index] = UserUnreturnedVotes[msg.sender][UserUnreturnedVotes[msg.sender].length - 1];
        UserUnreturnedVotesIndex[msg.sender][UserUnreturnedVotes[msg.sender][index]] = index;
        UserUnreturnedVotes[msg.sender].pop();

        VoterInfo[VotingInstance][msg.sender].CLDReturned = true;

        uint256 TotalToReturn;
        TotalToReturn += VoterInfo[VotingInstance][msg.sender].VotesLocked;
        TotalToReturn += (((VoterInfo[VotingInstance][msg.sender].VotesLocked * 100) * VotingInstances[VotingInstance].IncentivePerVote) / 10**9);

        ERC20(CLDAddress()).transfer(msg.sender, TotalToReturn);

        emit TokensReturned(msg.sender, TotalToReturn, (TotalToReturn - VoterInfo[VotingInstance][msg.sender].VotesLocked));
    } 

    function ReturnAllVotedTokens() public {
        for(uint256 i = 0; i < UserUnreturnedVotes[msg.sender].length; i++){
            uint256 VotingInstance = UserUnreturnedVotes[msg.sender][i];
            if(VotingInstances[VotingInstance].Status == VoteStatus(2) && VoterInfo[VotingInstance][msg.sender].CLDReturned == false){
                ReturnTokens(VotingInstance);
            }
        }
    }

    //Public View Functions

    function CLDAddress() public view returns(address CLD){
        return(Core(DAO).CLDAddress());
    }

    function GetVotingInstance(uint256 _VoteInstance) public view returns(uint256 ProposalID, uint256 VoteStarts, uint256 VoteEnds, VoteStatus Status, address[] memory Voters, uint256 TotalCLDVoted, bool MultiVote, uint8 MaxMulti, uint256 YEAvotes, uint256 NAYvotes, uint256 TotalIncentive, uint256 IncentivePerVote, uint256 CLDtoIncentive, uint256 CLDToBurn, uint256 CLDToExecutioner){
        return(VotingInstances[_VoteInstance].ProposalID, VotingInstances[_VoteInstance].VoteStarts, VotingInstances[_VoteInstance].VoteEnds, VotingInstances[_VoteInstance].Status, VotingInstances[_VoteInstance].Voters, VotingInstances[_VoteInstance].TotalCLDVoted, VotingInstances[_VoteInstance].MultiVote, VotingInstances[_VoteInstance].MaxMulti, VotingInstances[_VoteInstance].YEAvotes, VotingInstances[_VoteInstance].NAYvotes, VotingInstances[_VoteInstance].TotalIncentive, VotingInstances[_VoteInstance].IncentivePerVote, VotingInstances[_VoteInstance].CLDtoIncentive, VotingInstances[_VoteInstance].CLDToBurn, VotingInstances[_VoteInstance].CLDToExecutioner);
    }

    function GetVotingResult(uint256 _VoteInstance) public view returns(bool Result, uint8 Multi){
        require(block.timestamp >= VotingInstances[_VoteInstance].VoteEnds, "VotingSystemV1.GetVotingResult: The current vote is not over");

        //if the total votes does not meet the quorum, the vote fails and returns false
        if(VotingInstances[_VoteInstance].TotalCLDVoted < Quorum){
            return(false, 0);
        } 

        if(VotingInstances[_VoteInstance].YEAvotes > VotingInstances[_VoteInstance].NAYvotes){
            Result = true;
        } else {
            Result = false;
        }

        if(VotingInstances[_VoteInstance].MultiVote == true){
            uint256 HighestVote;
            if(MultiVotes[_VoteInstance].OptionOne > HighestVote){
                HighestVote = MultiVotes[_VoteInstance].OptionOne;
                Multi = 1;
            }
            if(MultiVotes[_VoteInstance].OptionTwo > HighestVote){
                HighestVote = MultiVotes[_VoteInstance].OptionTwo;
                Multi = 2;
            }
            if(MultiVotes[_VoteInstance].OptionThree > HighestVote){
                HighestVote = MultiVotes[_VoteInstance].OptionThree;
                Multi = 3;
            }
            if(MultiVotes[_VoteInstance].OptionFour > HighestVote){
                HighestVote = MultiVotes[_VoteInstance].OptionFour;
                Multi = 4;
            }
            if(MultiVotes[_VoteInstance].OptionFive > HighestVote){
                HighestVote = MultiVotes[_VoteInstance].OptionFive;
                Multi = 5;
            }
        }


        return(Result, Multi);
    }

    //OnlyDAO functions

    function InitializeVoteInstance(uint256 ProposalID, bool Multi, uint8 MaxMulti) external OnlyDAO returns(uint256 VoteInstanceID){

        uint256 NewInstanceID = MRInstance++;
        ActiveInstances++;
        uint256 EarliestStartTime = block.timestamp + 86400;
        address[] memory Empty;
        uint256 InititalRewardPool = (Core(DAO).ProposalCost() / 2);

        VotingInstances[NewInstanceID] = VoteInstance(ProposalID,EarliestStartTime,0,VoteStatus(0),Empty,0,Multi,MaxMulti,0,0,InititalRewardPool,0,0,0,0);
        VotingQueue.push(NewInstanceID);
        VotingQueueIndex[NewInstanceID] = VotingQueue.length - 1;

        _updateTaxesAndIndIncentive(NewInstanceID);
        // emit ProposalCreated(Proposer, ProposalID, block.timestamp, block.timestamp + Time);
        return(NewInstanceID);
    }

    //Status Changes
    function EndVoting(uint256 VotingInstance) internal {

        ERC20(CLDAddress()).Burn(VotingInstances[VotingInstance].CLDToBurn);
        
        ERC20(CLDAddress()).transfer(msg.sender, VotingInstances[VotingInstance].CLDToExecutioner);

        VotingInstances[VotingInstance].IncentivePerVote = ((VotingInstances[VotingInstance].CLDtoIncentive * 10**9) / VotingInstances[VotingInstance].TotalCLDVoted); //TODO: THis is probably wrong

        VotingInstances[VotingInstance].Status = VoteStatus(2);
        ActiveInstances--;
        //Post results
    }

    //start next voting instance
    function BeginNextVote() public returns(uint256 VotingInstance){
        require(VotingQueue.length > 0, "VotingSystemV1.BeginNextVote: There are no proposals in the queue");
        //check if the current vote is over, or if there is no current vote as it is the first
        if(CurrentOngoingVote != 0){
            require(block.timestamp >= VotingInstances[CurrentOngoingVote].VoteEnds, "VotingSystemV1.BeginNextVote: The current vote is not over");
            if(VotingInstances[CurrentOngoingVote].Status == VoteStatus(1)){
                EndVoting(CurrentOngoingVote);
            }
        }

        //loop through the queue to find the proposal with the highest incentive, begin it and remove it from the queue
        uint256 HighestIncentive = 0;
        uint256 HighestIncentiveProposal;
        for(uint256 i = 0; i < VotingQueue.length; i++){ //we check vote starts here because we want to ensure that the debate period is over
            if(VotingInstances[VotingQueue[i]].TotalIncentive > HighestIncentive && VotingInstances[VotingQueue[i]].VoteStarts > block.timestamp){
                HighestIncentive = VotingInstances[VotingQueue[i]].TotalIncentive;
                HighestIncentiveProposal = VotingQueue[i];
            }
        }

        CurrentOngoingVote = HighestIncentiveProposal;

        if(VotingQueue.length > 1){
            VotingQueue[VotingQueueIndex[CurrentOngoingVote]] = VotingQueue[VotingQueue.length - 1];
            VotingQueueIndex[VotingQueue[VotingQueue.length - 1]] = VotingQueueIndex[CurrentOngoingVote];
        }
        VotingQueue.pop();
        VotingQueueIndex[CurrentOngoingVote] = 0;

        VotingInstances[CurrentOngoingVote].VoteStarts = block.timestamp;
        VotingInstances[CurrentOngoingVote].VoteEnds = block.timestamp + Core(DAO).VoteLength();
        VotingInstances[CurrentOngoingVote].Status = VoteStatus(1);

        return(CurrentOngoingVote);
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
    
    //Internal functions

    function _updateTaxesAndIndIncentive(uint256 VotingInstance) internal  {    
            VotingInstances[VotingInstance].CLDToBurn = ((VotingInstances[VotingInstance].TotalIncentive * BurnCut) / 10000);

            VotingInstances[VotingInstance].CLDToExecutioner = ((VotingInstances[VotingInstance].TotalIncentive * ExecutorCut) / 10000);

            VotingInstances[VotingInstance].CLDtoIncentive = VotingInstances[VotingInstance].TotalIncentive - (VotingInstances[VotingInstance].CLDToBurn + VotingInstances[VotingInstance].CLDToExecutioner);
    }

}


//Interfaces

interface Core {
    function TreasuryContract() external returns(address payable TreasuryAddress);
    function CLDAddress() external view returns(address CLD);
    function ProposalCost() external view returns(uint256 Cost);
    function VoteLength() external view returns(uint256 Length);
}
