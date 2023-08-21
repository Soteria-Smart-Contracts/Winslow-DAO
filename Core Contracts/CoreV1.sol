//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by itself, and can also continue to be used 
if a new external core modules and contracts are deployed by changing their addresses and
providing previous contract information to the new contracts.
When setting up a new core or voting contract, ensure cross-compatibility and record keeping 
done by the archive contract, voting index and proposal indexes never restart */
pragma solidity ^0.8.17;


contract Winslow_Core_V1 {
    //Variable Declarations       //TODO:Comment this stuff
    string public Version = "V1";
    bool public ActiveContract;
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
        AddSecurityCommiteeMember,
        ChangeSaleMaxSalePercent,
        RemoveSecurityCommiteeMember
    }

    enum MultiOptions{
        OptionOne,
        OptionTwo,
        OptionThree,
        OptionFour,
        OptionFive
    }

    struct Proposal{
        uint256 ProposalID;
        address AddressSlot;            //To set an address either as a receiver, ProxyReceiver for approval of Eros proposal contract
        string Memo;                    //Short description of what the proposal is and does (Reduce length for gas efficiency)
        ProposalStatus Status;          //Types declared in enum
        SecurityStatus SecurityLevel;   //Types declared in enum
        ProposalTypes ProposalType;     //Types declared in enum
        SimpleProposalTypes SimpleType; //Types declared in enum
        uint256 VotingInstanceID;       //Identifier for the voting instance used for this proposal in the voting contract
        uint256 ProposalVotingLenght;   //Minimum 24 hours
        uint256 RequestedEtherAmount;   //Optional, can be zero
        uint256 RequestedAssetAmount;   //Optional, can be zero
        uint8 RequestedAssetID;         //Treasury asset identifier for proposals moving funds
        ProxyProposalArguments ProxyArgs; //List of arguments that can be used for proxy proposals, Also used for other data storage for simple proposals
        bool Multi;                     //False for just a regular one option proposal, True for any proposal with more than one option
        uint8 OptionsAvailable;         //Number of Options Available if there is more than one, default zero
        bool Executed;                  //Can only be executed once, when finished, proposal exist only as archive
        address Proposer;               //Address who initially created the proposal
    }

    struct ProxyProposalArguments{
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
        EmptyProxy = ProxyProposalArguments(0 ,0 ,0 ,address(0) ,address(0), address(0), false, false, false);
        //TODO: Special proposal in index 0
    }

    //Public state-modifing functions

    function SubmitSimpleProposal(address AddressSlot, uint256 UintSlot, SimpleProposalTypes SimpleType, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeSimpleProposal(AddressSlot, UintSlot, Memo, SimpleType, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID);

        return(success);

    }

    function SubmitProxyProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArgs) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeProxyProposal(Slot, Memo, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArgs);
        
        return(success);

    }


    function SubmitErosProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success){

        require(ReceiveProposalCost());

        InitializeErosProposal(Slot, Memo, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID);
        
        return(success);

    }

    //  Public view functions

    function CLDAddress() public view returns(address CLD){
        return(Treasury(TreasuryContract).CLDAddress());
    }

    //  Security Commitee functions

    //  Address Specific State Modifying Function


    //  Internal Functions

    function InitializeSimpleProposal(address AddressSlot, uint256 UintSlot, string memory Memo, SimpleProposalTypes SimpleType, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 Identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        //All simple proposals must have a slotted address for sending or action, but may be 0 in certain cases such as burn events or new sales
        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
        if(SimpleType == SimpleProposalTypes(2) || SimpleType == SimpleProposalTypes(3)){
            require(UintSlot > 0 && UintSlot <= 255 && UintSlot <= Treasury(TreasuryContract).RegisteredAssetLimit()); //TODO: problem here, should not be 2 and 3
            ProxyProposalArguments storage ProxyArgsWithSlot = EmptyProxy;
            ProxyArgsWithSlot.UnsignedInt1 = UintSlot;
            Proposals[NewIdentifier] = Proposal(NewIdentifier, AddressSlot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(0), SimpleType, VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArgsWithSlot, false, 0, false, msg.sender);
        } 
        else{
        Proposals[NewIdentifier] = Proposal(NewIdentifier, AddressSlot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(0), SimpleType, VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, EmptyProxy, false, 0, false, msg.sender);
        }

        return(NewIdentifier);

    }

    function InitializeProxyProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArgs) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ProxyProposals must have a slotted contract");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
        Proposals[NewIdentifier] = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(1), SimpleProposalTypes(0), VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArgs, false, 0, false, msg.sender);

        return(NewIdentifier);

    }

    function InitializeErosProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ErosProposals must have a slotted contract");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        if(EROS(Slot).Multi() ==  true){
            require(EROS(Slot).OptionCount() > 1, 'Eros proposal marked as multiple options true, but less than two options are available');
            uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, true);
            Proposals[NewIdentifier] = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(2), SimpleProposalTypes(0), VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, EmptyProxy, true, EROS(Slot).OptionCount(), false, msg.sender);
        }
        else{
            uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
            Proposals[NewIdentifier] = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(2), SimpleProposalTypes(0), VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, EmptyProxy, false, 0, false, msg.sender);
        }

        return(NewIdentifier);

    }

    //  Execution Functions

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
        uint8 Slot = uint8(Proposals[ProposalID].ProxyArgs.UnsignedInt1); 
        Treasury(TreasuryContract).RegisterAsset(TokenAddress, Slot);

        return(success);
    }
        //ChangeRegisteredAssetLimit
    function ChangeRegisteredAssetLimit(uint256 ProposalID) internal returns(bool success){
        
        uint8 NewLimit = uint8(Proposals[ProposalID].ProxyArgs.UnsignedInt1); 
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
        ActiveContract = false;

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


        // ChangeProposalCost

    function ChangeProposalCost(uint256 newCost) internal returns(bool success){

        ProposalCost = newCost;
        
        return(success);
    }

        // AddSecurityCommiteeMember
        // RemoveSecurityCommiteeMember
        // ChangeSaleFoundationFee

    function ChangeSaleFoundationFee(uint256 NewFee) internal returns(bool success){
            
        SaleFactory(SaleFactoryContract).();
        return(success);

    }

    
        // ChangeSaleRetractFee
        // ChangSaleeMinimumDeposit
        // ChangeSaleDefaultSaleLength
        // ChangeSaleMaxSalePercent
        // 


    // Other Internals
    //TODO: Make the cuts changeable via proposal
    function ReceiveProposalCost() internal returns(bool success){

        ERC20(CLDAddress()).transferFrom(msg.sender, TreasuryContract, (ProposalCost / 2));

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
        ActiveContract = true;

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
}

interface Replacements{
    function InheritCore(address Treasury, address Voting, uint256 LatestProposal, uint256 ProposalCost) external returns(bool success);
    function SendPredecessor(address Predecessor) external returns(bool success);
    function ChangeDAO(address NewDAO) external returns(bool success);
}

interface SaleFactory{
    function CreateNewSale(uint256 SaleID, uint256 CLDtoSell) external returns(address NewSaleContract);
    function MaximumSalePercentage() external returns(uint256 BasisPointMax);
}

interface SaleContract{
    function StartTime() external returns(uint256 Time);
    function EndTime() external returns(uint256 Time);
    function VerifyReadyForSale() external returns(bool Ready);
    function ChangeFoundationFee(uint256 NewFee) external returns(bool success);
    function ChangeRetractFee(uint256 NewRetractFee) external returns(bool success);
    function ChangeMinimumDeposit(uint256 NewMinDeposit) external returns(bool success);
    function ChangeDefaultSaleLength(uint256 NewLength) external returns(bool success);
    function ChangeMaxSalePercent(uint256 NewMaxPercent) external returns(bool success);
    
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