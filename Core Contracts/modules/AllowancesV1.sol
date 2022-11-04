//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

// TO DO OnlyDAO modifiers and functions
contract HarmoniaDAO_Allowances {
    address public DAO;
    address public CLD;
    uint128 public LastGrantID;

    struct Grant {
        bool IsActive;
        address payable[] Requestor;
        uint256 GrantID;
        bool IsItEther;
        uint256 OriginalValue;
        uint256 RemainingValue;
        uint8 AssetID;
        uint8 Installments;
        uint256 TimeBetweenInstallments;
        uint256 LastReclameTimestamp;
    }

    // GrantList[IDs] given to Requestor mapped address 
    mapping(address => uint256[]) public RequestorGrantList;
    // Grant given to Requestor address mapping
    Grant[] public GrantList;

    //Modifier declarations
    modifier OnlyDAO{ 
        require(msg.sender == DAO, 'This can only be done by the DAO');
        _;
    }

    modifier OnlyEros{
        require(msg.sender == DAO  || EROSDAO(DAO).CheckErosApproval(msg.sender), "The caller is either not the DAO or not approved by the DAO");
        _;
    }

        //Code executed on deployment
    constructor(address DAOcontract, address CLDcontract){
        DAO = DAOcontract;
        CLD = CLDcontract;
    }

    
    function RegisterAllowance(
        // TO DO make this an array, as teams can reclaim their grants with different addressess
        address payable[] memory _Requestor, 
        bool _IsItEther,
        uint256 _Value, 
        uint8 _AssetID, 
        uint8 _Installments, 
        uint128 _TimeBI
    ) public OnlyDAO {
    // Add this Grant to Requestor GrantList
        LastGrantID++;
        uint8 CurrentID = 0;
        while(CurrentID <= RegisteredAssetLimit) {  
            RequestorGrantList[_Requestor[CurrentID]].push(LastGrantID);
        }      
    // Grant given to Requestor address mapping
        GrantList.push(
            Grant({
                IsActive: true,
                Requestor: _Requestor,
                GrantID: LastGrantID,
                IsItEther: _IsItEther,
                OriginalValue: _Value,
                RemainingValue: _Value,
                AssetID: _AssetID,
                Installments: _Installments,
                TimeBetweenInstallments: _TimeBI,
                LastReclameTimestamp: block.timestamp
            })
        );

    // TO DO emit event

    }

    function PauseAllowance(uint256 AllowanceID) external OnlyDAO {
        require(AllowanceID != 0,
            'PauseAllowance: Allowance ID 0 cannot be paused');
        GrantList[AllowanceID].IsActive = false;

        // TO DO emit event
    }

    function ForgiveAllowanceDebt(uint256 AllowanceID) external OnlyDAO {
        // TO DO all of this
        // TO DO emit event
    }

    function ReclameAllowance(uint256 AllowanceID, uint8 RequestorID) external {
        require(GrantList[AllowanceID].IsActive,
            'ReclameAllowance: This grant is not active');
        require(payable(msg.sender) == GrantList[AllowanceID].Requestor[RequestorID], 
            'ReclameAllowance: You are not the owner of this grant');
        require(GrantList[AllowanceID].RemainingValue >= 0, 
            'ReclameAllowance: Debt is zero');
        require(GrantList[AllowanceID].LastReclameTimestamp >= block.timestamp,
            'ReclameAllowance: Not enough time has passed since last withdraw');
        uint256 ToSend = GrantList[AllowanceID].OriginalValue / GrantList[AllowanceID].Installments;
        if (GrantList[AllowanceID].IsItEther) {
            // TO DO we need a EtherBalance globally so the grants wont drain the Treasury's balance
            _TransferETH(ToSend, GrantList[AllowanceID].Requestor[RequestorID]);
        } else {
            _TransferERC20(GrantList[AllowanceID].AssetID, ToSend, GrantList[AllowanceID].Requestor[RequestorID]);
        }
        GrantList[AllowanceID].RemainingValue -= ToSend;
        GrantList[AllowanceID].LastReclameTimestamp = block.timestamp;
        // To do emit event

    }

}