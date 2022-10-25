//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;

contract CLDDao_Auction {

    constructor(uint256 StartTime, uint256 EndTime, uint256 Amount) {}
    
    function returnOne() public pure returns(uint8 number) {
        number = 1;
        return number;
    }

}

contract CLDDao_Auction_Factory {
    address public DAO;
    Auction[] public auctionList;

    struct Auction{
        address auctionAddress;
        uint256 startDate;
        uint256 endDate;
        uint256 amountAuctioned;
    }
    
    modifier OnlyDAO{ 
        require(msg.sender == DAO);
        _;
    }

    constructor(address DAOAddress) {
        DAO = DAOAddress;
    }

    function newCLDAuction(uint256 _EndTime, uint256 _Amount) external OnlyDAO {
        (CLDDao_Auction newInstance, 
        uint256 _startDate, 
        uint256 _endDate, 
        uint256 _amount ) = _newCLDAuction(_EndTime, _Amount);
        
        auctionList.push(
            Auction({auctionAddress: address(newInstance),
            startDate: _startDate,
            endDate: _endDate,
            amountAuctioned: _amount 
            }));
    }
    
    function _newCLDAuction(uint256 _EndTime, uint256 _Amount) 
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
        NewAuctionAddress = new CLDDao_Auction(_startDate, _endDate, _Amount);
        return (NewAuctionAddress, _startDate, _endDate, _Amount);
    }

    function setDAOAddress(address NewDAOAddress) external OnlyDAO {
        DAO = NewDAOAddress;
    }
}