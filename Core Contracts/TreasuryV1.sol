//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAOTreasury{
    //Variable, struct and type declarations
    string public Version = "V1";
    address public DAO;
    uint256 public RegisteredAssetLimit;
    Token public CLD;
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
    event ERC20Sent(uint256 Amount, address Receive, address TxOrigin);


    //Code executed on deployment
    constructor(address DAOcontract, address CLDcontract){
        DAO = DAOcontract;
        CLD = Token(CLDcontract, 0);
        RegisteredAssetLimit = 5;
        RegisteredAssets.push(CLD);
    }

    //Public callable functions
    function ReceiveRegisteredAsset(uint8 AssetID, uint amount) external {
        ERC20(RegisteredAssets[AssetID].TokenAddress).transferFrom(msg.sender, address(this), amount);
        uint256 NewBalance = UpdateERC20Balance(AssetID);
       
        emit ERC20BalanceUpdate(NewBalance, AssetID, tx.origin);
    }
 
    //CLD Claim
    function ClaimAssets(uint256 CLDamount) public returns(bool success){
        ERC20(CLD)
    }

    //DAO and Eros Proposal only access functions
    function TransferETH(uint256 amount, address payable receiver) external OnlyEros{
       receiver.transfer(amount);

       emit EtherSent(amount, receiver, tx.origin);
    }

    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external OnlyEros{
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