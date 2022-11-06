//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

//Just a testing contract, nothing to see here!
contract FakeDAO{
    address public owner;
    address public treasury;
    address public auctionFactory;

    mapping(address => bool) public ApprovedErosProposals;

    modifier OnlyOwner{
        require(msg.sender == owner);
        _;
    }

    constructor(){
        owner = msg.sender;
    }
    // Eros related fuctions
    function ApproveErosContract(address Proposal) external OnlyOwner{
        ApprovedErosProposals[Proposal] = true;
    }

    function ExecuteErosProposal(address Proposal) external OnlyOwner{
        require(ApprovedErosProposals[Proposal] == true, "Eros External Proposal Contract not approved");

        EROSEXT(Proposal).Execute();
    }

    function CheckErosApproval(address Proposal) external view returns(bool){
        return(ApprovedErosProposals[Proposal]);
    }

    // Treasury related functions
    function SetTreasury(address NewTreasury) external OnlyOwner{
        treasury = NewTreasury;
    }

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

    function RemAucInstanceDevAddress(address AuctInstance, address payable NewDevAddr) external OnlyOwner{
        AuctionInstance(AuctInstance).RemDev(NewDevAddr);
    }

    function RemAucInstanceDevAddresses(
        address AuctInstance, 
        address payable[] memory NewDevAddrs
        ) 
        external 
        OnlyOwner
    {
            AuctionInstance(AuctInstance).RemDevs(NewDevAddrs);
    }
}

interface EROSEXT {
    function Execute() external;
}

interface TreasuryV1 {
    function RegisterAsset(address tokenAddress, uint8 slot) external;
    function ChangeRegisteredAssetLimit(uint8 NewLimit) external;
    function TransferETH(uint256 amount, address payable receiver) external;
    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external;
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
    function RemDev(address payable DevAddr) external;
    function RemDevs(address payable[] memory DevAddrs) external;
}