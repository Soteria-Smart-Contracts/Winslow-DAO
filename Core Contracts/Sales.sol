//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

// TO DO OnlyDAO modifiers and functions
contract CLDDao_Auction {
    address public DAO;
    address payable public Treasury;
    address public CLD;
    address payable[] public DevTeam;
    uint256 public MinimunFee;
    uint256 public RetireeFee;
    uint256 public StartTime;
    uint256 public EndTime;
    uint256 public ETCCollected;
    uint256 public ETCDeductedFromRetirees;
    uint256 public TokenAmount;
    uint256 public CurrentTokenBalance;
    /*
    modifier OnlyDAO{
        require(msg.sender == DAO, "This can only be done by the DAO");
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
    
    event ETCDeposited(uint256 AmountReceived, address PartAddr);
    event ParticipantRetired(uint256 AmountRetired);
    event ETCDWithdrawed(uint256 AmountWithdrawed);
    event CLDWithdrawed(uint256 AmountWithdrawed, address PartAddr);

    constructor(
        uint256 _StartTime, 
        uint256 _EndTime, 
        uint256 _Amount, 
        uint256 _MinimunFeeInGwei,
        uint256 _RetireeFeeInBP,  // BP = Basis points (100 (1%) to 10000 (100%))
        address _DAO,
        address payable _Treasury,
        address _CLD, 
        address payable[] memory _Devs
    ) 
    {
        require(
            _RetireeFeeInBP > 10 && _RetireeFeeInBP < 10000,
            "CLDAuction._RetireeFeeInBP: Needs to be at least 0,1 or 100 in Basis Points"
        );
        StartTime = _StartTime;
        EndTime = _EndTime;
        TokenAmount = _Amount;
        MinimunFee = _MinimunFeeInGwei;
        RetireeFee = _RetireeFeeInBP;
        DAO = _DAO;
        Treasury = _Treasury;
        CLD = _CLD;
        DevTeam = _Devs;
    }

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
        participantInfo[msg.sender].PooledTokenShare = UpdatePooledTokenShare(msg.sender);

        emit ETCDeposited(msg.value, msg.sender);
        return true;
    }

    function RetireFromAuction(uint256 Amount) external {
        require(
            Amount <= participantInfo[msg.sender].DepositedETC, 
            "CLDAuction.RetireFromAuction: You can't withdraw this many ETC"
        );
        require(
            block.timestamp < EndTime, 
            "CLDAuction.RetireFromAuction: The sale is over, you can only withdraw your CLD"
        );
        participantInfo[msg.sender].DepositedETC -= Amount;
        uint256 penalty = (Amount * RetireeFee) / 10000;
        payable(msg.sender).transfer(Amount - penalty);
        ETCDeductedFromRetirees += penalty;
        ETCCollected -= (Amount);

        emit ParticipantRetired(Amount - penalty);
    }

    // To Do OnlyDao
    function AddDev(address payable DevAddr) external {
        DevTeam.push(DevAddr);
    }

    //TO DO OnlyDAO ???
    function WithdrawETC() public returns (bool) {
        require(block.timestamp > EndTime, "CLDAuction.WithdrawETC: The sale is not over yet");
        require(address(this).balance > 0, "CLDAuction.WithdrawETC: No ether on this contract");

        Treasury.transfer(ETCCollected);
        // TO DO this needs testing
        uint256 valueForEachDev = ETCDeductedFromRetirees / DevTeam.length;
        for (uint256 id = 0; id < DevTeam.length; ++id) {
            DevTeam[id].transfer(valueForEachDev);
        }  

        emit ETCDWithdrawed(ETCCollected);
        return true;
    }

    function WithdrawCLD(address PartAddr) public {
        require(
            msg.sender == participantInfo[PartAddr].PartAddr, 
            "CLDAuction.WithdrawETC: You can't withdraw what's not yours"
        );
        require(block.timestamp > EndTime, "CLDAuction.WithdrawCLD: The sale is not over yet");
        require(participantInfo[msg.sender].DepositedETC > 0, "CLDAuction.WithdrawCLD: You didn't buy any CLD");
        participantInfo[PartAddr].PooledTokenShare = UpdatePooledTokenShare(PartAddr);
        uint256 CLDToSend = (TokenAmount * participantInfo[PartAddr].PooledTokenShare) / 10000;
        participantInfo[PartAddr].DepositedETC = 0;
        ERC20(CLD).transfer(PartAddr, CLDToSend);
        emit CLDWithdrawed(CLDToSend, PartAddr);
    }
    // To do DEBUG ONLY???
    function CheckParticipant(address PartAddr) public view returns (uint256, uint256, uint256) {
        uint256 _TokenShare = ((participantInfo[PartAddr].DepositedETC * 10000) / address(this).balance);
        return (participantInfo[PartAddr].DepositedETC, participantInfo[PartAddr].PooledTokenShare, _TokenShare);
    }
    
    function UpdatePooledTokenShare(address PartAddr) internal view returns (uint256) {
        uint256 _TokenShare = ((participantInfo[PartAddr].DepositedETC * 10000) / address(this).balance);
        return _TokenShare;
    }

}

// TO DO This contract needs to ask the DAO to send CLD tokens from the Treasury
// to the Auction contract
contract CLDDao_Auction_Factory {
    address public DAO;
    address payable public Treasury;
    address public CLD;
    Auction[] public auctionList;

    event NewAuction(address Addr, uint256 startDate, uint256 endDate, uint256 _AmountToAuction, address payable[] DevTeam);

    struct Auction{
        address auctionAddress;
        uint256 startDate;
        uint256 endDate;
        uint256 amountAuctioned;
    }
    /*
    modifier OnlyDAO{
        require(msg.sender == DAO, "This can only be done by the DAO");
        _;
    }
   */
    constructor(address _DAO, address _CLD, address payable _Treasury) {
        DAO = _DAO;
        Treasury= _Treasury;
        CLD = _CLD;
    }
    

    function newCLDAuction(
        uint256 _EndTime, 
        uint256 _Amount, 
        uint256 _MinimunFeeInGwei, 
        uint256 _RetireeFeeInBP, 
        address payable[] memory _DevTeam
    )
    external 
    //TO DO OnlyDAO
    {
        (
        CLDDao_Auction newInstance, 
        uint256 _startDate, 
        uint256 _endDate, 
        uint256 _amount 
        ) = _newCLDAuction(_EndTime, _Amount, _MinimunFeeInGwei, _RetireeFeeInBP, _DevTeam);
       
        auctionList.push(
            Auction({
            auctionAddress: address(newInstance),
            startDate: _startDate,
            endDate: _endDate,
            amountAuctioned: _amount
        }));

        emit NewAuction(address(newInstance), _startDate, _endDate, _amount, _DevTeam);
    }
   
    function _newCLDAuction
    (
        uint256 _EndTime,
        uint256 _AmountToAuction,
        uint256 _MinimunFeeInGwei,
        uint256 _RetireeFeeInBP,
        address payable[] memory _DevTeam
    )
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
        NewAuctionAddress = new CLDDao_Auction(
            _startDate,
            _endDate,
            _AmountToAuction,
            _MinimunFeeInGwei,
            _RetireeFeeInBP,
            DAO,
            Treasury,
            CLD,
            _DevTeam
        );
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