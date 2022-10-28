//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

// TO DO OnlyDAO modifiers and functions
contract CLDDao_Auction {
    address public DAO;
    address payable public Treasury;
    address public CLD;
    uint256 public MinimunFee;
    uint256 public StartTime;
    uint256 public EndTime;
    uint256 public ETCCollected;
    uint256 public TokenAmount;
    uint256 public CurrentTokenBalance;
    /*
    modifier OnlyDAO{
        require(msg.sender == DAO);
        _;
    }
    */
    struct Participant {
        bool Participated;
        address PartAddr;
        uint256 DepositedETC;
        uint256 PooledTokenShare;
    } 

    address[] public ParticipantsList;
    mapping (address => Participant) public participantInfo;
    
    event ETCDeposited(uint256 AmountReceived, address Buyer);
    event ParticipantRetired(uint256 AmountRetired);
    event ETCDWithdrawed(uint256 AmountWithdrawed);
    event CLDWithdrawed(uint256 AmountWithdrawed, address Buyer);
    event UpdatedPooledTokenShare();


    constructor(uint256 _StartTime, uint256 _EndTime, uint256 _Amount, uint256 _FeeInGwei, address _DAO, address _CLD) {
        StartTime = _StartTime;
        EndTime = _EndTime;
        TokenAmount = _Amount;
        MinimunFee= _FeeInGwei;
        DAO = _DAO;
        CLD = _CLD;
    }

    /* TO DO Functions needed:
    * depositETC [Done, needs tests]
    * RetireFromAuction [Done, needs tests]
    * withdrawCLD
    * withdrawETC [Done, needs tests]
    */

    function DepositETC() external payable returns (bool) {
        require(block.timestamp < EndTime, "CLDAuction.DepositETC: The sale is over");
        require(msg.value > MinimunFee, "CLDAuction.DepositETC: Deposit amount not high enough");

        ETCCollected += msg.value;
        if (participantInfo[msg.sender].Participated) {
            participantInfo[msg.sender].DepositedETC += msg.value;
        } else {
            participantInfo[msg.sender].Participated = true;
            participantInfo[msg.sender].PartAddr = msg.sender;
            participantInfo[msg.sender].DepositedETC += msg.value;
            ParticipantsList.push(msg.sender);
        }
        participantInfo[msg.sender].PooledTokenShare = SeeUpdatePooledTokenShare(msg.sender);

        emit ETCDeposited(msg.value, msg.sender);
        return true;
    }

    // We should take a fee for this, DAO decided
    function RetireFromAuction(uint256 amount, address payable receiver) external {
        require(
            amount < participantInfo[msg.sender].DepositedETC, 
            "CLDAuction.RetireFromAuction: You can't withdraw this many ETC"
        );
        require(
            block.timestamp < EndTime, 
            "CLDAuction.RetireFromAuction: The sale is over, you can only withdraw your CLD"
        );
        require(
            receiver == msg.sender, 
            "CLDAuction.RetireFromAuction: You can't withdraw what's not yours"
        );
        participantInfo[receiver].DepositedETC -= amount;
        if (participantInfo[receiver].DepositedETC == 0) {
            participantInfo[receiver].Participated = false;
            participantInfo[receiver].PooledTokenShare = 0;
        }
        receiver.transfer(amount);

        emit ParticipantRetired(amount);
    }

    //TO DO OnlyDAO
    function WithdrawETC() public returns (bool) {
        require(block.timestamp > EndTime, "CLDAuction.WithdrawETC: The sale is not over yet");

        uint256 _ETCAmount = address(this).balance;
        Treasury.transfer(_ETCAmount);

        emit ETCDWithdrawed(_ETCAmount);
        return true;
    }

    function WithdrawCLD(address PartAddr) public {
        require(block.timestamp > EndTime, "CLDAuction.WithdrawCLD: The sale is not over yet");
        require(participantInfo[msg.sender].DepositedETC > 0, "CLDAuction.WithdrawCLD: You didn't buy any CLD");
        require(
            msg.sender == participantInfo[PartAddr].PartAddr, 
            "CLDAuction.WithdrawETC: You can't withdraw what's not yours"
        );
        participantInfo[PartAddr].PooledTokenShare = SeeUpdatePooledTokenShare(PartAddr);
        uint256 CLDToSend = (TokenAmount * participantInfo[PartAddr].PooledTokenShare) / 10000;
        participantInfo[PartAddr].DepositedETC = 0;
        //TokenAmount -= CLDToSend;
        ERC20(CLD).transfer(PartAddr, CLDToSend);
        emit CLDWithdrawed(CLDToSend, PartAddr);
    }

    function CheckParticipant(address PartAddr) public view returns (uint256, uint256) {
        return (
            participantInfo[PartAddr].DepositedETC, 
            participantInfo[PartAddr].PooledTokenShare
        );
    }

    function SeeUpdatePooledTokenShare(address PartAddr) public view returns (uint256) {
        uint256 _TokenShare = (( participantInfo[PartAddr].DepositedETC * 10000) / address(this).balance) ;
        return _TokenShare;
    }

    function MassUpdatePooledTokenShare() public {
        for (uint256 id = 0; id < ParticipantsList.length; ++id) {
            participantInfo[ParticipantsList[id]].PooledTokenShare = SeeUpdatePooledTokenShare(ParticipantsList[id]);
        }    
        emit UpdatedPooledTokenShare();
    }

}

// TO DO This contract needs to ask the DAO to send CLD tokens from the Treasury
// to the Auction contract
contract CLDDao_Auction_Factory {
    address public DAO;
    address public CLD;
    Auction[] public auctionList;

    event NewAuction(address Addr, uint256 startDate, uint256 endDate, uint256 _AmountToAuction);

    struct Auction{
        address auctionAddress;
        uint256 startDate;
        uint256 endDate;
        uint256 amountAuctioned;
    }
    /*
    modifier OnlyDAO{
        require(msg.sender == DAO);
        _;
    }
   */
    constructor(address _DAO, address _CLD) {
        DAO = _DAO;
        CLD = _CLD;
    }
    

    function newCLDAuction(uint256 _EndTime, uint256 _Amount, uint256 _FeeInGwei) 
    external 
    //TO DO OnlyDAO
    {
        (CLDDao_Auction newInstance, 
        uint256 _startDate, 
        uint256 _endDate, 
        uint256 _amount ) = _newCLDAuction(_EndTime, _Amount, _FeeInGwei);
       
        auctionList.push(
            Auction({
            auctionAddress: address(newInstance),
            startDate: _startDate,
            endDate: _endDate,
            amountAuctioned: _amount
        }));

        emit NewAuction(address(newInstance), _startDate, _endDate, _amount);
    }
   
    function _newCLDAuction(uint256 _EndTime, uint256 _AmountToAuction, uint256 _FeeInGwei) 
    internal 
    returns (
        CLDDao_Auction NewAuctionAddress, 
        uint256 startDate,
        uint256 endDate,
        uint256 amount
    ) 
    {
        uint256 _startDate = block.timestamp;
        uint256 _endDate = _startDate + _EndTime;
        NewAuctionAddress = new CLDDao_Auction(_startDate, _endDate, _AmountToAuction, _FeeInGwei, DAO, CLD);
        return (NewAuctionAddress, _startDate, _endDate, _AmountToAuction);
    }

    /*
    function setDAOAddress(address NewDAOAddress) external OnlyDAO {
        DAO = NewDAOAddress;
    }
    */

    function SeeAuctionData(uint AuctionID) public view returns (address, uint, uint, uint) {
        return (
        auctionList[AuctionID].auctionAddress,
        auctionList[AuctionID].startDate,
        auctionList[AuctionID].endDate,
        auctionList[AuctionID].amountAuctioned
        );
    }
}

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint value) external returns (bool);
  function Mint(address _MintTo, uint256 _MintAmount) external;
  function transfer(address to, uint value) external;
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint);
  function CheckMinter(address AddytoCheck) external view returns(uint);
}