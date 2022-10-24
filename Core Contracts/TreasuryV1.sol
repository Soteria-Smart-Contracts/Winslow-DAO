//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAOTreasury{
    //Variable, struct and type declarations
    string public Version = "V1";
    address public DAO;
    uint256 public RegisteredAssetLimit;
    Token[] public RegisteredAssets;

    mapping(address => bool) public AssetRegistryMap;

    struct Token{ 
        address TokenAddress;
        uint256 DAObalance;
    }

    //Modifier declarations
    modifier OnlyDAO{ 
        require(msg.sender == DAO);
        _;
    }

    modifier OnlyEros{
        require(msg.sender == DAO  || EROSDAO(DAO).CheckErosApproval(msg.sender), "The caller is either not the DAO or not approved by the DAO");
        _;
    }

    //How could someone exploit this by using an un-updated erc20 balance?

    //Event Declarations
    event AssetRegistered(address NewToken, uint256 CurrentBalance);
    event AssetLimitChange(uint256 NewLimit);
    event EtherReceived(uint256 Amount, address Sender, address TxOrigin);
    event EtherSent(uint256 Amount, address Receiver, address TxOrigin);
    event ERC20BalanceUpdate(uint256 NewAmount, uint8 AssetID, address TxOrigin);
    event ERC20Sent(uint256 Amount, address Receiver, address TxOrigin);
    event AssetsClaimedWithCLD(uint256 CLDin, uint256 EtherOut, address From, address OutTo, address TxOrigin);


    //Code executed on deployment
    constructor(address DAOcontract, address CLDcontract){
        DAO = DAOcontract;
        RegisteredAssetLimit = 5;
        RegisteredAssets.push(Token(CLDcontract, 0));
    }

    //Public callable functions
    function ReceiveRegisteredAsset(uint8 AssetID, uint amount) external {
        ERC20(RegisteredAssets[AssetID].TokenAddress).transferFrom(msg.sender, address(this), amount);
        uint256 NewBalance = UpdateERC20Balance(AssetID);
       
        emit ERC20BalanceUpdate(NewBalance, AssetID, tx.origin);
    }

 
    //CLD Claim
    function UserAssetClaim(uint256 CLDamount) public returns(bool success){

    }

    function AssetClaim(uint256 CLDamount, address From, address payable To) public returns(bool success){
        uint256 SupplyPreTransfer = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - RegisteredAssets[0].DAObalance); //Supply within the DAO does not count as backed
        require(ERC20(RegisteredAssets[0].TokenAddress).transferFrom(From, address(this), CLDamount), "Unable to transfer CLD to treasury, ensure allowance is given");
        UpdateERC20Balance(0);

        uint8 CurrentID = 1;
        uint256 DecimalReplacer = (10^10);
        while(CurrentID <= RegisteredAssetLimit){ //It is very important that ERC20 contracts are audited properly to ensure that no errors could occur here, as one failed transfer would revert the whole TX
            if(RegisteredAssets[CurrentID].TokenAddress != address(0)){ 
                uint256 AssetBalance = UpdateERC20Balance(CurrentID);
                uint256 ToSend = ((CLDamount * ((AssetBalance * DecimalReplacer) / SupplyPreTransfer)) / DecimalReplacer);
                ERC20(RegisteredAssets[CurrentID].TokenAddress).transfer(To, ToSend);
                emit ERC20Sent(ToSend, To, tx.origin);
                UpdateERC20Balance(CurrentID);
            }
            CurrentID++;
        }

        uint256 EtherToSend = ((CLDamount * ((address(this).balance * DecimalReplacer) / SupplyPreTransfer)) / DecimalReplacer);
        To.transfer(EtherToSend);

        return(success);
    }


    //DAO and Eros Proposal only access functions
    function TransferETH(uint256 amount, address payable receiver) external OnlyDAO{ //Only DAO for moving fyi
        receiver.transfer(amount);

        emit EtherSent(amount, receiver, tx.origin);
    }

    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external OnlyDAO{ //Only DAO for moving fyi
        ERC20(RegisteredAssets[AssetID].TokenAddress).transfer(receiver, amount);
        uint256 NewBalance = UpdateERC20Balance(AssetID);

        emit ERC20BalanceUpdate(NewBalance, AssetID, tx.origin);
    }

    //Asset Registry management
    function RegisterAsset(address tokenAddress, uint256 slot) external OnlyEros { //make callable from eros
        require(slot <= RegisteredAssetLimit && slot != 0);
        require(AssetRegistryMap[tokenAddress] == false);
        require(RegisteredAssets[slot].TokenAddress == address(0) || ERC20(RegisteredAssets[slot].TokenAddress).balanceOf(address(this)) == 0); //How can I check if a slot is populated?
        
        RegisteredAssets[slot] =  Token(tokenAddress, ERC20(tokenAddress).balanceOf(address(this)));
        AssetRegistryMap[tokenAddress] = true;

        emit AssetRegistered(RegisteredAssets[slot].TokenAddress, RegisteredAssets[slot].DAObalance);
    }

    function UpdateERC20Balance(uint256 AssetID) internal returns(uint256 NewBalance){
        RegisteredAssets[AssetID].DAObalance = ERC20(RegisteredAssets[AssetID].TokenAddress).balanceOf(address(this));

        return(RegisteredAssets[AssetID].DAObalance);
    }


    //Setting modification functions
    function ChangeRegisteredAssetLimit(uint NewLimit) external OnlyDAO{
        RegisteredAssetLimit = NewLimit;
        
        emit AssetLimitChange(NewLimit);
    }

    //Public viewing functions 
    function GetBackingValueEther(uint256 CLDamount) public view returns(uint256 EtherBacking){
        uint256 DecimalReplacer = (10 ^ 10);
        uint256 Supply = (ERC20(RegisteredAssets[0].TokenAddress).totalSupply() - RegisteredAssets[0].DAObalance);
        return(((CLDamount * ((address(this).balance * DecimalReplacer) / Supply)) / DecimalReplacer));
    }

    function GetBackingValueAsset(uint256 CLDamount, uint8 AssetID)

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

//I Need a way for proposals within the DAO that change DAO numbers like asset limits to be done withought EROS