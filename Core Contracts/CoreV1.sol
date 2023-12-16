//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by itself, and can also continue to be used 
if a new external core modules and contracts are deployed by changing their addresses and
providing previous contract information to the new contracts.
When setting up a new core or voting contract, ensure cross-compatibility and record keeping 
done by the archive contract, voting index and proposal indexes never restart */
pragma solidity ^0.8.19;

//import "./TreasuryV1.sol";
//import "./VotingV1.sol";

contract Winslow_Core_V1 {
    //Variable Declarations       //TODO:Comment this stuff
    string public Version = "V1";
    bool public IsActiveContract;
    address public TreasuryContract;
    address public VotingContract;
    address public SaleFactoryContract;
    address public FoundationAddress;
    address public InitialSetter;
    bool public InitialContractsSet;
    uint256 public ProposalCost = 100000000000000000000; //Initial cost, can be changed via proposals
    uint256 public SaleCount;
    uint256 public VoteLength = 600; //Default two days for an efficient DAO, but can be changed by proposals in case quorums are not being met TODO: Change back to 172800
    ProxyProposalArguments internal EmptyProxy;

    //Mapping, structs and other declarations
    
    //Proposals
    mapping(uint256 => Proposal) public Proposals;
    mapping(uint256 => ProposalInfo) public ProposalInfos;
    mapping(uint256 => ProxyProposalArguments) ProxyArgs;
    uint256 public MRIdentifier;

    //Token Sales
    mapping(uint256 => Sale) public Sales;
    function SaleActive() public view returns(bool){
        if(block.timestamp >= Sales[LatestSale].EndTime){return true;}else{return false;}
    }
    uint256 public LatestSale;

    enum ProposalStatus{
        Security_Verification,
        Pre_Voting,
        Voting,
        Executed,
        Rejected
    }

    enum ProposalTypes{
        Simple,
        Proxy,
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
        ChangeSaleFoundationFee,
        ChangeSaleRetractFee,
        ChangeSaleMinimumDeposit,
        ChangeSaleDefaultSaleLength,
        ChangeSaleMaxSalePercent,
        ChangeDefaultQuorum,
        ChangeFoundationAddress,
        ChangeVotingLength
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
        uint256 VotingInstanceID;       //Identifier for the voting instance used for this proposal in the voting contract
        uint256 ProposalVotingLength;
    }

    struct Proposal{
        address AddressSlot;            //To set an address either as a receiver, ProxyReceiver for approval of Eros proposal contract
        uint256 RequestedEtherAmount;   //Optional, can be zero
        uint256 RequestedAssetAmount;   //Optional, can be zero
        uint8 RequestedAssetID;         //Treasury asset identifier for proposals moving funds
        uint8 OptionsAvailable;         //Number of Options Available if there is more than one, default zero
        bool Multi;                     //False for just a regular one option proposal, True for any proposal with more than one option
        bool Executed;                  //Can only be executed once, when finished, proposal exist only as archive
        address Proposer;               //Address who initially created the proposal
    }

    struct ProxyProposalArguments{
        uint8 FunctionSelector;
        uint256 UnsignedInt1;
        uint256 UnsignedInt2;
        uint256 UnsignedInt3; 
        address Address1;
        address Address2;
        address Address3;
        bool Bool1;
        bool Bool2;
        bool Bool3;
    }

    struct Sale{
        address SaleContract;
        uint256 CLDSaleAmount;
        uint256 StartTime;
        uint256 EndTime;
    }

    //TODOs
    //TODO: Prepare proposal queue functionality where the highest reward proposal is always at the top of the queue and the next to be voted on
    //TODO: Review Multi Functionality
    //TODO: Review voteresult
    //TODO: Review default quorum
    //TODO: Review Voting lenght make sure 2 days thing is properly implemented
    //TODO: Lots of testing


    //TODO: Make Events
    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);
    //create all the events we need and in the following line for each add a comment and the line or lines it should be inserted into


    constructor(){
        InitialSetter = msg.sender;
        EmptyProxy = ProxyProposalArguments(0, 0 ,0 ,0 ,address(0) ,address(0), address(0), false, false, false);
        SubmitSimpleProposal("TODO: Make a community agreed first memo", address(0), 0, SimpleProposalTypes(0), 0, 0, 0);
    }

    //Public state-modifing functions

    function SubmitSimpleProposal(string memory Memo, address AddressSlot, uint256 UintSlot, SimpleProposalTypes SimpleType, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeSimpleProposal(Memo, AddressSlot, UintSlot, SimpleType, RequestedEther, RequestedAssetAmount, RequestedAssetID);

        return(success);

    }

    function SubmitProxyProposal(string memory Memo, address Slot, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArguments) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeProxyProposal(Memo, Slot, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArguments);
        
        return(success);

    }

    function SubmitErosProposal(address ProposalAddress) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeErosProposal(ProposalAddress);
        
        return(success);

    }

    //  Public view functions

    function CLDAddress() public view returns(address CLD){
        return(Treasury(TreasuryContract).CLDAddress());
    }


    //  Internal Functions

    function InitializeSimpleProposal(string memory Memo, address AddressSlot, uint256 UintSlot, SimpleProposalTypes SimpleType, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 Identifier){
        require(SimpleType != SimpleProposalTypes(0), "Simple proposals cannot be of type 0");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        //All simple proposals must have a slotted address for sending or action, but may be 0 in certain cases such as burn events or new sales
        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, false);
        if(SimpleType == SimpleProposalTypes(2)){
            require(UintSlot > 0 && UintSlot <= 255 && UintSlot <= Treasury(TreasuryContract).RegisteredAssetLimit());
            ProxyProposalArguments storage ProxyArgsWithSlot = EmptyProxy;
            ProxyArgsWithSlot.UnsignedInt1 = UintSlot;
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(0), SimpleType, ProposalStatus(0), VotingInstanceID, VoteLength);
            Proposals[NewIdentifier] = Proposal(AddressSlot, RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
            ProxyArgs[NewIdentifier] = ProxyArgsWithSlot;
        } 
        else{
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(0), SimpleType, ProposalStatus(0), VotingInstanceID, VoteLength);
            Proposals[NewIdentifier] = Proposal(AddressSlot, RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
            ProxyArgs[NewIdentifier] = EmptyProxy;
        }

        return(NewIdentifier);
    }

    function InitializeProxyProposal(string memory Memo, address Slot, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArguments) internal returns(uint256 identifier){
        require(Slot != address(0), "ProxyProposals must have a slotted contract");
        require(ProxyArguments.FunctionSelector > 0 && ProxyArguments.FunctionSelector < 9, "Proxy proposal function selector must be between 1 and 9");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, false);
        ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(1), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID, VoteLength);
        Proposals[NewIdentifier] = Proposal(Slot, RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
        ProxyArgs[NewIdentifier] = ProxyArguments;

        return(NewIdentifier);

    }

    function InitializeErosProposal(address ProposalAddress) internal returns(uint256 identifier){
        require(ProposalAddress != address(0), "ErosProposals must have a slotted contract");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        string memory Memo = EROS(ProposalAddress).ProposalMemo();
        uint256 RequestedEther = EROS(ProposalAddress).RequestEther();
        uint256 RequestedAssetAmount = EROS(ProposalAddress).RequestTokens();
        uint8 RequestedAssetID = EROS(ProposalAddress).TokenIdentifier();

        if(RequestedAssetAmount > 0){
            require(RequestedAssetID > 0 && RequestedAssetID <= 255 && RequestedAssetID <= Treasury(TreasuryContract).RegisteredAssetLimit(), "Requested asset ID must be atleast 1 and be registered in the treasury");
        }

        if(EROS(ProposalAddress).Multi() == true){
            uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, true);
            require(EROS(ProposalAddress).OptionCount() > 1, 'Eros proposal marked as multiple options true, but less than two options are available');

            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(2), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID, VoteLength);
            Proposals[NewIdentifier] = Proposal(ProposalAddress, RequestedEther, RequestedAssetAmount, RequestedAssetID, EROS(ProposalAddress).OptionCount(), true, false, msg.sender);
            ProxyArgs[NewIdentifier] = EmptyProxy;
        }
        else{
            uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, false);

            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(2), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID, VoteLength);
            Proposals[NewIdentifier] = Proposal(ProposalAddress, RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
            ProxyArgs[NewIdentifier] = EmptyProxy;
        }

        return(NewIdentifier);
    }

    //  Execution Functions

    function ExecuteProposal(uint256 ProposalID) external returns(bool success){
            require(msg.sender == VotingContract, "Only the voting contract can execute proposals");
            require(ProposalInfos[ProposalID].Status == ProposalStatus(2), "Proposal must be in voting status to be executed");
            (bool Result, uint8 Multi) = Voting(VotingContract).GetVoteResult(ProposalInfos[ProposalID].VotingInstanceID);
            require(Result == true, "Proposal must be approved by voting to be executed");
            require(Proposals[ProposalID].Executed == false, "Proposal has already been executed");
    
            Proposals[ProposalID].Executed = true;
            ProposalInfos[ProposalID].Status = ProposalStatus(3);
    
            if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(0)){
                ExecuteSimpleProposal(ProposalID);
            }
            else if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(1)){
                ExecuteProxyProposal(ProposalID);
            }
            else if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(2) && Proposals[ProposalID].Multi == true){
                ExecuteErosProposal(ProposalID);
            }
    
            return(success);
    }

    //  Simple Executionting

    function ExecuteSimpleProposal(uint256 ProposalID) internal {
        
        if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(0)){
            //Do nothing, this is a placeholder for the first proposal
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(1)){
            SendAssets(ProposalID);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(2)){
            RegisterTreasuryAsset(ProposalID);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(3)){
            ChangeRegisteredAssetLimit(ProposalID);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(4)){
            ReplaceTreasury(Proposals[ProposalID].AddressSlot);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(5)){
            ReplaceVoting(Proposals[ProposalID].AddressSlot);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(6)){
            ReplaceSaleFactory(Proposals[ProposalID].AddressSlot);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(7)){
            ReplaceCore(Proposals[ProposalID].AddressSlot);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(8)){
            StartPublicSale(Proposals[ProposalID].RequestedAssetAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(9)){
            ChangeProposalCost(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(10)){
            ChangeSaleFoundationFee(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(11)){
            ChangeSaleRetractFee(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(12)){
            ChangeSaleMinimumDeposit(Proposals[ProposalID].RequestedEtherAmount); 
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(13)){
            ChangeSaleDefaultSaleLength(Proposals[ProposalID].RequestedEtherAmount); //Value is stored in RequestedEtherAmount in seconds
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(14)){
            ChangeSaleMaxSalePercent(Proposals[ProposalID].RequestedEtherAmount); //Value is stored in RequestedEtherAmount in basis points
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(15)){
            ChangeQuorum(Proposals[ProposalID].RequestedEtherAmount); //Value is stored in RequestedEtherAmount in basis points
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(16)){
            ChangeFoundationAddress(Proposals[ProposalID].AddressSlot);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(17)){
            ChangeVotingLength(Proposals[ProposalID].RequestedEtherAmount); //Value is stored in RequestedEtherAmount in seconds
        }
    }

    //  Proxy Executionting

    function ExecuteProxyProposal(uint256 ProposalID) internal {

        if(ProxyArgs[ProposalID].FunctionSelector == 1){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionOne(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 2){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionTwo(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 3){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionThree(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 4){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionFour(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 5){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionFive(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 6){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionSix(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 7){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionSeven(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 8){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionEight(ProxyArgs[ProposalID]);
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 9){
            ProxyContract(Proposals[ProposalID].AddressSlot).ProxyFunctionNine(ProxyArgs[ProposalID]);
        }
    }

    //  Eros Executionting

    function ExecuteErosProposal(uint256 ProposalID) internal {
        // Send requested assets out to the eros address
        SendAssets(ProposalID);

        // Execute the eros proposal
        if(Proposals[ProposalID].Multi == true){
            EROS(Proposals[ProposalID].AddressSlot).ExecuteMulti(uint8(ProxyArgs[ProposalID].UnsignedInt1));
        }

        else{
            EROS(Proposals[ProposalID].AddressSlot).Execute();
        }

        
    }

    //  Internal Simple Proposal Call Functions

        // AssetSend
    function SendAssets(uint256 ProposalID) internal returns(bool success){

        if(Proposals[ProposalID].RequestedEtherAmount > 0){
            Treasury(TreasuryContract).TransferETH(Proposals[ProposalID].RequestedEtherAmount, payable(Proposals[ProposalID].AddressSlot));
        }
        if(Proposals[ProposalID].RequestedAssetAmount > 0){
            Treasury(TreasuryContract).TransferERC20(Proposals[ProposalID].RequestedAssetID, Proposals[ProposalID].RequestedAssetAmount, Proposals[ProposalID].AddressSlot);
        }

        return(success);
    }
    
        // AssetRegister
    function RegisterTreasuryAsset(uint256 ProposalID) internal returns(bool success){

        address TokenAddress = Proposals[ProposalID].AddressSlot;
        uint8 Slot = uint8(ProxyArgs[ProposalID].UnsignedInt1); 
        Treasury(TreasuryContract).RegisterAsset(TokenAddress, Slot);

        return(success);
    }
        //ChangeRegisteredAssetLimit
    function ChangeRegisteredAssetLimit(uint256 ProposalID) internal returns(bool success){
        
        uint8 NewLimit = uint8(ProxyArgs[ProposalID].UnsignedInt1); 
        Treasury(TreasuryContract).ChangeRegisteredAssetLimit(NewLimit);
        
        return(success);
    }

        // TreasuryChange
    function ReplaceTreasury(address NewTreasury) internal returns(bool success){

        Replacements(NewTreasury).SendPredecessor(TreasuryContract);
        TreasuryContract = NewTreasury;

        emit NewTreasurySet(NewTreasury);
        return(success);
    }
    
    function ReplaceVoting(address NewVoting) internal returns(bool success){
        
        Replacements(NewVoting).SendPredecessor(VotingContract);
        VotingContract = NewVoting;

        return(success);
    }

    function ReplaceSaleFactory(address NewSaleModule) internal returns(bool success){

        SaleFactoryContract = NewSaleModule;
        
        return success;
    }

    function ChangeFoundationAddress(address NewFoundationAddress) internal returns(bool success){

        FoundationAddress = NewFoundationAddress;
        
        return(success);
    }


    function ReplaceCore(address NewCore) internal returns(bool success){
        IsActiveContract = false;

        Replacements(NewCore).InheritCore(TreasuryContract, VotingContract, MRIdentifier, ProposalCost); //TODO: Make sure it transfers all needed info, add sale info
        Replacements(TreasuryContract).ChangeDAO(NewCore);
        Replacements(VotingContract).ChangeDAO(NewCore);
        Replacements(SaleFactoryContract).ChangeDAO(NewCore);

        return(success);
    }


    function StartPublicSale(uint256 CLDtoSell) internal returns(bool success, address NewSaleContract){
        require(!SaleActive());
        LatestSale++;

        address NewSaleAddress = SaleFactory(SaleFactoryContract).CreateNewSale(LatestSale, CLDtoSell);
        Sales[LatestSale] = Sale(NewSaleAddress,CLDtoSell, SaleContract(NewSaleAddress).StartTime(), SaleContract(NewSaleAddress).EndTime());

        Treasury(TreasuryContract).TransferERC20(0, CLDtoSell, NewSaleAddress);

        require(SaleContract(NewSaleAddress).VerifyReadyForSale(), 'The sale contract has not be able to confirm a receipt of CLD to sell');
        return(success, NewSaleAddress);
    }


    function ChangeProposalCost(uint256 newCost) internal returns(bool success){

        ProposalCost = newCost;
        
        return(success);
    }

    function ChangeQuorum(uint256 newQuorum) internal returns(bool success){

        Voting(VotingContract).ChangeQuorum(newQuorum);
        
        return(success);
    }

    
    //Sale factory variable change functions

    function ChangeSaleFoundationFee(uint256 NewFee) internal returns(bool success){
            
        SaleFactory(SaleFactoryContract).ChangeFoundationFee(NewFee);

        return(success);
    }

    function ChangeSaleRetractFee(uint256 NewRetractFee) internal returns(bool success){

        SaleFactory(SaleFactoryContract).ChangeRetractFee(NewRetractFee);

        return(success);
    }

    function ChangeSaleMinimumDeposit(uint256 NewMinDeposit) internal returns(bool success){

        SaleFactory(SaleFactoryContract).ChangeMinimumDeposit(NewMinDeposit);
    
        return(success);
    }

    function ChangeSaleDefaultSaleLength(uint256 NewLength) internal returns(bool success){
            
        SaleFactory(SaleFactoryContract).ChangeDefaultSaleLength(NewLength);
    
        return(success);
    }

    function ChangeSaleMaxSalePercent(uint256 NewMaxPercent) internal returns(bool success){
                
        SaleFactory(SaleFactoryContract).ChangeMaxSalePercent(NewMaxPercent);
        
        return(success);
    }

    function ChangeVotingLength(uint256 NewLength) internal returns(bool success){
                
        VoteLength = NewLength;
        
        return(success);
    }

    // Other Internals
    function ReceiveProposalCost() internal returns(bool success){

        ERC20(CLDAddress()).transferFrom(msg.sender, VotingContract, (ProposalCost / 2));

        ERC20(CLDAddress()).transferFrom(msg.sender, TreasuryContract, ERC20(CLDAddress()).balanceOf(address(this)));

        return(success);
    }

    
    //One Time Functions
    function SetInitialContracts(address _TreasuryAddress, address _VotingAddress, address _SaleFactory, address _FoundationAddress) external{

        require(msg.sender == InitialSetter);
        require(InitialContractsSet == false);

        TreasuryContract = _TreasuryAddress;
        VotingContract = _VotingAddress;
        SaleFactoryContract = _SaleFactory;
        FoundationAddress = _FoundationAddress;
        InitialSetter = address(0); //Once the reasury address has been set for the first time, it can only be set again via proposal 
        InitialContractsSet = true;
        IsActiveContract = true;

        emit NewTreasurySet(_TreasuryAddress);
        //TODO: NewVotingSet, New Sale Factory Set, New foundation address set
    }

    receive() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(TreasuryContract).transfer(address(this).balance);
    }

    fallback() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(TreasuryContract).transfer(address(this).balance);
    }
}

interface Voting{
    function InitializeVoteInstance(uint256 ProposalID, bool Multi) external returns(uint256 VoteInstanceID);
    function GetVoteResult(uint256 VoteInstanceID) external view returns(bool Result, uint8 Multi);
    function ChangeQuorum(uint256 NewQuorumBasisPoints) external returns(bool success);
}

interface Replacements{
    function InheritCore(address Treasury, address Voting, uint256 LatestProposal, uint256 ProposalCost) external returns(bool success);
    function SendPredecessor(address Predecessor) external returns(bool success);
    function ChangeDAO(address NewDAO) external returns(bool success);
}

interface SaleFactory{
    function CreateNewSale(uint256 SaleID, uint256 CLDtoSell) external returns(address NewSaleContract);
    function MaximumSalePercentage() external returns(uint256 BasisPointMax);
    function ChangeFoundationFee(uint256 NewFee) external returns(bool success);
    function ChangeRetractFee(uint256 NewRetractFee) external returns(bool success);
    function ChangeMinimumDeposit(uint256 NewMinDeposit) external returns(bool success);
    function ChangeDefaultSaleLength(uint256 NewLength) external returns(bool success);
    function ChangeMaxSalePercent(uint256 NewMaxPercent) external returns(bool success);
}

interface ProxyContract{
    function ProxyFunctionOne(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionTwo(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionThree(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionFour(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionFive(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionSix(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionSeven(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionEight(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
    function ProxyFunctionNine(Winslow_Core_V1.ProxyProposalArguments memory ExecutionArguments) external returns(bool success);
}

interface SaleContract{
    function StartTime() external returns(uint256 Time);
    function EndTime() external returns(uint256 Time);
    function VerifyReadyForSale() external returns(bool Ready); 
}

//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future, only Eros proposals will be able to access it due to their flexibility
interface Treasury {
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
    function CLDAddress() external view returns(address CLD);
    function RegisteredAssetLimit() external view returns(uint8 Limit);
    function IsRegistered(address TokenAddress) external view returns(bool);
    function GetBackingValueEther(uint256 CLDamount) external view returns(uint256 EtherBacking);
    function GetBackingValueAsset(uint256 CLDamount, uint8 AssetID) external view returns(uint256 AssetBacking);
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