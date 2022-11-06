//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAO_Allowances {
    address public DAO;
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
    // Grant given to Requestor address mapping
    Grant[] public grantList;

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
    event AllowanceForgiven(uint256 AllowanceID);
    event AllowanceReclamed(uint256 AllowanceID, address Receiver, uint256 RemainingValue);

    //Code executed on deployment
    constructor(address DAOcontract) {
        DAO = DAOcontract;
    }

    receive() external payable{
        emit EtherReceived(msg.value, msg.sender);
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
 
        grantList.push(
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
        require(grantList[AllowanceID].IsActive = false,
            'failed');
        grantList[AllowanceID].IsActive = false;

        emit AllowancePaused(AllowanceID);
    }

    function UnpauseAllowance(uint256 AllowanceID) external OnlyDAO {
        //require(AllowanceID != 0,
        //    'UnpauseAllowance: Allowance ID 0 cannot be paused');
        require(grantList[AllowanceID].IsActive == false,
            'UnpauseAllowance: Allowance must be paused');
        grantList[AllowanceID].IsActive = true;

        emit AllowanceUnpaused(AllowanceID);
    }

    function ForgiveAllowanceDebt(uint256 AllowanceID) external OnlyDAO {
        grantList[AllowanceID].RemainingValue = 0;

        emit AllowanceForgiven(AllowanceID);
    }

    function ReclameAllowance(uint256 AllowanceID) external {
        require(grantList[AllowanceID].IsActive,
            'ReclameAllowance: This grant is not active');
        require(payable(msg.sender) == grantList[AllowanceID].Requestor, 
            'ReclameAllowance: You are not the owner of this grant');
        require(grantList[AllowanceID].RemainingValue >= 0, 
            'ReclameAllowance: Debt is zero');
        require(block.timestamp >= grantList[AllowanceID].LastReclameTimestamp + 
            grantList[AllowanceID].TimeBetweenInstallments,
                'ReclameAllowance: Not enough time has passed since last withdraw');
        uint256 ToSend = grantList[AllowanceID].OriginalValue / grantList[AllowanceID].Installments;
        
        if (grantList[AllowanceID].IsItEther) {
            require(ToSend <= address(this).balance,
                'ReclameAllowance: Not enough value in this contract for that');
            _TransferETH(ToSend, grantList[AllowanceID].Requestor);
        } else {
            require(ToSend <= ERC20(grantList[AllowanceID].AssetAddress).balanceOf(address(this)),
                'ReclameAllowance: Not enough value in this contract for that');
            _TransferERC20(grantList[AllowanceID].AssetAddress, ToSend, grantList[AllowanceID].Requestor);
        }
        grantList[AllowanceID].RemainingValue -= ToSend;
        grantList[AllowanceID].LastReclameTimestamp = block.timestamp;
        
        emit AllowanceReclamed(AllowanceID, msg.sender, grantList[AllowanceID].RemainingValue);
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