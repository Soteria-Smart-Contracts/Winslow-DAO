//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract ErosProposal{
    address public DAO = 0x0000000000000000000000000000000000000000;
    bool public Executed;
    bool public Multi = true; //Must Exist or will be rejected by Core
    uint8 public OptionCount = 5; //Maximum 5
    mapping(uint8 => string) public OptionMemo; //Simplify and reduce lengths for best perfomance and lower gas

    //Fund request/s for the proposal, can only receive one asset per proposal, may receive both ERC20 and Ether
    uint256 public RequestEther = 0 ether; //Optional, can be ommited
    uint256 public RequestTokens = 0; //Optional, can be 0 but must exist to function properly
    uint8 public TokenIdentifier = 0; //Optional, can be 0 but must exist to function properly
    

    //Events
    event ContractExecuted(uint256 time);
    //Events

    //Additional variables can be added here
    address public ExternalContract = 0x0000000000000000000000000000000000000000;
    //Additional variables can be added here

    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract
        require(msg.sender == DAO);
        _;
    }

    constructor(string memory MemoOptionOne, string memory MemoOptionTwo, string memory MemoOptionThree, string memory MemoOptionFour, string memory MemoOptionFive){
        OptionMemo[1] = MemoOptionOne;
        
    }


    function Execute(uint8 OptionToExecute) external OnlyDAO returns(bool success){
        Executed = true; //Updates first to avoid recursive calling
        address TokenAddress = TreasuryV1(HarmoniaDAO(DAO).Treasury()).RegisteredAssets(TokenIdentifier);

        //External or internal code to execute
        if(OptionToExecute == 1){
            ExtCon(ExternalContract).Update("This value was updated by the DAO using the first option!");
        }
        else if(OptionToExecute == 2){
            ExtCon(ExternalContract).Update("This value was updated by the DAO using the second option!");
        }
        else if(OptionToExecute == 3){
            ExtCon(ExternalContract).Update("This value was updated by the DAO using the third option!");
        }
        else if(OptionToExecute == 4){
            ExtCon(ExternalContract).Update("This value was updated by the DAO using the fourth option!");
        }
        else if(OptionToExecute == 5){
            ExtCon(ExternalContract).Update("This value was updated by the DAO using the fifth option!");
        }
        else{
            revert("Option to execute is out of bounds, Eros Proposal Execution failed");
        }
        //External or internal code to execute

        if(address(this).balance > 0){ //Must be the last state changing part of this function
            payable(DAO).transfer(address(this).balance);
        }
        if((TokenAddress != address(0)) && (ERC20(TokenAddress).balanceOf(address(this)) < 0)){
            ERC20(TokenAddress).transfer(DAO, ERC20(TokenAddress).balanceOf(address(this)));
        }
        emit ContractExecuted(block.timestamp);
        return(success);
    }

    //Additional functions can go here that can only be executed by the Execute() function, therefore must be internal, public functions may present vulenrabilities to external contracts

}

interface HarmoniaDAO{
    function Treasury() external view returns(address);
}

//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future, only Eros proposals will be able to access it due to their flexibility
interface TreasuryV1{ //set up checker
//Public State Modifing Functions
    function ReceiveRegisteredAsset(uint8 AssetID, uint amount) external;
    function UserAssetClaim(uint256 CLDamount) external returns(bool success);
    function AssetClaim(uint256 CLDamount, address From, address payable To) external returns(bool success);
//OnlyDAO or OnlyEros State Modifing Functions
    function TransferETH(uint256 amount, address payable receiver) external;
    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external;
    function RegisterAsset(address tokenAddress, uint8 slot) external;
    function ChangeRegisteredAssetLimit(uint8 NewLimit) external;
//Public View Functions
    function IsRegistered(address TokenAddress) external view returns(bool);
    function RegisteredAssets(uint8 AssetID) external view returns(address);
    function GetBackingValueEther(uint256 CLDamount) external view returns(uint256 EtherBacking);
    function GetBackingValueAsset(uint256 CLDamount, uint8 AssetID) external view returns(uint256 AssetBacking);
}

interface ExtCon{ //Interface name can be different, ensure it is updated correctly with the external functions to be used in execution
    function ErosImplemented() external view returns(bool);
    function Update(string calldata) external;
}


interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint value) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
} 