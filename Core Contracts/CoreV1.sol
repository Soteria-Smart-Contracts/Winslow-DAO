//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract Winslow_Core_V1{
    //Variable Declarations
    string public Version = "V1";
    bool public ActiveContract;
    address public TreasuryContract = address(0);
    address public VotingContract = address(0);
    address public InitialSetter;
    bool public InitialContractsSet = false;
    uint256 public ProposalCost = 100000000000000000000; //Initial cost, can be changed via proposals
    ProxyProposalArguments internal EmptyProxy;

    //Mapping, structs and other declarations
     
    mapping(uint256 => Proposal) public Proposals;
    uint256 MRIdentifier = 0;

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
        TreasuryReplacement,
        VotingReplacement,
        CoreReplacement,
        AddSecurityCommiteeMember,
        RemoveSecurityCommiteeMember
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


    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);


    constructor(){
        InitialSetter = msg.sender;
        EmptyProxy = ProxyProposalArguments(0 ,0 ,0 ,address(0) ,address(0), address(0), false, false, false);
        //Special proposal in index 0
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

    //  Internal Functions

    function InitializeSimpleProposal(address AddressSlot, uint256 UintSlot, string memory Memo, SimpleProposalTypes SimpleType, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 Identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        //All simple proposals must have a slotted address for sending or action, but may be 0 in certain cases such as burn events
        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
        if(SimpleType == SimpleProposalTypes(2)){
            require(UintSlot > 0 && UintSlot <= 255 && UintSlot <= );
            ProxyProposalArguments storage ProxyArgsWithSlot = EmptyProxy;
            ProxyArgsWithSlot.UnsignedInt1 = UintSlot;
            Proposals[NewIdentifier] = Proposal(NewIdentifier, AddressSlot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(0), SimpleType, VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArgsWithSlot, false, msg.sender);
        } 
        else{
        Proposals[NewIdentifier] = Proposal(NewIdentifier, AddressSlot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(0), SimpleType, VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, EmptyProxy, false, msg.sender);
        }

        return(NewIdentifier);

    }

    function InitializeProxyProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArgs) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ProxyProposals must have a slotted contract");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
        Proposals[NewIdentifier] = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(1), SimpleProposalTypes(0), VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArgs, false, msg.sender);

        return(NewIdentifier);

    }

    function InitializeErosProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ErosProposals must have a slotted contract");

        uint256 NewIdentifier = MRIdentifier++;
        MRIdentifier++;

        uint256 VotingInstanceID = Voting(VotingContract).InitializeVoteInstance(NewIdentifier, VotingLength, false);
        Proposals[NewIdentifier] = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(2), SimpleProposalTypes(0), VotingInstanceID, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, EmptyProxy, false, msg.sender);

        return(NewIdentifier);

    }

    //  Execution Functions

    //  External Simple Proposal Call Functions

        // AssetSend
    function SendAssets(uint256 ProposalID) internal returns(bool success){


    }
    
        // AssetRegister
    function RegisterTreasuryAsset(uint256 ProposalID) internal returns(bool success){

        address TokenAddress = Proposals[ProposalID].AddressSlot;
        uint8 Slot = uint8(Proposals[ProposalID].ProxyArgs.UnsignedInt1); 
        Treasury(TreasuryContract).RegisterAsset(TokenAddress, Slot);

        return(success);
    }

        // TreasuryChange
    function ReplaceTreasury(address NewTreasury) internal returns(bool success){

        Replacements(NewTreasury).SendPreviousTreasury(TreasuryContract);
        TreasuryContract = NewTreasury;

        return(success);
    }
    
        // VotingChange
    function ReplaceVoting(address NewVoting) internal returns(bool success){
        
        Replacements(NewVoting).SendPreviousVoting(VotingContract);
        VotingContract = NewVoting;

        return(success);
    }

        // CoreReplacement
    function ReplaceCore(address NewCore) internal returns(bool success){
        ActiveContract = false;

        Replacements(NewCore).InheritCore(TreasuryContract, VotingContract, MRIdentifier, ProposalCost);

        return(success);
    }
        // AddSecurityCommiteeMember
        // RemoveSecurityCommiteeMember


    // Other Internals

    function ReceiveProposalCost() internal returns(bool success){

        ERC20(CLDAddress()).transferFrom(msg.sender, TreasuryContract, (ProposalCost / 2));

        ERC20(CLDAddress()).transferFrom(msg.sender, address(this), (ProposalCost / 2));
        ERC20(CLDAddress()).Burn(ERC20(CLDAddress()).balanceOf(address(this)));

        return(success);

    }
    
    //One Time Functions
    function SetInitialContracts(address TreasuryAddress, address VotingAddress) external{

        require(msg.sender == InitialSetter);
        require(InitialContractsSet == false);

        TreasuryContract = TreasuryAddress;
        VotingContract = VotingAddress;
        InitialSetter = address(0); //Once the reasury address has been set for the first time, it can only be set again via proposal 
        InitialContractsSet = true;
        ActiveContract = true;

        emit NewTreasurySet(TreasuryAddress);
        
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
    function SendPreviousVoting(address OldVoting) external returns(bool success);
    function SendPreviousTreasury(address OldTreasury) external returns(bool success);

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
}