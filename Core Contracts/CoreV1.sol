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

    enum SecurityStatus{
        Unconfirmed,
        Safe,
        Medium,
        Severe,
        Fatal
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
        CoreReplacement,
        StartPublicSale,
        ChangeProposalCost,
        ChangeSaleFoundationFee,
        ChangeSaleRetractFee,
        ChangeSaleMinimumDeposit,
        ChangeSaleDefaultSaleLength,
        ChangeSaleMaxSalePercent,
        ChangeDefaultQuorum
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
        SecurityStatus SecurityLevel;   //Types declared in enum
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

    //TODO: Make Events
    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);


    constructor(){
        InitialSetter = msg.sender;
        EmptyProxy = ProxyProposalArguments(0, 0 ,0 ,0 ,address(0) ,address(0), address(0), false, false, false);
        //TODO: Special proposal in index 0
    }

    //Public state-modifing functions

    function SubmitSimpleProposal(string memory Memo, address AddressSlot, uint256 UintSlot, SimpleProposalTypes SimpleType, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeSimpleProposal(Memo, AddressSlot, UintSlot, SimpleType, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID);

        return(success);

    }

    function SubmitProxyProposal(string memory Memo, address Slot, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArguments) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeProxyProposal(Memo, Slot, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArguments);
        
        return(success);

    }


    function SubmitErosProposal(string memory Memo, address Slot, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeErosProposal(Memo, Slot, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID);
        
        return(success);

    }

    //  Public view functions

    function CLDAddress() public view returns(address CLD){
        return(Treasury(TreasuryContract).CLDAddress());
    }

    //  Address Specific State Modifying Function


    //  Internal Functions

    function InitializeSimpleProposal(string memory Memo, address AddressSlot, uint256 UintSlot, SimpleProposalTypes SimpleType, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 Identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(SimpleType != SimpleProposalTypes(0), "Simple proposals cannot be of type 0");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        //All simple proposals must have a slotted address for sending or action, but may be 0 in certain cases such as burn events or new sales
        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
        if(SimpleType == SimpleProposalTypes(2) || SimpleType == SimpleProposalTypes(3)){
            require(UintSlot > 0 && UintSlot <= 255 && UintSlot <= Treasury(TreasuryContract).RegisteredAssetLimit()); //TODO: problem here, should not be 2 and 3
            ProxyProposalArguments storage ProxyArgsWithSlot = EmptyProxy;
            ProxyArgsWithSlot.UnsignedInt1 = UintSlot;
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(0), SimpleType, ProposalStatus(0), VotingInstanceID, VotingLength);
            Proposals[NewIdentifier] = Proposal(AddressSlot, SecurityStatus(0), RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
            ProxyArgs[NewIdentifier] = ProxyArgsWithSlot;
        } 
        else{
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(0), SimpleType, ProposalStatus(0), VotingInstanceID, VotingLength);
            Proposals[NewIdentifier] = Proposal(AddressSlot, SecurityStatus(0), RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
            ProxyArgs[NewIdentifier] = EmptyProxy;
        }

        return(NewIdentifier);

    }

    function InitializeProxyProposal(string memory Memo, address Slot, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArguments) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ProxyProposals must have a slotted contract");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
        ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(1), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID, VotingLength);
        Proposals[NewIdentifier] = Proposal(Slot, SecurityStatus(0), RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
        ProxyArgs[NewIdentifier] = ProxyArguments;

        return(NewIdentifier);

    }

    function InitializeErosProposal(string memory Memo, address Slot, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ErosProposals must have a slotted contract");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, true);

        if(EROS(Slot).Multi() ==  true){
            require(EROS(Slot).OptionCount() > 1, 'Eros proposal marked as multiple options true, but less than two options are available');
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(2), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID, VotingLength);
            Proposals[NewIdentifier] = Proposal(Slot, SecurityStatus(0), RequestedEther, RequestedAssetAmount, RequestedAssetID, EROS(Slot).OptionCount(), true, false, msg.sender);
            ProxyArgs[NewIdentifier] = EmptyProxy;
        }
        else{
            ProposalInfos[NewIdentifier] = ProposalInfo(Memo, ProposalTypes(2), SimpleProposalTypes(0), ProposalStatus(0), VotingInstanceID, VotingLength);
            Proposals[NewIdentifier] = Proposal(Slot, SecurityStatus(0), RequestedEther, RequestedAssetAmount, RequestedAssetID, 0, false, false, msg.sender);
            ProxyArgs[NewIdentifier] = EmptyProxy;
        }

        return(NewIdentifier);

    }

    //  Execution Functions

    function ExecuteProposal(uint256 ProposalID) external returns(bool success){
            require(msg.sender == VotingContract, "Only the voting contract can execute proposals");
            require(ProposalInfos[ProposalID].Status == ProposalStatus(2), "Proposal must be in voting status to be executed");
            require(Voting(VotingContract).GetVoteResult(ProposalInfos[ProposalID].VotingInstanceID) == true, "Proposal must be approved by voting to be executed");
            require(Proposals[ProposalID].Executed == false, "Proposal has already been executed");
    
            Proposals[ProposalID].Executed = true;
            ProposalInfos[ProposalID].Status = ProposalStatus(3);
    
            if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(0)){
                ExecuteSimpleProposal(ProposalID);
            }
            else if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(1)){
                ExecuteProxyProposal(ProposalID);
            }
            else if(ProposalInfos[ProposalID].ProposalType == ProposalTypes(2)){
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
            ReplaceCore(Proposals[ProposalID].AddressSlot);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(7)){
            StartPublicSale(Proposals[ProposalID].RequestedAssetAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(8)){
            ChangeProposalCost(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(9)){
            ChangeSaleFoundationFee(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(10)){
            ChangeSaleRetractFee(Proposals[ProposalID].RequestedEtherAmount);
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(11)){
            ChangeSaleMinimumDeposit(Proposals[ProposalID].RequestedEtherAmount); 
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(12)){
            ChangeSaleDefaultSaleLength(Proposals[ProposalID].RequestedEtherAmount); //Value is stored in RequestedEtherAmount in seconds
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(13)){
            ChangeSaleMaxSalePercent(Proposals[ProposalID].RequestedEtherAmount); //Value is stored in RequestedEtherAmount in basis points
        }
        else if(ProposalInfos[ProposalID].SimpleType == SimpleProposalTypes(14)){
            ChangeQuorum(Proposals[ProposalID].RequestedEtherAmount); //Value is stored in RequestedEtherAmount in basis points
        }

    }

    //  Proxy Executionting

    function ExecuteProxyProposal(uint256 ProposalID) internal {

        if(ProxyArgs[ProposalID].FunctionSelector == 1){
            ProxyProposal(Proposals[ProposalID].AddressSlot).ProxyFunctionOne();
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 2){
            ProxyProposal(Proposals[ProposalID].AddressSlot).ProxyFunctionTwo();
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 3){
            ProxyProposal(Proposals[ProposalID].AddressSlot).ProxyFunctionThree();
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 4){
            ProxyProposal(Proposals[ProposalID].AddressSlot).ProxyFunctionFour();
        }
        else if(ProxyArgs[ProposalID].FunctionSelector == 5){
            ProxyProposal(Proposals[ProposalID].AddressSlot).ProxyFunctionFive();
        }


        
    }

    //  Eros Executionting

    function ExecuteErosProposal(uint256 ProposalID) internal {

        
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
    
        // VotingChange
    function ReplaceVoting(address NewVoting) internal returns(bool success){
        
        Replacements(NewVoting).SendPredecessor(VotingContract);
        VotingContract = NewVoting;

        return(success);
    }

    //TODO: ReplaceSaleModule

        // CoreReplacement
    function ReplaceCore(address NewCore) internal returns(bool success){
        IsActiveContract = false;

        Replacements(NewCore).InheritCore(TreasuryContract, VotingContract, MRIdentifier, ProposalCost); //TODO: Make sure it transfers all needed info, add sale info
        Replacements(TreasuryContract).ChangeDAO(NewCore);
        Replacements(VotingContract).ChangeDAO(NewCore);

        //TODO: tell sale module to switch contract

        return(success);
    }
        //TODO:
        // StartPublicSale
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

    // Other Internals
    //TODO: Make the cuts changeable via proposal
    function ReceiveProposalCost() internal returns(bool success){

        ERC20(CLDAddress()).transferFrom(msg.sender, VotingContract, (ProposalCost / 2));

        ERC20(CLDAddress()).transferFrom(msg.sender, address(this), (ProposalCost / 2));
        ERC20(CLDAddress()).Burn(ERC20(CLDAddress()).balanceOf(address(this)));

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
    function InitializeVoteInstance(uint256 ProposalID, uint256 VotingLength, bool Multi) external returns(uint256 VoteInstanceID);
    function GetVoteResult(uint256 VoteInstanceID) external view returns(bool Result);
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

interface ProxyProposal{
    function ProxyFunctionOne() external returns(bool success);
    function ProxyFunctionTwo() external returns(bool success);
    function ProxyFunctionThree() external returns(bool success);
    function ProxyFunctionFour() external returns(bool success);
    function ProxyFunctionFive() external returns(bool success);
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
}