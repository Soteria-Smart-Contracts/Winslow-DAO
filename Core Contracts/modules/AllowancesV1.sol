//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAO_Allowances {
    address public DAO;
    address payable public Treasury; // TO DO set treasury
    address public CLD;
    uint128 public LastGrantID = 0;

    struct Grant {
        bool IsActive;
        address payable Requestor;
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
    mapping(uint256 => address) public RequestorsInGrant;
    // Grants array
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

    event EtherReceived(uint256 Value, address Sender);
    event NewAllowance(address payable _Requestor, uint256 LastGrantID, bool IsItEther, uint256 Value, address AssetAddress);
    event AllowancePaused(uint256 AllowanceID);
    event AllowanceUnpaused(uint256 AllowanceID);
    event AllowanceForgiven(uint256 AllowanceID, uint256 Value, bool IsEther, address AssetAddress);
    event AllowanceReclaimed(uint256 AllowanceID, address Receiver, uint256 RemainingValue);

    //Code executed on deployment
    constructor(address DAOcontract, address payable TreasuryAddr) {
        DAO = DAOcontract;
        Treasury = TreasuryAddr;
    }

    receive() external payable{
        emit EtherReceived(msg.value, msg.sender);
    }

    function ChangeDAO(address NewDAO) external OnlyDAO {
        DAO = NewDAO;
    }

    function ChangeTreasury(address payable NewTreasury) external OnlyDAO {
        Treasury = NewTreasury;
    }

    // TO DO The DAO needs to send the tokens for this grant
    function RegisterAllowance(
        address payable _Requestor, 
        bool _IsItEther,
        uint256 _Value, 
        address _AssetAddress, 
        uint8 _Installments, 
        uint128 _TimeBI  // In seconds
    ) public OnlyDAO {
    // Add these Requestor Grant to Requestor GrantList
        RequestorsInGrant[LastGrantID] = _Requestor;
 
        GrantList.push(
            Grant({
                IsActive: true,
                Requestor: _Requestor,
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

        emit NewAllowance(_Requestor, LastGrantID, _IsItEther, _Value, _AssetAddress);

        LastGrantID++;
    }

    function PauseAllowance(uint256 AllowanceID) external OnlyDAO {
        // require(AllowanceID != 0,
        //    'PauseAllowance: Allowance ID 0 cannot be paused');
        require(GrantList[AllowanceID].IsActive == true,
            'PauseAllowance: Allowance must be unpaused');
        GrantList[AllowanceID].IsActive = false;

        emit AllowancePaused(AllowanceID);
    }

    function UnpauseAllowance(uint256 AllowanceID) external OnlyDAO {
        //require(AllowanceID != 0,
        //    'UnpauseAllowance: Allowance ID 0 cannot be paused');
        require(GrantList[AllowanceID].IsActive == false,
            'UnpauseAllowance: Allowance must be paused');
        GrantList[AllowanceID].IsActive = true;

        emit AllowanceUnpaused(AllowanceID);
    }

    function ForgiveAllowanceDebt(uint256 AllowanceID) external OnlyDAO {
        if(GrantList[AllowanceID].IsItEther) {
            _TransferETH(GrantList[AllowanceID].RemainingValue, Treasury);

            emit AllowanceForgiven(
            AllowanceID, 
            GrantList[AllowanceID].RemainingValue, 
            GrantList[AllowanceID].IsItEther,
            address(0)
            );
        } else {
            _TransferERC20(GrantList[AllowanceID].AssetAddress,  
            GrantList[AllowanceID].RemainingValue,
            Treasury);

            emit AllowanceForgiven(
            AllowanceID, 
            GrantList[AllowanceID].RemainingValue, 
            GrantList[AllowanceID].IsItEther,
            GrantList[AllowanceID].AssetAddress
            );
        }

        GrantList[AllowanceID].IsActive = false;
        GrantList[AllowanceID].RemainingValue = 0;

    }

    function ReclameAllowance(uint256 AllowanceID) external {
        require(GrantList[AllowanceID].IsActive,
            'ReclameAllowance: This grant is not active');
        require(payable(msg.sender) == GrantList[AllowanceID].Requestor, 
            'ReclameAllowance: You are not the owner of this grant');
        require(GrantList[AllowanceID].RemainingValue >= 0, 
            'ReclameAllowance: Debt is zero');
        require(block.timestamp >= GrantList[AllowanceID].LastReclameTimestamp + 
            GrantList[AllowanceID].TimeBetweenInstallments,
                'ReclameAllowance: Not enough time has passed since last withdraw');
        uint256 ToSend = GrantList[AllowanceID].OriginalValue / GrantList[AllowanceID].Installments;
        
        if (GrantList[AllowanceID].IsItEther) {
            require(ToSend <= address(this).balance,
                'ReclameAllowance: Not enough ether value in this contract for that');
            _TransferETH(ToSend, GrantList[AllowanceID].Requestor);
        } else {
            require(ToSend <= ERC20(GrantList[AllowanceID].AssetAddress).balanceOf(address(this)),
                'ReclameAllowance: Not enough Token value in this contract for that');
            _TransferERC20(GrantList[AllowanceID].AssetAddress, ToSend, GrantList[AllowanceID].Requestor);
        }
        GrantList[AllowanceID].RemainingValue -= ToSend;
        GrantList[AllowanceID].LastReclameTimestamp = block.timestamp;
        
        emit AllowanceReclaimed(AllowanceID, msg.sender, GrantList[AllowanceID].RemainingValue);
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