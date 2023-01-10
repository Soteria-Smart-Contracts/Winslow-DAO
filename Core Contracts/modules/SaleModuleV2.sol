//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by the Winslow Core, and can also continue to be used 
if a new Winslow Core is deployed by changing DAO addresses
This contract provides a factory and sale contract for the Winslow Core to initiate sales of CLD from the treasury*/
pragma solidity ^0.8.17;

contract SaleFactoryV2{

}

contract SaleV2{
    //  Variable Declarations
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

    struct ParticipantDetails{
        bool Participated;
        uint256 EtherDeposited;
    }
    
    mapping(address => ParticipantDetails) public 




}