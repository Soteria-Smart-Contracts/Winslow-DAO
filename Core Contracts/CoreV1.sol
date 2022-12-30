//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract Winslow_Core_V1{
    //Variable Declarations
    string public Version = "V1";
    address public Treasury = address(0);
    address public TreasurySetter;
    bool public InitialTreasurySet = false;
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
        TreasuryChange,
        VotingChange
    }

    struct Proposal{
        uint256 ProposalID;
        address AddressSlot;            //To set an address either as a receiver, ProxyReceiver for approval of Eros proposal contract
        string Memo;                    //Short description of what the proposal is and does (Reduce length for gas efficiency)
        ProposalStatus Status;          //Types declared in enum
        SecurityStatus SecurityLevel;   //Types declared in enum
        ProposalTypes ProposalType;     //Types declared in enum
        SimpleProposalTypes SimpleType; //Types declared in enum
        uint256 ProposalVotingLenght;   //Minimum 24 hours
        uint256 RequestedEtherAmount;   //Optional, can be zero
        uint256 RequestedAssetAmount;   //Optional, can be zero
        uint8 RequestedAssetID;         //Treasury asset identifier for proposals moving funds
        ProxyProposalArguments ProxyArgs; //List of arguments that can be used for proxy proposals, Also used for other data storage for simple proposals
        bool Executed;                  //Can only be executed once, when finished, proposal exist only as archive
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
        TreasurySetter = msg.sender;
        EmptyProxy = ProxyProposalArguments(0 ,0 ,0 ,address(0) ,address(0), address(0), false, false, false);
        //Special proposal in index 0
    }

    //Public state-modifing functions

    function SubmitSimpleProposal(address Slot, SimpleProposalTypes SimpleType, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success, uint256 Identifier){

        uint256 NewIdentifier = MRIdentifier++;
        InitializeSimpleProposal(NewIdentifier, Slot, Memo, SimpleType, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID);


        return(true, NewIdentifier);

    }

    function SubmitProxyProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArgs) public returns(bool success, uint256 Identifier) {

        uint256 NewIdentifier = MRIdentifier++;
        InitializeProxyProposal(NewIdentifier, Slot, Memo, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArgs);

        
        return(true, NewIdentifier);

    }


    function SubmitErosProposal(address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) public returns(bool success, uint256 Identifier){

        uint256 NewIdentifier = MRIdentifier++;
        InitializeErosProposal(NewIdentifier, Slot, Memo, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID);
        
        return(true, NewIdentifier);

    }

    //  Public view functions


    //  Internal Functions

    function InitializeSimpleProposal(uint256 NewIdentifier, address Slot, string memory Memo, SimpleProposalTypes SimpleType, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 Identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        //All simple proposals must have a slotted address for sending or action, but may be 0 in certain cases such as burn events

        Proposal memory NewProposal = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(0), SimpleType, VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, EmptyProxy, false);
        Proposals.push(NewProposal);

        return(NewIdentifier);

    }

    function InitializeProxyProposal(uint256 NewIdentifier, address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID, ProxyProposalArguments memory ProxyArgs) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ProxyProposals must be a contract");

        Proposal memory NewProposal = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(1), SimpleProposalTypes(0), VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, ProxyArgs, false);
        Proposals.push(NewProposal);

        return(NewIdentifier);

    }

    function InitializeErosProposal(uint256 NewIdentifier, address Slot, string memory Memo, uint256 VotingLength, uint256 RequestedEther, uint256 RequestedAssetAmount, uint8 RequestedAssetID) internal returns(uint256 identifier){

        require(VotingLength >= 86400 && VotingLength <= 1209600, "Voting must be atleast 24 hours and less than two weeks");
        require(Slot != address(0), "ErosProposals must be a contract");

        Proposal memory NewProposal = Proposal(NewIdentifier, Slot, Memo, ProposalStatus(0), SecurityStatus(0), ProposalTypes(2), SimpleProposalTypes(0), VotingLength, RequestedEther, RequestedAssetAmount, RequestedAssetID, EmptyProxy, false);
        Proposals.push(NewProposal);

        return(NewIdentifier);

    }

    //  External Simple Proposal Call Functions

    //    function RegisterTreasuryAsset(address tokenAddress, uint8 slot, uint256 ProposalID) internal returns(bool success){

    //        TreasuryV1(Treasury).RegisterAsset(tokenAddress, slot);
    //    }
    
    //One Time Functions
    function SetInitialTreasury(address TreasuryAddress) external{

        require(msg.sender == TreasurySetter);
        require(InitialTreasurySet == false);

        Treasury = TreasuryAddress;
        TreasurySetter = address(0); //Once the reasury address has been set for the first time, it can only be set again via proposal 
        InitialTreasurySet = true;

        emit NewTreasurySet(TreasuryAddress);
        
    }

    receive() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(Treasury).transfer(address(this).balance);
    }

    fallback() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(Treasury).transfer(address(this).balance);
    }
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

interface EROS{
    function DAO() external view returns(address DAOaddress);
}