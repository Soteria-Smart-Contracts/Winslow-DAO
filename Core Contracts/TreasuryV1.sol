//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAOTreasury{
    //Variable, struct and type declarations
    string public Version = "V1";
    address public DAO;
    uint8 public RegisteredAssetLimit;
    uint128 public LastGrantID;

    mapping(address => bool) public AssetRegistryMap;
    mapping(uint8 => Token) public RegisteredAssets;

    struct Token{ 
        address TokenAddress;
        bool Filled;
    }

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


    //Event Declarations
    event AssetRegistered(address NewToken, uint256 CurrentBalance);
    event AssetLimitChange(uint256 NewLimit);
    event EtherReceived(uint256 Amount, address Sender, address TxOrigin);
    event EtherSent(uint256 Amount, address Receiver, address TxOrigin);
    event ERC20Sent(uint256 Amount, address Receiver, address TxOrigin);
    event AssetsClaimedWithCLD(uint256 CLDin, uint256 EtherOut, address From, address OutTo, address TxOrigin);


    //Code executed on deployment
    constructor(address DAOcontract, address CLDcontract){
        DAO = DAOcontract;
        RegisteredAssetLimit = 5;
        RegisteredAssets[0] = (Token(CLDcontract, true));
        AssetRegistryMap[CLDcontract] = true;
    }

    //Public callable functions
    function ReceiveRegisteredAsset(uint8 AssetID, uint amount) external {
        ERC20(RegisteredAssets[AssetID].TokenAddress).transferFrom(msg.sender, address(this), amount);
    }

 
    //CLD Claim
    function UserAssetClaim(uint256 CLDamount) public returns(bool success){
        AssetClaim(CLDamount, msg.sender, payable(msg.sender));

        return(success);
    }

    function AssetClaim(uint256 CLDamount, address From, address payable To) public returns(bool success){
        uint256 SupplyPreTransfer = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - ERC20(RegisteredAssets[0].TokenAddress).balanceOf(address(this)));
        //Supply within the DAO does not count as backed
        ERC20(RegisteredAssets[0].TokenAddress).transferFrom(From, address(this), CLDamount);

        uint8 CurrentID = 1;
        while(CurrentID <= RegisteredAssetLimit){
            //It is very important that ERC20 contracts are audited properly to ensure that no errors could occur here, as one failed transfer would revert the whole TX
            if(RegisteredAssets[CurrentID].Filled == true){
                uint256 ToSend = GetAssetToSend(CLDamount, CurrentID, SupplyPreTransfer);
                ERC20(RegisteredAssets[CurrentID].TokenAddress).transfer(To, ToSend);
                emit ERC20Sent(ToSend, To, tx.origin);
            }
            CurrentID++;
        }

        To.transfer(GetEtherToSend(CLDamount, SupplyPreTransfer));

        return(success);
    }


    //DAO and Eros Proposal only access functions
    function TransferETH(uint256 amount, address payable receiver) external OnlyDAO{ //Only DAO for moving fyi
        _TransferETH(amount, receiver);

        emit EtherSent(amount, receiver, tx.origin);
    }

    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external OnlyDAO{ 
        _TransferERC20(AssetID, amount, receiver);

        emit ERC20Sent(amount, receiver, tx.origin);
    }

    function _TransferETH(uint256 amount, address payable receiver) internal { 
        receiver.transfer(amount);
    }

    function _TransferERC20(uint8 AssetID, uint256 amount, address receiver) internal { 
        ERC20(RegisteredAssets[AssetID].TokenAddress).transfer(receiver, amount);
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

    //Asset Registry management
    function RegisterAsset(address tokenAddress, uint8 slot) external OnlyDAO { 
        require(slot <= RegisteredAssetLimit && slot != 0);
        require(AssetRegistryMap[tokenAddress] == false);
        if(RegisteredAssets[slot].Filled == true){
            //Could be used to prevent tx by sending some amount?
            require(ERC20(RegisteredAssets[slot].TokenAddress).balanceOf(address(this)) == 0);
            AssetRegistryMap[RegisteredAssets[slot].TokenAddress] = false;
        }
        if(tokenAddress == address(0)){
           RegisteredAssets[slot] = Token(address(0), false); 
        }
        else{
        RegisteredAssets[slot] =  Token(tokenAddress, true); 
        AssetRegistryMap[tokenAddress] = true;
        }

        emit AssetRegistered(RegisteredAssets[slot].TokenAddress, ERC20(RegisteredAssets[slot].TokenAddress).balanceOf(address(this)));
    }


    //Setting modification functions
    function ChangeRegisteredAssetLimit(uint8 NewLimit) external OnlyDAO{
        RegisteredAssetLimit = NewLimit;
        
        emit AssetLimitChange(NewLimit);
    }

    //Public viewing functions 
    function IsRegistered(address TokenAddress) public view returns(bool){
        return(AssetRegistryMap[TokenAddress]);
    }


    function GetBackingValueEther(uint256 CLDamount) public view returns(uint256 EtherBacking){
        uint256 DecimalReplacer = (10**10);
        uint256 DAObalance = ERC20(RegisteredAssets[0].TokenAddress).balanceOf(address(this));
        uint256 Supply = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - DAObalance);
        return(((CLDamount * ((address(this).balance * DecimalReplacer) / Supply)) / DecimalReplacer));
    }

    function GetBackingValueAsset(uint256 CLDamount, uint8 AssetID) public view returns(uint256 AssetBacking){
        require(AssetID > 0 && AssetID <= RegisteredAssetLimit && RegisteredAssets[AssetID].Filled == true, "Asset Cannot be CLD or a nonexistant slot");
        uint256 DecimalReplacer = (10**10);
        uint256 DAObalance = ERC20(RegisteredAssets[AssetID].TokenAddress).balanceOf(address(this));
        uint256 Supply = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - ERC20(RegisteredAssets[0].TokenAddress).balanceOf(address(this)));
        return(((CLDamount * ((DAObalance * DecimalReplacer) / Supply)) / DecimalReplacer));
    }

    function GetEtherToSend(uint256 CLDamount, uint256 PreSupply) internal view returns(uint256 EtherBacking){
        uint256 DecimalReplacer = (10**10);
        return(((CLDamount * ((address(this).balance * DecimalReplacer) / PreSupply)) / DecimalReplacer));
    }

    function GetAssetToSend(uint256 CLDamount, uint8 AssetID, uint256 PreSupply) internal view returns(uint256 AssetBacking){
        require(AssetID > 0 && AssetID <= RegisteredAssetLimit && RegisteredAssets[AssetID].Filled == true, "Asset Cannot be CLD or a nonexistant slot");
        uint256 DecimalReplacer = (10**10);
        uint256 DAOAssetBalance = ERC20(RegisteredAssets[AssetID].TokenAddress).balanceOf(address(this));
        return(((CLDamount * ((DAOAssetBalance * DecimalReplacer) / PreSupply)) / DecimalReplacer));
    }

    //Fallback Functions
    receive() external payable{
        emit EtherReceived(msg.value, msg.sender, tx.origin); //Does msg.value work for this?
    }

    fallback() external payable{
        emit EtherReceived(msg.value, msg.sender, tx.origin); //Does msg.value work for this?
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
