//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by itself, and can also continue to be used 
if a new external Winslow_Core_V1 modules and contracts are deployed by changing their addresses and
providing previous contract information to the new contracts.
When setting up a new Winslow_Core_V1 or Winslow_Voting_V1 contract, ensure cross-compatibility and record keeping 
done by the archive contract, Winslow_Voting_V1 index and proposal indexes never restart */
pragma solidity ^0.8.19;

contract Winslow_Core_V1 {
    //Variable Declarations       
    string public Version = "V1";
    bool public IsActiveContract;
    address payable public TreasuryContract;
    address public VotingContract; 
    address public SaleFactoryContract;
    uint256 public ProposalCost = 10000000000000000000; //Initial cost, can be changed via proposals
    uint256 public SaleCount;
    uint256 public VoteLength = 172800; //Default two days for an efficient DAO, but can be changed by proposals in case quorums are not being met

    //Mapping, structs and other declarations
    
    //Proposals
    mapping(uint256 => Proposal) public Proposals;
    mapping(uint256 => ProposalInfo) public ProposalInfos;
    uint256 public MRIdentifier;

    //Token Sales
    mapping(uint256 => Sale) public Sales;
    function SaleActive() public view returns(bool){
        if(block.timestamp <= Sales[LatestSale].EndTime){return true;}else{return false;}
    }
    uint256 public LatestSale;

    enum ProposalStatus{
        Pre_Voting,
        Winslow_Voting_V1,
        Executed,
        Rejected
    }

    enum ProposalTypes{
        Simple,
        Eros
    }

    enum SimpleProposalTypes{
        NotApplicable,
        AssetSend,
        AssetRegister,
        ChangeRegisteredAssetLimit,
        TreasuryReplacement,
        VotingReplacement,
        SaleFactoryReplacement,
        CoreReplacement,
        StartPublicSale,
        ChangeProposalCost,
        ChangeSaleRetractFee,
        ChangeSaleMinimumDeposit,
        ChangeSaleDefaultSaleLength,
        ChangeSaleMaxSalePercent,
        ChangeDefaultQuorum,
        ChangeVotingLength,
        ChangeVotingCuts
    }

    enum MultiOptions{
        OptionOne,
        OptionTwo,
        OptionThree,
        OptionFour,
        OptionFive
    }

    struct ProposalInfo{
        string Memo;                   //Memo for the proposal, can be changed by the DAO
        ProposalTypes ProposalType;     //Types declared in enum
        SimpleProposalTypes SimpleType; //Types declared in enum
        ProposalStatus Status;
        uint256 VotingInstanceID;       //Identifier for the Winslow_Voting_V1 instance used for this proposal in the Winslow_Voting_V1 contract
    }

    struct Proposal{
        address AddressSlot;            //To set an address either as a receiver, ProxyReceiver for approval of Eros proposal contract
        uint256 RequestedEtherAmount;   //Optional, can be zero
        uint256 RequestedAssetAmount;   //Optional, can be zero
        uint8 RequestedAssetID;         //Winslow_Treasury_V1 asset identifier for proposals moving funds
        uint8 OptionsAvailable;         //Number of Options Available if there is more than one, default zero
        bool Multi;                     //False for just a regular one option proposal, True for any proposal with more than one option
        bool Executed;                  //Can only be executed once, when finished, proposal exist only as archive
        address Proposer;               //Address who initially created the proposal
    }

    struct Sale{
        address Winslow_Sale_V2;
        uint256 CLDSaleAmount;
        uint256 StartTime;
        uint256 EndTime;
    }

    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);
    event SucceededExecution(uint256 ProposalID);
    event FailedExecution(uint256 ProposalID);


    constructor(address SaleFactory){
        TreasuryContract = payable(address(new Winslow_Treasury_V1()));
        VotingContract = address(new Winslow_Voting_V1());
        SaleFactoryContract = SaleFactory;
        Winslow_SaleFactory_V2(SaleFactory).SetDAO(address(this));

        IsActiveContract = true;
    }

    //Public state-modifing functions

    function SubmitSimpleProposal(string memory Memo, address AddressSlot, SimpleProposalTypes SimpleType, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success){

        ReceiveProposalCost();

        InitializeSimpleProposal(Memo, AddressSlot, SimpleType, RequestedEther, RequestedAssetAmount, RequestedAssetID);

        return(success);
    }

    function SubmitErosProposal(address ProposalAddress) public returns(bool success){

        ReceiveProposalCost();

        InitializeErosProposal(ProposalAddress);
        
        return(success);
    }

    //  Public view functions

    function CLDAddress() public view returns(address CLD){
        return(Winslow_Treasury_V1(TreasuryContract).CLDAddress());
    }


    //  Internal Functions

    function InitializeSimpleProposal(string memory Memo, address AddressSlot, SimpleProposalTypes SimpleType, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 Identifier){
        //require that there are no more than 100 proposals in the voting queue on the voting contract, if there are, the DAO must execute some before more can be added, this is to prevent gas issues for beginnextvote
        require(Winslow_Voting_V1(VotingContract).GetVotingQueueSize() < 100, "There are too many proposals in the queue, the DAO must execute some before more can be added");

        MRIdentifier++;
        uint256 NewIdentifier = MRIdentifier;

        //All simple proposals must have a slotted address for sending or action, but may be 0 in certain cases such as burn events or new sales
        uint256 VotingInstanceID = Winslow_Voting_V1(VotingContract).InitializeVoteInstance(NewIdentifier, 0);
        if(SimpleType == SimpleProposalTypes(2)){
            require(RequestedAssetID > 0 && RequestedAssetID <= 255 && RequestedAssetID <= Winslow_Treasury_V1(TreasuryContract).RegisteredAssetLimit());
            //Unused variables should remain as 0 for proposals of this type and others which do not require them. Regardless, even if they are set, they are not used in the execution of the proposal
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(0), SimpleType, ProposalStatus(0), VotingInstanceID);
            Proposals[NewIdentifier] = Proposal(AddressSlot, RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
        } 
        else{
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(0), SimpleType, ProposalStatus(0), VotingInstanceID);
            Proposals[NewIdentifier] = Proposal(AddressSlot, RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
        }

        return(NewIdentifier);
    }


    function InitializeErosProposal(address ProposalAddress) internal returns(uint256 identifier){
        require(ProposalAddress != address(0), "ErosProposals must have a slotted contract");
        require(Winslow_Voting_V1(VotingContract).GetVotingQueueSize() < 100, "There are too many proposals in the queue, the DAO must execute some before more can be added");

        MRIdentifier++;
        uint256 NewIdentifier = MRIdentifier;

        string memory Memo = EROS(ProposalAddress).ProposalMemo();
        uint256 RequestedEther = EROS(ProposalAddress).RequestEther();
        uint256 RequestedAssetAmount = EROS(ProposalAddress).RequestTokens();
        uint8 RequestedAssetID = EROS(ProposalAddress).TokenIdentifier();

        if(RequestedAssetAmount > 0){
            require(RequestedAssetID > 0 && RequestedAssetID <= 255 && RequestedAssetID <= Winslow_Treasury_V1(TreasuryContract).RegisteredAssetLimit(), "Requested asset ID must be atleast 1 and be registered in the Winslow_Treasury_V1");
        }

        if(EROS(ProposalAddress).Multi() == true){
            require(EROS(ProposalAddress).OptionCount() > 1, 'Eros proposal marked as multiple options true, but less than two options are available');
            uint256 VotingInstanceID = Winslow_Voting_V1(VotingContract).InitializeVoteInstance(NewIdentifier, EROS(ProposalAddress).OptionCount());

            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(1), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID);
            Proposals[NewIdentifier] = Proposal(ProposalAddress, RequestedEther, RequestedAssetAmount, RequestedAssetID, EROS(ProposalAddress).OptionCount(), true, false, msg.sender);
        }
        else{
            uint256 VotingInstanceID = Winslow_Voting_V1(VotingContract).InitializeVoteInstance(NewIdentifier, 0);

            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(1), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID);
            Proposals[NewIdentifier] = Proposal(ProposalAddress, RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
        }

        return(NewIdentifier);
    }

    //  Execution Functions

    function HandleEndedProposal(uint256 ProposalID) external returns(bool success){
        require(msg.sender == VotingContract, "Only the Winslow_Voting_V1 contract can execute proposals");
        require(ProposalInfos[ProposalID].Status == ProposalStatus(1), "Proposal status must be voting to be executed");
        (bool Result, uint8 Multi) = Winslow_Voting_V1(VotingContract).GetVoteResult(ProposalInfos[ProposalID].VotingInstanceID);
        require(Proposals[ProposalID].Executed == false, "Proposal has already been executed");
    
        Proposals[ProposalID].Executed = Result;

        if(Result == true){
            ProposalInfos[ProposalID].Status = ProposalStatus(2);
            if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(0)){
                ExecuteSimpleProposal(ProposalID);
            }
            else if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(1)){
                ExecuteErosProposal(ProposalID, Multi);
            }

            emit SucceededExecution(ProposalID);
        }
        else{
            ProposalInfos[ProposalID].Status = ProposalStatus(3);
        }
    
        return(success);
    }

    function ExecutionFailed(uint256 ProposalID) external returns(bool success){
        require(msg.sender == VotingContract, "Only the Winslow_Voting_V1 contract can set proposal status to failed");
        require(ProposalInfos[ProposalID].Status == ProposalStatus(1), "Proposal status must be voting to be set to failed");
        ProposalInfos[ProposalID].Status = ProposalStatus(3);

        emit FailedExecution(ProposalID);
        return(success);
    }

    //  Simple Executionting

    function ExecuteSimpleProposal(uint256 ProposalID) internal {
        
        if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(0)){
            //Do nothing, this is a placeholder for the first proposal and other proposals that do not require execution
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(1)){
            if(Proposals[ProposalID].RequestedEtherAmount > 0){
                Winslow_Treasury_V1(TreasuryContract).TransferETH(Proposals[ProposalID].RequestedEtherAmount, payable(Proposals[ProposalID].AddressSlot));
            }
            if(Proposals[ProposalID].RequestedAssetAmount > 0){
                Winslow_Treasury_V1(TreasuryContract).TransferERC20(Proposals[ProposalID].RequestedAssetID, Proposals[ProposalID].RequestedAssetAmount, Proposals[ProposalID].AddressSlot);
            }
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(2)){
            address TokenAddress = Proposals[ProposalID].AddressSlot;
            uint8 Slot = uint8(Proposals[ProposalID].RequestedEtherAmount);
            Winslow_Treasury_V1(TreasuryContract).RegisterAsset(TokenAddress, Slot);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(3)){
            uint8 NewLimit = uint8(Proposals[ProposalID].RequestedEtherAmount); 
            Winslow_Treasury_V1(TreasuryContract).ChangeRegisteredAssetLimit(NewLimit);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(4)){
            address NewTreasury = Proposals[ProposalID].AddressSlot;
            Replacements(NewTreasury).SendPredecessor(TreasuryContract);
            TreasuryContract = payable(NewTreasury);
            emit NewTreasurySet(NewTreasury);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(5)){
            address NewVoting = Proposals[ProposalID].AddressSlot;
            Replacements(NewVoting).SendPredecessor(VotingContract);
            VotingContract = NewVoting;
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(6)){
            address NewSaleModule = Proposals[ProposalID].AddressSlot;
            SaleFactoryContract = NewSaleModule;
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(7)){
            address NewCore = Proposals[ProposalID].AddressSlot;
            IsActiveContract = false;
            Replacements(NewCore).InheritCore(TreasuryContract, VotingContract, MRIdentifier, ProposalCost);
            Replacements(TreasuryContract).ChangeDAO(NewCore);
            Replacements(VotingContract).ChangeDAO(NewCore);
            Replacements(SaleFactoryContract).ChangeDAO(NewCore);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(8)){
            require(!SaleActive());
            uint256 CLDtoSell = Proposals[ProposalID].RequestedAssetAmount;
            LatestSale++;

            address NewSaleAddress = Winslow_SaleFactory_V2(SaleFactoryContract).CreateNewSale(LatestSale, CLDtoSell);
            Sales[LatestSale] = Sale(NewSaleAddress,CLDtoSell, Winslow_Sale_V2(NewSaleAddress).StartTime(), Winslow_Sale_V2(NewSaleAddress).EndTime());

            Winslow_Treasury_V1(TreasuryContract).TransferERC20(0, CLDtoSell, NewSaleAddress);

            require(Winslow_Sale_V2(NewSaleAddress).VerifyReadyForSale(), "The sale contract has not be able to confirm a receipt of CLD to sell");
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(9)){
            ProposalCost = Proposals[ProposalID].RequestedEtherAmount;
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(10)){
            Winslow_SaleFactory_V2(SaleFactoryContract).ChangeRetractFee(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(11)){
            Winslow_SaleFactory_V2(SaleFactoryContract).ChangeMinimumDeposit(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(12)){
            Winslow_SaleFactory_V2(SaleFactoryContract).ChangeDefaultSaleLength(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(13)){
            //Value is stored in RequestedEtherAmount in basis points
            Winslow_SaleFactory_V2(SaleFactoryContract).ChangeMaxSalePercent(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(14)){
            //Value is stored in RequestedEtherAmount in basis points
            Winslow_Voting_V1(VotingContract).ChangeQuorum(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(15)){
            //Value is stored in RequestedEtherAmount in seconds
            VoteLength = Proposals[ProposalID].RequestedEtherAmount;
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(16)){
            //Value is stored in RequestedEtherAmount and RequestedAssetAmount in basis points
            Winslow_Voting_V1(VotingContract).SetTaxAmount(Proposals[ProposalID].RequestedEtherAmount, Proposals[ProposalID].RequestedAssetAmount);
        }
    }

    //  Eros Executionting

    function ExecuteErosProposal(uint256 ProposalID, uint8 Multi) internal {
        if(Proposals[ProposalID].RequestedEtherAmount > 0){
            Winslow_Treasury_V1(TreasuryContract).TransferETH(Proposals[ProposalID].RequestedEtherAmount, payable(Proposals[ProposalID].AddressSlot));
        }
        if(Proposals[ProposalID].RequestedAssetAmount > 0){
            Winslow_Treasury_V1(TreasuryContract).TransferERC20(Proposals[ProposalID].RequestedAssetID, Proposals[ProposalID].RequestedAssetAmount, Proposals[ProposalID].AddressSlot);
        }

        if(Proposals[ProposalID].Multi == true){
            EROS(Proposals[ProposalID].AddressSlot).ExecuteMulti(Multi);
        }
        else{
            EROS(Proposals[ProposalID].AddressSlot).Execute();
        }
    }

    function SetProposalVoting(uint256 ProposalID) external returns(bool success){
        require(msg.sender == VotingContract, "Only the Winslow_Voting_V1 contract can set proposal status to voting");
        require(ProposalInfos[ProposalID].Status == ProposalStatus(0), "Proposal status must be pre-voting to be set to voting");
        ProposalInfos[ProposalID].Status = ProposalStatus(1);
        return(success);
    }

    // Other Internals
    function ReceiveProposalCost() internal returns(bool success){

        ERC20(CLDAddress()).transferFrom(msg.sender, VotingContract, (ProposalCost / 2));

        ERC20(CLDAddress()).transferFrom(msg.sender, TreasuryContract, (ProposalCost / 2));

        return(success);
    }
    
    //Receive and fallbacks
    receive() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(TreasuryContract).transfer(address(this).balance);
    }

    fallback() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(TreasuryContract).transfer(address(this).balance);
    }
}

contract Winslow_Voting_V1 {
    // Contracts and Routing Variables
    string public Version = "V1";
    address payable public DAO;
    uint256 public Quorum = 1500000000000000000000; //Default quorum to be changed in initial proposals
    bool public OngoingVote;

    // Percentages in Basis Points
    uint256 public ExecutorCut;
    uint256 public BurnCut;

    // Proposals being tracked by id here
    mapping(uint256 => VoteInstance) public VotingInstances;
    uint256 public ActiveInstances;

    uint256 public CurrentOngoingVote;
    uint256[] public VotingQueue;
    mapping(uint256 => uint256) public VotingQueueIndex;
    
    mapping(uint256 => MultiVoteCard) public MultiVotes;
    // Map user addresses to their Winslow_Voting_V1 information
    mapping(uint256 => mapping(address => VoterDetails)) public VoterInfo;

    mapping(address => uint256[]) public UserUnreturnedVotes;
    mapping(address => mapping(uint256 => uint256)) public UserUnreturnedVotesIndex;


    struct VoteInstance {
        uint256 ProposalID;      //DAO Proposal for Winslow_Voting_V1 instance
        uint256 VoteStarts;      //Unix Time, also used to store the debate period end time
        uint256 VoteEnds;        //Unix Time
        VoteStatus Status;       //Using VoteStatus enum
        address[] Voters;        //List of users that have voted that also can be called for total number of voters
        uint256 TotalCLDVoted;   //Total of CLD used in this instance for Winslow_Voting_V1
        uint8 MaxMulti;          //Max number of options for multivote
        uint256 YEAvotes;        //Votes to approve
        uint256 NAYvotes;        //Votes to refuse
        uint256 TotalIncentive;  //Total amount of CLD donated to this proposal for Winslow_Voting_V1 incentives, burning and execution reward
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

    event InstanceCreated(address Proposer, uint256 ProposalID, uint256 Timestamp);
    event VoteCast(address Voter, uint256 VotingInstance, string option, uint256 votesCasted);
    event ProposalIncentivized(address donator, uint256 VotingInstance, uint256 amountDonated);
    event TokensReturned(address Voter, uint256 TotalSent, uint256 IncentiveShare);
    event NewDAOAddress(address NewAddress);
    event VotingStarted(uint256 VotingInstance, uint256 StartTime);
    event VotingEnded(uint256 VotingInstance, bool Result, uint8 Multi);
 
    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    } 

    constructor(){
        ExecutorCut = 200;
        BurnCut = 200;
        DAO = payable(msg.sender);
    }

    //Active Vote Functions

    function CastVote(uint256 amount, Vote VoteChoice) external returns(bool success){
        uint256 VotingInstance = CurrentOngoingVote;
        require(VotingInstances[VotingInstance].MaxMulti == 0);
        require(ERC20(CLDAddress()).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.CastVote: You do not have enough CLD to vote this amount or have not given the proper allowance to Winslow_Voting_V1");
        require(VoteChoice == Vote(0) || VoteChoice == Vote(1), "VotingSystemV1.CastVote: You must either vote YEA or NAY");
        require(amount >= 10000000000000000, "VotingSystemV1.CastVote: The minimum CLD per vote is 0.01"); //For incentive payout reasons
        require(!VoterInfo[VotingInstance][msg.sender].Voted, "VotingSystemV1.CastVote: You may only cast a single vote per address per proposal"); //This may be changed in V2
        require(block.timestamp >= VotingInstances[VotingInstance].VoteStarts && block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.CastVote: This instance is not currently in Winslow_Voting_V1");

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
        VotingInstances[VotingInstance].TotalCLDVoted += amount;
        
        return(success);
    }
    
        //This is set up so that you can vote for or against the proposal, and if yes what of the options you prefer
    function CastMultiVote(uint256 amount, Vote VoteChoice, MultiOptions OptionChoice) external returns(bool success){ 
        uint256 VotingInstance = CurrentOngoingVote;
        require(VotingInstances[VotingInstance].MaxMulti > 0);
        require(ERC20(CLDAddress()).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.CastMultiVote: You do not have enough CLD to vote this amount or have not given the proper allowance to Winslow_Voting_V1");
        require(VoteChoice == Vote(0) || VoteChoice == Vote(1), "VotingSystemV1.CastMultiVote: You must either vote YEA or NAY");
        require(amount >= 10000000000000000, "VotingSystemV1.CastMultiVote: The minimum CLD per vote is 0.01"); //For incentive payout reasons
        require(!VoterInfo[VotingInstance][msg.sender].Voted, "VotingSystemV1.CastMultiVote: You may only cast a single vote per address per proposal"); //This may be changed in V2
        require(block.timestamp >= VotingInstances[VotingInstance].VoteStarts && block.timestamp <= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.CastMultiVote: This instance is not currently in Winslow_Voting_V1");
        require(uint8(OptionChoice) <= VotingInstances[VotingInstance].MaxMulti, "VotingSystemV1.CastMultiVote: You have selected an option that is not available for this instance");

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
        VotingInstances[VotingInstance].TotalCLDVoted += amount;

        return(success);
    }

    function IncentivizeProposal(uint256 VotingInstance, uint256 amount) public returns(bool success){
        require(VotingInstances[VotingInstance].VoteStarts != 0, "VotingSystemV1.IncentivizeProposal: This proposal does not exist");
        require(ERC20(CLDAddress()).transferFrom(msg.sender, address(this), amount), "VotingSystemV1.IncentivizeProposal: You do not have enough CLD to incentivize this proposal or you may not have given this contract enough allowance");
        require(VotingInstances[VotingInstance].Status == VoteStatus(0) || VotingInstances[VotingInstance].Status == VoteStatus(1), 'VotingSystemV1.IncentivizeProposal: This proposal has ended');

        VotingInstances[VotingInstance].TotalIncentive += amount;

        _updateTaxesAndIndIncentive(VotingInstance);
        emit ProposalIncentivized(msg.sender, VotingInstance, VotingInstances[VotingInstance].TotalIncentive);

        return(success);
    }

    //Post-Vote Functions

    function ReturnTokens(uint256 VotingInstance) public { //For returning your tokens for a specific instance after Winslow_Voting_V1, with the incentive payout
        require(VoterInfo[VotingInstance][msg.sender].Voted == true);
        require(VoterInfo[VotingInstance][msg.sender].CLDReturned == false);
        require(block.timestamp >= VotingInstances[VotingInstance].VoteEnds, "VotingSystemV1.ReturnTokens: Winslow_Voting_V1 has not ended for this instance");

        uint256 index = UserUnreturnedVotesIndex[msg.sender][VotingInstance];

        UserUnreturnedVotes[msg.sender][index] = UserUnreturnedVotes[msg.sender][UserUnreturnedVotes[msg.sender].length - 1];
        UserUnreturnedVotesIndex[msg.sender][UserUnreturnedVotes[msg.sender][index]] = index;
        UserUnreturnedVotes[msg.sender].pop();

        VoterInfo[VotingInstance][msg.sender].CLDReturned = true;

        uint256 TotalToReturn;
        TotalToReturn += VoterInfo[VotingInstance][msg.sender].VotesLocked;
        TotalToReturn += (((VoterInfo[VotingInstance][msg.sender].VotesLocked) * VotingInstances[VotingInstance].IncentivePerVote) / 10**9);

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
        return(Winslow_Core_V1(DAO).CLDAddress());
    }

    function GetVotingInstance(uint256 _VoteInstance) public view returns(VoteInstance memory Instance){
        return(VotingInstances[_VoteInstance]);
    }

    function GetVotingQueue() public view returns(uint256[] memory){
        return(VotingQueue);
    }

    function GetVotingQueueSize() public view returns(uint256){
        return(VotingQueue.length);
    }

    function GetVoteResult(uint256 _VoteInstance) public view returns(bool Result, uint8 Multi){
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

        if(VotingInstances[_VoteInstance].MaxMulti > 0){
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

    function InitializeVoteInstance(uint256 ProposalID, uint8 MaxMulti) external OnlyDAO returns(uint256 VoteInstanceID){
        ActiveInstances++;

        uint256 NewInstanceID = ProposalID;
        uint256 EarliestStartTime = block.timestamp + 21600;
        address[] memory Empty;
        uint256 InititalRewardPool = (Winslow_Core_V1(DAO).ProposalCost() / 2);

        VotingInstances[NewInstanceID] = VoteInstance(ProposalID,EarliestStartTime,0,VoteStatus(0),Empty,0,MaxMulti,0,0,InititalRewardPool,0,0,0,0);
        VotingQueue.push(NewInstanceID);
        VotingQueueIndex[NewInstanceID] = VotingQueue.length - 1;

        _updateTaxesAndIndIncentive(NewInstanceID);
        emit InstanceCreated(tx.origin, ProposalID, block.timestamp);
        return(NewInstanceID);
    }

    //Status Changes
    function EndVoting(uint256 VotingInstance) internal {

        ERC20(CLDAddress()).Burn(VotingInstances[VotingInstance].CLDToBurn);
        
        ERC20(CLDAddress()).transfer(msg.sender, VotingInstances[VotingInstance].CLDToExecutioner);

        if (VotingInstances[VotingInstance].TotalCLDVoted > 0) {
            VotingInstances[VotingInstance].IncentivePerVote = ((VotingInstances[VotingInstance].CLDtoIncentive * 10**9) / VotingInstances[VotingInstance].TotalCLDVoted);
        }

        VotingInstances[VotingInstance].Status = VoteStatus(2);
        ActiveInstances--;

        //get vote result for emitting event
        (bool Result, uint8 Multi) = GetVoteResult(VotingInstance);

        emit VotingEnded(VotingInstance, Result, Multi);
    }

    //start next Winslow_Voting_V1 instance
    function BeginNextVote() public returns(uint256 VotingInstance){
        require(VotingQueue.length > 0, "VotingSystemV1.BeginNextVote: There are no proposals in the queue");
        //check if the current vote is over, or if there is no current vote as it is the first
        if(OngoingVote){
            require(block.timestamp >= VotingInstances[CurrentOngoingVote].VoteEnds, "VotingSystemV1.BeginNextVote: The current vote is not over");
            EndVoting(CurrentOngoingVote);
            try Winslow_Core_V1(DAO).HandleEndedProposal(VotingInstances[CurrentOngoingVote].ProposalID){
            } catch {
                Winslow_Core_V1(DAO).ExecutionFailed(VotingInstances[CurrentOngoingVote].ProposalID);
            }
        }

        //loop through the queue to find the proposal with the highest incentive, begin it and remove it from the queue
        uint256 HighestIncentive = 0;
        uint256 HighestIncentiveProposal;
        for(uint256 i = 0; i < VotingQueue.length; i++){ //we check vote starts here because we want to ensure that the debate period is over
            if(VotingInstances[VotingQueue[i]].TotalIncentive >= HighestIncentive && VotingInstances[VotingQueue[i]].VoteStarts <= block.timestamp){
                HighestIncentive = VotingInstances[VotingQueue[i]].TotalIncentive;
                HighestIncentiveProposal = VotingQueue[i];
            }
        }
        require(HighestIncentiveProposal != 0, "No proposals available!");

        CurrentOngoingVote = HighestIncentiveProposal;

        if(VotingQueue.length > 1){
            VotingQueue[VotingQueueIndex[CurrentOngoingVote]] = VotingQueue[VotingQueue.length - 1];
            VotingQueueIndex[VotingQueue[VotingQueue.length - 1]] = VotingQueueIndex[CurrentOngoingVote];
        }
        VotingQueue.pop();
        VotingQueueIndex[CurrentOngoingVote] = 0;

        Winslow_Core_V1(DAO).SetProposalVoting(VotingInstances[CurrentOngoingVote].ProposalID);
        VotingInstances[CurrentOngoingVote].VoteStarts = (block.timestamp + 43200);
        VotingInstances[CurrentOngoingVote].VoteEnds = block.timestamp + Winslow_Core_V1(DAO).VoteLength();
        VotingInstances[CurrentOngoingVote].Status = VoteStatus(1);
        OngoingVote = true;

        emit VotingStarted(CurrentOngoingVote, VotingInstances[CurrentOngoingVote].VoteStarts);
        return(CurrentOngoingVote);
    }

    function SetTaxAmount(uint256 NewExecCut, uint256 NewBurnCut) external OnlyDAO returns (bool success) {
        require(NewExecCut > 0 && NewExecCut <= 10000);
        require(NewBurnCut > 0 && NewBurnCut <= 10000);

        ExecutorCut = NewExecCut;
        BurnCut = NewBurnCut;

        return true;
    }

    function ChangeQuorum(uint256 newQuorum) external OnlyDAO returns(bool success){
        require(newQuorum > 8400000000000000000000); //Minimum quorum is 8400 tokens (0.02% of total supply) for minimal security but should be adjusted to the community's liking and will likely never be close to this

        Quorum = newQuorum;
        
        return(success);
    }

    function ChangeDAO(address newAddr) external OnlyDAO {
        require(DAO != newAddr, "VotingSystemV1.ChangeDAO: New DAO address can't be the same as the old one");
        require(address(newAddr) != address(0), "VotingSystemV1.ChangeDAO: New DAO can't be the zero address");
        DAO = payable(newAddr);    
        emit NewDAOAddress(newAddr);
    }
    
    //Internal functions

    function _updateTaxesAndIndIncentive(uint256 VotingInstance) internal  {    
            VotingInstances[VotingInstance].CLDToBurn = ((VotingInstances[VotingInstance].TotalIncentive * BurnCut) / 10000);

            VotingInstances[VotingInstance].CLDToExecutioner = ((VotingInstances[VotingInstance].TotalIncentive * ExecutorCut) / 10000);

            VotingInstances[VotingInstance].CLDtoIncentive = VotingInstances[VotingInstance].TotalIncentive - (VotingInstances[VotingInstance].CLDToBurn + VotingInstances[VotingInstance].CLDToExecutioner);
    }

}

contract Winslow_SaleFactory_V2 {
    string public Version = "V1";
    address payable public DAO;
    uint256 public RetractFee; //^
    uint256 public MinimumDeposit; //^
    uint256 public DefaultSaleLength; //^
    uint256 public MaximumSalePercentage; //^The maximum percentage of the supply that can be sold at once, to avoid flooding markets/heavy inflation, in Basis Points

    constructor(){
        RetractFee = 100;
        MinimumDeposit = 100000000000000000;
        DefaultSaleLength = 432000;
        MaximumSalePercentage = 1000;
    }

    //Events
    event NewSaleCreated(uint256 SaleID, uint256 SaleAmount, address NewSaleContract);
    event NewDepositRetractFee(uint256 NewFeePercentBP);
    event NewMinimumDeposit(uint256 NewMinDeposit);
    event NewDefaultSaleLength(uint256 NewSaleLen);
    event NewMaxSalePercent(uint256 NewMax);
    event NewDAOAddress(address NewDAO);

    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    }

    function CreateNewSale(uint256 SaleID, uint256 CLDtoSell) external OnlyDAO returns(address _NewSaleAddress){
        uint256 TreasuryCLDBalance = ERC20(Winslow_Core_V1(DAO).CLDAddress()).balanceOf(Winslow_Core_V1(DAO).TreasuryContract());
        require(TreasuryCLDBalance >= CLDtoSell && CLDtoSell <= (((ERC20(Winslow_Core_V1(DAO).CLDAddress()).totalSupply() - TreasuryCLDBalance) * MaximumSalePercentage) / 10000));
        address NewSaleAddress = address(new Winslow_Sale_V2(DAO, SaleID, CLDtoSell, DefaultSaleLength, RetractFee, MinimumDeposit));
        
        emit NewSaleCreated(SaleID, CLDtoSell, NewSaleAddress);
        return(NewSaleAddress);
    }

    function ChangeRetractFee(uint256 NewRetractFee) external OnlyDAO returns(bool success){
        require(NewRetractFee <= 10000);
        RetractFee = NewRetractFee;

        emit NewDepositRetractFee(NewRetractFee);
        return(success);
    }

    function ChangeMinimumDeposit(uint256 NewMinDeposit) external OnlyDAO returns(bool success){
        require(NewMinDeposit > 1000000000000000);
        MinimumDeposit = NewMinDeposit;

        emit NewMinimumDeposit(NewMinDeposit);
        return(success);
    }

    function ChangeDefaultSaleLength(uint256 NewLength) external OnlyDAO returns(bool success){
        require(NewLength >= 259200 && NewLength <= 1209600); 
        DefaultSaleLength = NewLength;

        emit NewDefaultSaleLength(NewLength);
        return(success);
    }

    function ChangeMaxSalePercent(uint256 NewMaxPercent) external OnlyDAO returns(bool success){
        require(NewMaxPercent <= 10000);
        MaximumSalePercentage = NewMaxPercent;

        emit NewMaxSalePercent(NewMaxPercent);
        return(success);
    }

    function ChangeDAO(address newAddr) external OnlyDAO returns(bool success){
        require(DAO != newAddr, "VotingSystemV1.ChangeDAO: New DAO address can't be the same as the old one");
        require(address(newAddr) != address(0), "VotingSystemV1.ChangeDAO: New DAO can't be the zero address");
        DAO = payable(newAddr);    

        emit NewDAOAddress(newAddr);
        return(success);
    }

    function SetDAO(address DAOaddress) external returns(bool success){
        require(DAO == address(0), "VotingSystemV1.SetDAO: DAO address has already been set");

        DAO = payable(DAOaddress);
        return(success);
    }

}

contract Winslow_Sale_V2 {
    //  Variable, struct, mapping and other Declarations
    //  Winslow_Core_V1
    address payable public DAO;
    address public CLD;
    uint256 public SaleIdentifier; //This iteration of all CLD sales conducted
    uint256 public StartTime; //Unix Time
    uint256 public EndTime;   //Unix Time
    uint256 public CLDToBeSold; //Total Amount of CLD being offered for sale by the DAO
    //  Fees in basis points, chosen by proposer/al on deploy, so can be 0
    uint256 public MinimumDeposit; //Minimum Amount of Ether to be deposited when calling the deposit function
    uint256 public RetractFee; //Fee that is charged when a user removes their ether from the pool, to count as totaletherpool
    // Details
    uint256 public TotalEtherPool; //Defines the total Amount of ether deposited by participators
    uint256 public TotalRetractionFeesAccrued; //Total Amount of ether received from retraction fees
    bool public ProceedsNotTransfered = true; //Defaulted to true so that the if statement costs 0 gas after transfered for the first time

    enum SaleStatuses{ 
        Uncommenced, //Before the sale, allowing users to view the Amount of CLD that will sold and additional information
        Ongoing,     //While the sale is active, allowing users to deposit or withdraw ETC from the pool 
        Complete     //After the sale is complete, allowing users to withdraw their CLD in which they purchased
    }

    struct Participant{ 
        bool Participated;
        bool CLDclaimed;
        uint256 EtherDeposited;
        uint256 CLDWithdrawn;
    }

    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    } 

    event EtherDeposited(uint256 Amount, address User);
    event EtherWithdrawn(uint256 Amount, uint256 Fee, address User);
    event CLDclaimed(uint256 Amount, address User);
    event ProceedsTransfered(uint256 ToTreasury);
    
    //Mapping for participants
    mapping(address => Participant) public ParticipantDetails; 
    //List of participants for front-end ranking
    address[] public ParticipantList; 

    constructor(address _DAO, uint256 SaleID, uint256 CLDtoSell, uint256 SaleLength, uint256 RetractionFee, uint256 MinDeposit){
        require(SaleLength >= 259200 && SaleLength <= 1209600);
        DAO = payable(_DAO);
        SaleIdentifier = SaleID;
        CLD = Winslow_Core_V1(DAO).CLDAddress();
        CLDToBeSold = CLDtoSell; //Make sure CLD is transfered to contract by treasury, additional CLD sent to the sale contract will be lost
        StartTime = block.timestamp + 43200;
        EndTime = StartTime + SaleLength;
        RetractFee = RetractionFee;
        MinimumDeposit = MinDeposit;
    }

    //  During Sale
    //Deposit ETC

    function DepositEther() public payable returns(bool success){
        require(SaleStatus() == SaleStatuses(1));
        require(msg.value >= MinimumDeposit); 

        if(ParticipantDetails[msg.sender].Participated = false){
            ParticipantDetails[msg.sender].Participated = true;
            ParticipantList.push(msg.sender);
        }

        ParticipantDetails[msg.sender].EtherDeposited += msg.value;
        TotalEtherPool += msg.value;
        
        emit EtherDeposited(msg.value, msg.sender);
        return(success);
    }

    function WithdrawEther(uint256 Amount) public returns(bool success){
        require(ParticipantDetails[msg.sender].Participated == true);
        require(Amount <= ParticipantDetails[msg.sender].EtherDeposited);
        require(SaleStatus() == SaleStatuses(1));

        uint256 Fee = ((Amount * RetractFee) / 10000);

        TotalRetractionFeesAccrued += Fee;
        ParticipantDetails[msg.sender].EtherDeposited -= (Amount);
        TotalEtherPool -= (Amount - Fee);

        payable(msg.sender).transfer(Amount - Fee);

        emit EtherWithdrawn(Amount, Fee, msg.sender);
        return(success);
    }


    function ClaimCLD() public returns(bool success, uint256 AmountClaimed){
        require(ParticipantDetails[msg.sender].Participated == true);
        require(ParticipantDetails[msg.sender].CLDclaimed == false);
        require(SaleStatus() == SaleStatuses(2));
        ParticipantDetails[msg.sender].CLDclaimed = true;

        if(ProceedsNotTransfered){
            TransferProceeds();
        }

        uint256 CLDtoSend = ((CLDToBeSold *  ParticipantDetails[msg.sender].EtherDeposited) / TotalEtherPool);
        ParticipantDetails[msg.sender].CLDWithdrawn = CLDtoSend;

        ERC20(CLD).transfer(msg.sender, CLDtoSend);

        emit CLDclaimed(CLDtoSend, msg.sender);
        return(success, CLDtoSend);
    }

    //Internal functions

    function TransferProceeds() internal {
        ProceedsNotTransfered = false;

        (bool success1, ) = (Winslow_Core_V1(DAO).TreasuryContract()).call{value: TotalEtherPool}("");
        require(success1);

        emit ProceedsTransfered(TotalEtherPool);
    }

    //DAO Only functions

    function VerifyReadyForSale() external OnlyDAO view returns(bool Ready){
        require(ERC20(CLD).balanceOf(address(this)) == CLDToBeSold);
        
        return(Ready);
    }

    //View Functions

    function SaleStatus() public view returns(SaleStatuses Status){
        if(block.timestamp < StartTime){
            return(SaleStatuses(0));
        }
        if(block.timestamp > StartTime && block.timestamp < EndTime){
            return(SaleStatuses(1));
        }
        if(block.timestamp > EndTime){
            return(SaleStatuses(2));
        }
        else{
            revert("Error on getting sale status");
        }
    }

}

contract Winslow_Treasury_V1 {
    //Variable, struct and type declarations
    string public Version = "V1";
    address public DAO;
    uint8 public RegisteredAssetLimit;

    mapping(address => bool) public AssetRegistryMap;
    mapping(uint8 => Token) public RegisteredAssets;

    struct Token{ 
        address TokenAddress;
        bool Filled;
    }

    //Modifier declarations
    modifier OnlyDAO{ 
        require(msg.sender == DAO, 'This can only be done by the DAO');
        _;
    }

    //Event Declarations
    event AssetRegistered(address NewToken, uint256 CurrentBalance);
    event AssetLimitChange(uint256 NewLimit);
    event NewDAOAddress(address NewAddress);
    event EtherReceived(uint256 Amount, address Sender, address TxOrigin);
    event EtherSent(uint256 Amount, address Receiver, bytes data, bool sent, address TxOrigin);
    event ERC20Sent(uint256 Amount, address Receiver, address TxOrigin);
    event AssetsClaimedWithCLD(uint256 CLDin, uint256 EtherOut, address From, address OutTo, address TxOrigin);
    event ClaimTransferFailed(uint256 Amount, address Receiver, address Sender, address TokenAddress);

    //Code executed on deployment
    constructor(){
        DAO = msg.sender;
        RegisteredAssetLimit = 5;
        RegisteredAssets[0] = (Token(0xfc84c3Dc9898E186aD4b85734100e951E3bcb68c, true));
        AssetRegistryMap[0xfc84c3Dc9898E186aD4b85734100e951E3bcb68c] = true;
    }

    //Public callable functions
    function ReceiveRegisteredAsset(uint8 AssetID, uint amount) external {
        ERC20(RegisteredAssets[AssetID].TokenAddress).transferFrom(msg.sender, address(this), amount);
    }

        //CLD Claim
    function UserAssetClaim(uint256 CLDamount) public returns(bool success){
        AssetClaim(CLDamount, payable(msg.sender));

        return(success);
    }

    function AssetClaim(uint256 CLDamount, address payable To) public returns(bool success){
        uint256 SupplyPreTransfer = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - ERC20(RegisteredAssets[0].TokenAddress).balanceOf(address(this)));
        //Supply within the DAO does not count as backed
        ERC20(RegisteredAssets[0].TokenAddress).transferFrom(msg.sender, address(this), CLDamount);

        uint8 CurrentID = 1;
        while(CurrentID <= RegisteredAssetLimit){
            //It is very important that ERC20 contracts are audited properly to ensure that no errors could occur here, as one failed transfer would revert the whole TX
            if(RegisteredAssets[CurrentID].Filled == true){
                uint256 ToSend = GetAssetToSend(CLDamount, CurrentID, SupplyPreTransfer);
                try ERC20(RegisteredAssets[CurrentID].TokenAddress).transfer(To, ToSend){}
                catch {
                    emit ClaimTransferFailed(ToSend, To, msg.sender, RegisteredAssets[CurrentID].TokenAddress);
                }
                emit ERC20Sent(ToSend, To, tx.origin);
            }
            CurrentID++;
        }

        To.transfer(GetEtherToSend(CLDamount, SupplyPreTransfer));

        return(success);
    }

    //DAO and Eros Proposal only access functions
    function TransferETH(uint256 amount, address payable receiver) external OnlyDAO { 
        (bool sent, bytes memory data) = receiver.call{value: amount}("");

        emit EtherSent(amount, receiver, data, sent, tx.origin);
    }

    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external OnlyDAO { 
        ERC20(RegisteredAssets[AssetID].TokenAddress).transfer(receiver, amount);

        emit ERC20Sent(amount, receiver, tx.origin);
    }

    //Asset Registry management
    function RegisterAsset(address tokenAddress, uint8 slot) external OnlyDAO { 
        require(slot <= RegisteredAssetLimit && slot != 0);
        require(AssetRegistryMap[tokenAddress] == false);
        if(RegisteredAssets[slot].Filled == true){
            //Careful, if registered asset is replaced but not empty in contract, funds will be inaccesible
            AssetRegistryMap[RegisteredAssets[slot].TokenAddress] = false;
        }
        if(tokenAddress == address(0)){
           RegisteredAssets[slot] = Token(address(0), false); 
        }
        else{
        RegisteredAssets[slot] =  Token(tokenAddress, true); 
        AssetRegistryMap[tokenAddress] = true;
        }

        emit AssetRegistered(RegisteredAssets[slot].TokenAddress, ERC20(RegisteredAssets[slot].TokenAddress).balanceOf(address(this)));
    }

    //Setting modification functions
    function ChangeRegisteredAssetLimit(uint8 NewLimit) external OnlyDAO{
        //If assets are registered above the limit and the limit is changed, assets will still be registered so clear slots beforehand

        RegisteredAssetLimit = NewLimit;
        
        emit AssetLimitChange(NewLimit);
    }

    function ChangeDAO(address newAddr) external OnlyDAO{
        require(DAO != newAddr, "VotingSystemV1.ChangeDAO: New DAO address can't be the same as the old one");
        require(address(newAddr) != address(0), "VotingSystemV1.ChangeDAO: New DAO can't be the zero address");
        DAO = newAddr;    
        emit NewDAOAddress(newAddr);
    }

    //Public viewing functions 
    function IsRegistered(address TokenAddress) public view returns(bool){
        return(AssetRegistryMap[TokenAddress]);
    }

    function CLDAddress() public view returns(address CLD){
        return(RegisteredAssets[0].TokenAddress);
    }

    function GetBackingValueEther(uint256 CLDamount) public view returns(uint256 EtherBacking){
        uint256 DecimalReplacer = (10**10);
        uint256 DAObalance = ERC20(RegisteredAssets[0].TokenAddress).balanceOf(address(this));
        uint256 Supply = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - DAObalance);
        return(((CLDamount * ((address(this).balance * DecimalReplacer) / Supply)) / DecimalReplacer));
    }

    function GetBackingValueAsset(uint256 CLDamount, uint8 AssetID) public view returns(uint256 AssetBacking){
        require(AssetID > 0 && AssetID <= RegisteredAssetLimit && RegisteredAssets[AssetID].Filled == true, "Asset Cannot be CLD or a nonexistant slot");
        uint256 DecimalReplacer = (10**10);
        uint256 DAObalance = ERC20(RegisteredAssets[AssetID].TokenAddress).balanceOf(address(this));
        uint256 Supply = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - ERC20(RegisteredAssets[0].TokenAddress).balanceOf(address(this)));
        return(((CLDamount * ((DAObalance * DecimalReplacer) / Supply)) / DecimalReplacer));
    }

    function GetEtherToSend(uint256 CLDamount, uint256 PreSupply) internal view returns(uint256 EtherBacking){
        uint256 DecimalReplacer = (10**10);
        return(((CLDamount * ((address(this).balance * DecimalReplacer) / PreSupply)) / DecimalReplacer));
    }

    function GetAssetToSend(uint256 CLDamount, uint8 AssetID, uint256 PreSupply) internal view returns(uint256 AssetBacking){
        require(AssetID > 0 && AssetID <= RegisteredAssetLimit && RegisteredAssets[AssetID].Filled == true, "Asset Cannot be CLD or a nonexistant slot");
        uint256 DecimalReplacer = (10**10);
        uint256 DAOAssetBalance = ERC20(RegisteredAssets[AssetID].TokenAddress).balanceOf(address(this));
        return(((CLDamount * ((DAOAssetBalance * DecimalReplacer) / PreSupply)) / DecimalReplacer));
    }

    //Fallback Functions
    receive() external payable{
        emit EtherReceived(msg.value, msg.sender, tx.origin); 
    }

    fallback() external payable{
        emit EtherReceived(msg.value, msg.sender, tx.origin); 
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

interface EROS {
    function DAO() external view returns(address DAOaddress);
    function Multi() external view returns(bool);
    function OptionCount() external view returns(uint8);
    function RequestEther() external view returns(uint8);
    function TokenIdentifier() external view returns(uint8);
    function Execute() external returns(bool success);
    function ExecuteMulti(uint8 OptionToExecute) external returns(bool success);
    function ProposalMemo() external view returns(string memory);
    function VoteLength() external view returns(uint256);
    function RequestTokens() external view returns(uint256);
}

interface Replacements{
    function InheritCore(address Winslow_Treasury_V1, address Winslow_Voting_V1, uint256 LatestProposal, uint256 ProposalCost) external returns(bool success);
    function SendPredecessor(address Predecessor) external returns(bool success);
    function ChangeDAO(address NewDAO) external returns(bool success);
}