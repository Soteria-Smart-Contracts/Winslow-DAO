//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAOTreasury{
    string public Version = "V1";
    address public DAO;
    uint256 public RegisteredAssetLimit;
    Token public CLD;
    Token[] public RegisteredAssets;

    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract 
        require(msg.sender == DAO);
        _;
    }

    //Events

    //Events

    struct Token{
        address TokenAddress;
        uint256 DAObalance;
    }

    constructor(address DAOcontract, address CLDcontract){
        DAO = DAOcontract;
        CLD = Token(CLDcontract, 0);
        RegisteredAssetLimit = 5;
        RegisteredAssets.push(CLD);
    }

    function ChangeRegisteredAssetLimit(uint amount) internal{
        RegisteredAssetLimit = amount;
        // TO DO NewAssetLimit event

    }

    function ReceiveRegisteredAsset(address from, uint AssetId, uint amount) internal {
        ERC20(RegisteredAssets[AssetId].TokenAddress).transferFrom(from, address(this), amount);
        UpdateERC20Balance(AssetId);
        // TO DO assetreceived event
    }

    function AddToken(address tokenAddress, uint256 amount) external OnlyDAO {
        checkForDuplicate(tokenAddress);
        if (amount > 0) {
            ERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
            Token(tokenAddress, amount);
        } else {
        Token(tokenAddress, amount);
        }

        // TO DO addtoken event
    }

    function UpdateERC20Balance(uint256 AssetID) internal {
        RegisteredAssets[AssetID].DAObalance = ERC20(RegisteredAssets[AssetID].TokenAddress).balanceOf(address(this));
    }

    function checkForDuplicate(address _Token) internal view {
        uint256 length = RegisteredAssets.length;
        for (uint256 _pid = 0; _pid < length; _pid++) {
            require(RegisteredAssets[_pid].TokenAddress != _Token, "AddToken: This asset is already registered!");
        }

    }






    function TransferETH(uint256 amount, address payable receiver) public OnlyDAO{
        // TO DO verify how to use this to send data to a contract
        //(bool sent, bytes memory data) = receiver.call{gas :10000, value: msg.value}("func_signature(uint256 args)");
        bool sent = receiver.send(amount);
        require(sent, "TransferETH: Ether not sent!");
    }


    receive() external payable{
    }

    fallback() external payable{
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