//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAO_Allowances {
    address public DAO;
    address public CLD;
    uint128 public LastGrantID = 0;

    struct Grant {
        bool IsActive;
        address payable[] Requestor;
        uint256 GrantID;
        bool IsItEther;
        uint256 OriginalValue;
        uint256 RemainingValue;
        address AssetAddress;
        uint8 Installments;
        uint256 TimeBetweenInstallments;
        uint256 LastReclameTimestamp;
    }

    // Requestors in a specific Grant  
    mapping(uint256 => address[]) public RequestorsInGrant;
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
    constructor(address DAOcontract){
        DAO = DAOcontract;
    }

    // TO DO The DAO needs to send the tokens for this grant
    function RegisterAllowance(
        address payable[] memory _RequestorList, 
        bool _IsItEther,
        uint256 _Value, 
        address _AssetAddress, 
        uint8 _Installments, 
        uint128 _TimeBI  // In seconds
    ) public OnlyDAO {
    // Add these Requestor Grant to Requestor GrantList
        RequestorsInGrant[LastGrantID] = _RequestorList;
 
        GrantList.push(
            Grant({
                IsActive: true,
                Requestor: _RequestorList,
                GrantID: LastGrantID,
                IsItEther: _IsItEther,
                OriginalValue: _Value,
                RemainingValue: _Value,
                AssetAddress: _AssetAddress,
                Installments: _Installments,
                TimeBetweenInstallments: _TimeBI,
                LastReclameTimestamp: block.timestamp
            })
        );
        LastGrantID++;

    // TO DO emit event

    }

    function PauseAllowance(uint256 AllowanceID) external OnlyDAO {
        require(AllowanceID != 0,
            'PauseAllowance: Allowance ID 0 cannot be paused');
        require(GrantList[AllowanceID].IsActive = true,
            'UnpauseAllowance: Allowance must be unpaused');
        GrantList[AllowanceID].IsActive = false;

        // TO DO emit event
    }

    function UnpauseAllowance(uint256 AllowanceID) external OnlyDAO {
        require(AllowanceID != 0,
            'UnpauseAllowance: Allowance ID 0 cannot be paused');
        require(GrantList[AllowanceID].IsActive = false,
            'UnpauseAllowance: Allowance must be paused');
        GrantList[AllowanceID].IsActive = true;

        // TO DO emit event
    }

    function ForgiveAllowanceDebt(uint256 AllowanceID) external OnlyDAO {
        GrantList[AllowanceID].RemainingValue = 0;
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
            require(ToSend <= address(this).balance,
                'ReclameAllowance: Not enough value in this contract for that');
            _TransferETH(ToSend, GrantList[AllowanceID].Requestor[RequestorID]);
        } else {
            require(ToSend <= ERC20(GrantList[AllowanceID].AssetAddress).balanceOf(address(this)),
                'ReclameAllowance: Not enough value in this contract for that');
            _TransferERC20(GrantList[AllowanceID].AssetAddress, ToSend, GrantList[AllowanceID].Requestor[RequestorID]);
        }
        GrantList[AllowanceID].RemainingValue -= ToSend;
        GrantList[AllowanceID].LastReclameTimestamp = block.timestamp;
        // To do emit event

    }

    function _TransferETH(uint256 amount, address payable receiver) internal { 
        receiver.transfer(amount);
    }

    function _TransferERC20(address _AssetAddress, uint256 amount, address receiver) internal { 
        ERC20(_AssetAddress).transfer(receiver, amount);
    }
}

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
} 

interface EROSDAO{
    function CheckErosApproval(address) external view returns(bool);
}