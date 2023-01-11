//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by the Winslow Core, and can also continue to be used 
if a new Winslow Core is deployed by changing DAO addresses
This contract provides a factory and sale contract for the Winslow Core to initiate sales of CLD from the treasury*/
pragma solidity ^0.8.17;

contract SaleFactoryV2{

}

contract SaleV2{
    //  Variable, struct, mapping and other Declarations
    //  Core
    address DAO;
    address CLD;
    address Treasury;
    uint256 CLDToBeSold;
    uint256 StartTime; //Unix Time
    uint256 EndTime;   //Unix Time
    //  Fees in basis points, chosen by proposer/al on deploy, so can be 0
    uint256 DAOFoundationFee; //Fee that goes directly to the foundation for further development
    uint256 RetractFee; //Fee that is charged when a user removes their ether from the pool, to count as totaletherpool
    // Details
    uint256 TotalEtherPool; //Defines the total amount of ether deposited by participators
    uint256 TotalRetractionFees; //Total amount of ether received from retraction fees 

    struct Participant{
        bool Participated;
        uint256 EtherDeposited;
        uint256 CLDWithdrawn;
    }
    
    //Mapping for participants
    mapping(address => Participant) public ParticipantDetails; 
    //List of participants for front-end ranking
    address[] public ParticipantList; 

    constructor(address _DAO, address _Treasury, uint256 CLDtoSell, uint256 SaleLength, uint256 FoundationFee, uint256 RetractionFee){
        require(SaleLength >= 259200 && SaleLength <= 1209600);
        DAO = _DAO;
        CLD = _CLD;
        CLDToBeSold = CLDtoSell;
        StartTime = block.timestamp + 43200;
        EndTime = StartTime + SaleLength;
        DAOFoundationFee = FoundationFee;
        RetractFee = RetractionFee;
        

    }






}

interface Core {
    function Treasury() external returns(address payable TreasuryAddress);
    function CLDAddress() external view returns(address CLD);
}