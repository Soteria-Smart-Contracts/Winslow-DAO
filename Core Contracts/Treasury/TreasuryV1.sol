//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract HarmoniaDAO_V1_Treasury{
    address public DAO;
    uint256 public RegisteredAssetLimit = 5;
    Token public CLD;
    Token[] public RegisteredAssets;

    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract 
        require(msg.sender == DAO);
        _;
    }

    //Events

    //Events

    struct Token{
        uint16 AssetID;
        address TokenAddress;
        uint256 DAObalance;
    }

    constructor(address DAOcontract, address CLDcontract){
        DAO = DAOcontract;
        CLD = Token(0, CLDcontract, 0);
        RegisteredAssets.push(CLD);
    }

    function UpdateERC20Balance(uint256 AssetID) internal {
        RegisteredAssets[AssetID].DAObalance = ERC20(RegisteredAssets[AssetID].TokenAddress).balanceOf(address(this));
    }











    function TransferETH(uint256 amount, address receiver) public OnlyDAO{
        
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