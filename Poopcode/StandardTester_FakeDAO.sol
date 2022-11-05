//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

//Just a testing contract, nothing to see here!
contract FakeDAO{
    address public owner; // temporary owner, for tests only
    address public votingSystem;
    address public treasury;
    address public auctionFactory;
    uint256 public ProposalsID;

     //Mapping, structs and other declarations
    
    Proposal[] public Proposals;

    struct Proposal{
        uint256 ProposalID;
        uint8 ProposalType; //Type 0 is simple ether and asset sends, Type 1 are Proxy Proposals for external governance, Type 2 are Eros Prosposals
        uint256 RequestedEtherAmount; //Optional, can be zero
        uint256 RequestedAssetAmount; //Optional, can be zero
        uint8 RequestedAssetID;
        //proxy proposal entries here
        bool Executed; //Can only be executed once, when finished, proposal exist only as archive
    }

    mapping(address => bool) public ApprovedErosProposals;

    modifier OnlyOwner{
        require(msg.sender == owner);
        _;
    }

    
    modifier OnlyVoting{
        require(msg.sender == votingSystem);
        _;
    }

    constructor(){
        owner = msg.sender;
    }
    // Eros related fuctions
    function ApproveErosContract(address _Proposal) external OnlyOwner{
        ApprovedErosProposals[_Proposal] = true;
    }

    function ExecuteErosProposal(address _Proposal) external OnlyOwner{
        require(ApprovedErosProposals[_Proposal] == true, "Eros External Proposal Contract not approved");

        EROSEXT(_Proposal).Execute();
    }

    function CheckErosApproval(address _Proposal) external view returns(bool){
        return(ApprovedErosProposals[_Proposal]);
    }

    // FakeDAO admin functions

    function SetVotingAddress(address payable NewAddr) external OnlyOwner {
        votingSystem = NewAddr;
    }

    function SetTreasury(address NewTreasuryAddr) external OnlyOwner{
        treasury = NewTreasuryAddr;
    }
    // to do this
    function CreateNewProposal(uint8 Type, uint8 ReqAssetID, uint256 AmountToSend, uint256 Time ) external {
        ProposalsID++;

        Proposals.push(
            Proposal({
                ProposalID: ProposalsID,
                ProposalType: Type,
                RequestedEtherAmount: AmountToSend,
                RequestedAssetAmount: AmountToSend,
                RequestedAssetID: ReqAssetID,
                Executed: false
            })
        );
        NewProposal(ProposalsID, Time);
    }
    // to do Maybe this should have another name
    function ExecuteCoreProposal(uint256 ProposalID, bool Passed) external OnlyVoting returns (bool) {
        Proposals[ProposalID].Executed = true;

        // to do emit condition based test event
        return Passed;
    }

    // Voting related functions
    function NewVotingTax(uint256 amount, string calldata taxToSet) external OnlyOwner {
        VotingSystem(votingSystem).SetTaxAmount(amount, taxToSet);
    }

    function NewDAOInVoting(address payable NewAddr) external OnlyOwner {
        VotingSystem(votingSystem).ChangeDAO(NewAddr);
    }

    function NewProposal(uint256 ProposalID, uint256 Time) internal {
        // We need to ask for some gas to avoid spamming
        // Also: verify the proposer holds enough CLD

        // TO DO handle proposal via internal function??
        // TO DO this should push new proposals to a struct
        VotingSystem(votingSystem).CreateProposal(msg.sender, ProposalID, Time);
    }

    // Treasury related functions
    function RegisterTreasuryAsset(address tokenAddress, uint8 slot) external OnlyOwner{
        TreasuryV1(treasury).RegisterAsset(tokenAddress, slot);
    }

    function TreasuryEtherTransfer(uint256 amount, address payable receiver) external OnlyOwner{
        TreasuryV1(treasury).TransferETH(amount, receiver);
    }

    function TreasuryERC20Transfer(uint8 AssetID, uint256 amount, address payable receiver) external OnlyOwner{
        TreasuryV1(treasury).TransferERC20(AssetID, amount, receiver);
    }

    function NewTreasuryAssetLimit(uint8 NewLimit) external OnlyOwner{
        TreasuryV1(treasury).ChangeRegisteredAssetLimit(NewLimit);
    }

    function NewDAOInTreasury(address payable NewDAO) external OnlyOwner{
        TreasuryV1(treasury).ChangeDAO(NewDAO);
    }

    // Auction related contracts
    function SetAuctionFactory(address NewAucFactory) external OnlyOwner{
        auctionFactory = NewAucFactory;
    }

    function NewTokenAuction(
        uint256 _EndTime, 
        uint256 _Amount, 
        uint256 _MinimunFeeInGwei, 
        uint256 _RetireeFeeInBP, 
        address payable[] memory _DevTeam
    ) external OnlyOwner{
        AuctionFactory(auctionFactory).newCLDAuction(
            _EndTime,
            _Amount,
            _MinimunFeeInGwei,
            _RetireeFeeInBP,
            _DevTeam
        );
    }

    function AddAucInstanceDevAddress(address AuctInstance, address payable NewDevAddr) external OnlyOwner{
        AuctionInstance(AuctInstance).AddDev(NewDevAddr);
    }

    function AddAucInstanceDevAddresses(
        address AuctInstance, 
        address payable[] memory NewDevAddrs
        ) 
        external 
        OnlyOwner
    {
            AuctionInstance(AuctInstance).AddDevs(NewDevAddrs);
    }
}

interface EROSEXT {
    function Execute() external;
}

interface VotingSystem {
    function CreateProposal(address Proposer, uint256 ProposalID, uint Time) external;      
    function SetTaxAmount(uint amount, string memory taxToSet) external;      
    function ChangeDAO(address NewAddr) external;      
}

interface TreasuryV1 {
    function RegisterAsset(address tokenAddress, uint8 slot) external;
    function ChangeRegisteredAssetLimit(uint8 NewLimit) external;
    function TransferETH(uint256 amount, address payable receiver) external;
    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external;
    function ChangeDAO(address payable NewAddr) external;
}

interface AuctionFactory {
    function newCLDAuction(
        uint256 _EndTime, 
        uint256 _Amount, 
        uint256 _MinimunFeeInGwei, 
        uint256 _RetireeFeeInBP, 
        address payable[] memory _DevTeam
    )
    external;
}

interface AuctionInstance {
    function AddDev(address payable DevAddr) external;
    function AddDevs(address payable[] memory DevAddrs) external;
}